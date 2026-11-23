extends Control
## Browser adapter. The packaged workbench owns the wallet, compatibility,
## inventory, tasks, persistence and the 3D scene.
var game
var viewer: SubViewportContainer
var bridge
var on_action
var next_update := 0.0
var last_state := ""
var parts_cache: Array = []
var dirty_parts := true
var list_view := false

func _ready():
 get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 # Install the detailed subclass before the workbench preloads its stage.
 var stage_script: Script = preload("res://detail_stage.gd")
 if not stage_script.resource_path == "res://stage.gd":
  stage_script.take_over_path("res://stage.gd")
 game = load("res://Workbench.tscn").instantiate()
 add_child(game)
 viewer = game.stage.get_viewport().get_parent()
 viewer.reparent(self)
 viewer.custom_minimum_size = Vector2.ZERO
 viewer.stretch = true
 viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 game.hide()
 if OS.has_feature("web"):
  bridge = JavaScriptBridge.get_interface("window")
  on_action = JavaScriptBridge.create_callback(receive)
  bridge.forgeCommand = on_action
  list_view = DisplayServer.get_name() == "headless"
  if bridge.forgeMobile:
   Engine.max_fps = 30
   for lamp in game.stage.get_children():
    if lamp is Light3D: lamp.shadow_enabled = false
 update_ui()

func _process(delta):
 next_update -= delta
 if next_update <= 0:
  next_update = 0.45 if game.testing or game.benchmarking else 1.25
  update_ui()

func receive(args):
 if args.size() < 1: return
 var op = str(args[0])
 var arg = args[1] if args.size() > 1 else ""
 var value = args[2] if args.size() > 2 else 0
 match op:
  "orbit": game.stage.orbit(Vector2(arg,value)); return
  "pan": game.stage.pan(Vector2(arg,value)); return
  "zoom": game.stage.zoom(float(arg)); return
  "pick":
   var pt = Vector2(arg,value)*Vector2(game.stage.get_viewport().size)
   var event = InputEventMouseButton.new()
   event.button_index = MOUSE_BUTTON_LEFT
   event.position = pt
   event.pressed = true
   game.view_input(event)
  "reset": game.stage.reset_camera()
  "part":
   if game.part_buttons.has(str(arg)) and game.part_buttons[str(arg)].visible: game.select_part(str(arg))
  "installed":
   if list_view and str(arg) in game.rig.installed.values(): game.select_part(str(arg))
  "search":
   game.find_parts.text = str(arg)
   game.find_parts.text_changed.emit(str(arg))
  "button","select","tab","item","dismiss","confirm":
   var node = instance_from_id(int(str(arg)))
   if not is_instance_valid(node) or not game.is_ancestor_of(node): return
   match op:
    "button":
     if node is BaseButton and node.visible and not node.disabled: node.pressed.emit()
    "select":
     if node is OptionButton and int(value) >= 0 and int(value) < node.item_count:
      node.select(int(value))
      node.item_selected.emit(int(value))
    "item":
     if node is ItemList and int(value) >= 0 and int(value) < node.item_count:
      node.select(int(value))
      node.item_selected.emit(int(value))
    "tab":
     if node is TabContainer and int(value) >= 0 and int(value) < node.get_tab_count(): node.current_tab = int(value)
    "dismiss":
     if node is AcceptDialog and node.visible:
      node.hide()
      node.canceled.emit()
    "confirm":
     if node is AcceptDialog and node.visible:
      node.hide()
      node.confirmed.emit()
  "mode":
   var modes = [game.build_button,game.repair_button,game.school_button,game.order_button]
   if int(arg) in range(4): modes[int(arg)].pressed.emit()
 dirty_parts = true
 update_ui()
 call_deferred("update_ui")

