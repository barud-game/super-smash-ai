extends Node2D
## Sandbox: 2 fighters op de test-stage (scenes/sandbox_stage.gd) of de echte Eindpunt-stage, met de MatchCamera.
## F3 / F4 = archetype van speler 1 / 2 wisselen. F5 = beide respawnen. F6 = stage wisselen (stub / Eindpunt).
## F7 = KO-gedrag wisselen (auto-respawn op het platform / blijft weg tot F5). F1/F2/P/. via de debug overlay/Sim
## (F2 = hitboxes, hurtboxes en ECB). F8 = dummy-modus voor P2 (staat stil), F9 / F10 = % van P2 −/+ 10.
##
## Screenshot-modus (windowed, voor review):
##   Godot_console.exe --path . --position -20000,-20000 res://scenes/sandbox.tscn -- --screenshot C:/pad/shot.png [--frames 90 of 20,50,87] [--demo]
## --demo speelt een vaste inputreeks af (P1 dash + jump, P2 wavedash) i.p.v. controller-input.
## --stage eindpunt start direct op de echte stage.
## --demo-fight speelt een gevecht af (P1 short hop, fast fall + fair (C-stick) op P2; P2 staat stil), --hitboxes zet F2 aan,
## --p2-percent N zet het percentage van P2.
## --ledge-demo ID: P1 (archetype ID) valt naar de rechter ledge en hangt; P2 staat stil. De camera zoomt in op P1.
##   --ledge-option getup|roll|attack|jump|drop + --ledge-at N: die optie op frame N (standaard getup op 70).
##   --vh N: andere visual_height (8-30) voor die fighter.
##   Voorbeeld: ... -- --stage eindpunt --ledge-demo heavyweight --frames 40 --screenshot C:/tmp/hang.png
## --defense-demo shield|lightshield|grab|throw: shield-bubble, grab en throw (M4), zie _defense_demo_inputs().
## --p1 ID / --p2 ID: laad een echt character (characters/<ID>, bv. captain_pep) i.p.v. een archetype; stats via CharacterLoader.
## F11 / F12 = P1 / P2 door de echte roster (CharacterRegistry) wisselen. T / D-pad omhoog = taunt (P1).
## --taunt-demo: P1 taunt op frame 10 (tekstwolkje + taunt-props). Voorbeeld voor screenshots:
##   Godot_console.exe --path . --position -20000,-20000 res://scenes/sandbox.tscn -- --p1 _dummy --taunt-demo --frames 30,55 --screenshot C:/pad/taunt.png

const EINDPUNT_SCENE: String = "res://stages/eindpunt/eindpunt.tscn"

## SandboxStage (stub) of Stage (Eindpunt); beide hebben dezelfde minimale API.
var stage: Node2D
var use_eindpunt: bool = false
var fighters: Array[Fighter] = []
var archetype_index: Array[int] = [0, 1]
var camera: MatchCamera
var hud: Label

var _shot_path: String = ""
var _shot_frames: int = 90
## --frames 20,50,87: meerdere screenshots in één run (pad krijgt _f<frame>); leeg = alleen _shot_frames.
var _shot_list: Array[int] = []
var _demo: bool = false
var _demo_inputs: Array[InputHistory] = []
var _frames_seen: int = 0
var _demo_fight: bool = false
## --defense-demo shield|lightshield|grab|throw: zie _defense_demo_inputs().
var _defense_demo: String = ""
## --p1 / --p2: character-id per speler ("" = archetype).
var _pick_ids: Array[String] = ["", ""]
var roster_index: Array[int] = [-1, -1]
var _taunt_demo: bool = false
## --special-demo SLOT[:air]: P1 gebruikt die special (neutral/side/up/down; ":air" = eerst springen) op P2 (staat stil).
var _special_demo: String = ""
var _special_air: bool = false
var _p2_percent: float = 0.0
var _ledge_demo: String = ""
var _ledge_option: String = "getup"
var _ledge_at: int = 70
## --vh N: visual_height van de ledge-demo-fighter (0 = preset).
var _ledge_vh: float = 0.0
## F8: P2 krijgt een lege inputbron (staat stil).
var dummy_p2: bool = false
var vfx: VfxLayer


