class_name SpecialAim
extends RefCounted
## Stick-aim helper (bouwsteen 4): gekwantiseerde stick -> vaste N richtingen of vrije hoek, met
## deadzone-standaardrichting en maximale stuurhoek. Puur. Hoeken in graden, 0 = vooruit (facing), 90 = omhoog.

## ⚠️ Onder deze stickgrootte telt de stick als neutraal (= TURN_THRESHOLD, net buiten de deadzone).
const AIM_DEADZONE: float = 0.2875

## Slot-drempels voor de B-knop (Melee-achtig ⚠️): up-B bij stick-y >= UP, down-B bij <= -DOWN, side bij |x| >= SIDE.
const SLOT_UP_THRESHOLD: float = 0.6625
const SLOT_DOWN_THRESHOLD: float = 0.6625
const SLOT_SIDE_THRESHOLD: float = 0.6


## Wereldrichting (eenheidsvector, y omhoog) uit een hoek relatief aan facing (0 = vooruit, 90 = omhoog).
static func dir_from_angle(angle_deg: float, facing: int) -> Vector2:
	var a: float = deg_to_rad(angle_deg)
	return Vector2(cos(a) * facing, sin(a))


## Hoek relatief aan facing uit een wereldrichting.
static func angle_of(dir: Vector2, facing: int) -> float:
	return rad_to_deg(atan2(dir.y, dir.x * facing))


static func is_neutral(stick: Vector2) -> bool:
	return stick.length() < AIM_DEADZONE


## Richting uit de stick. mode: "fixed" (altijd `neutral_angle`), "stick_8dir", "stick_4dir", "stick_n_dir" (`n`),
## "stick_free". Stick neutraal -> `neutral_angle` (relatief aan facing). Resultaat: wereld-eenheidsvector.
static func direction(stick: Vector2, mode: String, facing: int, neutral_angle: float = 90.0, n: int = 8) -> Vector2:
	if mode == "fixed" or is_neutral(stick):
		return dir_from_angle(neutral_angle, facing)
	var a: float = atan2(stick.y, stick.x)
	match mode:
		"stick_8dir":
			return _snap(a, 8)
		"stick_4dir":
			return _snap(a, 4)
		"stick_n_dir":
			return _snap(a, maxi(n, 1))
		_:
			return Vector2(cos(a), sin(a))


static func _snap(a: float, n: int) -> Vector2:
	var step: float = TAU / float(n)
	var s: float = roundf(a / step) * step
	var v := Vector2(cos(s), sin(s))
	# Afrondingsruis wegpoetsen (deterministisch).
	return Vector2(snappedf(v.x, 0.000001), snappedf(v.y, 0.000001))


## Stuurhoek: basis `base_deg` (relatief aan facing) bijgestuurd door de stick, maximaal `max_dev_deg` afwijking.
## Stick neutraal -> basis.
static func steer_angle(stick: Vector2, facing: int, base_deg: float, max_dev_deg: float) -> float:
	if is_neutral(stick) or max_dev_deg <= 0.0:
		return base_deg
	var want: float = rad_to_deg(atan2(stick.y, stick.x * facing))
	var diff: float = wrapf(want - base_deg, -180.0, 180.0)
	return base_deg + clampf(diff, -max_dev_deg, max_dev_deg)


## Slot uit de stick (t.o.v. facing): "up", "down", "side" of "neutral". `dir` (out) = stickrichting x (-1/0/1).
static func slot_from_stick(stick: Vector2) -> String:
	if stick.y >= SLOT_UP_THRESHOLD - FighterConst.EPS and stick.y >= absf(stick.x):
		return "up"
	if stick.y <= -SLOT_DOWN_THRESHOLD + FighterConst.EPS and -stick.y >= absf(stick.x):
		return "down"
	if absf(stick.x) >= SLOT_SIDE_THRESHOLD - FighterConst.EPS:
		return "side"
	if stick.y >= SLOT_UP_THRESHOLD - FighterConst.EPS:
		return "up"
	if stick.y <= -SLOT_DOWN_THRESHOLD + FighterConst.EPS:
		return "down"
	return "neutral"