func control_data(n) -> Dictionary:
 var base = {"id":str(n.get_instance_id()),"kind":"text","text":""}
 if n is OptionButton or n is ItemList or n is TabContainer:
  base.kind = "choice"
  base.op = "select" if n is OptionButton else ("item" if n is ItemList else "tab")
  base.choices = []
  if n is TabContainer:
   base.value = n.current_tab
   for i in n.get_tab_count(): base.choices.append(n.get_tab_title(i))
  else:
   base.value = n.selected if n is OptionButton else (-1 if n.get_selected_items().is_empty() else n.get_selected_items()[0])
   for i in n.item_count: base.choices.append(n.get_item_text(i))
  if n is OptionButton: base.disabled = n.disabled
 elif n is BaseButton:
  base.kind = "button"
  base.text = n.text
  base.disabled = n.disabled
 elif n is Label:
  base.text = n.text
 elif n is RichTextLabel:
  base.text = n.get_parsed_text()
 elif n is ProgressBar:
  base.kind = "progress"
  base.value = n.ratio
 return base

func visible_widgets(parent, result):
 for n in parent.get_children():
  if n is not Control or not n.visible: continue
  if n is TabContainer:
   result.append(control_data(n))
   if n.get_current_tab_control(): visible_widgets(n.get_current_tab_control(),result)
  elif n is Label or n is RichTextLabel or n is Button or n is ItemList or n is ProgressBar:
   var d = control_data(n)
   if d.kind == "choice" or d.kind == "progress" or not str(d.text).is_empty(): result.append(d)
  else:
   visible_widgets(n,result)

func visible_buttons(nodes) -> Array:
 var result=[]
 for node in nodes:
  if node.visible: result.append(control_data(node))
 return result

func dialog_state() -> Dictionary:
 for w in [game.checkout,game.spec_dialog,game.quiz,game.board_dialog,game.arena]:
  if not w.visible: continue
  var content=[]
  visible_widgets(w,content)
  if w == game.spec_dialog:
   for n in [game.source_button,game.dimension_source]:
    if n.visible and not content.any(func(d): return d.id == str(n.get_instance_id())): content.append(control_data(n))
  return {"id":str(w.get_instance_id()),"title":w.title,"message":w.dialog_text,
   "ok":w.get_ok_button().text,"cancel":w is ConfirmationDialog,"content":content}
 return {}

func update_ui():
 if bridge == null: return
 var info = make_state()
 var message = JSON.stringify(info)
 if message != last_state:
  last_state = message
  bridge.forgeReceive(message)

func make_state() -> Dictionary:
 if dirty_parts:
  parts_cache = []
  for id in game.part_buttons:
   var b = game.part_buttons[id]
   if b.visible:
    parts_cache.append([id,b.text])
  dirty_parts = false
 var offers=[]
 if game.offer_tray.visible:
  for key in ["new","used"]:
   offers.append({"name":game.offer_title[key].text,"caption":game.offer_caption[key].text,
    "controls":visible_buttons([game.offer_buy[key],game.offer_source[key]])})
 var job = []
 visible_widgets(game.task_label.get_parent().get_parent(),job)
 var bar = game.build_button.get_parent()
 var files = []
 for n in bar.get_children():
  if n is Button and n.text in ["保存","读档"]: files.append(control_data(n))
 var current_mode = [game.build_button,game.repair_button,game.school_button,game.order_button].map(func(n):return n.disabled or n.button_pressed)
 var inspect_actions = visible_buttons([game.inspect_button,game.preview_power,game.panel_button,game.cable_side_button,game.compare_size,game.lift_cover])
 var installed_parts = []
 if list_view:
  for id in game.rig.installed.values():
   var part_button = game.part_buttons.get(id)
   if part_button:
    installed_parts.append([id, part_button.text.get_slice("\n", 0)])
 return {"balance":game.balance_label.text,"count":game.count_label.text,"status":game.status_label.text,
  "title":game.view_title.text,"selection":game.selection_label.text,"selected":game.selected,
  "focused":game.focused,"installed":game.rig.installed,"installedParts":installed_parts,"mode":current_mode,"job":str(game.rig.job),
  "shelfTitle":game.shelf_title.text,"filter":control_data(game.part_kind),"market":game.market_filter,
  "tabs":visible_buttons(game.market_tabs.get_children()),"pack":control_data(game.build_pack) if game.build_pack.visible else {},
  "matches":game.match_count.text,"parts":parts_cache,"offers":offers,"camera":inspect_actions,
  "actions":visible_buttons([game.action,game.detail_button,game.undo_button]),"work":job,
  "dialog":dialog_state(),"file":files,"readout":game.readout.text,"stageLabel":game.stage_label.text}
