class_name PlayerPanel
extends Control
## Spelerspaneel onderaan de character select: groot live portret (CharacterVisual, idle, spelerskleur),
## naam, archetype, OP-badge, tagline en status (kiezen / klaar).

const SIZE := Vector2(590, 210)
const FEET := Vector2(110, 192)
const SCALE := 1.05
const MAX_CACHED: int = 10

var player: int = 0
## "pick": speler kiest; "dummy": training-tegenstander (niet bedienbaar).
var kind: String = "pick"
var info: CharacterInfo = null
var show_random: bool = false
var locked: bool = false
var connected_text: String = ""
var page_hint: String = ""

var _visuals: Dictionary = {}   # id -> CharacterVisual
var _order: Array[String] = []
var _current: CharacterVisual = null
var _frame: int = 0
var _t: float = 0.0


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Toont dit character (null + show_rand = Random-vraagteken, null + !show_rand = leeg).
func show_info(new_info: CharacterInfo, show_rand: bool = false) -> void:
	info = new_info
	show_random = show_rand
	_use_visual(new_info)
	queue_redraw()


func _use_visual(i: CharacterInfo) -> void:
	if _current != null:
		_current.visible = false
		_current = null
	if i == null or not i.has_art:
		return
	var cv: CharacterVisual = _visuals.get(i.id)
	if cv == null:
		cv = CharacterVisual.new()
		cv.character_id = i.id
		cv.player_index = player
		cv.position = FEET
		cv.scale = Vector2(SCALE, SCALE)
		add_child(cv)
		_visuals[i.id] = cv
		_order.append(i.id)
		while _order.size() > MAX_CACHED:
			var old: String = _order.pop_front()
			var ocv: CharacterVisual = _visuals[old]
			_visuals.erase(old)
			ocv.queue_free()
		if cv.is_valid:
			cv.play("idle")
	if cv.is_valid:
		cv.visible = true
		_current = cv


func clear_cache() -> void:
	for id in _visuals:
		(_visuals[id] as CharacterVisual).queue_free()
	_visuals.clear()
	_order.clear()
	_current = null


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _current != null:
		_current.tick(_frame)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var col: Color = UiStyle.player_color(player)
	var r := Rect2(Vector2.ZERO, SIZE)
	draw_rect(r, UiStyle.PANEL)
	var accent: Color = info.color_primary if info != null else UiStyle.PANEL_EDGE
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(SIZE.x, 0), Vector2(SIZE.x, SIZE.y), Vector2(0, SIZE.y)]),
		PackedColorArray([Color(accent.r, accent.g, accent.b, 0.0), Color(accent.r, accent.g, accent.b, 0.0),
			Color(accent.r, accent.g, accent.b, 0.16), Color(accent.r, accent.g, accent.b, 0.30)]))
	draw_rect(Rect2(0, 0, SIZE.x, 6), col)
	draw_rect(r, col if locked else UiStyle.PANEL_EDGE, false, 3.0 if locked else 1.5)
	# Vloer + schaduw onder het character.
	draw_rect(Rect2(18, FEET.y, 184, 3), Color(1, 1, 1, 0.18))
	draw_circle(Vector2(FEET.x, FEET.y + 2), 38.0, Color(0, 0, 0, 0.0))
	if info == null:
		var q: String = "?" if (show_random or kind == "dummy") else ""
		UiStyle.text(self, q, Vector2(FEET.x, 140), 110, Color(1, 1, 1, 0.22), 1, 4)
	elif _current == null:
		UiStyle.text(self, info.display_name.substr(0, 1).to_upper(), Vector2(FEET.x, 140), 110,
			Color(accent.r, accent.g, accent.b, 0.8), 1, 4)

	# Spelerslabel.
	var tag: String = "P%d" % (player + 1) if kind == "pick" else "DUMMY"
	var tw: float = UiStyle.text_width(tag, 20) + 24.0
	draw_rect(Rect2(222, 22, tw, 28), col)
	UiStyle.text(self, tag, Vector2(222 + tw * 0.5, 43), 20, Color.WHITE, 1)
	if connected_text != "":
		UiStyle.text(self, connected_text, Vector2(222 + tw + 12, 43), 14, UiStyle.TEXT_DIM)

	# Status rechtsboven.
	if kind == "dummy":
		UiStyle.text(self, "willekeurig", Vector2(SIZE.x - 20, 43), 18, UiStyle.TEXT_DIM, 2)
	elif locked:
		var a: float = 0.8 + 0.2 * sin(_t * 6.0)
		UiStyle.text(self, "KLAAR", Vector2(SIZE.x - 20, 43), 26, Color(0.45, 1.0, 0.55, a), 2, 3)
	else:
		UiStyle.text(self, "KIEZEN…", Vector2(SIZE.x - 20, 43), 20, UiStyle.TEXT_DIM, 2)

	# Naam e.d.
	var name_s: String = "???"
	if info != null:
		name_s = info.display_name
	elif show_random:
		name_s = "RANDOM"
	elif kind == "dummy":
		name_s = "Willekeurig"
	var fs: int = 38
	while fs > 18 and UiStyle.text_width(name_s, fs) > SIZE.x - 250.0:
		fs -= 2
	UiStyle.text(self, name_s, Vector2(222, 100), fs, UiStyle.TEXT, 0, 3)
	if info != null:
		var ax: float = 222.0
		if info.op:
			UiStyle.op_badge(self, Vector2(ax, 112), 1.25)
			ax += 54.0
		UiStyle.text(self, info.archetype.to_upper(), Vector2(ax, 128), 18,
			UiStyle.GOLD if info.op else UiStyle.ACCENT)
		if info.tagline != "":
			draw_multiline_string(UiStyle.font(), Vector2(222, 158), info.tagline, HORIZONTAL_ALIGNMENT_LEFT,
				SIZE.x - 250.0, 16, 2, UiStyle.TEXT_DIM)
	elif show_random:
		UiStyle.text(self, "Een verrassing…", Vector2(222, 132), 18, UiStyle.ACCENT2)
	if page_hint != "":
		UiStyle.text(self, page_hint, Vector2(SIZE.x - 14, SIZE.y - 12), 13, UiStyle.TEXT_DIM, 2)
