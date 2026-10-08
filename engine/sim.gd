extends Node
## Autoload `Sim`: de simulatieklok. Enige plek met een gameplay-_physics_process.
## Volgorde per frame: 1) input samplen, 2) entities in registratievolgorde `sim_tick(frame)`.
## Gameplay gebruikt nooit delta; alles in frames.

signal frame_advanced(frame: int)
signal pause_changed(paused: bool)

## Aantal frames dat sim-ticks hebben gedraaid.
var frame: int = 0
var paused: bool = false
## Debug-toggle (F2); de eigenlijke hitbox-weergave volgt in een latere mijlpaal.
var debug_hitboxes: bool = false

var _entities: Array[Object] = []
var _step_requested: bool = false


## Registreer een gameplay-object. Het moet `sim_tick(frame: int)` hebben.
func register(entity: Object) -> void:
	if not _entities.has(entity):
		_entities.append(entity)


func unregister(entity: Object) -> void:
	_entities.erase(entity)


func entities() -> Array[Object]:
	return _entities


func set_paused(value: bool) -> void:
	if paused != value:
		paused = value
		pause_changed.emit(paused)


func request_step() -> void:
	if paused:
		_step_requested = true


func _physics_process(_delta: float) -> void:
	if paused:
		if not _step_requested:
			return
		_step_requested = false
	_advance()


func _advance() -> void:
	InputManager.sample(frame)
	var i: int = 0
	while i < _entities.size():
		var e: Object = _entities[i]
		if is_instance_valid(e):
			e.sim_tick(frame)
			i += 1
		else:
			_entities.remove_at(i)
	frame += 1
	frame_advanced.emit(frame)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P:
				set_paused(not paused)
			KEY_PERIOD:
				request_step()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_BACK:
			set_paused(not paused)
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER and OS.is_debug_build():
			request_step()
