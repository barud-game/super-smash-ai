class_name TplStallFall
extends SpecialMove
## Sjabloon `stall_fall` (§9): [grond: ground_hop] startup -> stall (stall_gravity, optionele stall-hitbox) ->
## fall (vaste val `fall_speed`, recht of schuin, rol "fall") -> landing (rol "landing" = shockwave, dan vaste
## landing lag, geen L-cancel). fall_trigger: "auto" (na stall_frames), "button_release" (B los), "stick_down".
## Blijft vallen tot de vloer of de blast zone (geen bescherming). Ledge: niet tijdens de val.

const DEFAULTS: Dictionary = {
	"startup": 8, "stall_frames": 20, "stall_gravity": 0.02, "stall_h_control": "none", "fall_trigger": "auto",
	"fall_speed": 4.5, "fall_direction": "down", "fall_angle": -60.0, "fall_end_action": "landing",
	"bounce_speed": 1.8, "ground_hop": 2.0, "hitbox_mode": "pierce", "fall_through_platform": false,
	"fall_damage": 9.0, "fall_kb_angle": 280.0, "fall_kb_base": 30.0, "fall_kb_scale": 70.0, "fall_size": 6.0,
	"landing_frames": 4, "landing_damage": 6.0, "landing_kb_angle": 50.0, "landing_kb_base": 40.0,
	"landing_kb_scale": 70.0, "landing_size": 10.0, "fall_hit_endlag": 15, "momentum_air": "zero",
}

var fall_dir: Vector2 = Vector2(0.0, -1.0)
var landed_lag: int = 0


func defaults() -> Dictionary:
	return DEFAULTS


func start() -> void:
	if f.grounded:
		f.leave_ground(Vector2(0.0, pf("ground_hop", 2.0)))
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				set_phase("stall")
		"stall":
			var trig: String = ps("fall_trigger", "auto")
			var go: bool = phase_frame >= maxi(pi_("stall_frames", 20), 1)
			if trig == "button_release" and not f.input.held(InputFrame.BTN_SPECIAL):
				go = true
			elif trig == "stick_down" and f.stick_y() <= -MeleeStick.FAST_FALL_THRESHOLD + FighterConst.EPS:
				go = true
			if go:
				_begin_fall()
		"fall":
			var stop_on_hit: bool = ps("hitbox_mode", "pierce") == "stop_on_hit"
			if stop_on_hit and hit_landed:
				f.vel = Vector2.ZERO
				set_phase("end")
		"end":
			if phase_frame >= pi_("fall_hit_endlag", 15):
				finish()
		"landing":
			if phase_frame >= maxi(landed_lag, 1):
				done = true
				f.change_state("Wait")


func _begin_fall() -> void:
	if ps("fall_direction", "down") == "angled":
		fall_dir = SpecialAim.dir_from_angle(pf("fall_angle", -60.0), f.facing)
	else:
		fall_dir = Vector2(0.0, -1.0)
	set_phase("fall")


func phys() -> void:
	match phase:
		"startup":
			if not f.grounded:
				f.vel.y = maxf(f.vel.y - f.stats.gravity * 0.5, -1.0)
				f.vel.x *= 0.9
			return
		"stall":
			f.vel.y = maxf(f.vel.y - pf("stall_gravity", 0.02), -1.0)
			if ps("stall_h_control", "none") == "none":
				f.vel.x = move_toward(f.vel.x, 0.0, 0.05)
			else:
				f.apply_air_drift(f.stick_x())
			return
		"fall":
			f.vel = fall_dir * pf("fall_speed", 4.5) * speed_mult
			return
		"landing":
			f.apply_ground_friction()
			return
	super.phys()


func on_land() -> void:
	if phase == "fall" or phase == "stall" or phase == "startup":
		if ps("fall_end_action", "landing") == "bounce" and phase == "fall":
			done = true
			f.leave_ground(Vector2(0.0, pf("bounce_speed", 1.8)))
			f.change_state("Fall")
			return
		landed_lag = def.landing_lag
		f.start_move()
		set_phase("landing")
		return
	super.on_land()


func lands_on_platforms() -> bool:
	if phase == "fall":
		return not pb("fall_through_platform")
	return super.lands_on_platforms()


func ledge_snap_active() -> bool:
	if def.ledge_snap == "none" or phase == "fall":
		return false
	return phase == "stall" or phase == "end"


func hitboxes() -> Array[ActiveHitbox]:
	var h: float = f.stats.visual_height
	match phase:
		"stall":
			return role_boxes("stall", phase_frame)
		"fall":
			var src: Array[HitboxData] = hits_or_default("fall", "fall_", 0, -1, Vector2(0.0, h * 0.25), 6.0, 9.0,
				280.0, 30.0, 70.0)
			return boxes(src, phase_frame)
		"landing":
			if phase_frame >= pi_("landing_frames", 4):
				return []
			var lsrc: Array[HitboxData] = hits_or_default("landing", "landing_", 0, -1, Vector2(0.0, 2.0), 10.0, 6.0,
				50.0, 40.0, 70.0)
			return boxes(lsrc, phase_frame)
	return []


func default_pose() -> String:
	match phase:
		"fall", "landing":
			return "atk_special_stall_fall"
	return "atk_special_stall"
