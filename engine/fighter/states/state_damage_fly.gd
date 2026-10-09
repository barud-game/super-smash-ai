class_name StateDamageFly
extends FighterState
## DamageFly: tumble-launch (KB >= 80). Geen acties tot de hitstun voorbij is; alleen gravity en de afnemende
## knockback-snelheid (DI is al toegepast aan het einde van de hitlag). Daarna DamageFall (tumble, actionable).
## Grondcontact in tumble: tech (shield binnen 20 frames ervoor) of missed tech (Fighter.land_in_tumble()).

var kb: KnockbackResult
var left: int = 0


func id() -> String:
	return "DamageFly"


func debug_name() -> String:
	return "DamageFly (hitstun %d)" % left


func enter(args: Dictionary) -> void:
	kb = args.get("kb")
	left = kb.hitstun if kb != null else 0


func anim() -> void:
	if left <= 0:
		f.change_state("DamageFall")
		return
	left -= 1


func phys() -> void:
	f.vel.x = move_toward(f.vel.x, 0.0, f.stats.air_friction)
	f.vel.y = maxf(f.vel.y - f.stats.gravity, -f.stats.terminal_velocity)


func is_grounded() -> bool:
	return f.grounded


func stops_at_edge() -> bool:
	return false


func on_land() -> void:
	f.land_in_tumble()


func pose() -> String:
	return "damage_fly" if sf() < 8 else "tumble"


func pose_frame() -> int:
	return sf() if sf() < 8 else sf() - 8
