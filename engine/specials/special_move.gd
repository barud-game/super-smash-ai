class_name SpecialMove
extends RefCounted
## Basis-runner van één uitgevoerde special (bouwsteen 1: move-runner/fase-machine). Elk sjabloon
## (engine/specials/templates/) en elk eigen character-script (`characters/<id>/specials/<slot>.gd`) breidt dit uit.
## Draait binnen `StateSpecial` (id "Special"): anim/iasa/phys/coll worden doorgegeven; hitlag bevriest alles
## automatisch (Fighter tickt de state dan niet).
##
## Frames: `frame` = frames sinds de knopdruk (0 = drukframe), `phase_frame` = frames in de huidige fase (0-based).
## Instellingen via `p(key, default)`: de `_air`/`_ground`-variant volgt waar de special begon (`started_air`).
## Zie docs/specials.md voor de API en de override-punten.

var f: Fighter
var def: SpecialDef
var kit: SpecialKit
var world: SpecialWorld
var host: StateSpecial
var slot: String = ""
var template: String = ""
## true = deze runner is templates[1] en leest linked_params.
var linked: bool = false
var phase: String = "startup"
var phase_frame: int = 0
var frame: int = 0
var started_air: bool = false
## Charge-schaal (0..1) van een charge-wikkel; de multipliers hieronder zijn daaruit afgeleid.
var charge_ratio: float = 0.0
var damage_mult: float = 1.0
var kb_mult: float = 1.0
var size_mult: float = 1.0
var speed_mult: float = 1.0
## Zwaartekracht-factor tijdens de move (0 = zweeft).
var gravity_scale: float = 1.0
## Er is (minstens) één treffer geland met deze move (eigen hitboxes of entities).
var hit_landed: bool = false
var armor_broken: bool = false
## Onzichtbaar + intangible (teleport-verdwijnfase).
var hidden: bool = false
var interrupted: bool = false
var done: bool = false

var _hits_seen: int = 0
var _scaled: Dictionary = {}


# =============================================================================================
# Levenscyclus
# =============================================================================================

## Door StateSpecial.enter(). Niet overschrijven; gebruik start().
func begin() -> void:
	f.start_move()
	started_air = not f.grounded
	f.fastfalling = false
	gravity_scale = pf("gravity_scale", 1.0)
	if started_air:
		match ps("momentum_air", "keep"):
			"zero":
				f.vel = Vector2.ZERO
			"scale":
				f.vel *= pf("momentum_scale", 0.5)
	if kit != null and kit.mult("damage_dealt_mult") != 1.0:
		damage_mult *= kit.mult("damage_dealt_mult")
	if kit != null and kit.mult("kb_dealt_mult") != 1.0:
		kb_mult *= kit.mult("kb_dealt_mult")
	phase = "startup"
	phase_frame = 0
	present("start")
	start()


## Vervolg-runner (templates[1]) die het overneemt van `prev` (charge-release, sequentie, follow-up).
func begin_linked(prev: SpecialMove) -> void:
	f.start_move()
	started_air = not f.grounded
	gravity_scale = pf("gravity_scale", prev.gravity_scale)
	hit_landed = prev.hit_landed
	phase = "startup"
	phase_frame = 0
	start()


## Override: mag de special nu starten (bv. max_alive vol met on_cap "block")? Vóór de state-wissel.
func can_start() -> bool:
	return true


## Override: zet de beginfase/snelheden. Standaard: startup.
func start() -> void:
	set_phase("startup")


## Override: fase-overgangen (draait elk frame in anim, na het ophogen van de tellers).
func step() -> void:
	pass


## Override: input tijdens de move (na de cancel-check).
func input() -> void:
	pass


## Override: opruimen bij het verlaten van de state (ook bij geraakt worden: `interrupted`).
func on_exit() -> void:
	if hidden:
		set_hidden(false)


func anim() -> void:
	frame += 1
	phase_frame += 1
	_track_hits()
	step()


func iasa() -> void:
	if done:
		return
	if _check_cancel():
		return
	input()


func phys() -> void:
	if f.grounded:
		ground_phys()
	else:
		air_phys()


## Standaard grond-physics: wrijving.
func ground_phys() -> void:
	f.apply_ground_friction()


## Standaard lucht-physics: gravity × gravity_scale (geen fast fall) + sturen volgens stick_control.
func air_phys() -> void:
	apply_gravity()
	match ps("stick_control", "none"):
		"x_only", "full":
			f.apply_air_drift(f.stick_x(), pf("drift_mobility", 1.0))
		_:
			f.vel.x = move_toward(f.vel.x, 0.0, f.stats.air_friction)


