extends RefCounted
## Special-checks voor de validator (docs/specials.md, "Validator"): sjablonen/combinatie, parameterbereiken,
## director-besluiten (max 2 sjablonen +2 U, teleport-cap 260, helpless-regel, telegraaf, zichtbare traps) en
## scores tegen de prijs-richtlijn van docs/special-sjablonen.md. Puur; gebruikt door validator.gd en tests.

const ST := preload("res://tools/validator/special_table.gd")


static func _add(res: Dictionary, level: String, msg: String) -> void:
	res["fails" if level == "fail" else "warns"].append(msg)


## Effectieve waarde van een instelling voor templates[i]: zoals SpecialMove.p() (lucht-variant eerst als
## `air`), met de sjabloon-standaard (DEFAULTS van het sjabloon-script) als terugval.
static func eff(d: SpecialDef, i: int, key: String, default: Variant = null, air: bool = false) -> Variant:
	var own: Dictionary = d.linked_params if i > 0 else d.params
	var v: Variant = _lookup(own, key, air)
	if v != null:
		return v
	v = _lookup(template_defaults(d.templates[i] if i < d.templates.size() else ""), key, air)
	if v != null:
		return v
	if i > 0:
		v = _lookup(d.params, key, air)
		if v != null:
			return v
	return default


static func _lookup(dict: Dictionary, key: String, air: bool) -> Variant:
	var variant: String = key + ("_air" if air else "_ground")
	if dict.has(variant):
		return dict[variant]
	return dict.get(key)


static func template_defaults(t: String) -> Dictionary:
	var s: Variant = Specials.TEMPLATE_SCRIPTS.get(t)
	if s is Script:
		var m: Dictionary = (s as Script).get_script_constant_map()
		if m.get("DEFAULTS") is Dictionary:
			return m["DEFAULTS"]
	return {}


## Valideert één SpecialDef. Geeft {scope, move, scores, measured, fails, warns, status, estimate}.
func validate_def(scope: String, d: SpecialDef) -> Dictionary:
	var res: Dictionary = {"scope": scope, "move": "special_def/" + (d.slot if d != null else "?"),
		"scores": d.scores if d != null else {}, "measured": {}, "fails": [], "warns": [], "status": "PASS",
		"estimate": {}}
	if d == null:
		_add(res, "fail", "geen SpecialDef")
		return _finish(res)
	if not (d.slot in SpecialDef.SLOTS):
		_add(res, "fail", "onbekend slot '%s' (verwacht %s)" % [d.slot, ", ".join(SpecialDef.SLOTS)])
	_check_templates(res, d)
	_check_ranges(res, d)
	_check_rules(res, d)
	_check_scores(res, d)
	return _finish(res)


static func _finish(res: Dictionary) -> Dictionary:
	res["status"] = "FAIL" if not res["fails"].is_empty() else ("WARN" if not res["warns"].is_empty() else "PASS")
	return res


func _check_templates(res: Dictionary, d: SpecialDef) -> void:
	if d.templates.is_empty():
		_add(res, "fail", "geen sjabloon")
	if d.templates.size() > ST.MAX_TEMPLATES:
		_add(res, "fail", "%d sjablonen (max %d; director-besluit 1)" % [d.templates.size(), ST.MAX_TEMPLATES])
	for t: String in d.templates:
		if not (t in SpecialDef.TEMPLATE_IDS):
			_add(res, "fail", "onbekend sjabloon '%s'" % t)
	if d.templates.size() == 2 and d.templates[0] == d.templates[1]:
		_add(res, "warn", "twee keer hetzelfde sjabloon '%s'" % d.templates[0])
	if d.script_path != "" and not ResourceLoader.exists(d.script_path):
		_add(res, "fail", "script_path bestaat niet: %s" % d.script_path)


func _range(res: Dictionary, label: String, v: Variant, r: Array) -> void:
	if not (v is int or v is float):
		return
	var x: float = float(v)
	if x < float(r[0]) - 0.0001 or x > float(r[1]) + 0.0001:
		_add(res, "fail", "%s %s buiten %s..%s" % [label, str(v), str(r[0]), str(r[1])])


