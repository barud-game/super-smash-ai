extends MenuScreen
## Results-scherm na een wedstrijd: winnaar groot (character in spelerskleur) + per speler KO's / falls / SD's.
## A = rematch (zelfde picks), B = character select. Leest `MatchResult.last`.

const SCENE_SELECT: String = "res://ui/character_select/character_select.tscn"
const SCENE_MATCH: String = "res://ui/match/match.tscn"
const FEET := Vector2(640, 505)
const SCALE := 1.7

var result: MatchResult
var _view: Control
var _visuals: Array[CharacterVisual] = []
var _frame: int = 0
var _confirmed: bool = false


func _build() -> void:
	result = MatchResult.last
	if result == null:
		result = MatchResult.new()
		result.picks = [MatchSetup.picks[0], MatchSetup.picks[1]]
	_view = Control.new()
	_view.size = UiStyle.SCREEN
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	stage.add_child(_view)
	_add_characters()
	add_hint_bar("A: rematch (zelfde characters)        B: character select")


func _add_characters() -> void:
	var show: Array[int] = []
	if result.winner >= 0:
		show.append(result.winner)
	else:
		show = [0, 1]
	for p in show:
		var cv := CharacterVisual.new()
		cv.character_id = result.picks[p]
		cv.player_index = p
		var big: bool = show.size() == 1
		cv.position = FEET if big else Vector2(420 + p * 440, FEET.y)
		cv.scale = Vector2.ONE * (SCALE if big else SCALE * 0.8)
		stage.add_child(cv)
		if cv.is_valid:
			cv.play("idle")
		_visuals.append(cv)


func _tick() -> void:
	_frame += 1
	for cv in _visuals:
		if cv.is_valid:
			cv.tick(_frame)
	_view.queue_redraw()


func _on_act(_player: int, act: int) -> void:
	if _confirmed:
		return
	if act == MenuNav.Act.CONFIRM or act == MenuNav.Act.START:
		_confirmed = true
		UiStyle.sfx("menu_confirm")
		go(SCENE_MATCH)
	elif act == MenuNav.Act.BACK:
		_confirmed = true
		UiStyle.sfx("menu_back")
		go(SCENE_SELECT)


func _name_of(p: int) -> String:
	var info: CharacterInfo = CharacterRegistry.get_info(result.picks[p])
	return info.display_name if info != null else result.picks[p]


func _draw_view() -> void:
	var c: Control = _view
	var head: String = "GAME SET"
	if result.reason == "time":
		head = "TIME!"
	UiStyle.text(c, head, Vector2(640, 66), 30, UiStyle.TEXT_DIM, 1, 3)
	if result.winner >= 0:
		var col: Color = UiStyle.player_color(result.winner)
		# gloed achter de winnaar
		for k in 6:
			c.draw_circle(FEET + Vector2(0, -170), 250.0 - k * 30.0, Color(col, 0.05))
		UiStyle.text(c, "P%d WINT" % (result.winner + 1), Vector2(640, 150), 76, col, 1, 9, Color(0.05, 0.03, 0.15, 0.95))
		var sub: String = _name_of(result.winner)
		if result.sudden_death:
			sub += "   ·   sudden death"
		UiStyle.text(c, sub, Vector2(640, 188), 26, UiStyle.TEXT, 1, 4)
		# vloer-schaduw
		c.draw_rect(Rect2(FEET.x - 150, FEET.y - 2, 300, 6), Color(col, 0.55))
	else:
		UiStyle.text(c, "GELIJKSPEL", Vector2(640, 150), 76, UiStyle.GOLD, 1, 9, Color(0.05, 0.03, 0.15, 0.95))
	for p in 2:
		_draw_card(c, p)


func _draw_card(c: Control, p: int) -> void:
	var col: Color = UiStyle.player_color(p)
	var won: bool = result.winner == p
	var r := Rect2(60 + p * 600, 524, 560, 148)
	c.draw_rect(r, UiStyle.PANEL)
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), col)
	if won:
		c.draw_rect(r, UiStyle.GOLD, false, 3.0)
	UiStyle.text(c, "P%d" % (p + 1), Vector2(r.position.x + 22, r.position.y + 46), 34, col, 0, 4)
	UiStyle.text(c, _name_of(p), Vector2(r.position.x + 84, r.position.y + 46), 28, UiStyle.TEXT, 0, 3)
	if won:
		UiStyle.text(c, "WINNAAR", Vector2(r.end.x - 22, r.position.y + 44), 22, UiStyle.GOLD, 2, 3)
	var cols: Array = [["KO's", result.kos[p]], ["Falls", result.falls[p]], ["SD's", result.sds[p]]]
	for i in cols.size():
		var x: float = r.position.x + 22 + i * 120.0
		UiStyle.text(c, String(cols[i][0]), Vector2(x, r.position.y + 82), 18, UiStyle.TEXT_DIM, 0, 2)
		UiStyle.text(c, str(cols[i][1]), Vector2(x, r.position.y + 124), 40, UiStyle.TEXT, 0, 4)
	var foot: String = "%d stock%s over" % [result.stocks[p], "" if result.stocks[p] == 1 else "s"]
	UiStyle.text(c, foot, Vector2(r.end.x - 22, r.position.y + 100), 20, UiStyle.TEXT_DIM, 2, 2)
	UiStyle.text(c, "%d%%" % int(result.percents[p]), Vector2(r.end.x - 22, r.position.y + 132), 26, UiStyle.TEXT, 2, 3)
