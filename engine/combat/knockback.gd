class_name Knockback
extends RefCounted
## Melee-knockback, hitstun, hitlag, DI en SDI. Puur en deterministisch. Zie docs/combat.md.

const HITSTUN_FACTOR: float = 0.4
const LAUNCH_SPEED_FACTOR: float = 0.03
const DECAY_PER_FRAME: float = 0.051
const SAKURAI_ANGLE: float = 361.0
const SAKURAI_GROUND_KB: float = 32.0
const SAKURAI_GROUND_LOW: float = 0.0
const SAKURAI_GROUND_HIGH: float = 44.0
const SAKURAI_AIR: float = 45.0
const TUMBLE_KB: float = 80.0
const CROUCH_CANCEL_FACTOR: float = 2.0 / 3.0
const MAX_DI_DEG: float = 18.0
const SDI_DISTANCE: float = 6.0
const ASDI_DISTANCE: float = 3.0
const SDI_THRESHOLD: float = 0.7
const ELECTRIC_HITLAG: float = 1.5
const CROUCH_HITLAG_FACTOR: float = 2.0 / 3.0
const MAX_HITLAG: int = 20
const SMASH_CHARGE_VICTIM_FACTOR: float = 1.2
const SHIELD_ANALOG_MIN: float = 0.3   ## shieldstun: analoge stand s wordt genormaliseerd met (s - 0.3) / 0.7
const SHIELD_ANALOG_RANGE: float = 0.7


## KB = ((((p/10 + p*d/20) * 200/(w+100) * 1.4) + 18) * g/100) + b.  p = percentage NA de hit.
## set_kb > 0 (WDSK): het damage-deel p/10 + p*d/20 wordt 1 + set_kb/2 (= p=10, d=set_kb) en g = 100.
static func raw_kb(percent_after: float, damage: float, weight: float, growth: float, base: float, set_kb: float = 0.0) -> float:
	var dmg_term: float = percent_after / 10.0 + percent_after * damage / 20.0
	var g: float = growth
	if set_kb > 0.0:
		dmg_term = 1.0 + set_kb * 10.0 / 20.0
		g = 100.0
	return (dmg_term * (200.0 / (weight + 100.0)) * 1.4 + 18.0) * g / 100.0 + base


static func hitstun_frames(kb: float) -> int:
	return int(floor(kb * HITSTUN_FACTOR))


static func launch_speed(kb: float) -> float:
	return kb * LAUNCH_SPEED_FACTOR


## Eén frame knockback-decay: de grootte van de launch-velocity neemt 0.051 af (richting blijft).
static func decay_step(v: Vector2) -> Vector2:
	var l: float = v.length()
	if l <= DECAY_PER_FRAME:
		return Vector2.ZERO
	return v * ((l - DECAY_PER_FRAME) / l)


## 361-regel; anders de hoek ongewijzigd. Hoek in graden t.o.v. kijkrichting.
static func resolve_angle(angle: float, kb: float, grounded: bool) -> float:
	if angle != SAKURAI_ANGLE:
		return angle
	if grounded:
		return SAKURAI_GROUND_LOW if kb < SAKURAI_GROUND_KB else SAKURAI_GROUND_HIGH
	return SAKURAI_AIR


## Hitlag in frames (ftCommon_CalcHitlag): int(int(dmg/3 + 3) * mul), dmg = integer damage, cap 20.
## Alleen het SLACHTOFFER (victim) krijgt de electric-multiplier (1.5) en, als het hurkt, x2/3; de aanvaller m = hitbox-mult.
static func hitlag_frames(damage: float, element: int = HitboxData.Element.NORMAL, hitlag_mult: float = 1.0,
		victim: bool = false, crouching: bool = false) -> int:
	var m: float = hitlag_mult
	if victim:
		if element == HitboxData.Element.ELECTRIC:
			m *= ELECTRIC_HITLAG
		if crouching:
			m *= CROUCH_HITLAG_FACTOR
	var base: int = int(floor(float(int(damage)) / 3.0 + 3.0))
	return mini(int(floor(float(base) * m)), MAX_HITLAG)


