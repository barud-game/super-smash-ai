class_name MeleeStick
extends RefCounted
## Kwantisatie van ruwe stick-input naar het Melee-raster.

const GRID: int = 80
## ⚠️ onverified: deadzone 23/80 = 0.2875. |waarde| < 23 -> 0, per as.
const DEADZONE: int = 23
## ⚠️ onverified: trigger telt als "volledig ingedrukt" vanaf deze waarde.
const TRIGGER_FULL: float = 0.95
## ⚠️ onverified: smash-drempels (genormaliseerd).
const SMASH_HIGH: float = 0.8
const SMASH_LOW: float = 0.3


## Ruwe stick (-1..1, y omhoog) -> integer -80..80, binnen de cirkel met straal 80.
static func quantize(raw: Vector2) -> Vector2i:
	var v: Vector2 = raw
	if v.length() > 1.0:
		v = v.normalized()
	var x: int = _snap(v.x)
	var y: int = _snap(v.y)
	# Afkappen richting nul kan nooit buiten de cirkel komen, maar float-epsilon veilig stellen.
	while x * x + y * y > GRID * GRID:
		if absi(x) >= absi(y):
			x -= signi(x)
		else:
			y -= signi(y)
	if absi(x) < DEADZONE:
		x = 0
	if absi(y) < DEADZONE:
		y = 0
	return Vector2i(x, y)


static func _snap(f: float) -> int:
	# Afkappen naar nul, met kleine epsilon zodat 1.0 -> 80 (niet 79).
	return int(f * GRID + signf(f) * 0.001)
