class_name InputHistory
extends RefCounted
## Ringbuffer van de laatste InputFrames van één speler, plus query-helpers.
## Index 0 = nieuwste frame, 1 = vorige, enz.

const SIZE: int = 32

var _buf: Array = []
var _head: int = 0  # volgende schrijfpositie
var _count: int = 0


func _init() -> void:
	_buf.resize(SIZE)


func push(frame: InputFrame) -> void:
	_buf[_head] = frame
	_head = (_head + 1) % SIZE
	_count = mini(_count + 1, SIZE)


func count() -> int:
	return _count


## Frame `back` frames geleden (0 = nieuwste). Geeft een neutraal frame buiten bereik.
func get_frame(back: int = 0) -> InputFrame:
	if back < 0 or back >= _count:
		return InputFrame.new()
	return _buf[(_head - 1 - back + SIZE * 2) % SIZE]


func held(button: int) -> bool:
	return get_frame(0).has(button)


func pressed(button: int) -> bool:
	return get_frame(0).has(button) and not get_frame(1).has(button)


func released(button: int) -> bool:
	return not get_frame(0).has(button) and get_frame(1).has(button)


func stick_smashed_x(frames_window: int) -> bool:
	return _smashed(frames_window, true)


func stick_smashed_y(frames_window: int) -> bool:
	return _smashed(frames_window, false)


## True als de stick binnen de laatste `frames_window` frames van onder SMASH_LOW naar >= SMASH_HIGH
## ging (zelfde richting), en het nieuwste frame nog >= SMASH_HIGH staat.
func _smashed(frames_window: int, horizontal: bool) -> bool:
	var window: int = mini(frames_window, _count - 1)
	if window < 1:
		return false
	var cur: float = _axis(0, horizontal)
	if absf(cur) < MeleeStick.SMASH_HIGH:
		return false
	for back in range(1, window + 1):
		if absf(_axis(back, horizontal)) < MeleeStick.SMASH_LOW:
			return true
		# Tegengestelde richting telt als doorgeslagen vanaf neutraal niet; stop zodra het teken omkeert.
		if _axis(back, horizontal) * cur < 0.0:
			return false
	return false


func _axis(back: int, horizontal: bool) -> float:
	var s: Vector2 = get_frame(back).stick_f()
	return s.x if horizontal else s.y
