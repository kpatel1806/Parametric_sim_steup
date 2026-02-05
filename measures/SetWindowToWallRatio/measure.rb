# frozen_string_literal: true

# 1. Define the class
class SetWindowToWallRatio < OpenStudio::Measure::ModelMeasure

  # 2. Metadata (Name and Description)
  def name
    return "Set Window to Wall Ratio"
  end

  def description
    return "Sets the window-to-wall ratio for all facades to a specific number."
  end

  def modeler_description
    return "This measure deletes all existing windows and adds new ribbons of windows to meet the target ratio."
  end

  # 3. ARGUMENTS (The Interface)
  #    This defines what you can control from Python.
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Argument: "wwr" (Window to Wall Ratio)
    # We ask for a "Double" (a decimal number like 0.4)
    wwr = OpenStudio::Measure::OSArgument.makeDoubleArgument("wwr", true)
    wwr.setDisplayName("Window to Wall Ratio (fraction)")
    wwr.setDescription("Enter a number between 0.0 and 0.99 (e.g., 0.4 for 40%)")
    wwr.setDefaultValue(0.4)
    args << wwr

    return args
  end

  # 4. RUN (The Logic)
  #    This is where we change the building.
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # A. Retrieve the input value from Python
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    wwr = runner.getDoubleArgumentValue("wwr", user_arguments)

    # B. Safety Check
    if wwr < 0.0 || wwr >= 1.0
      runner.registerError("WWR must be between 0.0 and 1.0.")
      return false
    end

    runner.registerInfo("Setting WWR to #{wwr}")

    # C. apply to the Model
    #    We use a shortcut built into OpenStudio models: "applyWindowToWallRatio"
    #    It automatically deletes old windows and adds new ones.
    model.getSurfaces.each do |surface|
      # Only apply to exterior walls
      if surface.surfaceType == "Wall" && surface.outsideBoundaryCondition == "Outdoors"
        # 0.7 = 70% offset from floor (sill height)
        # true = look at existing windows
        surface.setWindowToWallRatio(wwr, 0.8, true)
      end
    end

    return true
  end
end

# 5. Register the Measure
SetWindowToWallRatio.new.registerWithApplication
