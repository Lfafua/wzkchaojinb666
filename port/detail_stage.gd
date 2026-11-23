extends "res://stage.gd"
## Add fittings in each part's original local coordinate system. The original
## stage still owns fit, animated meshes, inspection poses and picking.
const Fittings = preload("res://detail_mesh.gd")
const BRUSHED_ALUMINUM := Color("#b8bec0")
const STEEL := Color("#666e73")
const GOLD := Color("#be9b51")
const CERAMIC := Color("#aa8b64")
const INK_BLACK := Color("#272c30")
const SILK := Color("#d9dcce")

func paint(n: Node3D, p: Dictionary, powered: bool, loose: bool, worn: bool, inspecting: bool, rad_pose: Transform3D = Transform3D.IDENTITY) -> void:
 super.paint(n, p, powered, loose, worn, inspecting, rad_pose)
 var parts := Fittings.new()
 var dims := Layout.size_of(p)
 match str(p.slot):
  "cpu": processor_marks(parts, n, dims, str(p.name).hash())
  "board": board_components(parts, dims)
  "gpu": card_hardware(parts, n, dims, p)
  "ram": memory_components(parts, n, p)
  "ssd": drive_components(parts)
  "case": chassis_fittings(parts, n, dims)
  "cooler": cooler_fittings(parts, n, dims, p)
  "psu": supply_fittings(parts, n, dims, int(p.get("watts", 500)))
 parts.finish_mesh(n)

# Locate the actual skin under a fitting. GPU backplates and CPU lids vary
# between profiles. The meshes may already have been scaled to fit the case.
func face_z(n: Node3D, point: Vector2, front: bool, fallback: float) -> float:
 var z := -INF if front else INF
 for child in n.get_children():
  if child is MeshInstance3D and child.mesh:
   var bounds: AABB = child.transform * child.get_aabb()
   if point.x >= bounds.position.x and point.x <= bounds.end.x and point.y >= bounds.position.y and point.y <= bounds.end.y:
    z = maxf(z, bounds.end.z) if front else minf(z, bounds.position.z)
 return fallback if is_inf(z) else z

func solder_pair(f: Fittings, at: Vector3, size: float):
 f.block(at, Vector3(size*2.4,size,size*0.55), BRUSHED_ALUMINUM)
 f.block(at+Vector3(0,0,size*0.16), Vector3(size*1.45,size*1.02,size*0.65), CERAMIC)

func processor_marks(f: Fittings, n: Node3D, s: Vector3, serial: int):
 var at := Vector2(-s.x*0.235, s.y*0.245)
 var z := face_z(n, at, true, s.z)+0.000045
 var pitch := s.x*0.013
 for y in 7:
  for x in 7:
   if x == 0 or y == 0 or ((serial >> ((x*5+y*3)%30)) & 1):
    f.block(Vector3(at.x+x*pitch, at.y+y*pitch, z), Vector3(pitch,pitch,0.000045), INK_BLACK)
 # Tiny decoupling capacitors sit on the substrate beside the heat spreader.
 for i in 6:
  var pt := Vector2(s.x*0.465, (i-2.5)*s.y*0.095)
  solder_pair(f, Vector3(pt.x,pt.y,face_z(n,pt,true,0.0005)+0.0002), 0.00056)

func board_components(f: Fittings, s: Vector3):
 # A surface-mounted controller with gull-wing leads and a pin-one marker.
 var at := Vector3(-s.x*0.21, -s.y*0.28, s.z/2+0.00025)
 for side in [-1,1]:
  for i in 10:
   var offset := (i-4.5)*0.00135
   f.block(at+Vector3(side*0.0085,offset,0), Vector3(0.004,0.00068,0.00045), BRUSHED_ALUMINUM)
   f.block(at+Vector3(offset,side*0.0085,0), Vector3(0.00068,0.004,0.00045), BRUSHED_ALUMINUM)
 f.block(at+Vector3(0,0,0.00115), Vector3(0.016,0.016,0.0022), INK_BLACK)
 f.block(at+Vector3(-0.0055,0.0055,0.00232), Vector3(0.0015,0.0015,0.00012), SILK)
 for i in 9:
  solder_pair(f, at+Vector3(0.015+(i%3)*0.0037,(i/3-1)*0.003,0.00025),0.00105)

