class_name SpecialKit
extends RefCounted
## Special-runtime per fighter (op de fighter als meta "special_kit"; Fighter zelf blijft ongewijzigd):
## geladen definities per slot, per-airtime-limieten (bouwsteen 15), bewaarde charge (17), buffs/stat-modifiers
## (20), cooldowns, heal-cap per stock en een log van presentatie-events (28; tests/debug).
## `poll()` draait één keer per frame via SpecialWorld (na alle fighters): resets, buff-duur, opruimen bij dood.

const META: String = "special_kit"
const FX_LOG_MAX: int = 64

var f: Fighter
## Slot -> SpecialDef (overschrijfbaar; anders geladen uit characters/<id>/specials/<slot>.tres).
var defs: Dictionary = {}
var _loaded: Dictionary = {}
## Slot -> gebruiken in deze airtime.
var air_uses: Dictionary = {}
## Slot -> {"ratio": float, "frames": int} (bewaarde charge, frames = resterende keep-tijd, -1 = onbeperkt).
var stored_charge: Dictionary = {}
## Slot -> resterende cooldown-frames.
var cooldowns: Dictionary = {}
## Slot -> gebruik deze stock.
var stock_uses: Dictionary = {}
## Actieve buffs: {slot, frames, modifiers, until_hit, stacks, move_swap}.
var buffs: Array[Dictionary] = []
## Totale genezing deze stock (absorber heal-cap).
var healed_this_stock: float = 0.0
## Presentatie-log: [{"tick", "kind" (vfx/sfx/pose/telegraph), "name", "pos"}].
var fx_log: Array[Dictionary] = []
## Laatste reset-reden (debug/tests).
var last_reset: String = ""

var _base_stats: FighterStats = null
var _base_moves: Dictionary = {}
var _was_dead: bool = false
var _prev_percent: float = 0.0


static func of(fighter: Fighter) -> SpecialKit:
	if fighter.has_meta(META):
		return fighter.get_meta(META)
	var k := SpecialKit.new()
	k.f = fighter
	k._prev_percent = fighter.percent
	fighter.set_meta(META, k)
	return k


## Definitie voor een slot: override in `defs`, anders characters/<id>/specials/<slot>.tres (gecachet).
func def_for(slot: String) -> SpecialDef:
	if defs.has(slot):
		return defs[slot]
	if _loaded.has(slot):
		return _loaded[slot]
	var d: SpecialDef = Specials.load_def(f.character_id, slot)
	_loaded[slot] = d
	return d


## Nieuw character in dezelfde fighter (Fighter.set_character): definities, buffs, charges en limieten opnieuw beginnen.
func reset_for_character() -> void:
	defs.clear()
	_loaded.clear()
	air_uses.clear()
	stored_charge.clear()
	cooldowns.clear()
	stock_uses.clear()
	buffs.clear()
	_base_stats = null
	_base_moves.clear()


# --- per-airtime-limieten ---------------------------------------------------------------------

func uses(slot: String) -> int:
	return int(air_uses.get(slot, 0))


func can_use(def: SpecialDef) -> bool:
	if int(cooldowns.get(def.slot, 0)) > 0:
		return false
	var lim: int = def.air_use_limit
	if lim >= 0 and not f.grounded and uses(def.slot) >= lim:
		return false
	var per_stock: int = int(def.get_param("use_limit_per_stock", false, -1))
	if per_stock >= 0 and int(stock_uses.get(def.slot, 0)) >= per_stock:
		return false
	return true


func count_use(def: SpecialDef) -> void:
	air_uses[def.slot] = uses(def.slot) + 1
	stock_uses[def.slot] = int(stock_uses.get(def.slot, 0)) + 1


## Reset van alle per-airtime-tellers. Redenen: "land", "ledge", "hit", "respawn", "wall_jump", "hit_landed".
func reset_air_limits(reason: String) -> void:
	if not air_uses.is_empty():
		last_reset = reason
	air_uses.clear()


# --- charge -----------------------------------------------------------------------------------

func store_charge(slot: String, ratio: float, keep_frames: int) -> void:
	stored_charge[slot] = {"ratio": clampf(ratio, 0.0, 1.0), "frames": keep_frames}


func take_charge(slot: String) -> float:
	if not stored_charge.has(slot):
		return 0.0
	var r: float = stored_charge[slot]["ratio"]
	stored_charge.erase(slot)
	return r


func peek_charge(slot: String) -> float:
	return float(stored_charge[slot]["ratio"]) if stored_charge.has(slot) else 0.0


# --- buffs / stat-modifiers (bouwsteen 20) ------------------------------------------------------

## Stat-velden die een buff mag schalen (FighterStats); andere modifiers (damage_dealt_mult, ...) worden
## alleen uitgelezen via `mult()`.
const STAT_FIELDS: Dictionary = {
	"walk_speed_mult": ["walk_max_velocity", "walk_initial_velocity"],
	"run_speed_mult": ["run_speed", "dash_initial_velocity"],
	"air_speed_mult": ["max_air_speed"],
	"jump_height_mult": ["jump_v_initial_velocity", "hop_v_initial_velocity"],
	"weight_mult": ["weight"],
	"fall_speed_mult": ["terminal_velocity", "fast_fall_velocity"],
}


