class_name SpecialWorld
extends Node2D
## Gedeelde special-wereld per stage (meta "special_world" op het stage-object, zoals de ledge-registry):
## tickt entities (projectielen, traps, haken) en lost de special-interacties op die Fighter/CombatSystem niet
## kennen. Eén `step()` per sim-frame, NA alle fighters en VÓÓR `CombatSystem.step()`:
##   1. SpecialKit.poll() per fighter (limieten resetten, buffs, opruimen bij dood)
##   2. entities tick (spawn-volgorde)
##   3. projectiel-vs-projectiel clank (hogere damage wint, gelijk = beide weg, transcendent negeert)
##   4. reflect-/absorb-boxen vs projectielen
##   5. trap-triggers (contact/proximity), trap-schade, chain
##   6. command-grab-boxen (grab-trade = beide mis)
##   7. intercepts: armor en counter (de special-state is dan intangible voor CombatSystem; hier worden de
##      inkomende hitboxes van fighters en entities zelf tegen de hurtboxes gelegd)
##   8. entity-hitboxes vs fighters (HitResolver; Fighter.receive_hit)
## In het spel registreert de wereld zich bij Sim en houdt zichzelf achter alle fighters in de tick-volgorde.
## Headless tests roepen `step()` zelf aan (zie tests/test_specials.gd).

const META: String = "special_world"
## Performance-caps: totaal aantal entities, traps per eigenaar (docs/special-sjablonen.md §1, §13).
const GLOBAL_ENTITY_CAP: int = 32
const TRAP_CAP_PER_OWNER: int = 8
## Dode entities blijven zo lang (frames) geldig als object voordat ze worden vrijgegeven.
const GRAVE_FRAMES: int = 120

var stage: Object
var segs: Array = []
var fighters: Array[Fighter] = []
var entities: Array[SpecialEntity] = []
## Gebeurtenissen van de laatste step() (tests/debug): {"kind", ...}.
var events: Array[Dictionary] = []
var frame: int = 0

var _serial: int = 0
var _instance: int = SpecialEntity.INSTANCE_BASE
var _sim: Node = null
var _holder: Object = null
var _graveyard: Array[SpecialEntity] = []
var _grave_frame: Dictionary = {}


# =============================================================================================
# Opzoeken / aanmaken
# =============================================================================================

static func _holder_of(f: Fighter) -> Object:
	return f.stage if f.stage != null else f


static func find(f: Fighter) -> SpecialWorld:
	var h: Object = _holder_of(f)
	if h != null and h.has_meta(META):
		var w: Variant = h.get_meta(META)
		if w is SpecialWorld and is_instance_valid(w):
			return w
	return null


## Wereld van deze fighter (aangemaakt bij het eerste gebruik). In de boom: child van de parent van de
## fighter + geregistreerd bij Sim.
static func of(f: Fighter) -> SpecialWorld:
	var w: SpecialWorld = find(f)
	if w == null:
		w = SpecialWorld.new()
		w.name = "SpecialWorld"
		w.stage = f.stage
		w._holder = _holder_of(f)
		w._holder.set_meta(META, w)
		if f.is_inside_tree() and f.get_parent() != null:
			f.get_parent().add_child(w)
			var sim: Node = f.get_node_or_null("/root/Sim")
			if sim != null and sim.has_method("register") and f.auto_register:
				w._sim = sim
				sim.register(w)
	w.add_fighter(f)
	return w


## Ruimt de wereld van een stage (of fighter) op: entities en de wereld zelf. Voor tests en match-einde.
static func dispose(holder: Object) -> void:
	if holder == null or not holder.has_meta(META):
		return
	var w: Variant = holder.get_meta(META)
	holder.remove_meta(META)
	if w is SpecialWorld and is_instance_valid(w):
		var sw: SpecialWorld = w
		sw._dispose()
		if sw.is_inside_tree():
			sw.queue_free()
		else:
			sw.free()


