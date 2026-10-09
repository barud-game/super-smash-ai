extends SceneTree
## Headless test voor tools/validator (move-validatie, budget, OP-pad).
## Run: Godot --headless --path . --script res://tests/test_validator.gd

const Validator := preload("res://tools/validator/validator.gd")
const CT := preload("res://tools/validator/conversion_table.gd")

var _fails: int = 0
var _total: int = 0
var _v: RefCounted = Validator.new()


func _initialize() -> void:
	_test_table()
	_test_jab()
	_test_aerial()
	_test_throw_grab()
	_test_agreements()
	_test_sanity()
	_test_scores()
	_test_budget()
	_test_files()
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name)


func _hb(start: int, end: int, off: Vector2, r: float, d: float, b: float, g: float, ang: float = 361.0) -> HitboxData:
	var h := HitboxData.new()
	h.start_frame = start
	h.end_frame = end
	h.offset = off
	h.radius = r
	h.damage = d
	h.base_kb = b
	h.kb_growth = g
	h.angle = ang
	return h


func _md(total: int, hbs: Array, aerial: bool = false) -> MoveData:
	var m := MoveData.new()
	m.total_frames = total
	m.aerial = aerial
	m.grounded = not aerial
	for h in hbs:
		h.id = m.hitboxes.size()
		m.hitboxes.append(h)
	return m


func _jab() -> MoveData:
	# S4 K1 B2 V2: startup 3 (start_frame 2), active 3, r 3.0, R 12, d3/b8/g60, adv -14 -> endlag 17.
	return _md(22, [_hb(2, 4, Vector2(9, 8), 3.0, 3, 8, 60)])


func _fair() -> MoveData:
	# S3 K2 B3 V3: startup 7, active 6, r 3.5, R 20, d8/b20/g120, LL 20, LC 10, air_endlag 26.
	var m := _md(38, [_hb(6, 11, Vector2(16.5, 7.5), 3.5, 8, 20, 120)], true)
	m.landing_lag = 20
	m.lcancel_lag = 10
	m.autocancel_before = 5
	m.autocancel_after = 24
	return m


func _test_table() -> void:
	_check("tabel: shieldstun(4) = 3", CT.shieldstun(4) == 3)
	_check("tabel: alle rijen hebben 6 waarden", _rows_ok())
	_check("tabel: 18 normals", CT.NORMAL_MOVES.size() == 18)


func _rows_ok() -> bool:
	for tbl in [CT.STARTUP, CT.REACH, CT.ACTIVE, CT.DAMAGE, CT.BKB, CT.KBG, CT.ADV_TARGET]:
		for k in tbl:
			if tbl[k].size() != 6:
				return false
	return CT.RADIUS.size() == 6 and CT.THROW_TOTAL.size() == 6 and CT.LANDING_LAG.size() == 6


func _test_jab() -> void:
	var sc := {"S": 4, "K": 1, "B": 2, "V": 2}
	var r: Dictionary = _v.validate_move("t", "jab", _jab(), sc)
	_check("jab die klopt: PASS", r["status"] == "PASS")
	_check("jab gemeten startup 3", int(r["measured"]["startup"]) == 3)
	_check("jab gemeten shield-adv -14", int(r["measured"]["shield_adv"]) == -14)

	var slow := _jab()
	slow.hitboxes[0].start_frame = 5
	slow.hitboxes[0].end_frame = 7
	slow.total_frames = 25
	r = _v.validate_move("t", "jab", slow, sc)
	_check("jab te traag: FAIL op startup", r["status"] == "FAIL" and _has(r, "startup"))

	var weak := _jab()
	weak.hitboxes[0].damage = 9
	r = _v.validate_move("t", "jab", weak, sc)
	_check("jab te sterk: FAIL op damage", r["status"] == "FAIL" and _has(r, "damage"))

	var small := _jab()
	small.hitboxes[0].radius = 1.0
	r = _v.validate_move("t", "jab", small, sc)
	_check("jab te kleine radius: FAIL", r["status"] == "FAIL" and _has(r, "radius"))

	var unsafe := _jab()
	unsafe.total_frames = 40
	r = _v.validate_move("t", "jab", unsafe, sc)
	_check("jab te veel endlag: FAIL op shield-advantage", r["status"] == "FAIL" and _has(r, "shield-advantage"))

	var shortm := _jab()
	shortm.hitboxes[0].offset.x = 4.0
	r = _v.validate_move("t", "jab", shortm, sc)
	_check("jab te weinig reach: FAIL", r["status"] == "FAIL" and _has(r, "reach"))

	var long := _jab()
	long.hitboxes[0].end_frame = 9
	long.total_frames = 27
	r = _v.validate_move("t", "jab", long, sc)
	_check("jab te lang actief: FAIL", r["status"] == "FAIL" and _has(r, "active"))


