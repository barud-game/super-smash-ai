extends Node2D
## Dummy-punt voor de cameratest: een marker ter grootte van een fighter.

@export var color: Color = Color.ORANGE


func _draw() -> void:
	draw_rect(Rect2(-12, -80, 24, 80), color)
	draw_circle(Vector2(0, -90), 14.0, color.lightened(0.2))