func _dispose() -> void:
	for e: SpecialEntity in entities:
		_free_entity(e)
	entities.clear()
	for e: SpecialEntity in _graveyard:
		_free_entity(e)
	_graveyard.clear()
	if _sim != null and is_instance_valid(_sim):
		_sim.unregister(self)
		_sim = null


func _exit_tree() -> void:
	if _sim != null and is_instance_valid(_sim):
		_sim.unregister(self)


const REGISTRY_META: String = "special_fighters"


## Lichte registratie van een fighter op zijn stage (instance-id -> fighter), zonder wereld aan te maken.
## O(1); de wereld leest en snoeit de registry pas als hij bestaat (SpecialWorld._refresh_fighters).
static func register_fighter(f: Fighter) -> void:
	var h: Object = f.stage
	if h == null:
		return
	if not h.has_meta(REGISTRY_META):
		h.set_meta(REGISTRY_META, {})
	(h.get_meta(REGISTRY_META) as Dictionary)[f.get_instance_id()] = f


func add_fighter(f: Fighter) -> void:
	if f == null or not is_instance_valid(f):
		return
	if not fighters.has(f):
		fighters.append(f)
		_sort_fighters()


## Ongeldige (vrijgegeven) fighters weg, dan op speler-id sorteren. Ongetypeerde lambda: geen conversiefout.
func _sort_fighters() -> void:
	var i: int = fighters.size() - 1
	while i >= 0:
		if not is_instance_valid(fighters[i]):
			fighters.remove_at(i)
		i -= 1
	# Alleen sorteren als de volgorde niet al klopt (bijna altijd): scheelt een lambda + sort per frame.
	var sorted: bool = true
	for k in range(1, fighters.size()):
		if fighters[k - 1].player > fighters[k].player:
			sorted = false
			break
	if not sorted:
		fighters.sort_custom(func(a, b) -> bool: return a.player < b.player)


func next_instance() -> int:
	_instance += 1
	return _instance


# =============================================================================================
# Entities
# =============================================================================================

## Registreer een nieuwe entity (vaste spawn-volgorde). Handhaaft de globale cap (oudste projectiel weg).
func spawn(e: SpecialEntity) -> SpecialEntity:
	_serial += 1
	e.serial = _serial
	e.instance = next_instance()
	e.world = self
	entities.append(e)
	add_child(e)
	if e.kind == "trap":
		var traps: Array[SpecialEntity] = alive_of(e.owner_fighter, "", "trap")
		while traps.size() > TRAP_CAP_PER_OWNER:
			traps[0].kill("cap")
			traps.remove_at(0)
	var alive_n: int = 0
	for x: SpecialEntity in entities:
		if x.alive:
			alive_n += 1
	if alive_n > GLOBAL_ENTITY_CAP:
		for x: SpecialEntity in entities:
			if x.alive and x.kind == "projectile":
				x.kill("cap")
				break
	return e


## Levende entities van een eigenaar (optioneel per slot en soort), oudste eerst.
func alive_of(owner_: Fighter, slot: String = "", kind_: String = "") -> Array[SpecialEntity]:
	var out: Array[SpecialEntity] = []
	for e: SpecialEntity in entities:
		if not e.alive or e.owner_fighter != owner_:
			continue
		if slot != "" and e.source_slot != slot:
			continue
		if kind_ != "" and e.kind != kind_:
			continue
		out.append(e)
	return out


## Alle entities van een fighter weg (dood/stock-verlies).
func clear_owner(f: Fighter) -> void:
	for e: SpecialEntity in entities:
		if e.alive and e.owner_fighter == f and not e.survives_owner_death:
			e.kill("owner_dead")


func _free_entity(e: SpecialEntity) -> void:
	if not is_instance_valid(e):
		return
	if e.get_parent() == self:
		remove_child(e)
	e.free()


