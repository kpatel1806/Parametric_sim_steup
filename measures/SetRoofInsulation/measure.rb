require 'openstudio'

class SetRoofInsulation < OpenStudio::Measure::ModelMeasure

  def name
    return "Set Roof Insulation (Target Assembly R)"
  end

  def description
    return "Creates/assigns a simple roof construction (membrane + insulation + roof board) to all outdoor RoofCeiling surfaces, sizing insulation to hit a target assembly R-value (IP)."
  end

  def modeler_description
    return "Targets whole-assembly R by subtracting fixed layer RSI from target RSI to determine insulation thickness. Reuses objects by name, clamps thickness, reports achieved R."
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    r_value = OpenStudio::Measure::OSArgument.makeDoubleArgument("r_value", true)
    r_value.setDisplayName("Target Assembly R-Value (IP: ft^2*h*R/Btu)")
    r_value.setDefaultValue(30.0)
    args << r_value

    return args
  end

  # --- helper: find existing by exact name ---
  def find_standard_opaque_material_by_name(model, name)
    model.getStandardOpaqueMaterials.each do |m|
      return m if m.nameString == name
    end
    return nil
  end

  def find_construction_by_name(model, name)
    model.getConstructions.each do |c|
      return c if c.nameString == name
    end
    return nil
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    target_r_ip = runner.getDoubleArgumentValue("r_value", user_arguments)

    if target_r_ip <= 0
      runner.registerError("Target R-value must be > 0. Got #{target_r_ip}.")
      return false
    end

    # Conversion: R (ft^2*h*F/Btu) -> RSI (m^2*K/W)
    rsi_per_rip = 0.1761101838
    target_rsi_total = target_r_ip * rsi_per_rip

    # -----------------------------
    # 1) Fixed layers (outside -> inside)
    # -----------------------------

    # A) Roof membrane (thin)
    membrane_name = "Parametric Roof Membrane"
    membrane = find_standard_opaque_material_by_name(model, membrane_name)
    if membrane.nil?
      membrane = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      membrane.setName(membrane_name)
      membrane.setRoughness("MediumRough")
      membrane.setThickness(0.005)      # 5 mm (still "thin" but not ultra-tiny)
      membrane.setConductivity(0.16)
      membrane.setDensity(1121)
      membrane.setSpecificHeat(1460)
      membrane.setThermalAbsorptance(0.9)
      membrane.setSolarAbsorptance(0.7)
      membrane.setVisibleAbsorptance(0.7)
    end

    # B) Roof board/substrate (more realistic than continuous steel deck)
    # Typical cover board / wood fiber / gypsum board-ish proxy
    board_name = "Parametric Roof Board"
    board = find_standard_opaque_material_by_name(model, board_name)
    if board.nil?
      board = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      board.setName(board_name)
      board.setRoughness("MediumSmooth")
      board.setThickness(0.016)         # 16 mm
      board.setConductivity(0.17)       # W/m-K (gypsum-ish proxy)
      board.setDensity(800)
      board.setSpecificHeat(1090)
    end

    # Compute fixed RSI (membrane + board)
    fixed_rsi = 0.0
    fixed_layers = [membrane, board]
    fixed_layers.each do |mat|
      t = mat.thickness
      k = mat.conductivity
      if t <= 0 || k <= 0
        runner.registerError("Invalid fixed layer properties for '#{mat.nameString}': thickness=#{t}, conductivity=#{k}")
        return false
      end
      fixed_rsi += (t / k)
    end

    # -----------------------------
    # 2) Insulation sizing
    # -----------------------------
    # Material: XPS/Polyiso-ish proxy
    conductivity = 0.03 # W/m-K

    # Solve for required insulation RSI to meet target assembly RSI
    needed_insul_rsi = target_rsi_total - fixed_rsi

    if needed_insul_rsi <= 0
      runner.registerWarning(
        "Target assembly RSI (#{target_rsi_total.round(3)}) is <= fixed layers RSI (#{fixed_rsi.round(3)}). " \
        "Insulation will be set to minimum thickness."
      )
      needed_insul_rsi = 0.0
    end

    needed_thickness = needed_insul_rsi * conductivity

    # Clamp thickness to sane bounds
    min_thickness = 0.01  # 10 mm
    max_thickness = 1.00  # 1000 mm

    if needed_thickness < min_thickness
      runner.registerWarning("Computed insulation thickness #{needed_thickness.round(4)} m < #{min_thickness} m. Clamping to minimum.")
      needed_thickness = min_thickness
    elsif needed_thickness > max_thickness
      runner.registerWarning("Computed insulation thickness #{needed_thickness.round(4)} m > #{max_thickness} m. Clamping to maximum.")
      needed_thickness = max_thickness
    end

    insul_name = "Parametric Roof Insulation (Sized to R-#{target_r_ip.round(1)} Assembly)"
    insulation = find_standard_opaque_material_by_name(model, insul_name)
    if insulation.nil?
      insulation = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      insulation.setName(insul_name)
      insulation.setRoughness("MediumRough")
      insulation.setConductivity(conductivity)
      insulation.setDensity(29)
      insulation.setSpecificHeat(1210)
    end
    insulation.setThickness(needed_thickness) # update each run

    # -----------------------------
    # 3) Construction (reuse by name)
    # -----------------------------
    const_name = "Parametric Roof (Assembly R-#{target_r_ip.round(1)} IP)"
    new_roof_const = find_construction_by_name(model, const_name)
    if new_roof_const.nil?
      new_roof_const = OpenStudio::Model::Construction.new(model)
      new_roof_const.setName(const_name)
    end

    # Outside -> membrane -> insulation -> board -> inside
    layers = OpenStudio::Model::MaterialVector.new
    layers << membrane
    layers << insulation
    layers << board
    new_roof_const.setLayers(layers)

    # Compute achieved assembly RSI and R-IP (based on these 3 layers only)
    achieved_rsi = fixed_rsi + (insulation.thickness / insulation.conductivity)
    achieved_r_ip = achieved_rsi / rsi_per_rip

    # -----------------------------
    # 4) Apply to all exterior roofs
    # -----------------------------
    count = 0
    touched = []

    model.getSurfaces.each do |s|
      next unless s.surfaceType == "RoofCeiling"
      next unless s.outsideBoundaryCondition == "Outdoors"

      s.setConstruction(new_roof_const)
      count += 1
      touched << s.nameString
    end

    if count == 0
      runner.registerAsNotApplicable("No outdoor RoofCeiling surfaces found; nothing changed.")
      return true
    end

    runner.registerInfo("Target assembly R-IP: #{target_r_ip.round(2)} (RSI=#{target_rsi_total.round(3)}).")
    runner.registerInfo("Fixed layers RSI (membrane+board): #{fixed_rsi.round(3)}.")
    runner.registerInfo("Insulation thickness set to #{needed_thickness.round(4)} m (k=#{conductivity}).")
    runner.registerInfo("Achieved assembly R-IP (3-layer): #{achieved_r_ip.round(2)} (RSI=#{achieved_rsi.round(3)}).")
    runner.registerInfo("Applied construction '#{const_name}' to #{count} surfaces.")

    # Optional: verbose listing (comment out if too noisy)
    # touched.each { |n| runner.registerInfo("  - #{n}") }

    return true
  end
end

SetRoofInsulation.new.registerWithApplication
