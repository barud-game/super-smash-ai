extends Control
## SFX-previewtool. Omhoog/omlaag = blader, Enter/Spatie = afspelen, E = exporteer dit geluid
## naar tools/sfx_preview/out/<naam>.wav, Shift+E = exporteer alle. R = recepten opnieuw laden.
## Draaien: open tools/sfx_preview/sfx_preview.tscn in de editor en druk F6.

const OUT_DIR: String = "res://tools/sfx_preview/out/"

var _names: PackedStringArray = SfxBank.NAMES
var _index: int = 0
var _player := AudioStreamPlayer.new()
var _label := Label.new()
var _wave := PackedFloat32Array()
var _stats: Dictionary = {}
var _status: String = ""


func _ready() -> void:
	add_child(_player)
	_label.position = Vector2(24, 16)
	add_child(_label)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_select(0)


func _select(i: int) -> void:
	_index = posmod(i, _names.size())
	var r: Dictionary = SfxBank.get_recipe(_names[_index])
	_wave = SfxSynth.render(r)
	_stats = SfxSynth.stats(_wave)
	_refresh()
	queue_redraw()


func _refresh() -> void:
	var lines: PackedStringArray = []
	for i in _names.size():
		lines.append("%s %s" % [">" if i == _index else " ", _names[i]])
	_label.text = "SFX preview  (Up/Down blader, Enter speel, E export, Shift+E export alles, R herlaad)\n\n" \
		+ "\n".join(lines) \
		+ "\n\n%s  dur %.3fs  peak %.3f  rms %.3f\n%s" % [_names[_index], _stats["duration"], _stats["peak"], _stats["rms"], _status]


func _play() -> void:
	_player.stream = SfxSynth.to_stream(_wave)
	_player.volume_db = SfxBank.get_volume_db(_names[_index])
	_player.play()


func _export(sfx_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var s: AudioStreamWAV = SfxSynth.to_stream(SfxSynth.render(SfxBank.get_recipe(sfx_name)))
	var path: String = ProjectSettings.globalize_path(OUT_DIR + sfx_name + ".wav")
	var err: Error = s.save_to_wav(path)
	_status = "Export %s: %s" % [path, "ok" if err == OK else error_string(err)]


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_UP:
			_select(_index - 1)
			_play()
		KEY_DOWN:
			_select(_index + 1)
			_play()
		KEY_ENTER, KEY_SPACE:
			_play()
		KEY_R:
			SfxBank.clear_cache()
			_select(_index)
			_status = "Recepten herladen"
			_refresh()
		KEY_E:
			if k.shift_pressed:
				for n in _names:
					_export(n)
				_status = "Alles geëxporteerd naar " + ProjectSettings.globalize_path(OUT_DIR)
			else:
				_export(_names[_index])
			_refresh()


func _draw() -> void:
	if _wave.is_empty():
		return
	var rect := Rect2(Vector2(360, 80), Vector2(size.x - 400, 240))
	draw_rect(rect, Color(0.08, 0.09, 0.12))
	var mid: float = rect.position.y + rect.size.y * 0.5
	draw_line(Vector2(rect.position.x, mid), Vector2(rect.end.x, mid), Color(0.3, 0.3, 0.35))
	var cols: int = int(rect.size.x)
	var per: float = float(_wave.size()) / cols
	for c in cols:
		var lo: float = 0.0
		var hi: float = 0.0
		var a: int = int(c * per)
		var b: int = mini(int((c + 1) * per) + 1, _wave.size())
		for j in range(a, b):
			lo = minf(lo, _wave[j])
			hi = maxf(hi, _wave[j])
		var x: float = rect.position.x + c
		draw_line(Vector2(x, mid - hi * rect.size.y * 0.5), Vector2(x, mid - lo * rect.size.y * 0.5), Color(0.4, 0.85, 1.0))
