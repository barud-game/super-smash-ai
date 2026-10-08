class_name MeleeStick
extends RefCounted
## Kwantisatie van ruwe stick-input naar het Melee-raster, plus alle stickdrempels die gameplay gebruikt.
## Zie docs/movement.md (sectie Input). Drempels zijn genormaliseerd (raster/80), vensters in frames.
##
## Flicks ("smash"-inputs) werken zoals in Melee: per as houdt InputHistory een teller bij
## "frames sinds de stick de deadzone verliet" (in de huidige richting). Een flick = |as| >= drempel
## terwijl die teller < venster. Er is dus geen "van onder een lage drempel"-voorwaarde.

const GRID: int = 80
## Deadzone 0.28 per as (PlCo) -> op het raster |v| < 23 is 0. ✅
const DEADZONE: int = 23
## ⚠️ benadering: XInput-trigger telt als digitale L/R-klik vanaf deze waarde.
const TRIGGER_FULL: float = 0.95

# --- Flick-drempels en vensters -------------------------------------------------------------
## Dash / smash horizontaal: 0.79 in Melee = 64/80 = 0.8 op het raster. ✅ (float ⚠️)
const SMASH_THRESHOLD: float = 0.8
## ⚠️ dash_smash_window: "binnen 2 frames" (teller < 2).
const SMASH_WINDOW: int = 2
## ⚠️ LENIENCY (Xbox-stick): venster voor dash/dashback/dash-dance in de grondstates. Melee gebruikt 2
## (SMASH_WINDOW, blijft voor smash-aanvallen); een echte Xbox-stick doet 2-4 frames over 0 -> vol.
## Langzaam duwen (>= 5 frames) blijft walk/tilt-turn.
const DASH_FLICK_WINDOW: int = 4
## Tap jump: stick-y >= 0.6625 (53/80) met teller < 4. ✅
const TAP_JUMP_THRESHOLD: float = 0.6625
const TAP_JUMP_WINDOW: int = 4
## ✅ waarde, ⚠️ nog niet gebruikt: Melee gebruikt hem in "sommige grondstates" (welke is onbekend).
const RELAXED_TAP_JUMP_THRESHOLD: float = 0.5625
## ⚠️ Short hop met tap jump: stick-y zakt tijdens jumpsquat onder deze waarde -> short hop.
const TAP_JUMP_RELEASE_THRESHOLD: float = 0.6625
## ⚠️ Fast fall: stick-y <= -0.6625 met teller < 4, en vy < 0.
const FAST_FALL_THRESHOLD: float = 0.6625
const FAST_FALL_WINDOW: int = 4
## ⚠️ LENIENCY: een omlaag-flick in de lucht blijft zoveel frames "geladen" en geeft fast fall zodra vy < 0
## wordt (short hop: de flick komt vaak vlak vóór de apex). Melee zelf: alleen flick binnen het venster zelf.
const FAST_FALL_BUFFER: int = 6
## ⚠️ AFWIJKING van Melee (speeltest 2, gebruiker wil het losser): fast fall mag ook tijdens het stijgen;
## de flick zet de val meteen in. false = Melee-gedrag (pas na de apex). Static var zodat tests beide kunnen draaien.
static var fast_fall_while_rising: bool = true
## ⚠️ Crouch: stick-y <= -0.6875 (55/80), ingehouden (geen venster).
const CROUCH_THRESHOLD: float = 0.6875
## ⚠️ Platform drop vanuit crouch: stick-y <= -0.6875 met teller < 4.
const PLATFORM_DROP_THRESHOLD: float = 0.6875
const PLATFORM_DROP_WINDOW: int = 4
## ⚠️ In special fall door een platform vallen als stick-y <= -deze waarde.
const PLATFORM_FALL_THROUGH_THRESHOLD: float = 0.6875
## ⚠️ Run-drempel (x58): Dash -> Run en Run blijft Run zolang stick_x*facing >= deze waarde.
const RUN_THRESHOLD: float = 0.62
## ⚠️ LENIENCY: tegen-de-run-in leunen start een RunTurn pas als het een flick is (>= SMASH_THRESHOLD) of
## dit aantal frames achtereen wordt vastgehouden. Voorkomt dat de terugveer-overshoot van een Xbox-stick
## (stick los -> kort even de andere kant op) een run-turnaround van 25+ frames triggert.
const RUN_TURN_DEBOUNCE: int = 5
## ⚠️ Turn-drempel (x34): elke stick-x tegen de kijkrichting buiten de deadzone draait om.
const TURN_THRESHOLD: float = 0.2875
## Teeter-walk: walk met |x| >= 0.75 loopt van de rand af, anders stopt hij. ✅
const TEETER_WALK_THRESHOLD: float = 0.75
## ⚠️ Walk-animatiedrempels (slow / middle / fast).
const WALK_MIDDLE_THRESHOLD: float = 0.5
const WALK_FAST_THRESHOLD: float = 0.8
## walk_stick_threshold 0.18 bestaat, maar ligt binnen de deadzone (onbereikbaar). ✅
const WALK_THRESHOLD: float = 0.18

# --- Analoge triggers ------------------------------------------------------------------------
## ✅ PlCo: lightshield begint rond deze waarde (M4).
const SHIELD_PRESS_THRESHOLD: float = 0.25
const ANALOG_SHOULDER_DEADZONE: float = 0.3
const Z_PRESS_ANALOG_VALUE: float = 0.35

## Teller-waarde als de as in de deadzone staat (Melee gebruikt een grote verzadigde waarde).
const TIMER_NEUTRAL: int = 255


## Ruwe stick (-1..1, y omhoog) -> integer -80..80, binnen de cirkel met straal 80.
static func quantize(raw: Vector2) -> Vector2i:
	var v: Vector2 = raw
	if v.length() > 1.0:
		v = v.normalized()
	var x: int = _snap(v.x)
	var y: int = _snap(v.y)
	# Afkappen richting nul kan nooit buiten de cirkel komen, maar float-epsilon veilig stellen.
	while x * x + y * y > GRID * GRID:
		if absi(x) >= absi(y):
			x -= signi(x)
		else:
			y -= signi(y)
	if absi(x) < DEADZONE:
		x = 0
	if absi(y) < DEADZONE:
		y = 0
	return Vector2i(x, y)


## |v| >= drempel, met een kleine marge zodat rasterwaarden (bv. 53/80 = 0.6625) exact meetellen.
static func reaches(v: float, threshold: float) -> bool:
	return absf(v) >= threshold - 0.000001


static func _snap(f: float) -> int:
	# Afkappen naar nul, met kleine epsilon zodat 1.0 -> 80 (niet 79).
	return int(f * GRID + signf(f) * 0.001)
