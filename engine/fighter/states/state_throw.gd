class_name StateThrow
extends FighterState
## Throw (Melee ThrowF/B/Hi/Lw): args move = "fthrow" / "bthrow" / "uthrow" / "dthrow" uit de moveset.
## De victim staat in Thrown en volgt de holder tot het launch-frame = het start_frame van de throw-hitbox
## (afspraak 3: round(totaal × 0.5)). Dan Fighter.queue_throw() -> throw_victim() (post-tick): knockback van die hitbox,
## kan niet missen, DI ja.
## Einde van de move (total_frames) -> Wait.

var move_name: String = ""
var move: MoveData
var launch_frame: int = 0
var launch_box: HitboxData = null
var thrown: bool = false


func id() -> String:
	return "Throw"


func debug_name() -> String:
	return "Throw (%s)" % move_name


func enter(args: Dictionary) -> void:
	move_name = args.get("move", "fthrow")
	move = f.get_move(move_name)
	thrown = false
	launch_box = launch_hitbox(move)
	launch_frame = launch_frame_for(move)
	f.start_move()
	var v: Fighter = f.grab_partner
	if v != null and is_instance_valid(v):
		v.change_state("Thrown")


## De throw-hitbox die lanceert: vroegste start_frame, bij gelijk de laagste id.
static func launch_hitbox(m: MoveData) -> HitboxData:
	if m == null:
		return null
	var best: HitboxData = null
	for h: HitboxData in m.hitboxes:
		if best == null or h.start_frame < best.start_frame or (h.start_frame == best.start_frame and h.id < best.id):
			best = h
	return best


## Launch-frame (0-based state-frame): start_frame van de throw-hitbox; zonder hitbox round(totaal × 0.5).
static func launch_frame_for(m: MoveData) -> int:
	if m == null:
		return 0
	var h: HitboxData = launch_hitbox(m)
	return h.start_frame if h != null else int(round(m.total_frames * 0.5))


func anim() -> void:
	if not thrown and sf() >= launch_frame:
		thrown = true
		f.queue_throw(launch_box)   # launch in de combat-stap van deze frame (Fighter.apply_grab_actions)
	if move == null or sf() >= move.total_frames:
		f.change_state("Wait")


func phys() -> void:
	f.apply_ground_friction()


func coll() -> void:
	super.coll()
	if not thrown:
		f.place_grab_victim()


func keeps_grab() -> bool:
	return true


func pose() -> String:
	return pick_pose("atk_" + move_name, "atk_grab_hold")


func pose_timing() -> Array:
	if move == null:
		return []
	return [launch_frame, 1, move.total_frames]
