extends Node2D
## Testscène: stage + camera + twee bewegende dummy-punten.
## Screenshot: Godot --path . res://stages/eindpunt/stage_test.tscn -- --shot C:/pad/x.png [--debug] [--frame N]

@onready var stage: Stage = $Eindpunt
@onready var cam: MatchCamera = $MatchCamera
@onready var p1: Node2D = $P1
@onready var p2: Node2D = $P2

var _t: int = 0
var _shot: String = ""
var _shot_frame: int = 120
var _wide: bool = false


func _ready() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "--shot" and i + 1 < a.size():
			_shot = a[i + 1]
		if a[i] == "--frame" and i + 1 < a.size():
			_shot_frame = int(a[i + 1])
		if a[i] == "--wide":
			_wide = true
		if a[i] == "--debug":
			Sim.debug_hitboxes = true
	if "--check" in a:
		_check_api()
		return
	cam.set_bounds_units(stage.get_camera_bounds())
	cam.set_targets([p1, p2] as Array[Node2D])


func _check_api() -> void:
	var ok: bool = stage.get_ground_segments().size() == 1 \
		and stage.get_ledges().size() == 2 \
		and stage.get_blast_zone() == stage.data.blast_zone \
		and stage.get_spawn(0) == stage.data.spawns[0] \
		and stage.get_spawn(4) == stage.data.spawns[0] \
		and stage.get_respawn(1).y > 0.0
	cam.set_bounds_units(stage.get_camera_bounds())
	cam.set_targets([p1, p2] as Array[Node2D])
	p1.position = Units.to_px(Vector2(-150, 0))
	p2.position = Units.to_px(Vector2(150, 40))
	var g: Dictionary = cam.compute_goal()
	var bpx: Rect2 = cam.bounds_px()
	var half: Vector2 = get_viewport_rect().size / float(g["zoom"]) * 0.5
	var inside: bool = bpx.grow(0.5).encloses(Rect2(g["pos"] - half, half * 2.0))
	print("API ", "PASS" if ok else "FAIL", " | camera zoom=", g["zoom"], " in bounds: ", "PASS" if inside else "FAIL")
	get_tree().quit(0 if ok and inside else 1)


func _physics_process(_delta: float) -> void:
	_t += 1
	var f: float = float(_t)
	p1.position = Units.to_px(Vector2(-60.0 + 95.0 * sin(f * 0.012), 8.0 + 20.0 * absf(sin(f * 0.03))))
	p2.position = Units.to_px(Vector2(40.0 + 120.0 * sin(f * 0.007 + 1.0), 25.0 + 60.0 * sin(f * 0.01)))
	if _wide:
		p1.position = Units.to_px(Vector2(-55, 0))
		p2.position = Units.to_px(Vector2(45, 0))
	if _shot != "" and _t == _shot_frame:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
