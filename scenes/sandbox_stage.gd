class_name SandboxStage
extends Node2D
## Eenvoudige test-stage voor de sandbox en headless tests (de echte stage komt uit engine/stage/).
## Implementeert dezelfde minimale interface als Stage: get_ground_segments(), get_blast_zone(),
## get_respawn(i). Alles in Melee-units; tekenen via Units.to_px.
##
## Hoofdplatform: vlak, Final Destination-breedte (±85.5657). Drie pass-through platforms
## (Battlefield-achtige maten) om landen, waveland en platform drop te testen.

const MAIN_HALF_WIDTH: float = 85.5657
const COL_SOLID := Color(0.85, 0.87, 0.92)
const COL_PLATFORM := Color(0.55, 0.8, 1.0)

## Segmenten als Dictionary {a, b, type}; type "solid" of "platform".
var segments: Array = [
	{"a": Vector2(-MAIN_HALF_WIDTH, 0.0), "b": Vector2(MAIN_HALF_WIDTH, 0.0), "type": "solid"},
	{"a": Vector2(-57.6, 27.2), "b": Vector2(-20.0, 27.2), "type": "platform"},
	{"a": Vector2(20.0, 27.2), "b": Vector2(57.6, 27.2), "type": "platform"},
	{"a": Vector2(-18.8, 54.4), "b": Vector2(18.8, 54.4), "type": "platform"},
]
## position = links/onder, size = breedte/hoogte (zelfde conventie als Stage).
var blast_zone: Rect2 = Rect2(-224.0, -108.8, 448.0, 308.8)
var spawns: Array[Vector2] = [Vector2(-30.0, 0.0), Vector2(30.0, 0.0)]


func get_ground_segments() -> Array:
	return segments


func get_blast_zone() -> Rect2:
	return blast_zone


func get_spawn(i: int) -> Vector2:
	return spawns[i % spawns.size()]


func get_respawn(_i: int) -> Vector2:
	return Vector2(0.0, 80.0)


func _draw() -> void:
	for s: Dictionary in segments:
		var a: Vector2 = Units.to_px(s["a"])
		var b: Vector2 = Units.to_px(s["b"])
		if s["type"] == "platform":
			draw_line(a, b, COL_PLATFORM, 4.0)
			draw_rect(Rect2(a + Vector2(0, 2), Vector2(b.x - a.x, 8)), Color(COL_PLATFORM, 0.25))
		else:
			var depth: float = 18.0 * Units.UNIT_TO_PX
			var poly := PackedVector2Array([a, b, b + Vector2(-60, depth), a + Vector2(60, depth)])
			draw_colored_polygon(poly, Color(0.22, 0.24, 0.3))
			draw_line(a, b, COL_SOLID, 4.0)
	# blast zone (dun)
	var tl: Vector2 = Units.to_px(Vector2(blast_zone.position.x, blast_zone.end.y))
	var br: Vector2 = Units.to_px(Vector2(blast_zone.end.x, blast_zone.position.y))
	draw_rect(Rect2(tl, br - tl), Color(1, 0.3, 0.3, 0.35), false, 2.0)