func _check_ranges(res: Dictionary, d: SpecialDef) -> void:
	for i in mini(d.templates.size(), ST.MAX_TEMPLATES):
		var t: String = d.templates[i]
		var own: Dictionary = d.linked_params if i > 0 else d.params
		var table: Dictionary = ST.TEMPLATE.get(t, {})
		for key: String in own:
			var base: String = key.trim_suffix("_air").trim_suffix("_ground")
			var label: String = ("%s.%s" % [t, key]) if i > 0 else key
			if table.has(base):
				_range(res, label, own[key], table[base])
			elif ST.SHARED.has(base):
				_range(res, label, own[key], ST.SHARED[base])
		if t == "buff":
			var mods: Variant = eff(d, i, "modifiers", {})
			if mods is Dictionary:
				for mk: String in mods:
					_range(res, "modifier %s" % mk, mods[mk], ST.MODIFIER_RANGE)
	_range(res, "landing_lag", d.landing_lag, ST.DEF_FIELDS["landing_lag"])
	_range(res, "ledge_snap_range", d.ledge_snap_range, ST.DEF_FIELDS["ledge_snap_range"])
	if "multi_jump" in d.templates:
		if d.air_use_limit < 0:
			_add(res, "fail", "multi_jump zonder air_use_limit (= count) geeft oneindige flaps")
		else:
			_range(res, "air_use_limit (count)", d.air_use_limit, ST.MULTI_JUMP_COUNT)
	else:
		_range(res, "air_use_limit", d.air_use_limit, ST.DEF_FIELDS["air_use_limit"])
	if not (d.ledge_snap in ["none", "during", "end_only"]):
		_add(res, "fail", "ledge_snap '%s' (none/during/end_only)" % d.ledge_snap)
	if not d.armor.is_empty():
		var md: float = float(d.armor.get("max_damage", 0.0))
		if md > 12.0:
			_add(res, "warn", "armor-drempel %.0f%% > 12%% (richtwaarde 5–12)" % md)
	if not d.intangible.is_empty():
		var dur: int = int(d.intangible.get("to", 0)) - int(d.intangible.get("from", 0)) + 1
		if dur > 20:
			_add(res, "warn", "intangible %d frames > 20 (utility-toeslag)" % dur)


func _u(d: SpecialDef) -> int:
	return int(d.scores.get("U", 0))


func _check_rules(res: Dictionary, d: SpecialDef) -> void:
	var u: int = _u(d)
	# Telegraaf (director-besluit 3).
	for t: String in d.templates:
		if t in ST.TELEGRAPH_TEMPLATES and d.telegraph == "":
			_add(res, "fail", "'%s' vereist een zichtbare telegraaf (telegraph leeg)" % t)
	# Onzichtbare traps verboden.
	for i in d.templates.size():
		if d.templates[i] == "trap" and not bool(eff(d, i, "visible_to_enemy", true)):
			_add(res, "fail", "onzichtbare trap (visible_to_enemy = false) is verboden; trap moet zichtbaar zijn")
	# Teleport-cap 260 (ook als de waarde in een variant staat).
	for i in d.templates.size():
		if d.templates[i] == "teleport":
			for air: bool in [false, true]:
				var dist: float = float(eff(d, i, "distance", 0.0, air))
				if dist > 260.0 + 0.0001 and not res["fails"].any(func(m: String) -> bool: return m.contains("distance")):
					_add(res, "fail", "teleport distance %.0f > 260 (director-besluit 2)" % dist)
	# Combinatie: +2 utility.
	if d.templates.size() == 2 and u < ST.COMBO_UTILITY + 1:
		_add(res, "warn", "combinatie van 2 sjablonen: reken +%d utility (U=%d)" % [ST.COMBO_UTILITY, u])
	# Helpless-regel bij lucht-recoveries (up/side).
	if d.air_allowed and (d.slot == "up" or d.slot == "side") and d.primary() in ST.RECOVERY_TEMPLATES \
			and not d.helpless_after and u >= ST.RECOVERY_MIN_UTILITY - 2:
		if u < ST.RECOVERY_MIN_UTILITY + ST.NO_HELPLESS_UTILITY:
			_add(res, "warn", "lucht-recovery zonder helpless_after: kost +%d utility (U=%d, verwacht >= %d)"
				% [ST.NO_HELPLESS_UTILITY, u, ST.RECOVERY_MIN_UTILITY + ST.NO_HELPLESS_UTILITY])
	# Scores-bereik.
	for a: String in ["S", "K", "B", "V"]:
		if not d.scores.has(a):
			_add(res, "warn", "score %s ontbreekt in de definitie" % a)
		elif int(d.scores[a]) < 0 or int(d.scores[a]) > 5:
			_add(res, "fail", "score %s=%d buiten 0..5" % [a, int(d.scores[a])])
	if u < 0 or u > 10:
		_add(res, "fail", "score U=%d buiten 0..10" % u)