func _log(kind: String, data: Dictionary = {}) -> void:
	var d: Dictionary = data.duplicate()
	d["kind"] = kind
	d["frame"] = frame
	events.append(d)


func had_event(kind: String) -> bool:
	for e: Dictionary in events:
		if e["kind"] == kind:
			return true
	return false


# =============================================================================================
# Per frame
# =============================================================================================

func sim_tick(_frame: int) -> void:
	# Stage weg zonder dispose (bv. stage-wissel): wereld ruimt zichzelf op.
	if _holder == null or not is_instance_valid(_holder) or not _holder.has_meta(META) or _holder.get_meta(META) != self:
		_dispose()
		if is_inside_tree():
			queue_free()
		return
	_ensure_after_fighters()
	step()


## Houd de wereld achter alle fighters in de Sim-volgorde (fighters kunnen later geregistreerd worden).
## Een verplaatsing werkt vanaf het volgende frame.
func _ensure_after_fighters() -> void:
	if _sim == null or not is_instance_valid(_sim):
		return
	var list: Array = _sim.entities()
	var me: int = list.find(self)
	for i in range(me + 1, list.size()):
		if list[i] is Fighter:
			_sim.unregister(self)
			_sim.register(self)
			return


func step() -> void:
	frame += 1
	events.clear()
	segs = SpecialGeometry.segments(stage)
	_refresh_fighters()
	for f: Fighter in fighters:
		SpecialKit.of(f).poll()
	if entities.is_empty():
		# Zonder entities en zonder fighter in een special-state zijn alle stappen hieronder no-ops.
		var busy: bool = false
		for f: Fighter in fighters:
			if _move_of(f) != null:
				busy = true
				break
		if not busy:
			_cleanup()
			return
	for e: SpecialEntity in entities.duplicate():
		if e.alive:
			e.tick()
	_entity_clanks()
	_reflect_absorb()
	_traps()
	_grab_boxes()
	_intercepts()
	_entity_hits()
	_cleanup()


func _refresh_fighters() -> void:
	_sort_fighters()
	# Fighters die naar een andere stage zijn verhuisd (sandbox F6) horen hier niet meer bij.
	var k: int = fighters.size() - 1
	while k >= 0:
		if fighters[k].stage != stage and stage != null:
			fighters.remove_at(k)
		k -= 1
	if _holder != null and is_instance_valid(_holder) and _holder.has_meta(REGISTRY_META):
		var reg: Dictionary = _holder.get_meta(REGISTRY_META)
		for id: int in reg.keys():
			var o: Variant = reg[id]
			if not is_instance_valid(o) or (o as Fighter).stage != stage:
				reg.erase(id)
			elif not fighters.has(o):
				fighters.append(o)
				_sort_fighters()
	if _sim != null and is_instance_valid(_sim):
		for e: Object in _sim.entities():
			if is_instance_valid(e) and e is Fighter and (e as Fighter).stage == stage and not fighters.has(e):
				fighters.append(e)
				_sort_fighters()


func _cleanup() -> void:
	var i: int = entities.size() - 1
	while i >= 0:
		var e: SpecialEntity = entities[i]
		if not is_instance_valid(e) or not e.alive:
			entities.remove_at(i)
			if is_instance_valid(e):
				_graveyard.append(e)
				_grave_frame[e] = frame
		i -= 1
	# Dode entities pas na GRAVE_FRAMES vrijgeven, zodat runners/tests hun referentie veilig kunnen uitlezen.
	var j: int = _graveyard.size() - 1
	while j >= 0:
		var g: SpecialEntity = _graveyard[j]
		if frame - int(_grave_frame.get(g, frame)) >= GRAVE_FRAMES:
			_graveyard.remove_at(j)
			_grave_frame.erase(g)
			_free_entity(g)
		j -= 1


static func _move_of(f: Fighter) -> SpecialMove:
	if f.state is StateSpecial:
		return (f.state as StateSpecial).move
	return null


