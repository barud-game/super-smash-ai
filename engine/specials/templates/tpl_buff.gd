class_name TplBuff
extends SpecialMove
## Sjabloon `buff` (§14): startup (telegraaf) -> transform (optioneel intangible) -> buff actief in SpecialKit
## (stat-modifiers base -> archetype -> buff, duur, until_hit, stack_rule, move_swap) -> endlag.
## toggle: dezelfde special met een actieve buff zet hem uit (modus-wissel). Buff vervalt bij dood.
## Modifiers: zie SpecialKit.STAT_FIELDS (stats) en damage_dealt_mult / kb_dealt_mult (specials; zie docs).

const DEFAULTS: Dictionary = {
	"startup": 16, "transform_frames": 8, "transform_intangible": false, "duration": 600, "until_hit": false,
	"modifiers": {}, "move_swap": {}, "stack_rule": "refresh", "stack_max": 2, "cooldown": 0, "endlag": 14,
	"toggle": false,
}

var applied: bool = false
var toggled_off: bool = false


func defaults() -> Dictionary:
	return DEFAULTS


func can_start() -> bool:
	if ps("stack_rule", "refresh") == "block" and kit.has_buff(slot) and not pb("toggle"):
		return false
	return true


func start() -> void:
	set_phase("startup")
	telegraph()


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				set_phase("transform")
		"transform":
			if phase_frame >= maxi(pi_("transform_frames", 8), 1):
				_apply()
				set_phase("end")
		"end":
			if phase_frame >= endlag_frames():
				finish()


func _apply() -> void:
	if pb("toggle") and kit.has_buff(slot):
		kit.remove_buff(slot)
		toggled_off = true
		return
	applied = kit.add_buff(slot, p("modifiers", {}), pi_("duration", 600), pb("until_hit"), ps("stack_rule", "refresh"),
		pi_("stack_max", 2), p("move_swap", {}))
	telegraph()
	var cd: int = pi_("cooldown", 0)
	if cd > 0:
		kit.cooldowns[slot] = cd


func intangible() -> bool:
	return super.intangible() or (phase == "transform" and pb("transform_intangible"))


func default_pose() -> String:
	return "atk_special_charge"
