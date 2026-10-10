extends SceneTree
## Genereert de 4 specials van Captain Pep (characters/captain_pep/specials/*.tres). Eigen runners: neutral.gd, up.gd, down.gd.
##   <godot_console> --headless --path . --script res://characters/captain_pep/specials/gen_specials.gd
## Daarna: --script res://tools/validator/validate.gd -- --character captain_pep

const OUT: String = "res://characters/captain_pep/specials"


func _initialize() -> void:
	var sc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://characters/captain_pep/scores.json"))["specials"]
	var ok: bool = true
	for d: SpecialDef in [_neutral(), _side(), _up(), _down()]:
		d.scores = sc[d.slot + "_b"]
		var err: int = ResourceSaver.save(d, OUT.path_join(d.slot + ".tres"))
		print("%s -> %s" % [d.slot, "ok" if err == OK else "FOUT %d" % err])
		ok = ok and err == OK
	quit(0 if ok else 1)


static func hb(start: int, end: int, off: Vector2, r: float, dmg: float, ang: float, bkb: float, kbg: float,
		id: int = 0, group: int = 0, element: int = 0) -> HitboxData:
	var h: HitboxData = MoveSet.make_hitbox(id, start, end, off, r, dmg, ang, bkb, kbg, group)
	h.element = element as HitboxData.Element
	return h


## Neutral-B "Last Shot": eet-ritueel (40f startup) en één enorme klap op de plek (neutral.gd), daarna hijgen.
func _neutral() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "neutral"
	d.display_name = "Last Shot"
	d.templates = ["dash_strike"]
	d.params = {"startup": 40, "dash_speed": 2.0, "dash_frames": 6, "ends_with": "stop", "hitbox_mode": "during",
		"passes_through": true, "cliff_stop": true, "endlag": 56, "dash_gravity": 0.0,
		"momentum_air": "scale", "momentum_scale": 0.3, "gravity_scale": 0.4}
	# De klap: reuze-hitbox vlak voor hem, 4 frames actief, killt heel vroeg.
	d.hitboxes = {"dash": [hb(0, 3, Vector2(5.5, 8.0), 6.0, 26.0, 42.0, 48.0, 104.0)] as Array[HitboxData]}
	d.landing_lag = 22
	d.helpless_after = false
	d.poses = {"startup": "pep_eat", "dash": "pep_haymaker", "end": "pep_pant"}
	d.sfx = {"dash": "throw"}
	# Frames sinds de knopdruk. Hamburger uit de zak (6..27), zoutvaatje met het kapje omlaag boven de burger
	# (strooien 10..19, schuddend), burger naar de mond en weg (28 = opgegeten).
	d.prop_events.append({"prop": "hamburger", "attach": "hand_r", "from_frame": 6, "to_frame": 27})
	d.prop_events.append({"prop": "zoutvaatje", "attach": "hand_l", "from_frame": 6, "to_frame": 9})
	var rot: float = 150.0
	for fr in range(10, 20, 2):
		d.prop_events.append({"prop": "zoutvaatje", "attach": "hand_l", "from_frame": fr, "to_frame": fr + 1, "rotation": rot})
		rot = 190.0 if rot < 170.0 else 150.0
	d.prop_events.append({"prop": "zoutvaatje", "attach": "hand_l", "from_frame": 20, "to_frame": 22})
	return d