func _test_aerial() -> void:
	var sc := {"S": 3, "K": 2, "B": 3, "V": 3}
	var r: Dictionary = _v.validate_move("t", "fair", _fair(), sc)
	_check("fair die klopt: PASS", r["status"] == "PASS")
	_check("fair gemeten landing lag 20", int(r["measured"]["landing_lag"]) == 20)

	var nolag := _fair()
	nolag.landing_lag = 0
	nolag.lcancel_lag = 0
	r = _v.validate_move("t", "fair", nolag, sc)
	_check("aerial zonder landing lag: FAIL", r["status"] == "FAIL" and _has(r, "landing"))

	var badlc := _fair()
	badlc.lcancel_lag = 15
	r = _v.validate_move("t", "fair", badlc, sc)
	_check("lcancel != floor(ll/2): FAIL", r["status"] == "FAIL" and _has(r, "lcancel"))

	var notair := _fair()
	notair.aerial = false
	r = _v.validate_move("t", "fair", notair, sc)
	_check("aerial-vlag uit: FAIL", r["status"] == "FAIL" and _has(r, "aerial=false"))

	var badac := _fair()
	badac.autocancel_before = 9
	r = _v.validate_move("t", "fair", badac, sc)
	_check("autocancel_before na hitbox-start: FAIL", r["status"] == "FAIL" and _has(r, "autocancel"))


func _test_throw_grab() -> void:
	var th := _md(41, [_hb(20, 20, Vector2(0, 8), 3.0, 3, 25, 85, 45)])
	th.grounded = true
	var r: Dictionary = _v.validate_move("t", "fthrow", th, {"S": 3, "K": 1})
	_check("fthrow die klopt: PASS", r["status"] == "PASS")
	var thbad := _md(60, [_hb(30, 30, Vector2(0, 8), 3.0, 3, 25, 85, 45)])
	r = _v.validate_move("t", "fthrow", thbad, {"S": 3, "K": 1})
	_check("fthrow totale duur fout: FAIL", r["status"] == "FAIL" and _has(r, "total"))
	var nothrow := _md(41, [])
	r = _v.validate_move("t", "fthrow", nothrow, {"S": 3, "K": 1})
	_check("throw zonder hitbox: FAIL", r["status"] == "FAIL" and _has(r, "geen hitboxen"))

	var g := _hb(6, 7, Vector2(9, 8), 3.0, 0, 0, 100)
	g.ignores_shield = true
	var gm := _md(31, [g])
	r = _v.validate_move("t", "grab", gm, {"S": 3, "B": 2})
	_check("grab die klopt: PASS", r["status"] == "PASS")
	g.ignores_shield = false
	r = _v.validate_move("t", "grab", gm, {"S": 3, "B": 2})
	_check("grab zonder ignores_shield: FAIL", r["status"] == "FAIL")


func _test_sanity() -> void:
	var sc := {"S": 4, "K": 1, "B": 2, "V": 2}
	var out := _jab()
	out.hitboxes[0].end_frame = 30
	var r: Dictionary = _v.validate_move("t", "jab", out, sc)
	_check("hitbox buiten move-duur: FAIL", r["status"] == "FAIL" and _has(r, "buiten move-duur"))
	var neg := _jab()
	neg.hitboxes[0].base_kb = -1.0
	r = _v.validate_move("t", "jab", neg, sc)
	_check("negatieve waarde: FAIL", r["status"] == "FAIL" and _has(r, "negatieve"))
	var back := _jab()
	back.hitboxes[0].offset.x = -9.0
	r = _v.validate_move("t", "jab", back, sc)
	_check("jab achter de fighter (facing): FAIL", r["status"] == "FAIL" and _has(r, "facing"))
	var empty := _jab()
	empty.hitboxes.clear()
	r = _v.validate_move("t", "jab", empty, sc)
	_check("move zonder hitboxen: FAIL", r["status"] == "FAIL")
	r = _v.validate_move("t", "jab", null, sc)
	_check("ontbrekende MoveData: FAIL", r["status"] == "FAIL")


