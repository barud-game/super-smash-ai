class_name HitResolver
extends RefCounted
## Bepaalt treffers uit actieve hitboxes en doelwitten. Puur: geen side effects, geen state.
## Het geheugen "dit is al geraakt" (already_hit) beheert de aanroeper: voeg event.key van elke
## HIT/SHIELD toe aan zijn set. Zie docs/combat.md.

const CLANK_DAMAGE_DIFF: float = 9.0


class Result:
	var hits: Array[HitEvent] = []    ## HIT en SHIELD
	var clanks: Array[HitEvent] = []


static func hit_key(owner: int, instance: int, group: int, target: int) -> String:
	return "%d:%d:%d:%d" % [owner, instance, group, target]


## Afstand van punt tot segment ab.
static func point_segment_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var l2: float = ab.length_squared()
	if l2 <= 0.000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func circle_hits_capsule(c: Vector2, r: float, a: Vector2, b: Vector2, cap_r: float) -> bool:
	return point_segment_dist(c, a, b) < r + cap_r


static func _sort_hitboxes(x: ActiveHitbox, y: ActiveHitbox) -> bool:
	if x.owner != y.owner:
		return x.owner < y.owner
	if x.instance != y.instance:
		return x.instance < y.instance
	return x.data.id < y.data.id


## `no_clank`: eigenaren (id -> true) waarvan de hitboxen niet clanken (aerials: Melee laat ze traden).
static func resolve(active: Array[ActiveHitbox], targets: Array[CombatTarget], already_hit: Dictionary = {},
		no_clank: Dictionary = {}) -> Result:
	var res := Result.new()
	var boxes: Array[ActiveHitbox] = active.duplicate()
	boxes.sort_custom(_sort_hitboxes)

	# 1. Clank tussen hitboxen van verschillende eigenaren.
	var removed: Dictionary = {}
	for i in boxes.size():
		var a: ActiveHitbox = boxes[i]
		if removed.has(i) or not a.data.clank or no_clank.has(a.owner):
			continue
		for j in range(i + 1, boxes.size()):
			var b: ActiveHitbox = boxes[j]
			if removed.has(j) or removed.has(i) or not b.data.clank or a.owner == b.owner or no_clank.has(b.owner):
				continue
			if a.pos.distance_to(b.pos) >= a.data.radius + b.data.radius:
				continue
			var ev := HitEvent.new()
			ev.kind = HitEvent.Kind.CLANK
			ev.attacker = a.owner
			ev.defender = b.owner
			ev.hitbox = a
			ev.other_hitbox = b
			ev.attacker_hitlag = Knockback.hitlag_frames(a.damage, a.data.element, a.data.hitlag_mult)
			ev.defender_hitlag = Knockback.hitlag_frames(b.damage, b.data.element, b.data.hitlag_mult)   # clank: beide aanvallers, geen electric
			var diff: float = floorf(a.damage) - floorf(b.damage)   # integer damage (Melee)
			if absf(diff) >= CLANK_DAMAGE_DIFF:
				if diff > 0.0:
					ev.defender_rebounds = true
					removed[j] = true
				else:
					ev.attacker_rebounds = true
					removed[i] = true
			else:
				ev.attacker_rebounds = true
				ev.defender_rebounds = true
				removed[i] = true
				removed[j] = true
			res.clanks.append(ev)

	# 2. Treffers per doelwit; per (eigenaar, instantie, doelwit) maximaal één per frame: laagste id.
	var taken: Dictionary = {}
	for t in targets:
		for i in boxes.size():
			if removed.has(i):
				continue
			var h: ActiveHitbox = boxes[i]
			var d: HitboxData = h.data
			if h.owner == t.id or t.intangible or t.invincible:
				continue
			if d.grounded_only and not t.grounded:
				continue
			if d.aerial_only and t.grounded:
				continue
			var gkey: String = hit_key(h.owner, h.instance, d.group, t.id)
			if already_hit.has(gkey):
				continue
			var fkey: String = "%d:%d:%d" % [h.owner, h.instance, t.id]
			if taken.has(fkey):
				continue
			var shielded: bool = t.shielding and not d.ignores_shield
			var touched: bool = false
			if shielded:
				touched = h.pos.distance_to(t.shield_center) < d.radius + t.shield_radius
			else:
				for hb in t.hurtboxes:
					if hb.intangible:
						continue
					if circle_hits_capsule(h.pos, d.radius, hb.world_a(t.origin, t.facing), hb.world_b(t.origin, t.facing), hb.radius):
						touched = true
						break
			if not touched:
				continue
			taken[fkey] = true
			var ev := HitEvent.new()
			ev.attacker = h.owner
			ev.defender = t.id
			ev.hitbox = h
			ev.key = gkey
			ev.damage = h.damage
			ev.attacker_hitlag = Knockback.hitlag_frames(h.damage, d.element, d.hitlag_mult)
			ev.defender_hitlag = Knockback.hitlag_frames(h.damage, d.element, d.hitlag_mult, true, t.crouching)
			if shielded:
				ev.kind = HitEvent.Kind.SHIELD
				ev.shield_stun = Knockback.shieldstun_frames(h.damage, t.shield_analog)
				ev.shield_damage = h.damage + d.shield_damage
			else:
				ev.kind = HitEvent.Kind.HIT
				ev.attacker_hitfall_allowed = true
				ev.knockback = Knockback.compute(d, h.damage, t.percent, t.weight, t.grounded, t.crouching, h.facing, t.charging)
			res.hits.append(ev)
	return res
