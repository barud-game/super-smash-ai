class_name TplTeleport
extends SpecialMove
## Sjabloon `teleport` (§3): startup -> vanish (onzichtbaar, intangible, geen gravity/collision) -> verplaatsen
## (SpecialGeometry.resolve_target: solide blokken, blast zone toegestaan) -> arrival (intangible, optionele
## hitbox) -> endlag -> helpless (def.helpless_after). Rollen: "departure" (frames relatief aan vanish),
## "arrival" (relatief aan arrival). Afstand begrensd op 260 units (director-besluit 2).

const DEFAULTS: Dictionary = {
	"startup": 10, "distance": 120.0, "direction_mode": "stick_8dir", "fixed_angle": 90.0, "neutral_angle": 90.0,
	"n_dir": 8, "vanish_frames": 8, "arrival_frames": 3, "direction_lock": "end", "target_validation": "snap_to_valid",
	"can_cross_walls": true, "momentum_after": "zero", "exit_speed": 1.0, "endlag": 20, "gravity_scale": 0.3,
	"momentum_air": "scale", "momentum_scale": 0.3,
}

var dir: Vector2 = Vector2(0.0, 1.0)
var from_pos: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var arrived_pos: Vector2 = Vector2.ZERO
var fizzled: bool = false
var _pre_vel: Vector2 = Vector2.ZERO


func defaults() -> Dictionary:
	return DEFAULTS


func start() -> void:
	set_phase("startup")


func distance() -> float:
	return minf(pf("distance", 120.0), SpecialGeometry.TELEPORT_MAX_DISTANCE)


func _aim() -> Vector2:
	var mode: String = ps("direction_mode", "stick_8dir")
	var neutral: float = pf("fixed_angle", 90.0) if mode == "fixed" else pf("neutral_angle", 90.0)
	return SpecialAim.direction(f.stick(), mode, f.facing, neutral, pi_("n_dir", 8))


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				_pre_vel = velocity()
				from_pos = f.pos
				if ps("direction_lock", "end") == "start":
					dir = _aim()
				set_phase("vanish")
				set_hidden(true)
		"vanish":
			if ps("direction_lock", "end") == "end":
				dir = _aim()
			if phase_frame >= maxi(pi_("vanish_frames", 8), 1):
				_arrive()
		"arrival":
			if phase_frame >= pi_("arrival_frames", 3):
				set_phase("end")
		"end":
			if phase_frame >= endlag_frames():
				finish()


func _arrive() -> void:
	var segs: Array = SpecialGeometry.segments(f.stage)
	target = from_pos + dir * distance()
	var r: Dictionary = SpecialGeometry.resolve_target(segs, from_pos, target, ps("target_validation", "snap_to_valid"),
		pb("can_cross_walls", true))
	fizzled = not bool(r["ok"])
	arrived_pos = r["pos"]
	set_hidden(false)
	if f.grounded:
		f.leave_ground(Vector2.ZERO)
	f.pos = arrived_pos + Vector2(0.0, 0.01)
	if dir.x != 0.0 and absf(dir.x) > 0.3:
		f.facing = 1 if dir.x > 0.0 else -1
	match ps("momentum_after", "zero"):
		"keep_pre":
			f.vel = _pre_vel
		"exit_velocity":
			f.vel = dir * pf("exit_speed", 1.0)
		_:
			f.vel = Vector2.ZERO
	set_phase("arrival")


func phys() -> void:
	if phase == "vanish":
		f.vel = Vector2.ZERO
		f.gr_vel = 0.0
		return
	if phase == "arrival" and not f.grounded:
		return
	super.phys()


func is_end_phase() -> bool:
	return phase == "arrival" or phase == "end"


func intangible() -> bool:
	return super.intangible() or phase == "vanish" or phase == "arrival"


func on_land() -> void:
	if phase == "vanish":
		return
	super.on_land()


func hitboxes() -> Array[ActiveHitbox]:
	match phase:
		"vanish":
			return boxes(def.hits("departure"), phase_frame, from_pos)
		"arrival":
			return role_boxes("arrival", phase_frame)
	return []


func lands_on_platforms() -> bool:
	# Aankomst: alleen landen op een platform als de fighter van boven komt (dalend); anders erdoorheen.
	return super.lands_on_platforms() and (phase != "arrival" or dir.y <= 0.0)


func default_pose() -> String:
	return "airdodge" if phase == "vanish" or phase == "startup" else "fall"


func debug_text() -> String:
	return "teleport:%s f%d" % [phase, phase_frame]