## Genormaliseerde analoge shield-stand voor shieldstun: (s - 0.3) / 0.7, geklemd 0..1.
static func shield_norm(analog: float) -> float:
	return clampf((analog - SHIELD_ANALOG_MIN) / SHIELD_ANALOG_RANGE, 0.0, 1.0)


## Shieldstun: floor(200/201 * (d * (0.65*(1-a) + 0.3) * 1.5 + 2)); a = shield_norm(s), s = ruwe analoge stand
## (digitaal/vol = 1 -> a = 1). Lichtste shield (s ~ 0.307) geeft factor ~0.95.
static func shieldstun_frames(damage: float, analog: float = 1.0) -> int:
	var a: float = shield_norm(analog)
	return int(floor(200.0 / 201.0 * (damage * (0.65 * (1.0 - a) + 0.3) * 1.5 + 2.0)))


## Complete berekening voor één treffer. facing = kijkrichting van de aanvaller (+1/-1).
static func compute(hb: HitboxData, damage: float, target_percent: float, weight: float,
		grounded: bool, crouching: bool, facing: int, victim_charging: bool = false) -> KnockbackResult:
	var r := KnockbackResult.new()
	var kb: float = raw_kb(target_percent + damage, damage, weight, hb.kb_growth, hb.base_kb, hb.set_kb)
	r.set_kb = hb.set_kb > 0.0
	if grounded and crouching:
		kb *= CROUCH_CANCEL_FACTOR
		r.crouch_cancelled = true
	if victim_charging:
		kb *= SMASH_CHARGE_VICTIM_FACTOR   # slachtoffer laadt een smash op (kb_smashcharge_mul)
	r.kb = kb
	r.hitstun = hitstun_frames(kb)
	r.speed = launch_speed(kb)
	var a: float = resolve_angle(hb.angle, kb, grounded)
	if facing < 0:
		a = 180.0 - a
	r.angle = fposmod(a, 360.0)
	r.launch_vel = Vector2.from_angle(deg_to_rad(r.angle)) * r.speed
	r.tumble = kb >= TUMBLE_KB
	# Grounded zonder tumble die niet omhoog wordt gelanceerd blijft staan (glijdt); met tumble altijd de lucht in.
	r.stays_grounded = grounded and not r.tumble and r.launch_vel.y <= 0.0001
	return r


## Directional influence (ftCo_8008E5A4): de launch-richting draait 18 graden x c*|c|, c = stickcomponent loodrecht
## op de launch (kwadratisch, teken behouden; halve stick = 1/4 effect). Stick in [-1,1]^2, y omhoog. Grootte blijft gelijk.
static func apply_di(launch_vel: Vector2, stick: Vector2) -> Vector2:
	var len: float = launch_vel.length()
	if len <= 0.0:
		return launch_vel
	var dir: Vector2 = launch_vel / len
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var c: float = clampf(stick.dot(perp), -1.0, 1.0)
	return dir.rotated(deg_to_rad(MAX_DI_DEG * c * absf(c))) * len


## Hoekverandering (graden, + = tegen de klok in) die apply_di zou geven.
static func di_angle_delta(launch_vel: Vector2, stick: Vector2) -> float:
	if launch_vel.length() <= 0.0:
		return 0.0
	var perp: Vector2 = Vector2(-launch_vel.y, launch_vel.x).normalized()
	var c: float = clampf(stick.dot(perp), -1.0, 1.0)
	return MAX_DI_DEG * c * absf(c)


## SDI: tijdens hitlag, op het frame dat de stick vanuit < 0.7 naar >= 0.7 beweegt (flick) verschuift de
## fighter stick x 6 units (NIET genormaliseerd: stick 0.7 -> 4.2 units). Geeft de positie-offset (units, y omhoog) of Vector2.ZERO.
static func sdi_offset(prev_stick: Vector2, stick: Vector2) -> Vector2:
	if stick.length() >= SDI_THRESHOLD and prev_stick.length() < SDI_THRESHOLD:
		return stick * SDI_DISTANCE
	return Vector2.ZERO


## ASDI: op het laatste hitlag-frame, stick >= 0.7 vastgehouden: 3 units in de stickrichting.
static func asdi_offset(stick: Vector2) -> Vector2:
	if stick.length() >= SDI_THRESHOLD:
		return stick * ASDI_DISTANCE
	return Vector2.ZERO
