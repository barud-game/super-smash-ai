class_name StateEscapeAir
extends FighterState
## EscapeAir (Melee air dodge). Bij start: stick neutraal -> vel = 0, anders vel = force * (cos t, sin t)
## met t = stickhoek (magnitude telt niet). Daarna vel *= decay tot airdodge_decay_end, dan alleen gravity.
## Intangible op frames airdodge_intangible_start..end. Einde -> FallSpecial. Landen -> LandingFallSpecial
## (wavedash/waveland, 10 frames).


func id() -> String:
	return "EscapeAir"


func enter(_args: Dictionary) -> void:
	var s: Vector2 = f.stick()
	f.fastfalling = false
	if s == Vector2.ZERO:
		f.vel = Vector2.ZERO
	else:
		var a: float = atan2(s.y, s.x)
		f.vel = Vector2(cos(a), sin(a)) * f.stats.airdodge_force


func anim() -> void:
	if sf() >= f.stats.airdodge_frames:
		f.change_state("FallSpecial")


func phys() -> void:
	if sf() == 0:
		return
	if sf() < f.stats.airdodge_decay_end:
		f.vel *= f.stats.airdodge_decay
	else:
		f.apply_air_vertical(false)


func is_grounded() -> bool:
	return false


func on_land() -> void:
	f.change_state("LandingFallSpecial", {"lag": f.stats.airdodge_landing_lag})


func intangible() -> bool:
	var n: int = sf() + 1
	return n >= f.stats.airdodge_intangible_start and n <= f.stats.airdodge_intangible_end


func pose() -> String:
	return "airdodge"
