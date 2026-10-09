class_name StateGrab
extends FighterState
## Grab (Melee Catch / CatchDash): de move "grab" uit de moveset. Grab-hitboxes (ActiveHitbox.is_grab) negeren de
## shield en raken alleen hurtboxes; raak -> GrabHold (CombatSystem -> Fighter.on_grab_landed). Mis = whiff tot het
## einde van de move (total_frames), dan Wait.
## args: dash = dash grab (uit Dash/Run): hitboxes en duur DASH_GRAB_DELAY frames later, bereik × DASH_GRAB_REACH,
## glijdt door met traction ×1.

var dash: bool = false
var move: MoveData
var delay: int = 0


func id() -> String:
	return "Grab"


func debug_name() -> String:
	return "Grab (dash)" if dash else "Grab"


func enter(args: Dictionary) -> void:
	dash = bool(args.get("dash", false))
	move = f.get_move("grab")
	delay = FighterConst.DASH_GRAB_DELAY if dash else 0
	f.start_move()


func total() -> int:
	return (move.total_frames if move != null else 30) + delay


func anim() -> void:
	if move == null or sf() >= total():
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction(not dash)


func hitboxes() -> Array[ActiveHitbox]:
	if move == null:
		return []
	var reach: float = FighterConst.DASH_GRAB_REACH if dash else 1.0
	var out: Array[ActiveHitbox] = []
	for h: HitboxData in move.hitboxes:
		if h.is_active(sf() - delay):
			var p: Vector2 = f.pos + Vector2(h.offset.x * reach * f.facing, h.offset.y)
			var a: ActiveHitbox = ActiveHitbox.make(h, f.player, f.move_instance, p, f.facing)
			a.is_grab = true
			out.append(a)
	return out


func pose() -> String:
	return pick_pose("atk_grab_dash" if dash else "atk_grab", "atk_grab")


func pose_timing() -> Array:
	if move == null:
		return []
	var t: Array = StateAttack.timing_for(move)
	return [int(t[0]) + delay, t[1], int(t[2]) + delay]
