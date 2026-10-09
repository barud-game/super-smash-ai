class_name TplCounter
extends SpecialMove
## Sjabloon `counter` (§5): startup -> window (counter-venster: inkomende hits worden afgevangen via
## SpecialWorld._intercepts) -> bij trigger: strike (tegenaanval, rol "counter", frames relatief aan strike)
## -> strike_end; zonder trigger: whiff-endlag. Director: werkt tegen projectielen, niet tegen grabs.
## Counter-damage = min(counter_base + counter_mult × damage_geraakt, counter_cap). Beide fighters krijgen hitlag.

const DEFAULTS: Dictionary = {
	"startup": 5, "window_frames": 20, "whiff_endlag": 30, "strike_startup": 5, "strike_active": 3,
	"strike_endlag": 20, "trigger_types": ["melee", "projectile"], "min_damage": 0.0, "counter_base": 0.0,
	"counter_mult": 1.2, "counter_cap": 30.0, "counter_min": 6.0, "counter_kb_angle": 40.0, "counter_kb_base": 50.0,
	"counter_kb_scale": 80.0, "counter_size": 8.0, "facing_mode": "to_attacker", "invincible_on_trigger": 8,
	"counter_cooldown": 0, "damage_taken": "none", "projectile_reflect_on_trigger": false, "gravity_scale": 0.4,
	"momentum_air": "scale", "momentum_scale": 0.3,
}

var triggered: bool = false
var trigger_damage: float = 0.0
var strike_damage: float = 0.0
var attacker_pos: Vector2 = Vector2.ZERO


func defaults() -> Dictionary:
	return DEFAULTS


func start() -> void:
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				set_phase("window")
		"window":
			if phase_frame >= maxi(pi_("window_frames", 20), 1):
				set_phase("end")
		"end":
			if phase_frame >= pi_("whiff_endlag", 30):
				finish()
		"strike":
			if phase_frame >= pi_("strike_startup", 5) + pi_("strike_active", 3):
				set_phase("strike_end")
		"strike_end":
			if phase_frame >= pi_("strike_endlag", 20):
				finish()


func intercepting() -> bool:
	return super.intercepting() or phase == "window"


func intangible() -> bool:
	return super.intangible() or (triggered and frame_since_trigger() < pi_("invincible_on_trigger", 8))


var _trigger_frame: int = -1000


func frame_since_trigger() -> int:
	return frame - _trigger_frame


func intercept(ev: HitEvent, source: Object) -> String:
	if phase != "window":
		return super.intercept(ev, source)
	var types: Array = p("trigger_types", ["melee", "projectile"])
	var is_proj: bool = source is SpecialEntity
	if is_proj and not ("projectile" in types):
		return "ignore"
	if not is_proj and not ("melee" in types):
		return "ignore"
	if ev.damage < pf("min_damage", 0.0):
		return "ignore"
	triggered = true
	_trigger_frame = frame
	trigger_damage = ev.damage
	strike_damage = clampf(pf("counter_base", 0.0) + pf("counter_mult", 1.2) * ev.damage,
		pf("counter_min", 6.0), pf("counter_cap", 30.0))
	match ps("damage_taken", "none"):
		"reduced":
			f.set_percent(minf(f.percent + ev.damage * 0.5, Fighter.MAX_PERCENT))
		"full":
			f.set_percent(minf(f.percent + ev.damage, Fighter.MAX_PERCENT))
	# Counter-hitlag: beide bevroren (de aanvaller via on_hit_landed in de wereld).
	f.hitlag_frames = maxi(f.hitlag_frames, ev.defender_hitlag)
	f.hitlag_victim = false
	attacker_pos = f.pos
	if source is Fighter:
		attacker_pos = (source as Fighter).pos
	elif source is SpecialEntity:
		var own: Fighter = (source as SpecialEntity).owner_fighter
		attacker_pos = own.pos if own != null and is_instance_valid(own) else (source as SpecialEntity).pos
	if ps("facing_mode", "to_attacker") == "to_attacker" and absf(attacker_pos.x - f.pos.x) > 0.01:
		f.facing = 1 if attacker_pos.x > f.pos.x else -1
	f.start_move()
	set_phase("strike")
	var cd: int = pi_("counter_cooldown", 0)
	if cd > 0:
		kit.cooldowns[slot] = cd
	if is_proj and pb("projectile_reflect_on_trigger"):
		(source as SpecialEntity).reflect(f, 1.5, 1.0, 3)
		return "counter_reflect"
	return "counter"


func hitboxes() -> Array[ActiveHitbox]:
	if phase != "strike":
		return []
	var su: int = pi_("strike_startup", 5)
	if phase_frame < su or phase_frame >= su + pi_("strike_active", 3):
		return []
	var h: float = f.stats.visual_height
	var src: Array[HitboxData] = hits_or_default("counter", "counter_", 0, -1, Vector2(7.0, h * 0.55), 8.0, 10.0,
		40.0, 50.0, 80.0)
	var out: Array[ActiveHitbox] = boxes(src, phase_frame - su)
	for a: ActiveHitbox in out:
		a.damage = strike_damage * (a.data.damage / maxf(src[0].damage, 0.001))
	return out


func default_pose() -> String:
	return "atk_special_counter_strike" if phase == "strike" or phase == "strike_end" else "atk_special_counter"


func debug_text() -> String:
	return "counter:%s f%d%s" % [phase, phase_frame, " (trig %.0f)" % trigger_damage if triggered else ""]
