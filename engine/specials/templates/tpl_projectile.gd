class_name TplProjectile
extends SpecialMove
## Sjabloon `projectile` (docs/special-sjablonen.md §1): startup -> spawn-frame -> endlag.
## Rol "projectile": hitboxes van het projectiel (offset t.o.v. het projectiel; end_frame < 0 = altijd actief),
## anders een standaard-hitbox uit damage/kb_angle/kb_base/kb_scale/size.

const DEFAULTS: Dictionary = {
	"startup": 12, "endlag": 22, "endlag_air": 20, "landing_lag": 6,
	"momentum_air": "scale", "momentum_scale": 0.5, "gravity_scale": 0.6,
	"spawn_offset": Vector2(8.0, 8.0), "speed": 2.0, "angle": 0.0, "angle_stick_aim": false,
	"aim_frames": 6, "steer_max_angle": 30.0, "gravity": 0.0, "bounce": "none", "bounce_count": 0,
	"lifetime": 90, "max_range": 0.0, "size": 3.0, "count": 1, "spread_angle": 0.0,
	"max_alive": 2, "on_cap": "block", "pierce": 0, "multi_hits": 1, "multi_interval": 8,
	"damage": 4.0, "kb_angle": 361.0, "kb_base": 10.0, "kb_scale": 50.0, "is_transcendent": false,
	"reflectable": true, "absorbable": true, "hitlag_mult": 0.75, "follows_owner": false,
	"orbit_radius": 12.0, "orbit_speed": 6.0, "spawn_blocked": "fizzle", "on_shield": "vanish",
}

var aim_angle: float = 0.0
## Projectielen van deze uitvoering (tests).
var spawned: Array[SpecialProjectile] = []


func defaults() -> Dictionary:
	return DEFAULTS


func can_start() -> bool:
	if ps("on_cap", "block") != "block":
		return true
	var max_alive: int = pi_("max_alive", 2)
	return world.alive_of(f, slot, "projectile").size() < max_alive


func start() -> void:
	aim_angle = pf("angle", 0.0)
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if pb("angle_stick_aim") and phase_frame <= pi_("aim_frames", 6):
				aim_angle = SpecialAim.steer_angle(f.stick(), f.facing, pf("angle", 0.0), pf("steer_max_angle", 30.0))
			if phase_frame >= startup_frames():
				set_phase("active")
				spawn_projectiles()
		"active":
			set_phase("end")
		"end":
			if phase_frame >= endlag_frames():
				finish()


func spawn_projectiles() -> void:
	var count: int = clampi(pi_("count", 1), 1, 5)
	var spread: float = pf("spread_angle", 0.0)
	var max_alive: int = pi_("max_alive", 2)
	var live: Array[SpecialEntity] = world.alive_of(f, slot, "projectile")
	for i in count:
		if live.size() >= max_alive:
			if ps("on_cap", "block") == "replace" and not live.is_empty():
				live[0].kill("replaced")
				live.remove_at(0)
			else:
				break
		var a: float = aim_angle
		if count > 1:
			a += spread * (float(i) / float(count - 1) - 0.5)
		var pr: SpecialProjectile = make_projectile(a)
		if pr == null:
			continue
		world.spawn(pr)
		live.append(pr)
		spawned.append(pr)


## Bouwt één projectiel (nog niet gespawnd). null als de spawn geblokkeerd is (fizzle).
func make_projectile(angle_deg: float) -> SpecialProjectile:
	var off: Vector2 = p("spawn_offset", Vector2(8.0, 8.0))
	var at: Vector2 = f.pos + Vector2(off.x * f.facing, off.y)
	var segs: Array = world.segs if not world.segs.is_empty() else SpecialGeometry.segments(f.stage)
	if SpecialGeometry.inside_solid(segs, at):
		if ps("spawn_blocked", "fizzle") == "fizzle":
			return null
		at = SpecialGeometry.resolve_target(segs, f.pos + Vector2(0.0, off.y), at, "snap_to_valid")["pos"]
	var pr := SpecialProjectile.new()
	pr.setup_entity(world, f, slot)
	pr.pos = at
	pr.facing = f.facing
	pr.vel = SpecialAim.dir_from_angle(angle_deg, f.facing) * pf("speed", 2.0) * speed_mult
	pr.gravity = pf("gravity", 0.0)
	pr.bounce = ps("bounce", "none")
	pr.bounces_left = pi_("bounce_count", 0)
	pr.lifetime = pi_("lifetime", 90)
	pr.max_range = pf("max_range", 0.0)
	pr.pierce = pi_("pierce", 0)
	pr.multi_hits = maxi(pi_("multi_hits", 1), 1)
	pr.multi_interval = maxi(pi_("multi_interval", 8), 1)
	pr.transcendent = pb("is_transcendent")
	pr.reflectable = pb("reflectable", true)
	pr.absorbable = pb("absorbable", true)
	pr.on_shield_mode = ps("on_shield", "vanish")
	pr.follows_owner = pb("follows_owner")
	pr.orbit_radius = pf("orbit_radius", 12.0)
	pr.orbit_speed = pf("orbit_speed", 6.0)
	pr.lands_on_platforms = pr.gravity > 0.0 and pr.bounce != "none"
	pr.damage_mult = damage_mult
	pr.draw_radius = pf("size", 3.0) * size_mult
	var src: Array[HitboxData] = hits_or_default("projectile", "", 0, -1, Vector2.ZERO, pf("size", 3.0),
		pf("damage", 4.0), pf("kb_angle", 361.0), pf("kb_base", 10.0), pf("kb_scale", 50.0))
	for h: HitboxData in src:
		var c: HitboxData = scaled(h)
		if not def.has_hits("projectile"):
			c = c.duplicate() as HitboxData
			c.hitlag_mult = pf("hitlag_mult", 0.75)
			c.clank = false
		pr.hit_list.append(c)
	return pr


func pose_timing() -> Array:
	var su: int = startup_frames()
	return [su, 1, su + 1 + endlag_frames()]


func pose_frame() -> int:
	return frame


func default_pose() -> String:
	return "atk_special_projectile"
