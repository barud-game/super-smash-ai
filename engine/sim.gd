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
## Debug-toetsen (P = pauze, `.` = stap, Back = pauze, RB = stap) werken alleen als dit aan staat:
## de sandbox en training zetten het aan. In menu's en in een gewone match is Start de pauze.
var debug_context: bool = false

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
	# Over een kopie lopen: een entity mag zich tijdens een tick afmelden of registreren zonder dat de
	# volgorde van de rest van dit frame verschuift.
	for e: Object in _entities.duplicate():
		if is_instance_valid(e) and _entities.has(e):
			e.sim_tick(frame)
	var k: int = _entities.size() - 1
	while k >= 0:
		if not is_instance_valid(_entities[k]):
			_entities.remove_at(k)
		k -= 1
	frame += 1
	frame_advanced.emit(frame)


func _input(event: InputEvent) -> void:
	if not debug_context:
		return
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
