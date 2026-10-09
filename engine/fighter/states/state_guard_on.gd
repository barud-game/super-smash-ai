class_name StateGuardOn
extends FighterState
## GuardOn: shield opzetten (Melee GuardOn). De shield staat vanaf frame 0. GUARD_ON_FRAMES lang (⚠️ minimale
## shield-tijd), daarna Guard (nog vast) of GuardOff (losgelaten). OoS-opties werken al (Fighter.check_oos()).
## Powershield: een digitale klik in de eerste POWERSHIELD_WINDOW frames (Fighter.powershield_active()).


func id() -> String:
	return "GuardOn"


func debug_name() -> String:
	return "GuardOn (powershield)" if f.powershield_active() else "GuardOn"


func anim() -> void:
	if f.drain_shield():
		return
	if sf() >= FighterConst.GUARD_ON_FRAMES:
		f.change_state("Guard" if f.shield_held() else "GuardOff")


func iasa() -> void:
	f.check_oos()


func phys() -> void:
	# Shield uit een run/wavedash glijdt uit met traction (×2 boven walk speed, zoals Wait).
	f.apply_ground_friction()


func is_shielding() -> bool:
	return true


func pose() -> String:
	return pick_pose("shield", "crouch")
