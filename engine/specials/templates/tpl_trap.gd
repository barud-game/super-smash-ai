class_name TplTrap
extends SpecialMove
## Sjabloon `trap` (§13): startup -> place (SpecialTrap spawnt op place_offset; in een blok: fizzle/shift)
## -> endlag. De trap leeft los (arm_time, trigger, lifetime, explosie: rol "explode", frames relatief aan de
## explosie). trigger "owner_signal": opnieuw B (zelfde slot) laat levende traps ontploffen (Specials.try_start).
## Cap: max_alive per eigenaar (on_cap "replace" = oudste weg, "block" = niet plaatsen). Altijd zichtbaar +
## verplichte telegraaf bij plaatsen.

const DEFAULTS: Dictionary = {
	"startup": 12, "endlag": 20, "place_offset": Vector2(8.0, 2.0), "place_mode": "drop", "throw_speed": 1.5,
	"throw_angle": 45.0, "size": 3.0, "arm_time": 30, "trigger": "contact_enemy", "trigger_radius": 10.0,
	"lifetime": 600, "max_alive": 2, "on_cap": "replace", "explode_frames": 6, "explode_damage": 12.0,
	"explode_kb_angle": 60.0, "explode_kb_base": 40.0, "explode_kb_scale": 80.0, "explode_size": 10.0,
	"knockable_by_enemy": false, "hp": 10.0, "owner_can_trigger": false, "chain": false,
	"spawn_blocked": "fizzle", "visible_to_enemy": true, "clear_on_owner_death": true,
}

var placed: SpecialTrap = null


func defaults() -> Dictionary:
	return DEFAULTS


func can_start() -> bool:
	if ps("on_cap", "replace") != "block":
		return true
	return world.alive_of(f, slot, "trap").size() < pi_("max_alive", 2)


func start() -> void:
	set_phase("startup")
	telegraph()


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				_place()
				set_phase("end")
		"end":
			if phase_frame >= endlag_frames():
				finish()


func _place() -> void:
	var off: Vector2 = p("place_offset", Vector2(8.0, 2.0))
	var at: Vector2 = f.pos + Vector2(off.x * f.facing, off.y)
	var segs: Array = SpecialGeometry.segments(f.stage)
	if SpecialGeometry.inside_solid(segs, at):
		if ps("spawn_blocked", "fizzle") == "fizzle":
			present("fizzle")
			return
		at = SpecialGeometry.resolve_target(segs, f.pos + Vector2(0.0, off.y), at, "snap_to_valid")["pos"]
	var live: Array[SpecialEntity] = world.alive_of(f, slot, "trap")
	while live.size() >= pi_("max_alive", 2) and not live.is_empty():
		live[0].kill("replaced")
		live.remove_at(0)
	var t := SpecialTrap.new()
	t.setup_entity(world, f, slot)
	t.pos = at
	t.place_mode = ps("place_mode", "drop")
	if t.place_mode == "throw_arc":
		t.vel = SpecialAim.dir_from_angle(pf("throw_angle", 45.0), f.facing) * pf("throw_speed", 1.5)
	t.arm_time = pi_("arm_time", 30)
	t.trigger = ps("trigger", "contact_enemy")
	t.trigger_radius = pf("trigger_radius", 10.0)
	t.lifetime = pi_("lifetime", 600)
	t.explode_frames = pi_("explode_frames", 6)
	t.owner_can_trigger = pb("owner_can_trigger")
	t.chain = pb("chain")
	t.hp = pf("hp", 10.0) if pb("knockable_by_enemy") else 0.0
	t.draw_radius = pf("size", 3.0)
	t.survives_owner_death = not pb("clear_on_owner_death", true)
	t.damage_mult = damage_mult
	var src: Array[HitboxData] = hits_or_default("explode", "explode_", 0, -1, Vector2.ZERO, 10.0, 12.0, 60.0, 40.0, 80.0)
	for h: HitboxData in src:
		t.hit_list.append(scaled(h))
	world.spawn(t)
	placed = t
	telegraph(at)


func default_pose() -> String:
	return "atk_special_projectile"
