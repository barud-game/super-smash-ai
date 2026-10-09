class_name MenuNav
extends RefCounted
## Menu-navigatie vanuit InputManager.history(p): stick -> richtingen met herhaalvertraging,
## knoppen -> acties. Toetsenbord (pijlen/Enter/Esc/Tab, plus WASD/J/Spatie via de history) telt voor speler 1.
## Aanroepen: één keer per physics-frame per speler: `for a in nav.poll(p): ...`.
##
## Knoppen: A=CONFIRM, B/Y=BACK, X=SECONDARY, Start=START, LT=PAGE_PREV, RT/RB=PAGE_NEXT.

enum Act { UP, DOWN, LEFT, RIGHT, CONFIRM, BACK, SECONDARY, START, PAGE_PREV, PAGE_NEXT }

const DIR_THRESHOLD: float = 0.55
const REPEAT_FIRST: int = 22
const REPEAT_NEXT: int = 6
const TRIGGER_ON: float = 0.7

## Gedempte spelers leveren geen acties (bv. tijdens typen in het zoekveld).
var muted: Array[bool] = [false, false]
var _held: Array = [{}, {}]
var _primed: Array[bool] = [false, false]


static func is_dir(a: int) -> bool:
	return a <= Act.RIGHT


func poll(p: int) -> Array[int]:
	var out: Array[int] = []
	var down: Dictionary = {} if muted[p] else _active(p)
	var held: Dictionary = _held[p]
	if not _primed[p]:
		# Wat bij binnenkomst al ingedrukt is (bv. de A waarmee je hier kwam) telt niet als nieuwe druk.
		_primed[p] = true
		for a in down:
			held[a] = 1
		return out
	for a in held.keys():
		if not down.has(a):
			held.erase(a)
	for a: int in down:
		var n: int = held.get(a, 0)
		if n == 0:
			out.append(a)
		elif is_dir(a) and n >= REPEAT_FIRST and (n - REPEAT_FIRST) % REPEAT_NEXT == 0:
			out.append(a)
		held[a] = n + 1
	return out


func _active(p: int) -> Dictionary:
	var d: Dictionary = {}
	var f: InputFrame = _autoload("InputManager").history(p).get_frame(0)
	_add_dir(d, f.stick_f())
	if f.has(InputFrame.BTN_ATTACK):
		d[Act.CONFIRM] = true
	if f.has(InputFrame.BTN_JUMP):
		d[Act.BACK] = true
	if f.has(InputFrame.BTN_SPECIAL):
		d[Act.SECONDARY] = true
	if f.has(InputFrame.BTN_START):
		d[Act.START] = true
	if f.trigger_l >= TRIGGER_ON:
		d[Act.PAGE_PREV] = true
	if f.trigger_r >= TRIGGER_ON or f.has(InputFrame.BTN_Z):
		d[Act.PAGE_NEXT] = true
	if p == 0:
		_add_keys(d)
	return d


func _add_dir(d: Dictionary, s: Vector2) -> void:
	if maxf(absf(s.x), absf(s.y)) < DIR_THRESHOLD:
		return
	if absf(s.x) >= absf(s.y):
		d[Act.RIGHT if s.x > 0.0 else Act.LEFT] = true
	else:
		d[Act.UP if s.y > 0.0 else Act.DOWN] = true


func _add_keys(d: Dictionary) -> void:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_UP):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		v.y -= 1.0
	_add_dir(d, v)
	if Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER):
		d[Act.CONFIRM] = true
	if Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_physical_key_pressed(KEY_BACKSPACE):
		d[Act.BACK] = true
	if Input.is_physical_key_pressed(KEY_TAB):
		d[Act.SECONDARY] = true
	if Input.is_physical_key_pressed(KEY_PAGEUP):
		d[Act.PAGE_PREV] = true
	if Input.is_physical_key_pressed(KEY_PAGEDOWN):
		d[Act.PAGE_NEXT] = true


## Autoload via de boom (zodat dit script ook compileert in `--script`-tests, waar globals nog ontbreken).
static func _autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(autoload_name) if tree != null else null