func set_phase(name_: String) -> void:
	phase = name_
	phase_frame = 0
	present(name_)


func is_end_phase() -> bool:
	return phase == "end"


# =============================================================================================
# Einde, landen, helpless (bouwstenen 13, 22)
# =============================================================================================

## Helpless na afloop? (special fall; director: standaard aan bij luchtrecoveries)
func helpless_now() -> bool:
	if not def.helpless_after:
		return false
	return not (def.helpless_on_miss_only and hit_landed)


## Normaal einde van de special. Sequentie-combinatie: templates[1] neemt het over.
func finish() -> void:
	if done:
		return
	if _chain_linked():
		return
	done = true
	if not f.grounded:
		if helpless_now():
			f.change_state("FallSpecial", {"landing_lag": def.landing_lag,
				"mobility": pf("helpless_mobility", f.stats.special_fall_mobility)})
		else:
			f.change_state("Fall")
	else:
		f.change_state("Wait")


## Hoe templates[1] aansluit: "sequence" (na afloop), "release" (charge), "follow_up" (command_dash), "none".
func chain_mode() -> String:
	return "sequence"


func _chain_linked() -> bool:
	if linked or def.linked_template() == "" or chain_mode() != "sequence" or host == null:
		return false
	start_linked(charge_ratio)
	return true


## Start templates[1] als vervolg (met charge-schaal `ratio`).
func start_linked(ratio: float) -> SpecialMove:
	var nxt: SpecialMove = Specials.make_runner(def, f, 1)
	if nxt == null:
		return null
	nxt.set_charge(ratio)
	host.swap(nxt, self)
	return nxt


## Landen tijdens de move. In de startup: doorgaan op de grond (als de grondvariant mag). Daarna (actief/einde):
## vaste landing lag (geen L-cancel), of de resterende grond-endlag als die lager is (§0.3).
func on_land() -> void:
	if phase == "startup" and def.ground_allowed:
		return
	land_with_lag(def.landing_lag)


func land_with_lag(lag: int) -> void:
	done = true
	var rest: int = remaining_ground_endlag()
	if rest >= 0:
		lag = mini(lag, rest)
	if helpless_now() or phase == "helpless":
		f.change_state("LandingFallSpecial", {"lag": maxi(lag, 1)})
	else:
		f.change_state("Landing", {"lag": maxi(lag, 1)})


## Resterende endlag als de move op de grond was gedaan (-1 = onbekend/niet van toepassing).
func remaining_ground_endlag() -> int:
	if phase != "end":
		return -1
	return maxi(pi_("endlag_ground", pi_("endlag", 20)) - phase_frame, 0)


## Grond-variant liep van de rand: true = de fighter glijdt eraf en gaat door in de lucht.
func wants_off_edge() -> bool:
	return false


## Aangeroepen door StateSpecial als de fighter aan de rand stopt; `gv` = gr_vel van vóór de stop.
func on_edge(side: int, gv: float) -> void:
	if wants_off_edge():
		f.pos.x += side * 0.05
		f.leave_ground(Vector2(gv, 0.0))


func lands_on_platforms() -> bool:
	return f.stick_y() > -MeleeStick.PLATFORM_FALL_THROUGH_THRESHOLD + FighterConst.EPS


## Ledge-snap-hook (bouwsteen 14): mag de move nu een ledge grijpen?
func ledge_snap_active() -> bool:
	if hidden:
		return false
	match def.ledge_snap:
		"during":
			return true
		"end_only":
			return is_end_phase()
	return false


## Mag de snap ook tijdens stijgen (alleen met de voeten onder de ledge)?
func ledge_snap_rising() -> bool:
	return def.ledge_snap == "during"


# =============================================================================================
# Vensters: armor, intangibility, cancel (bouwstenen 7, 8, 23)
# =============================================================================================

func _in_window(w: Dictionary) -> bool:
	if w.is_empty():
		return false
	return frame >= int(w.get("from", 0)) and frame <= int(w.get("to", -1))


func armor_active() -> bool:
	return not armor_broken and _in_window(def.armor)


## Intangible voor alle hitboxes (verdwijnen, intangible-venster).
func intangible() -> bool:
	return hidden or _in_window(def.intangible)


## Vangt de special zelf inkomende hits af (armor, counter)? De state is dan intangible voor CombatSystem
## en SpecialWorld legt de hits zelf tegen de hurtbox (zie SpecialWorld._intercepts).
func intercepting() -> bool:
	return armor_active()


