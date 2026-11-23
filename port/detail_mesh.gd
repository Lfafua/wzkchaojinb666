extends RefCounted
## Millimetre-scale fittings share one indexed, vertex-coloured surface per part.
var tool := SurfaceTool.new()
var faces := 0
var pose := Transform3D.IDENTITY
static var finish: StandardMaterial3D

func _init():
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color):
 # Godot uses clockwise front faces.
 var normal := (pose.basis * (c-a).cross(b-a)).normalized()
 for point in [a,b,c,a,c,d]:
  tool.set_color(tint)
  tool.set_normal(normal)
  tool.add_vertex(pose * point)
 faces += 1

func block(center: Vector3, size: Vector3, tint: Color):
 var lo := center - size / 2
 var hi := center + size / 2
 var a := Vector3(lo.x, lo.y, hi.z)
 var b := Vector3(lo.x, hi.y, hi.z)
 var c := Vector3(hi.x, hi.y, hi.z)
 var d := Vector3(hi.x, lo.y, hi.z)
 var depth := Vector3(0,0,size.z)
 quad(a,b,c,d,tint)
 quad(d-depth,c-depth,b-depth,a-depth,tint)
 quad(a-depth,b-depth,b,a,tint)
 quad(d,c,c-depth,d-depth,tint)
 quad(b,b-depth,c-depth,c,tint)
 quad(a,d,d-depth,a-depth,tint)

func washer(center: Vector3, radius: float, bore: float, height: float, tint: Color, sides := 12):
 var lift := Vector3(0,0,height)
 for i in sides:
  var a := Vector3(cos(TAU*i/sides), sin(TAU*i/sides), 0)
  var b := Vector3(cos(TAU*(i+1)/sides), sin(TAU*(i+1)/sides), 0)
  quad(center+a*bore+lift,center+b*bore+lift,center+b*radius+lift,center+a*radius+lift,tint)
  quad(center+a*radius,center+a*radius+lift,center+b*radius+lift,center+b*radius,tint)

func finish_mesh(parent: Node3D):
 if faces == 0: return
 if not finish:
  finish = StandardMaterial3D.new()
  finish.vertex_color_use_as_albedo = true
  finish.vertex_color_is_srgb = true
  finish.metallic = 0.32
  finish.roughness = 0.52
 tool.set_material(finish)
 tool.index()
 var instance := MeshInstance3D.new()
 instance.name = "HardwareFittings"
 instance.mesh = tool.commit()
 instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(instance)
