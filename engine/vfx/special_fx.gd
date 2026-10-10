class_name SpecialFx
extends VfxEffect
## Basis voor special-effecten (`VfxLayer.spawn_special_fx`). Generieke effecten staan in `GenericSpecialFx`;
## een character kan eigen effecten leveren in `characters/<id>/vfx/<naam>.gd` (`extends SpecialFx`).
##
## Tekenen gebeurt in **Melee-units** (1 unit = 7 px, y OMLAAG zoals Godot; oorsprong = spawnpunt, bij
## `at_feet` de voet van de fighter). Het transform is al geschaald, dus `draw_line(a, b, col, 0.4)` is 0.4 unit breed.
## Schrijf `_on_fx_setup()` (duur + deeltjes met `rng`) en `_draw_fx(t, f)` (pure functie van t/f en de arrays).

## Kijkrichting van de fighter (+1 rechts, -1 links).
var facing: int = 1
## Kleur (param `color`, standaard de spelerskleur).
var color: Color = Color.WHITE
var player: int = 0
var params: Dictionary = {}
## Uniforme schaal (param `size`, standaard 1).
var size_mult: float = 1.0
## Zet in `_on_fx_setup()` op true om op de voet te verschijnen (param `foot` van de special, in units) i.p.v. lichaamsmidden.
var at_feet: bool = false


## Door de layer aangeroepen. `pos_px` = spawnpunt (wereld-px), `p_params` = aanroep-params (+ `character`, `foot`).
func setup_fx(pos_px: Vector2, p_facing: int, p_color: Color, p_player: int, p_params: Dictionary) -> void:
	position = pos_px
	facing = 1 if p_facing >= 0 else -1
	color = p_color
	player = p_player
	params = p_params
	size_mult = clampf(float(p_params.get("size", 1.0)), 0.1, 6.0)
	z_index = 20
	_on_fx_setup()
	if params.has("duration"):
		duration = clampi(int(params["duration"]), 1, 90)
	duration = clampi(duration, 1, 90)
	if at_feet and params.get("foot") is Vector2:
		position = Units.to_px(params["foot"] as Vector2)


## Override: zet `duration` en bouw deeltjes (alleen `rng` gebruiken, nooit randf()).
func _on_fx_setup() -> void:
	pass


## Override: teken frame `f` (`t` = f / duration), in units.
func _draw_fx(_t: float, _f: int) -> void:
	pass


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * (Units.UNIT_TO_PX * size_mult))
	_draw_fx(progress(), age)


## Eenheidsvector uit hoek in graden (units-conventie: 0 = rechts, 90 = omhoog) in tekenruimte (y omlaag).
static func dir_deg(deg: float) -> Vector2:
	var r: float = deg_to_rad(deg)
	return Vector2(cos(r), -sin(r))


## Kleur lichter richting wit.
static func bright(c: Color, k: float = 0.6) -> Color:
	return c.lerp(Color.WHITE, k)
