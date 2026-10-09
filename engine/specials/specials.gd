class_name Specials
extends RefCounted
## Facade van de special-toolkit (M5). Aansluiting: `Specials.attach(fighter)` zet o.a. `Fighter.special_hook`
## (de M4-hook in check_special) op `Specials.hook`; zie docs/specials.md, "Aansluiting". Al het andere (states,
## wereld + entities, limieten resetten, opruimen bij dood) regelt de toolkit zelf.

const DIR: String = "res://characters/%s/specials"

const TEMPLATE_SCRIPTS: Dictionary = {
	"projectile": preload("res://engine/specials/templates/tpl_projectile.gd"),
	"charge": preload("res://engine/specials/templates/tpl_charge.gd"),
	"teleport": preload("res://engine/specials/templates/tpl_teleport.gd"),
	"rising_multi": preload("res://engine/specials/templates/tpl_rising_multi.gd"),
	"counter": preload("res://engine/specials/templates/tpl_counter.gd"),
	"reflector": preload("res://engine/specials/templates/tpl_reflector.gd"),
	"absorber": preload("res://engine/specials/templates/tpl_absorber.gd"),
	"command_grab": preload("res://engine/specials/templates/tpl_command_grab.gd"),
	"dash_strike": preload("res://engine/specials/templates/tpl_dash_strike.gd"),
	"stall_fall": preload("res://engine/specials/templates/tpl_stall_fall.gd"),
	"multi_jump": preload("res://engine/specials/templates/tpl_multi_jump.gd"),
	"tether": preload("res://engine/specials/templates/tpl_tether.gd"),
	"trap": preload("res://engine/specials/templates/tpl_trap.gd"),
	"buff": preload("res://engine/specials/templates/tpl_buff.gd"),
	"command_dash": preload("res://engine/specials/templates/tpl_command_dash.gd"),
	"spin": preload("res://engine/specials/templates/tpl_spin.gd"),
}

static var _def_cache: Dictionary = {}


static func clear_cache() -> void:
	_def_cache.clear()


## Registreert de special-states op een fighter (idempotent).
static func register_states(f: Fighter) -> void:
	if not f.has_state("Special"):
		f.register_state(StateSpecial.new())
	if not f.has_state("SpecialHeld"):
		f.register_state(StateSpecialHeld.new())


## Koppelt een fighter aan de toolkit: states, kit, `Fighter.special_hook` (M4-hook in check_special) en - als de
## stage bekend is - een O(1)-registratie op de stage. Goedkoop: de SpecialWorld ontstaat pas bij de eerste special.
## (zie docs/specials.md). Tests roepen dit voor alle fighters aan (ook tegenstanders zonder specials).
static func attach(f: Fighter) -> SpecialKit:
	register_states(f)
	if "special_hook" in f and not (f.get("special_hook") as Callable).is_valid():
		f.set("special_hook", Specials.hook)
	SpecialWorld.register_fighter(f)
	return SpecialKit.of(f)


## Callable voor Fighter.special_hook: input = Fighter.special_input() {dir, back, grounded}.
## Side-B achteruit draait de fighter om (Melee); dat doet try_start via de stick.
static func hook(f: Fighter, inp: Dictionary) -> bool:
	return try_start(f, String(inp.get("dir", "neutral")))


## Definitie uit characters/<id>/specials/<slot>.tres (null als die niet bestaat). Gecachet.
static func load_def(character_id: String, slot: String) -> SpecialDef:
	var path: String = CharacterLoader.dir(character_id).path_join("specials").path_join(slot + ".tres")
	if _def_cache.has(path):
		return _def_cache[path]
	var d: SpecialDef = null
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is SpecialDef:
			d = r
	_def_cache[path] = d
	return d


## Slot uit de stick (Melee-achtige drempels, SpecialAim.slot_from_stick).
static func slot_from_input(f: Fighter) -> String:
	return SpecialAim.slot_from_stick(f.stick())


## B-knop (nieuw ingedrukt) -> slot uit de stick -> try_start. Geeft true als er een special startte
## (of een owner_signal-trap ontplofte).
static func check_input(f: Fighter) -> bool:
	if not f.input.pressed(InputFrame.BTN_SPECIAL):
		return false
	return try_start(f, slot_from_input(f))


## Start de special van `slot` als dat mag (grond/lucht, per-airtime-limiet, cooldown, max-alive-block).
## Side-B met de stick naar achteren draait de fighter om (Melee).
static func try_start(f: Fighter, slot: String) -> bool:
	var kit: SpecialKit = attach(f)
	var def: SpecialDef = kit.def_for(slot)
	if def == null or def.templates.is_empty():
		return false
	if f.grounded and not def.ground_allowed:
		return false
	if not f.grounded and not def.air_allowed:
		return false
	# owner_signal: nog een levende trap van dit slot -> ontploffen i.p.v. een nieuwe plaatsen.
	if def.primary() == "trap" and String(def.get_param("trigger", not f.grounded, "")) == "owner_signal":
		var w: SpecialWorld = SpecialWorld.of(f)
		var live: Array[SpecialEntity] = w.alive_of(f, slot, "trap")
		if not live.is_empty():
			for t: SpecialEntity in live:
				(t as SpecialTrap).explode()
			return true
	if not kit.can_use(def):
		return false
	var move: SpecialMove = make_runner(def, f, 0)
	if move == null or not move.can_start():
		return false
	if slot == "side":
		var sx: float = f.stick_x()
		if absf(sx) >= SpecialAim.SLOT_SIDE_THRESHOLD - FighterConst.EPS and signf(sx) != float(f.facing):
			f.facing = -f.facing
	kit.count_use(def)
	f.change_state("Special", {"move": move})
	return true


## Runner voor templates[index] (0 = primair). Eigen script: def.script_path, anders
## characters/<id>/specials/<slot>.gd als dat bestaat (alleen voor index 0).
static func make_runner(def: SpecialDef, f: Fighter, index: int) -> SpecialMove:
	var script: Script = null
	if index == 0:
		var path: String = def.script_path
		if path == "":
			var guess: String = CharacterLoader.dir(f.character_id).path_join("specials").path_join(def.slot + ".gd")
			if ResourceLoader.exists(guess):
				path = guess
		if path != "" and ResourceLoader.exists(path):
			script = load(path)
	var tpl: String = def.templates[index] if index < def.templates.size() else ""
	if script == null:
		script = TEMPLATE_SCRIPTS.get(tpl)
	if script == null:
		push_error("Specials: onbekend sjabloon '%s' (%s)" % [tpl, def.slot])
		return null
	var m: Variant = script.new()
	if not (m is SpecialMove):
		push_error("Specials: script voor '%s' is geen SpecialMove" % def.slot)
		return null
	var move: SpecialMove = m
	move.f = f
	move.def = def
	move.kit = SpecialKit.of(f)
	move.world = SpecialWorld.of(f)
	move.slot = def.slot
	move.template = tpl
	move.linked = index > 0
	return move


## Eén special-stap voor alle fighters van een stage (tests zonder Sim; in het spel doet Sim dit).
static func step(holder: Object) -> void:
	if holder == null or not holder.has_meta(SpecialWorld.META):
		return
	var w: Variant = holder.get_meta(SpecialWorld.META)
	if w is SpecialWorld:
		(w as SpecialWorld).step()
