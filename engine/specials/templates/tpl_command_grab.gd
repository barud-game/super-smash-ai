class_name TplCommandGrab
extends SpecialMove
## Sjabloon `command_grab` (§7): startup (optioneel `travel_speed`) -> grab (grab-box, negeert shield;
## SpecialWorld test hem) -> bij raak: hold (slachtoffer in SpecialHeld; pummel/auto_hits; breakout) -> throw
## (rol "throw", of "throw_f/_b/_u/_d" met throw_stick_directions) -> throw_end; bij mis: miss_endlag.
## Grab-trade (twee grabs tegelijk) = beide mis. Intangible doelwit = mis.

const DEFAULTS: Dictionary = {
	"startup": 12, "grab_active": 4, "grab_radius": 6.0, "grab_offset": Vector2(8.0, 7.0),
	"grab_type": "grounded_only", "grab_ledge": false, "hold_frames": 20, "hold_offset": Vector2(9.0, 0.0),
	"hold_action": "none", "pummel_hits": 3, "pummel_damage": 2.0, "auto_hit_interval": 8,
	"throw_stick_directions": false, "breakout": "none", "breakout_presses": 12, "miss_endlag": 30,
	"throw_endlag": 18, "throw_damage": 9.0, "throw_kb_angle": 45.0, "throw_kb_base": 60.0, "throw_kb_scale": 70.0,
	"travel_speed": 0.0, "air_miss_helpless": false, "gravity_scale": 1.0,
}

var victim: Fighter = null
var grabbed: bool = false
var thrown: bool = false
var pummels: int = 0


func defaults() -> Dictionary:
	return DEFAULTS


func start() -> void:
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				set_phase("grab")
		"grab":
			if phase_frame >= maxi(pi_("grab_active", 4), 1):
				set_phase("end")
		"hold":
			if victim == null or not is_instance_valid(victim) or victim.state_name() != "SpecialHeld":
				# Losgebroken: korte endlag.
				victim = null
				set_phase("throw_end")
				return
			if ps("hold_action", "none") == "auto_hits" and phase_frame % maxi(pi_("auto_hit_interval", 8), 1) == 0:
				_pummel()
			if phase_frame >= pi_("hold_frames", 20):
				throw()
		"throw_end":
			if phase_frame >= pi_("throw_endlag", 18):
				finish()
		"end":
			if phase_frame >= pi_("miss_endlag", 30):
				finish()


func input() -> void:
	if phase == "hold" and ps("hold_action", "none") == "pummel" and f.input.pressed(InputFrame.BTN_ATTACK):
		_pummel()


func _pummel() -> void:
	if victim == null or pummels >= pi_("pummel_hits", 3):
		return
	pummels += 1
	victim.set_percent(minf(victim.percent + pf("pummel_damage", 2.0) * damage_mult, Fighter.MAX_PERCENT))
	present("pummel")


func phys() -> void:
	if phase == "startup" and pf("travel_speed", 0.0) != 0.0:
		set_velocity(Vector2(pf("travel_speed", 0.0) * f.facing, 0.0) if f.grounded
			else Vector2(pf("travel_speed", 0.0) * f.facing, f.vel.y))
		if not f.grounded:
			apply_gravity()
		return
	if phase == "hold" or phase == "throw_end":
		if f.grounded:
			f.apply_ground_friction()
		else:
			f.vel = Vector2.ZERO
		return
	super.phys()


func grab_box() -> Dictionary:
	if phase != "grab" or grabbed:
		return {}
	var off: Vector2 = p("grab_offset", Vector2(8.0, 7.0))
	return {"center": f.pos + Vector2(off.x * f.facing, off.y), "radius": pf("grab_radius", 6.0) * size_mult,
		"grab_type": ps("grab_type", "grounded_only"), "grab_ledge": pb("grab_ledge")}


func on_grab(v: Fighter) -> void:
	if grabbed:
		return
	grabbed = true
	victim = v
	hit_landed = true
	var br: int = pi_("breakout_presses", 12) if ps("breakout", "none") == "mash" else 0
	v.change_state("SpecialHeld", {"holder": f, "offset": p("hold_offset", Vector2(9.0, 0.0)), "breakout": br,
		"max_frames": pi_("hold_frames", 20) + 30})
	set_phase("hold")


func on_grab_clank() -> void:
	set_phase("end")


## Worp: één treffer met vaste KB vanaf de positie van het slachtoffer.
func throw() -> void:
	if thrown or victim == null:
		return
	thrown = true
	var role: String = "throw"
	if pb("throw_stick_directions"):
		var s: Vector2 = f.stick()
		if not SpecialAim.is_neutral(s):
			if absf(s.y) > absf(s.x):
				role = "throw_u" if s.y > 0.0 else "throw_d"
			else:
				role = "throw_f" if s.x * f.facing > 0.0 else "throw_b"
			if not def.has_hits(role):
				role = "throw"
	var src: Array[HitboxData] = hits_or_default(role, "throw_", 0, -1, Vector2.ZERO, 6.0, 9.0, 45.0, 60.0, 70.0)
	if not src.is_empty():
		SpecialMove.apply_direct_hit(f, victim, scaled(src[0]), src[0].damage * damage_mult)
	elif victim.state is StateSpecialHeld:
		(victim.state as StateSpecialHeld).release()
	victim = null
	set_phase("throw_end")


func on_exit() -> void:
	super.on_exit()
	if victim != null and is_instance_valid(victim) and victim.state_name() == "SpecialHeld":
		(victim.state as StateSpecialHeld).release()
	victim = null


func helpless_now() -> bool:
	if not grabbed and started_air and pb("air_miss_helpless"):
		return true
	return super.helpless_now()


func default_pose() -> String:
	match phase:
		"hold":
			return "atk_grab_hold"
		"throw_end":
			return "atk_fthrow"
	return "atk_grab"
