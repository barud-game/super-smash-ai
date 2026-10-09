class_name CombatSystem
extends RefCounted
## Combat-stap per sim-frame, ná de movement van alle fighters (docs/combat.md, "M3-integratie"):
##   1. hitboxes verzamelen (Fighter.active_hitboxes(); leeg tijdens hitlag) en CombatTarget-snapshots maken
##   2. HitResolver.resolve() één keer voor alle fighters (already_hit per move-instantie, gecombineerd)
##   3. events toepassen in vaste volgorde: clanks, dan aanvallers (hitlag, hitfall, already_hit),
##      dan slachtoffers (percent + percent_changed, knockback, hitlag, VFX/SFX)
## Deterministisch: fighters gesorteerd op `player`, events op (aanvaller, slachtoffer).
## De Sim-autoload roept step() aan na alle entity-ticks (post-tick); tests roepen step() zelf aan.

## Resultaat van de laatste stap (tests/debug).
var last_result: HitResolver.Result = null
## Clank-SFX (er is geen eigen clank-recept; ⚠️).
const CLANK_SFX: String = "hit_weak"


static func _by_player(a: Fighter, b: Fighter) -> bool:
	return a.player < b.player


static func _by_pair(a: HitEvent, b: HitEvent) -> bool:
	if a.attacker != b.attacker:
		return a.attacker < b.attacker
	return a.defender < b.defender


func step(entities: Array) -> void:
	var list: Array[Fighter] = []
	for e: Variant in entities:
		if is_instance_valid(e) and e is Fighter and (e as Fighter).active and (e as Fighter).state != null:
			list.append(e)
	if list.size() < 2:
		for f: Fighter in list:
			if f.hitlag_frames <= 0:
				f.last_hitboxes = f.active_hitboxes()
		return
	list.sort_custom(_by_player)
	var by_id: Dictionary = {}
	var boxes: Array[ActiveHitbox] = []
	var targets: Array[CombatTarget] = []
	var already: Dictionary = {}
	var no_clank: Dictionary = {}
	for f: Fighter in list:
		by_id[f.player] = f
		if f.hitlag_frames <= 0:
			f.last_hitboxes = f.active_hitboxes()
		var hb: Array[ActiveHitbox] = f.active_hitboxes()
		boxes.append_array(hb)
		targets.append(f.combat_target())
		already.merge(f.already_hit)
		if not f.grounded:
			no_clank[f.player] = true
	if boxes.is_empty():
		last_result = null
		return
	var res: HitResolver.Result = HitResolver.resolve(boxes, targets, already, no_clank)
	last_result = res
	var touched: Dictionary = {}

	# 1. Clanks: hitlag voor beide kanten, rebound voor de zwakste (of beide).
	var rebounders: Dictionary = {}
	for ev: HitEvent in res.clanks:
		var a: Fighter = by_id.get(ev.attacker)
		var d: Fighter = by_id.get(ev.defender)
		if a != null:
			a.on_clank(ev.attacker_hitlag, ev.attacker_rebounds)
			touched[a] = true
		if d != null:
			d.on_clank(ev.defender_hitlag, ev.defender_rebounds)
			touched[d] = true
		if ev.attacker_rebounds:
			rebounders[ev.attacker] = true
		if ev.defender_rebounds:
			rebounders[ev.defender] = true
		var fx_owner: Fighter = a if a != null else d
		if fx_owner != null:
			var v: Node = fx_owner.get_vfx()
			if v != null and v.has_method("spawn_clank"):
				v.spawn_clank((ev.hitbox.pos + ev.other_hitbox.pos) * 0.5)
			fx_owner._sfx(CLANK_SFX)

	# 2. Treffers (HIT en SHIELD); een gereboundde aanvaller raakt deze frame niets.
	var hits: Array[HitEvent] = []
	for ev: HitEvent in res.hits:
		if not rebounders.has(ev.attacker) and by_id.has(ev.attacker) and by_id.has(ev.defender):
			hits.append(ev)
	hits.sort_custom(_by_pair)
	for ev: HitEvent in hits:
		var a: Fighter = by_id[ev.attacker]
		a.on_hit_landed(ev)
		touched[a] = true
	for ev: HitEvent in hits:
		var d: Fighter = by_id[ev.defender]
		if ev.kind == HitEvent.Kind.HIT:
			d.receive_hit(ev)
		# TODO M4: Kind.SHIELD -> shieldstun/shield-damage bij de verdediger (shield bestaat nog niet).
		touched[d] = true
	for f: Fighter in list:
		if touched.has(f):
			f._update_visual()
