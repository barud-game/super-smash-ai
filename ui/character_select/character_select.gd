extends MenuScreen
## Character select. Fight: 2 spelers met eigen cursor en token. Training: alleen speler 1 kiest,
## de dummy wordt een willekeurig ander character. Grid met pagina's, zoeken en archetype-filter.
##
## Bediening (controller): stick = cursor, A = token plaatsen/starten, B = token terugpakken/terug,
## X = filter wisselen, LT/RT = pagina. Toetsenbord (P1): pijlen/Enter/Esc/Tab/PageUp/PageDown,
## "/" of Ctrl+F = zoeken. Muis: klik = kiezen, wiel = pagina.

const SCENE_MAIN: String = "res://ui/main_menu/main_menu.tscn"
const SCENE_MATCH: String = "res://ui/match/match.tscn"

const COLS: int = 7
const ROWS: int = 3
const PER_PAGE: int = COLS * ROWS
const GRID_POS := Vector2(45, 98)
const CELL := Vector2(158, 112)
const GAP := Vector2(14, 8)
const PANEL_Y: float = 484.0
const FILTER_ALL: String = ""
const FILTER_OP: String = "__op"

var training: bool = false
var entries: Array = []            # [null (= Random)] + CharacterInfo's
var cursor: Array[int] = [0, 0]
var locked: Array[bool] = [false, false]
var locked_id: Array[String] = ["", ""]
var locked_random: Array[bool] = [false, false]
var view_page: int = 0
var filter: String = FILTER_ALL
var query: String = ""

var cells: Array[CharCell] = []
var panels: Array[PlayerPanel] = []
var portraits: PortraitCache
var search: LineEdit
var _overlay: Control
var _header: Control
var _rng := RandomNumberGenerator.new()
var _mute_frames: int = 0
var _starting: bool = false




func _build() -> void:
	_rng.randomize()
	training = MatchSetup.mode == MatchSetup.MODE_TRAINING
	if training:
		active_players = [0]
	portraits = PortraitCache.new()
	add_child(portraits)

	_header = Control.new()
	_header.size = UiStyle.SCREEN
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.draw.connect(_draw_header)
	stage.add_child(_header)

	search = LineEdit.new()
	search.position = Vector2(880, 26)
	search.size = Vector2(360, 36)
	search.placeholder_text = "Zoek character…  ( / )"
	search.clear_button_enabled = true
	search.add_theme_font_size_override("font_size", 16)
	search.add_theme_color_override("font_color", UiStyle.TEXT)
	search.add_theme_color_override("font_placeholder_color", UiStyle.TEXT_DIM)
	search.add_theme_color_override("caret_color", UiStyle.ACCENT)
	search.add_theme_stylebox_override("normal", UiStyle.rounded_box(Color(0.06, 0.07, 0.16, 0.9), 4, UiStyle.PANEL_EDGE, 1))
	search.add_theme_stylebox_override("focus", UiStyle.rounded_box(Color(0.08, 0.1, 0.22, 0.95), 4, UiStyle.ACCENT, 2))
	search.text_changed.connect(_on_search_changed)
	search.text_submitted.connect(func(_t: String) -> void: search.release_focus())
	search.gui_input.connect(_on_search_gui_input)
	stage.add_child(search)

	# Filterknop (klikbaar).
	var chip := Control.new()
	chip.position = Vector2(880, 70)
	chip.size = Vector2(360, 26)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_cycle_filter())
	stage.add_child(chip)

	for i in PER_PAGE:
		var cell := CharCell.new()
		cell.size = CELL
		cell.position = _cell_pos(i)
		cell.clicked.connect(_on_cell_clicked)
		cell.wheel.connect(func(d: int) -> void: _change_page(0, d))
		stage.add_child(cell)
		cells.append(cell)

	for p in 2:
		var panel := PlayerPanel.new()
		panel.player = p
		panel.position = Vector2(40 + p * 610, PANEL_Y)
		if training and p == 1:
			panel.kind = "dummy"
		stage.add_child(panel)
		panels.append(panel)

	_overlay = Control.new()
	_overlay.size = UiStyle.SCREEN
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	stage.add_child(_overlay)

	add_hint_bar("Stick: cursor    A: kiezen / starten    B: terug    X: filter    LT/RT: pagina    /: zoeken")
	CharacterRegistry.rescanned.connect(_rebuild_entries)
	_rebuild_entries()
	if entries.size() > 1:
		cursor = [1, 1]
	_refresh_all()


