extends SceneTree
## Genereert de voorbeeld-specials van de oefenpop (characters/_dummy/specials/*.tres).
##   <godot_console> --headless --path . --script res://tools/specials/gen_dummy_specials.gd
## Daarna: --headless --path . --script res://tools/validator/validate.gd -- --character _dummy

const OUT: String = "res://characters/_dummy/specials"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var ok: bool = true
	for d: SpecialDef in [_neutral(), _side(), _up(), _down()]:
		var err: int = ResourceSaver.save(d, OUT.path_join(d.slot + ".tres"))
		print("%s -> %s" % [d.slot, "ok" if err == OK else "FOUT %d" % err])
		ok = ok and err == OK
	quit(0 if ok else 1)


static func hb(start: int, end: int, off: Vector2, r: float, dmg: float, ang: float, bkb: float, kbg: float,
		id: int = 0, group: int = 0) -> HitboxData:
	return MoveSet.make_hitbox(id, start, end, off, r, dmg, ang, bkb, kbg, group)


## Neutral-B "Splinterschot": houtsplinter opladen (charge) en afvuren (projectile).
func _neutral() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "neutral"
	d.display_name = "Splinterschot"
	d.templates = ["charge", "projectile"]
	d.params = {"startup": 8, "charge_max": 60, "hold_cancel": "shield", "charge_keep": true, "charge_stages": 0,
		"scale_damage": 2.5, "scale_size": 1.5, "scale_speed": 1.3}
	d.linked_params = {"startup": 4, "endlag": 20, "endlag_air": 18, "speed": 2.2, "lifetime": 70, "size": 3.0,
		"max_alive": 1, "on_cap": "block"}
	d.hitboxes = {"projectile": [hb(0, -1, Vector2.ZERO, 3.0, 4.0, 361.0, 10.0, 60.0)] as Array[HitboxData]}
	d.telegraph = "charge_glow"
	d.sfx = {"release": "throw"}
	d.scores = {"S": 3, "K": 2, "B": 3, "V": 3, "U": 4}
	return d


## Side-B "Plankstoot": schouderstoot vooruit (dash_strike), ook als kleine recovery.
func _side() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "side"
	d.display_name = "Plankstoot"
	d.templates = ["dash_strike"]
	d.params = {"startup": 12, "dash_speed": 3.5, "dash_frames": 22, "endlag": 22, "ends_with": "slide",
		"hitbox_mode": "first_contact_stop", "cliff_stop": false, "dash_gravity": 0.0}
	d.hitboxes = {"dash": [hb(0, -1, Vector2(5.0, 7.5), 5.0, 8.0, 40.0, 40.0, 70.0)] as Array[HitboxData]}
	d.helpless_after = true
	d.landing_lag = 15
	d.ledge_snap = "during"
	d.air_use_limit = 1
	d.scores = {"S": 3, "K": 2, "B": 2, "V": 2, "U": 4}
	return d


## Up-B "Wervelspaan": draaiende opwaartse multi-hit (rising_multi), de recovery.
func _up() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "up"
	d.display_name = "Wervelspaan"
	d.templates = ["rising_multi"]
	d.params = {"startup": 5, "rise_frames": 30, "rise_speed": 3.4, "rise_curve": "decel", "rise_angle": 70.0,
		"h_control": "x_only", "hits": 5, "interval": 5, "endlag": 24}
	d.hitboxes = {
		"multi": [hb(0, -1, Vector2(0.0, 7.5), 6.0, 1.5, 90.0, 20.0, 0.0)] as Array[HitboxData],
		"finisher": [hb(0, -1, Vector2(0.0, 10.0), 7.0, 6.0, 75.0, 40.0, 90.0)] as Array[HitboxData],
	}
	d.helpless_after = true
	d.landing_lag = 20
	d.ledge_snap = "during"
	d.air_use_limit = 1
	d.intangible = {"from": 0, "to": 3}
	d.scores = {"S": 5, "K": 2, "B": 2, "V": 1, "U": 5}
	return d


## Down-B "Knoestpareren": counter (pareert melee en projectielen).
func _down() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "down"
	d.display_name = "Knoestpareren"
	d.templates = ["counter"]
	d.params = {"startup": 6, "window_frames": 20, "whiff_endlag": 30, "counter_mult": 1.2, "counter_cap": 30.0,
		"strike_startup": 4, "strike_active": 3, "strike_endlag": 20}
	d.hitboxes = {"counter": [hb(0, -1, Vector2(7.0, 8.0), 8.0, 10.0, 40.0, 50.0, 80.0)] as Array[HitboxData]}
	d.vfx = {"strike": "counter_flash"}
	d.scores = {"S": 4, "K": 2, "B": 1, "V": 3, "U": 5}
	return d