## Side-B "Panic Rush": op de racefiets naar voren; één harde klap bij contact. Lucht: licht stijgend, daarna helpless.
func _side() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "side"
	d.display_name = "Panic Rush"
	d.templates = ["dash_strike"]
	d.params = {"startup": 18, "dash_speed": 5.0, "dash_frames": 25, "dash_angle_ground": 0.0, "dash_angle_air": 14.0,
		"ends_with_ground": "slide", "ends_with_air": "stop", "hitbox_mode": "first_contact_stop", "passes_through": false, "cliff_stop": false,
		"endlag": 36, "dash_gravity": 0.0, "momentum_air": "zero", "gravity_scale": 0.3}
	d.hitboxes = {"dash": [hb(0, -1, Vector2(7.0, 6.0), 6.5, 13.0, 45.0, 38.0, 82.0)] as Array[HitboxData]}
	d.helpless_after = true
	d.landing_lag = 20
	d.ledge_snap = "during"
	d.ledge_snap_range = 10.0
	d.air_use_limit = 1
	d.poses = {"startup": "pep_ride", "dash": "pep_ride", "end": "pep_ride"}
	d.sfx = {"dash": "dash"}
	# Fiets onder de voeten tijdens de hele move (verdwijnt als de special-state eindigt).
	d.prop_events.append({"prop": "racefiets", "attach": "under_feet", "from_frame": 0, "to_frame": -1})
	return d


## Up-B "Grabby Hands": omhoog met grab-box (up.gd), grijpt, ontploft in paarse vonken. Mist: helpless.
func _up() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "up"
	d.display_name = "Grabby Hands"
	d.templates = ["rising_multi", "command_grab"]
	d.params = {"startup": 16, "rise_frames": 26, "rise_speed": 4.2, "rise_curve": "decel", "rise_angle": 70.0,
		"h_control": "x_only", "endlag": 26, "momentum_air": "zero"}
	d.linked_params = {"grab_radius": 7.0, "grab_active": 4, "hold_frames": 12, "burst_frames": 8, "miss_endlag": 26,
		"grab_offset": Vector2(5.0, 12.0), "hold_offset": Vector2(7.0, 6.0)}
	# Geen rising_multi-hitboxes; de explosie is een directe treffer (rol "explosion").
	d.hitboxes = {
		"multi": [] as Array[HitboxData],
		"finisher": [] as Array[HitboxData],
		"explosion": [hb(0, -1, Vector2.ZERO, 6.0, 14.0, 75.0, 42.0, 66.0, 0, 0, HitboxData.Element.NORMAL)] as Array[HitboxData],
	}
	d.helpless_after = true
	d.helpless_on_miss_only = true
	d.landing_lag = 20
	d.ledge_snap = "during"
	d.ledge_snap_range = 10.0
	d.air_use_limit = 1
	d.vfx = {"burst": "purple_sparks"}
	d.sfx = {"hold": "grab"}
	return d


## Down-B "Stumble Kick": grond = glijdende trap, lucht = stall + schuine duiktrap (down.gd), landing lag.
func _down() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "down"
	d.display_name = "Stumble Kick"
	d.templates = ["stall_fall"]
	d.params = {"startup": 11, "stall_frames": 14, "stall_gravity": 0.03, "stall_h_control": "none",
		"fall_trigger": "auto", "fall_speed": 4.6, "fall_direction": "angled", "fall_angle": -48.0,
		"hitbox_mode": "pierce", "landing_frames": 4, "momentum_air": "scale", "momentum_scale": 0.5,
		"slide_frames": 18, "slide_speed": 3.2, "slide_speed_end": 1.2, "endlag_ground": 24}
	d.hitboxes = {
		"slide": [hb(0, -1, Vector2(7.0, 3.0), 5.0, 8.0, 50.0, 30.0, 62.0)] as Array[HitboxData],
		"fall": [hb(0, -1, Vector2(5.0, 2.0), 5.5, 11.0, 45.0, 35.0, 85.0)] as Array[HitboxData],
		"landing": [hb(0, -1, Vector2(4.0, 2.0), 9.0, 5.0, 75.0, 30.0, 40.0)] as Array[HitboxData],
	}
	d.helpless_after = false
	d.landing_lag = 24
	d.ledge_snap = "during"
	d.ledge_snap_range = 10.0
	d.air_use_limit = 1
	d.poses = {"slide": "pep_slide_kick"}
	return d