func _cell_pos(i: int) -> Vector2:
	var col: int = i % COLS
	var row: int = i / COLS
	return GRID_POS + Vector2(col * (CELL.x + GAP.x), row * (CELL.y + GAP.y))


# ---------------------------------------------------------------- lijst / filter

func _rebuild_entries() -> void:
	entries = [null]
	for c in CharacterRegistry.characters:
		if filter == FILTER_OP and not c.op:
			continue
		if filter != FILTER_ALL and filter != FILTER_OP and c.archetype != filter:
			continue
		if not c.matches(query):
			continue
		entries.append(c)
	for p in 2:
		cursor[p] = clampi(cursor[p], 0, entries.size() - 1)
	view_page = clampi(view_page, 0, _page_count() - 1)


func _page_count() -> int:
	return maxi(1, ceili(float(entries.size()) / PER_PAGE))


func _filter_options() -> Array[String]:
	var o: Array[String] = [FILTER_ALL]
	o.append_array(CharacterRegistry.archetypes_in_use())
	o.append(FILTER_OP)
	return o


func _filter_label() -> String:
	if filter == FILTER_ALL:
		return "Alle"
	if filter == FILTER_OP:
		return "Alleen OP"
	return filter


func _cycle_filter() -> void:
	var o: Array[String] = _filter_options()
	filter = o[(maxi(o.find(filter), 0) + 1) % o.size()]
	UiStyle.sfx("menu_move")
	_filter_changed()


func _filter_changed() -> void:
	_rebuild_entries()
	cursor = [mini(1, entries.size() - 1), mini(1, entries.size() - 1)]
	view_page = 0
	_refresh_all()


func _on_search_changed(text: String) -> void:
	query = text
	_filter_changed()


func _on_search_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		search.release_focus()
		search.accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or search.has_focus():
		return
	if k.keycode == KEY_SLASH or (k.keycode == KEY_F and k.ctrl_pressed):
		search.grab_focus()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if search != null and search.has_focus() and event is InputEventMouseButton and event.pressed:
		if not search.get_global_rect().has_point(event.position):
			search.release_focus()


# ---------------------------------------------------------------- weergave verversen

func _refresh_all() -> void:
	_refresh_cells()
	_refresh_panels()
	_overlay.queue_redraw()
	_header.queue_redraw()


func _refresh_cells() -> void:
	for i in PER_PAGE:
		var slot: int = view_page * PER_PAGE + i
		var cell: CharCell = cells[i]
		if slot < entries.size():
			var info: CharacterInfo = entries[slot]
			cell.visible = true
			cell.set_entry(slot, info, portraits.texture(info, 0) if info != null else null)
		else:
			cell.visible = false


func _refresh_panels() -> void:
	for p in 2:
		var panel: PlayerPanel = panels[p]
		panel.locked = locked[p] or (training and p == 1)
		var dev: int = InputManager.devices[p]
		panel.connected_text = ("Controller %d" % (dev + 1)) if dev != InputManager.NO_DEVICE \
			else ("Toetsenbord" if p == 0 else "geen controller")
		if training and p == 1:
			panel.show_info(null, true)
			panel.connected_text = ""
			continue
		if locked[p]:
			if locked_random[p]:
				panel.show_info(CharacterRegistry.get_info(locked_id[p]), false)
			else:
				panel.show_info(CharacterRegistry.get_info(locked_id[p]), false)
		else:
			var e: Variant = entries[cursor[p]] if cursor[p] < entries.size() else null
			panel.show_info(e as CharacterInfo, e == null)
		var cp: int = cursor[p] / PER_PAGE
		panel.page_hint = "cursor op pagina %d" % (cp + 1) if (cp != view_page and not locked[p]) else ""


# ---------------------------------------------------------------- invoer

func _tick() -> void:
	if search.has_focus():
		_mute_frames = 15
	nav.muted[0] = _mute_frames > 0
	if _mute_frames > 0 and not search.has_focus():
		_mute_frames -= 1
	_overlay.queue_redraw()