## Buff toevoegen volgens `stack_rule` ("refresh", "stack_max", "block"). Geeft false bij "block".
func add_buff(slot: String, modifiers: Dictionary, frames: int, until_hit: bool, stack_rule: String,
		stack_max: int = 1, move_swap: Dictionary = {}) -> bool:
	for b: Dictionary in buffs:
		if b["slot"] != slot:
			continue
		match stack_rule:
			"block":
				return false
			"stack_max":
				if int(b["stacks"]) < stack_max:
					b["stacks"] = int(b["stacks"]) + 1
				b["frames"] = frames
				_apply_stats()
				return true
			_:
				b["frames"] = frames
				return true
	buffs.append({"slot": slot, "frames": frames, "modifiers": modifiers.duplicate(), "until_hit": until_hit,
		"stacks": 1, "move_swap": move_swap.duplicate()})
	_apply_stats()
	_apply_move_swap()
	return true


func has_buff(slot: String) -> bool:
	for b: Dictionary in buffs:
		if b["slot"] == slot:
			return true
	return false


func remove_buff(slot: String) -> void:
	var i: int = buffs.size() - 1
	while i >= 0:
		if buffs[i]["slot"] == slot:
			buffs.remove_at(i)
		i -= 1
	_apply_stats()
	_apply_move_swap()


func clear_buffs() -> void:
	if buffs.is_empty():
		return
	buffs.clear()
	_apply_stats()
	_apply_move_swap()


## Product van een modifier over alle buffs (stacks tellen als macht). 1.0 zonder buffs.
func mult(key: String) -> float:
	var m: float = 1.0
	for b: Dictionary in buffs:
		var mods: Dictionary = b["modifiers"]
		if mods.has(key):
			m *= pow(float(mods[key]), int(b["stacks"]))
	return m


## Vaste volgorde base -> archetype -> buff: de basis-stats (preset) worden gekopieerd en daarna geschaald.
func _apply_stats() -> void:
	if _base_stats == null:
		_base_stats = f.stats
	if buffs.is_empty():
		if f.stats != _base_stats:
			f.stats = _base_stats
		return
	var s: FighterStats = _base_stats.duplicate() as FighterStats
	for key: String in STAT_FIELDS:
		var m: float = mult(key)
		if m == 1.0:
			continue
		for field: String in STAT_FIELDS[key]:
			s.set(field, float(_base_stats.get(field)) * m)
	f.stats = s


## Move-swap (director-besluit 9): alleen data-moves (MoveData) in Fighter.moves, terug bij einde/dood.
## ⚠️ Wisselt direct; StateAttack leest de move bij enter, dus een lopende aanval houdt de oude.
func _apply_move_swap() -> void:
	for n: String in _base_moves:
		f.moves[n] = _base_moves[n]
	_base_moves.clear()
	for b: Dictionary in buffs:
		var sw: Dictionary = b["move_swap"]
		for n: String in sw:
			if sw[n] is MoveData:
				if not _base_moves.has(n):
					_base_moves[n] = f.moves.get(n)
				f.moves[n] = sw[n]


# --- presentatie --------------------------------------------------------------------------------

func log_fx(kind: String, fx_name: String, at: Vector2) -> void:
	fx_log.append({"tick": f.tick_count, "kind": kind, "name": fx_name, "pos": at})
	if fx_log.size() > FX_LOG_MAX:
		fx_log.remove_at(0)


func fx_seen(kind: String, fx_name: String) -> bool:
	for e: Dictionary in fx_log:
		if e["kind"] == kind and e["name"] == fx_name:
			return true
	return false


# --- per frame ----------------------------------------------------------------------------------

## Eén keer per frame (SpecialWorld, na alle fighters). Bouwsteen 15: limieten resetten bij landen, ledge,
## geraakt worden, respawn. Buff-duur loopt niet tijdens eigen hitlag (tick_during_hitlag = false).
func poll() -> void:
	var dead: bool = not f.active or f.state_name() == "Dead"
	if dead:
		if not _was_dead:
			_on_death()
		_was_dead = true
		return
	if _was_dead:
		_was_dead = false
		reset_air_limits("respawn")
	var sn: String = f.state_name()
	var in_special: bool = sn == "Special"
	if f.state_name() == "RebirthWait":
		reset_air_limits("respawn")
	elif f.grounded and not in_special:
		reset_air_limits("land")
	elif f.ledge_key != "":
		reset_air_limits("ledge")
	var got_hit: bool = f.percent > _prev_percent + 0.0001 and sn.begins_with("Damage")
	if got_hit:
		reset_air_limits("hit")
	_prev_percent = f.percent
	for s: String in cooldowns.keys():
		cooldowns[s] = int(cooldowns[s]) - 1
		if int(cooldowns[s]) <= 0:
			cooldowns.erase(s)
	for s: String in stored_charge.keys():
		var fr: int = int(stored_charge[s]["frames"])
		if fr > 0:
			stored_charge[s]["frames"] = fr - 1
			if fr - 1 <= 0:
				stored_charge.erase(s)
	if buffs.is_empty():
		return
	var frozen: bool = f.hitlag_frames > 0
	var changed: bool = false
	var i: int = buffs.size() - 1
	while i >= 0:
		var b: Dictionary = buffs[i]
		if (bool(b["until_hit"]) and got_hit):
			buffs.remove_at(i)
			changed = true
		elif not frozen and int(b["frames"]) >= 0:
			b["frames"] = int(b["frames"]) - 1
			if int(b["frames"]) <= 0:
				buffs.remove_at(i)
				changed = true
		i -= 1
	if changed:
		_apply_stats()
		_apply_move_swap()


func _on_death() -> void:
	reset_air_limits("respawn")
	clear_buffs()
	stored_charge.clear()
	stock_uses.clear()
	healed_this_stock = 0.0
	var w: SpecialWorld = SpecialWorld.find(f)
	if w != null:
		w.clear_owner(f)
