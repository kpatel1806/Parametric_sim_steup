require 'openstudio'

class SetInfiltrationWeatherDriven < OpenStudio::Measure::ModelMeasure

  def name
    return "Set Infiltration (Weather-Driven)"
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    flow = OpenStudio::Measure::OSArgument.makeDoubleArgument("flow_per_area", true)
    flow.setDisplayName("Base Flow per Exterior Surface Area (m3/s per m2 exterior)")
    flow.setDefaultValue(0.000226)
    args << flow

    # Coefficients: V = Vdesign*(A + B|dT| + C*Wind + D*Wind^2)
    a = OpenStudio::Measure::OSArgument.makeDoubleArgument("const_coeff", true)
    a.setDisplayName("Constant Term Coefficient (A)")
    a.setDefaultValue(1.0)
    args << a

    b = OpenStudio::Measure::OSArgument.makeDoubleArgument("temp_coeff", true)
    b.setDisplayName("Temperature Term Coefficient (B) multiplying |ΔT| [1/K]")
    b.setDefaultValue(0.0)
    args << b

    c = OpenStudio::Measure::OSArgument.makeDoubleArgument("wind_coeff", true)
    c.setDisplayName("Wind Speed Term Coefficient (C) multiplying Wind [s/m]")
    c.setDefaultValue(0.0)
    args << c

    d = OpenStudio::Measure::OSArgument.makeDoubleArgument("wind2_coeff", true)
    d.setDisplayName("Wind Speed Squared Term Coefficient (D) multiplying Wind^2 [s^2/m^2]")
    d.setDefaultValue(0.0)
    args << d

    create_if_missing = OpenStudio::Measure::OSArgument.makeBoolArgument("create_if_missing", true)
    create_if_missing.setDisplayName("Create infiltration objects if none exist")
    create_if_missing.setDefaultValue(true)
    args << create_if_missing

    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    flow_per_area = runner.getDoubleArgumentValue("flow_per_area", user_arguments)
    a = runner.getDoubleArgumentValue("const_coeff", user_arguments)
    b = runner.getDoubleArgumentValue("temp_coeff", user_arguments)
    c = runner.getDoubleArgumentValue("wind_coeff", user_arguments)
    d = runner.getDoubleArgumentValue("wind2_coeff", user_arguments)
    create_if_missing = runner.getBoolArgumentValue("create_if_missing", user_arguments)

    if flow_per_area < 0
      runner.registerError("flow_per_area must be >= 0. Got #{flow_per_area}.")
      return false
    end

    infils = model.getSpaceInfiltrationDesignFlowRates

    if infils.empty?
      if create_if_missing
        model.getSpaces.each do |space|
          infil = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
          infil.setName("Weather-Driven Infiltration - #{space.nameString}")
          infil.setSpace(space)
          infils << infil
        end
        runner.registerInfo("Created #{infils.size} infiltration objects (one per space).")
      else
        runner.registerAsNotApplicable("No infiltration objects found; nothing to update.")
        return true
      end
    end

    updated = 0
    infils.each do |infil|
      # Base magnitude method:
      infil.setFlowperExteriorSurfaceArea(flow_per_area)

      # Defensive: disable other base methods if present
      infil.setDesignFlowRate(0.0) if infil.designFlowRate.is_initialized
      infil.setFlowperSpaceFloorArea(0.0) if infil.flowperSpaceFloorArea.is_initialized
      infil.setAirChangesperHour(0.0) if infil.airChangesperHour.is_initialized

      # Weather dependence (EPW drives Outdoor T and Wind)
      infil.setConstantTermCoefficient(a)
      infil.setTemperatureTermCoefficient(b)
      infil.setVelocityTermCoefficient(c)
      infil.setVelocitySquaredTermCoefficient(d)

      updated += 1
    end

    runner.registerInfo("Set weather-driven infiltration on #{updated} objects.")
    runner.registerInfo("Base: #{flow_per_area} m3/s/m2(exterior). Coeffs: A=#{a}, B=#{b}, C=#{c}, D=#{d}.")
    return true
  end
end

SetInfiltrationWeatherDriven.new.registerWithApplication
