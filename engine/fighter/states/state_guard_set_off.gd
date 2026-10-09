class_name StateGuardSetOff
extends FighterState
## GuardSetOff: shieldstun van de verdediger (Melee). args: stun (frames, Knockback.shieldstun_frames met de analoge
## stand), push (gr_vel, weg van de hitbox). Geen acties; pushback remt met traction ×1. Daarna Guard (nog vast) of
## GuardOff. De hitlag gaat eraan vooraf (Fighter.on_shield_hit); de stun telt pas daarna.

var stun: int = 0


func id() -> String:
	return "GuardSetOff"


func debug_name() -> String:
	return "GuardSetOff (stun %d)" % stun


func enter(args: Dictionary) -> void:
	stun = int(args.get("stun", 0))
	f.gr_vel = float(args.get("push", 0.0))


func anim() -> void:
	if sf() >= stun:
		f.change_state("Guard" if f.shield_held() else "GuardOff")


func phys() -> void:
	f.apply_ground_friction(false)


func is_shielding() -> bool:
	return true


func pose() -> String:
	return pick_pose("shield_stun", "shield")
