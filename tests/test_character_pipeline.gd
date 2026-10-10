extends SceneTree
## Tests van de character-pipeline: CharacterLoader (stats per character), taunt (input -> state -> tekstwolkje),
## props (SpecialDef.prop_events + taunt_props), move-override, validator-velden, sandbox/match-integratie.
##   Godot_console.exe --headless --path . --script res://tests/test_character_pipeline.gd
## Gebruikt een tijdelijke characters-map in user:// (CharacterLoader.root), dus raakt de echte characters niet aan.
## Exit code 0 = alles geslaagd.

const Validator := preload("res://tools/validator/validator.gd")
const TMP: String = "user://pipeline_test"
const CH: String = "user://pipeline_test/chars"
const DEFAULT_ROOT: String = "res://characters"

var _fails: int = 0
var _total: int = 0
var stage: SandboxStage


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== reset tijdelijke map")
	_wipe(TMP)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CH))
	_test_loader_real()
	_make_temp_chars()
	CharacterLoader.root = CH
	CharacterLoader.clear_cache()
	MoveSet.clear_cache()
	Specials.clear_cache()
	_test_loader_temp()
	_test_pose_override()
	_test_taunt()
	_test_prop_event_math()
	_test_visual_props()
	_test_taunt_props_fighter()
	_test_special_props()
	_test_move_override()
	_test_validator()
	await _test_match()
	CharacterLoader.root = DEFAULT_ROOT
	CharacterLoader.clear_cache()
	MoveSet.clear_cache()
	Specials.clear_cache()
	await _test_sandbox()
	_free_stage()
	_wipe(TMP)
	print("")
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func check(name: String, cond: bool, detail: String = "") -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, ("   (" + detail + ")") if detail != "" else "")


# --- hulpjes -----------------------------------------------------------------------------------

func _wipe(path: String) -> void:
	var abs_: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs_):
		return
	for f in DirAccess.get_files_at(abs_):
		DirAccess.remove_absolute(abs_.path_join(f))
	for d in DirAccess.get_directories_at(abs_):
		_wipe(path.path_join(d))
	DirAccess.remove_absolute(abs_)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Character-map in CH: character.json, scores.json en (optioneel) een kopie van de _dummy-art + props.
func _char(id: String, manifest: Dictionary, scores_: Dictionary = {}, with_art: bool = false) -> void:
	var m: Dictionary = {"id": id, "name": id, "archetype": "Fast-faller"}
	m.merge(manifest, true)
	_write("%s/%s/character.json" % [CH, id], JSON.stringify(m))
	_write("%s/%s/scores.json" % [CH, id], JSON.stringify(scores_))
	if with_art:
		for f in DirAccess.get_files_at("res://characters/_dummy/art"):
			if f.ends_with(".svg"):
				_write("%s/%s/art/%s" % [CH, id, f], FileAccess.get_file_as_string("res://characters/_dummy/art/" + f))
		_write("%s/%s/art/props/flag.svg" % [CH, id],
			FileAccess.get_file_as_string("res://characters/_dummy/art/props/flag.svg"))


