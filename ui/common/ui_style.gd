class_name UiStyle
extends RefCounted
## Gedeelde kleuren en tekenhulpjes voor alle menu's (donker kosmisch).

const BG_TOP := Color("04050d")
const BG_BOTTOM := Color("1b1038")
const PANEL := Color(0.07, 0.08, 0.16, 0.88)
const PANEL_EDGE := Color("2f3566")
const TEXT := Color("eef0ff")
const TEXT_DIM := Color("8e93bd")
const ACCENT := Color("6fd6ff")
const ACCENT2 := Color("b07bff")
const GOLD := Color("ffc933")
const OP_RED := Color("e8324a")
const PLAYER_COLORS: Array[Color] = [Color("e5423b"), Color("3b7be5"), Color("3fb85a"), Color("e5b93b")]
const SCREEN := Vector2(1280, 720)


static func player_color(p: int) -> Color:
	return PLAYER_COLORS[clampi(p, 0, PLAYER_COLORS.size() - 1)]


## Speelt een UI-geluid via de autoload Sfx, als die bestaat.
static func sfx(sound: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var n: Node = tree.root.get_node_or_null("Sfx")
	if n != null and n.has_method("play"):
		n.call("play", sound)


static func font() -> Font:
	return ThemeDB.fallback_font


## Tekent tekst met rand; `align`: 0 links, 1 midden, 2 rechts rond `pos.x`. pos.y = basislijn.
static func text(c: CanvasItem, s: String, pos: Vector2, size: int, color: Color = TEXT,
		align: int = 0, outline: int = 0, outline_color: Color = Color(0, 0, 0, 0.75)) -> void:
	var f: Font = font()
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = pos.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	if outline > 0:
		c.draw_string_outline(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			outline, outline_color)
	c.draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_width(s: String, size: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Parallellogram (schuine kant) als polygonpunten.
static func slanted(r: Rect2, skew: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r.position.x + skew, r.position.y), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - skew, r.end.y), Vector2(r.position.x, r.end.y)])


static func outline_poly(c: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, color, width, true)


static func rounded_box(color: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	return sb


## "OP"-badge: rode pil met gouden rand. `pos` = linksboven, `scale` schaalt het hele ding.
static func op_badge(c: CanvasItem, pos: Vector2, scale: float = 1.0) -> void:
	var r := Rect2(pos, Vector2(34, 18) * scale)
	c.draw_rect(r, OP_RED)
	c.draw_rect(r, GOLD, false, maxf(1.5 * scale, 1.0))
	text(c, "OP", Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.78), int(13 * scale), GOLD, 1)
