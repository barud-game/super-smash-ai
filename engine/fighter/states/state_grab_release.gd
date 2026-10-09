class_name StateGrabRelease
extends FighterState
## GrabRelease (Melee CatchCut / CaptureCut): beide kanten na een grond-release (grab-timer op, of de grab werd
## verbroken). args: push = gr_vel (weg van de ander). GRAB_RELEASE_FRAMES geen acties ⚠️, dan Wait.
## In de lucht (bv. van de rand geduwd): gravity, landen loopt gewoon door.


func id() -> String:
	return "GrabRelease"


func enter(args: Dictionary) -> void:
	if f.grounded:
		f.gr_vel = float(args.get("push", 0.0))
	else:
		f.vel.x = float(args.get("push", 0.0))


func anim() -> void:
	if sf() >= FighterConst.GRAB_RELEASE_FRAMES:
		f.change_state("Wait" if f.grounded else "Fall")


func phys() -> void:
	if f.grounded:
		f.apply_ground_friction(false)
	else:
		f.vel.x = move_toward(f.vel.x, 0.0, f.stats.air_friction)
		f.vel.y = maxf(f.vel.y - f.stats.gravity, -f.stats.terminal_velocity)


func is_grounded() -> bool:
	return f.grounded


func stops_at_edge() -> bool:
	return false


func on_land() -> void:
	pass


func pose() -> String:
	return pick_pose("damage_low", "idle")