## Inkomende hit tijdens intercepting(). Geeft de uitkomst: "armor" (opgevangen), "armor_break"
## (de wereld past de hit gewoon toe), "counter", "counter_reflect" of "ignore".
func intercept(ev: HitEvent, _source: Object) -> String:
	if armor_active():
		var cap: float = float(def.armor.get("max_damage", 8.0))
		if ev.damage <= cap + 0.0001:
			f.set_percent(minf(f.percent + ev.damage, Fighter.MAX_PERCENT))
			f.hitlag_frames = maxi(f.hitlag_frames, ev.defender_hitlag)
			f.hitlag_victim = false
			return "armor"
		armor_broken = true
		return "armor_break"
	return "ignore"


func _check_cancel() -> bool:
	if not _in_window(def.cancel_window):
		return false
	var to: Array = def.cancel_window.get("to_states", ["jump"])
	if "jump" in to:
		var src: int = f.jump_source()
		if src != 0:
			if src == 2:
				f.consume_tap_jump()
			done = true
			if f.grounded:
				f.change_state("KneeBend", {"tap": src == 2})
				return true
			if f.air_jumps_used < f.stats.air_jumps:
				f.change_state("JumpAerial")
				return true
			done = false
	if "shield" in to and f.input.pressed(InputFrame.BTN_SHIELD):
		done = true
		if f.grounded:
			# ⚠️ Shield bestaat nog niet (M4): Guard als die state er is, anders Wait.
			f.change_state("Guard" if f.has_state("Guard") else "Wait")
		else:
			f.change_state("EscapeAir")
		return true
	return false


# =============================================================================================
# Wereld-interacties (overschrijfbaar): reflect, absorb, grab, intercept-callbacks
# =============================================================================================

## {center, radius, damage_mult, speed_mult, limit, facing} of leeg.
func reflect_box() -> Dictionary:
	return {}


## {center, radius, facing} of leeg.
func absorb_box() -> Dictionary:
	return {}


## {center, radius, grab_type, grab_ledge} of leeg.
func grab_box() -> Dictionary:
	return {}


func on_reflect(_e: SpecialEntity) -> void:
	pass


## true = opgenomen (entity verdwijnt).
func on_absorb(_e: SpecialEntity) -> bool:
	return false


func on_grab(_victim: Fighter) -> void:
	pass


func on_grab_clank() -> void:
	pass


# =============================================================================================
# Hitboxes (bouwsteen 2)
# =============================================================================================

## Override: hitboxes van dit frame.
func hitboxes() -> Array[ActiveHitbox]:
	return []


## Actieve hitboxes van een lijst op fase-frame `t` (frames relatief aan de fase; end_frame < 0 = altijd),
## rond `origin`, met charge/buff-schaal.
func boxes(list: Array[HitboxData], t: int, origin: Vector2 = Vector2.INF, fac: int = 0) -> Array[ActiveHitbox]:
	var out: Array[ActiveHitbox] = []
	var o: Vector2 = f.pos if origin == Vector2.INF else origin
	var fc: int = f.facing if fac == 0 else fac
	for raw: HitboxData in list:
		if raw.end_frame >= 0 and not raw.is_active(t):
			continue
		var h: HitboxData = scaled(raw)
		var a: ActiveHitbox = ActiveHitbox.make(h, f.player, f.move_instance, MoveData.world_pos(h, o, fc), fc)
		a.damage = h.damage * damage_mult
		out.append(a)
	return out


## Hitboxes van een rol uit de definitie.
func role_boxes(role: String, t: int, origin: Vector2 = Vector2.INF, fac: int = 0) -> Array[ActiveHitbox]:
	return boxes(def.hits(role), t, origin, fac)


## Kopie met kb/size-schaal (gecachet per bron-hitbox). Damage-schaal zit in ActiveHitbox.damage.
func scaled(h: HitboxData) -> HitboxData:
	if kb_mult == 1.0 and size_mult == 1.0:
		return h
	if _scaled.has(h):
		return _scaled[h]
	var c: HitboxData = h.duplicate() as HitboxData
	c.base_kb = h.base_kb * kb_mult
	c.kb_growth = h.kb_growth * kb_mult
	c.set_kb = h.set_kb * kb_mult
	c.radius = h.radius * size_mult
	_scaled[h] = c
	return c


## Hitbox uit eenvoudige parameters (voor sjablonen zonder eigen hit_data).
static func make_hit(id_: int, start: int, end: int, offset: Vector2, radius: float, damage: float,
		angle: float = 361.0, bkb: float = 20.0, kbg: float = 80.0, group: int = 0) -> HitboxData:
	return MoveSet.make_hitbox(id_, start, end, offset, radius, damage, angle, bkb, kbg, group)


