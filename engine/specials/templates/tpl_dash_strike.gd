class_name TplDashStrike
extends SpecialMove
## Sjabloon `dash_strike` (§8): startup -> dash (dash_speed langs dash_angle/stick, `dash_frames` of
## `dash_distance`) -> [finisher (ends_with "finisher_hit")] -> end (slide/stop) -> klaar.
## Rollen: "dash" (frames relatief aan de dash; standaard de hele dash), "finisher". hitbox_mode: "during",
## "end_only" (laatste 3 dash-frames), "first_contact_stop" (stopt bij de eerste treffer); passes_through=false
## stopt ook bij een treffer. cliff_stop: stopt aan de rand (anders glijdt de fighter eraf en gaat door in de lucht).

const DEFAULTS: Dictionary = {
	"startup": 10, "dash_speed": 4.0, "dash_frames": 12, "dash_angle": 0.0, "stick_aim": false,
	"steer_max_angle": 30.0, "ends_with": "slide", "hitbox_mode": "during", "passes_through": true,
	"cliff_stop": false, "slide_friction": 0.15, "endlag": 22, "dash_gravity": 0.0, "dash_damage": 8.0,
	"dash_kb_angle": 40.0, "dash_kb_base": 40.0, "dash_kb_scale": 70.0, "dash_size": 5.0, "finisher_frames": 3,
	"finisher_damage": 10.0, "finisher_kb_angle": 40.0, "finisher_kb_base": 50.0, "finisher_kb_scale": 85.0,
	"finisher_size": 6.0, "momentum_air": "zero", "gravity_scale": 0.5,
}

var dash_dir: Vector2 = Vector2.RIGHT
var stopped: bool = false


func defaults() -> Dictionary:
	return DEFAULTS


func dash_frames() -> int:
	var d: float = pf("dash_distance", 0.0)
	if d > 0.0:
		return maxi(int(ceilf(d / maxf(pf("dash_speed", 4.0), 0.1))), 1)
	return maxi(pi_("dash_frames", 12), 1)


func start() -> void:
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				var ang: float = pf("dash_angle", 0.0)
				if pb("stick_aim"):
					ang = SpecialAim.steer_angle(f.stick(), f.facing, ang, pf("steer_max_angle", 30.0))
				dash_dir = SpecialAim.dir_from_angle(ang, f.facing)
				set_phase("dash")
		"dash":
			var stop_on_hit: bool = ps("hitbox_mode", "during") == "first_contact_stop" or not pb("passes_through", true)
			if phase_frame >= dash_frames() or (stop_on_hit and hit_landed):
				stopped = phase_frame < dash_frames()
				if ps("ends_with", "slide") == "finisher_hit":
					set_phase("finisher")
				else:
					_end_dash()
		"finisher":
			if phase_frame >= pi_("finisher_frames", 3):
				_end_dash()
		"end":
			if phase_frame >= endlag_frames():
				finish()


func _end_dash() -> void:
	if ps("ends_with", "slide") == "stop" or stopped:
		if f.grounded:
			f.gr_vel = 0.0
		else:
			f.vel = Vector2.ZERO
	set_phase("end")


func phys() -> void:
	match phase:
		"dash":
			var v: Vector2 = dash_dir * pf("dash_speed", 4.0) * speed_mult
			if f.grounded:
				if v.y > 0.0001 and pb("leave_ground"):
					f.leave_ground(v)
				else:
					f.gr_vel = v.x
			else:
				f.vel = v
				var g: float = pf("dash_gravity", 0.0)
				if g > 0.0:
					f.vel.y -= f.stats.gravity * g
			return
		"end", "finisher":
			if f.grounded:
				if ps("ends_with", "slide") == "slide":
					f.gr_vel = move_toward(f.gr_vel, 0.0, pf("slide_friction", 0.15))
				else:
					f.apply_ground_friction()
				return
	super.phys()


func wants_off_edge() -> bool:
	return not pb("cliff_stop")


func on_land() -> void:
	if phase == "dash" or phase == "startup":
		return
	super.on_land()


func hitboxes() -> Array[ActiveHitbox]:
	var h: float = f.stats.visual_height
	match phase:
		"dash":
			var mode: String = ps("hitbox_mode", "during")
			if mode == "end_only" and phase_frame < dash_frames() - 3:
				return []
			var src: Array[HitboxData] = hits_or_default("dash", "dash_", 0, -1, Vector2(5.0, h * 0.5), 5.0, 8.0,
				40.0, 40.0, 70.0)
			return boxes(src, phase_frame)
		"finisher":
			var fin: Array[HitboxData] = hits_or_default("finisher", "finisher_", 0, -1, Vector2(7.0, h * 0.5), 6.0,
				10.0, 40.0, 50.0, 85.0)
			var out: Array[ActiveHitbox] = boxes(fin, phase_frame)
			for a: ActiveHitbox in out:
				if a.data.group == 0:
					var c: HitboxData = a.data.duplicate() as HitboxData
					c.group = 50
					a.data = c
			return out
	return []


func default_pose() -> String:
	return "atk_special_dash"


func fallback_pose() -> String:
	return "atk_dash_attack"
