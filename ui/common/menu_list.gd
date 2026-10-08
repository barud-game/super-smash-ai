class_name MenuList
extends Control
## Verticale lijst met schuine rijen (Melee-menu-gevoel). Bediening via `move()`/`activate()`/`adjust()`
## (controller) en muis (hover = selecteren, klik = activeren, klik op de pijlen = aanpassen).
##
## items: Array van Dictionary { "label": String, "value": String (optioneel, toont < waarde >),
##   "enabled": bool (optioneel), "id": String (optioneel), "hint": String (optioneel) }

signal activated(index: int)
signal adjusted(index: int, direction: int)
signal moved(index: int)

const ROW_H: float = 58.0
const ROW_GAP: float = 10.0
const SKEW: float = 22.0

var items: Array = []:
	set(v):
		items = v
		selected = clampi(selected, 0, maxi(items.size() - 1, 0))
		_fit()
		queue_redraw()
var selected: int = 0
var row_width: float = 420.0
var font_size: int = 28
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit()


func _fit() -> void:
	custom_minimum_size = Vector2(row_width, items.size() * (ROW_H + ROW_GAP))
	size = custom_minimum_size


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func row_rect(i: int) -> Rect2:
	return Rect2(Vector2(0, i * (ROW_H + ROW_GAP)), Vector2(row_width, ROW_H))


func _enabled(i: int) -> bool:
	return bool(items[i].get("enabled", true))


func move(dir: int) -> void:
	if items.is_empty():
		return
	var n: int = items.size()
	var i: int = selected
	for _k in n:
		i = posmod(i + dir, n)
		if _enabled(i):
			break
	if i != selected:
		selected = i
		UiStyle.sfx("menu_move")
		moved.emit(selected)
	queue_redraw()


func activate() -> void:
	if items.is_empty() or not _enabled(selected):
		return
	UiStyle.sfx("menu_confirm")
	activated.emit(selected)


func adjust(dir: int) -> void:
	if items.is_empty() or not items[selected].has("value"):
		return
	UiStyle.sfx("menu_move")
	adjusted.emit(selected, dir)


func select(i: int) -> void:
	if i != selected and i >= 0 and i < items.size() and _enabled(i):
		selected = i
		UiStyle.sfx("menu_move")
		moved.emit(selected)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i: int = _row_at(event.position)
		if i != -1:
			select(i)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i: int = _row_at(event.position)
		if i == -1:
			return
		select(i)
		if items[i].has("value"):
			adjust(1)
		else:
			activate()


func _row_at(p: Vector2) -> int:
	for i in items.size():
		if row_rect(i).has_point(p):
			return i
	return -1


func _draw() -> void:
	for i in items.size():
		var it: Dictionary = items[i]
		var r: Rect2 = row_rect(i)
		var sel: bool = i == selected
		var en: bool = _enabled(i)
		var off: float = 14.0 if sel else 0.0
		r.position.x += off
		var poly: PackedVector2Array = UiStyle.slanted(r, SKEW)
		var base := Color(0.08, 0.09, 0.2, 0.82)
		if sel:
			# Gloeiende schaduw + verloop in accentkleur.
			var glow: float = 0.5 + 0.5 * sin(_t * 4.0)
			for g in 3:
				var gr := Rect2(r.position - Vector2(g * 3, g * 3), r.size + Vector2(g * 6, g * 6))
				draw_colored_polygon(UiStyle.slanted(gr, SKEW), Color(0.42, 0.84, 1.0, 0.05 + 0.03 * glow))
			draw_colored_polygon(poly, Color("1d2a5c"))
			var accent := PackedVector2Array([
				Vector2(r.position.x + SKEW, r.position.y), Vector2(r.position.x + SKEW + 10, r.position.y),
				Vector2(r.position.x + 10, r.end.y), Vector2(r.position.x, r.end.y)])
			draw_colored_polygon(accent, UiStyle.ACCENT)
			UiStyle.outline_poly(self, poly, UiStyle.ACCENT, 2.0)
		else:
			draw_colored_polygon(poly, base)
			UiStyle.outline_poly(self, poly, UiStyle.PANEL_EDGE, 1.5)
		var col: Color = UiStyle.TEXT if sel else UiStyle.TEXT_DIM
		if not en:
			col = Color(col.r, col.g, col.b, 0.4)
		var base_y: float = r.position.y + ROW_H * 0.5 + font_size * 0.36
		UiStyle.text(self, String(it.get("label", "")).to_upper(), Vector2(r.position.x + SKEW + 26, base_y),
			font_size, col)
		if it.has("value"):
			var vx: float = r.end.x - SKEW - 20.0
			var v: String = String(it["value"])
			UiStyle.text(self, v, Vector2(vx - 34.0, base_y), font_size - 4, UiStyle.ACCENT if sel else col, 2)
			if sel:
				_arrow(Vector2(vx - 34.0 - UiStyle.text_width(v, font_size - 4) - 18.0, r.position.y + ROW_H * 0.5), -1)
				_arrow(Vector2(vx - 6.0, r.position.y + ROW_H * 0.5), 1)


func _arrow(c: Vector2, dir: int) -> void:
	var pts := PackedVector2Array([c + Vector2(-6 * dir, -9), c + Vector2(6 * dir, 0), c + Vector2(-6 * dir, 9)])
	draw_colored_polygon(pts, UiStyle.ACCENT)
