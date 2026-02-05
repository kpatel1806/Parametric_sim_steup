require 'openstudio'

class SetBuildingScale < OpenStudio::Measure::ModelMeasure
  def name
    "Set Building Scale (X/Y Centered, Z Grounded)"
  end

  def description
    "Scales geometry. X/Y are anchored to the bounding-box center. Z is anchored to the minimum Z (ground), preventing downward growth."
  end

  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    x_scale = OpenStudio::Measure::OSArgument.makeDoubleArgument("x_scale", true)
    x_scale.setDisplayName("X Scale Factor")
    x_scale.setDefaultValue(1.0)
    args << x_scale

    y_scale = OpenStudio::Measure::OSArgument.makeDoubleArgument("y_scale", true)
    y_scale.setDisplayName("Y Scale Factor")
    y_scale.setDefaultValue(1.0)
    args << y_scale

    z_scale = OpenStudio::Measure::OSArgument.makeDoubleArgument("z_scale", true)
    z_scale.setDisplayName("Z Scale Factor")
    z_scale.setDefaultValue(1.0)
    args << z_scale

    return args
  end

  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    xs = runner.getDoubleArgumentValue("x_scale", user_arguments)
    ys = runner.getDoubleArgumentValue("y_scale", user_arguments)
    zs = runner.getDoubleArgumentValue("z_scale", user_arguments)

    if xs <= 0 || ys <= 0 || zs <= 0
      runner.registerError("Scale factors must be > 0.")
      return false
    end

    if zs > 1.5 || zs < 0.7
      runner.registerWarning("Z scale factor #{zs} may significantly alter floor-to-floor heights and zone volumes.")
    end

    # Collect all points for a robust bounding box
    pts = []

    model.getSurfaces.each do |s|
      s.vertices.each { |v| pts << v }
      s.subSurfaces.each do |ss|
        ss.vertices.each { |v| pts << v }
      end
    end

    model.getShadingSurfaces.each do |sh|
      sh.vertices.each { |v| pts << v }
    end

    if pts.empty?
      runner.registerAsNotApplicable("No geometry found to scale (no surfaces/shading).")
      return true
    end

    # Bounding box
    min_x = pts.map(&:x).min
    max_x = pts.map(&:x).max
    min_y = pts.map(&:y).min
    max_y = pts.map(&:y).max
    min_z = pts.map(&:z).min
    # max_z = pts.map(&:z).max # not needed unless you want reporting

    # Anchors: XY = bbox center, Z = ground (min Z)
    anchor_x = (min_x + max_x) / 2.0
    anchor_y = (min_y + max_y) / 2.0
    anchor_z = min_z

    scale_op = lambda do |vertices|
      new_verts = OpenStudio::Point3dVector.new
      vertices.each do |v|
        nx = anchor_x + (v.x - anchor_x) * xs
        ny = anchor_y + (v.y - anchor_y) * ys
        nz = anchor_z + (v.z - anchor_z) * zs
        new_verts << OpenStudio::Point3d.new(nx, ny, nz)
      end
      new_verts
    end

    # Scale surfaces + subsurfaces
    model.getSurfaces.each do |s|
      s.setVertices(scale_op.call(s.vertices))
      s.subSurfaces.each do |ss|
        ss.setVertices(scale_op.call(ss.vertices))
      end
    end

    # Scale shading
    model.getShadingSurfaces.each do |sh|
      sh.setVertices(scale_op.call(sh.vertices))
    end

    # Heal adjacencies
    begin
      OpenStudio::Model.matchSurfaces(model)
    rescue => e
      runner.registerWarning("matchSurfaces failed: #{e}")
    end

    runner.registerInfo("Scaled building with anchors: X/Y=bbox center (#{anchor_x.round(2)}, #{anchor_y.round(2)}), Z=ground (#{anchor_z.round(2)}).")
    runner.registerInfo("Scale factors: X=#{xs}, Y=#{ys}, Z=#{zs}.")
    return true
  end
end

SetBuildingScale.new.registerWithApplication
