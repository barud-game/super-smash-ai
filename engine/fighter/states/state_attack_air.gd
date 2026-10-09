class_name StateAttackAir
extends FighterState
## AttackAir: aerial (nair/fair/bair/uair/dair), gestuurd door MoveData. Air drift, gravity en fast fall
## werken door (zoals Melee). Einde animatie -> Fall; vanaf IASA weer aerials/air dodge/double jump.
## Landen: auto-cancel-venster -> normale landing lag; anders aerial landing lag, gehalveerd (L-cancel) als
## L/R/Z binnen 7 frames vóór de landing is ingedrukt. Geen ledge grab tijdens een aerial (Melee).

var move_name: String = ""
var move: MoveData


func id() -> String:
	return "AttackAir"


func debug_name() -> String:
	return "AttackAir (%s)" % move_name


func enter(args: Dictionary) -> void:
	move_name = args.get("move", "")
	move = f.get_move(move_name)
	f.start_move()


func move_frame() -> int:
	return sf()


func anim() -> void:
	if move == null or sf() >= move.total_frames:
		f.change_state("Fall")


func iasa() -> void:
	if move != null and sf() >= move.iasa_frame():
		if not f.check_aerial():
			f.check_air_interrupts()


func phys() -> void:
	f.apply_air_physics()


func is_grounded() -> bool:
	return false


## Landing lag op dit frame: auto-cancel = normale landing lag; L-cancel = lcancel_lag (of floor(lag/2), min 1).
static func landing_lag_for(m: MoveData, frame: int, lcancelled: bool, normal_lag: int) -> int:
	if m == null or m.has_autocancel(frame) or m.landing_lag <= 0:
		return normal_lag
	if lcancelled:
		var lc: int = m.lcancel_lag if m.lcancel_lag > 0 else m.landing_lag / 2
		return maxi(lc, 1)
	return m.landing_lag


func on_land() -> void:
	var auto: bool = move == null or move.has_autocancel(sf())
	var lc: bool = not auto and f.lcancel_ready()
	var lag: int = landing_lag_for(move, sf(), lc, f.stats.normal_landing_lag)
	f.change_state("Landing", {"lag": lag, "aerial": move_name, "lcancel": lc})


func hitboxes() -> Array[ActiveHitbox]:
	if move == null:
		return []
	return move.active_hitboxes(sf(), f.pos, f.facing, f.player, f.move_instance)


func pose() -> String:
	return pick_pose(StateAttack.attack_pose(move_name), "atk_nair")


func pose_timing() -> Array:
	return StateAttack.timing_for(move) if move != null else []
