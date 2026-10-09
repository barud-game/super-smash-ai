class_name TplCommandDash
extends SpecialMove
## Sjabloon `command_dash` (§15): startup -> move (dash/hop/slide/backstep; optioneel intangible) -> window
## (follow-up-keuze met input-buffer; bevriest in hitlag) -> follow-up of endlag.
## follow_ups: lijst {"input": "attack"/"special"/"grab"/"jump"/"shield", "role": <hit-rol>, "total": frames}.
##   - hit-rol: mini-move met hitboxes (frames relatief aan de follow-up), daarna klaar
##   - "special": templates[1] als die er is (bv. command_grab), anders deze special opnieuw (chain_limit)
##   - "jump"/"shield": cancel (KneeBend/JumpAerial, Guard/Wait/EscapeAir)
## Geen input: default_follow_up (rol of "none") -> endlag.

const DEFAULTS: Dictionary = {
	"startup": 6, "move_kind": "dash", "distance": 80.0, "move_frames": 12, "direction": "forward",
	"hop_speed": 1.6, "follow_ups": [{"input": "attack", "role": "follow_attack", "total": 26}], "window": 12,
	"input_buffer": 4, "default_follow_up": "none", "invincible": false, "chain_limit": 1, "endlag": 18,
	"cliff_stop": true, "gravity_scale": 0.6, "follow_attack_damage": 9.0, "follow_attack_kb_angle": 40.0,
	"follow_attack_kb_base": 40.0, "follow_attack_kb_scale": 80.0, "follow_attack_size": 6.0,
}

const INPUT_BUTTONS: Dictionary = {
	"attack": InputFrame.BTN_ATTACK, "special": InputFrame.BTN_SPECIAL, "grab": InputFrame.BTN_Z,
	"jump": InputFrame.BTN_JUMP, "shield": InputFrame.BTN_SHIELD,
}

var move_dir: int = 1
var chain_count: int = 1
var follow: Dictionary = {}


func defaults() -> Dictionary:
	return DEFAULTS


func chain_mode() -> String:
	return "follow_up"


func start() -> void:
	set_phase("startup")


func move_frames() -> int:
	return maxi(pi_("move_frames", 12), 1)


func step() -> void:
	match phase:
		"startup":
			if phase_frame >= startup_frames():
				var dmode: String = ps("direction", "forward")
				move_dir = f.facing
				if dmode == "back" or ps("move_kind", "dash") == "backstep":
					move_dir = -f.facing
				elif dmode == "stick" and absf(f.stick_x()) >= SpecialAim.AIM_DEADZONE:
					move_dir = 1 if f.stick_x() > 0.0 else -1
				if ps("move_kind", "dash") == "hop":
					set_velocity(Vector2(move_dir * _speed(), pf("hop_speed", 1.6)))
				set_phase("move")
		"move":
			if phase_frame >= move_frames():
				if ps("move_kind", "dash") != "slide":
					if f.grounded:
						f.gr_vel = 0.0
					else:
						f.vel.x = 0.0
				if ps("move_kind", "dash") == "backstep":
					f.facing = -f.facing
				set_phase("window")
				_check_follow_up(true)
		"window":
			if phase_frame >= maxi(pi_("window", 12), 1):
				var dflt: String = ps("default_follow_up", "none")
				if dflt != "none":
					_start_follow({"input": "", "role": dflt, "total": 24})
				else:
					set_phase("end")
		"follow":
			if phase_frame >= int(follow.get("total", 24)):
				finish()
		"end":
			if phase_frame >= endlag_frames():
				finish()


func _speed() -> float:
	return pf("distance", 80.0) / float(move_frames()) * speed_mult


func input() -> void:
	if phase == "window":
		_check_follow_up(false)


## Follow-up-keuze. `buffered`: ook drukken binnen input_buffer frames vóór het venster tellen.
func _check_follow_up(buffered: bool) -> void:
	var list: Array = p("follow_ups", [])
	var back: int = pi_("input_buffer", 4) if buffered else 0
	for fu: Variant in list:
		if not (fu is Dictionary):
			continue
		var btn: int = int(INPUT_BUTTONS.get(String(fu.get("input", "")), 0))
		if btn != 0 and _pressed_within(btn, back):
			_start_follow(fu)
			return


func _pressed_within(btn: int, back: int) -> bool:
	for i in range(back + 1):
		var cur: InputFrame = f.input.get_frame(i)
		var prev: InputFrame = f.input.get_frame(i + 1)
		if cur.has(btn) and not prev.has(btn):
			return true
	return false


func _start_follow(fu: Dictionary) -> void:
	var inp: String = String(fu.get("input", ""))
	match inp:
		"jump":
			done = true
			if f.grounded:
				f.change_state("KneeBend", {"tap": false})
			elif f.air_jumps_used < f.stats.air_jumps:
				f.change_state("JumpAerial")
			else:
				done = false
				return
			return
		"shield":
			done = true
			if f.grounded:
				f.change_state("Guard" if f.has_state("Guard") else "Wait")
			else:
				f.change_state("EscapeAir")
			return
		"special":
			if def.linked_template() != "" and not linked:
				start_linked(charge_ratio)
				return
			if chain_count < pi_("chain_limit", 1):
				var nxt: SpecialMove = Specials.make_runner(def, f, 0)
				if nxt is TplCommandDash:
					(nxt as TplCommandDash).chain_count = chain_count + 1
					host.swap(nxt, self)
				return
			return
	follow = fu
	f.start_move()
	set_phase("follow")


func phys() -> void:
	if phase == "move":
		var kind: String = ps("move_kind", "dash")
		if kind == "hop" and not f.grounded:
			apply_gravity()
			return
		if f.grounded:
			f.gr_vel = move_dir * _speed()
		else:
			f.vel = Vector2(move_dir * _speed(), maxf(f.vel.y - f.stats.gravity * gravity_scale, -1.0))
		return
	super.phys()


func wants_off_edge() -> bool:
	return not pb("cliff_stop", true)


func on_land() -> void:
	if phase == "move" or phase == "startup":
		return
	super.on_land()


func intangible() -> bool:
	return super.intangible() or (phase == "move" and pb("invincible"))


func is_end_phase() -> bool:
	return phase == "end" or phase == "window"


func hitboxes() -> Array[ActiveHitbox]:
	match phase:
		"move":
			return role_boxes("move", phase_frame)
		"follow":
			var role: String = String(follow.get("role", "follow_attack"))
			var h: float = f.stats.visual_height
			var src: Array[HitboxData] = def.hits(role)
			if src.is_empty() and role == "follow_attack":
				src = hits_or_default("follow_attack", "follow_attack_", 6, 9, Vector2(7.0, h * 0.5), 6.0, 9.0,
					40.0, 40.0, 80.0)
			return boxes(src, phase_frame)
	return []


func default_pose() -> String:
	match phase:
		"follow":
			return "atk_ftilt"
	return "atk_special_dash"
