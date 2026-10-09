class_name TplSpin
extends SpecialMove
## Sjabloon `spin` (§16): startup -> spin (multi-hit rondom om de `hit_every` frames, elke hit eigen groep;
## optioneel h_speed via stick en rise_speed) -> ender (rol "ender") -> endlag (helpless in de lucht als
## def.helpless_after). Rollen: "spin" (één patroon, per hit herhaald), "ender". pull_in: hits trekken naar het
## midden. hold_extend: B opnieuw tijdens de spin verlengt met een halve loop (max N keer). Grond <-> lucht
## wisselt zonder af te breken.

const DEFAULTS: Dictionary = {
	"startup": 6, "spin_frames": 30, "hit_every": 5, "radius": 8.0, "h_speed": 1.0, "rise_speed": 0.0,
	"pull_in": true, "spin_damage": 1.5, "spin_kb_base": 15.0, "spin_kb_scale": 0.0, "ender_frames": 4,
	"ender_damage": 6.0, "ender_kb_angle": 50.0, "ender_kb_base": 45.0, "ender_kb_scale": 90.0, "ender_size": 9.0,
	"hold_extend": 0, "endlag": 22, "ground_slide_friction": 0.08, "gravity_scale": 0.5, "stick_control": "x_only",
	"momentum_air": "scale", "momentum_scale": 0.5,
}

var extra_frames: int = 0
var extends_used: int = 0


func defaults() -> Dictionary:
	return DEFAULTS


func spin_frames() -> int:
	return maxi(pi_("spin_frames", 30), 1) + extra_frames


func start() -> void:
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				set_phase("spin")
		"spin":
			if phase_frame >= spin_frames():
				set_phase("ender")
		"ender":
			if phase_frame >= pi_("ender_frames", 4):
				set_phase("end")
		"end":
			if phase_frame >= endlag_frames():
				finish()


func input() -> void:
	if phase == "spin" and extends_used < pi_("hold_extend", 0) and f.input.pressed(InputFrame.BTN_SPECIAL):
		extends_used += 1
		extra_frames += maxi(pi_("spin_frames", 30) / 2, 1)


func phys() -> void:
	if phase == "spin":
		var hs: float = pf("h_speed", 1.0)
		var sc: String = ps("stick_control", "x_only")
		var tx: float = f.stick_x() * hs if sc != "none" else 0.0
		if f.grounded:
			f.gr_vel = move_toward(f.gr_vel, tx, pf("ground_slide_friction", 0.08) + 0.05)
			var rs0: float = pf("rise_speed", 0.0)
			if rs0 > 0.0:
				f.leave_ground(Vector2(f.gr_vel, rs0))
		else:
			f.vel.x = move_toward(f.vel.x, tx, 0.08)
			var rs: float = pf("rise_speed", 0.0)
			if rs > 0.0:
				f.vel.y = rs
			else:
				apply_gravity()
		return
	super.phys()


func wants_off_edge() -> bool:
	return phase == "spin"


func on_land() -> void:
	if phase == "spin" or phase == "startup":
		return
	super.on_land()


func hitboxes() -> Array[ActiveHitbox]:
	var h: float = f.stats.visual_height
	var r: float = pf("radius", 8.0)
	match phase:
		"spin":
			var every: int = maxi(pi_("hit_every", 5), 1)
			if phase_frame % every != 0:
				return []
			var group: int = phase_frame / every + 1
			var src: Array[HitboxData] = def.hits("spin")
			if src.is_empty():
				var pull: bool = pb("pull_in", true)
				var dmg: float = pf("spin_damage", 1.5)
				var bkb: float = pf("spin_kb_base", 15.0)
				var kbg: float = pf("spin_kb_scale", 0.0)
				src = [
					make_hit(0, 0, -1, Vector2(r * 0.6, h * 0.5), r * 0.7, dmg, 160.0 if pull else 40.0, bkb, kbg),
					make_hit(1, 0, -1, Vector2(-r * 0.6, h * 0.5), r * 0.7, dmg, 20.0 if pull else 140.0, bkb, kbg),
				]
			var out: Array[ActiveHitbox] = boxes(src, 0)
			for a: ActiveHitbox in out:
				var c: HitboxData = a.data.duplicate() as HitboxData
				c.group = group
				a.data = c
			return out
		"ender":
			var en: Array[HitboxData] = hits_or_default("ender", "ender_", 0, -1, Vector2(0.0, h * 0.5), r * 1.1, 6.0,
				50.0, 45.0, 90.0)
			var o2: Array[ActiveHitbox] = boxes(en, phase_frame)
			for a2: ActiveHitbox in o2:
				var c2: HitboxData = a2.data.duplicate() as HitboxData
				c2.group = 999
				a2.data = c2
			return o2
	return []


func default_pose() -> String:
	return "atk_special_spin"
