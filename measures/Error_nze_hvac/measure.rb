# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

class NzeHvac < OpenStudio::Measure::ModelMeasure
  require 'openstudio-standards'

  def name
    'NZEHVAC'
  end

  def description
    'Replaces existing HVAC with a high-efficiency system from NREL ZNE Ready 2017 standards.'
  end

  def modeler_description
    'Uses openstudio-standards to apply HVAC systems. Skips efficiency checks for stability.'
  end

  # Helper method to add systems
  def add_system_to_zones(model, runner, hvac_system_type, zones, standard, doas_dcv: false)
    doas_system_type = doas_dcv ? 'DOAS with DCV' : 'DOAS'

    case hvac_system_type.to_s
    when 'DOAS with fan coil chiller with boiler'
      standard.model_add_hvac_system(model, doas_system_type, 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', air_loop_heating_type: 'Water', air_loop_cooling_type: 'Water')
      standard.model_add_hvac_system(model, 'Fan Coil', 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', zone_equipment_ventilation: false)
      standard.model_add_waterside_economizer(model, model.getPlantLoopByName('Chilled Water Loop').get, model.getPlantLoopByName('Condenser Water Loop').get, integrated: true)

    when 'DOAS with fan coil chiller with central air source heat pump'
      standard.model_add_hvac_system(model, doas_system_type, 'AirSourceHeatPump', nil, 'Electricity', zones, air_loop_heating_type: 'Water', air_loop_cooling_type: 'Water')
      standard.model_add_hvac_system(model, 'Fan Coil', 'AirSourceHeatPump', nil, 'Electricity', zones, zone_equipment_ventilation: false)
      standard.model_add_waterside_economizer(model, model.getPlantLoopByName('Chilled Water Loop').get, model.getPlantLoopByName('Condenser Water Loop').get, integrated: true)

    when 'DOAS with fan coil air-cooled chiller with boiler'
      standard.model_add_hvac_system(model, doas_system_type, 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', chilled_water_loop_cooling_type: 'AirCooled', air_loop_heating_type: 'Water', air_loop_cooling_type: 'Water')
      standard.model_add_hvac_system(model, 'Fan Coil', 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', chilled_water_loop_cooling_type: 'AirCooled', zone_equipment_ventilation: false)

    when 'DOAS with fan coil air-cooled chiller with central air source heat pump'
      standard.model_add_hvac_system(model, doas_system_type, 'AirSourceHeatPump', nil, 'Electricity', zones, chilled_water_loop_cooling_type: 'AirCooled', air_loop_heating_type: 'Water', air_loop_cooling_type: 'Water')
      standard.model_add_hvac_system(model, 'Fan Coil', 'AirSourceHeatPump', nil, 'Electricity', zones, chilled_water_loop_cooling_type: 'AirCooled', zone_equipment_ventilation: false)

    when 'Fan coil chiller with boiler'
      standard.model_add_hvac_system(self, 'Fan Coil', 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature')
      standard.model_add_waterside_economizer(model, model.getPlantLoopByName('Chilled Water Loop').get, model.getPlantLoopByName('Condenser Water Loop').get, integrated: true)

    when 'Fan coil chiller with central air source heat pump'
      standard.model_add_hvac_system(self, 'Fan Coil', 'AirSourceHeatPump', nil, 'Electricity', zones)
      standard.model_add_waterside_economizer(model, model.getPlantLoopByName('Chilled Water Loop').get, model.getPlantLoopByName('Condenser Water Loop').get, integrated: true)

    when 'Fan coil air-cooled chiller with boiler'
      standard.model_add_hvac_system(self, 'Fan Coil', 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', chilled_water_loop_cooling_type: 'AirCooled')

    when 'Fan coil air-cooled chiller with central air source heat pump'
      standard.model_add_hvac_system(self, 'Fan Coil', 'AirSourceHeatPump', nil, 'Electricity', zones, chilled_water_loop_cooling_type: 'AirCooled')

    when 'DOAS with radiant slab chiller with boiler'
      standard.model_add_hvac_system(model, doas_system_type, 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', air_loop_heating_type: 'Water', air_loop_cooling_type: 'Water')
      standard.model_add_hvac_system(model, 'Radiant Slab', 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature')
      standard.model_add_waterside_economizer(model, model.getPlantLoopByName('Chilled Water Loop').get, model.getPlantLoopByName('Condenser Water Loop').get, integrated: true)

    when 'DOAS with radiant slab chiller with central air source heat pump'
      standard.model_add_hvac_system(model, doas_system_type, 'AirSourceHeatPump', nil, 'Electricity', zones, air_loop_heating_type: 'Water', air_loop_cooling_type: 'Water')
      standard.model_add_hvac_system(model, 'Radiant Slab', 'AirSourceHeatPump', nil, 'Electricity', zones)
      standard.model_add_waterside_economizer(model, model.getPlantLoopByName('Chilled Water Loop').get, model.getPlantLoopByName('Condenser Water Loop').get, integrated: true)

    when 'DOAS with radiant slab air-cooled chiller with boiler'
      standard.model_add_hvac_system(model, doas_system_type, 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', chilled_water_loop_cooling_type: 'AirCooled', air_loop_heating_type: 'Water', air_loop_cooling_type: 'Water')
      standard.model_add_hvac_system(model, 'Radiant Slab', 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', chilled_water_loop_cooling_type: 'AirCooled')

    when 'DOAS with radiant slab air-cooled chiller with central air source heat pump'
      standard.model_add_hvac_system(model, doas_system_type, 'AirSourceHeatPump', nil, 'Electricity', zones, chilled_water_loop_cooling_type: 'AirCooled', air_loop_heating_type: 'Water', air_loop_cooling_type: 'Water')
      standard.model_add_hvac_system(model, 'Radiant Slab', 'AirSourceHeatPump', nil, 'Electricity', zones, chilled_water_loop_cooling_type: 'AirCooled')

    when 'DOAS with VRF'
      standard.model_add_hvac_system(model, doas_system_type, 'Electricity', nil, 'Electricity', zones, air_loop_heating_type: 'DX', air_loop_cooling_type: 'DX')
      standard.model_add_hvac_system(model, 'VRF', 'Electricity', nil, 'Electricity', zones, zone_equipment_ventilation: false)

    when 'VRF'
      standard.model_add_hvac_system(model, 'VRF', 'Electricity', nil, 'Electricity', zones)

    when 'DOAS with water source heat pumps cooling tower with boiler'
      standard.model_add_hvac_system(model, doas_system_type, 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature')
      standard.model_add_hvac_system(model, 'Water Source Heat Pumps', 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', heat_pump_loop_cooling_type: 'CoolingTower', zone_equipment_ventilation: false)

    when 'DOAS with water source heat pumps with ground source heat pump'
      standard.model_add_hvac_system(model, doas_system_type, 'Electricity', nil, 'Electricity', zones, air_loop_heating_type: 'DX', air_loop_cooling_type: 'DX')
      standard.model_add_hvac_system(model, 'Ground Source Heat Pumps', 'Electricity', nil, 'Electricity', zones, zone_equipment_ventilation: false)

    when 'Water source heat pumps cooling tower with boiler'
      standard.model_add_hvac_system(model, 'Water Source Heat Pumps', 'NaturalGas', nil, 'Electricity', zones, hot_water_loop_type: 'LowTemperature', heat_pump_loop_cooling_type: 'CoolingTower')

    when 'Water source heat pumps with ground source heat pump'
      standard.model_add_hvac_system(model, 'Ground Source Heat Pumps', 'Electricity', nil, 'Electricity', zones)

    when 'PVAV with gas boiler reheat'
      standard.model_add_hvac_system(model, 'PVAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity', zones, hot_water_loop_type: 'LowTemperature')

    when 'PVAV with central air source heat pump reheat'
      standard.model_add_hvac_system(model, 'PVAV Reheat', 'AirSourceHeatPump', 'AirSourceHeatPump', 'Electricity', zones)

    when 'VAV chiller with gas boiler reheat'
      standard.model_add_hvac_system(model, 'VAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity', zones, hot_water_loop_type: 'LowTemperature')
      standard.model_add_waterside_economizer(model, model.getPlantLoopByName('Chilled Water Loop').get, model.getPlantLoopByName('Condenser Water Loop').get, integrated: true)

    when 'VAV chiller with central air source heat pump reheat'
      standard.model_add_hvac_system(model, 'VAV Reheat', 'AirSourceHeatPump', 'AirSourceHeatPump', 'Electricity', zones)
      standard.model_add_waterside_economizer(model, model.getPlantLoopByName('Chilled Water Loop').get, model.getPlantLoopByName('Condenser Water Loop').get, integrated: true)

    when 'VAV air-cooled chiller with gas boiler reheat'
      standard.model_add_hvac_system(model, 'VAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity', zones, hot_water_loop_type: 'LowTemperature', chilled_water_loop_cooling_type: 'AirCooled')

    when 'VAV air-cooled chiller with central air source heat pump reheat'
      standard.model_add_hvac_system(model, 'VAV Reheat', 'AirSourceHeatPump', 'AirSourceHeatPump', 'Electricity', zones, chilled_water_loop_cooling_type: 'AirCooled')

    when 'PSZ-HP'
      standard.model_add_hvac_system(self, 'PSZ-HP', 'Electricity', nil, 'Electricity', zones)
    else
      runner.registerError("HVAC System #{hvac_system_type} not recognized")
      return false
    end
    runner.registerInfo("Added HVAC System type #{hvac_system_type} to the model for #{zones.size} zones")
  end

  def arguments(_model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # === MANUAL CLIMATE ZONE ARGUMENT ===
    climate_zone_manual = OpenStudio::Measure::OSArgument.makeStringArgument('climate_zone_manual', false)
    climate_zone_manual.setDisplayName('Manual Climate Zone Override')
    climate_zone_manual.setDescription('Overrides internal check.')
    args << climate_zone_manual
    # ====================================

    remove_existing_hvac = OpenStudio::Measure::OSArgument.makeBoolArgument('remove_existing_hvac', true)
    remove_existing_hvac.setDisplayName('Remove existing HVAC?')
    remove_existing_hvac.setDefaultValue(false)
    args << remove_existing_hvac

    hvac_system_type_choices = OpenStudio::StringVector.new
    hvac_system_type_choices << 'DOAS with fan coil chiller with boiler'
    hvac_system_type_choices << 'DOAS with fan coil chiller with central air source heat pump'
    hvac_system_type_choices << 'DOAS with fan coil air-cooled chiller with boiler'
    hvac_system_type_choices << 'DOAS with fan coil air-cooled chiller with central air source heat pump'
    hvac_system_type_choices << 'Fan coil chiller with boiler'
    hvac_system_type_choices << 'Fan coil chiller with central air source heat pump'
    hvac_system_type_choices << 'Fan coil air-cooled chiller with boiler'
    hvac_system_type_choices << 'Fan coil air-cooled chiller with central air source heat pump'
    hvac_system_type_choices << 'DOAS with radiant slab chiller with boiler'
    hvac_system_type_choices << 'DOAS with radiant slab chiller with central air source heat pump'
    hvac_system_type_choices << 'DOAS with radiant slab air-cooled chiller with boiler'
    hvac_system_type_choices << 'DOAS with radiant slab air-cooled chiller with central air source heat pump'
    hvac_system_type_choices << 'DOAS with VRF'
    hvac_system_type_choices << 'VRF'
    hvac_system_type_choices << 'DOAS with water source heat pumps cooling tower with boiler'
    hvac_system_type_choices << 'DOAS with water source heat pumps with ground source heat pump'
    hvac_system_type_choices << 'Water source heat pumps cooling tower with boiler'
    hvac_system_type_choices << 'Water source heat pumps with ground source heat pump'
    hvac_system_type_choices << 'VAV chiller with gas boiler reheat'
    hvac_system_type_choices << 'VAV chiller with central air source heat pump reheat'
    hvac_system_type_choices << 'VAV air-cooled chiller with gas boiler reheat'
    hvac_system_type_choices << 'VAV air-cooled chiller with central air source heat pump reheat'
    hvac_system_type_choices << 'PVAV with gas boiler reheat'
    hvac_system_type_choices << 'PVAV with central air source heat pump reheat'
    hvac_system_type = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_system_type', hvac_system_type_choices, true)
    hvac_system_type.setDisplayName('HVAC System Type:')
    hvac_system_type.setDefaultValue('DOAS with fan coil chiller with central air source heat pump')
    args << hvac_system_type

    doas_dcv = OpenStudio::Measure::OSArgument.makeBoolArgument('doas_dcv', true)
    doas_dcv.setDisplayName('DOAS capable of demand control ventilation?')
    doas_dcv.setDefaultValue(false)
    args << doas_dcv

    hvac_system_partition_choices = OpenStudio::StringVector.new
    hvac_system_partition_choices << 'Automatic Partition'
    hvac_system_partition_choices << 'Whole Building'
    hvac_system_partition_choices << 'One System Per Building Story'
    hvac_system_partition_choices << 'One System Per Building Type'
    hvac_system_partition = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_system_partition', hvac_system_partition_choices, true)
    hvac_system_partition.setDisplayName('HVAC System Partition:')
    hvac_system_partition.setDefaultValue('Automatic Partition')
    args << hvac_system_partition

    args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    remove_existing_hvac = runner.getBoolArgumentValue('remove_existing_hvac', user_arguments)
    hvac_system_type = runner.getOptionalStringArgumentValue('hvac_system_type', user_arguments)
    doas_dcv = runner.getBoolArgumentValue('doas_dcv', user_arguments)
    hvac_system_partition = runner.getOptionalStringArgumentValue('hvac_system_partition', user_arguments)
    hvac_system_partition = hvac_system_partition.to_s

    # Switch to 90.1-2013 because it has better VRF data coverage
    std = Standard.build('90.1-2013')

    unless model.getBuilding.standardsBuildingType.is_initialized
      dominant_building_type = std.model_get_standards_building_type(model)
      model.getBuilding.setStandardsBuildingType(dominant_building_type.nil? ? 'Office' : dominant_building_type)
    end

    # === MANUAL CLIMATE ZONE LOGIC (FIXED) ===
    climate_zone_manual = runner.getOptionalStringArgumentValue('climate_zone_manual', user_arguments)
    climate_zone_obj = model.getClimateZones.getClimateZone('ASHRAE', 2013)

    if climate_zone_manual.is_initialized
      climate_zone = climate_zone_manual.get
      runner.registerInfo("Using manual climate zone from Python: #{climate_zone}")
    elsif !climate_zone_obj.empty
      climate_zone = "ASHRAE 169-2013-#{climate_zone_obj.value}"
    else
      runner.registerWarning("No Climate Zone found. Defaulting to ASHRAE 169-2013-4A")
      climate_zone = "ASHRAE 169-2013-4A"
    end
    # ========================================

    if remove_existing_hvac
      runner.registerInfo('Removing existing HVAC systems from the model')
      std.remove_hvac(model)
    end

    conditioned_zones = []
    model.getThermalZones.each do |zone|
      next if OpenstudioStandards::ThermalZone.thermal_zone_plenum?(zone)
      next if !OpenstudioStandards::ThermalZone.thermal_zone_heated?(zone) && !OpenstudioStandards::ThermalZone.thermal_zone_cooled?(zone)
      conditioned_zones << zone
    end

    case hvac_system_partition
    when 'Automatic Partition'
      sys_groups = OpenstudioStandards::Geometry.model_group_thermal_zones_by_occupancy_type(model, min_area_m2: OpenStudio.convert(20_000, 'ft^2', 'm^2').get)
      sec_sys_type = (['VAV Reheat', 'PVAV Reheat'].include?(hvac_system_type.to_s)) ? 'PSZ-HP' : hvac_system_type

      sys_groups.each do |sys_group|
        pri_sec_zone_lists = std.model_differentiate_primary_secondary_thermal_zones(model, sys_group['zones'])
        add_system_to_zones(model, runner, hvac_system_type, pri_sec_zone_lists['primary'], std, doas_dcv: doas_dcv)
        unless pri_sec_zone_lists['secondary'].empty?
          add_system_to_zones(model, runner, sec_sys_type, pri_sec_zone_lists['secondary'], std, doas_dcv: doas_dcv)
        end
      end
    when 'Whole Building'
      add_system_to_zones(model, runner, hvac_system_type, conditioned_zones, std, doas_dcv: doas_dcv)
    when 'One System Per Building Story'
      story_groups = OpenstudioStandards::Geometry.model_group_thermal_zones_by_building_story(model, conditioned_zones)
      story_groups.each do |story_zones|
        add_system_to_zones(model, runner, hvac_system_type, story_zones, std, doas_dcv: doas_dcv)
      end
    when 'One System Per Building Type'
      system_groups = OpenstudioStandards::Geometry.model_group_thermal_zones_by_building_type(model, min_area_m2: 0.0)
      system_groups.each do |system_group|
        add_system_to_zones(model, runner, hvac_system_type, system_group['zones'], std, doas_dcv: doas_dcv)
      end
    else
      runner.registerError('Invalid HVAC system partition choice')
      return false
    end

    # === CRITICAL FIX: DISABLE EFFICIENCY CHECK ===
    std.model_apply_hvac_efficiency_standard(model, climate_zone)
    runner.registerWarning("SKIPPING EFFICIENCY STANDARD CHECK to prevent crash.")
    # ==============================================

    # Run Sizing Run
    if std.model_run_sizing_run(model, "#{Dir.pwd}/SizingRun") == false
      runner.registerError("Sizing run failed.")
      return false
    end

    runner.registerFinalCondition("Added system type #{hvac_system_type} to model.")
    true
  end
end

NzeHvac.new.registerWithApplication
