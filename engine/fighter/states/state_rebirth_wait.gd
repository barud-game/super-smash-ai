class_name StateRebirthWait
extends FighterState
## RebirthWait: stilstaan op het respawn-platform (Melee: Rebirth/RebirthWait). Geen gravity, geen collision.
## Eindigt op input (na REBIRTH_MIN_FRAMES) of na REBIRTH_MAX_FRAMES met Fall; alle sprongen beschikbaar.
## De invincibility zit in Fighter.intangible_frames (gezet door respawn_at) en loopt door na het platform.
## ⚠️ duur (300), minimale wachttijd (20) en invincibility (120) zijn schattingen.


func id() -> String:
	return "RebirthWait"


func enter(_args: Dictionary) -> void:
	f.vel = Vector2.ZERO
	f.grounded = false
	f.ground_seg = -1


func anim() -> void:
	if sf() >= FighterConst.REBIRTH_MAX_FRAMES:
		_leave()


func iasa() -> void:
	if sf() < FighterConst.REBIRTH_MIN_FRAMES:
		return
	var fr: InputFrame = f.input.get_frame(0)
	if fr.stick != Vector2i.ZERO or fr.buttons != 0:
		_leave()


func _leave() -> void:
	f.vel = Vector2.ZERO
	f.air_jumps_used = 0
	f.change_state("Fall")


func phys() -> void:
	pass


func coll() -> void:
	pass


func is_grounded() -> bool:
	return false


func pose() -> String:
	return pick_pose("respawn_platform", "idle")
