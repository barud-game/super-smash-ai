class_name TplTether
extends SpecialMove
## Sjabloon `tether` (§11, eenvoudig): startup -> extend (SpecialHook vliegt `extend_speed` tot `max_length`)
## -> latch (`latch_frames`) -> pull:
##   self:     fighter vliegt naar de ledge-hangpositie en grijpt de ledge (Fighter.grab_ledge; bezet = mis)
##   opponent: tegenstander (SpecialHeld) wordt naar de fighter getrokken, daarna rol "throw" (of standaard)
## -> endlag. Mis: miss_endlag (+ helpless_on_miss in de lucht). Rol "hook": hitbox op de haak (alleen als
## "fighter" geen anker-type is). Ledge-regels (bezet, grab-limiet) via het gedeelde ledge-systeem.

const DEFAULTS: Dictionary = {
	"startup": 10, "max_length": 120.0, "extend_speed": 8.0, "aim_mode": "fixed", "angle": 45.0,
	"anchor_types": ["ledge"], "pull_mode": "self", "pull_speed": 4.0, "latch_frames": 3, "endlag": 16,
	"miss_endlag": 30, "helpless_on_miss": true, "hand_offset": Vector2(4.0, 8.0), "pull_end_distance": 10.0,
	"throw_damage": 6.0, "throw_kb_angle": 45.0, "throw_kb_base": 50.0, "throw_kb_scale": 60.0, "gravity_scale": 0.5,
	"momentum_air": "scale", "momentum_scale": 0.3, "ledge_catch_radius": 6.0,
}

var hook: SpecialHook = null
var missed: bool = false
var victim: Fighter = null
var _offset: Vector2 = Vector2.ZERO


func defaults() -> Dictionary:
	return DEFAULTS


func start() -> void:
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				_shoot()
				set_phase("extend")
		"extend":
			if hook == null or not is_instance_valid(hook) or not hook.alive:
				_miss()
			elif hook.state == "latched":
				if hook.latched_kind == "fighter":
					_latch_fighter(hook.latched_fighter)
				else:
					set_phase("latch")
			elif hook.state == "miss":
				_miss()
		"latch":
			if phase_frame >= pi_("latch_frames", 3):
				set_phase("pull")
		"pull":
			if hook == null or not is_instance_valid(hook) or not hook.alive:
				_miss()
			elif hook.latched_kind == "ledge":
				_pull_self()
			else:
				_pull_opponent()
		"end":
			if phase_frame >= endlag_frames():
				finish()
		"miss_end":
			if phase_frame >= pi_("miss_endlag", 30):
				finish()


func _shoot() -> void:
	var mode: String = ps("aim_mode", "fixed")
	var dir: Vector2 = SpecialAim.direction(f.stick(), mode, f.facing, pf("angle", 45.0))
	if mode == "fixed":
		dir = SpecialAim.dir_from_angle(pf("angle", 45.0), f.facing)
	hook = SpecialHook.new()
	hook.setup_entity(world, f, slot)
	hook.dir = dir
	hook.extend_speed = pf("extend_speed", 8.0)
	hook.max_length = pf("max_length", 120.0)
	hook.hand_offset = p("hand_offset", Vector2(4.0, 8.0))
	hook.anchor_types = p("anchor_types", ["ledge"])
	hook.ledge_catch_radius = pf("ledge_catch_radius", 6.0)
	hook.pos = hook.hand()
	if not ("fighter" in hook.anchor_types):
		hook.hit_list = def.hits("hook")
	world.spawn(hook)


func _miss() -> void:
	missed = true
	_drop_hook()
	set_phase("miss_end")


func _latch_fighter(v: Fighter) -> void:
	if v == null or not is_instance_valid(v) or v.is_intangible() or not v.active:
		_miss()
		return
	victim = v
	hit_landed = true
	_offset = Vector2((v.pos.x - f.pos.x) * f.facing, v.pos.y - f.pos.y)
	v.change_state("SpecialHeld", {"holder": f, "offset": _offset, "max_frames": 120})
	set_phase("latch")


func _pull_self() -> void:
	var l: Dictionary = hook.latched_ledge
	var lp: Vector2 = l["pos"]
	var side: int = l["side"]
	var hang: Vector2 = f.ledge_hang_pos(lp, side)
	var to: Vector2 = hang - f.pos
	var spd: float = pf("pull_speed", 4.0)
	if to.length() <= spd + 0.5:
		_drop_hook()
		if f.ledge_occupied_by_other(lp, side) or f.ledge_cooldown_frames > 0:
			_miss()
			return
		done = true
		f.grab_ledge(lp, side)
		return
	if f.grounded:
		f.leave_ground(Vector2.ZERO)
	f.vel = to.normalized() * spd


func _pull_opponent() -> void:
	if victim == null or not is_instance_valid(victim) or victim.state_name() != "SpecialHeld":
		_drop_hook()
		set_phase("end")
		return
	var spd: float = pf("pull_speed", 4.0)
	var d: float = _offset.length()
	if d <= pf("pull_end_distance", 10.0) + spd:
		var src: Array[HitboxData] = hits_or_default("throw", "throw_", 0, -1, Vector2.ZERO, 6.0, 6.0, 45.0, 50.0, 60.0)
		_drop_hook()
		var v: Fighter = victim
		victim = null
		if not src.is_empty():
			SpecialMove.apply_direct_hit(f, v, scaled(src[0]), src[0].damage * damage_mult)
		elif v.state is StateSpecialHeld:
			(v.state as StateSpecialHeld).release()
		set_phase("end")
		return
	_offset = _offset - _offset.normalized() * spd
	var st: StateSpecialHeld = victim.state as StateSpecialHeld
	st.offset = _offset


func _drop_hook() -> void:
	if hook != null and is_instance_valid(hook) and hook.alive:
		hook.kill("done")
	hook = null


func phys() -> void:
	match phase:
		"pull":
			if hook != null and hook.latched_kind == "ledge":
				return
			if f.grounded:
				f.apply_ground_friction()
			else:
				f.vel = f.vel * 0.8
			return
		"extend", "latch":
			if not f.grounded:
				f.vel.x *= 0.9
				apply_gravity()
				return
	super.phys()


func on_land() -> void:
	if phase == "pull" or phase == "extend" or phase == "latch":
		return
	super.on_land()


func helpless_now() -> bool:
	if missed and pb("helpless_on_miss", true):
		return true
	return super.helpless_now()


func on_exit() -> void:
	super.on_exit()
	_drop_hook()
	if victim != null and is_instance_valid(victim) and victim.state_name() == "SpecialHeld":
		(victim.state as StateSpecialHeld).release()
	victim = null


func default_pose() -> String:
	return "atk_special_projectile"
