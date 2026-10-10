extends TplDashStrike
## Neutral-B "Last Shot": dash_strike met afstand 0. Geen klassieke windup maar een eet-ritueel (hamburger pakken,
## zout erop strooien, naar binnen schrokken) tijdens de lange startup; daarna één enorme klap op de plek en lang
## hijgen. Kan zich tijdens de startup omdraaien (stick achteruit). Het sjabloon dasht normaal vooruit; hier staat de
## fighter stil (dash_speed 2.0 in de .tres is alleen de ondergrens van de validator, phys() negeert hem).
## Grond en lucht: dezelfde klap; geen helpless (helpless_after = false), landen in de endlag = landing_lag.
## Props (hamburger, zoutvaatje) staan als prop_events in de .tres (frames sinds de knopdruk).

const TURN_COOLDOWN: int = 10

var _turn_cd: int = 0


func step() -> void:
	if _turn_cd > 0:
		_turn_cd -= 1
	super.step()


## Omdraaien tijdens de startup: stick duidelijk tegen de kijkrichting in (zelfde drempel als side-B achteruit).
func input() -> void:
	if phase != "startup" or _turn_cd > 0:
		return
	var sx: float = f.stick_x()
	if sx * f.facing < 0.0 and MeleeStick.reaches(sx, MeleeStick.TURN_THRESHOLD):
		f.facing = -f.facing
		_turn_cd = TURN_COOLDOWN
		present("turn")


func phys() -> void:
	if phase == "dash":
		if f.grounded:
			f.gr_vel = 0.0
		else:
			apply_gravity()
			f.vel.x = 0.0
		return
	super.phys()


func default_pose() -> String:
	match phase:
		"startup":
			return "pep_eat"
		"dash":
			return "pep_haymaker"
		"end":
			return "pep_pant"
	return "idle"


func fallback_pose() -> String:
	return "atk_special_dash"
