class_name MenuScreen
extends Control
## Basis voor alle menuschermen: kosmische achtergrond, een `stage` van 1280x720 gecentreerd in het venster,
## en MenuNav-polling voor beide spelers. Subclasses bouwen hun UI in `_build()` (children van `stage`)
## en reageren in `_on_act(player, act)`. Zie docs/ui.md.

var stage: Control
var nav := MenuNav.new()
## Welke spelers deze scherm bedienen (training: alleen speler 1).
var active_players: Array[int] = [0, 1]


func _ready() -> void:
	# Menu's hebben geen debug-toetsen en draaien nooit gepauzeerd (bv. na een match-quit).
	var sim: Node = MenuNav._autoload("Sim")
	if sim != null:
		sim.set_paused(false)
		sim.debug_context = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := CosmicBackground.new()
	add_child(bg)
	stage = Control.new()
	stage.size = UiStyle.SCREEN
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	resized.connect(_center_stage)
	_center_stage()
	_build()


func _center_stage() -> void:
	if stage != null:
		stage.position = ((size - UiStyle.SCREEN) * 0.5).floor()


func _build() -> void:
	pass


func _on_act(_player: int, _act: int) -> void:
	pass


func _physics_process(_delta: float) -> void:
	for p in active_players:
		for a in nav.poll(p):
			_on_act(p, a)
	_tick()


func _tick() -> void:
	pass


func go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


## Voetregel met knop-uitleg onderaan het scherm.
func add_hint_bar(text: String) -> Control:
	var c := Control.new()
	c.position = Vector2(0, 690)
	c.size = Vector2(1280, 30)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		UiStyle.text(c, text, Vector2(640, 18), 15, UiStyle.TEXT_DIM, 1))
	stage.add_child(c)
	return c
