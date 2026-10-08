extends Node2D
## Sandbox: 2 fighters op de test-stage (scenes/sandbox_stage.gd) met een simpele volg-camera.
## F3 / F4 = archetype van speler 1 / 2 wisselen. F5 = beide respawnen. F1/F2/P/. via de debug overlay/Sim.
##
## Screenshot-modus (windowed, voor review):
##   Godot_console.exe --path . res://scenes/sandbox.tscn -- --screenshot C:/pad/shot.png [--frames 90] [--demo]
## --demo speelt een vaste inputreeks af (P1 dash + jump, P2 wavedash) i.p.v. controller-input.

const CAM_MARGIN_PX: float = 260.0
const CAM_MIN_ZOOM: float = 0.45
const CAM_MAX_ZOOM: float = 0.9

var stage: SandboxStage
var fighters: Array[Fighter] = []
var archetype_index: Array[int] = [0, 1]
var camera: Camera2D
var hud: Label

var _shot_path: String = ""
var _shot_frames: int = 90
var _demo: bool = false
var _demo_inputs: Array[InputHistory] = []
var _frames_seen: int = 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.13, 0.13, 0.17))
	_parse_args()
	stage = SandboxStage.new()
	add_child(stage)
	for p in 2:
		var f := Fighter.new()
		f.player = p
		f.stage = stage
		f.stats = Archetypes.load_stats(Archetypes.IDS[archetype_index[p]])
		f.pos = stage.get_spawn(p)
		f.facing = 1 if p == 0 else -1
		if _demo:
			var h := InputHistory.new()
			_demo_inputs.append(h)
			f.input = h
		add_child(f)
		fighters.append(f)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 14)
	hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	hud.position = Vector2(12, 680)
	layer.add_child(hud)
	_update_hud()
	_update_camera(true)
	var sim: Node = get_node_or_null("/root/Sim")
	if sim != null:
		sim.frame_advanced.connect(_on_frame)


func _parse_args() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	for i in a.size():
		match a[i]:
			"--screenshot":
				if i + 1 < a.size():
					_shot_path = a[i + 1]
			"--frames":
				if i + 1 < a.size():
					_shot_frames = int(a[i + 1])
			"--demo":
				_demo = true


func _on_frame(frame: int) -> void:
	_frames_seen += 1
	_update_camera(false)
	if _shot_path != "" and _frames_seen == _shot_frames:
		_save_shot()


## Demo-input: wordt vóór de sim-tick gepusht (Sim sampled eerst InputManager, dan de entities;
## onze eigen InputHistory vullen we in _physics_process, dat vóór Sim draait want de sandbox staat
## lager in de boom dan de autoloads -> we pushen voor het VOLGENDE frame; deterministisch genoeg voor een demo).
func _physics_process(_delta: float) -> void:
	if not _demo:
		return
	var t: int = _frames_seen
	for p in 2:
		var fr := InputFrame.new()
		if p == 0:
			if t >= 10 and t < 40:
				fr.stick = Vector2i(80, 0)
			if t >= 40 and t < 44:
				fr.buttons |= InputFrame.BTN_JUMP
		else:
			if t >= 20 and t < 24:
				fr.buttons |= InputFrame.BTN_JUMP
			if t >= 23:
				fr.stick = Vector2i(-76, -25)
			if t >= 23 and t < 25:
				fr.buttons |= InputFrame.BTN_SHIELD
		_demo_inputs[p].push(fr)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F3:
				_cycle(0)
			KEY_F4:
				_cycle(1)
			KEY_F5:
				for f in fighters:
					f.spawn(stage.get_spawn(f.player), 1 if f.player == 0 else -1)
					f._update_visual()


func _cycle(p: int) -> void:
	archetype_index[p] = (archetype_index[p] + 1) % Archetypes.IDS.size()
	fighters[p].set_stats(Archetypes.load_stats(Archetypes.IDS[archetype_index[p]]))
	_update_hud()


func _update_hud() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for f in fighters:
		parts.append("P%d: %s (%s)" % [f.player + 1, f.stats.display_name, f.stats.reference.get_slice(" ", 0)])
	hud.text = "%s     F3/F4 = archetype wisselen, F5 = reset, F1 = overlay, F2 = ECB, P = pauze, . = frame" % "   ".join(parts)


func _update_camera(snap: bool) -> void:
	if fighters.is_empty():
		return
	var r := Rect2(fighters[0].position, Vector2.ZERO)
	for f in fighters:
		r = r.expand(f.position)
		r = r.expand(f.position + Vector2(0, -160))
	r = r.grow(CAM_MARGIN_PX)
	var vp: Vector2 = get_viewport_rect().size
	var z: float = clampf(minf(vp.x / r.size.x, vp.y / r.size.y), CAM_MIN_ZOOM, CAM_MAX_ZOOM)
	var goal_pos: Vector2 = r.get_center()
	if snap:
		camera.position = goal_pos
		camera.zoom = Vector2(z, z)
	else:
		camera.position = camera.position.lerp(goal_pos, 0.12)
		camera.zoom = camera.zoom.lerp(Vector2(z, z), 0.06)


func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(_shot_path)
	if err != OK:
		printerr("sandbox: screenshot opslaan mislukt: ", error_string(err))
	else:
		print("sandbox: screenshot -> ", _shot_path)
	for f in fighters:
		print("  ", f, ": ", f.get_debug_state_name())
	get_tree().quit(0 if err == OK else 1)
