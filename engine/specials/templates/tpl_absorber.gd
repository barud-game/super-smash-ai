class_name TplAbsorber
extends SpecialMove
## Sjabloon `absorber` (§12): startup -> absorb (absorb-box: SpecialWorld neemt absorbeerbare projectielen op en
## roept on_absorb) -> endlag. gain: "heal" (percent omlaag, max per gebruik en per stock), "charge" (vult de
## bewaarde charge van `charge_slot`), "buff" (tijdelijke modifiers). Geen melee-bescherming tenzij armor.

const DEFAULTS: Dictionary = {
	"startup": 6, "absorb_frames": 24, "endlag": 20, "absorb_radius": 11.0, "absorb_offset": Vector2(4.0, 8.0),
	"gain": "heal", "gain_mult": 1.0, "max_heal_per_use": 15.0, "heal_cap_per_stock": 40.0, "max_absorbs": 3,
	"charge_slot": "neutral", "charge_gain": 0.34, "buff_modifiers": {}, "buff_duration": 300,
	"facing": "both", "gravity_scale": 1.0,
}

var absorbed: int = 0
var healed: float = 0.0


func defaults() -> Dictionary:
	return DEFAULTS


func start() -> void:
	set_phase("startup")


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				set_phase("absorb")
		"absorb":
			if phase_frame >= maxi(pi_("absorb_frames", 24), 1):
				set_phase("end")
		"end":
			if phase_frame >= endlag_frames():
				finish()


func absorb_box() -> Dictionary:
	if phase != "absorb" or absorbed >= pi_("max_absorbs", 3):
		return {}
	var off: Vector2 = p("absorb_offset", Vector2(4.0, 8.0))
	return {"center": f.pos + Vector2(off.x * f.facing, off.y), "radius": pf("absorb_radius", 11.0),
		"facing": ps("facing", "both")}


func on_absorb(e: SpecialEntity) -> bool:
	if absorbed >= pi_("max_absorbs", 3):
		return false
	absorbed += 1
	var amount: float = e.clank_damage() * pf("gain_mult", 1.0)
	match ps("gain", "heal"):
		"heal":
			var room_use: float = maxf(pf("max_heal_per_use", 15.0) - healed, 0.0)
			var room_stock: float = maxf(pf("heal_cap_per_stock", 40.0) - kit.healed_this_stock, 0.0)
			var h: float = minf(minf(amount, room_use), minf(room_stock, f.percent))
			healed += h
			kit.healed_this_stock += h
			f.set_percent(f.percent - h)
		"charge":
			var cs: String = ps("charge_slot", "neutral")
			kit.store_charge(cs, minf(kit.peek_charge(cs) + pf("charge_gain", 0.34), 1.0), -1)
		"buff":
			kit.add_buff(slot, p("buff_modifiers", {}), pi_("buff_duration", 300), false, "refresh")
	present("absorb")
	return true


func default_pose() -> String:
	return "atk_special_counter"