## Schatting per as uit de parameters (alleen assen waarvoor de prijs-richtlijn een regel geeft).
func estimate(d: SpecialDef) -> Dictionary:
	var e: Dictionary = {}
	var t: String = d.primary()
	var first: int = int(eff(d, 0, "startup", 10)) + 1
	match t:
		"projectile":
			e["S"] = ST.band(first, ST.SPEED_PROJECTILE, 1)
			e["B"] = _projectile_range(d, 0)
			e["V"] = ST.band(int(eff(d, 0, "endlag", 20)), ST.SAFETY_PROJECTILE, 2)
		"charge":
			e["S"] = ST.band(int(eff(d, 0, "startup", 8)) + int(eff(d, 0, "charge_max", 60)), ST.SPEED_CHARGE_FULL, 2)
			if d.linked_template() == "projectile":
				e["B"] = _projectile_range(d, 1, float(d.get_param("scale_speed", false, 1.0)))
		"teleport":
			e["S"] = ST.band(first, ST.SPEED_TELEPORT, 2)
			var b: int = ST.band(minf(float(eff(d, 0, "distance", 120.0)), 260.0), ST.RANGE_TELEPORT, 5)
			if String(eff(d, 0, "direction_mode", "stick_8dir")) == "stick_free":
				b = mini(b + 1, 5)
			e["B"] = b
			if not d.has_hits("arrival") and not d.has_hits("departure"):
				e["K"] = 0
		"rising_multi":
			e["S"] = ST.band(first, ST.SPEED_RISING, 2)
			var frames: float = float(eff(d, 0, "rise_frames", 24))
			var dist: float = float(eff(d, 0, "rise_distance", 0.0))
			if dist <= 0.0:
				dist = float(eff(d, 0, "rise_speed", 2.6)) * frames
			var rb: int = ST.band(dist, ST.RANGE_RISING, 4)
			if String(eff(d, 0, "h_control", "x_only")) == "full":
				rb = mini(rb + 1, 5)
			e["B"] = rb
		"counter":
			e["S"] = ST.band(first, ST.SPEED_COUNTER, 2)
			e["V"] = ST.band(int(eff(d, 0, "whiff_endlag", 30)), ST.SAFETY_COUNTER, 1)
		"command_grab":
			e["S"] = ST.band(first, ST.SPEED_GRAB, 2)
			var off: Vector2 = eff(d, 0, "grab_offset", Vector2(8, 7))
			var gb: int = ST.band(absf(off.x) + float(eff(d, 0, "grab_radius", 6.0)), ST.RANGE_GRAB, 3)
			if float(eff(d, 0, "travel_speed", 0.0)) > 0.0:
				gb = mini(gb + 1, 5)
			e["B"] = gb
			e["V"] = ST.band(int(eff(d, 0, "miss_endlag", 30)), ST.SAFETY_GRAB, 1)
		"reflector":
			e["S"] = ST.band(first, ST.SPEED_REFLECT, 2)
			var rr: int = ST.band(2.0 * float(eff(d, 0, "reflect_radius", 11.0)), ST.RANGE_REFLECT, 3)
			if String(eff(d, 0, "facing", "both")) == "both":
				rr = mini(rr + 1, 5)
			e["B"] = rr
			e["V"] = ST.band(int(eff(d, 0, "endlag", 18)), ST.SAFETY_REFLECT, 2)
		"dash_strike":
			e["S"] = ST.band(first, ST.SPEED_PROJECTILE, 1)
			var dd: float = float(eff(d, 0, "dash_distance", 0.0))
			if dd <= 0.0:
				dd = float(eff(d, 0, "dash_speed", 4.0)) * float(eff(d, 0, "dash_frames", 12))
			e["B"] = ST.band(dd, ST.RANGE_DASH, 5)
		"tether":
			e["S"] = ST.band(first, ST.SPEED_PROJECTILE, 1)
			e["B"] = ST.band(float(eff(d, 0, "max_length", 120.0)), ST.RANGE_TETHER, 5)
		"multi_jump":
			e["S"] = 5
			e["K"] = 0
		"absorber":
			e["K"] = 0
		"trap", "spin", "command_dash", "stall_fall":
			e["S"] = ST.band(first, ST.SPEED_PROJECTILE, 1)
	return e


func _projectile_range(d: SpecialDef, i: int, speed_scale: float = 1.0) -> int:
	var dist: float = float(eff(d, i, "max_range", 0.0))
	if dist <= 0.0:
		dist = float(eff(d, i, "speed", 2.0)) * speed_scale * float(eff(d, i, "lifetime", 90))
	var b: int = ST.band(dist, ST.RANGE_PROJECTILE, 5)
	if int(eff(d, i, "pierce", 0)) != 0:
		b += 1
	if float(eff(d, i, "gravity", 0.0)) > 0.0 or String(eff(d, i, "bounce", "none")) != "none":
		b += 1
	return mini(b, 5)


func _check_scores(res: Dictionary, d: SpecialDef) -> void:
	var e: Dictionary = estimate(d)
	res["estimate"] = e
	for a: String in e:
		if not d.scores.has(a):
			continue
		var diff: int = absi(int(d.scores[a]) - int(e[a]))
		res["measured"]["est_" + a] = e[a]
		if diff >= ST.FAIL_DIFF:
			_add(res, "fail", "score %s=%d past niet bij de parameters (prijs-richtlijn ~%d)" % [a, int(d.scores[a]), e[a]])
		elif diff >= ST.WARN_DIFF:
			_add(res, "warn", "score %s=%d wijkt af van de prijs-richtlijn (~%d)" % [a, int(d.scores[a]), e[a]])


## Recovery-check op character-niveau (§0.5): minstens één up/side-special met U >= 5 die een recovery-sjabloon is
## of multi_jump. Geeft "" of een waarschuwing.
static func recovery_warning(defs: Dictionary) -> String:
	for s: String in ["up", "side"]:
		var d: SpecialDef = defs.get(s)
		if d == null:
			continue
		var t: String = d.primary()
		if (t in ST.RECOVERY_TEMPLATES or t == "multi_jump") and int(d.scores.get("U", 0)) >= ST.RECOVERY_MIN_UTILITY:
			return ""
	return "geen bruikbare recovery (up/side met utility >= %d)" % ST.RECOVERY_MIN_UTILITY
