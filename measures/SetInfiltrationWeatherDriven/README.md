

###### (Automatically generated documentation)

# Set Infiltration (Weather-Driven)

## Description


## Modeler Description


## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Base Flow per Exterior Surface Area (m3/s per m2 exterior)

**Name:** flow_per_area,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Constant Term Coefficient (A)

**Name:** const_coeff,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Temperature Term Coefficient (B) multiplying |ΔT| [1/K]

**Name:** temp_coeff,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Wind Speed Term Coefficient (C) multiplying Wind [s/m]

**Name:** wind_coeff,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Wind Speed Squared Term Coefficient (D) multiplying Wind^2 [s^2/m^2]

**Name:** wind2_coeff,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Create infiltration objects if none exist

**Name:** create_if_missing,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false




