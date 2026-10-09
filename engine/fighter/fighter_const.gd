class_name FighterConst
extends RefCounted
## Gedeelde constanten voor fighter-code.

## Marge voor float-vergelijkingen tegen stickdrempels.
const EPS: float = 0.000001

# --- Ledge / respawn (M2) ---
## ⚠️ Stick-y <= -deze waarde in de lucht voorkomt een ledge grab (Melee: x480, waarde onbekend).
const LEDGE_GRAB_DOWN_BLOCK: float = 0.6875
## ⚠️ Getup: stick richting de stage >= dit; stick omhoog >= LEDGE_UP_THRESHOLD.
const LEDGE_GETUP_THRESHOLD: float = 0.5
const LEDGE_UP_THRESHOLD: float = 0.6875
## ⚠️ Loslaten: stick omlaag of van de stage af >= dit.
const LEDGE_DROP_THRESHOLD: float = 0.6875
## ⚠️ Respawn-platform: max wachttijd (5 s), minimum voordat input telt, standaard invincibility (2 s).
const REBIRTH_MAX_FRAMES: int = 300
const REBIRTH_MIN_FRAMES: int = 20
const REBIRTH_INVINCIBLE_FRAMES: int = 120

# --- Gevecht (M3). Zie docs/combat.md, "M3-integratie". ---
## Smash-aanval met A: stick-flick (>= SMASH_THRESHOLD) met teller < dit venster. Melee/`SMASH_WINDOW` = 2;
## ⚠️ Xbox-leniency 4 (zelfde reden als DASH_FLICK_WINDOW: een Xbox-stick doet 3-4 frames over een flick).
const SMASH_ATTACK_WINDOW: int = 4
## C-stick: één as voorbij deze waarde (vorige frame eronder) = smash op de grond / aerial in de lucht. ⚠️
const CSTICK_THRESHOLD: float = 0.6625
## JC usmash: A in jumpsquat met stick-y >= dit (of C-stick omhoog). ⚠️ (= tap-jump-drempel)
const JC_USMASH_THRESHOLD: float = 0.6625
## Smash charge: de move blijft op dit move-frame (0-based) staan zolang A vast is, max SMASH_CHARGE_MAX frames.
## Damage × (1 + SMASH_CHARGE_BONUS · charge/SMASH_CHARGE_MAX) → ×1.3671 bij volle lading (Melee ✅ 1.3671, 60 frames ✅).
const SMASH_CHARGE_FRAME: int = 2
const SMASH_CHARGE_MAX: int = 60
const SMASH_CHARGE_BONUS: float = 0.3671
## Jab-combo: A opnieuw (nieuw ingedrukt) tijdens een jab zet de volgende jab klaar; die start zodra het
## jab-frame voorbij de laatste actieve frame + dit is. ⚠️
const JAB_COMBO_GAP: int = 1
## L-cancel: L/R/Z (of analoge trigger-druk) binnen 7 frames vóór de landing ✅. Lag = floor(landing_lag/2), min 1 ✅.
const LCANCEL_WINDOW: int = 7
## Analoge trigger telt als druk (L-cancel/tech) vanaf deze waarde (Melee analog_shoulder_deadzone 0.3 ✅).
const TRIGGER_PRESS: float = 0.3
## Tech: shield binnen 20 frames vóór het neerkomen ✅; na een druk 40 frames geen nieuw tech-venster (lockout) ⚠️.
const TECH_WINDOW: int = 20
const TECH_LOCKOUT: int = 40
## Tech-roll: stick-x >= dit bij het neerkomen. ⚠️
const TECH_ROLL_THRESHOLD: float = 0.5
## Tech in place / tech roll / getups vanaf de grond: duur, intangible (1-based) en afstand. Alles ⚠️.
const TECH_FRAMES: int = 26
const TECH_INTANGIBLE_END: int = 20
const TECH_ROLL_FRAMES: int = 40
const TECH_ROLL_INTANGIBLE_END: int = 20
const TECH_ROLL_DISTANCE: float = 28.0
const TECH_ROLL_MOVE_FRAMES: int = 30
## Missed tech: stuiteren (DownBound), liggen (DownWait, max 220 = x424 [N]), dan getups (roll 36, attack 50 [P]).
const DOWN_BOUND_FRAMES: int = 26
const DOWN_WAIT_MAX: int = 220
const GETUP_STAND_FRAMES: int = 30
const GETUP_STAND_INTANGIBLE_END: int = 22
const GETUP_ROLL_FRAMES: int = 36
const GETUP_ROLL_INTANGIBLE_END: int = 25
const GETUP_ROLL_DISTANCE: float = 26.0
const GETUP_ATTACK_FRAMES: int = 50
const GETUP_ATTACK_INTANGIBLE_END: int = 26
## Rebound na een clank op de grond. ⚠️
const REBOUND_FRAMES: int = 20
## Hitstun-pose: KB < MID = damage_low, < HIGH = damage_mid, anders damage_high. ⚠️
const DAMAGE_POSE_MID_KB: float = 30.0
const DAMAGE_POSE_HIGH_KB: float = 55.0
## ASDI omlaag: grounded, geen tumble, stick-y <= -dit op het laatste hitlag-frame -> blijft op de grond. ⚠️
const ASDI_DOWN_THRESHOLD: float = 0.7
## Grond-bounce: tumble-launch de grond in vanaf de grond -> vy wordt gespiegeld × dit. ⚠️
const GROUND_BOUNCE_FACTOR: float = 0.8