func _test_scores() -> void:
	var r: Dictionary = _v.validate_move("t", "jab", _jab(), {"S": 0, "K": 0, "B": 0, "V": 0})
	_check("alle assen 0: FAIL", r["status"] == "FAIL" and _has(r, "alle assen 0"))
	r = _v.validate_move("t", "jab", _jab(), {"S": 5, "K": 5, "B": 5, "V": 5})
	_check("alles 5: FAIL", r["status"] == "FAIL" and _has(r, "allemaal 5"))
	r = _v.validate_move("t", "jab", _jab(), {"S": 4, "K": 1, "B": 2, "V": 9})
	_check("score buiten bereik: FAIL", r["status"] == "FAIL" and _has(r, "buiten"))
	r = _v.validate_move("t", "jab", _jab(), {"S": 4, "K": 1, "B": 2})
	_check("score ontbreekt: FAIL", r["status"] == "FAIL" and _has(r, "ontbreekt"))


func _test_budget() -> void:
	var normals := {}
	for m in CT.NORMAL_MOVES:
		normals[m] = {"S": 2, "K": 2, "B": 2, "V": 2, "U": 0}
	# 13 vier-assige (8) + grab (S+B = 4) + 4 throws (S+K = 4) = 104 + 4 + 16 = 124
	_check("normals_total = 124", Validator.normals_total(normals) == 124)
	var specials := {"neutral_b": {"S": 3, "K": 3, "B": 3, "V": 3, "U": 4}, "up_b": {"S": 2, "K": 1, "B": 1, "V": 1, "U": 6}}
	var b: Dictionary = Validator.character_budget(normals, specials, {"extra_jump": -15}, false)
	# specials 16 + 11 = 27, extras 15 -> 166
	_check("budget 124+27+15 = 166, PASS", int(b["total"]) == 166 and b["status"] == "PASS")
	var over: Dictionary = Validator.character_budget(normals, specials, {"extra_jump": -15, "wall_jump": -5, "glide": -10, "x": -30}, false)
	_check("budget 211 > 200 zonder OP: FAIL", int(over["total"]) == 211 and over["status"] == "FAIL")
	var op: Dictionary = Validator.character_budget(normals, specials, {"extra_jump": -15, "wall_jump": -5, "glide": -10, "x": -30}, true)
	_check("budget 211 met op: PASS met OP-melding", op["status"] == "PASS" and "OP" in String(op["msg"]))
	var neg: Dictionary = Validator.character_budget(normals, specials, {"no_double_jump": 20}, false)
	_check("nadeel (+20) verlaagt kosten", int(neg["extras"]) == -20)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _test_files() -> void:
	var root := "user://validator_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root + "/arch/allrounder/moves"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root + "/chars/tester/moves"))
	ResourceSaver.save(_jab(), root + "/arch/allrounder/moves/jab.tres")
	var arch := {}
	for m in CT.NORMAL_MOVES:
		arch[m] = {"S": 2, "K": 2, "B": 2, "V": 2}
	arch["jab"] = {"S": 4, "K": 1, "B": 2, "V": 2}
	_write(root + "/arch/allrounder/moves/scores.json", JSON.stringify(arch))
	var v: RefCounted = Validator.new()
	v.arch_root = root + "/arch"
	v.char_root = root + "/chars"
	var rep: Dictionary = v.validate_archetype("allrounder")
	var jab_ok := false
	var missing := false
	for r in rep["results"]:
		if r["move"] == "jab":
			jab_ok = r["status"] == "PASS"
		if r["move"] == "ftilt":
			missing = r["status"] == "FAIL" and _has(r, "ontbreekt")
	_check("archetype-map: jab uit .tres PASS", jab_ok)
	_check("archetype-map: ontbrekend move-bestand FAIL", missing)

	# Character met eigen jab, hoge specials -> over budget; dan met op:true.
	ResourceSaver.save(_jab(), root + "/chars/tester/moves/jab.tres")
	_write(root + "/chars/tester/character.json", '{"id":"tester","archetype":"Allrounder","op":false}')
	var cs := {
		"jab": {"S": 4, "K": 1, "B": 2, "V": 2},
		"specials": {
			"neutral_b": {"S": 4, "K": 4, "B": 4, "V": 4, "U": 10},
			"side_b": {"S": 4, "K": 4, "B": 4, "V": 4, "U": 10},
			"up_b": {"S": 4, "K": 4, "B": 4, "V": 4, "U": 10},
			"down_b": {"S": 4, "K": 4, "B": 4, "V": 4, "U": 10},
		},
		"movement_extras": {"extra_jump": -15},
		"op": false,
	}
	_write(root + "/chars/tester/scores.json", JSON.stringify(cs))
	var cr: Dictionary = v.validate_character("tester")
	var b: Dictionary = cr["budget"]
	# normals: 8*? zie arch: 12 vierassige van 8 = 96 minus... jab 9 -> 13 four-axis moves: 12*8 + 9 = 105; grab 4; throws 16 -> 125
	# specials 4*26 = 104; extras 15 -> 244
	_check("character: eigen jab gevalideerd (PASS)", _move_status(cr, "jab") == "PASS")
	_check("character: budget 244 > 200 FAIL", int(b["total"]) == 244 and b["status"] == "FAIL")
	cs["op"] = true
	_write(root + "/chars/tester/scores.json", JSON.stringify(cs))
	b = v.validate_character("tester")["budget"]
	_check("character: op=true -> PASS met OP-melding", b["status"] == "PASS" and bool(b["op"]) and "OP" in String(b["msg"]))
	_check("archetype-alias Zwaargewicht", Validator.normalize_archetype("Zwaargewicht") == "heavyweight")
	_check("archetype-alias Fast-faller", Validator.normalize_archetype("Fast-faller") == "fast_faller")


