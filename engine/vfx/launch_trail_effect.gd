class_name LaunchTrailEffect
extends VfxEffect
## Melee-achtig rookspoor achter een gelanceerde fighter. Volgt `target` zolang `follow_frames`
## lopen en laat daarna de laatste rookpluimen uitdoven.

const PUFF_LIFE: int = 18

var target: Node2D = null
var follow_frames: int = 30
var color: Color = Color(0.92, 0.9, 0.95)
var _puffs: Array[Dictionary] = []   # {pos (global px), born, r}


func setup(p_target: Node2D, frames: int, p_color: Color = Color(0.92, 0.9, 0.95)) -> void:
	target = p_target
	follow_frames = maxi(frames, 1)
	color = p_color
	duration = follow_frames + PUFF_LIFE
	z_index = -2
	# Effect staat op de layer-oorsprong; puffs staan in wereldcoordinaten.
	position = Vector2.ZERO


func _on_tick() -> void:
	if age < follow_frames and is_instance_valid(target):
		var gp: Vector2 = target.global_position + Vector2(0, -VfxConst.TRAIL_BODY_Y_PX)
		_puffs.append({"pos": gp, "born": age, "r": rng.randf_range(9.0, 15.0), "j": Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))})
	elif age < follow_frames:
		# Target verdwenen: stop met volgen.
		follow_frames = age
		duration = age + PUFF_LIFE


func _draw() -> void:
	for pf: Dictionary in _puffs:
		var life: float = float(age - int(pf["born"])) / float(PUFF_LIFE)
		if life >= 1.0:
			continue
		var p: Vector2 = to_local(pf["pos"] + pf["j"] * life * 2.0 + Vector2(0, -life * 3.0))
		var r: float = float(pf["r"]) * VfxConst.TRAIL_SCALE * (0.6 + 0.9 * ease_out(life))
		var a: float = (1.0 - life) * 0.7
		disc(p, r, with_alpha(color.darkened(0.25), a * 0.7))
		disc(p + Vector2(0, -r * 0.1), r * 0.75, with_alpha(color, a))
