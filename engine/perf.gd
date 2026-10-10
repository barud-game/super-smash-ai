class_name Perf
extends RefCounted
## Optionele prestatiemeting per subsysteem (alleen voor tools/bench). Staat standaard uit: dan kost
## elke aanroep één bool-check. Gebruik: `var t := Perf.begin()` ... `Perf.end(&"naam", t)`.
## Meet nooit gameplay-beslissingen af: deze klasse heeft geen invloed op de simulatie.

static var enabled: bool = false
static var _acc: Dictionary = {}


static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func end(key: StringName, t0: int) -> void:
	if enabled:
		_acc[key] = int(_acc.get(key, 0)) + Time.get_ticks_usec() - t0


## Telt een gebeurtenis (bv. een allocatie) mee onder `key`.
static func count(key: StringName, n: int = 1) -> void:
	if enabled:
		_acc[key] = int(_acc.get(key, 0)) + n


## Geeft de totalen sinds de vorige aanroep en reset ze.
static func take() -> Dictionary:
	var out: Dictionary = _acc
	_acc = {}
	return out