func _fighter(id: int) -> Fighter:
	for f: Fighter in fighters:
		if f.player == id:
			return f
	return null


func _vfx(at: Vector2, kind: String) -> void:
	for f: Fighter in fighters:
		var v: Node = f.get_vfx()
		if v == null:
			continue
		if kind == "clank" and v.has_method("spawn_clank"):
			v.spawn_clank(at)
		elif v.has_method("spawn_special_fx"):
			v.spawn_special_fx(kind, at)
		return


# --- 3. clank ---------------------------------------------------------------------------------

func _entity_clanks() -> void:
	var list: Array[SpecialEntity] = []
	for e: SpecialEntity in entities:
		if e.alive and e.hitboxes_live() and not e.transcendent and e.kind == "projectile":
			list.append(e)
	for i in list.size():
		var a: SpecialEntity = list[i]
		if not a.alive:
			continue
		for j in range(i + 1, list.size()):
			var b: SpecialEntity = list[j]
			if not b.alive or not a.alive or a.owner_id == b.owner_id:
				continue
			if a.pos.distance_to(b.pos) >= a.body_radius() + b.body_radius():
				continue
			var da: float = floorf(a.clank_damage())
			var db: float = floorf(b.clank_damage())
			if da >= db:
				b.kill("clank")
			if db >= da:
				a.kill("clank")
			_log("clank", {"a": a.serial, "b": b.serial})
			_vfx((a.pos + b.pos) * 0.5, "clank")


# --- 4. reflect / absorb ----------------------------------------------------------------------

func _reflect_absorb() -> void:
	for f: Fighter in fighters:
		var m: SpecialMove = _move_of(f)
		if m == null:
			continue
		var rb: Dictionary = m.reflect_box()
		var ab: Dictionary = m.absorb_box()
		if rb.is_empty() and ab.is_empty():
			continue
		for e: SpecialEntity in entities:
			if not e.alive or e.owner_fighter == f or e.owner_id == f.player:
				continue
			if not rb.is_empty() and e.reflectable and _in_box(rb, e, f):
				if e.reflect(f, float(rb.get("damage_mult", 1.5)), float(rb.get("speed_mult", 1.0)),
						int(rb.get("limit", -1))):
					m.on_reflect(e)
					_log("reflect", {"by": f.player, "entity": e.serial})
					_vfx(e.pos, "clank")
				continue
			if not ab.is_empty() and e.absorbable and _in_box(ab, e, f):
				if m.on_absorb(e):
					e.kill("absorbed")
					_log("absorb", {"by": f.player, "entity": e.serial})


func _in_box(box: Dictionary, e: SpecialEntity, f: Fighter) -> bool:
	var c: Vector2 = box["center"]
	if e.pos.distance_to(c) >= float(box["radius"]) + e.body_radius():
		return false
	if String(box.get("facing", "both")) == "front":
		return (e.pos.x - f.pos.x) * f.facing >= -0.5
	return true


# --- 5. traps ---------------------------------------------------------------------------------

func _traps() -> void:
	for e: SpecialEntity in entities:
		if not (e is SpecialTrap) or not e.alive:
			continue
		var t: SpecialTrap = e
		if t.phase == "exploding":
			if t.chain:
				for o: SpecialEntity in entities:
					if o != t and o is SpecialTrap and o.alive and o.owner_fighter == t.owner_fighter \
							and (o as SpecialTrap).phase != "exploding" and _boxes_touch_point(t.active_hitboxes(), o.pos, o.body_radius()):
						(o as SpecialTrap).explode()
						_log("trap_chain", {"trap": o.serial})
			continue
		for f: Fighter in fighters:
			if not f.active or f.is_intangible():
				continue
			if f == t.owner_fighter:
				continue
			if t.hp > 0.0:
				for hb: ActiveHitbox in f.active_hitboxes():
					if hb.pos.distance_to(t.pos) < hb.data.radius + t.body_radius():
						t.hp -= hb.damage
						if t.hp <= 0.0:
							t.kill("destroyed")
							_log("trap_destroyed", {"trap": t.serial})
						break
			if not t.alive or not t.armed:
				continue
			var trig: bool = false
			if t.trigger == "contact_enemy":
				trig = _touches_fighter(t.pos, maxf(t.body_radius(), t.trigger_radius * 0.5), f)
			elif t.trigger == "proximity":
				var mid: Vector2 = f.pos + Vector2(0.0, f.stats.visual_height * 0.5)
				trig = mid.distance_to(t.pos) <= t.trigger_radius
			if trig:
				t.explode()
				_log("trap_trigger", {"trap": t.serial, "by": f.player})
				break
		if t.alive and t.armed and t.owner_can_trigger and t.owner_fighter != null and t.trigger == "contact_enemy" \
				and _touches_fighter(t.pos, t.body_radius(), t.owner_fighter):
			t.explode()


