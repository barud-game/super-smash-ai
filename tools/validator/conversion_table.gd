extends RefCounted
## Conversietabel score -> Melee-frame data, 1-op-1 uit docs/move-conversie.md.
## BIJ ELKE WIJZIGING IN docs/move-conversie.md MOET DIT BESTAND MEE (en andersom). Zie docs/validator.md.
## Alle rijen zijn arrays van 6 waarden, index = score 0..5.

const NORMAL_MOVES: Array[String] = [
	"jab", "ftilt", "utilt", "dtilt", "dash_attack", "fsmash", "usmash", "dsmash",
	"nair", "fair", "bair", "uair", "dair",
	"grab", "fthrow", "bthrow", "uthrow", "dthrow",
]
const SPECIAL_MOVES: Array[String] = ["neutral_b", "side_b", "up_b", "down_b"]

## Kracht-groep per move (§2.1). Throws/grab: "throw"/"grab".
const GROUP := {
	"jab": "jab",
	"ftilt": "normal", "utilt": "normal", "dtilt": "normal", "dash_attack": "normal",
	"nair": "normal", "fair": "normal", "bair": "normal", "uair": "normal", "dair": "normal",
	"fsmash": "smash", "usmash": "smash", "dsmash": "smash",
	"fthrow": "throw", "bthrow": "throw", "uthrow": "throw", "dthrow": "throw",
	"grab": "grab",
}

## Welke assen tellen mee voor kosten (balans.md): normals S/K/B/V, throws S/K, grab S/B.
const AXES := {"default": ["S", "K", "B", "V"], "throw": ["S", "K"], "grab": ["S", "B"]}

## §2.1 Kracht: d (damage), b (BKB), g (KBG) per groep, index = Kr.
const DAMAGE := {
	"jab": [2, 3, 4, 5, 6, 7],
	"normal": [4, 6, 8, 10, 12, 14],
	"smash": [8, 10, 13, 15, 17, 20],
	"throw": [2, 3, 4, 5, 7, 9],
}
const BKB := {
	"jab": [5, 8, 12, 15, 20, 25],
	"normal": [10, 15, 20, 25, 30, 35],
	"smash": [20, 25, 30, 30, 35, 40],
	"throw": [20, 25, 30, 35, 40, 45],
}
const KBG := {
	"jab": [60, 60, 80, 90, 110, 125],
	"normal": [95, 110, 120, 120, 125, 130],
	"smash": [95, 105, 100, 105, 115, 110],
	"throw": [65, 85, 105, 125, 125, 130],
}
## §2.2 Damage-plafond per groep (gemeten maxima).
const DAMAGE_CEILING := {"jab": 7, "normal": 17, "smash": 24, "throw": 9}
## Tilt-plafond (14) is lager dan het aerial-plafond (17).
const TILT_CEILING := 14
const SOURSPOT_DAMAGE_MULT := 0.7
const SOURSPOT_BKB_MINUS := 10

## §3 Snelheid -> startup (1-based eerste actieve frame). Throws: totale duur. Grab: staand.
const STARTUP := {
	"jab": [8, 6, 5, 4, 3, 2],
	"ftilt": [15, 12, 9, 7, 5, 4],
	"utilt": [13, 10, 8, 6, 5, 4],
	"dtilt": [18, 14, 11, 9, 7, 5],
	"dash_attack": [16, 13, 10, 8, 6, 4],
	"fsmash": [28, 21, 16, 13, 11, 9],
	"usmash": [22, 16, 12, 9, 7, 6],
	"dsmash": [16, 13, 10, 8, 6, 5],
	"nair": [12, 10, 8, 6, 5, 4],
	"fair": [15, 12, 9, 7, 6, 4],
	"bair": [15, 12, 9, 8, 6, 4],
	"uair": [18, 14, 10, 8, 6, 4],
	"dair": [16, 12, 9, 7, 5, 4],
	"grab": [12, 10, 8, 7, 6, 5],
}
const THROW_TOTAL := [85, 60, 46, 41, 36, 31]
## ⚠️ ontwerpkeuze: worp lanceert op frame round(total * 0,5).
const THROW_LAUNCH_FRACTION := 0.5

