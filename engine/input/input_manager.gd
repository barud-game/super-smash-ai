extends Node
## Autoload `InputManager`: koppelt joypads aan spelers en levert per sim-frame een InputFrame.
## Alleen input; geen gameplay-logica. Wordt aangeroepen door Sim vóór de entities.

const MAX_PLAYERS: int = 2
const NO_DEVICE: int = -1

## Joypad-device per speler (NO_DEVICE = vrij).
var devices: Array[int] = []
var _histories: Array[InputHistory] = []
## Optionele gescripte bron (tools/bench, tests): `(player: int, frame: int) -> InputFrame` vervangt het
## pad/toetsenbord-samplen. Ongeldige Callable = normale input.
var scripted_source: Callable = Callable()


func _ready() -> void:
	for i in MAX_PLAYERS:
		devices.append(NO_DEVICE)
		_histories.append(InputHistory.new())
	for d in Input.get_connected_joypads():
		_assign(d)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_assign(device)
	else:
		var p: int = devices.find(device)
		if p != -1:
			devices[p] = NO_DEVICE


func _assign(device: int) -> void:
	if devices.has(device):
		return
	var p: int = devices.find(NO_DEVICE)
	if p != -1:
		devices[p] = device


func history(player: int) -> InputHistory:
	return _histories[player]


func latest(player: int) -> InputFrame:
	return _histories[player].get_frame(0)


## Sampled alle spelers en duwt het resultaat in de ringbuffers. Eén keer per sim-frame.
func sample(_frame: int) -> void:
	if scripted_source.is_valid():
		for p in MAX_PLAYERS:
			_histories[p].push(scripted_source.call(p, _frame))
		return
	for p in MAX_PLAYERS:
		var f: InputFrame = null
		if devices[p] != NO_DEVICE:
			f = _sample_pad(devices[p])
		if p == 0:
			var k: InputFrame = _sample_keyboard()
			if f == null or _is_active(k):
				f = k
		if f == null:
			f = InputFrame.new()
		_histories[p].push(f)


func _is_active(f: InputFrame) -> bool:
	return f.stick != Vector2i.ZERO or f.cstick != Vector2i.ZERO or f.buttons != 0 \
		or f.trigger_l > 0.0 or f.trigger_r > 0.0


func _sample_pad(d: int) -> InputFrame:
	var f := InputFrame.new()
	# Godot: y-as omlaag = positief; Melee: omhoog = positief.
	f.stick = MeleeStick.quantize(Vector2(
		Input.get_joy_axis(d, JOY_AXIS_LEFT_X), -Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)))
	f.cstick = MeleeStick.quantize(Vector2(
		Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), -Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y)))
	f.trigger_l = clampf(Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT), 0.0, 1.0)
	f.trigger_r = clampf(Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT), 0.0, 1.0)
	var b: int = 0
	if Input.is_joy_button_pressed(d, JOY_BUTTON_A):
		b |= InputFrame.BTN_ATTACK
	if Input.is_joy_button_pressed(d, JOY_BUTTON_X):
		b |= InputFrame.BTN_SPECIAL
	if Input.is_joy_button_pressed(d, JOY_BUTTON_Y) or Input.is_joy_button_pressed(d, JOY_BUTTON_B):
		b |= InputFrame.BTN_JUMP
	if Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER):
		b |= InputFrame.BTN_Z
	if Input.is_joy_button_pressed(d, JOY_BUTTON_START):
		b |= InputFrame.BTN_START
	if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP):
		b |= InputFrame.BTN_TAUNT
	f.buttons = b | _shield_bit(f)
	return f


func _sample_keyboard() -> InputFrame:
	var f := InputFrame.new()
	f.stick = MeleeStick.quantize(_key_vec(KEY_A, KEY_D, KEY_S, KEY_W))
	f.cstick = MeleeStick.quantize(_key_vec(KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_UP))
	var b: int = 0
	if Input.is_physical_key_pressed(KEY_J):
		b |= InputFrame.BTN_ATTACK
	if Input.is_physical_key_pressed(KEY_K):
		b |= InputFrame.BTN_SPECIAL
	if Input.is_physical_key_pressed(KEY_SPACE):
		b |= InputFrame.BTN_JUMP
	if Input.is_physical_key_pressed(KEY_I):
		b |= InputFrame.BTN_Z
	if Input.is_physical_key_pressed(KEY_T):
		b |= InputFrame.BTN_TAUNT
	if Input.is_physical_key_pressed(KEY_L):
		f.trigger_l = 1.0
	f.buttons = b | _shield_bit(f)
	return f


func _key_vec(left: Key, right: Key, down: Key, up: Key) -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(left):
		v.x -= 1.0
	if Input.is_physical_key_pressed(right):
		v.x += 1.0
	if Input.is_physical_key_pressed(down):
		v.y -= 1.0
	if Input.is_physical_key_pressed(up):
		v.y += 1.0
	return v


func _shield_bit(f: InputFrame) -> int:
	return InputFrame.BTN_SHIELD if f.shield_analog() >= MeleeStick.TRIGGER_FULL else 0
