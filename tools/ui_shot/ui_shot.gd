extends Node
## Maakt een screenshot van een UI-scène (windowed; --headless rendert niet).
##   Godot_console.exe --path . res://tools/ui_shot/ui_shot.tscn -- --scene res://ui/main_menu/main_menu.tscn --out C:/pad/x.png
## Opties: --wait <frames> (standaard 20), --mode training|fight, --lock1 <id>, --lock2 <id>, --filter op, --move1 <n> (cursor P1 n stappen rechts)

func _ready() -> void:
	var a: Dictionary = {}
	var u: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < u.size():
		if u[i].begins_with("--") and i + 1 < u.size():
			a[u[i].substr(2)] = u[i + 1]
			i += 2
		else:
			i += 1
	if a.get("mode", "") == "training":
		MatchSetup.mode = MatchSetup.MODE_TRAINING
	var scene: Node = load(String(a.get("scene", "res://ui/main_menu/main_menu.tscn"))).instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	if a.has("lock1") and scene.has_method("_confirm"):
		for k in int(a.get("move1", "0")):
			scene._move(0, 1, 0)
		scene._confirm(0)
	if a.has("lock2") and scene.has_method("_confirm"):
		scene._move(1, 1, 0)
		scene._move(1, 1, 0)
		scene._confirm(1)
	for n in int(a.get("wait", "20")):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(String(a.get("out", "user://shot.png")))
	print("ui_shot: ", a.get("out", "user://shot.png"), " ", img.get_size())
	get_tree().quit()