func _on_act(p: int, act: int) -> void:
	if _starting:
		return
	match act:
		MenuNav.Act.UP:
			_move(p, 0, -1)
		MenuNav.Act.DOWN:
			_move(p, 0, 1)
		MenuNav.Act.LEFT:
			_move(p, -1, 0)
		MenuNav.Act.RIGHT:
			_move(p, 1, 0)
		MenuNav.Act.CONFIRM:
			_confirm(p)
		MenuNav.Act.BACK:
			_back(p)
		MenuNav.Act.START:
			if _ready_to_start():
				_start()
			elif not locked[p]:
				_confirm(p)
		MenuNav.Act.SECONDARY:
			_cycle_filter()
		MenuNav.Act.PAGE_PREV:
			_change_page(p, -1)
		MenuNav.Act.PAGE_NEXT:
			_change_page(p, 1)


func _move(p: int, dx: int, dy: int) -> void:
	if locked[p]:
		return
	var n: int = entries.size()
	var idx: int = cursor[p]
	if dx != 0:
		idx = posmod(idx + dx, n)
	elif dy != 0:
		var ni: int = idx + dy * COLS
		if ni >= 0 and ni < n:
			idx = ni
	if idx != cursor[p]:
		cursor[p] = idx
		view_page = idx / PER_PAGE
		UiStyle.sfx("menu_move")
		_refresh_all()


func _change_page(p: int, dir: int) -> void:
	var pages: int = _page_count()
	if pages <= 1:
		return
	var np: int = posmod(view_page + dir, pages)
	var slot_in_page: int = cursor[p] % PER_PAGE
	view_page = np
	if not locked[p]:
		cursor[p] = mini(np * PER_PAGE + slot_in_page, entries.size() - 1)
	UiStyle.sfx("menu_move")
	_refresh_all()


func _on_cell_clicked(slot: int) -> void:
	if _starting:
		return
	if locked[0]:
		if _ready_to_start():
			_start()
		return
	cursor[0] = slot
	_confirm(0)
	_refresh_all()


func _confirm(p: int) -> void:
	if locked[p]:
		if _ready_to_start():
			_start()
		return
	var e: Variant = entries[cursor[p]] if cursor[p] < entries.size() else null
	var info := e as CharacterInfo
	if info == null:
		var pool: Array[CharacterInfo] = []
		for x in entries:
			if x != null:
				pool.append(x)
		if pool.is_empty():
			pool.append_array(CharacterRegistry.characters)
		if pool.is_empty():
			return
		info = pool[_rng.randi_range(0, pool.size() - 1)]
		locked_random[p] = true
	else:
		locked_random[p] = false
	locked[p] = true
	locked_id[p] = info.id
	UiStyle.sfx("menu_confirm")
	_refresh_all()


func _back(p: int) -> void:
	if locked[p]:
		locked[p] = false
		locked_random[p] = false
		UiStyle.sfx("menu_back")
		_refresh_all()
	elif p == 0:
		UiStyle.sfx("menu_back")
		go(SCENE_MAIN)


func _ready_to_start() -> bool:
	if training:
		return locked[0]
	return locked[0] and locked[1]


func _start() -> void:
	_starting = true
	MatchSetup.mode = MatchSetup.MODE_TRAINING if training else MatchSetup.MODE_FIGHT
	MatchSetup.picks = [locked_id[0], locked_id[1]]
	MatchSetup.was_random = [locked_random[0], locked_random[1]]
	if training:
		MatchSetup.picks[1] = CharacterRegistry.random_id(_rng, locked_id[0])
		MatchSetup.was_random[1] = true
	UiStyle.sfx("menu_start")
	go(SCENE_MATCH)


# ---------------------------------------------------------------- tekenen

