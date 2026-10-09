extends Node
## Rendert een character naar een PNG-contactsheet (voor svg-artist en director).
##
## Gebruik (windowed, --headless rendert niet!):
##   Godot_console.exe --path . res://tools/preview/preview.tscn -- --character _dummy --out C:/pad/preview.png
## Opties:
##   --character <id>    map onder characters/ (verplicht)
##   --out <pad>         PNG-bestand (standaard: user://preview_<id>.png)
##   --pose <naam>       alleen deze pose, groot (met --frames 0,5,10 en --zoom 2)
##   --frames a,b,c      frames voor --pose (standaard 0,1,2,3)
##   --zoom <f>          schaal voor --pose (standaard 1.6)
##   --poses a,b,c       meerdere poses; frames automatisch uit de keytijden (max 7 per pose), cellen zonder labels-ruis
##   --frames per pose kan ook: --maxf <n> om het aantal te beperken
##   --art <map>         art-map overschrijven (bv. een character met weapon.svg)
##   --player <1..4>     teamkleur voor het sheet (standaard 1; de kopregel toont altijd 1 en 2)
## Sluit zichzelf af. Exit code 1 bij fouten in het character.

const CELL := Vector2(190, 215)
const GROUND_Y := 180.0
const BG := Color("e8e6df")
const SAMPLES: Array = [
	["idle", [0, 45]], ["walk", [0, 9, 18, 27]], ["dash", [0, 5, 10, 15]], ["run", [0, 7, 14, 21]],
	["skid", [10]], ["turn", [0, 8]], ["crouch", [7]], ["jumpsquat", [5]],
	["jump", [0, 13]], ["fall", [0, 12]], ["fastfall", [5]], ["jump_aerial", [0, 8, 16, 24]],
	["airdodge", [0, 8, 16]], ["land", [0, 4]], ["landfall", [6]], ["wavedash", [6]],
]

var _char_id: String = ""
var _out: String = ""
var _art: String = ""
var _exit_code: int = 0


func _ready() -> void:
	var args: Dictionary = _parse_args()
	_char_id = args.get("character", "")
	if _char_id == "":
		printerr("preview: --character <id> ontbreekt")
		get_tree().quit(2)
		return
	_out = args.get("out", "user://preview_%s.png" % _char_id)
	var player: int = int(args.get("player", "1")) - 1
	_art = args.get("art", "")

	var cells: Array = []
	var cols: int = 7
	var zoom: float = 1.0
	if args.has("poses"):
		zoom = float(args.get("zoom", "1.0"))
		var lib := PoseLibrary.load_for(_char_id)
		var maxf: int = int(args.get("maxf", "7"))
		for pn: String in String(args["poses"]).split(","):
			if not lib.poses.has(pn):
				printerr("preview: pose bestaat niet: ", pn)
				continue
			var pz: Pose = lib.poses[pn]
			var fr: Array = []
			for t in pz.times:
				var fi: int = int(round(t))
				if not fr.has(fi):
					fr.append(fi)
			while fr.size() > maxf:
				fr.remove_at(1 + (fr.size() - 2) / 2)
			for f in fr:
				cells.append({"pose": pn, "frame": f, "player": player, "facing": 1, "label": "%s f%d" % [pn, f]})
		cols = maxi(1, mini(cells.size(), 7))
	elif args.has("pose"):
		zoom = float(args.get("zoom", "1.6"))
		var pn: String = args["pose"]
		var frames: Array = []
		if args.has("frames"):
			for s in String(args["frames"]).split(","):
				frames.append(int(s))
		else:
			frames = [0, 1, 2, 3]
		for f in frames:
			cells.append({"pose": pn, "frame": f, "player": player, "facing": 1, "label": "%s f%d" % [pn, f]})
		cols = maxi(1, mini(cells.size(), int(floor(1800.0 / (CELL.x * zoom)))))
	else:
		cells.append({"pose": "idle", "frame": 0, "player": 0, "facing": 1, "label": "speler 1 (rechts)"})
		cells.append({"pose": "idle", "frame": 0, "player": 1, "facing": -1, "label": "speler 2 (links)"})
		for s: Array in SAMPLES:
			for f: int in s[1]:
				cells.append({"pose": s[0], "frame": f, "player": player, "facing": 1, "label": "%s f%d" % [s[0], f]})
	_build_sheet(cells, cols, zoom)


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < a.size():
		if a[i].begins_with("--"):
			var key: String = a[i].substr(2)
			if i + 1 < a.size() and not a[i + 1].begins_with("--"):
				out[key] = a[i + 1]
				i += 2
				continue
			out[key] = "true"
		i += 1
	return out


func _build_sheet(cells: Array, cols: int, zoom: float) -> void:
	var cw: float = CELL.x * zoom
	var chh: float = CELL.y * zoom
	var rows: int = int(ceil(float(cells.size()) / cols))
	var size := Vector2i(int(cw * cols), int(chh * rows))
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(size)
	vp.add_child(bg)
	var any_invalid: bool = false
	var warned: bool = false
	for idx in cells.size():
		var c: Dictionary = cells[idx]
		var cz: float = c.get("zoom", zoom)
		var col: int = idx % cols
		var row: int = idx / cols
		var origin := Vector2(col * cw, row * chh)
		var frame_rect := ColorRect.new()
		frame_rect.color = Color(0, 0, 0, 0.05) if (row + col) % 2 == 0 else Color(0, 0, 0, 0.0)
		frame_rect.position = origin
		frame_rect.size = Vector2(cw, chh)
		vp.add_child(frame_rect)
		var ground := ColorRect.new()
		ground.color = Color(0.3, 0.3, 0.35, 0.55)
		var ground_y: float = GROUND_Y * zoom
		ground.position = origin + Vector2(8, ground_y)
		ground.size = Vector2(cw - 16, 2)
		vp.add_child(ground)
		var cv := CharacterVisual.new()
		cv.character_id = _char_id
		cv.player_index = c["player"]
		cv.facing = c["facing"]
		if _art != "":
			cv.art_dir_override = _art
		vp.add_child(cv)
		if not cv.is_valid:
			any_invalid = true
			if not warned:
				for e in cv.errors:
					printerr("preview: ", e)
		if not warned:
			for w in cv.warnings:
				print("preview waarschuwing: ", w)
			warned = true
		cv.play(c["pose"])
		cv.clear_blend()
		cv.tick(int(c["frame"]))
		cv.position = origin + Vector2(cw * 0.5, ground_y)
		cv.scale = Vector2(cz, cz)
		if c["label"] != "":
			var l := Label.new()
			l.text = c["label"]
			l.position = origin + Vector2(8, chh - 28)
			l.add_theme_color_override("font_color", Color("222230"))
			l.add_theme_font_size_override("font_size", 14)
			vp.add_child(l)

	_exit_code = 1 if any_invalid else 0
	for i in 4:
		await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	var err: Error = img.save_png(_out)
	if err != OK:
		printerr("preview: opslaan mislukt (%s): %s" % [error_string(err), _out])
		_exit_code = 2
	else:
		print("preview: geschreven naar ", ProjectSettings.globalize_path(_out), " (", size.x, "x", size.y, ")")
	get_tree().quit(_exit_code)
