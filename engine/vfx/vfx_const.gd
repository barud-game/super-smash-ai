class_name VfxConst
extends RefCounted
## Gedeelde VFX-constanten.

## Gelijk aan `HitboxData.Element` (NORMAL, FIRE, ELECTRIC, ICE, SLASH); DARK is extra.
const EL_NORMAL: int = 0
const EL_FIRE: int = 1
const EL_ELECTRIC: int = 2
const EL_ICE: int = 3
const EL_SLASH: int = 4
const EL_DARK: int = 5

## Kant van de blast zone waar de fighter uitvloog.
const SIDE_LEFT: int = 0
const SIDE_RIGHT: int = 1
const SIDE_TOP: int = 2
const SIDE_BOTTOM: int = 3

## Harde grens voor een KO-effect.
const KO_MAX_FRAMES: int = 90
## Maximale zichtbare grootte van een KO-effect (px, straal rond de spawnpositie).
const KO_MAX_RADIUS_PX: float = 700.0


## Richting INTO the stage voor een blast-zone-kant, in Godot-px (y omlaag).
static func inward_dir(side: int) -> Vector2:
	match side:
		SIDE_LEFT:
			return Vector2.RIGHT
		SIDE_RIGHT:
			return Vector2.LEFT
		SIDE_TOP:
			return Vector2.DOWN
		_:
			return Vector2.UP


## Deterministische jitter voor hitlag-shake van een fighter-visual (px). `frames_left` = resterende
## hitlag, `strength` in px (Melee: ~1-2 units = 7-14 px bij hoge damage). Geen RNG-state nodig.
static func hitlag_jitter(frames_left: int, strength: float) -> Vector2:
	var s: float = 1.0 if frames_left % 2 == 0 else -1.0
	var k: float = float((frames_left * 37) % 5) / 4.0
	return Vector2(s * strength, (k - 0.5) * strength * 0.6)
