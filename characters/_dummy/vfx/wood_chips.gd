extends SpecialFx
## Voorbeeld van een per-character special-effect (docs/vfx.md): houtsplinters die omhoog vliegen en vallen.
## Gebruik: `spawn_special_fx("wood_chips", ...)` of `d.vfx = {"event": "wood_chips"}` in de SpecialDef.
## Maten in units; y omlaag. Alleen `rng` gebruiken.

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _rot := PackedFloat32Array()


func _on_fx_setup() -> void:
	duration = 22
	for i in 8:
		_pos.append(Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.0)))
		_vel.append(Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.7, -0.3)))
		_rot.append(rng.randf() * TAU)


func _draw_fx(t: float, f: int) -> void:
	var wood: Color = color.lerp(Color("#c9a26b"), 0.7)
	for i in _pos.size():
		var fl: float = float(f)
		var p: Vector2 = _pos[i] + _vel[i] * fl + Vector2(0.0, 0.035 * fl * fl)   # eenvoudige zwaartekracht
		draw_spike(p, SpecialFx.dir_deg(rad_to_deg(_rot[i]) + fl * 20.0), 1.4, 0.25, with_alpha(wood, 1.0 - t * t))
