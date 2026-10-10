class_name StateWallJump
extends FighterState
## WallJump (Melee: Fox/Falco/Sheik/...): in de lucht tegen een stage-zijkant, stick van de muur af gesmasht ->
## korte wall-touch (TOUCH_FRAMES, vel 0, geen gravity), dan een sprong weg van de muur (vy = air-jump-kracht,
## vx = WALL_JUMP_VX weg van de muur). Geen extra double jump terug; wel reset van de special-limieten.
## Alleen met `stats.wall_jump`. Alleen uit Jump/JumpAerial/Fall (check_air_interrupts); niet uit helpless
## (FallSpecial), tijdens aanvallen of in hitstun (Melee-gedrag van de meeste wall-jumpers) ⚠️.
## Stages hebben geen echte muren: de "muur" is de zijkant van elk SOLID-segment (x = uiteinde), van
## de segment-rand tot WALL_DEPTH eronder (zelfde diepte als het solide blok in SpecialWorld).

const TOUCH_FRAMES: int = 2  # ⚠️ wall-touch voor de afzet
const WALL_JUMP_VX: float = 1.0  # ⚠️ snelheid weg van de muur
const WALL_JUMP_VY_MULT: float = 1.0  # ⚠️ x air_jump_velocity (= jump_v * air_jump_v_multiplier)
const ANIM_FRAMES: int = 30  # ⚠️ daarna Fall
const WALL_REACH: float = 8.0  # ⚠️ max. afstand voeten-x tot de muur (units)
const WALL_DEPTH: float = 30.0  # ⚠️ muurhoogte onder de segment-rand
const COOLDOWN: int = 40  # ⚠️ min. frames tussen twee wall jumps (Melee: eens per luchtduik)
const META_TICK: String = "wall_jump_tick"

var away: int = 1


func id() -> String:
	return "WallJump"


## Richting weg van de nabije muur (+1/-1), of 0 als er geen muur binnen bereik is.
static func wall_away(fighter: Fighter) -> int:
	for s: Dictionary in fighter._segments:
		if s["platform"]:
			continue
		for side: int in [-1, 1]:
			var edge: Vector2 = s["a"] if side < 0 else s["b"]
			# Fighter staat buiten het segment, aan de zijde `side`; de muur zit aan zijn andere kant.
			if (fighter.pos.x - edge.x) * side < 0.0 or absf(fighter.pos.x - edge.x) > WALL_REACH:
				continue
			if fighter.pos.y < edge.y - 2.0 and fighter.pos.y >= edge.y - WALL_DEPTH:
				return side
	return 0


## Voorwaarden voor een wall jump nu: vlag, muur in bereik, verse smash weg van de muur, cooldown.
static func can_start(fighter: Fighter) -> bool:
	if not fighter.stats.wall_jump or fighter.grounded:
		return false
	if fighter.has_meta(META_TICK) and fighter.tick_count - int(fighter.get_meta(META_TICK)) < COOLDOWN:
		return false
	var away_dir: int = wall_away(fighter)
	if away_dir == 0:
		return false
	return fighter.input.flick_x(MeleeStick.SMASH_THRESHOLD, MeleeStick.SMASH_WINDOW) == away_dir


func enter(_args: Dictionary) -> void:
	away = wall_away(f)
	if away == 0:
		away = 1 if f.stick_x() >= 0.0 else -1
	f.facing = away
	f.vel = Vector2.ZERO
	f.fastfalling = false
	f.reset_fast_fall_buffer()
	f.set_meta(META_TICK, f.tick_count)
	SpecialKit.of(f).reset_air_limits("wall_jump")


func anim() -> void:
	if sf() >= ANIM_FRAMES:
		f.change_state("Fall")


func iasa() -> void:
	if sf() > TOUCH_FRAMES and not f.check_aerial():
		f.check_air_interrupts()


func phys() -> void:
	if sf() < TOUCH_FRAMES:
		f.vel = Vector2.ZERO
		return
	if sf() == TOUCH_FRAMES:
		f.vel = Vector2(away * WALL_JUMP_VX, f.stats.air_jump_velocity(0) * WALL_JUMP_VY_MULT)
	f.apply_air_physics()


func is_grounded() -> bool:
	return false


func pose() -> String:
	return "jump_aerial"


func can_grab_ledge() -> bool:
	return sf() > TOUCH_FRAMES