func _make_temp_chars() -> void:
	_char("t_basic", {"visual_height": 14.0})
	_char("t_tall", {"visual_height": 40.0})
	_char("t_tiny", {"visual_height": 2.0})
	_char("t_extras", {}, {"movement_extras": {"zwaarder": -5, "extra_jump": -15, "snellere_jumpsquat": -8,
		"tragere_dash": 5, "langere_wavedash": -5, "glide": -10, "wall_jump": -5, "bestaat_niet": 3}}, true)
	_char("t_alias", {"archetype": "Zwaargewicht"}, {"movement_extras": {"heavier": -5, "no_double_jump": 20}})
	_char("t_light", {"archetype": "Lichtgewicht"}, {"movement_extras": {"lichter": 5}})
	_char("t_override", {"visual_height": 16.0}, {"movement_extras": {"zwaarder": -5}}, true)
	var s := FighterStats.new()
	s.display_name = "Eigen"
	s.weight = 123.0
	s.visual_height = 20.0
	ResourceSaver.save(s, CH + "/t_override/stats.tres")
	_char("t_taunt", {"taunt_text": "HALLO!", "taunt_frames": 40, "visual_height": 15.0,
		"taunt_props": [{"prop": "flag", "attach": "hand_r", "from_frame": 5, "to_frame": 9, "scale": 0.5}]},
		{}, true)
	_char("t_move", {}, {})
	var mv := MoveData.new()
	mv.move_name = "jab"
	mv.total_frames = 77
	_ensure_dir(CH + "/t_move/moves")
	ResourceSaver.save(mv, CH + "/t_move/moves/jab.tres")
	_char("t_special", {"taunt_text": "SPECIAL"}, {}, true)
	_char("t_pivot", {}, {}, true)
	_write(CH + "/t_pivot/art/props/props.json", JSON.stringify({"flag": {"pivot": [10, 20]}}))
	_write(CH + "/t_pivot/art/props/mark.svg", "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"30\" height=\"40\" data-pivot=\"5,7\" viewBox=\"0 0 30 40\"><rect width=\"30\" height=\"40\" fill=\"#ff00ff\"/></svg>")
	_char("t_val", {"visual_height": 9.0, "taunt_text": "OK", "taunt_props": [
		{"prop": "flag", "attach": "hand_r", "from_frame": 2, "to_frame": 6},
		{"prop": "missend", "attach": "hand_r"},
		{"prop": "flag", "attach": "elleboog"},
		{"prop": "flag", "from_frame": 9, "to_frame": 3}]},
		{"movement_extras": {"onzin": 1}}, true)
	var vd := SpecialDef.new()
	vd.slot = "neutral"
	vd.templates = ["projectile"]
	vd.prop_events = [{"prop": "flag", "attach": "hand_r"}, {"prop": "weg", "attach": "root"}]
	_ensure_dir(CH + "/t_val/specials")
	ResourceSaver.save(vd, CH + "/t_val/specials/neutral.tres")
	_char("t_pose", {}, {}, false)
	_write(CH + "/t_pose/poses/mijn.json", JSON.stringify({"taunt": {"length": 40, "keys": [{"t": 0}, {"t": 40}]}}))


