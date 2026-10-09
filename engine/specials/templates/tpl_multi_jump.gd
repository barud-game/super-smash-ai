class_name TplMultiJump
extends SpecialMove
## Sjabloon `multi_jump` (§10): extra sprongen/zweven via de special-knop. Aantal per airtime =
## def.air_use_limit (= `count`; reset bij landen/ledge/hit). Geen helpless.
##   flap:  startup -> flap (vy = flap_power × (1 − power_decay)^(n−1), drift tot h_drift) -> Fall
##   hover: zolang B vast en < hover_frames: gravity × hover_gravity_scale (fast fall breekt) -> Fall
##   glide: horizontale vlucht (glide_h_speed, glide_fall_speed) tot B los of landen -> Fall
## can_attack_during: aerials mogen tijdens flap/hover/glide (breken de special af).

const DEFAULTS: Dictionary = {
	"kind": "flap", "startup": 3, "flap_power": 2.2, "power_decay": 0.15, "h_drift": 1.0, "flap_frames": 12,
	"hover_frames": 90, "hover_gravity_scale": 0.15, "hover_max_fall": 0.4, "glide_fall_speed": 0.6,
	"glide_h_speed": 1.6, "glide_frames": 180, "cooldown_between": 0, "can_attack_during": false,
	"momentum_air": "keep",
}


func defaults() -> Dictionary:
	return DEFAULTS


func kind() -> String:
	return ps("kind", "flap")


func start() -> void:
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= maxi(pi_("startup", 3), 1):
				set_phase(kind())
				if kind() == "flap":
					var n: int = maxi(kit.uses(slot), 1)
					var power: float = pf("flap_power", 2.2) * pow(1.0 - clampf(pf("power_decay", 0.15), 0.0, 0.9), n - 1)
					set_velocity(Vector2(velocity().x, power))
		"flap":
			if phase_frame >= maxi(pi_("flap_frames", 12), 1):
				_end()
		"hover":
			if phase_frame >= pi_("hover_frames", 90) or not f.input.held(InputFrame.BTN_SPECIAL):
				_end()
		"glide":
			if phase_frame >= pi_("glide_frames", 180) or not f.input.held(InputFrame.BTN_SPECIAL):
				_end()


func _end() -> void:
	var cd: int = pi_("cooldown_between", 0)
	if cd > 0:
		kit.cooldowns[slot] = cd
	finish()


func input() -> void:
	if pb("can_attack_during") and phase != "startup" and not f.grounded:
		if f.check_aerial():
			done = true
			return
	if phase == "hover" and f.input.flick_y(MeleeStick.FAST_FALL_THRESHOLD, MeleeStick.FAST_FALL_WINDOW) == -1:
		done = true
		f.fastfalling = true
		f.change_state("Fall")


func phys() -> void:
	if f.grounded:
		super.phys()
		return
	match phase:
		"startup":
			f.vel.y = maxf(f.vel.y - f.stats.gravity * 0.5, -f.stats.terminal_velocity)
		"flap":
			apply_gravity(1.0)
			var hd: float = pf("h_drift", 1.0)
			f.vel.x = move_toward(f.vel.x, f.stick_x() * hd, f.stats.air_accel_base + f.stats.air_accel_additional)
		"hover":
			f.vel.y = maxf(f.vel.y - f.stats.gravity * pf("hover_gravity_scale", 0.15), -pf("hover_max_fall", 0.4))
			f.apply_air_drift(f.stick_x())
		"glide":
			var vy: float = -pf("glide_fall_speed", 0.6) + f.stick_y() * 0.3
			f.vel = Vector2(f.facing * pf("glide_h_speed", 1.6), minf(vy, 0.0))
		_:
			super.phys()


func on_land() -> void:
	done = true
	f.change_state("Landing", {"lag": maxi(f.stats.normal_landing_lag, 1)})


func ledge_snap_active() -> bool:
	return def.ledge_snap != "none" and phase != "startup"


func default_pose() -> String:
	match phase:
		"glide", "hover":
			return "atk_special_stall"
	return "jump_aerial"
