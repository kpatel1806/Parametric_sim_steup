require 'openstudio'

class SetFloorInsulation < OpenStudio::Measure::ModelMeasure

  def name
    return "Set Floor Insulation (Target Assembly R)"
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    r_value = OpenStudio::Measure::OSArgument.makeDoubleArgument("r_value", true)
    r_value.setDisplayName("Target Assembly R-Value (IP: ft^2*h*R/Btu)")
    r_value.setDefaultValue(10.0)
    args << r_value

    return args
  end

  # --- helpers to reuse objects ---
  def find_standard_opaque_material_by_name(model, name)
    model.getStandardOpaqueMaterials.each { |m| return m if m.nameString == name }
    nil
  end

  def find_construction_by_name(model, name)
    model.getConstructions.each { |c| return c if c.nameString == name }
    nil
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    target_r_ip = runner.getDoubleArgumentValue("r_value", user_arguments)
    if target_r_ip <= 0
      runner.registerError("Target R-value must be > 0. Got #{target_r_ip}.")
      return false
    end

    rsi_per_rip = 0.1761101838
    target_rsi_total = target_r_ip * rsi_per_rip

    # --- fixed layers ---
    concrete_name = "Parametric 150mm Concrete Slab"
    concrete = find_standard_opaque_material_by_name(model, concrete_name)
    if concrete.nil?
      concrete = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      concrete.setName(concrete_name)
      concrete.setRoughness("MediumRough")
      concrete.setThickness(0.15)
      concrete.setConductivity(2.3)
      concrete.setDensity(2400)
      concrete.setSpecificHeat(840)
    end

    carpet_name = "Parametric Carpet Finish"
    carpet = find_standard_opaque_material_by_name(model, carpet_name)
    if carpet.nil?
      carpet = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      carpet.setName(carpet_name)
      carpet.setRoughness("VeryRough")
      carpet.setThickness(0.01)
      carpet.setConductivity(0.06)
      carpet.setDensity(200)
      carpet.setSpecificHeat(1300)
    end

    fixed_rsi = (concrete.thickness / concrete.conductivity) + (carpet.thickness / carpet.conductivity)

    # --- insulation sizing to hit target assembly RSI ---
    conductivity = 0.03 # W/m-K (foam proxy)

    needed_insul_rsi = target_rsi_total - fixed_rsi
    if needed_insul_rsi <= 0
      runner.registerWarning(
        "Target assembly RSI (#{target_rsi_total.round(3)}) is <= fixed layers RSI (#{fixed_rsi.round(3)}). " \
        "Insulation will be set to minimum thickness."
      )
      needed_insul_rsi = 0.0
    end

    needed_thickness = needed_insul_rsi * conductivity

    # clamp to sane bounds
    min_thickness = 0.01
    max_thickness = 1.00
    if needed_thickness < min_thickness
      runner.registerWarning("Computed insulation thickness #{needed_thickness.round(4)} m < #{min_thickness} m. Clamping.")
      needed_thickness = min_thickness
    elsif needed_thickness > max_thickness
      runner.registerWarning("Computed insulation thickness #{needed_thickness.round(4)} m > #{max_thickness} m. Clamping.")
      needed_thickness = max_thickness
    end

    insul_name = "Parametric Floor Insulation (Sized to R-#{target_r_ip.round(1)} Assembly)"
    insulation = find_standard_opaque_material_by_name(model, insul_name)
    if insulation.nil?
      insulation = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      insulation.setName(insul_name)
      insulation.setRoughness("MediumRough")
      insulation.setConductivity(conductivity)
      insulation.setDensity(29)
      insulation.setSpecificHeat(1210)
    end
    insulation.setThickness(needed_thickness)

    # Achieved assembly R (of these layers)
    achieved_rsi = fixed_rsi + (insulation.thickness / insulation.conductivity)
    achieved_r_ip = achieved_rsi / rsi_per_rip

    # --- construction reuse ---
    const_name = "Parametric Slab (Assembly R-#{target_r_ip.round(1)} IP)"
    new_floor_const = find_construction_by_name(model, const_name)
    if new_floor_const.nil?
      new_floor_const = OpenStudio::Model::Construction.new(model)
      new_floor_const.setName(const_name)
    end

    # Outside (ground) -> insulation -> concrete -> carpet -> inside
    layers = OpenStudio::Model::MaterialVector.new
    layers << insulation
    layers << concrete
    layers << carpet
    new_floor_const.setLayers(layers)

    # --- apply ---
    count = 0
    model.getSurfaces.each do |s|
      next unless s.surfaceType == "Floor"
      next unless s.outsideBoundaryCondition == "Ground"
      s.setConstruction(new_floor_const)
      count += 1
    end

    if count == 0
      runner.registerAsNotApplicable("No ground-contact Floor surfaces found; nothing changed.")
      return true
    end

    runner.registerInfo("Target assembly R-IP: #{target_r_ip.round(2)} (RSI=#{target_rsi_total.round(3)}).")
    runner.registerInfo("Fixed layers RSI (concrete+carpet): #{fixed_rsi.round(3)}.")
    runner.registerInfo("Insulation thickness set to #{needed_thickness.round(4)} m (k=#{conductivity}).")
    runner.registerInfo("Achieved assembly R-IP (3-layer): #{achieved_r_ip.round(2)} (RSI=#{achieved_rsi.round(3)}).")
    runner.registerInfo("Applied construction '#{const_name}' to #{count} ground floor surfaces.")

    return true
  end
end

SetFloorInsulation.new.registerWithApplication
