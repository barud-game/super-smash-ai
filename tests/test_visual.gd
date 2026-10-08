extends SceneTree
## Headless test voor het SVG-rig (engine/visual). Draaien:
##   Godot_console.exe --headless --path . --script res://tests/test_visual.gd
## (Renderen kan headless niet, maar laden, poses en foutafhandeling wel.)

var _fails: int = 0
var _total: int = 0


func _initialize() -> void:
	_test_pose_math()
	_test_library()
	_test_dummy()
	_test_missing_and_optional()
	print("")
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name)


func _test_pose_math() -> void:
	var p := Pose.from_dict("t", {"keys": [{"t": 0, "r": {"torso": 0}}, {"t": 10, "r": {"torso": 20}}]})
	check("pose lineair midden = 10", is_equal_approx(p.sample(5.0)["r"]["torso"], 10.0))
	check("pose houdt laatste key vast", is_equal_approx(p.sample(99.0)["r"]["torso"], 20.0))
	var l := Pose.from_dict("l", {"loop": true, "length": 8, "keys": [{"t": 0, "r": {"torso": 0}}, {"t": 4, "r": {"torso": 8}}]})
	check("loop wikkelt (t=8 == t=0)", is_equal_approx(l.sample(8.0)["r"]["torso"], l.sample(0.0)["r"]["torso"]))
	var d := Pose.from_dict("d", {"keys": [{"t": 0, "drop": 0.0}, {"t": 1, "drop": 24.0}]})
	var s: Dictionary = d.sample(1.0)
	check("drop 0 = rechte benen", absf(Pose.from_dict("z", {"keys": [{"t": 0, "drop": 0.0}]}).sample(0.0)["r"]["thigh_r"]) < 0.01)
	# voet moet na drop weer op de grond staan: hoogte heup->enkel = 63 - drop
	var th: float = deg_to_rad(-s["r"]["thigh_r"])
	var sh: float = deg_to_rad(s["r"]["shin_r"] + s["r"]["thigh_r"])
	var h: float = Rig.THIGH_LEN * cos(th) + Rig.SHIN_LEN * cos(sh)
	check("drop 24: enkelhoogte klopt (39)", absf(h - 39.0) < 0.1)
	check("drop 24: enkel onder heup", absf(Rig.THIGH_LEN * sin(th) - Rig.SHIN_LEN * sin(sh)) < 0.1)


func _test_library() -> void:
	var lib := PoseLibrary.load_for("_dummy")
	check("pose-library zonder fouten", lib.errors.is_empty())
	for n in ["idle", "walk", "dash", "run", "skid", "turn", "crouch", "jumpsquat", "jump", "fall", "fastfall", "jump_aerial", "airdodge", "land", "landfall", "wavedash"]:
		check("pose bestaat: " + n, lib.poses.has(n))


func _test_dummy() -> void:
	var cv := CharacterVisual.new()
	cv.character_id = "_dummy"
	root.add_child(cv)
	cv.reload()   # _ready loopt in --script-modus pas na _initialize
	check("dummy laadt zonder fouten", cv.is_valid)
	check("dummy: geen waarschuwingen (canvasmaten kloppen)", cv.warnings.is_empty())
	for part in ["head", "torso", "pelvis", "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]:
		check("sprite aanwezig: " + part, cv.sprites.has(part))
	check("optioneel cape aanwezig", cv.sprites.has("cape"))
	check("optioneel weapon afwezig", not cv.sprites.has("weapon"))
	cv.play("run")
	cv.tick(7)
	var a: float = cv.bones["thigh_r"].rotation
	cv.tick(7)
	check("tick(frame) is deterministisch", is_equal_approx(a, cv.bones["thigh_r"].rotation))
	cv.facing = -1
	check("facing -1 spiegelt", is_equal_approx(cv.get_node("Flip").scale.x, -1.0))
	cv.play("bestaat_niet")
	check("onbekende pose valt terug op idle", cv.current_pose == "idle")
	check("reload() geeft true", cv.reload())
	check("facing blijft na reload", cv.facing == -1)
	cv.player_index = 1
	check("speler-2 kleur geladen", cv.is_valid)
	check("recolor vervangt teamkleur", CharacterVisual.recolor("fill=\"#ff00ff\"", Rig.PLAYER_PALETTES[1]).contains("#3b7be5"))
	cv.queue_free()


func _test_missing_and_optional() -> void:
	var tmp: String = "user://rig_test_art"
	DirAccess.make_dir_recursive_absolute(tmp)
	var src: String = "res://characters/_dummy/art"
	for f in DirAccess.open(src).get_files():
		if f.get_extension() == "svg":
			DirAccess.copy_absolute(src.path_join(f), tmp.path_join(f))
	# weapon toevoegen (optioneel onderdeel)
	var w := FileAccess.open(tmp.path_join("weapon.svg"), FileAccess.WRITE)
	w.store_string("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"128\"><rect x=\"28\" y=\"20\" width=\"8\" height=\"100\" fill=\"#ff00ff\"/></svg>")
	w.close()
	var cv := CharacterVisual.new()
	cv.art_dir_override = tmp
	root.add_child(cv)
	cv.reload()
	check("weapon-slot laadt", cv.is_valid and cv.sprites.has("weapon"))
	# verplicht onderdeel weghalen
	DirAccess.remove_absolute(tmp.path_join("foot.svg"))
	var ok: bool = cv.reload()
	check("ontbrekend verplicht onderdeel -> reload() false", not ok)
	check("foutmelding noemt 'foot'", "; ".join(cv.errors).contains("foot"))
	cv.queue_free()
	for f in DirAccess.open(tmp).get_files():
		DirAccess.remove_absolute(tmp.path_join(f))
	DirAccess.remove_absolute(tmp)
