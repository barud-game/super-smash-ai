class_name MatchHud
extends CanvasLayer
## Melee-achtige HUD: per speler onderaan naam, mini-portret, groot damage-% (wit -> geel -> rood -> donkerrood,
## schudt kort bij toename) en stock-iconen; timer bovenaan; countdown/GAME!-banners; pauze-overlay; training-hint.
## Puur presentatie: leest alleen uit de MatchController. Animaties tellen sim-frames (bevriezen dus in de pauze).

const PANEL_W: float = 300.0
const PANEL_H: float = 118.0
const MARGIN_BOTTOM: float = 56.0
const SHAKE_FRAMES: int = 14
## Waar (in %) de kleur schuift: wit -> geel -> oranje -> rood -> donkerrood.
const PCT_STOPS: Array[float] = [0.0, 40.0, 90.0, 140.0, 220.0]
const PCT_COLORS: Array[Color] = [Color("ffffff"), Color("ffe45c"), Color("ff8a26"), Color("e62a1e"), Color("6e0a12")]

var controller: MatchController

var _canvas: Control
var _portraits: PortraitCache
var _shown_pct: Array[float] = [0.0, 0.0]
var _shake_until: Array[int] = [-1, -1]
var _shake_amp: Array[float] = [0.0, 0.0]
var _frame: int = 0


func _ready() -> void:
	layer = 20
	_portraits = PortraitCache.new()
	add_child(_portraits)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)
	var sim: Node = get_node_or_null("/root/Sim")
	if sim != null:
		sim.frame_advanced.connect(_on_frame)


func _on_frame(_f: int) -> void:
	_frame += 1


func _process(_delta: float) -> void:
	if controller == null:
		return
	for p in 2:
		var pct: float = controller.get_percent(p)
		if pct > _shown_pct[p] + 0.01:
			var gain: float = pct - _shown_pct[p]
			_shake_until[p] = _frame + SHAKE_FRAMES
			_shake_amp[p] = clampf(2.0 + gain * 0.35, 2.0, 11.0)
		_shown_pct[p] = pct
	_canvas.queue_redraw()


## Kleur bij een percentage (publiek voor tests/screenshots).
static func percent_color(pct: float) -> Color:
	if pct <= PCT_STOPS[0]:
		return PCT_COLORS[0]
	for i in range(1, PCT_STOPS.size()):
		if pct <= PCT_STOPS[i]:
			var t: float = (pct - PCT_STOPS[i - 1]) / (PCT_STOPS[i] - PCT_STOPS[i - 1])
			return PCT_COLORS[i - 1].lerp(PCT_COLORS[i], t)
	return PCT_COLORS[PCT_COLORS.size() - 1]


## "M:SS" van resterende frames (naar boven afgerond op hele seconden, zoals de Melee-klok).
static func format_time(frames: int) -> String:
	var secs: int = ceili(float(frames) / 60.0)
	return "%d:%02d" % [secs / 60, secs % 60]


# =============================================================================================

func _draw_all() -> void:
	if controller == null:
		return
	var c: Control = _canvas
	var sz: Vector2 = c.size
	_draw_timer(c, sz)
	var training: bool = controller.is_training()
	for p in 2:
		var cx: float = sz.x * 0.5 + (-1.0 if p == 0 else 1.0) * 215.0
		_draw_panel(c, p, Rect2(cx - PANEL_W * 0.5, sz.y - PANEL_H - MARGIN_BOTTOM, PANEL_W, PANEL_H), training)
	_draw_banners(c, sz)
	if training:
		_draw_training_bar(c, sz)
	if controller.paused_by >= 0:
		_draw_pause(c, sz)


