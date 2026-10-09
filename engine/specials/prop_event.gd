class_name PropEvent
extends RefCounted
## Rekwisiet-events (props) voor specials en taunt: "toon prop X aan bot Y tussen frame A en B".
## Data-only helpers; het tonen zelf doet CharacterVisual.set_props(). Zie docs/specials.md §7 en docs/rig.md §9.
##
## Eén event is een Dictionary (in `SpecialDef.prop_events` of `taunt_props` in character.json):
##   prop        naam van characters/<id>/art/props/<naam>.svg (verplicht)
##   attach      "hand_r" | "hand_l" | "root" | "under_feet" (standaard "hand_r")
##   from_frame  eerste frame waarop de prop zichtbaar is (standaard 0)
##   to_frame    laatste frame (inclusief); -1 = tot het einde van de special/taunt (standaard -1)
##   offset      [x, y] of Vector2, rig-px t.o.v. de bot (standaard 0,0)
##   rotation    graden, kloksgewijs (standaard 0)
##   scale       factor (standaard 1)
##   pivot       optioneel [x, y] of Vector2: greeppunt in canvas-px; anders het standaardpunt per attach
## Frames: bij een special = frames sinds de knopdruk (0 = drukframe, Fighter.state_frame); bij de taunt = taunt-frame.

const ATTACHES: Array[String] = ["hand_r", "hand_l", "root", "under_feet"]
const MAX_SCALE: float = 8.0


## Complete, getypeerde versie van een ruw event (JSON of .tres). Onbekende velden worden genegeerd.
static func normalize(raw: Dictionary) -> Dictionary:
	var ev: Dictionary = {
		"prop": String(raw.get("prop", "")),
		"attach": String(raw.get("attach", "hand_r")),
		"from_frame": int(raw.get("from_frame", 0)),
		"to_frame": int(raw.get("to_frame", -1)),
		"offset": _vec(raw.get("offset", null), Vector2.ZERO),
		"rotation": float(raw.get("rotation", 0.0)),
		"scale": float(raw.get("scale", 1.0)),
	}
	if raw.has("pivot"):
		ev["pivot"] = _vec(raw["pivot"], Vector2.ZERO)
	return ev


## Fouten in een ruw event (leeg = geldig). Wordt door de validator gebruikt.
static func problems(raw: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if not (raw is Dictionary):
		out.append("prop-event is geen dictionary")
		return out
	var d: Dictionary = raw
	if String(d.get("prop", "")) == "":
		out.append("prop-event zonder 'prop' (naam van art/props/<naam>.svg)")
	elif not String(d["prop"]).is_valid_filename() or String(d["prop"]).contains("."):
		out.append("prop-naam '%s' is ongeldig (alleen een bestandsnaam zonder extensie)" % d["prop"])
	var attach: String = String(d.get("attach", "hand_r"))
	if not ATTACHES.has(attach):
		out.append("prop '%s': attach '%s' onbekend (%s)" % [d.get("prop", "?"), attach, ", ".join(ATTACHES)])
	var from_f: int = int(d.get("from_frame", 0))
	var to_f: int = int(d.get("to_frame", -1))
	if from_f < 0:
		out.append("prop '%s': from_frame < 0" % d.get("prop", "?"))
	if to_f != -1 and to_f < from_f:
		out.append("prop '%s': to_frame (%d) < from_frame (%d)" % [d.get("prop", "?"), to_f, from_f])
	var sc: float = float(d.get("scale", 1.0))
	if sc <= 0.0 or sc > MAX_SCALE:
		out.append("prop '%s': scale %.2f buiten 0..%.0f" % [d.get("prop", "?"), sc, MAX_SCALE])
	return out


## Genormaliseerde events die op `frame` zichtbaar zijn (from_frame <= frame <= to_frame, of to_frame -1).
static func active(events: Array, frame: int) -> Array:
	var out: Array = []
	for raw: Variant in events:
		if not (raw is Dictionary):
			continue
		var ev: Dictionary = normalize(raw)
		if ev["prop"] == "" or frame < int(ev["from_frame"]):
			continue
		if int(ev["to_frame"]) >= 0 and frame > int(ev["to_frame"]):
			continue
		out.append(ev)
	return out


static func _vec(v: Variant, fallback: Vector2) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return fallback
