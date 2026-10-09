class_name SpecialDef
extends Resource
## Definitie van één special (neutral/side/up/down-B). Data-only; het gedrag zit in een sjabloon-runner
## (engine/specials/templates/) of in een eigen script dat `SpecialMove` uitbreidt. Zie docs/specials.md.
##
## Bestanden per character: `characters/<id>/specials/<slot>.tres` (+ optioneel `<slot>.gd`).
## Alle frames 0-based binnen hun fase (fase-frame 0 = eerste frame van de fase). Hitbox-frames in `hitboxes`
## zijn relatief aan het begin van de fase waar de rol bij hoort (zie de sjablonen).

const SLOTS: Array[String] = ["neutral", "side", "up", "down"]
const TEMPLATE_IDS: Array[String] = [
	"projectile", "charge", "teleport", "rising_multi", "counter", "reflector", "absorber", "command_grab",
	"dash_strike", "stall_fall", "multi_jump", "tether", "trap", "buff", "command_dash", "spin",
]

@export var slot: String = "neutral"
@export var display_name: String = ""
## 1 of 2 sjabloon-id's (director-besluit: max 2). [0] = primair. [1] = gekoppeld: bij `charge` het effect dat
## loskomt, bij `command_dash` de "special"-follow-up, anders volgt [1] na afloop van [0] (sequentie).
@export var templates: Array[String] = ["projectile"]
## Gedeelde instellingen (§0.2) + instellingen van templates[0]. Varianten: `<key>_ground` / `<key>_air`.
@export var params: Dictionary = {}
## Instellingen van templates[1] (vallen terug op `params` voor gedeelde sleutels).
@export var linked_params: Dictionary = {}
## Rol -> Array van HitboxData (zelfde formaat als MoveData). Rollen per sjabloon: zie docs/specials.md.
@export var hitboxes: Dictionary = {}
## Fase -> pose-naam (docs/rig.md: atk_special_*). Leeg = standaard van het sjabloon.
@export var poses: Dictionary = {}
## Fase -> VFX-/SFX-naam (presentatie-hook bij het begin van die fase).
@export var vfx: Dictionary = {}
@export var sfx: Dictionary = {}
## Verplichte telegraaf (charge, buff, trap): VFX-naam die de tegenstander ziet.
@export var telegraph: String = ""

@export var ground_allowed: bool = true
@export var air_allowed: bool = true
## Special fall (helpless) na afloop in de lucht. Director: standaard aan bij luchtrecoveries.
@export var helpless_after: bool = false
## Helpless pas als de move mist (true) i.p.v. altijd.
@export var helpless_on_miss_only: bool = false
## Landing lag bij landen tijdens de move of in de special fall erna (vast, geen L-cancel).
@export var landing_lag: int = 10
## "none" / "during" / "end_only".
@export var ledge_snap: String = "none"
## Extra grijpbereik (units) bovenop de normale ledge-grab-box.
@export var ledge_snap_range: float = 0.0
## Gebruiken per airtime (-1 = onbeperkt). Reset bij landen, ledge grab, geraakt worden, respawn (en wall jump).
@export var air_use_limit: int = -1
## Ook een eigen treffer herstelt de limiet.
@export var limit_resets_on_hit: bool = false
## {"from": int, "to": int, "max_damage": float, "vs_grab": bool} (frames vanaf het begin van de special).
@export var armor: Dictionary = {}
## {"from": int, "to": int} (frames vanaf het begin van de special).
@export var intangible: Dictionary = {}
## {"from": int, "to": int, "to_states": ["jump", "shield"]} (frames vanaf het begin van de special).
@export var cancel_window: Dictionary = {}
## Prijs-scores {S, K, B, V, U} (docs/balans.md). De validator controleert ze tegen de parameters.
@export var scores: Dictionary = {}
## Rekwisieten (PropEvent): losse SVG-props uit characters/<id>/art/props/ die op bepaalde frames (sinds de knopdruk)
## aan een bot hangen. Zie docs/specials.md §7.
@export var prop_events: Array[Dictionary] = []
## Optioneel eigen runner-script (extends SpecialMove). Leeg = `characters/<id>/specials/<slot>.gd` als dat bestaat.
@export var script_path: String = ""


func primary() -> String:
	return templates[0] if not templates.is_empty() else ""


func linked_template() -> String:
	return templates[1] if templates.size() > 1 else ""


## Parameter opzoeken. `air`: variant `<key>_air` / `<key>_ground` heeft voorrang. `linked`: eerst linked_params.
func get_param(key: String, air: bool, default: Variant = null, linked: bool = false) -> Variant:
	var variant: String = key + ("_air" if air else "_ground")
	if linked:
		if linked_params.has(variant):
			return linked_params[variant]
		if linked_params.has(key):
			return linked_params[key]
	if params.has(variant):
		return params[variant]
	if params.has(key):
		return params[key]
	return default


func has_param(key: String, linked: bool = false) -> bool:
	if linked and (linked_params.has(key) or linked_params.has(key + "_air") or linked_params.has(key + "_ground")):
		return true
	return params.has(key) or params.has(key + "_air") or params.has(key + "_ground")


## Hitboxes van een rol (lege lijst als de rol niet bestaat).
func hits(role: String) -> Array[HitboxData]:
	var out: Array[HitboxData] = []
	var raw: Variant = hitboxes.get(role)
	if raw is Array:
		for h: Variant in raw:
			if h is HitboxData:
				out.append(h)
	elif raw is HitboxData:
		out.append(raw)
	return out


func has_hits(role: String) -> bool:
	return not hits(role).is_empty()
