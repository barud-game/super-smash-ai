extends SceneTree
## Headless testrunner. Zie tests/README.md.

var _fails: int = 0
var _total: int = 0


func _initialize() -> void:
	_test_quantize()
	_test_history()
	_test_smash()
	_test_units()
	print("")
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name)


func _frame(sx: int, buttons: int = 0) -> InputFrame:
	var f := InputFrame.new()
	f.stick = Vector2i(sx, 0)
	f.buttons = buttons
	return f


func _test_quantize() -> void:
	check("quantize neutraal", MeleeStick.quantize(Vector2.ZERO) == Vector2i.ZERO)
	check("quantize vol rechts = 80", MeleeStick.quantize(Vector2(1, 0)) == Vector2i(80, 0))
	check("quantize vol links = -80", MeleeStick.quantize(Vector2(-1, 0)) == Vector2i(-80, 0))
	check("quantize vol omhoog = 80", MeleeStick.quantize(Vector2(0, 1)) == Vector2i(0, 80))
	var dz: float = float(MeleeStick.DEADZONE) / MeleeStick.GRID
	check("deadzone: net eronder = 0", MeleeStick.quantize(Vector2(dz - 0.01, 0)).x == 0)
	check("deadzone: net erboven != 0", MeleeStick.quantize(Vector2(dz + 0.02, 0)).x >= MeleeStick.DEADZONE)
	check("deadzone negatief", MeleeStick.quantize(Vector2(-(dz - 0.01), 0)).x == 0)
	check("deadzone per as", MeleeStick.quantize(Vector2(0.1, 0.9)) == Vector2i(0, 72))
	var d: Vector2i = MeleeStick.quantize(Vector2(1, 1))
	check("diagonaal binnen cirkel", d.x * d.x + d.y * d.y <= 6400)
	check("diagonaal symmetrisch", d.x == d.y and d.x >= 55)
	var big: Vector2i = MeleeStick.quantize(Vector2(5, -5))
	check("overshoot geclampt", big.x * big.x + big.y * big.y <= 6400 and big.x > 0 and big.y < 0)
	var ok: bool = true
	for i in 361:
		var a: float = deg_to_rad(i)
		var q: Vector2i = MeleeStick.quantize(Vector2(cos(a), sin(a)) * 1.2)
		if q.x * q.x + q.y * q.y > 6400 or absi(q.x) > 80 or absi(q.y) > 80:
			ok = false
	check("rondje: altijd binnen raster", ok)
	var fr := InputFrame.new()
	fr.stick = Vector2i(40, -80)
	check("stick_f = int/80", fr.stick_f().is_equal_approx(Vector2(0.5, -1.0)))


func _test_history() -> void:
	var h := InputHistory.new()
	check("leeg: niets held", not h.held(InputFrame.BTN_ATTACK))
	h.push(_frame(0))
	h.push(_frame(0, InputFrame.BTN_ATTACK))
	check("pressed bij eerste frame", h.pressed(InputFrame.BTN_ATTACK))
	check("held", h.held(InputFrame.BTN_ATTACK))
	h.push(_frame(0, InputFrame.BTN_ATTACK))
	check("pressed alleen eerste frame", not h.pressed(InputFrame.BTN_ATTACK))
	h.push(_frame(0))
	check("released", h.released(InputFrame.BTN_ATTACK))
	check("niet meer held", not h.held(InputFrame.BTN_ATTACK))
	var h2 := InputHistory.new()
	for i in 50:
		h2.push(_frame(i))
	check("ringbuffer count capped", h2.count() == InputHistory.SIZE)
	check("ringbuffer nieuwste", h2.get_frame(0).stick.x == 49)
	check("ringbuffer oudste", h2.get_frame(InputHistory.SIZE - 1).stick.x == 50 - InputHistory.SIZE)
	check("buiten bereik = neutraal", h2.get_frame(InputHistory.SIZE).stick == Vector2i.ZERO)


func _test_smash() -> void:
	var h := InputHistory.new()
	h.push(_frame(0))
	h.push(_frame(0))
	h.push(_frame(80))
	check("smash: neutraal -> vol in 1 frame", h.stick_smashed_x(2))
	check("geen smash op y-as", not h.stick_smashed_y(2))
	var slow := InputHistory.new()
	for v in [0, 20, 40, 50, 60, 70, 80]:
		slow.push(_frame(v))
	check("geen smash bij langzame beweging", not slow.stick_smashed_x(3))
	check("wel smash met groot venster", slow.stick_smashed_x(8))
	var held := InputHistory.new()
	for i in 6:
		held.push(_frame(80))
	check("geen smash als stick al vol stond", not held.stick_smashed_x(5))
	var neg := InputHistory.new()
	neg.push(_frame(0))
	neg.push(_frame(-60))
	neg.push(_frame(-80))
	check("smash naar links", neg.stick_smashed_x(3))
	var flip := InputHistory.new()
	flip.push(_frame(-80))
	flip.push(_frame(80))
	check("omklappen volledig = geen smash vanaf neutraal", not flip.stick_smashed_x(3))
	var short := InputHistory.new()
	short.push(_frame(80))
	check("te weinig historie = geen smash", not short.stick_smashed_x(3))


func _test_units() -> void:
	check("units: y omgedraaid", Units.to_px(Vector2(1, 1)) == Vector2(Units.UNIT_TO_PX, -Units.UNIT_TO_PX))
	check("units: ±85 units past in 1280px", 85.0 * 2.0 * Units.UNIT_TO_PX <= 1280.0)
