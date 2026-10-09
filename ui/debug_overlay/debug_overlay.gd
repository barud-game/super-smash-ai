extends CanvasLayer
## Debug-overlay: F1 = aan/uit, F2 = hitbox-weergave (hook). Alleen renderen, geen gameplay.

const COL_TEXT := Color(1, 1, 1)
const COL_DIM := Color(1, 1, 1, 0.35)
const COL_ON := Color(0.4, 1.0, 0.4)
const BUTTONS: Array = [
	["A", InputFrame.BTN_ATTACK], ["SP", InputFrame.BTN_SPECIAL], ["JMP", InputFrame.BTN_JUMP],
	["SH", InputFrame.BTN_SHIELD], ["Z", InputFrame.BTN_Z], ["ST", InputFrame.BTN_START], ["TA", InputFrame.BTN_TAUNT],
]

var _ctl: Control
var _font: Font


func _ready() -> void:
	layer = 100
	_font = ThemeDB.fallback_font
	_ctl = Control.new()
	_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctl.draw.connect(_draw_overlay)
	add_child(_ctl)


func _process(_delta: float) -> void:
	_ctl.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			visible = not visible
		elif event.keycode == KEY_F2:
			Sim.debug_hitboxes = not Sim.debug_hitboxes


func _text(pos: Vector2, s: String, col: Color = COL_TEXT, size: int = 14) -> void:
	_ctl.draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_overlay() -> void:
	_text(Vector2(12, 20), "Frame %d   FPS %d" % [Sim.frame, Engine.get_frames_per_second()])
	if Sim.paused:
		_text(Vector2(12, 40), "PAUSED  (P = hervat, . = stap)", Color(1, 0.8, 0.2))
	_text(Vector2(12, 60), "Hitboxes (F2): %s" % ("aan" if Sim.debug_hitboxes else "uit"), COL_DIM)
	# Per entity de huidige state-naam (entities mogen get_debug_state_name() aanbieden).
	var y: float = 80.0
	for e in Sim.entities():
		if is_instance_valid(e) and e.has_method("get_debug_state_name"):
			_text(Vector2(12, y), "%s: %s" % [str(e), e.get_debug_state_name()], COL_DIM)
			y += 18.0
	for p in InputManager.MAX_PLAYERS:
		_draw_player(p, Vector2(12 + p * 330, 470))


func _draw_player(p: int, origin: Vector2) -> void:
	var f: InputFrame = InputManager.latest(p)
	var dev: int = InputManager.devices[p]
	var dev_s: String = "geen"
	if dev != InputManager.NO_DEVICE:
		dev_s = "pad %d" % dev
	elif p == 0:
		dev_s = "toetsenbord"
	_text(origin, "P%d  [%s]" % [p + 1, dev_s])
	_draw_stick(origin + Vector2(60, 90), 50.0, f.stick, "stick")
	_draw_stick(origin + Vector2(190, 90), 36.0, f.cstick, "C")
	for t in 2:
		var v: float = f.trigger_l if t == 0 else f.trigger_r
		var r := Rect2(origin + Vector2(260 + t * 26, 40), Vector2(18, 100))
		_ctl.draw_rect(r, COL_DIM, false)
		_ctl.draw_rect(Rect2(r.position.x, r.end.y - r.size.y * v, r.size.x, r.size.y * v), COL_ON)
		_text(r.position + Vector2(2, 116), "L" if t == 0 else "R", COL_DIM, 12)
	for i in BUTTONS.size():
		var on: bool = f.has(BUTTONS[i][1])
		var pos: Vector2 = origin + Vector2(i * 46, 175)
		_ctl.draw_circle(pos + Vector2(8, 8), 7.0, COL_ON if on else COL_DIM)
		_text(pos + Vector2(-2, 32), BUTTONS[i][0], COL_DIM, 11)


func _draw_stick(c: Vector2, r: float, v: Vector2i, label: String) -> void:
	_ctl.draw_arc(c, r, 0.0, TAU, 48, COL_DIM, 1.5)
	_ctl.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(1, 1, 1, 0.12))
	_ctl.draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(1, 1, 1, 0.12))
	var dz: float = r * float(MeleeStick.DEADZONE) / float(MeleeStick.GRID)
	_ctl.draw_arc(c, dz, 0.0, TAU, 24, Color(1, 0.4, 0.4, 0.3), 1.0)
	var pt := c + Vector2(v.x, -v.y) / float(MeleeStick.GRID) * r
	_ctl.draw_circle(pt, 4.0, COL_ON)
	_text(c + Vector2(-r, r + 16), "%s %d,%d" % [label, v.x, v.y], COL_TEXT, 12)