func _boxes_touch_point(boxes: Array[ActiveHitbox], p: Vector2, r: float) -> bool:
	for b: ActiveHitbox in boxes:
		if b.pos.distance_to(p) < b.data.radius + r:
			return true
	return false


func _touches_fighter(p: Vector2, r: float, f: Fighter) -> bool:
	var t: CombatTarget = f.combat_target()
	for hb: HurtboxData in t.hurtboxes:
		if hb.intangible:
			continue
		if HitResolver.circle_hits_capsule(p, r, hb.world_a(t.origin, t.facing), hb.world_b(t.origin, t.facing), hb.radius):
			return true
	return false


# --- 6. command grab --------------------------------------------------------------------------

func _grab_boxes() -> void:
	var grabs: Array[Dictionary] = []
	for f: Fighter in fighters:
		var m: SpecialMove = _move_of(f)
		if m == null or f.hitlag_frames > 0:
			continue
		var gb: Dictionary = m.grab_box()
		if gb.is_empty():
			continue
		for v: Fighter in fighters:
			if v == f or not v.active or v.is_intangible():
				continue
			var gt: String = String(gb.get("grab_type", "grounded_only"))
			if gt == "grounded_only" and not v.grounded:
				continue
			if gt == "airborne_only" and v.grounded:
				continue
			if v.ledge_key != "" and not bool(gb.get("grab_ledge", false)):
				continue
			if _touches_fighter(gb["center"], float(gb["radius"]), v):
				grabs.append({"by": f, "victim": v, "move": m})
				break
	# Grab-trade: twee grabs die elkaar tegelijk pakken -> beide mis.
	for g: Dictionary in grabs:
		var traded: bool = false
		for o: Dictionary in grabs:
			if o != g and o["by"] == g["victim"] and o["victim"] == g["by"]:
				traded = true
		if traded:
			(g["move"] as SpecialMove).on_grab_clank()
			_log("grab_clank", {"by": (g["by"] as Fighter).player})
			continue
		(g["move"] as SpecialMove).on_grab(g["victim"])
		_log("grab", {"by": (g["by"] as Fighter).player, "victim": (g["victim"] as Fighter).player})


# --- 7. intercepts (armor, counter) ------------------------------------------------------------

