extends Node2D
## VFX-preview: speelt een effect frame voor frame af en schrijft een contactsheet-PNG.
## Windowed draaien (--headless rendert niet):
##   Godot_console.exe --path . res://tools/vfx_preview/vfx_preview.tscn -- --effect hit --out C:/pad/hit.png
## Opties: --effect hit|hit_fire|hit_electric|hit_ice|hit_dark|hit_slash|hit_kill|shield|clank|dust|airdodge|trail|respawn|ko|elements
##         --character <id> (voor ko, standaard _dummy; "" = fallback) --side left|right|top|bottom
##         --strength 0..1 (standaard 0.6) --ref 0|1 (referentiefiguur 15 units, standaard 1) --frames "0,2,4,..." (standaard automatisch) --cols N --scale F

const CELL: Vector2i = Vector2i(360, 300)
## Referentiefiguur: allrounder van 15 units; effecten die op het lichaam raken spawnen op lichaamsmidden.
const REF_HEIGHT_UNITS: float = 15.0
const BODY: Vector2 = Vector2(0.0, 7.5)

var _args: Dictionary = {}


func _ready() -> void:
	var u: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < u.size():
		if u[i].begins_with("--") and i + 1 < u.size():
			_args[u[i].substr(2)] = u[i + 1]
			i += 2
		else:
			i += 1
	_run.call_deferred()


func _run() -> void:
	var effect: String = String(_args.get("effect", "hit"))
	var out: String = String(_args.get("out", "user://vfx_preview.png"))
	var strength: float = float(_args.get("strength", "0.6"))
	var character: String = String(_args.get("character", "_dummy"))
	var side: int = {"left": VfxConst.SIDE_LEFT, "right": VfxConst.SIDE_RIGHT, "top": VfxConst.SIDE_TOP, "bottom": VfxConst.SIDE_BOTTOM}.get(String(_args.get("side", "left")), 0)
	var shots: Array[Image] = []
	var labels: Array[String] = []

	if effect == "elements":
		for el in 6:
			var names: Array[String] = ["normal", "fire", "electric", "ice", "slash", "dark"]
			var frames: Array[int] = [1, 4, 8]
			var imgs: Array[Image] = await _capture(func(l: VfxLayer) -> void: l.spawn_hit(BODY, strength, el, 35.0), frames, Vector2(0, -REF_HEIGHT_UNITS * 0.5 * Units.UNIT_TO_PX), 1.0)
			shots.append_array(imgs)
			for f in frames:
				labels.append("%s f%d" % [names[el], f])
		await _write_sheet(shots, labels, out, 3)
		return

	if effect == "specials":
		# Contactsheet van alle special-effecten: per effect 3 frames naast de 15-units-referentie.
		var sp_names: Array[String] = ["sparks", "purple_sparks", "smoke_puff", "burst", "explosion", "speed_lines", "charge_glow",
			"shockwave", "counter_flash", "reflect_shine", "teleport_poof", "dust_kick", "wood_chips"]
		if _args.has("fx"):
			sp_names = [String(_args["fx"])]
		var sp_frames: Array[int] = [2, 6, 11]
		for n in sp_names:
			var nm: String = n
			var imgs3: Array[Image] = await _capture(func(l: VfxLayer) -> void:
				l.spawn_special_fx(nm, BODY, 1, 0, {"foot": Vector2.ZERO, "character": "_dummy"}), sp_frames, Vector2(0, -REF_HEIGHT_UNITS * 0.5 * Units.UNIT_TO_PX), 1.0)
			shots.append_array(imgs3)
			for f in sp_frames:
				labels.append("%s f%d" % [nm, f])
		await _write_sheet(shots, labels, out, 9)
		return

	var spawn: Callable
	var frames2: Array[int] = [0, 1, 2, 3, 5, 7, 9, 12]
	var center: Vector2 = Vector2(0, -REF_HEIGHT_UNITS * 0.5 * Units.UNIT_TO_PX)
	var scale: float = float(_args.get("scale", "1.0"))
	match effect:
		"hit":
			spawn = func(l: VfxLayer) -> void: l.spawn_hit(BODY, strength, 0, 35.0)
		"hit_fire":
			spawn = func(l: VfxLayer) -> void: l.spawn_hit(BODY, strength, VfxConst.EL_FIRE, 35.0)
		"hit_electric":
			spawn = func(l: VfxLayer) -> void: l.spawn_hit(BODY, strength, VfxConst.EL_ELECTRIC, 35.0)
		"hit_ice":
			spawn = func(l: VfxLayer) -> void: l.spawn_hit(BODY, strength, VfxConst.EL_ICE, 35.0)
		"hit_dark":
			spawn = func(l: VfxLayer) -> void: l.spawn_hit(BODY, strength, VfxConst.EL_DARK, 35.0)
		"hit_slash":
			spawn = func(l: VfxLayer) -> void: l.spawn_hit(BODY, strength, VfxConst.EL_SLASH, 35.0)
		"hit_kill":
			spawn = func(l: VfxLayer) -> void: l.spawn_hit(BODY, 1.0, 0, 35.0, true)
			frames2 = [0, 2, 4, 6, 9, 12, 16, 22]
		"shield":
			spawn = func(l: VfxLayer) -> void: l.spawn_shield_hit(BODY, strength, Color(0.4, 0.8, 1.0), 20.0)
		"clank":
			spawn = func(l: VfxLayer) -> void: l.spawn_clank(BODY)
		"dust":
			spawn = func(l: VfxLayer) -> void:
				l.spawn_land_dust(Vector2(-14, 0), true)
				l.spawn_land_dust(Vector2(0, 0), false)
				l.spawn_jump_dust(Vector2(12, 0))
				l.spawn_dash_dust(Vector2(24, 0), 1)
			center = Vector2(0, -50)
			frames2 = [0, 2, 4, 7, 10, 14, 18, 22]
		"airdodge":
			spawn = func(l: VfxLayer) -> void: l.spawn_airdodge_trail(BODY, 20.0, Color(1.0, 0.6, 0.4))
		"trail":
			spawn = func(l: VfxLayer) -> void:
				var t := Node2D.new()
				l.add_child(t)
				t.set_meta("trail_target", true)
				l.spawn_launch_trail(t, 24)
			frames2 = [2, 6, 10, 14, 18, 22, 28, 36]
		"respawn":
			spawn = func(l: VfxLayer) -> void: l.spawn_respawn(Vector2.ZERO, Color(0.5, 0.8, 1.0))
			center = Vector2(0, -75)
			frames2 = [0, 3, 6, 10, 14, 20, 26, 34]
		"ko":
			var pc: Color = Color(1.0, 0.4, 0.35)
			spawn = func(l: VfxLayer) -> void: l.spawn_ko(character, Vector2.ZERO, side, pc)
			frames2 = [0, 3, 6, 10, 16, 24, 36, 50, 64, 74]
			center = VfxConst.inward_dir(side) * 150.0
			scale = float(_args.get("scale", "0.55"))
		_:
			push_error("onbekend effect: " + effect)
			get_tree().quit(1)
			return
	if _args.has("frames"):
		frames2 = []
		for s in String(_args["frames"]).split(","):
			frames2.append(int(s))
	var move_trail: bool = effect == "trail"
	var imgs2: Array[Image] = await _capture(spawn, frames2, center, scale, move_trail)
	for f in frames2:
		labels.append("f%d" % f)
	await _write_sheet(imgs2, labels, out, int(_args.get("cols", "4")))


