class_name InputFrame
extends RefCounted
## Eén gesampled input-frame voor één speler (na Melee-kwantisatie).

const BTN_ATTACK: int = 1 << 0
const BTN_SPECIAL: int = 1 << 1
const BTN_JUMP: int = 1 << 2
## Digitale "shield volledig ingedrukt"-bit (trigger >= TRIGGER_FULL).
const BTN_SHIELD: int = 1 << 3
const BTN_Z: int = 1 << 4
const BTN_START: int = 1 << 5

## Linkerstick, integer -80..80, y omhoog = positief.
var stick: Vector2i = Vector2i.ZERO
## C-stick, zelfde raster.
var cstick: Vector2i = Vector2i.ZERO
## Analoge triggers 0..1.
var trigger_l: float = 0.0
var trigger_r: float = 0.0
var buttons: int = 0


func stick_f() -> Vector2:
	return Vector2(stick) / float(MeleeStick.GRID)


func cstick_f() -> Vector2:
	return Vector2(cstick) / float(MeleeStick.GRID)


## Analoge shield-waarde (sterkste trigger).
func shield_analog() -> float:
	return maxf(trigger_l, trigger_r)


func has(button: int) -> bool:
	return (buttons & button) != 0