func card_hardware(f: Fittings, n: Node3D, s: Vector3, profile: Dictionary):
 # Spring-screw collars and a stamped X-shaped GPU retention bracket.
 var center := Vector2(-s.x*0.12,0)
 var spacing := minf(s.y*0.225,s.x*0.12)
 var backing := face_z(n, center, false, -s.z/2)
 f.pose = Transform3D(Basis(Vector3.UP, PI),Vector3(center.x,center.y,backing-0.00015))
 for angle in [PI/4,-PI/4]:
  var mount_pose := f.pose
  f.pose = mount_pose.rotated_local(Vector3.BACK,angle)
  f.block(Vector3(0,0,0.00045),Vector3(spacing*2.82,0.005,0.0009),STEEL)
  f.pose = mount_pose
 for x in [-1,1]:
  for y in [-1,1]:
   var p := Vector3(x*spacing,y*spacing,0.0008)
   f.washer(p,0.0042,0.0014,0.0012,BRUSHED_ALUMINUM)
   f.block(p+Vector3(0,0,0.00075),Vector3(0.0042,0.00065,0.0003),INK_BLACK)

 # A screw-mounted badge on the outer edge shows the actual GPU and VRAM.
 # Detect the shroud at this cross-section after the base game's fitting pass.
 var z_slice := s.z*0.12
 var edge := -INF
 for child in n.get_children():
  if child is MeshInstance3D and child.mesh:
   var bounds: AABB = child.transform * child.get_aabb()
   if bounds.position.x<=0 and bounds.end.x>=0 and bounds.position.z<=z_slice and bounds.end.z>=z_slice:
    edge = maxf(edge,bounds.end.y)
 if is_inf(edge): edge=s.y*0.44
 var badge := Node3D.new()
 badge.name="BoardIdentification"
 badge.transform=Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(0,edge+0.00035,z_slice))
 n.add_child(badge)
 f.pose=badge.transform
 var width := s.x*0.56
 var height := minf(s.z*0.59,s.y*0.18)
 f.block(Vector3.ZERO,Vector3(width,height,0.0007),INK_BLACK)
 f.block(Vector3(-width*0.39,0,0.00042),Vector3(width*0.025,height*0.78,0.00015),GOLD)
 for side in [-1,1]:
  f.washer(Vector3(side*width*0.46,0,0.0004),minf(0.002,height*0.11),0.0006,0.0005,BRUSHED_ALUMINUM)
 var title := str(profile.name)
 ink(badge,title,Vector3(0,height*0.14,0.00055),minf(height*0.46,width*1.3/maxi(1,title.length())),"e0e5e8")
 var memory := str(profile.get("memory",""))
 if not memory.is_empty():
  ink(badge,memory,Vector3(0,-height*0.28,0.00055),minf(height*0.25,width*1.25/memory.length()),"b7c3bc")

func memory_components(f: Fittings, n: Node3D, profile: Dictionary):
 # The DIMM holder rotates when seated and can contain several sticks per kit.
 for stick in n.get_children():
  if not stick is Node3D or stick is VisualInstance3D: continue
  if stick.get_child_count()==0: continue
  f.pose = stick.transform
  for side in [-1,1]:
   for i in 8:
    solder_pair(f,Vector3((i-3.5)*0.0068,side*0.0106,0.00135),0.00085)
  for i in 4:
   f.washer(Vector3(-0.059+i*0.0022,0.008,0.0009),0.0008,0.00033,0.00018,GOLD,8)

  # Identification sticker on the reverse face, clear of the front branding.
  for side in stick.get_children():
   if not side is Node3D or side is VisualInstance3D or side.transform.basis.z.z > -0.7: continue
   f.pose = stick.transform * side.transform
   var at := Vector3(0.013,0.001,face_z(side,Vector2(0.013,0.001),true,0.0019)+0.00025)
   f.block(at,Vector3(0.044,0.011,0.0004),SILK)
   ink(side, "DDR%d  %d MT/s" % [int(profile.get("ddr",4)), int(profile.get("mts",0))],
    at+Vector3(0,0.0018,0.00024),0.0038,"222830")
   for i in 15:
    var width := 0.00045 + (i*7%3)*0.0002
    f.block(at+Vector3((i-7)*0.0022,-0.0026,0.00024),Vector3(width,0.0022,0.00008),INK_BLACK)
   break

func drive_components(f: Fittings):
 # The M.2 retaining eyelet and small passives occupy the exposed PCB edges.
 f.washer(Vector3(-0.0376,0,0.0014),0.00265,0.00145,0.00033,GOLD,18)
 for side in [-1,1]:
  for i in 11:
   solder_pair(f,Vector3((i-5)*0.0046,side*0.0100,0.00094),0.00064)
 # Back-side solder test points.
 f.pose=Transform3D(Basis(Vector3.UP,PI),Vector3(0,0,-0.00076))
 for i in 7:
  f.washer(Vector3(0.006+i*0.0033,-0.004,0),0.00105,0.00024,0.00015,GOLD,8)