## §4.1 Radius per Bereik-score.
const RADIUS := [2.0, 2.5, 3.0, 3.5, 4.5, 6.0]
## §4.1 Reach R (units, buitenrand verste hitbox). ⚠️ geschat.
const REACH := {
	"jab": [8, 10, 12, 14, 17, 20],
	"ftilt": [10, 12, 15, 18, 22, 26],
	"utilt": [10, 13, 16, 19, 23, 27],
	"dtilt": [10, 12, 15, 18, 21, 24],
	"dash_attack": [8, 10, 12, 15, 18, 21],
	"fsmash": [14, 16, 19, 22, 26, 30],
	"usmash": [16, 19, 22, 26, 30, 34],
	"dsmash": [12, 14, 17, 20, 23, 26],
	"nair": [8, 10, 12, 14, 17, 20],
	"fair": [12, 14, 17, 20, 24, 28],
	"bair": [12, 14, 17, 20, 24, 28],
	"uair": [14, 17, 20, 23, 27, 31],
	"dair": [12, 14, 17, 20, 24, 28],
	"grab": [8, 10, 12, 14, 17, 20],
}
## Richting waarin reach gemeten wordt: "fwd" (+x), "back" (-x), "side" (|x|), "up" (+y), "down" (-y).
## Definitie (afspraak 9): reach = (positie langs die as / (visual_height/15)) + radius. De positie is de offset t.o.v.
## de fighter-oorsprong (= de voeten). Verticale moves (utilt, usmash, uair, dair) meten we dus in y vanaf de voeten
## (omhoog +y, omlaag -y); horizontale moves en aerials (nair, fair, bair) in x vanaf het lichaamsmidden (x = 0).
## De radius schaalt niet mee.
const REACH_DIR := {
	"jab": "fwd", "ftilt": "fwd", "utilt": "up", "dtilt": "fwd", "dash_attack": "fwd",
	"fsmash": "fwd", "usmash": "up", "dsmash": "side",
	"nair": "side", "fair": "fwd", "bair": "back", "uair": "up", "dair": "down", "grab": "fwd",
}
## Tolerantie op reach (units): reach is een schatting.
const REACH_TOL := 1.5
const RADIUS_TOL := 0.05

## §4.2 Active frames (aaneengesloten hit-blok) per Bereik-score.
const ACTIVE := {
	"jab": [2, 2, 3, 3, 4, 4],
	"ftilt": [3, 3, 4, 4, 5, 6],
	"utilt": [3, 4, 5, 6, 7, 9],
	"dtilt": [2, 3, 3, 4, 5, 7],
	"dash_attack": [3, 4, 6, 8, 11, 14],
	"fsmash": [3, 4, 5, 7, 9, 11],
	"usmash": [3, 4, 5, 6, 8, 11],
	"dsmash": [2, 3, 4, 5, 6, 8],
	"nair": [3, 5, 8, 12, 18, 26],
	"fair": [3, 4, 4, 6, 10, 16],
	"bair": [3, 4, 5, 7, 10, 14],
	"uair": [3, 4, 4, 5, 6, 8],
	"dair": [3, 4, 4, 5, 6, 8],
	"grab": [2, 2, 2, 2, 2, 2],
}
## Hits met minder dan dit aantal frames ertussen horen bij hetzelfde hit-blok (multi-hit interval 3).
const BLOCK_MAX_GAP := 3
## Disjoint verwacht vanaf Bereik-score.
const DISJOINT_MIN_BE := 4

## §5.1 Grondmoves: doel-shield-advantage (late hit) per Veiligheid-score. Familie: jab / tilt / smash.
const ADV_FAMILY := {
	"jab": "jab", "ftilt": "tilt", "utilt": "tilt", "dtilt": "tilt", "dash_attack": "tilt",
	"fsmash": "smash", "usmash": "smash", "dsmash": "smash",
}
const ADV_TARGET := {
	"jab": [-22, -18, -14, -11, -8, -5],
	"tilt": [-24, -18, -13, -9, -6, -3],
	"smash": [-36, -30, -24, -18, -13, -8],
}
## Afrondings-tolerantie (frames) op shield-advantage.
const ADV_TOL := 1
const MIN_TOTAL_FRAMES := 10