## Speelt het effect af op een eigen layer en maakt op de gevraagde frames een screenshot (viewport = CELL).
func _capture(spawn: Callable, frames: Array[int], center: Vector2, scale: float, move_trail: bool = false) -> Array[Image]:
	var vp := SubViewport.new()
	vp.size = CELL
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.16)
	bg.z_index = -100
	bg.size = Vector2(CELL)
	vp.add_child(bg)
	var world := Node2D.new()
	world.position = Vector2(CELL) * 0.5 - center * scale
	world.scale = Vector2(scale, scale)
	vp.add_child(world)
	# grondstreep als referentie
	var ground := Line2D.new()
	ground.points = PackedVector2Array([Vector2(-2000, 0), Vector2(2000, 0)])
	ground.width = 2.0
	ground.default_color = Color(0.3, 0.32, 0.45)
	world.add_child(ground)
	if String(_args.get("ref", "1")) != "0":
		var fig := RefFigure.new()
		fig.z_index = 10
		world.add_child(fig)
	var layer := VfxLayer.new()
	layer.auto_register = false
	world.add_child(layer)
	spawn.call(layer)
	var trail_node: Node2D = null
	if move_trail:
		for c in layer.get_children():
			if c is Node2D and c.has_meta("trail_target"):
				trail_node = c
	var out: Array[Image] = []
	var last: int = 0
	for f in frames:
		last = maxi(last, f)
	var wanted: Dictionary = {}
	for f in frames:
		wanted[f] = true
	for f in last + 1:
		if trail_node != null:
			trail_node.position = Vector2(-90.0 + float(f) * 8.0, -float(f) * 4.0 + float(f * f) * 0.12)
		if wanted.has(f):
			layer.vfx_tick(f)  # tick f -> age f+1 getekend
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			out.append(vp.get_texture().get_image())
		else:
			layer.vfx_tick(f)
	vp.queue_free()
	return out


func _write_sheet(imgs: Array[Image], labels: Array[String], path: String, cols: int) -> void:
	cols = maxi(cols, 1)
	var rows: int = int(ceil(float(imgs.size()) / float(cols)))
	var sheet := Image.create(cols * CELL.x, rows * CELL.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.05, 0.08))
	for i in imgs.size():
		var im: Image = imgs[i]
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
	var gpath: String = path
	if path.begins_with("user://") or path.begins_with("res://"):
		gpath = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(gpath.get_base_dir())
	sheet.save_png(gpath)
	print("vfx_preview: ", gpath, " ", sheet.get_size(), " frames=", labels)
	get_tree().quit()


## Silhouet van een character van REF_HEIGHT_UNITS hoog (voeten op y=0) als maatstaf.
class RefFigure extends Node2D:
	func _draw() -> void:
		var h: float = REF_HEIGHT_UNITS * Units.UNIT_TO_PX
		var col := Color(0.55, 0.6, 0.75, 0.55)
		var head_r: float = h * 0.17
		draw_circle(Vector2(0, -h + head_r), head_r, col)
		draw_colored_polygon(PackedVector2Array([Vector2(-h * 0.17, -h * 0.62), Vector2(h * 0.17, -h * 0.62),
			Vector2(h * 0.14, -h * 0.28), Vector2(-h * 0.14, -h * 0.28)]), col)
		draw_rect(Rect2(-h * 0.14, -h * 0.3, h * 0.11, h * 0.3), col)
		draw_rect(Rect2(h * 0.03, -h * 0.3, h * 0.11, h * 0.3), col)
		draw_rect(Rect2(-h * 0.6, 0, h * 1.2, 0), col)
