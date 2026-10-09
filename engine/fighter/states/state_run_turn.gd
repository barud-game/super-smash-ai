class_name StateRunTurn
extends FighterState
## RunTurn (TurnRun, run turnaround): remt met traction tot stilstand, draait dan om en versnelt met de
## run-formule. Melee: traag (tot ~51 frames bij Marth), dus alleen onderbreekbaar met:
## - jump (altijd);
## - een dash-flick (⚠️ leniency): in de oude richting = turnaround afbreken en weer dashen, in de nieuwe
##   richting (na het omdraaien) = Dash;
## - voor het omdraaien: stick weer vooruit (>= run-drempel) = terug naar Run, stick neutraal = RunBrake
##   (de speler wilde stoppen, niet omdraaien: facing verandert dan niet).
## Na het omdraaien: Run zodra de stick vooruit staat (≥ run-drempel), anders Wait na run_turn_frames.

var new_dir: int = 1
var flipped: bool = false
var flip_frame: int = 0
## Tick van binnenkomst: de flick die de turn startte telt niet als nieuwe dash-flick.
var entry_tick: int = 0


func id() -> String:
	return "RunTurn"


func enter(_args: Dictionary) -> void:
	new_dir = -f.facing
	flipped = false
	flip_frame = 0
	entry_tick = f.tick_count


func anim() -> void:
	if not flipped:
		return
	var fwd: bool = f.stick_x() * f.facing >= MeleeStick.RUN_THRESHOLD - FighterConst.EPS
	if fwd:
		f.change_state("Run")
	elif sf() >= f.stats.run_turn_frames:
		f.change_state("Wait")


func iasa() -> void:
	if f.check_ground_jump():
		return
	# Alleen een NIEUWE flick (begonnen na binnenkomst) onderbreekt; de flick die de turn startte niet.
	if f.tick_count - f.input.stick_timer_x() > entry_tick and f.check_dash():
		return
	if not flipped:
		var d: float = f.stick_x() * f.facing  # t.o.v. de oude richting (facing)
		if d >= MeleeStick.RUN_THRESHOLD - FighterConst.EPS:
			f.change_state("Run")
		elif d >= 0.0:
			# Stick (bijna) neutraal of licht vooruit: geen omdraai-intentie meer -> uitglijden.
			f.change_state("RunBrake")


func phys() -> void:
	if not flipped:
		f.gr_vel = move_toward(f.gr_vel, 0.0, f.stats.traction)
		if f.gr_vel == 0.0 or signf(f.gr_vel) == float(new_dir):
			flipped = true
			flip_frame = sf()
			f.facing = new_dir
	elif f.stick_x() * f.facing > 0.0:
		f.apply_dash_run_accel(f.stick_x())
	else:
		f.apply_ground_friction(false)


## Glijdt over de rand en valt eraf (Melee: alleen langzaam lopen/stilstaan stopt aan de rand). ⚠️
func stops_at_edge() -> bool:
	return false


func pose() -> String:
	return "turn" if flipped else "skid"


func pose_frame() -> int:
	return sf() - flip_frame if flipped else sf()
