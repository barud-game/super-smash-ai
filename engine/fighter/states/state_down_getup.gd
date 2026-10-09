class_name StateDownGetup
extends FighterState
## DownGetup: opstaan na een missed tech. kind = "stand" (DownStand), "roll" (DownForward/Back, dir = wereldrichting)
## of "attack" (DownAttack, move "getup_attack" uit Fighter.moves, raakt voor en achter). Begin intangible,
## daarna Wait. Duur/intangibility/afstand ⚠️ in FighterConst.

var kind: String = "stand"
var dir: int = 1
var move: MoveData


func id() -> String:
	return "DownGetup"


func debug_name() -> String:
	return "DownGetup (%s)" % kind


func enter(args: Dictionary) -> void:
	kind = args.get("kind", "stand")
	dir = int(args.get("dir", f.facing))
	move = null
	f.gr_vel = 0.0
	if kind == "attack":
		move = f.get_move("getup_attack")
		f.start_move()


func total() -> int:
	match kind:
		"roll":
			return FighterConst.GETUP_ROLL_FRAMES
		"attack":
			return move.total_frames if move != null else FighterConst.GETUP_ATTACK_FRAMES
	return FighterConst.GETUP_STAND_FRAMES


func anim() -> void:
	if sf() >= total():
		f.change_state("Wait")


func phys() -> void:
	if kind == "roll" and sf() < FighterConst.GETUP_ROLL_FRAMES - 8:
		f.gr_vel = dir * FighterConst.GETUP_ROLL_DISTANCE / float(FighterConst.GETUP_ROLL_FRAMES - 8)
	else:
		f.gr_vel = 0.0


func intangible() -> bool:
	var end: int = FighterConst.GETUP_STAND_INTANGIBLE_END
	if kind == "roll":
		end = FighterConst.GETUP_ROLL_INTANGIBLE_END
	elif kind == "attack":
		end = FighterConst.GETUP_ATTACK_INTANGIBLE_END
	return sf() + 1 <= end


func hitboxes() -> Array[ActiveHitbox]:
	if move == null:
		return []
	return move.active_hitboxes(sf(), f.pos, f.facing, f.player, f.move_instance)


func hurtbox_shape() -> String:
	return "lie" if sf() < 10 else "stand"


func pose() -> String:
	if kind == "roll":
		return "roll_forward" if dir == f.facing else "roll_back"
	return "getup_from_lie"


func pose_speed() -> float:
	var length: float = 28.0 if kind == "roll" else 30.0
	return length / float(maxi(total(), 1))
