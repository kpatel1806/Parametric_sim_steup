# frozen_string_literal: true
require 'openstudio'

class SetWallInsulation < OpenStudio::Measure::ModelMeasure

  def name
    "Set Wall Insulation (Target Assembly R)"
  end

  def description
    "Assigns a parametric wall construction to all exterior walls and sizes insulation to hit a target assembly R-value (IP)."
  end

  def modeler_description
    "Creates/reuses a construction (cladding + insulation + gypsum) and applies it to Wall surfaces with Outdoors boundary."
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    r_value = OpenStudio::Measure::OSArgument.makeDoubleArgument("r_value", true)
    r_value.setDisplayName("Target Assembly R-Value (IP: ft^2*h*R/Btu)")
    r_value.setDefaultValue(13.0)
    args << r_value

    args
  end

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

    # --- Fixed layers (outside -> inside) ---
    # A) Cladding / sheathing proxy (adjust to match your standards)
    cladding_name = "Parametric Wall Cladding"
    cladding = find_standard_opaque_material_by_name(model, cladding_name)
    if cladding.nil?
      cladding = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      cladding.setName(cladding_name)
      cladding.setRoughness("MediumRough")
      cladding.setThickness(0.012)      # 12 mm
      cladding.setConductivity(0.16)    # wood-ish proxy
      cladding.setDensity(600)
      cladding.setSpecificHeat(1210)
    end

    # B) Interior gypsum
    gypsum_name = "Parametric Gypsum Board"
    gypsum = find_standard_opaque_material_by_name(model, gypsum_name)
    if gypsum.nil?
      gypsum = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      gypsum.setName(gypsum_name)
      gypsum.setRoughness("Smooth")
      gypsum.setThickness(0.0127)       # 1/2"
      gypsum.setConductivity(0.16)
      gypsum.setDensity(800)
      gypsum.setSpecificHeat(1090)
    end

    fixed_rsi = (cladding.thickness / cladding.conductivity) + (gypsum.thickness / gypsum.conductivity)

    # --- Insulation (variable) ---
    conductivity = 0.03 # W/m-K foam proxy; change if you want batt ~0.04
    needed_insul_rsi = target_rsi_total - fixed_rsi

    if needed_insul_rsi <= 0
      runner.registerWarning(
        "Target assembly RSI (#{target_rsi_total.round(3)}) <= fixed layers RSI (#{fixed_rsi.round(3)}). " \
        "Insulation set to minimum thickness."
      )
      needed_insul_rsi = 0.0
    end

    needed_thickness = needed_insul_rsi * conductivity

    # clamp thickness
    min_thickness = 0.01
    max_thickness = 0.60
    if needed_thickness < min_thickness
      runner.registerWarning("Computed insulation thickness #{needed_thickness.round(4)} m < #{min_thickness} m. Clamping.")
      needed_thickness = min_thickness
    elsif needed_thickness > max_thickness
      runner.registerWarning("Computed insulation thickness #{needed_thickness.round(4)} m > #{max_thickness} m. Clamping.")
      needed_thickness = max_thickness
    end

    insul_name = "Parametric Wall Insulation (Sized to R-#{target_r_ip.round(1)} Assembly)"
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

    achieved_rsi = fixed_rsi + (insulation.thickness / insulation.conductivity)
    achieved_r_ip = achieved_rsi / rsi_per_rip

    # --- Construction reuse ---
    const_name = "Parametric Wall (Assembly R-#{target_r_ip.round(1)} IP)"
    wall_const = find_construction_by_name(model, const_name)
    if wall_const.nil?
      wall_const = OpenStudio::Model::Construction.new(model)
      wall_const.setName(const_name)
    end

    layers = OpenStudio::Model::MaterialVector.new
    layers << cladding
    layers << insulation
    layers << gypsum
    wall_const.setLayers(layers)

    # --- Apply to exterior wall surfaces only ---
    count = 0
    model.getSurfaces.each do |s|
      next unless s.surfaceType == "Wall"
      next unless s.outsideBoundaryCondition == "Outdoors"
      s.setConstruction(wall_const)
      count += 1
    end

    if count == 0
      runner.registerAsNotApplicable("No exterior Wall surfaces (Outdoors) found; nothing changed.")
      return true
    end

    runner.registerInfo("Target assembly R-IP: #{target_r_ip.round(2)} (RSI=#{target_rsi_total.round(3)}).")
    runner.registerInfo("Fixed layers RSI (cladding+gypsum): #{fixed_rsi.round(3)}.")
    runner.registerInfo("Insulation thickness set to #{needed_thickness.round(4)} m (k=#{conductivity}).")
    runner.registerInfo("Achieved assembly R-IP (3-layer): #{achieved_r_ip.round(2)} (RSI=#{achieved_rsi.round(3)}).")
    runner.registerInfo("Applied construction '#{const_name}' to #{count} exterior wall surfaces.")

    true
  end
end

SetWallInsulation.new.registerWithApplication
