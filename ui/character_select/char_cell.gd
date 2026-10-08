class_name CharCell
extends Control
## Eén vakje in het character-grid. `info == null` betekent de Random-tegel.

signal clicked(slot: int)
signal wheel(direction: int)

var slot: int = 0
var info: CharacterInfo = null
var texture: Texture2D = null
var is_random: bool = false
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	if info != null and info.op and visible:
		_t += delta
		queue_redraw()


func set_entry(new_slot: int, new_info: CharacterInfo, tex: Texture2D) -> void:
	slot = new_slot
	info = new_info
	is_random = new_info == null
	texture = tex
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				clicked.emit(slot)
			MOUSE_BUTTON_WHEEL_UP:
				wheel.emit(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				wheel.emit(1)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if is_random:
		draw_rect(r, Color(0.08, 0.09, 0.2, 0.85))
		draw_rect(r, UiStyle.ACCENT2, false, 2.0)
		UiStyle.text(self, "?", Vector2(r.size.x * 0.5, 74), 64, UiStyle.ACCENT2, 1, 4)
		UiStyle.text(self, "RANDOM", Vector2(r.size.x * 0.5, r.size.y - 11), 15, UiStyle.TEXT, 1)
		return
	if info == null:
		return
	draw_rect(r, Color(0.07, 0.08, 0.17, 0.9))
	# Kleurverloop vanuit de character-kleur.
	var cp: Color = info.color_primary
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(r.size.x, 0), Vector2(r.size.x, r.size.y), Vector2(0, r.size.y)]),
		PackedColorArray([Color(cp.r, cp.g, cp.b, 0.0), Color(cp.r, cp.g, cp.b, 0.0),
			Color(cp.r, cp.g, cp.b, 0.30), Color(cp.r, cp.g, cp.b, 0.30)]))
	if texture != null:
		draw_texture(texture, Vector2((r.size.x - texture.get_width()) * 0.5, 2.0))
	else:
		UiStyle.text(self, info.display_name.substr(0, 1).to_upper(), Vector2(r.size.x * 0.5, 70), 54,
			Color(cp.r, cp.g, cp.b, 0.9), 1, 3)
	# Naamlabel.
	draw_rect(Rect2(0, r.size.y - 26, r.size.x, 26), Color(0.02, 0.02, 0.07, 0.72))
	var fs: int = 16
	while fs > 10 and UiStyle.text_width(info.display_name, fs) > r.size.x - 12.0:
		fs -= 1
	UiStyle.text(self, info.display_name, Vector2(r.size.x * 0.5, r.size.y - 8), fs, UiStyle.TEXT, 1)
	if info.archetype != "":
		UiStyle.text(self, info.archetype.to_upper(), Vector2(7, 15), 10, UiStyle.TEXT_DIM)
	if info.op:
		var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
		draw_rect(r.grow(2), Color(UiStyle.OP_RED.r, UiStyle.OP_RED.g, UiStyle.OP_RED.b, 0.18 + 0.14 * pulse), false, 4.0)
		draw_rect(r, UiStyle.GOLD, false, 3.0)
		draw_rect(r.grow(-4), Color(UiStyle.OP_RED.r, UiStyle.OP_RED.g, UiStyle.OP_RED.b, 0.9), false, 1.0)
		UiStyle.op_badge(self, Vector2(r.size.x - 40, 5))
	else:
		draw_rect(r, UiStyle.PANEL_EDGE, false, 2.0)
