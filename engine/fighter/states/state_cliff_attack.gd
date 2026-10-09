class_name StateCliffAttack
extends StateCliffMove
## CliffAttack (ledge attack, A). Beweegt als een getup; de hitbox komt uit move "ledge_attack" (< 100%) of
## "ledge_attack_slow" (≥ 100%) in Fighter.moves: een bestand van het archetype/character, anders ingebouwd
## (MoveSet.builtin, actief vanaf opt["hit"]). Frames van die move = state-frames van CliffAttack.

var move: MoveData


func id() -> String:
	return "CliffAttack"


func kind() -> String:
	return "attack"


func enter(args: Dictionary) -> void:
	super.enter(args)
	move = f.get_move("ledge_attack_slow" if high else "ledge_attack")
	f.start_move()


func hitboxes() -> Array[ActiveHitbox]:
	if move == null:
		return []
	return move.active_hitboxes(sf(), f.pos, f.facing, f.player, f.move_instance)


func pose() -> String:
	return pick_pose("cliff_attack", "jump")


func pose_timing() -> Array:
	if move == null:
		return []
	var t: Array = StateAttack.timing_for(move)
	t[2] = int(opt["frames"])
	return t


func pose_speed() -> float:
	return 1.0
