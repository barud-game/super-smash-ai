class_name TplRisingMulti
extends SpecialMove
## Sjabloon `rising_multi` (§4): startup -> rise (velocity-profiel, multi-hit om de `interval` frames, elke hit
## een eigen groep) -> finisher -> endlag -> helpless. Rollen: "multi" (één hit-patroon; wordt per hit herhaald
## met groep i+1), "finisher" (frames relatief aan de finisher-fase). Plafond: stijgen stopt onder een solide blok.

const DEFAULTS: Dictionary = {
	"startup": 5, "rise_frames": 24, "rise_speed": 2.6, "rise_curve": "decel", "rise_angle": 70.0,
	"h_control": "x_only", "h_speed_max": 0.8, "hits": 5, "interval": 4, "multi_damage": 2.0,
	"multi_kb_angle": 90.0, "multi_kb_base": 20.0, "multi_kb_scale": 0.0, "multi_size": 6.0,
	"finisher_frames": 3, "finisher_damage": 7.0, "finisher_kb_angle": 75.0, "finisher_kb_base": 40.0,
	"finisher_kb_scale": 90.0, "finisher_size": 7.0, "momentum_end": "keep_vertical", "endlag": 24,
	"momentum_air": "zero", "ceiling_policy": "stop_rise",
}

var rise_dir: Vector2 = Vector2(0.0, 1.0)


func defaults() -> Dictionary:
	return DEFAULTS


func rise_frames() -> int:
	return maxi(pi_("rise_frames", 24), 1)


## Snelheid per frame (u/f): `rise_speed`, of `rise_distance / rise_frames` als die gezet is.
func base_speed() -> float:
	var d: float = pf("rise_distance", 0.0)
	return d / float(rise_frames()) if d > 0.0 else pf("rise_speed", 2.6)


## Profielfactor (gemiddeld ~1 over de rise, zodat afstand ≈ snelheid × frames).
func curve(t: float) -> float:
	match ps("rise_curve", "decel"):
		"decel":
			return 2.0 * (1.0 - t)
		"accel":
			return 2.0 * t
		"burst_then_float":
			return 2.2 if t < 0.3 else 0.4857
	return 1.0


func start() -> void:
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				_aim()
				set_phase("rise")
		"rise":
			if phase_frame >= rise_frames():
				if ps("momentum_end", "keep_vertical") == "zero":
					f.vel = Vector2.ZERO
				set_phase("finisher")
		"finisher":
			if phase_frame >= pi_("finisher_frames", 3):
				set_phase("end")
		"end":
			if phase_frame >= endlag_frames():
				finish()


## Rise-hoek: `rise_angle` (60–90) is de laagste elevatie; de stick kiest binnen [rise_angle, 180 − rise_angle].
func _aim() -> void:
	var min_el: float = clampf(pf("rise_angle", 70.0), 0.0, 90.0)
	var sx: float = f.stick_x() * f.facing
	if ps("h_control", "x_only") == "none":
		sx = 0.0
	var el: float = 90.0 - sx * (90.0 - min_el)
	rise_dir = SpecialAim.dir_from_angle(el, f.facing)


func phys() -> void:
	if phase == "rise":
		var t: float = float(phase_frame) / float(rise_frames())
		var v: Vector2 = rise_dir * base_speed() * curve(t) * speed_mult
		if ps("h_control", "x_only") == "full":
			v.x += f.stick_x() * pf("h_speed_max", 0.8)
		if _ceiling_blocked(v):
			v.y = minf(v.y, 0.0)
		set_velocity(v)
		return
	if phase == "startup" and not f.grounded:
		f.vel *= 0.8
		return
	super.phys()


func _ceiling_blocked(v: Vector2) -> bool:
	if ps("ceiling_policy", "stop_rise") != "stop_rise" or v.y <= 0.0:
		return false
	var head: Vector2 = f.pos + v + Vector2(0.0, f.stats.visual_height)
	return SpecialGeometry.inside_solid(SpecialGeometry.segments(f.stage), head) \
		and not SpecialGeometry.inside_solid(SpecialGeometry.segments(f.stage), f.pos + Vector2(0.0, 0.5))


func on_land() -> void:
	if phase == "rise" and f.vel.y > 0.0:
		return
	super.on_land()


func hitboxes() -> Array[ActiveHitbox]:
	var h: float = f.stats.visual_height
	match phase:
		"rise":
			var hits: int = maxi(pi_("hits", 5), 1)
			var interval: int = maxi(pi_("interval", 4), 1)
			var k: int = phase_frame / interval
			if k >= hits or phase_frame % interval != 0:
				return []
			var src: Array[HitboxData] = hits_or_default("multi", "multi_", 0, -1, Vector2(0.0, h * 0.5), 6.0, 2.0,
				90.0, 20.0, 0.0)
			return _with_group(src, k + 1)
		"finisher":
			var fin: Array[HitboxData] = hits_or_default("finisher", "finisher_", 0, -1, Vector2(0.0, h * 0.7), 7.0,
				7.0, 75.0, 40.0, 90.0)
			return _with_group(fin, 100, phase_frame)
	return []


## Hitboxes met een vaste groep (elke multi-hit raakt opnieuw). Frames: rol-frames t.o.v. `t` (standaard 0).
func _with_group(src: Array[HitboxData], group: int, t: int = 0) -> Array[ActiveHitbox]:
	var out: Array[ActiveHitbox] = boxes(src, t)
	for a: ActiveHitbox in out:
		if a.data.group != group:
			var c: HitboxData = a.data.duplicate() as HitboxData
			c.group = group
			a.data = c
	return out


func default_pose() -> String:
	return "atk_special_rise"


func fallback_pose() -> String:
	return "jump_aerial"
