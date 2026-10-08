extends MenuScreen
## Instellingen: tap-jump per speler, rumble, volumes, fullscreen. Slaat direct op via de autoload Settings.

const SCENE_MAIN: String = "res://ui/main_menu/main_menu.tscn"
const VOLUME_STEP: float = 0.1

var list: MenuList
var _header: Control


func _build() -> void:
	_header = Control.new()
	_header.size = UiStyle.SCREEN
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.draw.connect(func() -> void:
		UiStyle.text(_header, "INSTELLINGEN", Vector2(110, 120), 64, UiStyle.TEXT, 0, 8, Color(0.1, 0.05, 0.3, 0.9))
		_header.draw_colored_polygon(PackedVector2Array([Vector2(60, 142), Vector2(700, 142), Vector2(682, 150), Vector2(42, 150)]),
			UiStyle.ACCENT))
	stage.add_child(_header)
	list = MenuList.new()
	list.position = Vector2(110, 190)
	list.row_width = 700.0
	list.font_size = 26
	list.activated.connect(_on_activated)
	list.adjusted.connect(_on_adjusted)
	stage.add_child(list)
	_refresh()
	add_hint_bar("Stick omhoog/omlaag: kiezen    links/rechts: aanpassen    A / Enter: schakelen    B / Esc: terug")


func _refresh() -> void:
	list.items = [
		{"id": "tj0", "label": "Tap-jump speler 1", "value": _onoff(Settings.tap_jump[0])},
		{"id": "tj1", "label": "Tap-jump speler 2", "value": _onoff(Settings.tap_jump[1])},
		{"id": "rumble", "label": "Trillen (rumble)", "value": _onoff(Settings.rumble)},
		{"id": "master", "label": "Hoofdvolume", "value": _pct(Settings.master_volume)},
		{"id": "sfx", "label": "Geluidseffecten", "value": _pct(Settings.sfx_volume)},
		{"id": "fullscreen", "label": "Volledig scherm", "value": _onoff(Settings.fullscreen)},
		{"id": "back", "label": "Terug"},
	]


func _onoff(v: bool) -> String:
	return "AAN" if v else "UIT"


func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


func _on_act(_player: int, act: int) -> void:
	match act:
		MenuNav.Act.UP:
			list.move(-1)
		MenuNav.Act.DOWN:
			list.move(1)
		MenuNav.Act.LEFT:
			list.adjust(-1)
		MenuNav.Act.RIGHT:
			list.adjust(1)
		MenuNav.Act.CONFIRM:
			if list.items[list.selected].has("value"):
				list.adjust(1)
			else:
				list.activate()
		MenuNav.Act.BACK, MenuNav.Act.START:
			UiStyle.sfx("menu_back")
			go(SCENE_MAIN)


func _on_activated(i: int) -> void:
	if String(list.items[i]["id"]) == "back":
		go(SCENE_MAIN)


func _on_adjusted(i: int, dir: int) -> void:
	match String(list.items[i]["id"]):
		"tj0":
			Settings.set_tap_jump(0, not Settings.tap_jump[0])
		"tj1":
			Settings.set_tap_jump(1, not Settings.tap_jump[1])
		"rumble":
			Settings.set_rumble(not Settings.rumble)
		"master":
			Settings.set_master_volume(_step(Settings.master_volume, dir))
		"sfx":
			Settings.set_sfx_volume(_step(Settings.sfx_volume, dir))
		"fullscreen":
			Settings.set_fullscreen(not Settings.fullscreen)
	_refresh()


## Volume in stappen van 10%; verder dan 100% springt naar 0% (voor muis/A-knop).
func _step(v: float, dir: int) -> float:
	var n: int = roundi(v / VOLUME_STEP) + dir
	if n > 10:
		n = 0
	elif n < 0:
		n = 10 if dir > 0 else 0
	return float(n) * VOLUME_STEP
