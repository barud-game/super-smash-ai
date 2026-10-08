class_name Units
extends RefCounted
## Melee-units en schaling naar pixels.
##
## Physics rekent in Melee-units (per frame). Alleen bij renderen schalen we met UNIT_TO_PX.
## Keuze: 7.0 px/unit. Final Destination is ~±85 units breed (170 units) = 1190 px,
## dat past net in het 1280px-brede venster (45 px marge per kant). Blastzones vallen buiten beeld;
## de latere camera zoomt desnoods uit.

const TICKS_PER_SECOND: int = 60
const UNIT_TO_PX: float = 7.0


## Melee-units (y omhoog) -> Godot-pixels (y omlaag).
static func to_px(units: Vector2) -> Vector2:
	return Vector2(units.x * UNIT_TO_PX, -units.y * UNIT_TO_PX)


static func from_px(px: Vector2) -> Vector2:
	return Vector2(px.x / UNIT_TO_PX, -px.y / UNIT_TO_PX)
