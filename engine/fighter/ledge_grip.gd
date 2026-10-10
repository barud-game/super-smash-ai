class_name LedgeGrip
extends RefCounted
## Waar de handen van een character zitten als hij aan de ledge hangt, berekend uit het rig (geen vaste getallen).
##
## Forward kinematics over Rig.BONES met de pose `cliff_wait` op frame 0 (gedeelde poses + eventuele eigen poses
## van het character, PoseLibrary.load_for). Het greeppunt = gemiddelde van beide handpalmen + GRIP_INSET.
## Resultaat in rig-px (character kijkt rechts, y omlaag, oorsprong = voeten-midden) en gecachet per character.
## Fighter.ledge_grip() schaalt het met visual_height naar Melee-units, dus elke lengte (8-30 units) werkt.
## Puur rekenwerk op pose-data: deterministisch en zonder scene tree (headless tests, rollback).

const HANG_POSE: String = "cliff_wait"
## Middelpunt van de handpalm t.o.v. de pols (hand.svg: pivot y=6, middelpunt y≈12).
const PALM_PX: Vector2 = Vector2(0.0, 6.0)
## Ledge-hoek t.o.v. het palm-midden (rig-px): de palm ligt iets binnen de rand en óp de bovenkant.
const GRIP_INSET: Vector2 = Vector2(-4.0, 6.0)
## Fallback als er geen hang-pose is (rig-px, ≈ handen recht boven het hoofd).
const FALLBACK_PX: Vector2 = Vector2(14.0, -154.0)

static var _cache: Dictionary = {}


## Ledge-hoek t.o.v. de voeten in rig-px (x = richting de stage/kijkrichting, y omlaag; y < 0).
static func grip_px(character_id: String, library: PoseLibrary = null) -> Vector2:
	if _cache.has(character_id):
		return _cache[character_id]
	var lib: PoseLibrary = library if library != null else PoseLibrary.load_for(character_id)
	var p: Vector2 = FALLBACK_PX
	var pose: Pose = lib.poses.get(HANG_POSE)
	if pose != null:
		var g: Dictionary = bone_transforms(pose, 0.0)
		var palm_r: Vector2 = (g["hand_r"] as Transform2D) * PALM_PX
		var palm_l: Vector2 = (g["hand_l"] as Transform2D) * PALM_PX
		p = (palm_r + palm_l) * 0.5 + GRIP_INSET
	_cache[character_id] = p
	return p


## Vergeet de cache (na het herladen van poses). Leeg = alles.
static func clear_cache(character_id: String = "") -> void:
	if character_id == "":
		_cache.clear()
	else:
		_cache.erase(character_id)


## Globale transforms (rig-px) van alle botten in `pose` op tijd `t`, zoals CharacterVisual._apply ze zet.
static func bone_transforms(pose: Pose, t: float) -> Dictionary:
	var s: Dictionary = pose.sample(t)
	var r: Dictionary = s["r"]
	var o: Dictionary = s["o"]
	var g: Dictionary = {}
	for def: Array in Rig.BONES:
		var bone: String = def[0]
		var parent: String = def[1]
		var rest: Vector2 = def[2]
		var local := Transform2D(deg_to_rad(float(r.get(bone, 0.0))), rest + (o.get(bone, Vector2.ZERO) as Vector2))
		g[bone] = local if parent == "" else (g[parent] as Transform2D) * local
	return g
