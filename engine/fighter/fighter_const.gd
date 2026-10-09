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

# --- Verdediging (M4). Zie docs/combat.md, "M4-implementatie". ---
## Shield-HP (Melee ✅ [W] Shield): max 60, slijt 0.28/frame bij vasthouden, herstelt 0.07/frame als je niet shieldt,
## na een shield break begint hij weer op 30.
const SHIELD_MAX_HP: float = 60.0
const SHIELD_DEPLETION: float = 0.28
const SHIELD_REGEN: float = 0.07
const SHIELD_BREAK_RESET_HP: float = 30.0
## Shield-schade = (damage + hitbox.shield_damage) × (0.65·(1 − a) + 0.7), a = Knockback.shield_norm(s):
## volle shield ×0.7 ✅ [W], lichtste shield ×1.35 (verificatie C17 "a + 0.7" met a = 0.65·(1 − norm)).
const SHIELD_DAMAGE_MULT: float = 0.7
const SHIELD_DAMAGE_LIGHT_EXTRA: float = 0.65
## Shield aan: analoge trigger >= dit (Melee analog_shoulder_deadzone 0.3 ✅; lightshield-normalisatie begint hier) of de digitale klik.
const SHIELD_ON_THRESHOLD: float = 0.3
## Shield-bubble: straal = shield_size_ratio · visual_height · (MIN + (1 − MIN)·hp/60) · (1 + LIGHT_GROW·(1 − a)).
## ⚠️ Melee: bubble krimpt met de HP en een lightshield is groter; exacte schaal niet gevonden.
const SHIELD_MIN_SCALE: float = 0.15
const SHIELD_LIGHT_GROW: float = 0.3
## GuardOn (opzetten) en GuardOff (loslaten). GuardOff 15 ✅ [W]; GuardOn 8 ⚠️ (minimale shield-tijd, niet geverifieerd).
const GUARD_ON_FRAMES: int = 8
const GUARD_OFF_FRAMES: int = 15
## Shield-pushback van de verdediger: gr_vel = PUSH_BASE + d · (0.65·(1 − a) + 0.3) · PUSH_PER_DAMAGE, max PUSH_MAX,
## remt met traction ×1. ⚠️ structuur (lightshield = meer pushback ✅ [W]), getallen gekozen.
const SHIELD_PUSH_BASE: float = 0.3
const SHIELD_PUSH_PER_DAMAGE: float = 0.15
const SHIELD_PUSH_MAX: float = 2.2
## Powershield: een digitale klik (BTN_SHIELD) die GuardOn start; een treffer binnen de eerste POWERSHIELD_WINDOW frames
## van GuardOn = geen shield-schade, geen shieldstun, geen pushback, geen hitlag voor de verdediger. Reflecteert niets.
## ⚠️ Melee: 4 frames voor projectielen (2 voor fysieke aanvallen volgens sommige bronnen); hier 4 voor alles.
const POWERSHIELD_WINDOW: int = 4
## Shield break: omhoog gelanceerd (ShieldBreak, vy ⚠️), landen -> ShieldBreakDown (⚠️ frames) -> Dizzy.
const SHIELD_BREAK_VY: float = 2.5
const SHIELD_BREAK_DOWN_FRAMES: int = 30
## Dizzy-duur (FuraFura) = max(DIZZY_BASE − percent, DIZZY_MIN): hoger percentage = korter. ⚠️ (Melee: afhankelijk van %;
## exacte formule niet gevonden; mashen verkort het hier niet).
const DIZZY_BASE: float = 400.0
const DIZZY_MIN: int = 120

# --- OoS-inputs (M4) ---
## Roll uit shield: x-flick (>= SMASH_THRESHOLD, teller < DASH_FLICK_WINDOW 4 ⚠️ leniency).
## Spotdodge: y-flick omlaag <= -SPOTDODGE_THRESHOLD met teller < SPOTDODGE_WINDOW. ⚠️
const SPOTDODGE_THRESHOLD: float = 0.7
const SPOTDODGE_WINDOW: int = 4
## Shield drop (op een platform, verse omlaag-flick, verificatie #20): vanilla alleen in de smalle band
## PLATFORM_DROP_THRESHOLD (0.6875) <= -y < SPOTDODGE_THRESHOLD ("notch"); UCF ook schuin omlaag met |x| >= dit. ⚠️
const UCF_SHIELD_DROP_MIN_X: float = 0.4

# --- Grab / throws (M4) ---
## Dash grab: hitboxes en totale duur DASH_GRAB_DELAY frames later (afspraak 2: +7), bereik × DASH_GRAB_REACH ⚠️.
const DASH_GRAB_DELAY: int = 7
const DASH_GRAB_REACH: float = 1.2
## Victim-positie: voeten op grab-tip + dit × visual_height van de gegrepen fighter (het lijf zit achter de hand). ⚠️
const GRAB_HOLD_BODY_RATIO: float = 0.1
## Frames na de grab voordat throw/pummel-input telt (Melee CatchPull). ⚠️
const GRAB_PULL_FRAMES: int = 4
## Grab-timer van de gegrepen fighter: BASE + PER_PERCENT · percent frames; elke mash-input (nieuwe knop of verse
## stickrichting) trekt er GRAB_MASH_FRAMES af. ⚠️ (Melee: afhankelijk van % en mashen verkort ✅ structuur; getallen gekozen)
const GRAB_TIMER_BASE: float = 90.0
const GRAB_TIMER_PER_PERCENT: float = 1.7
const GRAB_MASH_FRAMES: int = 6
## Throw-richting: stick (dominante as) >= dit, of een verse C-stick-input. ⚠️
const THROW_STICK_THRESHOLD: float = 0.6625
## Pummel: totale duur en het (0-based) frame waarop de damage valt (kan niet missen). ⚠️
const PUMMEL_FRAMES: int = 24
const PUMMEL_HIT_FRAME: int = 6
## Grab release (timer op): grond-release = beide GrabRelease (frames ⚠️), gegrepen fighter wordt weggeduwd (gr_vel ⚠️).
## Lucht-release (gegrepen in de lucht): gegrepen fighter springt omhoog weg en is direct actionable (Fall). ⚠️
const GRAB_RELEASE_FRAMES: int = 30
const GRAB_RELEASE_PUSH: float = 1.0
const GRAB_AIR_RELEASE_VY: float = 2.0

# --- Special-hook (Fighter.check_special / special_input) ---
## Up/down-B: stick-y (dominante as) >= dit; side-B: |stick-x| >= dit; anders neutral-B. ⚠️ (Melee-drempels niet nagelezen)
const SPECIAL_UPDOWN_THRESHOLD: float = 0.6625
const SPECIAL_SIDE_THRESHOLD: float = 0.6

# --- Taunt ---
## Standaardduur van een taunt in frames (Melee: ~80-100 per character) ⚠️. `taunt_frames` in character.json overschrijft (30..180).
const TAUNT_FRAMES: int = 80
const TAUNT_FRAMES_MIN: int = 30
const TAUNT_FRAMES_MAX: int = 180
## Tekstwolkje: verschijnt na dit aantal taunt-frames en verdwijnt zoveel frames vóór het einde. ⚠️ presentatie
const TAUNT_BUBBLE_IN: int = 4
const TAUNT_BUBBLE_OUT: int = 4
