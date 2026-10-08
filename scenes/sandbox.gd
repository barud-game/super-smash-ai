extends Node2D
## Testscène: grijze achtergrond, vloer op y=0 (Melee-units, geschaald). Nog geen fighter.

const STAGE_HALF_WIDTH: float = 85.0  # Final Destination-achtig, in units
## Screen-positie van de oorsprong (Melee 0,0) in pixels.
const ORIGIN_PX := Vector2(640, 440)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.35, 0.35, 0.38))
	position = ORIGIN_PX
	var floor_line := Line2D.new()
	floor_line.width = 3.0
	floor_line.default_color = Color(0.9, 0.9, 0.9)
	floor_line.points = PackedVector2Array([
		Units.to_px(Vector2(-STAGE_HALF_WIDTH, 0.0)), Units.to_px(Vector2(STAGE_HALF_WIDTH, 0.0))])
	add_child(floor_line)
