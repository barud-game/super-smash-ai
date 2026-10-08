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


## Melee-teller "frames sinds de stick de deadzone verliet" voor de x-as (0 = dit frame).
## Telt per richting: van links naar rechts in één frame reset de teller ook (de vorige waarde stond
## niet aan deze kant buiten de deadzone). In de deadzone: MeleeStick.TIMER_NEUTRAL.
func stick_timer_x(back: int = 0) -> int:
	return _timer(back, true)


func stick_timer_y(back: int = 0) -> int:
	return _timer(back, false)


## Flick op de x-as: |x| >= drempel en teller < venster. Geeft de richting (+1/-1) of 0.
func flick_x(threshold: float, window: int) -> int:
	return _flick(threshold, window, true)


## Flick op de y-as: |y| >= drempel en teller < venster. Geeft de richting (+1 omhoog / -1 omlaag) of 0.
func flick_y(threshold: float, window: int) -> int:
	return _flick(threshold, window, false)


## Dash/smash-flick (drempel 0.8) binnen `frames_window` (teller < venster).
func stick_smashed_x(frames_window: int = MeleeStick.SMASH_WINDOW) -> bool:
	return flick_x(MeleeStick.SMASH_THRESHOLD, frames_window) != 0


func stick_smashed_y(frames_window: int = MeleeStick.SMASH_WINDOW) -> bool:
	return flick_y(MeleeStick.SMASH_THRESHOLD, frames_window) != 0


func _flick(threshold: float, window: int, horizontal: bool) -> int:
	var v: int = _axis_i(0, horizontal)
	if v == 0 or not MeleeStick.reaches(float(v) / MeleeStick.GRID, threshold):
		return 0
	return signi(v) if _timer(0, horizontal) < window else 0


func _timer(back: int, horizontal: bool) -> int:
	var cur: int = _axis_i(back, horizontal)
	if cur == 0:
		return MeleeStick.TIMER_NEUTRAL
	var s: int = signi(cur)
	var n: int = 0
	var b: int = back + 1
	while b < SIZE and signi(_axis_i(b, horizontal)) == s:
		n += 1
		b += 1
	return n


## Stickwaarde op het raster; binnen de deadzone = 0 (ook voor niet-gekwantiseerde testframes).
func _axis_i(back: int, horizontal: bool) -> int:
	var s: Vector2i = get_frame(back).stick
	var v: int = s.x if horizontal else s.y
	return 0 if absi(v) < MeleeStick.DEADZONE else v
