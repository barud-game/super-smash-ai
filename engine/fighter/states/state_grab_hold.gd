class_name StateGrabHold
extends FighterState
## GrabHold (Melee CatchWait): de holder houdt de victim vast op de grab-tip (Fighter.place_grab_victim).
## Na GRAB_PULL_FRAMES: stick/C-stick -> Throw (f/b/u/dthrow t.o.v. de kijkrichting), A -> Pummel.
## De grab-timer zit op de victim (StateGrabbed); is die op, dan komen beiden los (Fighter.grab_escape).


func id() -> String:
	return "GrabHold"


func anim() -> void:
	if f.grab_partner == null or not is_instance_valid(f.grab_partner):
		f.change_state("Wait")


func iasa() -> void:
	if f.grab_partner == null or sf() < FighterConst.GRAB_PULL_FRAMES:
		return
	var t: String = f.throw_input()
	if t != "":
		if not f.has_move(t):
			t = "fthrow"
		if f.has_move(t):
			f.change_state("Throw", {"move": t})
			return
	if f.input.pressed(InputFrame.BTN_ATTACK):
		f.change_state("Pummel")


func phys() -> void:
	f.apply_ground_friction()


func coll() -> void:
	super.coll()
	f.place_grab_victim()


func keeps_grab() -> bool:
	return true


func pose() -> String:
	return pick_pose("atk_grab_hold", "idle")
