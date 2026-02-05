

###### (Automatically generated documentation)

# NZEHVAC

## Description
Replaces existing HVAC with a high-efficiency system from NREL ZNE Ready 2017 standards.

## Modeler Description
Uses openstudio-standards to apply HVAC systems. Skips efficiency checks for stability.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Manual Climate Zone Override
Overrides internal check.
**Name:** climate_zone_manual,
**Type:** String,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Remove existing HVAC?

**Name:** remove_existing_hvac,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### HVAC System Type:

**Name:** hvac_system_type,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### DOAS capable of demand control ventilation?

**Name:** doas_dcv,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### HVAC System Partition:

**Name:** hvac_system_partition,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false




