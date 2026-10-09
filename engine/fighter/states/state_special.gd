class_name StateSpecial
extends FighterState
## Special (neutral/side/up/down-B): generieke host voor een SpecialMove-runner (sjabloon of eigen script).
## Grond en lucht in één state: is_grounded() volgt de fighter, landen/van de rand gaan via de runner.
## args: move (SpecialMove, al gekoppeld aan fighter/def/kit). Starten via Specials.try_start(). Zie docs/specials.md.

var move: SpecialMove


func id() -> String:
	return "Special"


func debug_name() -> String:
	if move == null:
		return "Special"
	return "Special (%s %s)" % [move.def.slot if move.def != null else "?", move.debug_text()]


func enter(args: Dictionary) -> void:
	move = args.get("move")
	if move == null:
		return
	move.host = self
	move.begin()


func exit() -> void:
	if move == null:
		return
	# Geraakt worden: Fighter.receive_hit zet _victim_tick op dit frame vóór de state-wissel.
	move.interrupted = f._victim_tick == f.tick_count
	var m: SpecialMove = move
	move = null
	m.on_exit()
	# Geen RefCounted-cyclus (state <-> runner) laten staan.
	m.host = null


## Vervang de runner (charge-release, sequentie, follow-up). De state blijft "Special".
func swap(next: SpecialMove, prev: SpecialMove) -> void:
	prev.done = true
	prev.on_exit()
	prev.host = null
	move = next
	next.host = self
	next.begin_linked(prev)


func anim() -> void:
	if move == null:
		f.change_state("Fall" if not f.grounded else "Wait")
		return
	move.anim()


func iasa() -> void:
	if move != null and f.state == self:
		move.iasa()


func phys() -> void:
	if move != null and f.state == self:
		move.phys()


func coll() -> void:
	if move == null or f.state != self:
		return
	if f.grounded:
		_gv_pre = f.gr_vel
		f.ground_coll()
	else:
		f.air_coll()
		if f.state == self and not f.grounded and move.ledge_snap_active():
			SpecialGeometry.try_ledge_snap(f, move.def.ledge_snap_range, move.ledge_snap_rising())


## gr_vel van vóór ground_coll() (die zet hem op 0 bij een rand-stop).
var _gv_pre: float = 0.0


func is_grounded() -> bool:
	return f.grounded


## Altijd stoppen: de runner beslist in on_edge() of de fighter eraf glijdt (geen automatische Fall).
func stops_at_edge() -> bool:
	return true


func on_edge_stop(side: int) -> void:
	if move != null:
		move.on_edge(side, _gv_pre)


func lands_on_platforms() -> bool:
	return move == null or move.lands_on_platforms()


func on_land() -> void:
	if move != null:
		move.on_land()
	else:
		f.change_state("Landing")


## Ledge-snap doet de runner zelf (eigen bereik, stijg-regel); de standaard fighter-check niet.
func can_grab_ledge() -> bool:
	return false


func intangible() -> bool:
	return move != null and (move.intangible() or move.intercepting())


func hitboxes() -> Array[ActiveHitbox]:
	if move == null:
		return []
	return move.hitboxes()


func pose() -> String:
	return move.pose() if move != null else "idle"


func pose_timing() -> Array:
	return move.pose_timing() if move != null else []


func pose_frame() -> int:
	return move.pose_frame() if move != null else sf()


## Rekwisieten van de special-definitie (SpecialDef.prop_events), frames sinds de knopdruk.
func props() -> Array:
	if move == null or move.def == null or move.def.prop_events.is_empty():
		return []
	return PropEvent.active(move.def.prop_events, f.state_frame)
