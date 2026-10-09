class_name SpecialGeometry
extends RefCounted
## Stage-geometrie voor specials (bouwstenen 14, 16): solide blokken, teleport-/reposition-service,
## blast zone en de ledge-snap-hook. Puur (alleen lezen); geen Godot-physics.
##
## De stage-interface kent alleen bovenvlakken (segmenten). Een SOLID-segment is de bovenkant van een blok
## van SOLID_DEPTH units diep ⚠️ (aanname; stage-data heeft geen onderkant). Platforms zijn dun (pass-through).

## ⚠️ Diepte van een solide blok onder zijn bovenvlak (Final Destination-achtig).
const SOLID_DEPTH: float = 30.0
## Stapgrootte (units) bij het terugzoeken naar een vrije plek langs een lijn.
const WALK_BACK_STEP: float = 0.5
## Marge buiten de blast zone waarbinnen entities nog leven.
const BLAST_MARGIN: float = 10.0
## ⚠️ Global cap teleport-afstand (director-besluit 2).
const TELEPORT_MAX_DISTANCE: float = 260.0


static func segments(stage: Object) -> Array:
	var out: Array = []
	if stage == null or not stage.has_method("get_ground_segments"):
		return out
	for raw: Variant in stage.get_ground_segments():
		var n: Dictionary = Fighter.normalize_segment(raw)
		if not n.is_empty():
			out.append(n)
	return out


static func ledges(stage: Object) -> Array:
	var out: Array = []
	if stage == null or not stage.has_method("get_ledges"):
		return out
	for raw: Variant in stage.get_ledges():
		var p: Variant = raw.get("position") if (raw is Object or raw is Dictionary) else null
		var s: Variant = raw.get("side") if (raw is Object or raw is Dictionary) else null
		if p is Vector2 and (s is int or s is float) and int(s) != 0:
			out.append({"pos": p, "side": 1 if int(s) > 0 else -1})
	return out


static func blast_zone(stage: Object) -> Rect2:
	if stage == null or not stage.has_method("get_blast_zone"):
		return Rect2()
	return stage.get_blast_zone()


## Ligt `p` buiten de blast zone (met marge)? Lege blast zone = nooit.
static func outside_blast(stage: Object, p: Vector2, margin: float = BLAST_MARGIN) -> bool:
	var bz: Rect2 = blast_zone(stage)
	if bz.size == Vector2.ZERO:
		return false
	return not bz.grow(margin).has_point(p)


static func seg_y(s: Dictionary, x: float) -> float:
	var a: Vector2 = s["a"]
	var b: Vector2 = s["b"]
	if absf(b.x - a.x) < 0.0001:
		return maxf(a.y, b.y)
	return lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))


## Index van het solide segment waarvan het blok `p` bevat (-1 = vrij). `margin` krimpt het blok.
static func solid_at(segs: Array, p: Vector2, margin: float = 0.0) -> int:
	for i in segs.size():
		var s: Dictionary = segs[i]
		if s["platform"]:
			continue
		if p.x <= s["a"].x + margin or p.x >= s["b"].x - margin:
			continue
		var top: float = seg_y(s, p.x)
		if p.y < top - margin and p.y > top - SOLID_DEPTH:
			return i
	return -1


static func inside_solid(segs: Array, p: Vector2, margin: float = 0.0) -> bool:
	return solid_at(segs, p, margin) >= 0


## Eerste bovenvlak dat de beweging from -> to van boven naar beneden kruist.
## {hit: bool, seg: int, point: Vector2}. `platforms` = ook pass-through platforms meenemen.
static func crossing_top(segs: Array, from: Vector2, to: Vector2, platforms: bool) -> Dictionary:
	var best: Dictionary = {"hit": false, "seg": -1, "point": to}
	if to.y >= from.y:
		return best
	var best_t: float = INF
	for i in segs.size():
		var s: Dictionary = segs[i]
		if s["platform"] and not platforms:
			continue
		if to.x < s["a"].x - 0.0001 or to.x > s["b"].x + 0.0001:
			continue
		var y_from: float = seg_y(s, from.x)
		var y_to: float = seg_y(s, to.x)
		if from.y >= y_from - 0.01 and to.y <= y_to:
			var denom: float = (from.y - to.y)
			var t: float = clampf((from.y - y_from) / denom, 0.0, 1.0) if denom > 0.0 else 0.0
			if t < best_t:
				best_t = t
				best = {"hit": true, "seg": i, "point": Vector2(to.x, y_to)}
	return best


