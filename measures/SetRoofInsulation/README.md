

###### (Automatically generated documentation)

# Set Roof Insulation (Target Assembly R)

## Description
Creates/assigns a simple roof construction (membrane + insulation + roof board) to all outdoor RoofCeiling surfaces, sizing insulation to hit a target assembly R-value (IP).

## Modeler Description
Targets whole-assembly R by subtracting fixed layer RSI from target RSI to determine insulation thickness. Reuses objects by name, clamps thickness, reports achieved R.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Target Assembly R-Value (IP: ft^2*h*R/Btu)

**Name:** r_value,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false




