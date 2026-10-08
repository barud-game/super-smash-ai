class_name PortraitCache
extends Node
## Rendert per character één keer een klein portret (CharacterVisual, idle-pose) naar een eigen SubViewport
## en geeft de ViewportTexture terug. Lui: alleen wat de pagina nodig heeft. `clear()` voor hot reload.

const PORTRAIT_SIZE := Vector2i(110, 96)
const FEET := Vector2(55, 92)
const SCALE := 0.55

var _viewports: Dictionary = {}   # "<id>#<speler>" -> SubViewport


func texture(info: CharacterInfo, player: int = 0) -> Texture2D:
	if info == null or not info.has_art:
		return null
	var key: String = "%s#%d" % [info.id, player]
	if _viewports.has(key):
		var vp0: SubViewport = _viewports[key]
		return vp0.get_texture() if vp0 != null else null
	var vp := SubViewport.new()
	vp.size = PORTRAIT_SIZE
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cv := CharacterVisual.new()
	cv.character_id = info.id
	cv.player_index = player
	cv.position = FEET
	cv.scale = Vector2(SCALE, SCALE)
	vp.add_child(cv)
	add_child(vp)   # _ready van cv laadt de SVG's
	if not cv.is_valid:
		vp.queue_free()
		_viewports[key] = null
		return null
	cv.play("idle")
	cv.tick(0)
	_viewports[key] = vp
	return vp.get_texture()


func clear() -> void:
	for k in _viewports:
		var vp: SubViewport = _viewports[k]
		if vp != null:
			vp.queue_free()
	_viewports.clear()