## Teleport-/reposition-service. Geeft {pos, ok, adjusted}. mode:
##   "snap_to_valid": doel in een blok -> dichtstbijzijnde vrije plek (terug langs de lijn, of bovenop het blok)
##   "shorten": doel in een blok -> terug langs de lijn tot vrij
##   "fizzle": doel in een blok -> ok = false (de aanroeper blijft staan)
## `cross_walls` false: ook de lijn zelf mag geen blok doorkruisen (stopt vóór het blok).
## Blast zone: bestemming buiten de blast zone is toegestaan (suïcide mogelijk, docs/special-sjablonen.md §3).
static func resolve_target(segs: Array, from: Vector2, to: Vector2, mode: String, cross_walls: bool = true) -> Dictionary:
	var target: Vector2 = to
	var adjusted: bool = false
	if not cross_walls:
		var steps: int = maxi(int(ceilf(from.distance_to(to) / WALK_BACK_STEP)), 1)
		for i in range(1, steps + 1):
			var q: Vector2 = from.lerp(to, float(i) / float(steps))
			if inside_solid(segs, q):
				target = from.lerp(to, float(i - 1) / float(steps))
				adjusted = true
				break
	var blk: int = solid_at(segs, target)
	if blk < 0:
		return {"pos": target, "ok": true, "adjusted": adjusted}
	if mode == "fizzle":
		return {"pos": from, "ok": false, "adjusted": true}
	var back: Vector2 = _walk_back(segs, from, target)
	if mode == "snap_to_valid":
		var s: Dictionary = segs[blk]
		var top := Vector2(target.x, seg_y(s, target.x) + 0.01)
		if top.distance_to(target) < back.distance_to(target) and not inside_solid(segs, top):
			return {"pos": top, "ok": true, "adjusted": true}
	return {"pos": back, "ok": true, "adjusted": true}


static func _walk_back(segs: Array, from: Vector2, to: Vector2) -> Vector2:
	var dist: float = from.distance_to(to)
	var dir: Vector2 = (from - to).normalized() if dist > 0.0 else Vector2(0.0, 1.0)
	var p: Vector2 = to
	var guard: int = 0
	while inside_solid(segs, p) and guard < 2000:
		p += dir * WALK_BACK_STEP
		guard += 1
	return p


## Staat `p` (bijna) op een bovenvlak? Geeft segment-index of -1.
static func surface_at(segs: Array, p: Vector2, tol: float = 0.05, platforms: bool = true) -> int:
	for i in segs.size():
		var s: Dictionary = segs[i]
		if s["platform"] and not platforms:
			continue
		if p.x >= s["a"].x - 0.0001 and p.x <= s["b"].x + 0.0001 and absf(p.y - seg_y(s, p.x)) <= tol:
			return i
	return -1


# =============================================================================================
# Ledge-snap-hook (bouwsteen 14). Hergebruikt Fighter.grab_ledge / ledge_occupied_by_other (Melee-regels:
# geen ledge-steal, ledge-lock, regrab-intangibility via het bestaande systeem).
# =============================================================================================

## Probeer de fighter tijdens/na een special aan een ledge te hangen. `extra_range` vergroot de grab-box
## (units). `allow_rising`: ook grijpen tijdens stijgen, maar alleen als de voeten ónder de ledge zijn
## (Melee-regel voor stijgende fighters ⚠️). Specials grijpen ook achterwaarts (fighter draait) ⚠️.
static func try_ledge_snap(f: Fighter, extra_range: float, allow_rising: bool) -> bool:
	if f.grounded or f.ledge_cooldown_frames > 0 or f.ledge_key != "":
		return false
	if f.stick_y() <= -FighterConst.LEDGE_GRAB_DOWN_BLOCK + FighterConst.EPS:
		return false
	var rising: bool = f.vel.y + f.kb_vel.y >= 0.0
	if rising and not allow_rising:
		return false
	var front: float = f.stats.ledge_grab_front() + extra_range
	var back: float = f.stats.ledge_grab_back() + extra_range
	var y_min: float = f.stats.ledge_grab_y_min() - extra_range
	var y_max: float = f.stats.ledge_grab_y_max() + extra_range
	if rising:
		y_min = maxf(y_min, 0.0)
	for l: Dictionary in ledges(f.stage):
		var side: int = l["side"]
		var lp: Vector2 = l["pos"]
		var outward: float = (f.pos.x - lp.x) * side
		var above: float = lp.y - f.pos.y
		if outward < -back or outward > front:
			continue
		if above < y_min or above > y_max:
			continue
		if f.ledge_occupied_by_other(lp, side):
			continue
		f.grab_ledge(lp, side)
		return true
	return false
