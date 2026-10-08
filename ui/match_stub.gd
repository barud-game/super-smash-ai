extends MenuScreen
## Tijdelijke stub voor de match (M6): toont de keuzes uit MatchSetup. B = terug naar de character select.

const SCENE_SELECT: String = "res://ui/character_select/character_select.tscn"

var _view: Control


func _build() -> void:
	_view = Control.new()
	_view.size = UiStyle.SCREEN
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	stage.add_child(_view)
	add_hint_bar("B / Esc: terug naar character select    (stub: de echte match volgt in M6)")


func _on_act(_player: int, act: int) -> void:
	if act == MenuNav.Act.BACK:
		UiStyle.sfx("menu_back")
		go(SCENE_SELECT)


func _draw_view() -> void:
	var c: Control = _view
	var training: bool = MatchSetup.mode == MatchSetup.MODE_TRAINING
	UiStyle.text(c, "TRAINING" if training else "FIGHT", Vector2(640, 110), 64, UiStyle.TEXT, 1, 8,
		Color(0.1, 0.05, 0.3, 0.9))
	UiStyle.text(c, "match-stub: hier komt de stage met de fighters", Vector2(640, 148), 18, UiStyle.TEXT_DIM, 1)
	for p in 2:
		var x: float = 120.0 + p * 560.0
		var col: Color = UiStyle.player_color(p)
		var id: String = MatchSetup.picks[p]
		var info: CharacterInfo = CharacterRegistry.get_info(id)
		c.draw_rect(Rect2(x, 200, 480, 220), UiStyle.PANEL)
		c.draw_rect(Rect2(x, 200, 480, 6), col)
		var who: String = "P%d" % (p + 1)
		if training and p == 1:
			who = "DUMMY"
		UiStyle.text(c, who, Vector2(x + 24, 250), 34, col, 0, 3)
		var nm: String = info.display_name if info != null else (id if id != "" else "?")
		UiStyle.text(c, nm, Vector2(x + 24, 310), 44, UiStyle.TEXT)
		if info != null:
			UiStyle.text(c, info.archetype + ("   ·   OP" if info.op else ""), Vector2(x + 24, 348), 22,
				UiStyle.GOLD if info.op else UiStyle.TEXT_DIM)
		if MatchSetup.was_random[p]:
			UiStyle.text(c, "(random)", Vector2(x + 24, 384), 18, UiStyle.ACCENT)
		var dev: int = InputManager.devices[p]
		UiStyle.text(c, "Controller %d" % (dev + 1) if dev != InputManager.NO_DEVICE else "Toetsenbord / geen controller",
			Vector2(x + 24, 408), 16, UiStyle.TEXT_DIM)
	UiStyle.text(c, "Regels: " + MatchSetup.rules.summary(), Vector2(640, 480), 20, UiStyle.TEXT, 1)
	UiStyle.text(c, "Tap-jump:  P1 %s   P2 %s" % [
		"aan" if Settings.tap_jump[0] else "uit", "aan" if Settings.tap_jump[1] else "uit"],
		Vector2(640, 514), 18, UiStyle.TEXT_DIM, 1)