func _draw_header() -> void:
	var c: Control = _header
	UiStyle.text(c, "TRAINING" if training else "FIGHT", Vector2(46, 34), 16, UiStyle.ACCENT2, 0, 0)
	UiStyle.text(c, "KIES JE CHARACTER", Vector2(44, 76), 34, UiStyle.TEXT, 0, 5, Color(0.1, 0.05, 0.3, 0.9))
	c.draw_colored_polygon(PackedVector2Array([Vector2(46, 86), Vector2(520, 86), Vector2(512, 91), Vector2(38, 91)]),
		UiStyle.ACCENT)
	var pages: int = _page_count()
	var shown: int = entries.size() - 1
	UiStyle.text(c, "Pagina %d / %d   ·   %d characters" % [view_page + 1, pages, shown],
		Vector2(540, 76), 16, UiStyle.TEXT_DIM)
	# Filterchip.
	var r := Rect2(880, 70, 360, 26)
	c.draw_rect(r, Color(0.06, 0.07, 0.16, 0.9))
	c.draw_rect(r, UiStyle.PANEL_EDGE if filter == FILTER_ALL else UiStyle.GOLD if filter == FILTER_OP else UiStyle.ACCENT, false, 1.5)
	UiStyle.text(c, "FILTER  [X]", Vector2(890, 89), 13, UiStyle.TEXT_DIM)
	UiStyle.text(c, _filter_label().to_upper(), Vector2(1230, 89), 15,
		UiStyle.GOLD if filter == FILTER_OP else UiStyle.TEXT, 2)
	if entries.size() <= 1:
		UiStyle.text(c, "Geen characters gevonden", Vector2(640, 300), 26, UiStyle.TEXT_DIM, 1)


func _draw_overlay() -> void:
	var o: Control = _overlay
	var now: float = Time.get_ticks_msec() / 1000.0
	# Tokens (geplaatst) eerst, cursors erboven.
	for p in 2:
		if locked[p]:
			var idx: int = _entry_index(locked_id[p], locked_random[p])
			if idx != -1 and idx / PER_PAGE == view_page:
				_draw_token(o, p, idx)
	for p in active_players:
		if locked[p] or cursor[p] / PER_PAGE != view_page:
			continue
		_draw_cursor(o, p, cursor[p], now)
	if _ready_to_start() and not _starting:
		var a: float = 0.75 + 0.25 * sin(now * 5.0)
		var rr := Rect2(340, 456, 600, 26)
		o.draw_colored_polygon(UiStyle.slanted(rr, 14.0), Color(0.05, 0.3, 0.12, 0.95))
		UiStyle.outline_poly(o, UiStyle.slanted(rr, 14.0), Color(0.5, 1.0, 0.6, a), 2.0)
		UiStyle.text(o, "BEREID  ·  A of START om te beginnen  ·  B om te wijzigen", Vector2(640, 475), 16,
			Color(0.8, 1.0, 0.85, a), 1)


func _entry_index(id: String, was_random: bool) -> int:
	if was_random:
		return 0 if entries.size() > 0 else -1   # token blijft op de Random-tegel zichtbaar
	for i in range(1, entries.size()):
		if (entries[i] as CharacterInfo).id == id:
			return i
	return -1


func _slot_rect(idx: int) -> Rect2:
	return Rect2(_cell_pos(idx % PER_PAGE), CELL)


func _draw_cursor(o: Control, p: int, idx: int, now: float) -> void:
	var col: Color = UiStyle.player_color(p)
	var r: Rect2 = _slot_rect(idx)
	var inset: float = 0.0
	if active_players.size() > 1 and cursor[1 - p] == idx and not locked[1 - p] and p == 1:
		inset = 6.0
	var pulse: float = 0.5 + 0.5 * sin(now * 8.0)
	r = r.grow(3.0 - inset)
	o.draw_rect(r.grow(2.0), Color(col.r, col.g, col.b, 0.18 + 0.16 * pulse), false, 6.0)
	o.draw_rect(r, col, false, 4.0)
	var tag := Rect2(r.position + Vector2(-2, -22), Vector2(34, 22))
	if p == 1:
		tag.position.x = r.end.x - 32.0
	o.draw_rect(tag, col)
	UiStyle.text(o, "P%d" % (p + 1), tag.position + Vector2(17, 16), 15, Color.WHITE, 1)


func _draw_token(o: Control, p: int, idx: int) -> void:
	var col: Color = UiStyle.player_color(p)
	var r: Rect2 = _slot_rect(idx)
	o.draw_rect(r.grow(2.0), col, false, 4.0)
	var c: Vector2 = Vector2(r.end.x - 20 - p * 28, r.position.y + 44)
	o.draw_circle(c, 14.0, Color(0, 0, 0, 0.5))
	o.draw_circle(c, 12.0, col)
	o.draw_arc(c, 12.0, 0, TAU, 24, Color.WHITE, 2.0, true)
	UiStyle.text(o, "P%d" % (p + 1), c + Vector2(0, 5), 13, Color.WHITE, 1)