func _draw_timer(c: Control, sz: Vector2) -> void:
	var training: bool = controller.is_training()
	var left: int = controller.state.time_left()
	var text: String = ""
	var col: Color = UiStyle.TEXT
	if training:
		text = "TRAINING"
	elif controller.state.sudden_death:
		text = "SUDDEN DEATH"
		col = UiStyle.OP_RED
	elif left < 0:
		text = "∞"
	else:
		text = format_time(left)
		if left <= 10 * 60:
			col = Color("ff5a4a")
	var fs: int = 34 if (training or controller.state.sudden_death) else 46
	var w: float = UiStyle.text_width(text, fs) + 56.0
	var r := Rect2(sz.x * 0.5 - w * 0.5, 10.0, w, 62.0)
	c.draw_colored_polygon(UiStyle.slanted(r, 14.0), Color(0.03, 0.04, 0.1, 0.78))
	UiStyle.outline_poly(c, UiStyle.slanted(r, 14.0), UiStyle.PANEL_EDGE, 2.0)
	UiStyle.text(c, text, Vector2(sz.x * 0.5, r.position.y + 45.0), fs, col, 1, 4, Color(0, 0, 0, 0.85))


func _draw_panel(c: Control, p: int, r: Rect2, training: bool) -> void:
	var col: Color = UiStyle.player_color(p)
	var dead: bool = controller.is_dead(p)
	var alpha: float = 0.45 if dead else 1.0
	# achtergrondplaat
	var plate := Rect2(r.position + Vector2(0, 30), Vector2(r.size.x, r.size.y - 30))
	c.draw_colored_polygon(UiStyle.slanted(plate, 16.0), Color(0.03, 0.04, 0.1, 0.72 * alpha))
	UiStyle.outline_poly(c, UiStyle.slanted(plate, 16.0), Color(col, 0.75 * alpha), 2.5)
	c.draw_rect(Rect2(plate.position.x + 16, plate.position.y, plate.size.x - 16, 4), Color(col, alpha))
	# portret (steekt boven de plaat uit)
	var info: CharacterInfo = null
	var reg: Node = get_node_or_null("/root/CharacterRegistry")
	if reg != null:
		info = reg.get_info(controller.picks[p])
	var tex: Texture2D = _portraits.texture(info, p) if info != null else null
	var pshift: Vector2 = Vector2(0, 0)
	if tex != null:
		var psize: Vector2 = Vector2(tex.get_size()) * 1.1
		c.draw_texture_rect(tex, Rect2(r.position + Vector2(8, plate.position.y - r.position.y + plate.size.y - psize.y - 4), psize), false,
			Color(1, 1, 1, alpha))
	# naam
	var tag: String = "DUMMY" if (training and p == 1) else "P%d" % (p + 1)
	var nm: String = controller.display_name(p)
	UiStyle.text(c, tag, Vector2(r.position.x + 130, r.position.y + 22), 17, col, 0, 3)
	UiStyle.text(c, nm, Vector2(r.position.x + 130 + UiStyle.text_width(tag, 17) + 10, r.position.y + 22), 17,
		Color(UiStyle.TEXT, alpha), 0, 3)
	# damage-%
	var pct: float = controller.get_percent(p)
	var shake := Vector2.ZERO
	if _frame < _shake_until[p]:
		var k: int = _shake_until[p] - _frame
		var a: float = _shake_amp[p] * float(k) / float(SHAKE_FRAMES)
		shake = Vector2(sin(_frame * 2.9 + p * 1.7), cos(_frame * 3.7 + p)) * a
	var pcol: Color = percent_color(pct)
	pcol.a = alpha
	var num: String = str(int(pct))
	var base := Vector2(r.position.x + r.size.x - 40, r.position.y + 96) + shake
	var big: int = 74
	var wnum: float = UiStyle.text_width(num, big)
	UiStyle.text(c, "%", Vector2(base.x + 4, base.y - 6), 32, pcol, 0, 5, Color(0, 0, 0, 0.9 * alpha))
	UiStyle.text(c, num, Vector2(base.x - wnum, base.y), big, pcol, 0, 7, Color(0, 0, 0, 0.9 * alpha))
	# stocks
	if not training:
		_draw_stocks(c, p, Vector2(r.position.x + 34, r.end.y + 32), col, alpha)


