class_name SonnyDoubleTake
extends TplMultiJump
## Side-B "Double Take": schuine sprong opzij (facing-richting) met een sabelhaal halverwege de sprong.
## Uitbreiding van TplMultiJump (flap): de flap krijgt een vaste horizontale snelheid `side_speed` en de rol
## "slash" (frames relatief aan de flap-fase) als hitbox. Twee keer per airtime (air_use_limit 2 in de .tres);
## de tweede sprong staat los van de eerste haal (raakt of mist, hij kan er altijd achteraan).
## Past niet in het kale sjabloon omdat multi_jump geen hitboxes en geen vaste zijwaartse richting kent.


func phys() -> void:
	if phase == "flap" and not f.grounded:
		apply_gravity(1.0)
		f.vel.x = f.facing * pf("side_speed", 1.7)
		return
	super.phys()


func hitboxes() -> Array[ActiveHitbox]:
	if phase != "flap":
		return []
	return role_boxes("slash", phase_frame)


func default_pose() -> String:
	if phase == "flap" and phase_frame >= 4 and phase_frame <= 10:
		return "atk_special_spin"
	return super.default_pose()
