class_name StateShieldBreak
extends FighterState
## ShieldBreak (Melee ShieldBreakFly/Fall): shield-HP op. Omhoog gelanceerd (SHIELD_BREAK_VY ⚠️), geen drift en geen
## acties; gravity tot de grond. Landen -> ShieldBreakDown. Kwetsbaar.


func id() -> String:
	return "ShieldBreak"


func enter(_args: Dictionary) -> void:
	f.leave_ground(Vector2(0.0, FighterConst.SHIELD_BREAK_VY))
	f.air_jumps_used = f.stats.air_jumps


func phys() -> void:
	f.vel.x = move_toward(f.vel.x, 0.0, f.stats.air_friction)
	f.vel.y = maxf(f.vel.y - f.stats.gravity, -f.stats.terminal_velocity)


func is_grounded() -> bool:
	return false


func on_land() -> void:
	f.change_state("ShieldBreakDown")


func pose() -> String:
	return pick_pose("tumble", "fall")
