extends Node
## Screenshot van een lopende match (HUD) of het results-scherm. Windowed (headless rendert niet).
##   Godot_console.exe --path . res://tools/match_shot/match_shot.tscn -- --out C:/pad/x.png [opties]
## Opties: --ko <n> (speler 1 vliegt de blast zone uit, shot n sim-frames later), --frames <n> Sim-frame om op te wachten (standaard 230, countdown is 180), --mode training|fight,
##   --pct1 <x> --pct2 <x> (damage-% vlak vóór de shot), --stocks1 <n> --stocks2 <n>, --pause (pauzeer als speler 1),
##   --results (toon results-scherm met nep-uitslag; --winner 0|1|-1), --size 1280x720 (venstergrootte)

func _ready() -> void:
	var a: Dictionary = {}
	var u: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < u.size():
		if u[i] == "--pause" or u[i] == "--results":
			a[u[i].substr(2)] = "1"
			i += 1
		elif u[i].begins_with("--") and i + 1 < u.size():
			a[u[i].substr(2)] = u[i + 1]
			i += 2
		else:
			i += 1
	var reg: Node = get_node("/root/CharacterRegistry")
	reg.include_dummy = true
	reg.rescan()
	var setup: Node = get_node("/root/MatchSetup")
	setup.reset()
	setup.mode = String(a.get("mode", "fight"))
	setup.picks[0] = "_dummy"
	setup.picks[1] = "_dummy"
	if a.has("size"):
		var wh: PackedStringArray = String(a["size"]).split("x")
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if a.has("results"):
		var r := MatchResult.new()
		r.winner = int(a.get("winner", "0"))
		r.picks.assign(["_dummy", "_dummy"])
		r.stocks.assign([2, 0] if r.winner == 0 else [0, 3])
		r.percents.assign([87.0, 143.0])
		r.kos.assign([4, 2])
		r.falls.assign([2, 4])
		r.sds.assign([0, 1])
		MatchResult.last = r
		var rs: Node = load("res://ui/results/results.tscn").instantiate()
		get_tree().root.add_child.call_deferred(rs)
		for n in 40:
			await get_tree().process_frame
		await _save(String(a.get("out", "user://shot.png")))
		return
	var m: MatchController = load("res://ui/match/match.tscn").instantiate()
	m.auto_navigate = false
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var target: int = int(a.get("frames", "230"))
	var sim: Node = get_node("/root/Sim")
	var start: int = sim.frame
	while sim.frame < start + target:
		await get_tree().physics_frame
	if a.has("stocks1"):
		m.state.stocks[0] = int(a["stocks1"])
	if a.has("stocks2"):
		m.state.stocks[1] = int(a["stocks2"])
	if a.has("pct1"):
		m.set_percent(0, float(a["pct1"]))
	if a.has("pct2"):
		m.set_percent(1, float(a["pct2"]))
	if a.has("ko"):
		var f0: Fighter = m.fighters[0] as Fighter
		f0.grounded = false
		f0.ground_seg = -1
		f0.change_state("Fall")
		f0.pos = Vector2(-300, 40)   # links van de blast zone
		var ko_start: int = sim.frame
		while sim.frame < ko_start + int(a["ko"]):
			await get_tree().physics_frame
	if a.has("pause"):
		var f := InputFrame.new()
		f.buttons = InputFrame.BTN_START
		m.process_pause_input(0, f)
	for n in 12:
		await get_tree().process_frame
	await _save(String(a.get("out", "user://shot.png")))


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(path)
	print("match_shot: ", path, " ", img.get_size())
	get_tree().quit()
