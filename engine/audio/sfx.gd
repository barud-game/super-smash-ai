extends Node
## Autoload `Sfx`. Speelt gegenereerde geluidseffecten af via een kleine pool van spelers.
## Pitch-variatie gebruikt een eigen RNG en raakt de gameplay/sim nooit.

const POOL_SIZE: int = 16

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()
var enabled: bool = true


func _ready() -> void:
	_rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Speelt `sfx_name`. `pitch_variance` 0.05 = willekeurig +-5% toonhoogte.
## `character_id` zoekt eerst characters/<id>/sfx/<naam>.json.
func play(sfx_name: String, pitch_variance: float = 0.0, volume_db: float = 0.0, character_id: String = "") -> void:
	if not enabled:
		return
	var stream: AudioStreamWAV = SfxBank.get_stream(sfx_name, character_id)
	if stream == null:
		return
	var p: AudioStreamPlayer = _free_player()
	p.stream = stream
	p.volume_db = volume_db + SfxBank.get_volume_db(sfx_name, character_id)
	p.pitch_scale = 1.0 + (_rng.randf_range(-pitch_variance, pitch_variance) if pitch_variance > 0.0 else 0.0)
	p.play()


## Genereert alle geluiden vooraf (bv. tijdens een laadscherm) zodat de eerste hit niet hapert.
func preload_all(character_id: String = "") -> void:
	for n in SfxBank.NAMES:
		SfxBank.get_stream(n, character_id)


func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p2: AudioStreamPlayer = _players[_next]   # alles bezet: round-robin overnemen
	_next = (_next + 1) % _players.size()
	return p2