func chassis_fittings(f: Fittings, n: Node3D, s: Vector3):
 # Attach tool-less thumb screws to the removable cable-side panel so they
 # follow its visibility. Panoramic cases use the rear chassis flange.
 var panel := n.get_node_or_null("CableSidePanel") as Node3D
 var rear := -s.z/2
 if panel:
  rear = panel.position.z
 var carrier := panel if panel else n
 var trim := Fittings.new()
 trim.pose=Transform3D(Basis(Vector3.UP,PI), Vector3.ZERO if panel else Vector3(0,0,rear))
 for x in [-1,1]:
  for y in [-1,1]:
   var at:=Vector3(x*(s.x*0.5-0.012), y*(s.y*0.5-0.014), 0.003)
   trim.washer(at,0.0046,0.001,0.0032,STEEL,12)
   trim.block(at+Vector3(0,0,0.0033),Vector3(0.0052,0.0009,0.00025),INK_BLACK)
 trim.finish_mesh(carrier)
 # Fastener heads in the vertical rear upright, visible with panels removed.
 for y in [-0.36,-0.14,0.14,0.36]:
  f.washer(Vector3(-s.x*0.5+0.008,s.y*y,s.z*0.5-0.0035),0.0031,0.001,0.0009,BRUSHED_ALUMINUM)

func cooler_fittings(f: Fittings, n: Node3D, s: Vector3, p: Dictionary):
 if p.get("radiator_mm",0)>0:
  # Fit around the base of the pump without obscuring the LCD or fan.
  var pump := n.get_node_or_null("LCDPump") as Node3D
  var body := pump if pump else n
  var z := face_z(body,Vector2.ZERO,false,-s.z/2)
  f.pose = Transform3D(Basis(Vector3.UP,PI),Vector3(0,0,z-0.0001))
  for x in [-1,1]:
   for y in [-1,1]:
    f.washer(Vector3(x*0.016,y*0.016,0),0.0036,0.0012,0.0006,STEEL)
  # Fine contact-plate machining lines.
  for i in 5:
   f.washer(Vector3.ZERO,0.003+i*0.0027,0.00285+i*0.0027,0.00005,CERAMIC,32)
 else:
  # Machined heat-pipe collars on the top of each fin stack.
  for x in [-1,1]:
   for y in [-1,0,1]:
    var pt := Vector2(x*s.x*0.19,y*s.y*0.29)
    var z := face_z(n,pt,true,s.z*0.465)
    f.washer(Vector3(pt.x,pt.y,z+0.0001),0.0034,0.0018,0.0008,BRUSHED_ALUMINUM)

func supply_fittings(f: Fittings, n: Node3D, s: Vector3, watts: int):
 # Stamped side-panel seam and ratings plate with a printed rail table.
 var at := Vector3(-s.x*0.13,-s.y*0.09,s.z/2+0.00016)
 var w := s.x*0.38
 var h := s.y*0.43
 f.block(at,Vector3(w,h,0.0003),INK_BLACK)
 for y in [-0.35,-0.09,0.28]:
  f.block(at+Vector3(0,y*h,0.00022),Vector3(w*0.83,0.00045,0.00012),SILK)
 ink(n, "%d W" % watts, at+Vector3(0,h*0.10,0.00033),h*0.28,"dfe4dc")
 ink(n, "DC OUTPUT", at+Vector3(0,-h*0.22,0.00033),h*0.135,"b5b9b1")
 for side in [-1,1]:
  f.washer(Vector3(s.x*0.44,side*s.y*0.40,s.z/2+0.00015),0.0028,0.001,0.0008,BRUSHED_ALUMINUM)
 var scale_width := w*clampf(watts/1400.0,0.18,0.83)
 f.block(at+Vector3(-w*0.415+scale_width/2,h*0.41,0.0002),Vector3(scale_width,h*0.06,0.00015),GOLD)

func cable_plug(parent: Node3D, socket: Transform3D, pins: Vector2i) -> Vector3:
 var end := super.cable_plug(parent,socket,pins)
 var f := Fittings.new()
 # Molded grip ribs sit on the terminal housing, parallel with the pin row.
 f.pose=socket
 var width := maxf(0.005,pins.x*0.0042)
 for i in 3:
  f.block(Vector3(0, pins.y*0.0021+0.0005,0.006+i*0.0025),
   Vector3(width*0.64,0.0012,0.0009),STEEL)
 f.finish_mesh(parent)
 return end