func _intercepts() -> void:
	for d: Fighter in fighters:
		var m: SpecialMove = _move_of(d)
		if m == null or not d.active or d.hitlag_frames > 0 or not m.intercepting():
			continue
		var target: CombatTarget = d.combat_target()
		target.intangible = false
		var cands: Array[ActiveHitbox] = []
		var src: Dictionary = {}
		var seen: Dictionary = {}
		for a: Fighter in fighters:
			if a == d or not a.active:
				continue
			for hb: ActiveHitbox in a.active_hitboxes():
				var key: String = HitResolver.hit_key(hb.owner, hb.instance, hb.data.group, d.player)
				if a.already_hit.has(key):
					continue
				cands.append(hb)
				src[hb] = a
		for e: SpecialEntity in entities:
			if not e.alive or e.owner_id == d.player:
				continue
			for hb: ActiveHitbox in e.active_hitboxes():
				var key2: String = HitResolver.hit_key(hb.owner, hb.instance, hb.data.group, d.player)
				if e.already_hit.has(key2):
					continue
				cands.append(hb)
				src[hb] = e
		if cands.is_empty():
			continue
		var tl: Array[CombatTarget] = [target]
		var res: HitResolver.Result = HitResolver.resolve(cands, tl, {}, _all_ids())
		for ev: HitEvent in res.hits:
			if ev.kind != HitEvent.Kind.HIT:
				continue
			var key3: String = "%d:%d" % [ev.hitbox.owner, ev.hitbox.instance]
			if seen.has(key3):
				continue
			seen[key3] = true
			var s: Object = src.get(ev.hitbox)
			var outcome: String = m.intercept(ev, s)
			_log(outcome, {"defender": d.player, "attacker": ev.attacker, "damage": ev.damage})
			if s is Fighter:
				(s as Fighter).on_hit_landed(ev)
			elif s is SpecialEntity:
				var en: SpecialEntity = s
				en.already_hit[ev.key] = true
				if outcome == "counter" or outcome == "counter_reflect":
					if outcome == "counter":
						en.kill("countered")
				else:
					en.on_hit_target(ev)
			if outcome == "armor_break":
				d.receive_hit(ev)
			if not m.intercepting() or outcome != "armor":
				break


func _all_ids() -> Dictionary:
	var ids: Dictionary = {}
	for f: Fighter in fighters:
		ids[f.player] = true
	for e: SpecialEntity in entities:
		ids[e.owner_id] = true
	return ids


# --- 8. entity-hits ---------------------------------------------------------------------------

func _entity_hits() -> void:
	var boxes: Array[ActiveHitbox] = []
	var by_inst: Dictionary = {}
	var already: Dictionary = {}
	for e: SpecialEntity in entities:
		if not e.alive:
			continue
		var hb: Array[ActiveHitbox] = e.active_hitboxes()
		if hb.is_empty():
			continue
		boxes.append_array(hb)
		by_inst[e.instance] = e
		already.merge(e.already_hit)
	if boxes.is_empty():
		return
	var targets: Array[CombatTarget] = []
	for f: Fighter in fighters:
		if f.active and f.state != null:
			targets.append(f.combat_target())
	var res: HitResolver.Result = HitResolver.resolve(boxes, targets, already, _all_ids())
	var hits: Array[HitEvent] = res.hits.duplicate()
	hits.sort_custom(func(a: HitEvent, b: HitEvent) -> bool:
		if a.hitbox.instance != b.hitbox.instance:
			return a.hitbox.instance < b.hitbox.instance
		return a.defender < b.defender)
	for ev: HitEvent in hits:
		var e: SpecialEntity = by_inst.get(ev.hitbox.instance)
		var d: Fighter = _fighter(ev.defender)
		if e == null or d == null or not e.alive:
			continue
		e.already_hit[ev.key] = true
		if ev.kind == HitEvent.Kind.HIT:
			d.receive_hit(ev)
			e.on_hit_target(ev)
			_log("entity_hit", {"entity": e.serial, "defender": d.player, "damage": ev.damage})
			var owner_kit: SpecialKit = SpecialKit.of(e.owner_fighter) if e.owner_fighter != null else null
			if owner_kit != null:
				var od: SpecialDef = owner_kit.def_for(e.source_slot) if e.source_slot != "" else null
				if od != null and od.limit_resets_on_hit:
					owner_kit.reset_air_limits("hit_landed")
		else:
			if ev.kind == HitEvent.Kind.SHIELD and d.has_method("on_shield_hit"):
				d.call("on_shield_hit", ev)
			e.on_shield(ev)
			_log("entity_shield", {"entity": e.serial, "defender": d.player})