## Hitboxes van een rol, of een standaard-hitbox uit de parameters (`<prefix>damage`, `<prefix>kb_angle`,
## `<prefix>kb_base`, `<prefix>kb_scale`, `<prefix>size`) als de rol ontbreekt. Een expliciet lege rol = geen hitbox.
func hits_or_default(role: String, prefix: String, start: int, end: int, offset: Vector2, radius: float,
		damage: float, angle: float = 361.0, bkb: float = 20.0, kbg: float = 80.0) -> Array[HitboxData]:
	var list: Array[HitboxData] = def.hits(role)
	if not list.is_empty() or def.hitboxes.has(role):
		return list
	var h: HitboxData = make_hit(0, start, end, offset, pf(prefix + "size", radius), pf(prefix + "damage", damage),
		pf(prefix + "kb_angle", angle), pf(prefix + "kb_base", bkb), pf(prefix + "kb_scale", kbg))
	var out: Array[HitboxData] = [h]
	return out


## Directe treffer (worp, tether-pull, explosie op een vastgehouden doelwit): één hitbox op het lichaamsmidden van
## `victim`, langs HitResolver (dezelfde knockback/hitlag-regels), daarna aanvaller-hitlag + receive_hit.
## Negeert intangibility en shield van het slachtoffer (hij wordt vastgehouden). Geeft het event of null.
static func apply_direct_hit(attacker: Fighter, victim: Fighter, h: HitboxData, damage: float) -> HitEvent:
	var c: HitboxData = h.duplicate() as HitboxData
	c.offset = Vector2.ZERO
	c.radius = maxf(c.radius, 2.0)
	c.ignores_shield = true
	var at: Vector2 = victim.pos + Vector2(0.0, victim.stats.visual_height * 0.5)
	var a: ActiveHitbox = ActiveHitbox.make(c, attacker.player, attacker.move_instance, at, attacker.facing)
	a.damage = damage
	var t: CombatTarget = victim.combat_target()
	t.intangible = false
	t.invincible = false
	t.shielding = false
	var bl: Array[ActiveHitbox] = [a]
	var tl: Array[CombatTarget] = [t]
	var res: HitResolver.Result = HitResolver.resolve(bl, tl, {}, {attacker.player: true, victim.player: true})
	if res.hits.is_empty():
		return null
	var ev: HitEvent = res.hits[0]
	attacker.on_hit_landed(ev)
	victim.receive_hit(ev)
	return ev


func _track_hits() -> void:
	var n: int = f.already_hit.size()
	if n > _hits_seen:
		hit_landed = true
		if def.limit_resets_on_hit and kit != null:
			kit.reset_air_limits("hit_landed")
	_hits_seen = n


# =============================================================================================
# Velocity-helpers (bouwsteen 3)
# =============================================================================================

func apply_gravity(scale: float = -1.0) -> void:
	var g: float = gravity_scale if scale < 0.0 else scale
	f.vel.y = maxf(f.vel.y - f.stats.gravity * g, -f.stats.terminal_velocity)


## Zet de snelheid in een wereldrichting. Op de grond: alleen horizontaal (gr_vel), tenzij `dir` omhoog wijst
## (dan van de grond af).
func set_velocity(v: Vector2) -> void:
	if f.grounded:
		if v.y > 0.0001:
			f.leave_ground(v)
		else:
			f.gr_vel = v.x
	else:
		f.vel = v


func scale_velocity(k: float) -> void:
	if f.grounded:
		f.gr_vel *= k
	else:
		f.vel *= k


func velocity() -> Vector2:
	return Vector2(f.gr_vel, 0.0) if f.grounded else f.vel


func set_hidden(v: bool) -> void:
	hidden = v
	if f.visual != null:
		f.visual.visible = not v


# =============================================================================================
# Charge-schaal (bouwsteen 17)
# =============================================================================================

## Schaal uit de charge-instellingen van de definitie (`scale_damage`, `scale_kb`, `scale_size`, `scale_speed`:
## de multiplier bij volle lading; lineair, of in `charge_stages` treden).
func set_charge(ratio: float) -> void:
	charge_ratio = clampf(ratio, 0.0, 1.0)
	var r: float = charge_ratio
	var stages: int = int(def.get_param("charge_stages", false, 0))
	if stages > 0:
		r = floorf(r * float(stages) + 0.0001) / float(stages)
	damage_mult *= lerpf(1.0, float(def.get_param("scale_damage", false, 1.0)), r)
	kb_mult *= lerpf(1.0, float(def.get_param("scale_kb", false, 1.0)), r)
	size_mult *= lerpf(1.0, float(def.get_param("scale_size", false, 1.0)), r)
	speed_mult *= lerpf(1.0, float(def.get_param("scale_speed", false, 1.0)), r)
	_scaled.clear()


