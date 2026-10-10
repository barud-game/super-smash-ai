extends SceneTree
## Genereert de 4 specials van Sonny Daylight (characters/sonny_daylight/specials/*.tres).
##   <godot_console> --headless --path . --script res://characters/sonny_daylight/specials/gen_specials.gd
## Daarna: --script res://tools/validator/validate.gd -- --character sonny_daylight

const OUT: String = "res://characters/sonny_daylight/specials"


func _initialize() -> void:
	var sc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://characters/sonny_daylight/scores.json"))["specials"]
	var ok: bool = true
	for d: SpecialDef in [_neutral(), _side(), _up(), _down()]:
		d.scores = sc[d.slot + "_b"]
		var err: int = ResourceSaver.save(d, OUT.path_join(d.slot + ".tres"))
		print("%s -> %s" % [d.slot, "ok" if err == OK else "FOUT %d" % err])
		ok = ok and err == OK
	quit(0 if ok else 1)


static func hb(start: int, end: int, off: Vector2, r: float, dmg: float, ang: float, bkb: float, kbg: float,
		id: int = 0, group: int = 0, disjoint: bool = true) -> HitboxData:
	var h: HitboxData = MoveSet.make_hitbox(id, start, end, off, r, dmg, ang, bkb, kbg, group)
	h.disjoint = disjoint
	return h


## Neutral-B "Punchline": één brede sabelslag (dash_strike met minimale stap), grond en lucht.
func _neutral() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "neutral"
	d.display_name = "Punchline"
	d.templates = ["dash_strike"]
	d.params = {"startup": 11, "dash_speed": 2.0, "dash_frames": 6, "ends_with": "stop", "hitbox_mode": "during",
		"passes_through": true, "cliff_stop": true, "endlag": 22, "dash_gravity": 0.0,
		"momentum_air": "scale", "momentum_scale": 0.6, "gravity_scale": 0.6}
	d.hitboxes = {"dash": [
		hb(0, -1, Vector2(8.0, 8.0), 6.0, 9.0, 45.0, 40.0, 80.0, 0, 1),
		hb(0, -1, Vector2(15.0, 9.0), 5.5, 10.0, 45.0, 45.0, 85.0, 1, 1),
	] as Array[HitboxData]}
	d.landing_lag = 12
	d.sfx = {"dash": "sword_swing"}
	return d


## Side-B "Double Take": schuine zijsprong met sabelhaal (eigen runner side.gd op multi_jump), 2x per airtime.
func _side() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "side"
	d.display_name = "Double Take"
	d.templates = ["multi_jump"]
	d.params = {"kind": "flap", "startup": 4, "flap_power": 2.3, "power_decay": 0.1, "flap_frames": 16,
		"side_speed": 1.7, "momentum_air": "scale", "momentum_scale": 0.3}
	d.hitboxes = {"slash": [hb(5, 10, Vector2(10.0, 8.0), 6.5, 5.0, 65.0, 30.0, 35.0)] as Array[HitboxData]}
	d.poses = {"flap": "atk_special_slash"}
	d.helpless_after = false
	d.air_use_limit = 2
	d.ledge_snap = "during"
	return d


## Up-B "Crossbow Line": kruisboogpijl met touw schuin omhoog naar de ledge (tether), pijlpunt raakt ook.
func _up() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "up"
	d.display_name = "Crossbow Line"
	d.templates = ["tether"]
	d.params = {"startup": 16, "max_length": 120.0, "extend_speed": 9.0, "aim_mode": "fixed", "angle": 50.0,
		"anchor_types": ["ledge"], "pull_mode": "self", "pull_speed": 4.5, "miss_endlag": 40,
		"helpless_on_miss": true, "endlag": 14}
	d.hitboxes = {"hook": [hb(0, -1, Vector2.ZERO, 2.5, 3.0, 60.0, 25.0, 30.0)] as Array[HitboxData]}
	d.helpless_after = true
	d.landing_lag = 18
	# Kruisboog in de linkerhand van de druk tot het einde (schuin omhoog gericht). pijl_touw aan het tether-uiteinde
	# wordt door het prop-mechanisme niet ondersteund (alleen bot-attaches).
	d.prop_events = [{"prop": "kruisboog", "attach": "hand_l", "from_frame": 0, "to_frame": -1, "rotation": -50.0}]
	d.air_use_limit = 1
	return d


## Down-B "Ha, Gemist!": counter; ontwijkt en prikt terug met een houten staak.
func _down() -> SpecialDef:
	var d := SpecialDef.new()
	d.slot = "down"
	d.display_name = "Ha, Gemist!"
	d.templates = ["counter"]
	d.params = {"startup": 15, "window_frames": 22, "whiff_endlag": 38, "counter_mult": 1.3, "counter_cap": 30.0,
		"strike_startup": 6, "strike_active": 3, "strike_endlag": 18}
	d.hitboxes = {"counter": [hb(0, -1, Vector2(12.0, 7.5), 4.0, 10.0, 40.0, 50.0, 80.0)] as Array[HitboxData]}
	d.vfx = {"strike": "counter_flash"}
	return d