func _ready() -> void:
	Sim.debug_context = true
	RenderingServer.set_default_clear_color(Color(0.13, 0.13, 0.17))
	_parse_args()
	_build_stage()
	for p in 2:
		var f := Fighter.new()
		f.player = p
		f.stage = stage
		f.stats = Archetypes.load_stats(Archetypes.IDS[archetype_index[p]])
		if _pick_ids[p] != "":
			f.character_id = _pick_ids[p]
			f.stats = CharacterLoader.stats_for(_pick_ids[p])
		f.pos = stage.get_spawn(p)
		if _demo_fight:
			f.pos = Vector2(-14.0 if p == 0 else 2.0, 0.0)
		if _defense_demo != "":
			f.pos = Vector2(-8.0 if p == 0 else 2.0, 0.0)
		if _special_demo != "":
			f.pos = Vector2(-14.0 if p == 0 else -14.0 + _special_demo_gap(), 0.0)
		f.facing = 1 if p == 0 else -1
		if _ledge_demo != "" and p == 0:
			f.stats = Archetypes.load_stats(_ledge_demo)
			if _ledge_vh > 0.0:
				f.stats = f.stats.duplicate()
				f.stats.visual_height = _ledge_vh
			f.pos = _right_ledge() + Vector2(6.0, 10.0)
			f.facing = -1
		if _demo:
			var h := InputHistory.new()
			_demo_inputs.append(h)
			f.input = h
		add_child(f)
		fighters.append(f)
	fighters[1].percent = _p2_percent
	camera = MatchCamera.new()
	add_child(camera)
	camera.make_current()
	# VFX-laag op de wereldoorsprong; fighters vinden hem via `vfx` of groep "vfx_layer".
	vfx = VfxLayer.new()
	vfx.camera = camera
	vfx.add_to_group(&"vfx_layer")
	add_child(vfx)
	for f in fighters:
		f.vfx = vfx
	_setup_camera()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 14)
	hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	hud.position = Vector2(12, 680)
	layer.add_child(hud)
	_update_hud()
	fighters[1].percent_changed.connect(func(_v: float) -> void: _update_hud())
	var sim: Node = get_node_or_null("/root/Sim")
	if sim != null:
		sim.frame_advanced.connect(_on_frame)


func _exit_tree() -> void:
	var sim: Node = get_node_or_null("/root/Sim")
	if sim != null:
		sim.debug_context = false


func _parse_args() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	for i in a.size():
		match a[i]:
			"--screenshot":
				if i + 1 < a.size():
					_shot_path = a[i + 1]
			"--frames":
				if i + 1 < a.size():
					for part: String in a[i + 1].split(",", false):
						_shot_list.append(int(part))
					_shot_frames = _shot_list.max()
					if _shot_list.size() == 1:
						_shot_list.clear()
			"--demo":
				_demo = true
			"--demo-fight":
				_demo = true
				_demo_fight = true
			"--defense-demo":
				_demo = true
				if i + 1 < a.size():
					_defense_demo = a[i + 1]
			"--p1":
				if i + 1 < a.size():
					_pick_ids[0] = a[i + 1]
			"--p2":
				if i + 1 < a.size():
					_pick_ids[1] = a[i + 1]
			"--special-demo":
				_demo = true
				if i + 1 < a.size():
					var sp: PackedStringArray = a[i + 1].split(":")
					_special_demo = sp[0]
					_special_air = sp.size() > 1 and sp[1] == "air"
			"--taunt-demo":
				_demo = true
				_taunt_demo = true
			"--hitboxes":
				var sim: Node = get_node_or_null("/root/Sim")
				if sim != null:
					sim.debug_hitboxes = true
			"--p2-percent":
				if i + 1 < a.size():
					_p2_percent = float(a[i + 1])
			"--stage":
				if i + 1 < a.size():
					use_eindpunt = a[i + 1] == "eindpunt"
			"--ledge-demo":
				_demo = true
				if i + 1 < a.size():
					_ledge_demo = a[i + 1]
			"--ledge-option":
				if i + 1 < a.size():
					_ledge_option = a[i + 1]
			"--ledge-at":
				if i + 1 < a.size():
					_ledge_at = int(a[i + 1])
			"--vh":
				if i + 1 < a.size():
					_ledge_vh = float(a[i + 1])


func _on_frame(frame: int) -> void:
	_frames_seen += 1
	if _shot_path == "":
		return
	if _shot_list.has(_frames_seen):
		_save_shot(_shot_path.get_basename() + "_f%d.png" % _frames_seen, _frames_seen == _shot_frames)
	elif _shot_list.is_empty() and _frames_seen == _shot_frames:
		_save_shot(_shot_path, true)


