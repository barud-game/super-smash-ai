extends MenuScreen
## Hoofdmenu: Fight, Training, Instellingen, (Sandbox: alleen debug), Afsluiten.

const SCENE_SELECT: String = "res://ui/character_select/character_select.tscn"
const SCENE_SETTINGS: String = "res://ui/settings/settings_menu.tscn"
const SCENE_SANDBOX: String = "res://scenes/sandbox.tscn"

var list: MenuList
var _title: Control
var _status: Control
var _t: float = 0.0


func _build() -> void:
	_title = Control.new()
	_title.size = UiStyle.SCREEN
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.draw.connect(_draw_title)
	stage.add_child(_title)

	list = MenuList.new()
	list.position = Vector2(110, 300)
	list.row_width = 440.0
	var items: Array = [
		{"id": "fight", "label": "Fight"},
		{"id": "training", "label": "Training"},
		{"id": "settings", "label": "Instellingen"},
	]
	if OS.is_debug_build():
		items.append({"id": "sandbox", "label": "Sandbox (debug)"})
	items.append({"id": "quit", "label": "Afsluiten"})
	list.items = items
	list.activated.connect(_on_activated)
	stage.add_child(list)

	_status = Control.new()
	_status.size = UiStyle.SCREEN
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.draw.connect(_draw_status)
	stage.add_child(_status)
	add_hint_bar("Stick / pijlen: kiezen    A / Enter: bevestigen    B / Esc: terug")


func _process(delta: float) -> void:
	_t += delta
	if _title != null:
		_title.queue_redraw()
		_status.queue_redraw()


func _on_act(_player: int, act: int) -> void:
	match act:
		MenuNav.Act.UP:
			list.move(-1)
		MenuNav.Act.DOWN:
			list.move(1)
		MenuNav.Act.CONFIRM, MenuNav.Act.START:
			list.activate()


func _on_activated(i: int) -> void:
	match String(list.items[i]["id"]):
		"fight":
			MatchSetup.mode = MatchSetup.MODE_FIGHT
			go(SCENE_SELECT)
		"training":
			MatchSetup.mode = MatchSetup.MODE_TRAINING
			go(SCENE_SELECT)
		"settings":
			go(SCENE_SETTINGS)
		"sandbox":
			go(SCENE_SANDBOX)
		"quit":
			get_tree().quit()


func _draw_title() -> void:
	var c: Control = _title
	# Schuine accentstrepen achter de titel.
	var bar := PackedVector2Array([Vector2(60, 214), Vector2(900, 214), Vector2(880, 222), Vector2(40, 222)])
	c.draw_colored_polygon(bar, UiStyle.ACCENT)
	c.draw_colored_polygon(PackedVector2Array([Vector2(920, 214), Vector2(1010, 214), Vector2(990, 222), Vector2(900, 222)]),
		UiStyle.ACCENT2)
	UiStyle.text(c, "SUPER", Vector2(104, 112), 56, UiStyle.ACCENT, 0, 6)
	UiStyle.text(c, "SMASH AI", Vector2(100, 202), 104, UiStyle.TEXT, 0, 10, Color(0.1, 0.05, 0.3, 0.9))
	UiStyle.text(c, "platform fighter  ·  jouw eigen characters", Vector2(106, 252), 18, UiStyle.TEXT_DIM)


func _draw_status() -> void:
	var c: Control = _status
	for p in 2:
		var dev: int = InputManager.devices[p]
		var s: String = "Controller %d" % (dev + 1) if dev != InputManager.NO_DEVICE else \
			("Toetsenbord" if p == 0 else "geen controller")
		var ok: bool = dev != InputManager.NO_DEVICE or p == 0
		var col: Color = UiStyle.player_color(p)
		var x: float = 1230.0 - (1 - p) * 230.0   # P1 links van P2
		c.draw_rect(Rect2(x - 214, 28, 214, 34), Color(0.06, 0.07, 0.15, 0.85))
		c.draw_rect(Rect2(x - 214, 28, 6, 34), col if ok else UiStyle.PANEL_EDGE)
		UiStyle.text(c, "P%d" % (p + 1), Vector2(x - 196, 51), 18, col if ok else UiStyle.TEXT_DIM)
		UiStyle.text(c, s, Vector2(x - 162, 51), 16, UiStyle.TEXT if ok else UiStyle.TEXT_DIM)
