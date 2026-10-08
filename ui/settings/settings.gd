extends Node
## Autoload `Settings`: gebruikersinstellingen in user://settings.cfg.
## Tap-jump staat standaard AAN (PLAN.md). Alleen opslag + toepassen van scherm/volume;
## gameplay leest `tap_jump_enabled(player)` / `rumble` zelf.

signal changed

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

var path: String = DEFAULT_PATH
var tap_jump: Array[bool] = [true, true]
var rumble: bool = true
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var fullscreen: bool = false


func _ready() -> void:
	load_settings()
	apply()


func tap_jump_enabled(player: int) -> bool:
	return tap_jump[clampi(player, 0, tap_jump.size() - 1)]


func set_tap_jump(player: int, value: bool) -> void:
	tap_jump[clampi(player, 0, tap_jump.size() - 1)] = value
	_touch()


func set_rumble(value: bool) -> void:
	rumble = value
	_touch()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_touch()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_touch()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_touch()


func _touch() -> void:
	apply()
	save_settings()
	changed.emit()


func reset_defaults() -> void:
	tap_jump = [true, true]
	rumble = true
	master_volume = 1.0
	sfx_volume = 1.0
	fullscreen = false
	_touch()


func save_settings() -> Error:
	var cf := ConfigFile.new()
	cf.set_value(SECTION, "tap_jump_p1", tap_jump[0])
	cf.set_value(SECTION, "tap_jump_p2", tap_jump[1])
	cf.set_value(SECTION, "rumble", rumble)
	cf.set_value(SECTION, "master_volume", master_volume)
	cf.set_value(SECTION, "sfx_volume", sfx_volume)
	cf.set_value(SECTION, "fullscreen", fullscreen)
	return cf.save(path)


## Leest het bestand; ontbrekende sleutels houden hun standaardwaarde.
func load_settings() -> Error:
	var cf := ConfigFile.new()
	var err: Error = cf.load(path)
	if err != OK:
		return err
	tap_jump[0] = bool(cf.get_value(SECTION, "tap_jump_p1", true))
	tap_jump[1] = bool(cf.get_value(SECTION, "tap_jump_p2", true))
	rumble = bool(cf.get_value(SECTION, "rumble", true))
	master_volume = clampf(float(cf.get_value(SECTION, "master_volume", 1.0)), 0.0, 1.0)
	sfx_volume = clampf(float(cf.get_value(SECTION, "sfx_volume", 1.0)), 0.0, 1.0)
	fullscreen = bool(cf.get_value(SECTION, "fullscreen", false))
	return OK


func apply() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
		AudioServer.set_bus_mute(bus, master_volume <= 0.0)
	if DisplayServer.get_name() != "headless":
		var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
			else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
