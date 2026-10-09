class_name StateDamage
extends FighterState
## Damage: hitstun zonder tumble (KB < 80; Melee DamageN/DamageAir, kleine flinch). Geen acties tot de
## hitstun op is. Grond: glijden met wrijving. Lucht: gravity + knockback-snelheid, geen drift of fast fall.
## args: kb (KnockbackResult). De launch zelf zet Fighter._launch() aan het einde van de hitlag.
## Hitstun telt vanaf het eerste frame na de hitlag: N frames geen actie, op frame N+1 actionable.

var kb: KnockbackResult
var left: int = 0


func id() -> String:
	return "Damage"


func debug_name() -> String:
	return "Damage (hitstun %d)" % left


func enter(args: Dictionary) -> void:
	kb = args.get("kb")
	left = kb.hitstun if kb != null else 0


func anim() -> void:
	if left <= 0:
		f.change_state("Wait" if f.grounded else "Fall")
		return
	left -= 1


func phys() -> void:
	if f.grounded:
		f.apply_ground_friction()
	else:
		f.vel.x = move_toward(f.vel.x, 0.0, f.stats.air_friction)
		f.vel.y = maxf(f.vel.y - f.stats.gravity, -f.stats.terminal_velocity)


func is_grounded() -> bool:
	return f.grounded


func stops_at_edge() -> bool:
	return false


## Landen tijdens niet-tumble-hitstun: de hitstun loopt op de grond door.
func on_land() -> void:
	pass


func pose() -> String:
	var k: float = kb.kb if kb != null else 0.0
	if k < FighterConst.DAMAGE_POSE_MID_KB:
		return "damage_low"
	if k < FighterConst.DAMAGE_POSE_HIGH_KB:
		return "damage_mid"
	return "damage_high"
