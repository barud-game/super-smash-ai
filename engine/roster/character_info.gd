class_name CharacterInfo
extends RefCounted
## Eén character zoals de CharacterRegistry hem kent (uit characters/<id>/character.json).
## Formaat: zie docs/ui.md.

var id: String = ""
var display_name: String = ""
var archetype: String = ""
var op: bool = false
var tagline: String = ""
## Hoofdkleur en accentkleur voor de UI (kaartjes, randen).
var color_primary: Color = Color("8a8fb8")
var color_secondary: Color = Color("3a3f6b")
## res://-map van het character.
var dir: String = ""
## True als er een character.json was die goed te lezen was.
var has_manifest: bool = false
var has_art: bool = false
var warnings: PackedStringArray = PackedStringArray()


func matches(query: String) -> bool:
	var q: String = query.strip_edges().to_lower()
	if q == "":
		return true
	return display_name.to_lower().contains(q) or id.to_lower().contains(q) \
		or archetype.to_lower().contains(q) or tagline.to_lower().contains(q)
