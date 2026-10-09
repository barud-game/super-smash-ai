class_name KoEffect
extends VfxEffect
## Basisclass van alle KO-effecten (blast zone-explosie). Per character mag er een subclass staan in
## `characters/<id>/ko_effect/ko_effect.gd`; zie docs/vfx.md voor de specificatie.
##
## Lokale ruimte van het effect: oorsprong = punt waar de fighter de blast zone uit vloog,
## `dir` = eenheidsvector de stage in (Godot-px, y omlaag), `perp` = haaks daarop.
## Overschrijf `_on_ko_setup()` (eenmalig, zet `duration` en bouw deeltjes met `rng`) en `_draw_ko(t, age)`.
## Teken alleen met de draw_*-hulpen; geen gameplay, geen `_process`, geen `randf()` (gebruik `rng`).

var side: int = VfxConst.SIDE_LEFT
var dir: Vector2 = Vector2.RIGHT
var perp: Vector2 = Vector2.DOWN
## Kleur van de speler (team/poort).
var player_color: Color = Color.WHITE
## Karakterkleuren (character.json `colors`: primary, secondary, ...); nooit leeg na setup.
var colors: PackedColorArray = PackedColorArray()
var character_id: String = ""


func setup_ko(pos_px: Vector2, p_side: int, p_player_color: Color, p_colors: PackedColorArray, p_character_id: String = "") -> void:
	position = pos_px
	side = p_side
	dir = VfxConst.inward_dir(side)
	perp = Vector2(-dir.y, dir.x)
	player_color = p_player_color
	colors = p_colors
	if colors.is_empty():
		colors = PackedColorArray([p_player_color, p_player_color.darkened(0.4)])
	character_id = p_character_id
	duration = 60
	z_index = 30
	_on_ko_setup()
	duration = clampi(duration, 1, VfxConst.KO_MAX_FRAMES)


## Hoofdkleur van het character.
func primary() -> Color:
	return colors[0]


func secondary() -> Color:
	return colors[1] if colors.size() > 1 else colors[0].darkened(0.4)


func _on_ko_setup() -> void:
	pass


func _draw() -> void:
	_draw_ko(progress(), age)


func _draw_ko(_t: float, _frame: int) -> void:
	pass