func _move_status(rep: Dictionary, move: String) -> String:
	for r in rep["results"]:
		if r["move"] == move:
			return r["status"]
	return ""


func _has(r: Dictionary, needle: String) -> bool:
	for s in r["fails"] + r["warns"]:
		if needle in String(s):
			return true
	return false


## Director-afspraken (docs/standaard-movesets.md): schaal, hoeken, grab-whiff, throws, rondom, multi-hit, sourspot.
func _test_agreements() -> void:
	var sc := {"S": 4, "K": 1, "B": 2, "V": 2}
	# 9: positie schaalt met visual_height / 15, radius niet. Heavyweight (19): offset 9 * 19/15 = 11.4.
	var big := _jab()
	big.hitboxes[0].offset.x = 11.4
	var r: Dictionary = _v.validate_move("t", "jab", big, sc, 19.0)
	_check("schaal: jab op 19 units met offset 11.4: PASS", r["status"] == "PASS" or not _has(r, "reach"))
	r = _v.validate_move("t", "jab", _jab(), sc, 19.0)
	_check("schaal: ongeschaalde offset bij 19 units: FAIL op reach", r["status"] == "FAIL" and _has(r, "reach"))
	r = _v.validate_move("t", "jab", _jab(), sc, 19.0)
	_check("schaal: hoogte y=8 bij 19 units: WARN op afspraak 8", _has(r, "afspraak 8"))

	# 1: achterwaarts > 90.
	var bair := _bair()
	r = _v.validate_move("t", "bair", bair, {"S": 3, "K": 2, "B": 2, "V": 3})
	_check("bair met angle 135: geen back-angle WARN", not _has(r, "afspraak 1"))
	bair.hitboxes[0].angle = 45.0
	r = _v.validate_move("t", "bair", bair, {"S": 3, "K": 2, "B": 2, "V": 3})
	_check("bair met angle 45: WARN", _has(r, "afspraak 1"))
	bair.hitboxes[0].angle = 361.0
	r = _v.validate_move("t", "bair", bair, {"S": 3, "K": 2, "B": 2, "V": 3})
	_check("bair met angle 361 (lanceert vooruit): WARN", _has(r, "afspraak 1"))
	var bt := _md(46, [_hb(22, 22, Vector2(9, 8), 3.0, 4, 30, 105, 45)])
	r = _v.validate_move("t", "bthrow", bt, {"S": 2, "K": 2})
	_check("bthrow 45 graden: WARN", r["status"] == "WARN" and _has(r, "afspraak 1"))
	bt.hitboxes[0].angle = 135.0
	r = _v.validate_move("t", "bthrow", bt, {"S": 2, "K": 2})
	_check("bthrow 135 graden: PASS", r["status"] == "PASS")

	# 2: grab-whiff = laatste actieve frame + 23.
	var g := _hb(6, 7, Vector2(9, 8), 3.0, 0, 0, 100)
	g.ignores_shield = true
	var gm := _md(40, [g])
	r = _v.validate_move("t", "grab", gm, {"S": 3, "B": 2})
	_check("grab-whiff 40 i.p.v. 31: FAIL", r["status"] == "FAIL" and _has(r, "grab-whiff"))
	gm.total_frames = 31
	r = _v.validate_move("t", "grab", gm, {"S": 3, "B": 2})
	_check("grab-whiff 31 (8 + 23): PASS", r["status"] == "PASS")

	# 3: throw-hitbox radius 3.0 op de grab-tip.
	var th := _md(41, [_hb(20, 20, Vector2(9, 8), 2.5, 3, 25, 85, 45)])
	r = _v.validate_move("t", "fthrow", th, {"S": 3, "K": 1}, 15.0, gm)
	_check("throw radius 2.5: FAIL", r["status"] == "FAIL" and _has(r, "radius"))
	th.hitboxes[0].radius = 3.0
	r = _v.validate_move("t", "fthrow", th, {"S": 3, "K": 1}, 15.0, gm)
	_check("throw radius 3.0 op de grab-tip: PASS", r["status"] == "PASS")
	th.hitboxes[0].offset = Vector2(0, 13)
	r = _v.validate_move("t", "fthrow", th, {"S": 3, "K": 1}, 15.0, gm)
	_check("throw niet op de grab-tip: WARN", r["status"] == "WARN" and _has(r, "grab-tip"))

	# 10: rondom-moves.
	var nair := _nair()
	r = _v.validate_move("t", "nair", nair, {"S": 3, "K": 1, "B": 2, "V": 3})
	_check("nair met box voor en achter: PASS", r["status"] == "PASS")
	nair.hitboxes.remove_at(1)
	r = _v.validate_move("t", "nair", nair, {"S": 3, "K": 1, "B": 2, "V": 3})
	_check("nair alleen voor: FAIL (afspraak 10)", r["status"] == "FAIL" and _has(r, "afspraak 10"))

	# 5 en 7: sourspot en sex kick.
	nair = _nair()
	nair.hitboxes[1].damage = 5.0
	r = _v.validate_move("t", "nair", nair, {"S": 3, "K": 1, "B": 2, "V": 3})
	_check("sourspot met verkeerde damage: WARN", r["status"] == "WARN" and _has(r, "sourspot"))
	var sk := _nair()
	sk.hitboxes[0].end_frame = 8
	var late := _hb(9, 12, Vector2(9, 7.5), 3.0, 6, 15, 110, 361)
	late.id = 2
	sk.hitboxes.append(late)
	sk.hitboxes[1].end_frame = 12
	r = _v.validate_move("t", "nair", sk, {"S": 3, "K": 1, "B": 2, "V": 3})
	_check("sex kick: late blok even sterk als begin: WARN", _has(r, "sex-kick"))
	late.damage = 4.0
	late.base_kb = 5.0
	r = _v.validate_move("t", "nair", sk, {"S": 3, "K": 1, "B": 2, "V": 3})
	_check("sex kick: late blok als sourspot: geen WARN", not _has(r, "sex-kick"))

	# 6: multi-hit.
	var mh := _md(36, [
		_hb(7, 9, Vector2(0, -11.5), 2.5, 2, 5, 100, 270),
		_hb(10, 10, Vector2(0, -11.5), 2.5, 6, 15, 110, 290)], true)
	mh.hitboxes[1].group = 1
	mh.landing_lag = 20
	mh.lcancel_lag = 10
	mh.autocancel_before = 5
	mh.autocancel_after = 22
	r = _v.validate_move("t", "dair", mh, {"S": 3, "K": 1, "B": 1, "V": 3}, 12.0)
	_check("multi-hit drill: kleine hits ok", not _has(r, "multi-hit"))
	mh.hitboxes[0].damage = 5.0
	r = _v.validate_move("t", "dair", mh, {"S": 3, "K": 1, "B": 1, "V": 3}, 12.0)
	_check("multi-hit met grote eerste hit: WARN", _has(r, "multi-hit"))

	# unieke ids.
	var dup := _jab()
	dup.hitboxes.append(_hb(3, 4, Vector2(4.5, 8), 3.0, 3, 8, 60))
	r = _v.validate_move("t", "jab", dup, sc)
	_check("dubbel hitbox-id: WARN", _has(r, "niet uniek"))


func _bair() -> MoveData:
	# S3 K2 B2 V3: startup 9 (start 8), active 5, r 3.0, reach 17 (x -14), d8/b20/g120, LL 20, LC 10, air_endlag 26.
	var m := _md(39, [_hb(8, 12, Vector2(-14, 7.5), 3.0, 8, 20, 120, 135)], true)
	m.landing_lag = 20
	m.lcancel_lag = 10
	m.autocancel_before = 6
	m.autocancel_after = 25
	return m


func _nair() -> MoveData:
	# S3 K1 B2 V3: startup 6 (start 5), active 8 (5..12), r 3.0, reach 12 (x 9), d6/b15/g110; achter = sourspot.
	var m := _md(39, [
		_hb(5, 12, Vector2(9, 7.5), 3.0, 6, 15, 110),
		_hb(5, 12, Vector2(-4.5, 7.5), 3.0, 4, 5, 110, 135)], true)
	m.landing_lag = 20
	m.lcancel_lag = 10
	m.autocancel_before = 4
	m.autocancel_after = 25
	return m