## §5.2 Aerials per Veiligheid-score.
const LANDING_LAG := [40, 30, 24, 20, 15, 12]
const LCANCEL_LAG := [20, 15, 12, 10, 7, 6]
const AIR_ENDLAG := [46, 38, 32, 26, 22, 18]
const AIR_ENDLAG_TOL := 1
## Auto-cancel ⚠️: na last_active + 12 (gemeten +3..+20).
const AUTOCANCEL_AFTER_OFFSET := 12

## §6 Toegestane launch-angles (hoofd-hitbox): lijst van [lo, hi]. 361 = Sakurai.
const ANGLES := {
	"jab": [[361, 361], [70, 83]],
	"ftilt": [[361, 361], [30, 45]],
	"utilt": [[84, 110]],
	"dtilt": [[20, 30], [70, 90], [361, 361]],
	"dash_attack": [[361, 361], [72, 80], [110, 110]],
	"fsmash": [[361, 361], [60, 70]],
	"usmash": [[75, 90]],
	"dsmash": [[361, 361], [25, 25], [0, 0], [91, 180]],
	"nair": [[361, 361], [80, 90]],
	"fair": [[361, 361], [67, 67], [24, 24]],
	"bair": [[91, 180]],
	"uair": [[80, 92]],
	"dair": [[270, 290], [361, 361]],
	"fthrow": [[45, 55]],
	"bthrow": [[91, 180]],
	"uthrow": [[70, 93]],
	"dthrow": [[50, 50], [80, 80], [135, 135], [270, 270]],
}

## Afspraken (docs/standaard-movesets.md, director).
## 1. Hoeken: achterwaarts lanceren = hoek > 90 (361 is relatief aan de kijkrichting en lanceert dus vooruit).
const SAKURAI := 361.0
const BACK_ANGLE_MIN := 90.0
## 2. Grab-whiff: totale duur = laatste actieve frame (1-based) + 23.
const GRAB_WHIFF_AFTER := 23
## 3. Throws: launch-hitbox op de grab-tip, radius 3.0.
const THROW_RADIUS := 3.0
const THROW_POS_TOL := 0.5
## 8. Hoogtes als fractie van visual_height (tolerantie ook als fractie); dtilt/dsmash op y = 2 (+-1).
const HEIGHT_HORIZONTAL := 0.55
const HEIGHT_AERIAL := 0.5
const HEIGHT_TOL := 0.12
const HEIGHT_LOW := 2.0
const HEIGHT_LOW_TOL := 1.0
## 9. Referentielengte waarvoor de reach-tabel geldt.
const REFERENCE_HEIGHT := 15.0
## 10. Rondom-moves: minimaal een box voor (x > 0) en een achter (x < 0).
const AROUND_MOVES: Array[String] = ["nair", "dsmash"]
## 6. Multi-hit: eerdere hits d 1-2, BKB <= 10.
const MULTI_DAMAGE_MIN := 1.0
const MULTI_DAMAGE_MAX := 2.0
const MULTI_BKB_MAX := 10.0

## §7 Grab: hitbox-eigenschappen (angle 361, BKB 0, KBG 100, geen damage).
const GRAB_BKB := 0
const GRAB_KBG := 100

## Score-bereiken.
const SCORE_MAX := 5
const UTILITY_MAX := 10
const BUDGET := 200


static func group_of(move: String) -> String:
	return GROUP.get(move, "")


static func is_aerial(move: String) -> bool:
	return move in ["nair", "fair", "bair", "uair", "dair"]


static func is_throw(move: String) -> bool:
	return move in ["fthrow", "bthrow", "uthrow", "dthrow"]


static func is_ground(move: String) -> bool:
	return move in ["jab", "ftilt", "utilt", "dtilt", "dash_attack", "fsmash", "usmash", "dsmash"]


static func axes_for(move: String) -> Array:
	if is_throw(move):
		return AXES["throw"]
	if move == "grab":
		return AXES["grab"]
	return AXES["default"]


static func shieldstun(damage: float) -> int:
	return int(floor(0.448 * damage + 2.0))
