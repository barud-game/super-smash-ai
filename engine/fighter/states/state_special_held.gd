class_name StateSpecialHeld
extends FighterState
## SpecialHeld: slachtoffer van een command grab / tether-pull (bouwsteen 12, eenvoudige vasthoud-fase zolang
## de M4-grab-states er niet zijn). Geen controle, intangible voor derden, positie volgt de vasthouder
## (`holder.pos + offset`, x gespiegeld met diens facing). Breakout (optioneel): elke nieuwe knop/stick-flick
## telt; genoeg = loskomen. De vasthouder beëindigt de hold met een worp (Fighter.receive_hit) of release().
## args: holder (Fighter), offset (Vector2), breakout (int, 0 = geen), max_frames (int, vangnet).

var holder: Fighter
var offset: Vector2 = Vector2(8.0, 0.0)
var breakout_needed: int = 0
var mash: int = 0
var max_frames: int = 300
var released: bool = false


func id() -> String:
	return "SpecialHeld"


func debug_name() -> String:
	return "SpecialHeld (mash %d/%d)" % [mash, breakout_needed] if breakout_needed > 0 else "SpecialHeld"


func enter(args: Dictionary) -> void:
	holder = args.get("holder")
	offset = args.get("offset", Vector2(8.0, 0.0))
	breakout_needed = int(args.get("breakout", 0))
	max_frames = int(args.get("max_frames", 300))
	mash = 0
	released = false
	f.vel = Vector2.ZERO
	f.kb_vel = Vector2.ZERO
	f.gr_vel = 0.0
	f.fastfalling = false
	_follow()


func _holder_ok() -> bool:
	return holder != null and is_instance_valid(holder) and holder.active and holder.state_name() == "Special"


func anim() -> void:
	if not _holder_ok() or sf() >= max_frames:
		release()
		return
	if breakout_needed > 0 and mash >= breakout_needed:
		release()


func iasa() -> void:
	if breakout_needed <= 0:
		return
	var inp: InputHistory = f.input
	for b: int in [InputFrame.BTN_ATTACK, InputFrame.BTN_SPECIAL, InputFrame.BTN_JUMP, InputFrame.BTN_SHIELD]:
		if inp.pressed(b):
			mash += 1
	if inp.flick_x(MeleeStick.SMASH_THRESHOLD, 2) != 0 or inp.flick_y(MeleeStick.SMASH_THRESHOLD, 2) != 0:
		mash += 1


func phys() -> void:
	_follow()


func coll() -> void:
	pass


func _follow() -> void:
	if holder == null or not is_instance_valid(holder):
		return
	f.pos = holder.pos + Vector2(offset.x * holder.facing, offset.y)
	f.facing = -holder.facing
	f.grounded = false
	f.ground_seg = -1


## Loslaten zonder worp: op de grond Wait, anders Fall.
func release() -> void:
	if released:
		return
	released = true
	var segs: Array = SpecialGeometry.segments(f.stage)
	var seg: int = SpecialGeometry.surface_at(segs, f.pos, 0.6)
	if seg >= 0:
		f.finish_ledge_move(f.pos)
	else:
		f.change_state("Fall")


func is_grounded() -> bool:
	return false


func intangible() -> bool:
	return true


func pose() -> String:
	return pick_pose("grabbed", "damage_low")
