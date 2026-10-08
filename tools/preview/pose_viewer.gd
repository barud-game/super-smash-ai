extends Node2D
## Pose-viewer: blader in de editor (F6 op deze scene) door de poses van een character.
##
##   Links/Rechts   vorige/volgende pose
##   Omhoog/Omlaag  tempo (0.25x .. 2x)
##   Spatie         pauze;  ,/.  een frame terug/vooruit (bij pauze)
##   F              spiegel (facing)
##   P              wissel speler-kleur
##   C              wissel character (map onder characters/)
##   R              herlaad SVG's en poses van schijf (hot reload)
##
## Dit is een tool: het mag _physics_process gebruiken om op 60 Hz te lopen, de game-visual niet.

@export var character_id: String = "_dummy"

var _cv: CharacterVisual
var _names: Array = []
var _idx: int = 0
var _frame: int = 0
var _paused: bool = false
var _speed: float = 1.0
var _label: Label
var _player: int = 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("e8e6df"))
	_cv = CharacterVisual.new()
	_cv.character_id = character_id
	_cv.position = Vector2(640, 520)
	_cv.scale = Vector2(2.2, 2.2)
	add_child(_cv)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_color_override("font_color", Color("222230"))
	layer.add_child(_label)
	_refresh_names()
	_select(0)


func _refresh_names() -> void:
	_names = _cv.library.poses.keys()
	_names.sort()


func _select(i: int) -> void:
	if _names.is_empty():
		return
	_idx = posmod(i, _names.size())
	_frame = 0
	_cv.play(_names[_idx])
	_update_label()


func _physics_process(_delta: float) -> void:
	if _names.is_empty():
		return
	if not _paused:
		_frame += 1
		var p: Pose = _cv.library.poses[_names[_idx]]
		if not p.loop and _frame > int(p.length) + 30:
			_frame = 0
		_cv.tick(_frame, _speed)
	_update_label()


func _update_label() -> void:
	var status := "OK" if _cv.is_valid else "FOUTEN: " + "; ".join(_cv.errors)
	_label.text = "%s  [%d/%d] %s  frame %d  tempo %.2fx%s  speler %d  %s\n< > pose | ^ v tempo | spatie pauze | , . frame | F spiegel | P kleur | C character | R herlaad" % [
		character_id, _idx + 1, _names.size(), _names[_idx] if not _names.is_empty() else "-", _frame, _speed, " (pauze)" if _paused else "", _player + 1, status]


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.keycode:
		KEY_RIGHT: _select(_idx + 1)
		KEY_LEFT: _select(_idx - 1)
		KEY_UP: _speed = minf(_speed * 2.0, 2.0)
		KEY_DOWN: _speed = maxf(_speed * 0.5, 0.25)
		KEY_SPACE: _paused = not _paused
		KEY_PERIOD:
			_paused = true
			_frame += 1
			_cv.tick(_frame, _speed)
		KEY_COMMA:
			_paused = true
			_frame = maxi(0, _frame - 1)
			_cv.tick(_frame, _speed)
		KEY_F: _cv.facing = -_cv.facing
		KEY_P:
			_player = (_player + 1) % Rig.PLAYER_PALETTES.size()
			_cv.set_player(_player)
		KEY_C: _next_character()
		KEY_R:
			_cv.reload()
			_refresh_names()
			_select(mini(_idx, _names.size() - 1))


func _next_character() -> void:
	var dir := DirAccess.open("res://characters")
	if dir == null:
		return
	var ids: Array = []
	for d in dir.get_directories():
		if DirAccess.dir_exists_absolute("res://characters/%s/art" % d):
			ids.append(d)
	ids.sort()
	if ids.is_empty():
		return
	var i: int = ids.find(character_id)
	character_id = ids[(i + 1) % ids.size()]
	_cv.character_id = character_id
	_refresh_names()
	_select(0)