## Demo-input: wordt vóór de sim-tick gepusht (Sim sampled eerst InputManager, dan de entities;
## onze eigen InputHistory vullen we in _physics_process, dat vóór Sim draait want de sandbox staat
## lager in de boom dan de autoloads -> we pushen voor het VOLGENDE frame; deterministisch genoeg voor een demo).
func _physics_process(_delta: float) -> void:
	if not _demo:
		return
	var t: int = _frames_seen
	if _demo_fight:
		_demo_fight_inputs(t)
		return
	if _taunt_demo:
		var tp1 := InputFrame.new()
		if t >= 10 and t < 12:
			tp1.buttons |= InputFrame.BTN_TAUNT
		_demo_inputs[0].push(tp1)
		_demo_inputs[1].push(InputFrame.new())
		return
	if _special_demo != "":
		_special_demo_inputs(t)
		return
	if _defense_demo != "":
		_defense_demo_inputs(t)
		return
	if _ledge_demo != "":
		_ledge_demo_inputs(t)
		return
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
			KEY_F11:
				_cycle_roster(0)
			KEY_F12:
				_cycle_roster(1)
			KEY_F5:
				for f in fighters:
					f.spawn(stage.get_spawn(f.player), 1 if f.player == 0 else -1)
					f._update_visual()
			KEY_F6:
				use_eindpunt = not use_eindpunt
				_build_stage()
				for f in fighters:
					f.stage = stage
					Specials.attach(f)
					f.spawn(stage.get_spawn(f.player), 1 if f.player == 0 else -1)
					f._update_visual()
				_setup_camera()
				_update_hud()
			KEY_F7:
				var auto: bool = not fighters[0].auto_respawn
				for f in fighters:
					f.auto_respawn = auto
				_update_hud()
			KEY_F8:
				dummy_p2 = not dummy_p2
				if not _demo:
					var im: Node = get_node_or_null("/root/InputManager")
					fighters[1].input = InputHistory.new() if dummy_p2 or im == null else im.history(1)
				_update_hud()
			KEY_F9:
				fighters[1].percent = maxf(fighters[1].percent - 10.0, 0.0)
				_update_hud()
			KEY_F10:
				fighters[1].percent = minf(fighters[1].percent + 10.0, 999.0)
				_update_hud()


func _cycle(p: int) -> void:
	archetype_index[p] = (archetype_index[p] + 1) % Archetypes.IDS.size()
	fighters[p].set_stats(Archetypes.load_stats(Archetypes.IDS[archetype_index[p]]))
	_update_hud()


## F11/F12: volgende character uit de echte roster (CharacterRegistry) voor speler p.
func _cycle_roster(p: int) -> void:
	var reg: Node = get_node_or_null("/root/CharacterRegistry")
	if reg == null or reg.ids().is_empty():
		return
	var ids: PackedStringArray = reg.ids()
	roster_index[p] = (roster_index[p] + 1) % ids.size()
	fighters[p].set_character(ids[roster_index[p]])
	_update_hud()


func _update_hud() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for f in fighters:
		parts.append("P%d: %s [%s] (%s)" % [f.player + 1, f.stats.display_name, f.character_id, f.stats.reference.get_slice(" ", 0)])
	hud.text = "%s   [%s, KO: %s, P2: %s %.0f%%]     F3/F4 = archetype, F11/F12 = character, T = taunt, F5 = reset, F6 = stage, F7 = KO-gedrag, F8 = dummy, F9/F10 = P2 %% -/+10, F1 = overlay, F2 = hitboxes, P = pauze, . = frame" % [
		"   ".join(parts), "Eindpunt" if use_eindpunt else "stub", "auto-respawn" if fighters[0].auto_respawn else "blijft weg",
		"dummy" if dummy_p2 else "speler", fighters[1].percent]


## (Her)bouwt de stage: SandboxStage-stub of de echte Eindpunt (engine/stage/stage.gd).
func _build_stage() -> void:
	if stage != null:
		SpecialWorld.dispose(stage)   # projectielen/traps van de oude stage weg
		remove_child(stage)
		stage.queue_free()
	if use_eindpunt:
		stage = (load(EINDPUNT_SCENE) as PackedScene).instantiate()
	else:
		stage = SandboxStage.new()
	add_child(stage)
	move_child(stage, 0)


func _setup_camera() -> void:
	var targets: Array[Node2D] = []
	for f in fighters:
		targets.append(f)
	if _ledge_demo != "":
		# Close-up van de hangende fighter (stage-rand in beeld).
		var mark := Node2D.new()
		mark.position = Units.to_px(_right_ledge() + Vector2(0.0, 6.0))
		add_child(mark)
		targets = [fighters[0], mark]
		camera.margin_units = 14.0
		camera.max_zoom = 3.0
	camera.set_targets(targets)
	camera.set_bounds_units(stage.get_camera_bounds())
	camera.snap_next()


