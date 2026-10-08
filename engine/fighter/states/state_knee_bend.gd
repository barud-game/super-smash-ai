class_name StateKneeBend
extends FighterState
## KneeBend (jumpsquat). Duurt jumpsquat_frames frames (frame 0 = het frame van de input).
## Short hop als de jump-knop wordt losgelaten op frame 1 .. jumpsquat-1 (venster = jumpsquat - 1);
## bij tap jump: als stick-y onder de loslaat-drempel zakt. Daarna Jump (gr_vel -> lucht via formule).

var tap: bool = false
var short_hop: bool = false


func id() -> String:
	return "KneeBend"


func debug_name() -> String:
	return "KneeBend (%s%s)" % ["tap" if tap else "knop", ", SH" if short_hop else ""]


func enter(args: Dictionary) -> void:
	tap = args.get("tap", false)
	short_hop = false


func anim() -> void:
	if sf() >= f.stats.jumpsquat_frames:
		f.ground_jump(short_hop)
		f.change_state("Jump", {"short": short_hop})


func iasa() -> void:
	if sf() < 1:
		return
	if tap:
		if f.stick_y() < MeleeStick.TAP_JUMP_RELEASE_THRESHOLD - FighterConst.EPS:
			short_hop = true
	elif not f.input.held(InputFrame.BTN_JUMP):
		short_hop = true


func phys() -> void:
	f.apply_ground_friction()


func pose() -> String:
	return "jumpsquat"
