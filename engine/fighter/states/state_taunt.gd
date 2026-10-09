class_name StateTaunt
extends FighterState
## Taunt (Melee: D-pad omhoog). Alleen vanuit Wait (stilstaan op de grond); niet cancelbaar: pas actionable als de
## animatie klaar is (daarna Wait). Wel te raken (gewone hurtbox). Duur: `taunt_frames` uit character.json, anders
## FighterConst.TAUNT_FRAMES. Presentatie: pose `taunt` (character-eigen of gedeeld), tekstwolkje met `taunt_text`
## (Fighter.bubble_text) en optionele `taunt_props` (PropEvent). Zie docs/rig.md §9 / docs/character-creatie.md.

## Nominale lengte van de gedeelde pose `taunt` (poses/combat.json) als de visual hem niet kent.
const POSE_LENGTH_FALLBACK: float = 80.0

var duration: int = FighterConst.TAUNT_FRAMES


func id() -> String:
	return "Taunt"


func enter(_args: Dictionary) -> void:
	duration = CharacterLoader.taunt_frames(f.character_id)


func anim() -> void:
	if sf() >= duration:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return pick_pose("taunt", "idle")


func pose_speed() -> float:
	var length: float = POSE_LENGTH_FALLBACK
	if f.visual != null and f.visual.has_pose("taunt"):
		length = maxf(f.visual.pose_length("taunt"), 1.0)
	return length / float(maxi(duration, 1))


## Tekst van het wolkje op dit frame ("" = geen wolkje): vanaf TAUNT_BUBBLE_IN tot TAUNT_BUBBLE_OUT frames vóór het einde.
func bubble_text() -> String:
	if sf() < FighterConst.TAUNT_BUBBLE_IN or sf() >= duration - FighterConst.TAUNT_BUBBLE_OUT:
		return ""
	return CharacterLoader.taunt_text(f.character_id)


func props() -> Array:
	return PropEvent.active(CharacterLoader.taunt_props(f.character_id), sf())
