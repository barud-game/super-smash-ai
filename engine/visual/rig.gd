class_name Rig
extends RefCounted
## Definitie van het gedeelde SVG-skelet. Zie docs/rig.md (houd die en dit bestand gelijk).
##
## Alle maten zijn "art-pixels": 1 art-px = 1 game-px (UNIT_TO_PX = 7, dus 7 art-px = 1 Melee-unit).
## Rustpose: character kijkt naar rechts (+x), staat op de grond. Oorsprong (0,0) = midden van de voeten
## op de grond; y wijst omlaag. Alleen visueel: niets hier raakt gameplay.

const SCALE_SUPERSAMPLE: float = 2.0  ## SVG wordt 2x gerasterd en op 0.5 getoond, zodat hij scherp blijft.
const OUTLINE_COLOR: String = "#1b1b24"  ## Aanbevolen outline-kleur (niet verplicht).

const THIGH_LEN: float = 32.0
const SHIN_LEN: float = 31.0
const STAND_HEIGHT_PX: float = 156.0  ## Hoogte vloer -> kruin in rustpose (~22 Melee-units).

## Bot: [naam, ouder, rustpositie t.o.v. ouder]. Volgorde = ouders vóór kinderen.
const BONES: Array = [
	["root", "", Vector2(0, 0)],
	["hip", "root", Vector2(0, -68)],
	["torso", "hip", Vector2(0, -6)],
	["head", "torso", Vector2(0, -38)],
	["upper_arm_l", "torso", Vector2(0, -34)],
	["forearm_l", "upper_arm_l", Vector2(0, 26)],
	["hand_l", "forearm_l", Vector2(0, 24)],
	["upper_arm_r", "torso", Vector2(0, -34)],
	["forearm_r", "upper_arm_r", Vector2(0, 26)],
	["hand_r", "forearm_r", Vector2(0, 24)],
	["thigh_l", "hip", Vector2(0, 0)],
	["shin_l", "thigh_l", Vector2(0, 32)],
	["foot_l", "shin_l", Vector2(0, 31)],
	["thigh_r", "hip", Vector2(0, 0)],
	["shin_r", "thigh_r", Vector2(0, 32)],
	["foot_r", "shin_r", Vector2(0, 31)],
	["cape", "torso", Vector2(-4, -34)],
	["weapon_r", "hand_r", Vector2(0, 6)],
]

## Onderdeel-definitie. "file" = bestandsnaam zonder .svg in characters/<id>/art/.
## size = canvas (px), pivot = gewricht in canvas-px (linksboven = 0,0).
## z = tekenvolgorde (laag = achter). required = moet bestaan.
## sides: true = één bestand voor beide kanten (`<file>.svg`), optioneel overschreven door `<file>_l.svg`
## voor de verre (linker) kant. De verre kant wordt automatisch iets donkerder getoond.
const PARTS: Dictionary = {
	"cape":        {"bone": "cape",        "size": Vector2i(56, 100), "pivot": Vector2i(46, 6),  "z": 0,  "required": false, "sides": false},
	"hair_back":   {"bone": "head",        "size": Vector2i(72, 72),  "pivot": Vector2i(36, 60), "z": 1,  "required": false, "sides": false},
	"upper_arm":   {"bone": "upper_arm_",  "size": Vector2i(24, 40),  "pivot": Vector2i(12, 8),  "z": 2,  "required": true,  "sides": true},
	"forearm":     {"bone": "forearm_",    "size": Vector2i(22, 38),  "pivot": Vector2i(11, 8),  "z": 3,  "required": true,  "sides": true},
	"hand":        {"bone": "hand_",       "size": Vector2i(20, 20),  "pivot": Vector2i(10, 6),  "z": 4,  "required": true,  "sides": true},
	"thigh":       {"bone": "thigh_",      "size": Vector2i(28, 48),  "pivot": Vector2i(14, 8),  "z": 5,  "required": true,  "sides": true},
	"shin":        {"bone": "shin_",       "size": Vector2i(26, 46),  "pivot": Vector2i(13, 8),  "z": 6,  "required": true,  "sides": true},
	"foot":        {"bone": "foot_",       "size": Vector2i(44, 20),  "pivot": Vector2i(12, 10), "z": 7,  "required": true,  "sides": true},
	"pelvis":      {"bone": "hip",         "size": Vector2i(44, 26),  "pivot": Vector2i(22, 12), "z": 8,  "required": true,  "sides": false},
	"torso":       {"bone": "torso",       "size": Vector2i(56, 64),  "pivot": Vector2i(28, 52), "z": 12, "required": true,  "sides": false},
	"head":        {"bone": "head",        "size": Vector2i(72, 72),  "pivot": Vector2i(36, 60), "z": 13, "required": true,  "sides": false},
	"hair_front":  {"bone": "head",        "size": Vector2i(72, 72),  "pivot": Vector2i(36, 60), "z": 14, "required": false, "sides": false},
	"hat":         {"bone": "head",        "size": Vector2i(72, 72),  "pivot": Vector2i(36, 60), "z": 15, "required": false, "sides": false},
	"weapon":      {"bone": "weapon_r",    "size": Vector2i(64, 128), "pivot": Vector2i(32, 24), "z": 30, "required": false, "sides": false},
}
## Z-offsets voor de zij-gebonden onderdelen: de verre (l) kant ligt achter de romp, de nabije (r) ervoor.
## Verre kant: z zoals in PARTS. Nabije kant: arm/been-onderdelen krijgen deze extra z-opslag.
const NEAR_Z_BONUS: Dictionary = {
	"upper_arm": 14, "forearm": 14, "hand": 14,   # arm_r: 16, 17, 18 (voor romp 12 / hoofd 13)
	"thigh": 4, "shin": 4, "foot": 4,             # been_r: 9, 10, 11 (voor bekken 8, achter romp 12)
}

const FAR_TINT: Color = Color(0.74, 0.74, 0.82)

## Teamkleuren: gereserveerde kleuren in de SVG's worden per speler vervangen.
const TEAM_MAIN: String = "#ff00ff"
const TEAM_DARK: String = "#a000a0"
const TEAM_LIGHT: String = "#ff99ff"
const PLAYER_PALETTES: Array = [
	{"main": "#e5423b", "dark": "#9a1f2a", "light": "#ff958c"},  # speler 1: rood
	{"main": "#3b7be5", "dark": "#1f3f9a", "light": "#8cb8ff"},  # speler 2: blauw
	{"main": "#3fb85a", "dark": "#1d6e33", "light": "#97e8a8"},  # speler 3: groen
	{"main": "#e5b93b", "dark": "#9a7414", "light": "#ffe28c"},  # speler 4: geel
]