func _draw_stocks(c: Control, p: int, origin: Vector2, col: Color, alpha: float) -> void:
	var n: int = controller.state.stocks[p]
	if n <= 6:
		for i in n:
			var pos := origin + Vector2(i * 22.0 + 9.0, -9.0)
			c.draw_circle(pos, 10.0, Color(0, 0, 0, 0.85 * alpha))
			c.draw_circle(pos, 8.0, Color(col, alpha))
			c.draw_circle(pos + Vector2(-2.5, -2.5), 3.0, Color(1, 1, 1, 0.45 * alpha))
	else:
		c.draw_circle(origin + Vector2(9, -9), 10.0, Color(0, 0, 0, 0.85 * alpha))
		c.draw_circle(origin + Vector2(9, -9), 8.0, Color(col, alpha))
		UiStyle.text(c, "x %d" % n, Vector2(origin.x + 26, origin.y - 2), 20, Color(UiStyle.TEXT, alpha), 0, 3)


func _draw_banners(c: Control, sz: Vector2) -> void:
	var mid := Vector2(sz.x * 0.5, sz.y * 0.42)
	var n: int = controller.countdown_number()
	if controller.sudden_death_banner:
		UiStyle.text(c, "SUDDEN DEATH", mid + Vector2(0, -130), 54, UiStyle.OP_RED, 1, 8, Color(0, 0, 0, 0.9))
	if n > 0:
		var age: float = float(controller.countdown_age()) / 60.0
		var fs: int = int(150.0 * (1.0 + 0.35 * pow(1.0 - age, 3.0)))
		UiStyle.text(c, str(n), mid + Vector2(0, fs * 0.33), fs, Color(1, 1, 1, 1.0 - age * 0.35), 1, 10, Color(0.05, 0.05, 0.2, 0.9))
	elif controller.go_visible():
		var age2: float = float(controller.go_age()) / float(MatchController.GO_SHOW)
		var fs2: int = int(170.0 * (1.0 + 0.4 * pow(age2, 2.0)))
		UiStyle.text(c, "GO!", mid + Vector2(0, fs2 * 0.33), fs2, Color(UiStyle.GOLD, 1.0 - pow(age2, 3.0)), 1, 10,
			Color(0.2, 0.05, 0.0, 0.9 * (1.0 - age2)))
	var eb: String = controller.end_banner()
	if eb != "":
		var shade := Color(0, 0, 0, 0.35)
		c.draw_rect(Rect2(0, mid.y - 120, sz.x, 190), shade)
		UiStyle.text(c, eb, mid + Vector2(0, 40), 150, UiStyle.TEXT, 1, 12, Color(0.05, 0.05, 0.25, 0.95))


func _draw_training_bar(c: Control, sz: Vector2) -> void:
	var text: String = "D-pad ↑/↓: dummy-% ±10    ←: reset posities    →: dummy-% = 0    Start: pauze    (toetsenbord: F7/F6, F8, F9)"
	var w: float = UiStyle.text_width(text, 15) + 36.0
	var r := Rect2(sz.x * 0.5 - w * 0.5, 80.0, w, 26.0)
	c.draw_rect(r, Color(0.03, 0.04, 0.1, 0.6))
	UiStyle.text(c, text, Vector2(sz.x * 0.5, r.position.y + 19.0), 15, UiStyle.TEXT_DIM, 1)


func _draw_pause(c: Control, sz: Vector2) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.0, 0.05, 0.55))
	var mid := Vector2(sz.x * 0.5, sz.y * 0.4)
	var col: Color = UiStyle.player_color(controller.paused_by)
	UiStyle.text(c, "PAUZE", mid, 96, UiStyle.TEXT, 1, 9, Color(0.05, 0.05, 0.25, 0.95))
	UiStyle.text(c, "Speler %d heeft gepauzeerd" % (controller.paused_by + 1), mid + Vector2(0, 50), 26, col, 1, 4)
	UiStyle.text(c, "Start: verder spelen", mid + Vector2(0, 110), 24, UiStyle.TEXT, 1, 3)
	UiStyle.text(c, "L + R + A + Start: wedstrijd stoppen", mid + Vector2(0, 148), 24, UiStyle.TEXT_DIM, 1, 3)
	UiStyle.text(c, "(toetsenbord: Enter = verder, Q = stoppen)", mid + Vector2(0, 182), 16, UiStyle.TEXT_DIM, 1)
