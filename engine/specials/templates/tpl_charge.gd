class_name TplCharge
extends SpecialMove
## Sjabloon `charge` (§2): startup -> charge-loop (knop vast) -> release. Bij release neemt templates[1]
## het over met de lading (set_charge: scale_damage/scale_kb/scale_size/scale_speed). Zonder gekoppeld sjabloon:
## eigen release-hit (rol "release", frames relatief aan de release-fase) + endlag.
## Bewaren (charge_keep): shield/jump-cancel of geraakt worden (on_hit "keep") slaat de lading op in de kit;
## de volgende keer begint de charge daar (vol = direct vuren na de startup). Telegraaf verplicht.

const DEFAULTS: Dictionary = {
	"startup": 8, "charge_min": 0, "charge_max": 60, "hold_cancel": "shield", "charge_keep": false,
	"keep_frames": -1, "auto_release": false, "on_hit": "lose", "charge_move": "none", "release_on": "release",
	"charge_continues_on_land": true, "momentum_air": "scale", "momentum_scale": 0.3, "gravity_scale": 0.5,
	"endlag": 20, "release_startup": 4,
}

var charge_frames: int = 0
var released: bool = false
var _stage_sig: int = -1
var _cancel_to: String = ""


func defaults() -> Dictionary:
	return DEFAULTS


func chain_mode() -> String:
	return "release"


func start() -> void:
	var stored: float = kit.take_charge(slot) if kit != null else 0.0
	charge_frames = int(roundf(stored * float(charge_max())))
	set_phase("startup")
	telegraph()


func charge_max() -> int:
	return maxi(pi_("charge_max", 60), 1)


func ratio() -> float:
	var n: int = maxi(charge_frames, pi_("charge_min", 0))
	return clampf(float(n) / float(charge_max()), 0.0, 1.0)


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				if charge_frames >= charge_max():
					release()
				else:
					set_phase("charge")
		"charge":
			if charge_frames < charge_max():
				charge_frames += 1
			_signal_stage()
			if charge_frames >= charge_max() and pb("auto_release"):
				release()
		"release":
			var hits: Array[HitboxData] = def.hits("release")
			var last: int = pi_("release_startup", 4) + 2
			for h: HitboxData in hits:
				last = maxi(last, h.end_frame)
			if phase_frame > last + endlag_frames():
				finish()


## Zichtbaar/hoorbaar niveau (verplichte telegraaf): bij elke nieuwe kwart-lading en bij vol.
func _signal_stage() -> void:
	var stages: int = maxi(int(def.get_param("charge_stages", false, 4)), 1)
	var s: int = int(floorf(ratio() * float(stages) + 0.0001))
	if s != _stage_sig:
		_stage_sig = s
		telegraph()


func input() -> void:
	if phase != "charge" and phase != "startup":
		return
	var hc: String = ps("hold_cancel", "shield")
	if (hc == "shield" or hc == "both") and f.input.pressed(InputFrame.BTN_SHIELD):
		_cancel("shield")
		return
	if (hc == "jump" or hc == "both") and f.jump_source() != 0:
		_cancel("jump")
		return
	if phase != "charge":
		return
	var rel: bool
	if ps("release_on", "release") == "press":
		rel = f.input.pressed(InputFrame.BTN_SPECIAL)
	else:
		rel = not f.input.held(InputFrame.BTN_SPECIAL)
	if rel:
		release()


func _cancel(kind: String) -> void:
	if pb("charge_keep"):
		kit.store_charge(slot, ratio(), pi_("keep_frames", -1))
	done = true
	if kind == "jump":
		if f.grounded:
			if f.jump_source() == 2:
				f.consume_tap_jump()
			f.change_state("KneeBend", {"tap": false})
		elif f.air_jumps_used < f.stats.air_jumps:
			f.change_state("JumpAerial")
		else:
			f.change_state("Fall")
		return
	if f.grounded:
		f.change_state("Guard" if f.has_state("Guard") else "Wait")
	else:
		f.change_state("Fall")


func release() -> void:
	if released:
		return
	released = true
	present("release")
	if def.linked_template() != "" and not linked:
		start_linked(ratio())
		return
	set_charge(ratio())
	f.start_move()
	set_phase("release")


func phys() -> void:
	if phase == "charge" and f.grounded:
		match ps("charge_move", "none"):
			"walk":
				f.apply_walk(f.stick_x() * 0.5)
			_:
				f.apply_ground_friction()
		return
	if phase == "charge" and not f.grounded and ps("charge_move", "none") == "drift":
		apply_gravity()
		f.apply_air_drift(f.stick_x(), 0.5)
		return
	super.phys()


func on_land() -> void:
	if phase == "charge" or phase == "startup":
		if pb("charge_continues_on_land", true):
			return
		_cancel("land")
		return
	super.on_land()


func wants_off_edge() -> bool:
	return false


func on_exit() -> void:
	super.on_exit()
	if interrupted and not released and pb("charge_keep") and ps("on_hit", "lose") == "keep":
		kit.store_charge(slot, ratio(), pi_("keep_frames", -1))


## Charge-armor (optioneel): {"max_damage": x, "min_ratio": r} geldt tijdens de charge-loop vanaf lading r.
func armor_active() -> bool:
	if super.armor_active():
		return true
	var ca: Variant = p("charge_armor", {})
	if not (ca is Dictionary) or (ca as Dictionary).is_empty() or armor_broken:
		return false
	return phase == "charge" and ratio() >= float((ca as Dictionary).get("min_ratio", 0.0))


func intercept(ev: HitEvent, source: Object) -> String:
	var ca: Variant = p("charge_armor", {})
	if not super.armor_active() and ca is Dictionary and not (ca as Dictionary).is_empty() and armor_active():
		if ev.damage <= float((ca as Dictionary).get("max_damage", 8.0)) + 0.0001:
			f.set_percent(minf(f.percent + ev.damage, Fighter.MAX_PERCENT))
			f.hitlag_frames = maxi(f.hitlag_frames, ev.defender_hitlag)
			f.hitlag_victim = false
			return "armor"
		armor_broken = true
		return "armor_break"
	return super.intercept(ev, source)


func hitboxes() -> Array[ActiveHitbox]:
	if phase == "release":
		return role_boxes("release", phase_frame)
	return []


func default_pose() -> String:
	return "atk_special_release" if phase == "release" else "atk_special_charge"


func debug_text() -> String:
	return "charge:%s %d/%d" % [phase, charge_frames, charge_max()]