func _save_shot(path: String, quit_after: bool) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(path)
	if err != OK:
		printerr("sandbox: screenshot opslaan mislukt: ", error_string(err))
	else:
		print("sandbox: screenshot -> ", path)
	for f in fighters:
		print("  ", f, ": ", f.get_debug_state_name())
	if quit_after or err != OK:
		get_tree().quit(0 if err == OK else 1)


## --defense-demo (M4), P1 op x=-8, P2 op x=2 (binnen grab-bereik):
##   shield      P2 houdt de shield (digitaal) vanaf frame 5; P1 ftilt op frame 30 (shieldstun + pushback).
##   lightshield idem met de trigger op 0.45 (grotere, lichtere bubble).
##   grab        P1 Z op frame 20 -> GrabHold/Grabbed; pummel op frame 40.
##   throw       P1 Z op frame 20, fthrow (stick vooruit) op frame 32.
func _defense_demo_inputs(t: int) -> void:
	var p1 := InputFrame.new()
	var p2 := InputFrame.new()
	match _defense_demo:
		"shield", "lightshield":
			if t >= 5:
				if _defense_demo == "shield":
					p2.buttons |= InputFrame.BTN_SHIELD
					p2.trigger_l = 1.0
				else:
					p2.trigger_l = 0.45
			if t == 30:
				p1.stick = Vector2i(40, 0)
				p1.buttons |= InputFrame.BTN_ATTACK
		"grab":
			if t == 20:
				p1.buttons |= InputFrame.BTN_Z
			if t == 40:
				p1.buttons |= InputFrame.BTN_ATTACK
		"throw":
			if t == 20:
				p1.buttons |= InputFrame.BTN_Z
			if t >= 32 and t < 36:
				p1.stick = Vector2i(80, 0)
	_demo_inputs[0].push(p1)
	_demo_inputs[1].push(p2)


## Afstand P1-P2 per special-demo.
func _special_demo_gap() -> float:
	match _special_demo:
		"neutral":
			return 10.0
		"side":
			return 45.0
		"up":
			return 8.0
	return 20.0


func _special_demo_inputs(t: int) -> void:
	var p1 := InputFrame.new()
	var t0: int = 24 if _special_air else 10
	if _special_air and t >= 5 and t < 8:
		p1.buttons |= InputFrame.BTN_JUMP
	if t >= t0:
		match _special_demo:
			"side":
				p1.stick = Vector2i(80, 0)
			"up":
				p1.stick = Vector2i(0, 80)
			"down":
				p1.stick = Vector2i(0, -80)
		if t < t0 + 2:
			p1.buttons |= InputFrame.BTN_SPECIAL
	_demo_inputs[0].push(p1)
	_demo_inputs[1].push(InputFrame.new())


## --demo-fight: P1 short hop + fair op P2 (P2 staat stil, eventueel op --p2-percent). Daarna niets.
func _demo_fight_inputs(t: int) -> void:
	var p1 := InputFrame.new()
	if t == 10:
		p1.buttons |= InputFrame.BTN_JUMP
	if t == 25:
		p1.cstick = Vector2i(80, 0)
	if t >= 27 and t < 30:
		p1.stick = Vector2i(0, -80)
	_demo_inputs[0].push(p1)
	_demo_inputs[1].push(InputFrame.new())


## Rechter ledge van de huidige stage (units).
func _right_ledge() -> Vector2:
	var best := Vector2(-INF, 0.0)
	for l: StageLedge in stage.get_ledges():
		if l.side > 0 and l.position.x > best.x:
			best = l.position
	return best if best.x > -INF else Vector2.ZERO


## --ledge-demo: P1 laat zich naar de ledge vallen; op frame _ledge_at de gekozen optie. P2 doet niets.
func _ledge_demo_inputs(t: int) -> void:
	var p1 := InputFrame.new()
	if t == _ledge_at:
		match _ledge_option:
			"getup":
				p1.stick = Vector2i(-80, 0)
			"roll":
				p1.buttons |= InputFrame.BTN_SHIELD
			"attack":
				p1.buttons |= InputFrame.BTN_ATTACK
			"jump":
				p1.buttons |= InputFrame.BTN_JUMP
			"drop":
				p1.stick = Vector2i(0, -80)
	_demo_inputs[0].push(p1)
	_demo_inputs[1].push(InputFrame.new())