# =============================================================================================
# Parameters
# =============================================================================================

## Parameter (variant `_air`/`_ground` eerst). Primair: params > sjabloon-standaard (defaults()) > `default`.
## Gekoppeld (templates[1]): linked_params > sjabloon-standaard > params (gedeelde sleutels) > `default`,
## zodat bv. de startup van een charge niet in het gekoppelde projectiel lekt.
func p(key: String, default: Variant = null) -> Variant:
	var v: Variant = _lookup(def.linked_params if linked else def.params, key)
	if v != null:
		return v
	v = _lookup(defaults(), key)
	if v != null:
		return v
	if linked:
		v = _lookup(def.params, key)
		if v != null:
			return v
	return default


func _lookup(d: Dictionary, key: String) -> Variant:
	var variant: String = key + ("_air" if started_air else "_ground")
	if d.has(variant):
		return d[variant]
	return d.get(key)


## Override: standaardwaarden van het sjabloon (docs/special-sjablonen.md).
func defaults() -> Dictionary:
	return {}


func pf(key: String, default: float = 0.0) -> float:
	return float(p(key, default))


func pi_(key: String, default: int = 0) -> int:
	return int(p(key, default))


func pb(key: String, default: bool = false) -> bool:
	return bool(p(key, default))


func ps(key: String, default: String = "") -> String:
	return String(p(key, default))


## Standaard fase-lengtes (§0.2).
func startup_frames() -> int:
	return maxi(pi_("startup", 10), 1)


func active_frames() -> int:
	return maxi(pi_("active_frames", 4), 1)


func endlag_frames() -> int:
	return maxi(pi_("endlag", 20), 0)


# =============================================================================================
# Presentatie (bouwsteen 28)
# =============================================================================================

## Fase-event: VFX/SFX uit de definitie. Alles wordt gelogd in SpecialKit.fx_log (tests/debug).
func present(event: String) -> void:
	if def == null:
		return
	var v: String = String(def.vfx.get(event, ""))
	var s: String = String(def.sfx.get(event, ""))
	if v != "":
		# "a+b" = meerdere effecten tegelijk (bv. "speed_lines+dust_kick").
		for n: String in v.split("+", false):
			fx(n.strip_edges(), f.pos + Vector2(0.0, f.stats.visual_height * 0.5))
	if s != "":
		if kit != null:
			kit.log_fx("sfx", s, f.pos)
		f._sfx(s)


## Verplichte telegraaf (charge/buff/trap): altijd gelogd; zonder naam de standaard "telegraph".
func telegraph(at: Vector2 = Vector2.INF) -> void:
	var n: String = def.telegraph if def.telegraph != "" else "telegraph"
	var p0: Vector2 = f.pos + Vector2(0.0, f.stats.visual_height * 0.5) if at == Vector2.INF else at
	if kit != null:
		kit.log_fx("telegraph", n, p0)
	_spawn_vfx(n, p0)


## Presentatie-effect (gelogd + VfxLayer.spawn_special_fx). `params`: o.a. `color`, `size`, `count` (docs/vfx.md).
func fx(vfx_name: String, at: Vector2, params: Dictionary = {}) -> void:
	if kit != null:
		kit.log_fx("vfx", vfx_name, at)
	_spawn_vfx(vfx_name, at, params)


func _spawn_vfx(vfx_name: String, at: Vector2, params: Dictionary = {}) -> void:
	var layer: Node = f.get_vfx()
	if layer != null and layer.has_method("spawn_special_fx"):
		var p: Dictionary = params.duplicate()
		p["character"] = f.character_id
		p["foot"] = f.pos
		layer.spawn_special_fx(vfx_name, at, f.facing, f.player, p)


## Pose voor de huidige fase: definitie > sjabloon-standaard, met fallback als het rig de pose niet heeft.
func pose() -> String:
	var want: String = String(def.poses.get(phase, default_pose()))
	if host != null:
		return host.pick_pose(want, fallback_pose())
	return want


## Override: standaard pose per fase.
func default_pose() -> String:
	return "atk_special_projectile"


func fallback_pose() -> String:
	return "fall" if not f.grounded else "idle"


## [startup, active, total] voor play_timed, of leeg (loop-poses).
func pose_timing() -> Array:
	return []


func pose_frame() -> int:
	return phase_frame


func debug_text() -> String:
	return "%s:%s f%d" % [template, phase, phase_frame]
