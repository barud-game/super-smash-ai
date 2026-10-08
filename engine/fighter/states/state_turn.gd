class_name StateTurn
extends FighterState
## Turn (staand omdraaien). Kijkrichting draait bij binnenkomst om.
## - Smash-turn (binnengekomen met een dash-flick): op frame 1 stick nog >= dash-drempel in de nieuwe
##   richting -> Dash (dashback / dash-dance). Anders is het een pivot: rest van de turn actionable.
## - Tilt-turn: in vanilla Melee geen dash uit de turn. UCF-dashback: haalt de stick op frame 1 alsnog
##   de dash-drempel binnen het flick-venster, dan toch Dash.

var smash: bool = false


func id() -> String:
	return "Turn"


func debug_name() -> String:
	return "Turn (smash)" if smash else "Turn"


func enter(args: Dictionary) -> void:
	smash = args.get("smash", false)
	f.facing = -f.facing


func anim() -> void:
	if sf() >= f.stats.turn_frames:
		f.change_state("Wait")


func iasa() -> void:
	if f.check_ground_jump():
		return
	if sf() == 1:
		var sx: float = f.stick_x()
		if smash and sx * f.facing > 0.0 and MeleeStick.reaches(sx, MeleeStick.SMASH_THRESHOLD):
			f.change_state("Dash")
			return
	# ⚠️ Leniency (UCF-achtig): in elke Turn-frame geeft een dash-flick in de nieuwe richting een Dash
	# (tilt-turn niet meer op slot; voorkomt "stick terugveer -> Turn -> dash lukt niet" op Xbox).
	if (smash or f.ucf_dashback) \
			and f.input.flick_x(MeleeStick.SMASH_THRESHOLD, MeleeStick.DASH_FLICK_WINDOW) == f.facing:
		f.change_state("Dash")
		return
	if smash and sf() >= 1:
		# Pivot: smash-turn zonder dash is direct actionable.
		f.check_wait_interrupts()
		return
	f.check_squat()


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return "turn"
