extends SceneTree
## Headless test voor het SVG-rig (engine/visual). Draaien:
##   Godot_console.exe --headless --path . --script res://tests/test_visual.gd
## (Renderen kan headless niet, maar laden, poses en foutafhandeling wel.)

var _fails: int = 0
var _total: int = 0


func _initialize() -> void:
	_test_pose_math()
	_test_library()
	_test_attack_poses()
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


const ATTACK_POSES: Array = [
	"atk_jab1", "atk_jab2", "atk_jab3", "atk_jab_rapid", "atk_ftilt", "atk_utilt", "atk_dtilt", "atk_dash_attack",
	"atk_fsmash", "atk_fsmash_charge", "atk_usmash", "atk_usmash_charge", "atk_dsmash", "atk_dsmash_charge",
	"atk_nair", "atk_fair", "atk_bair", "atk_uair", "atk_dair",
	"atk_grab", "atk_grab_dash", "atk_grab_hold", "atk_pummel", "atk_fthrow", "atk_bthrow", "atk_uthrow", "atk_dthrow",
	"atk_special_projectile", "atk_special_charge", "atk_special_release", "atk_special_rise", "atk_special_dash",
	"atk_special_counter", "atk_special_counter_strike", "atk_special_spin", "atk_special_slash", "atk_special_stall", "atk_special_stall_fall",
]
const COMBAT_POSES: Array = [
	"shield", "shield_stun", "roll_forward", "roll_back", "spotdodge", "cliff_catch", "cliff_wait", "cliff_getup",
	"cliff_roll", "cliff_attack", "cliff_jump", "teeter", "respawn_platform", "damage_low", "damage_mid", "damage_high",
	"damage_fly", "tumble", "tech", "tech_roll", "missed_tech_lie", "missed_tech_lie_down", "getup_from_lie",
	"shield_break_dizzy", "grabbed", "thrown",
]


func _test_attack_poses() -> void:
	var lib := PoseLibrary.load_for("_dummy")
	check("pose-library (aanval/combat) zonder fouten", lib.errors.is_empty())
	var valid: Dictionary = {}
	for def: Array in Rig.BONES:
		valid[def[0]] = true
	var all_bones_ok: bool = true
	var marks_ok: bool = true
	var timed_ok: bool = true
	var names: Array = ATTACK_POSES + COMBAT_POSES
	for n: String in names:
		check("pose bestaat: " + n, lib.poses.has(n))
		if not lib.poses.has(n):
			continue
		var p: Pose = lib.poses[n]
		for b: String in p.bones:
			if not valid.has(b):
				all_bones_ok = false
				print("  onbekend bot '%s' in %s" % [b, n])
		if p.mark_active >= 0.0:
			if not (p.mark_active > 0.0 and p.mark_active < p.mark_end and p.mark_end <= p.length):
				marks_ok = false
				print("  ongeldige marks in ", n)
			# remap: 0 -> 0, startup -> mark_active, startup+active -> mark_end, total -> length, monotoon
			var prev: float = -1.0
			for t in range(0, 61):
				var v: float = p.remap(float(t), 7.0, 3.0, 60.0)
				if v < prev - 0.0001:
					timed_ok = false
				prev = v
			if not (is_equal_approx(p.remap(0.0, 7.0, 3.0, 60.0), 0.0) and is_equal_approx(p.remap(7.0, 7.0, 3.0, 60.0), p.mark_active) 					and is_equal_approx(p.remap(10.0, 7.0, 3.0, 60.0), p.mark_end) and is_equal_approx(p.remap(60.0, 7.0, 3.0, 60.0), p.length)):
				timed_ok = false
				print("  remap-ankers kloppen niet in ", n)
	check("alle aanval/combat-poses gebruiken geldige botten", all_bones_ok)
	check("marks: 0 < active < end <= length", marks_ok)
	check("remap: ankers kloppen en is monotoon", timed_ok)
	# poses zonder marks schalen uniform
	var u := Pose.from_dict("u", {"length": 10, "keys": [{"t": 0}, {"t": 10}]})
	check("remap zonder marks = uniform", is_equal_approx(u.remap(15.0, 5.0, 2.0, 30.0), 5.0))
	# expliciete marks
	var m := Pose.from_dict("m", {"length": 20, "marks": {"active": 4, "end": 8}, "keys": [{"t": 0}, {"t": 20}]})
	check("remap: startup-fase", is_equal_approx(m.remap(5.0, 10.0, 5.0, 40.0), 2.0))
	check("remap: active-fase", is_equal_approx(m.remap(12.5, 10.0, 5.0, 40.0), 6.0))
	check("remap: endlag-fase", is_equal_approx(m.remap(27.5, 10.0, 5.0, 40.0), 14.0))
	# combat/attack-poses die moeten loopen
	for n in ["atk_fsmash_charge", "atk_grab_hold", "atk_jab_rapid", "atk_special_charge", "atk_special_spin", "shield", "tumble", "cliff_wait", "teeter", "grabbed"]:
		check("loop: " + n, lib.poses.has(n) and lib.poses[n].loop)
	# play_timed op een echte visual
	var cv := CharacterVisual.new()
	cv.character_id = "_dummy"
	root.add_child(cv)
	cv.reload()
	cv.play_timed("atk_fsmash", 12, 4, 50)
	check("play_timed zet de pose", cv.current_pose == "atk_fsmash")
	var fp: Pose = lib.poses["atk_fsmash"]
	cv.tick(12)
	check("play_timed: eerste actieve frame = mark_active", is_equal_approx(cv.pose_frame, fp.mark_active))
	cv.tick(16)
	check("play_timed: einde active = mark_end", is_equal_approx(cv.pose_frame, fp.mark_end))
	cv.tick(50)
	check("play_timed: totaal = length", is_equal_approx(cv.pose_frame, fp.length))
	var r1: float = cv.bones["upper_arm_r"].rotation
	cv.tick(50)
	check("play_timed is deterministisch", is_equal_approx(r1, cv.bones["upper_arm_r"].rotation))
	cv.play("idle")
	cv.tick(7)
	check("play() na play_timed schakelt de schaling uit", is_equal_approx(cv.pose_frame, 7.0))
	cv.queue_free()


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
