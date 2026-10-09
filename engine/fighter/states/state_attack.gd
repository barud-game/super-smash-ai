class_name StateAttack
extends FighterState
## Attack: generieke grondaanval, volledig gestuurd door MoveData (jab, tilts, dash attack, smashes).
## args: move (naam in Fighter.moves), facing (optioneel, draait om), charge (smash: A wordt vastgehouden).
## - move-frame = state_frame − charge-frames (0-based, = HitboxData.start_frame/end_frame).
## - Smash charge: op move-frame SMASH_CHARGE_FRAME blijft de move staan zolang A vast is (max 60 frames);
##   damage × (1 + 0.3671 · charge/60).
## - Jab-combo: A opnieuw tijdens jab N zet jab N+1 klaar (als die move bestaat); start na de laatste actieve frame.
## - IASA: vanaf MoveData.iasa_frame() Wait-interrupts (incl. een nieuwe aanval); einde -> Wait (dtilt: SquatWait).

const JAB_CHAIN: Dictionary = {"jab": "jab2", "jab2": "jab3"}

var move_name: String = ""
var move: MoveData
var charge_frames: int = 0
var charging: bool = false
var combo_queued: bool = false


func id() -> String:
	return "Attack"


func debug_name() -> String:
	var s: String = "Attack (%s" % move_name
	if charge_frames > 0:
		s += ", charge %d%s" % [charge_frames, "…" if charging else ""]
	if combo_queued:
		s += ", +jab"
	return s + ")"


func enter(args: Dictionary) -> void:
	move_name = args.get("move", "")
	move = f.get_move(move_name)
	if args.has("facing"):
		f.facing = 1 if int(args["facing"]) >= 0 else -1
	charge_frames = 0
	charging = bool(args.get("charge", false)) and move_name.ends_with("smash")
	combo_queued = false
	f.start_move()


## Frame in de move (charge-frames tellen niet mee).
func move_frame() -> int:
	return sf() - charge_frames


func damage_mult() -> float:
	return 1.0 + FighterConst.SMASH_CHARGE_BONUS * float(charge_frames) / float(FighterConst.SMASH_CHARGE_MAX)


func anim() -> void:
	if move == null:
		f.change_state("Wait")
		return
	if charging and sf() - charge_frames > FighterConst.SMASH_CHARGE_FRAME:
		if f.input.held(InputFrame.BTN_ATTACK) and charge_frames < FighterConst.SMASH_CHARGE_MAX:
			charge_frames += 1
		else:
			charging = false
	var mf: int = move_frame()
	if combo_queued and mf > move.last_active_frame() + FighterConst.JAB_COMBO_GAP:
		f.start_attack(JAB_CHAIN[move_name])
		return
	if mf >= move.total_frames:
		_finish()


func _finish() -> void:
	if move_name == "dtilt" and f.stick_y() <= -MeleeStick.CROUCH_THRESHOLD + FighterConst.EPS:
		f.change_state("SquatWait")
	else:
		f.change_state("Wait")


func iasa() -> void:
	if move == null:
		return
	if JAB_CHAIN.has(move_name) and f.has_move(JAB_CHAIN[move_name]) and sf() > 0 \
			and f.input.pressed(InputFrame.BTN_ATTACK):
		combo_queued = true
	if not charging and not combo_queued and move_frame() >= move.iasa_frame():
		f.check_wait_interrupts()


func phys() -> void:
	# ⚠️ Dash attack glijdt door (traction ×1), andere grondaanvallen remmen als Wait (×2 boven walk speed).
	f.apply_ground_friction(move_name != "dash_attack")


func stops_at_edge() -> bool:
	return move_name != "dash_attack"


func hitboxes() -> Array[ActiveHitbox]:
	if move == null:
		return []
	var out: Array[ActiveHitbox] = move.active_hitboxes(move_frame(), f.pos, f.facing, f.player, f.move_instance)
	var m: float = damage_mult()
	if m != 1.0:
		for h: ActiveHitbox in out:
			h.damage = h.data.damage * m
	return out


func hurtbox_shape() -> String:
	return "crouch" if move_name == "dtilt" else "stand"


func pose() -> String:
	if charging and charge_frames > 0:
		return pick_pose("atk_%s_charge" % move_name, attack_pose(move_name))
	return pick_pose(attack_pose(move_name), "idle")


## Pose-tijd: na een charge begint de aanvalspose pas bij het loslaten (vanaf de charge-houding).
func _pose_base() -> int:
	return FighterConst.SMASH_CHARGE_FRAME if charge_frames > 0 else 0


func pose_timing() -> Array:
	if move == null or (charging and charge_frames > 0):
		return []
	return timing_for(move, _pose_base())


func pose_frame() -> int:
	if charging and charge_frames > 0:
		return charge_frames
	return maxi(move_frame() - _pose_base(), 0)


## "jab" -> atk_jab1, "jab2" -> atk_jab2, anders atk_<move>.
static func attack_pose(n: String) -> String:
	if n == "jab":
		return "atk_jab1"
	return "atk_" + n


## [startup, active, total] voor play_timed (0-based start_frame = frames vóór het eerste actieve frame).
static func timing_for(m: MoveData, base: int = 0) -> Array:
	var first: int = m.total_frames
	var last: int = -1
	for h: HitboxData in m.hitboxes:
		first = mini(first, h.start_frame)
		last = maxi(last, h.end_frame)
	if last < 0:
		return [0, 1, maxi(m.total_frames - base, 1)]
	return [maxi(first - base, 0), last - first + 1, maxi(m.total_frames - base, 1)]
