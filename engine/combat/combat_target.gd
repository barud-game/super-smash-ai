class_name CombatTarget
extends RefCounted
## Alles wat de resolver over een mogelijk doelwit moet weten (momentopname, wereldcoördinaten).

var id: int = 0
var origin: Vector2 = Vector2.ZERO
var facing: int = 1
var hurtboxes: Array[HurtboxData] = []
var percent: float = 0.0       ## percentage vóór de hit
var weight: float = 100.0
var grounded: bool = false
var crouching: bool = false
var charging: bool = false     ## laadt een smash op: KB x1.2 als hij geraakt wordt
var intangible: bool = false   ## hele fighter (dodge, ledge, respawn): wordt niet geraakt
var invincible: bool = false   ## hele fighter onkwetsbaar (bv. respawn-platform): wordt niet geraakt
var shielding: bool = false
var shield_center: Vector2 = Vector2.ZERO
var shield_radius: float = 0.0
var shield_analog: float = 1.0 ## ruwe analoge stand s, 0..1 (1 = vol/digitaal); shieldstun normaliseert (s-0.3)/0.7
var grabbable: bool = true    ## false = kan niet gegrepen worden (al gegrepen, zelf aan het grijpen/gooien)
