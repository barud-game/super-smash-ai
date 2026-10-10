extends TplRisingMulti
## Up-B "Grabby Hands": rising_multi + command_grab als één geïntegreerde move. Pep schiet omhoog met een grab-box
## voor/boven zich (negeert shield, grond en lucht). Raakt die: het slachtoffer wordt vastgehouden (SpecialHeld,
## `hold_frames`), Pep hangt stil en laat hem dan ontploffen in een paarse vonkenwolk (directe treffer, rol
## "explosion", element DARK = paars). Mist de grab: normaal einde en helpless (helpless_on_miss_only: na een
## geslaagde grab niet helpless). De sjablonen-sequentie (rising -> grab) wordt uitgezet (chain_mode "none"):
## de grab-instellingen staan in linked_params van de .tres en worden hier gelezen.
## VFX: def.vfx["burst"] via het toolkit-hook (spawn_special_fx); bestaat die nog niet, dan een bestaande
## VfxLayer.spawn_hit met EL_DARK op de plek van het slachtoffer.

var victim: Fighter = null
var grabbed: bool = false


func chain_mode() -> String:
	return "none"


## Instelling van het grab-deel (linked_params, valt terug op params).
func lp(key: String, default: Variant) -> Variant:
	return def.get_param(key, started_air, default, true)


func hold_frames() -> int:
	return int(lp("hold_frames", 12))


func step() -> void:
	match phase:
		"rise":
			if phase_frame >= rise_frames():
				set_phase("end")
			return
		"hold":
			if victim == null or not is_instance_valid(victim) or victim.state_name() != "SpecialHeld":
				victim = null
				set_phase("end")
				return
			if phase_frame >= hold_frames():
				_explode()
			return
		"burst":
			if phase_frame >= int(lp("burst_frames", 8)):
				set_phase("end")
			return
	super.step()


func phys() -> void:
	if phase == "hold" or phase == "burst":
		if f.grounded:
			f.apply_ground_friction()
		else:
			f.vel = Vector2.ZERO
		return
	super.phys()


func grab_box() -> Dictionary:
	if phase != "rise" or grabbed:
		return {}
	var off: Vector2 = lp("grab_offset", Vector2(5.0, 12.0))
	return {"center": f.pos + Vector2(off.x * f.facing, off.y), "radius": float(lp("grab_radius", 7.0)) * size_mult,
		"grab_type": "both", "grab_ledge": false}


func on_grab(v: Fighter) -> void:
	if grabbed:
		return
	grabbed = true
	victim = v
	hit_landed = true
	v.change_state("SpecialHeld", {"holder": f, "offset": lp("hold_offset", Vector2(7.0, 6.0)), "breakout": 0,
		"max_frames": hold_frames() + 30})
	set_phase("hold")


func on_grab_clank() -> void:
	set_phase("end")


func _explode() -> void:
	var src: Array[HitboxData] = def.hits("explosion")
	var v: Fighter = victim
	victim = null
	set_phase("burst")
	if src.is_empty() or v == null:
		return
	var at: Vector2 = v.pos + Vector2(0.0, v.stats.visual_height * 0.5)
	SpecialMove.apply_direct_hit(f, v, scaled(src[0]), src[0].damage * damage_mult)
	var layer: Node = f.get_vfx()
	if layer != null and not layer.has_method("spawn_special_fx") and layer.has_method("spawn_hit"):
		layer.spawn_hit(at, 1.0, VfxConst.EL_DARK, 70.0, false, 12.0)


func hitboxes() -> Array[ActiveHitbox]:
	return []


func on_exit() -> void:
	super.on_exit()
	if victim != null and is_instance_valid(victim) and victim.state_name() == "SpecialHeld":
		(victim.state as StateSpecialHeld).release()
	victim = null


func default_pose() -> String:
	match phase:
		"hold":
			return "atk_grab_hold"
		"burst":
			return "atk_fthrow"
	return "atk_special_rise"
