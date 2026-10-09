class_name SpecialProjectile
extends SpecialEntity
## Projectiel-entity (bouwstenen 5, 6): rechte lijn of boog (gravity), stuiteren, lifetime/max-range, pierce,
## multi-hit, orbit rond de eigenaar, botsing met solide blokken, verdwijnen buiten de blast zone.
## Clank/reflect/absorb doet SpecialWorld. Zie docs/special-sjablonen.md §1.

## Snelheid (u/f) langs `vel`; gravity (u/f²) trekt vel.y omlaag.
var gravity: float = 0.0
## Max vallende snelheid bij gravity (u/f) ⚠️.
var max_fall: float = 3.0
## "none" / "floor" / "walls" / "both".
var bounce: String = "none"
var bounces_left: int = 0
## ⚠️ Energie na een stuiter.
var bounce_damping: float = 0.8
## Afstand tot verdwijnen (units; <= 0 = onbeperkt).
var max_range: float = 0.0
var traveled: float = 0.0
## Hoeveel extra doelwitten na het eerste (0 = verdwijnt bij de eerste treffer, -1 = onbeperkt).
var pierce: int = 0
var targets_done: int = 0
## Multi-hit: aantal treffers per doelwit en interval (frames) ertussen.
var multi_hits: int = 1
var multi_interval: int = 8
## "vanish" / "pass".
var on_shield_mode: String = "vanish"
## Orbit rond de eigenaar (follows_owner): straal (units) en hoeksnelheid (graden/frame).
var follows_owner: bool = false
var orbit_radius: float = 12.0
var orbit_speed: float = 6.0
var orbit_center_y: float = 8.0
## Landt op pass-through platforms (boogprojectielen met bounce != none).
var lands_on_platforms: bool = false
## Hitlag van het projectiel zelf bij een treffer (0 = leeft door).
var self_hitlag: bool = false

var _hits_on: Dictionary = {}
var _rehit_at: Dictionary = {}


func _init() -> void:
	kind = "projectile"


func tick() -> bool:
	if not super.tick():
		return false
	_expire_rehits()
	if follows_owner:
		_orbit()
		return true
	var segs: Array = world.segs if world != null else []
	if gravity > 0.0:
		vel.y = maxf(vel.y - gravity, -max_fall)
	var from: Vector2 = pos
	var to: Vector2 = pos + vel
	# Boven op een vloer/platform terechtkomen (alleen dalend).
	var cross: Dictionary = SpecialGeometry.crossing_top(segs, from, to, lands_on_platforms)
	if cross["hit"]:
		if bounce == "floor" or bounce == "both":
			if bounces_left > 0:
				bounces_left -= 1
				pos = Vector2(to.x, cross["point"].y + 0.01)
				vel = Vector2(vel.x, absf(vel.y) * bounce_damping)
				traveled += from.distance_to(pos)
				return true
		kill("stage")
		return false
	if SpecialGeometry.inside_solid(segs, to):
		if (bounce == "walls" or bounce == "both") and bounces_left > 0:
			bounces_left -= 1
			vel.x = -vel.x * bounce_damping
			facing = -facing
			return true
		kill("stage")
		return false
	pos = to
	traveled += vel.length()
	if max_range > 0.0 and traveled >= max_range:
		kill("range")
		return false
	if world != null and SpecialGeometry.outside_blast(world.stage, pos):
		kill("blast_zone")
		return false
	return true


func _orbit() -> void:
	if owner_fighter == null or not is_instance_valid(owner_fighter):
		kill("owner")
		return
	var a: float = deg_to_rad(float(age) * orbit_speed)
	pos = owner_fighter.pos + Vector2(0.0, orbit_center_y) + Vector2(cos(a), sin(a)) * orbit_radius


func on_hit_target(ev: HitEvent) -> void:
	if self_hitlag:
		hitlag = ev.attacker_hitlag
	var n: int = int(_hits_on.get(ev.defender, 0)) + 1
	_hits_on[ev.defender] = n
	if n < multi_hits:
		_rehit_at[ev.key] = age + multi_interval
		return
	targets_done += 1
	if pierce >= 0 and targets_done > pierce:
		kill("hit")


func on_shield(ev: HitEvent) -> void:
	if on_shield_mode == "pass":
		already_hit[ev.key] = true
		return
	kill("shield")


func reflect(by: Fighter, dmg_mult: float, spd_mult: float, limit: int) -> bool:
	_hits_on.clear()
	_rehit_at.clear()
	targets_done = 0
	follows_owner = false
	return super.reflect(by, dmg_mult, spd_mult, limit)


## Multi-hit: na `multi_interval` frames mag hetzelfde doelwit weer geraakt worden.
func _expire_rehits() -> void:
	if _rehit_at.is_empty():
		return
	for k: String in _rehit_at.keys():
		if age >= int(_rehit_at[k]):
			already_hit.erase(k)
			_rehit_at.erase(k)
