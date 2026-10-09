class_name TplReflector
extends SpecialMove
## Sjabloon `reflector` (§6): startup -> reflect (reflect-box actief; SpecialWorld kaatst reflecteerbare
## projectielen terug: richting om, eigenaar wisselt, damage × damage_mult, snelheid × speed_mult, lifetime reset,
## max `reflect_limit` keer per projectiel) -> endlag. Optioneel melee-push: rol "push" (frames relatief aan reflect).
## Geen hurtbox-bescherming tegen melee tenzij armor/intangible is gezet.

const DEFAULTS: Dictionary = {
	"startup": 4, "reflect_frames": 20, "endlag": 18, "reflect_radius": 11.0, "reflect_offset": Vector2(5.0, 8.0),
	"damage_mult": 1.5, "speed_mult": 1.0, "reflect_limit": 3, "facing": "both", "gravity_scale": 0.8,
	"momentum_air": "scale", "momentum_scale": 0.5,
}

var reflected: int = 0


func defaults() -> Dictionary:
	return DEFAULTS


func start() -> void:
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				set_phase("reflect")
		"reflect":
			if phase_frame >= maxi(pi_("reflect_frames", 20), 1):
				set_phase("end")
		"end":
			if phase_frame >= endlag_frames():
				finish()


func reflect_box() -> Dictionary:
	if phase != "reflect":
		return {}
	var off: Vector2 = p("reflect_offset", Vector2(5.0, 8.0))
	return {"center": f.pos + Vector2(off.x * f.facing, off.y), "radius": pf("reflect_radius", 11.0),
		"damage_mult": pf("damage_mult", 1.5), "speed_mult": pf("speed_mult", 1.0),
		"limit": pi_("reflect_limit", 3), "facing": ps("facing", "both")}


func on_reflect(_e: SpecialEntity) -> void:
	reflected += 1


func hitboxes() -> Array[ActiveHitbox]:
	if phase == "reflect":
		return role_boxes("push", phase_frame)
	return []


func default_pose() -> String:
	return "atk_special_counter"
