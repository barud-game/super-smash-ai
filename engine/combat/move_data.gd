class_name MoveData
extends Resource
## Data van één aanval (normal of special-aanval). Frames 0-based = Fighter.state_frame.

@export var move_name: String = ""
@export var total_frames: int = 30
## Eerste frame waarop de fighter actionable is (IASA); -1 = total_frames.
@export var iasa: int = -1
@export var aerial: bool = false
@export var grounded: bool = true
## Landing lag in frames (aerials) en de L-cancel-waarde (normaal floor(landing_lag / 2)).
@export var landing_lag: int = 0
@export var lcancel_lag: int = 0
## Auto-cancel: landen op frame < autocancel_before of > autocancel_after geeft geen landing lag (-1 = uit).
@export var autocancel_before: int = -1
@export var autocancel_after: int = -1
@export var hitboxes: Array[HitboxData] = []


func iasa_frame() -> int:
	return total_frames if iasa < 0 else iasa


func is_finished(frame: int) -> bool:
	return frame >= total_frames


func has_autocancel(frame: int) -> bool:
	if autocancel_before >= 0 and frame < autocancel_before:
		return true
	if autocancel_after >= 0 and frame > autocancel_after:
		return true
	return false


## Landing lag bij landen op `frame`: 0 bij auto-cancel, lcancel_lag bij L-cancel, anders landing_lag.
func landing_lag_at(frame: int, lcancelled: bool) -> int:
	if has_autocancel(frame):
		return 0
	return lcancel_lag if lcancelled else landing_lag


func last_active_frame() -> int:
	var m: int = -1
	for h in hitboxes:
		m = maxi(m, h.end_frame)
	return m


## Wereldpositie van een hitbox (offset gespiegeld met facing).
static func world_pos(h: HitboxData, origin: Vector2, facing: int) -> Vector2:
	return origin + Vector2(h.offset.x * facing, h.offset.y)


## Actieve hitboxes op dit frame, klaar voor HitResolver.
func active_hitboxes(frame: int, origin: Vector2, facing: int, owner: int, instance: int) -> Array[ActiveHitbox]:
	var out: Array[ActiveHitbox] = []
	for h in hitboxes:
		if h.is_active(frame):
			out.append(ActiveHitbox.make(h, owner, instance, world_pos(h, origin, facing), facing, h.is_late(frame)))
	return out