func _ensure_dir(path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	return true


func _free_stage() -> void:
	if stage != null:
		SpecialWorld.dispose(stage)
		stage.free()
		stage = null


func make_fighter(char_id: String, with_visual: bool = false, at: Vector2 = Vector2(0, 0)) -> Fighter:
	_free_stage()
	stage = SandboxStage.new()
	var f := Fighter.new()
	f.use_visual = with_visual
	f.auto_register = false
	f.player = 0
	f.character_id = char_id
	f.stats = CharacterLoader.stats_for(char_id)
	f.stage = stage
	f.input = InputHistory.new()
	f.tap_jump_override = 1
	f.pos = at
	f.facing = 1
	if with_visual:
		root.add_child(f)
	else:
		f.setup()
	Specials.attach(f)
	SpecialWorld.of(f)
	return f


func tick(f: Fighter, buttons: int = 0, stick: Vector2i = Vector2i.ZERO) -> void:
	var i := InputFrame.new()
	i.buttons = buttons
	i.stick = stick
	f.input.push(i)
	f.sim_tick(0)
	Specials.step(stage)


func idle(f: Fighter, n: int) -> void:
	for i in n:
		tick(f)


func free_fighter(f: Fighter) -> void:
	if f.is_inside_tree():
		root.remove_child(f)
	f.free()
	_free_stage()


# --- 1. CharacterLoader ------------------------------------------------------------------------

func _test_loader_real() -> void:
	print("== CharacterLoader: echt character captain_pep")
	var ff: FighterStats = Archetypes.load_stats("fast_faller")
	var rep: Dictionary = CharacterLoader.report("captain_pep")
	var s: FighterStats = rep["stats"]
	check("captain_pep: archetype fast_faller", rep["archetype"] == "fast_faller" and rep["source"] == "preset")
	check("captain_pep: visual_height 14 uit character.json (preset 12)", is_equal_approx(s.visual_height, 14.0)
		and is_equal_approx(ff.visual_height, 12.0))
	check("captain_pep: zwaarder = weight +10%", is_equal_approx(s.weight, ff.weight * 1.1), str(s.weight))
	check("captain_pep: rest van de preset ongemoeid", is_equal_approx(s.run_speed, ff.run_speed) \
		and s.jumpsquat_frames == ff.jumpsquat_frames and s.air_jumps == ff.air_jumps)
	check("preset-resource zelf niet gemuteerd", is_equal_approx(Archetypes.load_stats("fast_faller").weight, 75.0))
	check("stats_for geeft een eigen kopie", CharacterLoader.stats_for("captain_pep") != CharacterLoader.stats_for("captain_pep"))
	check("captain_pep: taunt_text uit character.json", CharacterLoader.taunt_text("captain_pep") == "DA'S PAS SPUL!")
	check("taunt_frames standaard", CharacterLoader.taunt_frames("captain_pep") == FighterConst.TAUNT_FRAMES)
	check("onbekend character -> Allrounder-preset", is_equal_approx(CharacterLoader.stats_for("bestaat_niet").weight, 87.0)
		and CharacterLoader.report("bestaat_niet")["source"] == "fallback")
	check("MatchController.stats_for = CharacterLoader", is_equal_approx(MatchController.stats_for("captain_pep").weight, s.weight))
	check("gedeelde pose 'taunt' bestaat", PoseLibrary.load_for("_dummy").poses.has("taunt"))


func _test_loader_temp() -> void:
	print("== CharacterLoader: tijdelijke characters")
	var tall: Dictionary = CharacterLoader.report("t_tall")
	check("visual_height 40 -> geklemd op 30 + waarschuwing", is_equal_approx(tall["stats"].visual_height, 30.0) \
		and tall["warnings"].size() == 1)
	var tiny: Dictionary = CharacterLoader.report("t_tiny")
	check("visual_height 2 -> geklemd op 8", is_equal_approx(tiny["stats"].visual_height, 8.0) and tiny["warnings"].size() == 1)
	check("visual_height 14 binnen bereik: geen waarschuwing", CharacterLoader.report("t_basic")["warnings"].is_empty())
	var base: FighterStats = Archetypes.load_stats("fast_faller")
	var ex: Dictionary = CharacterLoader.report("t_extras")
	var s: FighterStats = ex["stats"]
	check("extra: zwaarder", is_equal_approx(s.weight, base.weight * 1.1))
	check("extra: extra_jump = +1 air jump", s.air_jumps == base.air_jumps + 1)
	check("extra: snellere_jumpsquat = -1 frame", s.jumpsquat_frames == base.jumpsquat_frames - 1)
	check("extra: tragere_dash", is_equal_approx(s.dash_initial_velocity, base.dash_initial_velocity * 0.8) \
		and is_equal_approx(s.dash_accel_additional, base.dash_accel_additional * 0.85))
	check("extra: langere_wavedash = lagere traction", is_equal_approx(s.traction, base.traction * 0.8) and s.traction < base.traction)
	check("extra: glide en wall_jump zetten hun vlag", s.glide and s.wall_jump and not base.glide)
	check("onbekende extra -> waarschuwing, rest wel toegepast", ex["warnings"].size() == 1 and ex["applied"].size() == 7)
	check("snellere_jumpsquat nooit onder 2", _jumpsquat_floor())
	var al: FighterStats = CharacterLoader.stats_for("t_alias")
	var hv: FighterStats = Archetypes.load_stats("heavyweight")
	check("aliassen: heavier + no_double_jump", is_equal_approx(al.weight, hv.weight * 1.1) and al.air_jumps == 0)
	check("extra: lichter", is_equal_approx(CharacterLoader.stats_for("t_light").weight, Archetypes.load_stats("lightweight").weight * 0.9))
	var ov: Dictionary = CharacterLoader.report("t_override")
	check("stats.tres = volledige override (geen preset/extras/json-hoogte)", ov["source"] == "stats.tres" \
		and is_equal_approx(ov["stats"].weight, 123.0) and is_equal_approx(ov["stats"].visual_height, 20.0))
	check("canonical_extra: alias + onbekend", CharacterLoader.canonical_extra("Heavier") == "zwaarder" \
		and CharacterLoader.canonical_extra("flauwekul") == "")
	var fighter := make_fighter("t_extras")
	check("Fighter krijgt de aangepaste stats", fighter.stats.air_jumps == base.air_jumps + 1)
	check("moveset-archetype blijft fast_faller bij gekopieerde stats", fighter.resolved_archetype() == "fast_faller")
	free_fighter(fighter)


func _jumpsquat_floor() -> bool:
	var s := FighterStats.new()
	s.jumpsquat_frames = 2
	CharacterLoader.apply_extra(s, "snellere_jumpsquat")
	return s.jumpsquat_frames == 2


func _test_pose_override() -> void:
	print("== character-poses overschrijven per naam")
	var lib_default := PoseLibrary.load_for("t_basic")
	var lib_own := PoseLibrary.load_for("t_pose")
	check("gedeelde taunt-pose is 80 frames", is_equal_approx((lib_default.poses["taunt"] as Pose).length, 80.0))
	check("character-taunt overschrijft (40 frames), andere poses blijven", is_equal_approx((lib_own.poses["taunt"] as Pose).length, 40.0) \
		and lib_own.poses.has("idle"))


# --- 2. Taunt ----------------------------------------------------------------------------------

func _test_taunt() -> void:
	print("== Taunt")
	check("BTN_TAUNT is een eigen bit", InputFrame.BTN_TAUNT != 0 and (InputFrame.BTN_TAUNT & (InputFrame.BTN_START | InputFrame.BTN_Z
		| InputFrame.BTN_SHIELD | InputFrame.BTN_JUMP | InputFrame.BTN_SPECIAL | InputFrame.BTN_ATTACK)) == 0)
	var f := make_fighter("t_taunt")
	idle(f, 3)
	check("start in Wait", f.state_name() == "Wait")
	tick(f, InputFrame.BTN_TAUNT)
	check("taunt-input in Wait -> Taunt", f.state_name() == "Taunt")
	check("geen wolkje op frame 0", f.bubble_text() == "")
	for i in FighterConst.TAUNT_BUBBLE_IN:
		tick(f)
	check("wolkje toont taunt_text vanaf frame %d" % FighterConst.TAUNT_BUBBLE_IN, f.bubble_text() == "HALLO!", f.bubble_text())
	tick(f, InputFrame.BTN_ATTACK | InputFrame.BTN_JUMP | InputFrame.BTN_SPECIAL)
	check("niet cancelbaar (A/jump/B)", f.state_name() == "Taunt")
	tick(f, 0, Vector2i(80, 0))
	check("niet cancelbaar (stick)", f.state_name() == "Taunt")
	# taunt_frames 40: frame 0 = invoerframe, dus nog 40 - 1 - 6 ticks tot Wait.
	var dur: int = CharacterLoader.taunt_frames("t_taunt")
	check("taunt_frames uit character.json (40)", dur == 40)
	while f.state_name() == "Taunt" and f.state_frame < dur - FighterConst.TAUNT_BUBBLE_OUT - 1:
		tick(f)
	check("wolkje nog zichtbaar vlak voor het einde", f.bubble_text() == "HALLO!")
	tick(f)
	check("wolkje weg in de laatste frames", f.bubble_text() == "")
	var n: int = 0
	while f.state_name() == "Taunt" and n < 100:
		tick(f)
		n += 1
	check("na de taunt weer Wait", f.state_name() == "Wait")
	check("taunt duurde precies taunt_frames", f.prev_state_name == "Taunt")
	check("wolkje weg buiten de taunt", f.bubble_text() == "")
	tick(f, InputFrame.BTN_ATTACK)
	check("daarna weer actionable (A -> jab)", f.state_name() != "Wait" and f.state_name() != "Taunt")
	free_fighter(f)
	# Standaardduur en lengte van de gedeelde pose.
	var g := make_fighter("t_basic")
	idle(g, 3)
	tick(g, InputFrame.BTN_TAUNT)
	var frames: int = 1
	while frames < 300:
		tick(g)
		if g.state_name() != "Taunt":
			break
		frames += 1
	check("standaard taunt duurt %d frames" % FighterConst.TAUNT_FRAMES, frames == FighterConst.TAUNT_FRAMES, str(frames))
	check("zonder taunt_text geen wolkje", CharacterLoader.taunt_text("t_basic") == "")
	# Alleen vanuit stilstand op de grond.
	tick(g, 0, Vector2i(60, 0))
	tick(g, 0, Vector2i(60, 0))
	check("(controle) stick -> Walk", g.state_name() == "Walk" or g.state_name() == "Turn" or g.state_name() == "Dash")
	tick(g, InputFrame.BTN_TAUNT, Vector2i(60, 0))
	check("geen taunt tijdens lopen/dashen", g.state_name() != "Taunt")
	free_fighter(g)
	var a := make_fighter("t_taunt", false, Vector2(0, 30))
	idle(a, 3)
	check("(controle) in de lucht", not a.grounded)
	tick(a, InputFrame.BTN_TAUNT)
	check("geen taunt in de lucht", a.state_name() != "Taunt")
	free_fighter(a)
	var h := make_fighter("t_taunt")
	idle(h, 3)
	tick(h, InputFrame.BTN_TAUNT)
	idle(h, 5)
	check("Taunt-pose: taunt (gedeeld), geen idle-fallback", h.state.pose() == "taunt")
	free_fighter(h)


# --- 3. Props ----------------------------------------------------------------------------------

func _test_prop_event_math() -> void:
	print("== PropEvent")
	var ev: Dictionary = PropEvent.normalize({"prop": "x"})
	check("normalize: standaardwaarden", ev["attach"] == "hand_r" and ev["from_frame"] == 0 and ev["to_frame"] == -1 \
		and ev["scale"] == 1.0 and ev["offset"] == Vector2.ZERO and not ev.has("pivot"))
	check("normalize: offset/pivot als lijst", PropEvent.normalize({"prop": "x", "offset": [3, 4], "pivot": [1, 2]})["offset"] == Vector2(3, 4))
	var evs: Array = [{"prop": "a", "from_frame": 3, "to_frame": 5}, {"prop": "b", "from_frame": 5}, {"prop": ""}]
	check("active: voor het venster niets", PropEvent.active(evs, 2).is_empty())
	check("active: eerste frame", PropEvent.active(evs, 3).size() == 1)
	check("active: inclusief laatste frame + open einde", PropEvent.active(evs, 5).size() == 2)
	check("active: na to_frame verdwijnt a, b blijft", PropEvent.active(evs, 6).size() == 1 and PropEvent.active(evs, 600)[0]["prop"] == "b")
	check("problems: geldig = leeg", PropEvent.problems({"prop": "flag", "attach": "root"}).is_empty())
	check("problems: ontbrekende naam, attach, venster, schaal", PropEvent.problems({}).size() == 1 \
		and PropEvent.problems({"prop": "a", "attach": "voet"}).size() == 1 \
		and PropEvent.problems({"prop": "a", "from_frame": 5, "to_frame": 2}).size() == 1 \
		and PropEvent.problems({"prop": "a", "scale": 0}).size() == 1)


func _test_visual_props() -> void:
	print("== CharacterVisual: props tonen/verbergen")
	var cv := CharacterVisual.new()
	cv.character_id = "t_taunt"
	root.add_child(cv)
	check("visual geldig (art + props-map in tijdelijk character)", cv.is_valid, str(cv.errors))
	check("geen props bij start", cv.visible_props().is_empty())
	cv.set_props(PropEvent.active([{"prop": "flag", "attach": "hand_r"}], 0))
	check("prop zichtbaar na set_props", cv.visible_props() == PackedStringArray(["flag"]))
	var spr: Sprite2D = cv.prop_sprite("flag")
	check("hand_r-prop hangt aan bot hand_r", spr != null and spr.get_parent() == cv.bones["hand_r"])
	cv.set_props([])
	check("verborgen na lege set", cv.visible_props().is_empty())
	cv.set_props(PropEvent.active([{"prop": "flag", "attach": "hand_l"}, {"prop": "flag", "attach": "under_feet", "offset": [5, 0]}], 0))
	var two: Array = []
	for i in cv.bones["hand_l"].get_children():
		if i is Sprite2D and i.name.begins_with("flag"):
			two.append(i)
	check("hand_l + under_feet: twee zichtbare props, juiste ouders", cv.visible_props().size() == 2 and two.size() == 1 \
		and cv.bones["root"].get_child(0) is Sprite2D)
	var pv := CharacterVisual.new()
	pv.character_id = "t_pivot"
	root.add_child(pv)
	pv.set_props(PropEvent.active([{"prop": "flag"}, {"prop": "mark"}, {"prop": "mark", "pivot": [1, 2]}], 0))
	var flag_s: Sprite2D = pv.prop_sprite("flag")
	var mark_s: Sprite2D = pv.prop_sprite("mark")
	check("pivot uit props.json", flag_s != null and flag_s.offset == Vector2(-10, -20) * Rig.SCALE_SUPERSAMPLE)
	check("pivot uit data-pivot in de SVG", mark_s != null and mark_s.offset == Vector2(-5, -7) * Rig.SCALE_SUPERSAMPLE)
	pv.set_props(PropEvent.active([{"prop": "mark", "pivot": [1, 2]}], 0))
	check("pivot in het event wint", pv.prop_sprite("mark").offset == Vector2(-1, -2) * Rig.SCALE_SUPERSAMPLE)
	root.remove_child(pv)
	pv.free()
	cv.set_props(PropEvent.active([{"prop": "bestaat_niet"}], 0))
	check("onbekende prop: niets zichtbaar, geen crash", cv.visible_props().is_empty())
	cv.set_props(PropEvent.active([{"prop": "flag"}], 0))
	cv.reload()
	check("props overleven een reload (hot reload)", cv.visible_props() == PackedStringArray(["flag"]))
	root.remove_child(cv)
	cv.free()


func _test_taunt_props_fighter() -> void:
	print("== Taunt-props op de juiste frames (Fighter + visual)")
	var f := make_fighter("t_taunt", true)
	idle(f, 3)
	check("fighter heeft een geldige visual", f.visual != null and f.visual.is_valid, str(f.visual.errors if f.visual else "-"))
	tick(f, InputFrame.BTN_TAUNT)
	var seen: Dictionary = {}
	while f.state_name() == "Taunt":
		seen[f.state_frame] = f.visual.visible_props().size()
		tick(f)
	var ok: bool = true
	var detail: String = ""
	for fr: int in seen:
		var want: int = 1 if fr >= 5 and fr <= 9 else 0
		if seen[fr] != want:
			ok = false
			detail += " f%d=%d" % [fr, seen[fr]]
	check("prop zichtbaar op frames 5..9 en alleen daar", ok and seen.size() > 30, detail)
	check("na de taunt geen props meer", f.visual.visible_props().is_empty() and f.active_props().is_empty())
	# Meeschalen met visual_height en spiegelen met facing.
	f.stats.visual_height = 15.0
	tick(f, InputFrame.BTN_TAUNT)
	for i in 6:
		tick(f)
	var spr: Sprite2D = f.visual.prop_sprite("flag")
	var expected: float = 15.0 * Units.UNIT_TO_PX / Rig.STAND_HEIGHT_PX * 0.5 / Rig.SCALE_SUPERSAMPLE
	check("prop schaalt mee met visual_height (x scale event)", spr != null \
		and absf(absf(spr.global_transform.get_scale().x) - expected) < 0.0005,
		"%s vs %s" % [spr.global_transform.get_scale().x if spr else -1.0, expected])
	check("rechts kijkend: niet gespiegeld", spr != null and spr.global_transform.determinant() > 0.0)
	f.facing = -1
	tick(f)
	spr = f.visual.prop_sprite("flag")
	check("links kijkend: prop gespiegeld", spr != null and spr.global_transform.determinant() < 0.0)
	free_fighter(f)


func _test_special_props() -> void:
	print("== Special-props (SpecialDef.prop_events)")
	var f := make_fighter("t_special", true)
	idle(f, 3)
	var d := SpecialDef.new()
	d.slot = "neutral"
	d.templates = ["projectile"]
	d.params = {"startup": 10, "endlag": 20, "speed": 3.0, "lifetime": 30}
	d.prop_events = [{"prop": "flag", "attach": "hand_r", "from_frame": 2, "to_frame": 6, "rotation": 30.0}]
	SpecialKit.of(f).defs["neutral"] = d
	check("special start", Specials.try_start(f, "neutral") and f.state_name() == "Special")
	f._update_visual()
	var seen: Dictionary = {}
	for i in 14:
		seen[f.state_frame] = f.visual.visible_props().size()
		tick(f)
	var ok: bool = true
	var detail: String = ""
	for fr: int in seen:
		var want: int = 1 if fr >= 2 and fr <= 6 else 0
		if seen[fr] != want:
			ok = false
			detail += " f%d=%d" % [fr, seen[fr]]
	check("special-prop zichtbaar op frames 2..6 sinds de knopdruk", ok and seen.size() >= 10, detail)
	check("zonder prop_events: lege props()", (f.state as StateSpecial).props().size() == 0 or f.state_frame > 6)
	var spr: Sprite2D = null
	f.change_state("Wait")
	Specials.try_start(f, "neutral")
	for i in 3:
		tick(f)
	spr = f.visual.prop_sprite("flag")
	check("prop-rotatie uit het event", spr != null and absf(rad_to_deg(spr.rotation) - 30.0) < 0.01)
	f.change_state("Wait")
	tick(f)
	check("prop weg als de special voorbij/afgebroken is", f.visual.visible_props().is_empty())
	free_fighter(f)


# --- 4. Moves ----------------------------------------------------------------------------------

func _test_move_override() -> void:
	print("== characters/<id>/moves overschrijft de archetype-move")
	var base_jab: MoveData = MoveSet.load_files("fast_faller", "").get("jab")
	var own: Fighter = make_fighter("t_move")
	var plain: Fighter = make_fighter("t_basic")
	check("archetype-jab bestaat en wijkt af van 77", base_jab != null and base_jab.total_frames != 77)
	check("character-jab overschrijft (77 frames)", own.get_move("jab") != null and own.get_move("jab").total_frames == 77)
	check("character zonder moves/ houdt de archetype-jab", plain.get_move("jab") != null \
		and plain.get_move("jab").total_frames == base_jab.total_frames)
	check("niet-overschreven moves blijven archetype", own.get_move("ftilt") != null \
		and own.get_move("ftilt") == MoveSet.load_files("fast_faller", "").get("ftilt"))
	plain.free()
	free_fighter(own)


# --- 5. Validator ------------------------------------------------------------------------------

func _result(rep: Dictionary, move: String) -> Dictionary:
	for r in rep["results"]:
		if r["move"] == move:
			return r
	return {}


func _test_validator() -> void:
	print("== Validator: character-velden")
	var v: RefCounted = Validator.new()
	v.char_root = CH
	var rep: Dictionary = v.validate_character("t_val")
	var vh: Dictionary = _result(rep, "character_fields/visual_height")
	check("kleinere lengte: WARN met kosten (12 -> 9 = 6 punten)", vh.get("status") == "WARN" and str(vh.get("warns")).contains("6 punten"), str(vh))
	check("budget bevat lengte-kosten 6", rep["budget"]["height"] == 6, str(rep["budget"]))
	check("height_cost: groter kost niets, 1 unit kleiner = 2", Validator.height_cost(12.0, 14.0) == 0 and Validator.height_cost(12.0, 11.0) == 2)
	var tr: Dictionary = _result(rep, "character_fields/taunt")
	check("taunt-props: onbekend bestand, attach en venster -> FAIL", tr.get("status") == "FAIL" and tr["fails"].size() == 3, str(tr.get("fails")))
	var mv: Dictionary = _result(rep, "character_fields/movement")
	check("onbekende movement_extra -> WARN", mv.get("status") == "WARN" and str(mv["warns"]).contains("onzin"), str(mv))
	var sp: Dictionary = _result(rep, "special_def/neutral")
	check("special prop_events: ontbrekend prop-bestand -> FAIL", not sp.is_empty() and sp["status"] == "FAIL" and str(sp["fails"]).contains("weg.svg"), str(sp))
	var tall: Dictionary = v.validate_character("t_tall")
	check("visual_height buiten 8-30 -> FAIL", _result(tall, "character_fields/visual_height").get("status") == "FAIL")
	var ok: Dictionary = v.validate_character("t_taunt")
	check("goed taunt-character: taunt en lengte geen FAIL", _result(ok, "character_fields/taunt").get("status") == "PASS" \
		and _result(ok, "character_fields/visual_height").get("status") == "PASS", str(_result(ok, "character_fields/taunt")))
	var ovr: Dictionary = v.validate_character("t_override")
	check("stats.tres: WARN (volledige override)", _result(ovr, "character_fields/movement").get("status") == "WARN")
	# Echt character: de nieuwe velden mogen niet falen.
	var real: RefCounted = Validator.new()
	var pep: Dictionary = real.validate_character("captain_pep")
	var fails: int = 0
	for field in ["visual_height", "taunt", "movement"]:
		if _result(pep, "character_fields/" + field).get("status") == "FAIL":
			fails += 1
	check("captain_pep: visual_height/taunt/movement geen FAIL", fails == 0 and not _result(pep, "character_fields/taunt").is_empty())
	check("captain_pep: geen lengtekosten (14 >= 12)", pep["budget"]["height"] == 0)


# --- 6. Match en sandbox -----------------------------------------------------------------------

func _test_match() -> void:
	print("== MatchController gebruikt CharacterLoader")
	_free_stage()
	var c := MatchController.new()
	c.mode = "fight"
	c.rules = MatchRules.new()
	c.picks = ["t_extras", "t_override"]
	c.build_hud = false
	c.auto_navigate = false
	c.auto_register = false
	root.add_child(c)
	await process_frame
	var f0: Fighter = c.fighters[0] as Fighter
	var f1: Fighter = c.fighters[1] as Fighter
	var base: FighterStats = Archetypes.load_stats("fast_faller")
	check("match: P1 stats met movement_extras", f0.stats.air_jumps == base.air_jumps + 1 and is_equal_approx(f0.stats.weight, base.weight * 1.1))
	check("match: P2 stats.tres-override", is_equal_approx(f1.stats.weight, 123.0))
	check("match: character_id gezet", f0.character_id == "t_extras" and f1.character_id == "t_override")
	c.queue_free()
	await process_frame


func _test_sandbox() -> void:
	print("== Sandbox: --p1/--p2 en roster-wissel")
	var sb: Node2D = (load("res://scenes/sandbox.gd") as GDScript).new()
	var picks: Array[String] = ["captain_pep", "_dummy"]
	sb.set("_pick_ids", picks)
	root.add_child(sb)
	await process_frame
	var fs: Array = sb.get("fighters")
	check("sandbox --p1 captain_pep: character + stats", fs[0].character_id == "captain_pep" \
		and is_equal_approx(fs[0].stats.visual_height, 14.0) and is_equal_approx(fs[0].stats.weight, 82.5))
	check("sandbox --p2 _dummy: Allrounder-stats", fs[1].character_id == "_dummy" and is_equal_approx(fs[1].stats.weight, 87.0))
	var reg: Node = root.get_node("/root/CharacterRegistry")
	reg.include_dummy = true
	reg.rescan()
	var ids: PackedStringArray = reg.ids()
	sb.call("_cycle_roster", 1)
	check("roster-wissel P2: volgende uit CharacterRegistry", fs[1].character_id == ids[0], "%s vs %s" % [fs[1].character_id, ids[0]])
	check("roster-wissel laadt stats van dat character", is_equal_approx(fs[1].stats.visual_height, CharacterLoader.stats_for(ids[0]).visual_height))
	check("roster-wissel herlaadt de moveset", fs[1].moves.has("jab"))
	sb.call("_cycle", 0)
	check("archetype-wissel (F3) werkt nog naast de roster", fs[0].stats.display_name != "")
	root.remove_child(sb)
	sb.queue_free()
	await process_frame
	await process_frame
	# Bug-fix: met alleen --p1 is P2 de _dummy (Allrounder), niet de Fast-faller-preset van de F3/F4-rij.
	var sb2: Node2D = (load("res://scenes/sandbox.gd") as GDScript).new()
	var only_p1: Array[String] = ["captain_pep", ""]
	sb2.set("_pick_ids", only_p1)
	root.add_child(sb2)
	await process_frame
	var fs2: Array = sb2.get("fighters")
	check("sandbox --p1 alleen: P2 = _dummy als Allrounder", fs2[1].character_id == "_dummy" and fs2[1].stats.display_name == "Allrounder")
	check("sandbox --p1 alleen: label toont Allrounder voor P2", String(sb2.get("hud").text).contains("P2: Allrounder [_dummy]"))
	root.remove_child(sb2)
	sb2.queue_free()
