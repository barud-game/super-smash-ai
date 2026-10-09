# Melee-physics referentie

Alles wat we van Melee nabouwen, met de waarden die we gebruiken.
Zekerheid per punt: ✅ = bron gevonden en consistent, ⚠️ = bron onduidelijk, tegenstrijdig of alleen uit geheugen/afleiding.
Bronnen staan als [S#] — zie de lijst onderaan `docs/melee-referentie.md`. Per-character cijfers staan daar in tabel B.

Conventie: richting-/stickwaarden zijn genormaliseerd (raster/80). Snelheden in Melee-units per frame, accel in units/frame².

## Basis
- 60 frames per seconde. Alle timings in frames. ✅
- Posities/snelheden in **Melee-units** (per frame). Renderen via `UNIT_TO_PX`.
- Frame-volgorde in de decompilatie (doldecomp/melee) per fighter-state: Anim → IASA (input-checks/transities) → Phys (snelheid/accel) → Coll. Gravity en accel werken op `self_vel` in de Phys-stap. [S12] ✅

## Input (stick)
Geïmplementeerd in `engine/input/` (M0). Constanten staan in `MeleeStick`.

### Raster en deadzone
- Stick is een cirkel met straal 80 (X²+Y² ≤ 6400); waarden −80..80 per as. [S6] ✅ — code: `GRID = 80` klopt.
- Deadzone: in PlCo.dat `horizontal/vertical_stick_deadzone = 0.28`, per as apart. [S12] ✅ 0.28×80 = 22,4, dus op het raster is |waarde| ≥ 23 actief en < 23 nul.
  **Code (`DEADZONE = 23`, |v| < 23 → 0) komt hiermee overeen.** (Het ruleset-document noemt ≤ 0.275 = 22/80 als deadzone, zelfde grens. [S6])
- Er is een tweede, lagere `stick_smash_deadzone = 0.25` (PlCo) die in de praktijk door de 0.28 wordt overschaduwd. [S12] ✅ — geen aparte implementatie nodig.
- Echte hardware geeft 0..~100+ raw; UCF/ruleset normaliseren naar dit raster. Wij starten vanuit XInput → cirkel clampen is voldoende. ✅

### Hoe Melee flicks/“smash” detecteert (afwijkt van onze code)
Melee houdt per stickas een **teller “frames sinds de stick de deadzone verliet”** bij (`active_timer.lstick.x/.y`). Een actie triggert als de stickwaarde de drempel haalt **terwijl die teller kleiner is dan het venster**. Er is dus **geen** “van onder een lage drempel (0.3) naar boven”-voorwaarde. [S12] ✅ (mechanisme)

| Input | Drempel (as) | Venster (frames sinds deadzone verlaten) | Zekerheid |
|---|---|---|---|
| Dash / smash (horizontaal) | `dash_smash_stick_threshold`: 0.79, op raster = 64/80 = 0.8 | `dash_smash_window`: 2 (≈ “binnen 2–3 frames”) | drempel ⚠️ (decomp noemt de waarde niet; ruleset noemt 0.8 voor dash [S6]), venster ⚠️ |
| Tap jump (stick omhoog) | `tap_jump_threshold` = **0.6625** (= 53/80) | `tap_jump_window` = **4** | ✅ [S12] |
| Tap jump in sommige grondstates | `relaxed_tap_jump_threshold` = **0.5625** | idem 4 | ✅ [S12] |
| Tap-jump loslaten (short hop met stick) | `tap_jump_release_threshold`: stick-y valt eronder tijdens jumpsquat | — | waarde ⚠️ |
| Fast fall | stick-y ≤ −`x88` én stick-flick < `x8C` frames geleden, en vy < 0 | zie hieronder | waarde ⚠️ (≈ 0.65–0.6625; ruleset toont 0.65/0.6625 als grens voor neer/omhoog [S6]) |
| Crouch | stick-y < −`x90` | geen venster (ingehouden) | waarde ⚠️ (≈ 0.6875, afgeleid uit ruleset [S6]) |
| Platform drop | stick-y ≤ −`x464` en flick < `x468` frames; óf shield (L/R) vast + onder-richting | zie Platforms | waarde ⚠️ |
| Walk-drempel | `walk_stick_threshold` 0.18 (onbereikbaar door deadzone 0.28) | — | ✅ [S12] |
| Teeter-walk | 0.75 | — | ✅ [S12] |

- **Geïmplementeerd (M1):** het oude `SMASH_LOW = 0.3`-mechanisme is vervangen door Melee's teller. `InputHistory.stick_timer_x/y()` = frames sinds de as de deadzone verliet (0 op het eerste frame buiten de deadzone; **per richting**, dus van links naar rechts in één frame reset de teller ook — nodig voor dash-dance; in de deadzone `TIMER_NEUTRAL` = 255). `flick_x/flick_y(drempel, venster)` = |as| ≥ drempel én teller < venster. De flick moet dus *vanuit de deadzone* beginnen en snel genoeg de drempel halen; langzaam voorbij de drempel geeft tilt/walk/crouch. ⚠️ Of Melee de teller ook reset bij een tekenwissel zonder deadzone-frame is niet in de decomp nagelezen; aangenomen van wel.
- Alle drempels/vensters staan als constanten in `MeleeStick` (`engine/input/melee_stick.gd`). Gekozen ⚠️-waarden: dash/smash 0.8 met venster 2 (grondstates: `DASH_FLICK_WINDOW` 4, zie M1-speeltestfeedback); fast fall 0.6625 / 4; crouch 0.6875 (ingehouden); platform drop 0.6875 / 4; door platform vallen in special fall 0.6875; tap-jump-loslaten (short hop met stick) 0.6625; run-drempel (`x58`) 0.62; turn-drempel (`x34`) = deadzone; walk-animatie slow < 0.5 ≤ middle < 0.8 ≤ fast. `RELAXED_TAP_JUMP_THRESHOLD` (0.5625) is gedefinieerd maar nog niet gebruikt (welke grondstates hem gebruiken is onbekend).
- `SMASH_THRESHOLD = 0.8` ligt op het raster gelijk aan de echte drempel (0.79 → 64/80 = 0.8). ✅ praktisch correct, ⚠️ exacte float. Vergelijkingen via `MeleeStick.reaches()` (marge 1e-6) zodat rasterwaarden als 53/80 = 0.6625 exact meetellen.
- **Eén flick = één tap jump:** de fighter onthoudt welke stick-omhoog-beweging al een sprong gaf, zodat dezelfde flick (teller nog < 4 na een 3-frame jumpsquat) geen double jump geeft. ⚠️ Melee doet dit op een eigen manier (niet nagelezen); effect is hetzelfde.
- Analoge trigger: `shield_press_threshold = 0.25`, `analog_shoulder_deadzone = 0.3`, `z_press_analog_value = 0.35`. [S12] ✅ — lightshield begint rond 0.25–0.3. Air dodge, tech en L-cancel gebruiken de **digitale** L/R-bit (hardware “klik”, volledig ingedrukt). `TRIGGER_FULL = 0.95` is een redelijke benadering voor XInput (⚠️ er bestaat geen vaste Melee-analoge drempel voor de digitale klik). Powershield-venster: `powershield_input_window` frames na trigger ≠ 0 (waarde onbekend ⚠️; M4 gebruikt 4 frames na de digitale klik).
- Historie: ringbuffer van 32 `InputFrame`s per speler (`InputHistory`) met `pressed/released/held`.
- Layout (XInput): A=attack, X=special, Y/B=jump, LT/RT=shield, RB=Z, rechterstick=C-stick, Start=start. Toetsenbord speler 1: WASD=stick, pijltjes=C-stick, J=A, K=special, Space=jump, L=shield, I=Z.
- Schaal: `UNIT_TO_PX = 7.0` (`engine/units.gd`); ±85 units = 1190 px.

## Grond
Toestandsvolgorde dash/run/brake: Wait → (flick) Dash → Run → (stick los) RunBrake → Wait. [S12] ✅

**Gedeelde rekenregel voor dash en run** (`CalcGroundAccel_DashRun`, `getAccelAndTarget`) [S12] ✅:
```
accel  = stick_x * dash_accel_mul + sign(stick_x) * dash_accel_base     # "additional" en "base" in tabel
target = stick_x * dash_max_velocity                                     # = run speed bij volle stick
if gr_vel * accel >= 0 en gr_vel + accel voorbij target:
    accel = -traction  (begrensd zodat we niet voorbij target schieten)    # daarom remt initiële dash terug naar run speed
gr_vel += accel  (nooit voorbij ground_max_horizontal_velocity)
```
- **Initial dash**: bij het betreden zet Melee de snelheid direct op `±dash_initial_velocity` (staat je gr_vel al in dezelfde richting dan wordt het verschil toegepast; tegen de richting in begin je gewoon op de initiële snelheid). Op de allereerste frame wordt géén accel toegepast. Daarna elke frame bovenstaande formule. Is initial dash > run speed (Fox 1.9 < 2.2 niet; Falco 1.9 > 1.5 wel), dan remt traction naar run speed. [S1, S12] ✅
- **Duur initial dash** is per character (animatielengte): Fox/Falco 11, Sheik 7, Pikachu/Bowser/Jigglypuff 13, Falcon/Marth/Peach/Ganondorf 15 frames. [S1] ✅ Daarna: stick nog ≥ run-drempel (`x58`, ⚠️ waarde) vooruit → Run; anders Wait/stand.
- **Dash-dance**: tijdens de dash-animatie kan een omgekeerde flick (zelfde drempel/venster als dash) opnieuw `Dash_Enter` in de andere richting geven (Turn-smash-pad). Venster in animatieframes: `x4C` (⚠️ waarde); pivot (omkeren met 1 frame stilstaan) bestaat: “1 frame” pivot-turn. [S1] ✅ (pivot 1 frame), ⚠️ exacte DD-framevenster. Moonwalken: achterwaartse stick tijdens de dash verandert target_vel (formule hierboven met negatieve stick).
- **Run**: zelfde formule met `accel` tapering (`run_accel_taper_gain`) ⚠️ (waarde onbekend; Fox/Falco bereiken run speed na ~initial dash + enkele frames). Run-snelheid = `stick_x * dash_max_velocity`.
- **RunBrake (skid)**: start als |stick_x| < run-drempel `x58`. Per frame alleen wrijving (`traction × run_dash_turn_friction_multiplier`, multiplier = 1.0 in PlCo ✅). Duur = min(animatie, `max_run_brake_frames` per character ⚠️ waarde). Crouchen kan na 1 frame RunBrake. [S1, S12] ✅ (structuur), ⚠️ aantallen.
- **Run turnaround (TurnRun)**: omkeren tijdens run is traag (tot 51 frames bij Marth), alleen jump onderbreekt. [S1] ✅
- **Traction / friction op de grond**: elke frame zonder aandrijving `Deaccel`: `gr_vel` richting 0 met `traction`; **als |gr_vel| > walk_max_vel is de wrijving ×`friction_when_above_walk_speed` = 2.0** (alleen in Wait/Turn/Landing-achtige states, **niet** in Dash en RunBrake). [S3, S12] ✅ Dit verklaart de wavedash-lengte (voorbeeld: Peach traction 0.1 → snelheid 1.0 wordt 0.8). 
- **Walk**: target ≈ `stick_x × walk_max_vel`, accel `walk_accel_base + stick×walk_accel_mul` met taper (`walk_accel_taper_gain`) ⚠️ (details/waarden niet gevonden; walk max per character in tabel). Er zijn drie loopanimatie-snelheden (slow/mid/fast) op basis van de stick. [S4] ✅
- **Crouch**: stick-y < −drempel (⚠️ ≈0.6875) → Squat; cancelt niet de wrijving. Kan direct na 1 frame RunBrake.
- **Turn (staand omdraaien)**: stick tegen kijkrichting (`x34`-drempel ⚠️) → Turn; `standing_turn_frames` per character (⚠️ niet verzameld); smash-/tilt-inputs tijdens de turn worden doorgezet in IASA. [S12] ✅ (structuur)

## Springen
- **Jumpsquat** (frames, NTSC): Fox/Pikachu/Sheik 3; Falcon/Marth 4; Falco/Peach/Jigglypuff 5; Ganondorf 6; Bowser 8. [S2] ✅ (complete tabel in tabel B)
- Jump-input: knop X/Y óf stick-y ≥ tap-jump-drempel binnen venster (zie Input). Stick-omhoog tijdens run/dash is dus “tap jump”; C-stick omhoog ook (`JumpInput_CStick`). [S12] ✅
- **Short hop vs full hop**: tijdens elk frame van de jumpsquat wordt gecontroleerd of de jump-knop nog vastgehouden wordt (bij tap-jump: of stick-y onder de loslaat-drempel is gezakt). Eenmaal losgelaten → short hop. De jump begint zodra animatieframe ≥ `jump_startup_time` (= jumpsquat). Venster voor short hop = **jumpsquat − 1 frames** (Fox 2, Bowser 7). Stickpositie beïnvloedt hoogte niet. [S2, S5, S12] ✅
- **Take-off snelheid**:
  - `vy = jump_v_initial_velocity` (full hop) of `hop_v_initial_velocity` (short hop); waarden in tabel B. De formule hoogte = Σ(v0 − g·n) tot ≥ 0 reproduceert de gepubliceerde hoogtes exact (Fox FH 31.28, SH 10.65; gecontroleerd voor alle 10 characters). ✅
  - `vx = clamp( gr_vel × ground_to_air_jump_momentum_multiplier + stick_x × jump_h_initial_velocity , ±jump_h_max_velocity )`. [S12] ✅ (formule). **De drie character-constanten (g2a-multiplier, h-initial, h-max) zijn niet in tekstbronnen gevonden** ⚠️ — alleen in de Pl*.dat binaries; zie lijst “nog open”.
  - Op de eerste frame van een grondsprong werkt gravity niet; bij een double jump wel. [S2] ✅
- **Double jump (air jump)**: `vy = jump_v_initial_velocity × air_jump_v_multiplier` (multipliers in tabel B); `vx = stick_x × air_jump_h_multiplier` — het horizontale momentum wordt **vervangen** (niet opgeteld). Alleen als `jumps_used < max_jumps`. [S12, S7] ✅ (formule), ⚠️ `air_jump_h_multiplier`-waarden niet gevonden. 
- **Aantal jumps**: 1 luchtsprong voor iedereen behalve Jigglypuff (5, met afnemende force 1.65/1.59/1.47/1.36/1.25 en multiplier 0). Peach heeft een float i.p.v. extra jump na de eerste (niet nagebouwd). [S7] ✅

## Lucht
- **Gravity**: elke frame `vy −= gravity`, begrensd op `−terminal_velocity`. Per character (tabel B). [S12, S8] ✅
- **Fast fall**: mag zodra `vy < 0` (dus ná de apex) en een neerwaartse stick-flick (zie Input) wordt gedaan. Effect: `vy = −fast_fall_velocity` direct, en blijft zo (kan niet terug) tot landing/hit; blijft behouden door bijv. special fall. [S12, S9] ✅ — drempel/venster ⚠️.
- **Air drift** (`CalcSelfAccel_AccelToVelClamped`, `DriftFrom`) [S12] ✅:
  ```
  accel  = stick_x * air_accel_additional + sign(stick_x) * air_accel_base
  target = stick_x * max_air_speed        # air_drift_max
  als vx voorbij target zou komen:  accel = -air_friction   (beperkt zodat je niet voorbij target schiet;
                                                            nooit voorbij air_max_horizontal_velocity)
  als stick_x == 0:  vx beweegt met air_friction richting 0
  ```
  Air friction werkt dus alleen als je niet actief stuurt (of in hitstun). Boven `max_air_speed` (bv. door wavedash/knockback) remt de lucht met `aerial_friction_oob` (PlCo, waarde ⚠️). [S10] ✅
- Waarden: air accel base/additional, max air speed, air friction per character in tabel B.

## Air dodge / wavedash
- Invoer: digitale L of R in de lucht, niet tijdens tumble/hitstun. [S11] ✅
- Gedrag (decomp `EscapeAir`) [S12] ✅ structuur:
  - Bij start: zijn |stick_x| én |stick_y| onder `escapeair_deadzone` → `vel = (0,0)`; anders `vel = escapeair_force × (cos θ, sin θ)` met θ = hoek van de stick (volle 360°, de stick-magnitude doet niet mee).
  - Elke frame: `vel *= escapeair_decay` (op x én y), totdat een animatie-event `skip_decay` zet; daarna normale val (gravity/drift als Fall).
  - Waarden: `escapeair_force` = **3.1**, `escapeair_decay` = **0.9** — ⚠️ uit geheugen/community, structuur uit decomp bevestigd, getal zelf niet in tekstbron gevonden.
- **Duur**: animatie 49 frames (Mewtwo 39); intangible frames **4–29** (Bowser 3–29; Peach/Zelda 4–19). Ledge grabben pas na de animatie. [S11] ✅ (Gebruiker-aanname “duur” komt dus op 49; effectieve vrijheid daarna via special fall.)
- **Na afloop**: **special fall** (helpless, `FallSpecial`): vallen met normale gravity/fast fall, drift beperkt tot `air_drift_max × mobility` (mobility via `x340`, ⚠️ waarde), geen acties behalve sturen. [S12] ✅ structuur.
- **Landing (wavedash/waveland)**: grondcontact tijdens air dodge → `LandingFallSpecial` met **10 frames** landing lag; horizontale snelheid blijft behouden. [S13] ✅ (10 frames).
- **Snelheidsomzetting bij landing**: `gr_vel = self_vel.x` (verticale snelheid vervalt), begrensd op `ground_max_horizontal_velocity`; jumps worden hersteld. Daarna per frame de Landing-wrijving: traction, **×2 zolang |gr_vel| > walk_max_vel**. Geen kracht-aan/uit. [S12, S3] ✅
- Maximale wavedashlengte bij een neerwaartse hoek ≈ **17.1°** onder horizontaal (SmashWiki); (de ruleset noemt 27°–73° als stickhoek-bereik voor “airdodge angles” bij digitale input, geen engine-waarde). [S13, S6] ✅
- Wavedash = jumpsquat (3–8 frames per character) → direct air dodge. Karakters met hoge traction glijden korter, hoge walk speed verdubbelt de wrijving vaker (langer glijden). [S3, S13] ✅

## Landing
- **Normale landing** (`Landing`, `normal_landing_lag`): per character, meestal 4 frames. ⚠️ (waarden niet in SmashWiki-tabellen gevonden; “4” uit gedeeltelijk geheugen).
- Landing in **special fall**: lag via `LandingFallSpecial`; vanuit air dodge 10 frames (zie boven); landing lag bij “helpless” na specials is per move (vaak 30 frames, ⚠️ niet geverifieerd).
- **Aerial landing lag**: per aerial en per character (`landingair{n,f,b,hi,lw}_lag`); wordt bij de landing als animatiesnelheid uitgedrukt. [S12] ✅
- **L-cancel**: L, R of Z ingedrukt **tot 7 frames vóór** de landing (in hitlag verruimd: nog tot 6 frames erna). Effect: landing-animatie op dubbele snelheid → lag **gehalveerd, naar beneden afgerond** (minimaal 1). [S14, S12] ✅ (decomp: `lag / 2.0`, minimum 1).
- Landen reset de jumps, `gr_vel = vx` (zie boven).

## Platforms
- Landen: op een pass-through platform land je als je valt (vy ≤ 0) en je stick-y niet onder de platform-landdrempel `x25C` zit (omlaag houden laat je er doorheen vallen in special fall). [S12] ✅ structuur, ⚠️ waarde.
- **Doorzakken (platform drop)**: stick omlaag-flick (≤ −`x464`, binnen `x468` frames na de deadzone) terwijl je op een platform staat, óf L/R vast + omlaag. Zet `vy = x46C` (kleine neerwaartse impuls) en schakelt “floor skip” aan; daarna normale Fall. [S12] ✅ structuur, ⚠️ getallen (verwacht ≈ −0.6625 en ~ 3–4 frames; niet gevonden).
- Springen door platform omhoog kan altijd (alleen als bovenop landen vereist vy ≤ 0).

## Ledge (bronnen; implementatie zie "M2-implementatie" onderaan)
- **Grab-conditie**: ledge-grab-flag van de collision (sweetspot-boxen voor/achter het hoofd per character); je kijkt de ledge in (anders niet, behalve bv. Falcon Dive/Spinning Kong); **niet** als stick-y ≤ −`x480` (omlaag houden voorkomt grab). [S15, S12] ✅ structuur, ⚠️ box-afmetingen en `x480`.
- **Snap**: positie wordt elke frame vastgezet op de ledge-positie met per-character offset (`ledge_snap_x/y/height`) ⚠️ waarden niet verzameld.
- **Invincibility**: **30 frames + de grab-animatie (7 frames; Link 3)** intangible bij grabben. Intangibility blijft behouden bij loslaten (ledgestall). [S15] ✅
- **Max hang**: 11 s onder 100%, 8 s vanaf 100%. [S15] ✅
- **Bezet**: staat er al iemand op dezelfde ledge, dan wordt de eerste eraf geduwd (“ledge steal”) als de ander grabt, of de grab faalt — de decomp geeft afhandeling via `ft_80082E3C` ⚠️ (details niet geverifieerd).
- **Regrab/cooldown**: `ledge_cooldown` (frames, PlCo) na loslaten ⚠️ waarde niet gevonden; een community-bron noemt **54 frames** lock na geraakt worden. [S16] ⚠️. Melee heeft géén afnemende regrab-invincibility zoals Ultimate. [S15] ✅
- **Opties vanaf de ledge**: getup (neutraal), roll, attack, jump (intangible tijdens het begin), drop. Framedata niet verzameld ⚠️.

## Knockback (Melee-formule)
Deze sectie is in deze ronde niet opnieuw geverifieerd; veldnamen in de decompilatie bevestigen wel `knockbackFrameDecay` en `kb_*`-constanten in PlCo. ⚠️
```
KB = ((((p/10 + p*d/20) * 200/(w+100) * 1.4) + 18) * g/100) + b
```
- `p` = percentage ná de hit, `d` = damage van de hit, `w` = weight, `g` = knockback growth, `b` = base knockback.
- Hitstun = `floor(KB * 0.4)` frames.
- Lanceersnelheid = `KB * 0.03`, neemt af met 0.051 per frame.
- Hitlag ⚠️ = `floor((d/3 + 3) * multiplier)` frames.
- DI: tot 18° verandering van de lanceerhoek.
- Weight-waarden (NTSC) voor de formule staan in tabel B.

## Samenvatting: code in `engine/input/` t.o.v. Melee
| Constante | Code | Melee | Oordeel |
|---|---|---|---|
| `GRID` | 80 | cirkel straal 80 | ✅ correct |
| `DEADZONE` | 23 (per as, <23 → 0) | 0.28 per as ⇒ ≥ 23/80 actief | ✅ correct |
| `SMASH_THRESHOLD` / `SMASH_WINDOW` | 0.8 / 2 | 0.79 ⇒ 64/80 = 0.8 op raster; venster ≈ 2 | ✅ drempel praktisch correct (⚠️ float), ⚠️ venster |
| flick-detectie | teller “frames sinds deadzone verlaten” < venster (`InputHistory`) | idem | ✅ zelfde mechanisme sinds M1 (`SMASH_LOW` verwijderd) |
| `TAP_JUMP_THRESHOLD` / `TAP_JUMP_WINDOW` | 0.6625 / 4 | idem | ✅ |
| overige stickdrempels | zie Input-sectie | deels onbekend | ⚠️ |
| `TRIGGER_FULL` | 0.95 | digitale hardware-klik; analoog shield vanaf 0.25–0.3, Z-analoog 0.35 | ⚠️ benadering |

## M1-implementatie (`engine/fighter/`)
Status: gebouwd en headless getest (`tests/test_movement.gd`, 286 checks). Gevoel met controller nog te testen.

### Opbouw
- `Fighter` (`fighter.gd`, Node2D): registreert zich bij `Sim`, leest `InputManager.history(player)` (tests geven een eigen `InputHistory`), houdt `pos`/`vel`/`gr_vel` in Melee-units bij. Node-positie (px) is alleen presentatie.
- `FighterState` (`fighter_state.gd`): basis met `anim()`, `iasa()`, `phys()`, `coll()` + flags (`is_grounded`, `stops_at_edge`, `lands_on_platforms`, `on_land`, `intangible`, `pose`). Eén class per state in `states/`. Nieuwe states (Guard, Attack*, Cliff*) erven hiervan en gaan erbij met `Fighter.register_state()`; gedeelde interrupt-checks staan als `check_*()` op `Fighter` (zoals de `ftCo_*_CheckInput`-functies in Melee), dus een aanval/shield-check wordt één extra regel in de betreffende `iasa()`.
- `FighterStats` (`fighter_stats.gd`, Resource): alle movement-attributen (tabel B1/B2 + geschatte ⚠️-velden), met `jump_height(v0)`.
- Presets: `archetypes/*.tres`, lijst in `archetypes.gd` (`Archetypes.IDS`).
- Tap jump per speler: `Settings.tap_jump_enabled(player)` als die autoload bestaat, anders aan; `Fighter.tap_jump_override` voor tests.

### Frame-volgorde (zoals Melee: Anim → IASA → Phys → Coll)
Per `sim_tick`: `state_frame += 1` → `anim()` (tijd-overgangen: jumpsquat klaar, landing lag op, einde animatie) → `iasa()` van de state die er dán is (een state die in `anim()` begon krijgt dus op hetzelfde frame zijn IASA: na landing lag ben je op dat frame actionable) → `phys()` → `coll()` → blast zone → visual. `state_frame` = 0 op het frame dat een state begint; een state van N frames beslaat frames 0..N−1.
- Grondsprong: KneeBend begint op het input-frame (frame 0); op frame `jumpsquat` zet `anim()` de sprong in en draait de IASA van Jump nog op dat frame. Daardoor kan een air dodge op het eerste luchtframe (frame-perfecte wavedash) en landt die direct.
- Jump: eerste frame geen gravity/drift (✅ Melee), dus hoogte = Σ(v0 − g·n): de tests reproduceren de full/short-hop-hoogtes van Fox, Marth, Ganondorf, Peach en Pikachu tot op 0.01.
- JumpAerial: gravity en drift werken al op frame 0 (✅).

### States
| State | Pose | Kern | Interrupts (IASA) |
|---|---|---|---|
| Wait | idle | traction, ×2 boven walk | jump, dash/smash-turn, squat, turn, walk |
| Walk (Slow/Middle/Fast) | walk | accel naar stick·walk_max ⚠️ | jump, dash, squat, turn; stick los → Wait |
| Dash | dash | gr_vel = ±initial dash, frame 0 geen accel, dan dash/run-formule | jump, omgekeerde dash-flick → Turn(smash) (dash-dance), venster 4 ⚠️ |
| Run | run | dash/run-formule | jump; terug → RunTurn; < run-drempel → RunBrake |
| RunBrake | skid | traction ×1 | jump; dash-flick → Dash/Turn-dash ⚠️; squat vanaf frame 1; echte terug-input → RunTurn |
| Turn (tilt/smash) | turn | facing direct om; traction ×2-regel | jump; smash-turn frame 1 → Dash of pivot (actionable); UCF-dashback; squat |
| RunTurn | skid → turn | remmen met traction tot 0, omdraaien, dan run-accel | jump |
| Squat / SquatWait / SquatRv | crouch | traction | jump, platform drop; SquatRv = Wait-interrupts |
| KneeBend | jumpsquat | traction; short-hop-check frames 1..js−1 | (sprong in `anim`) |
| Jump (F/B) | jump | ground→air-formule; vy < 0 → Fall | air dodge, double jump |
| JumpAerial (F/B) | jump_aerial | momentum vervangen; 30 frames ⚠️ dan Fall | air dodge, double jump |
| Fall | fall / fastfall | gravity/terminal, fast fall, air drift | air dodge, double jump |
| EscapeAir | airdodge | 3.1·(cos,sin) ⚠️, ×0.9 tot frame 30 ⚠️, 49 frames, intangible 4–29 | — |
| FallSpecial | fall / fastfall | helpless, drift × mobility ⚠️ 1.0, omlaag = door platforms | — |
| Landing | land | normal_landing_lag ⚠️ 4 | (→ Wait) |
| LandingFallSpecial | wavedash / landfall | 10 frames, gr_vel = vx, traction ×2 boven walk | (→ Wait) |

Platform drop gebruikt Fall (geen aparte Pass-state); van de rand af gaat ook naar Fall (luchtsprong blijft beschikbaar, zoals Melee).

### UCF
- **Dashback:** vanilla Melee: leest het eerste frame van een terugflick nog in het tilt-gebied, dan wordt het een tilt-turn waar je niet uit kunt dashen. UCF (aan, `Fighter.ucf_dashback`): haalt de stick op Turn-frame 1 alsnog ≥ 0.8 met teller < 2, dan alsnog Dash. Getest: met UCF Dash, zonder UCF Turn.
- Shield drop (UCF): gebouwd in M4, zie "M4-implementatie" hieronder.

### ECB en grond (keuze)
- **ECB = diamant** met het onderpunt op `pos` (voeten), bovenpunt op `ecb_height`, zijpunten op `ecb_mid_y` ± `ecb_half_width` (per preset ⚠️; zichtbaar met F2). Voor M1 doet alleen het **onderpunt** mee: landen = het onderpunt kruist een segment van boven naar beneden met vy ≤ 0 (lijnstuk van vorige naar nieuwe positie, hoogste segment wint). Geen muren/plafonds nog. Melee verschuift de ECB-onderkant in de lucht per animatie omhoog; dat doen we (nog) niet ⚠️ — gevolg: landen gebeurt exact op voethoogte.
- Op de grond: `x += gr_vel` langs het segment (y = segmenthoogte; schuine segmenten via interpolatie, aansluitende segmenten worden gevolgd). Aan de rand: `stops_at_edge()` per state. Stoppen: Wait, Walk met |x| < 0.75 (teeter-walk ✅), Turn, Squat*, KneeBend. Eraf: Dash, Run, RunBrake, RunTurn, Walk ≥ 0.75, Landing, LandingFallSpecial (wavedash van de rand af); zie "Grondstates aan de rand". Teeter-state sinds M2.
- Pass-through platforms: landen alleen van boven en met vy ≤ 0; in FallSpecial niet als stick-y ≤ −0.6875. Platform drop zet `ignore_platform` tot je 0.5 unit onder het platform bent.
- Stage-interface: `get_ledges()` (optioneel, M2), `get_ground_segments()` (objecten of dictionaries met `a`, `b`, `type`: `StageSegment.Type` 0/1 of `"solid"`/`"platform"`), `get_blast_zone()` (Rect2, position = links/onder), optioneel `get_respawn(i)`. Sandbox-stub: `scenes/sandbox_stage.gd`.
- Blast zone: buiten de Rect2 → `blast_ko`-signaal en respawn-platform (zie M2-implementatie).


### Speeltest-feedback M1 (Xbox-controller): leniency-keuzes
Reproductie in `tests/test_movement.gd` (sectie "Xbox-stickprofielen": flicks van 1-4 frames, 0-2 deadzone-frames bij omklappen, terugveer-overshoot). Alle ⚠️ hieronder zijn bewuste leniency-keuzes, niet Melee-waarden; constanten staan in `MeleeStick`.
- **Dash-venster `DASH_FLICK_WINDOW = 4`** (Melee/`SMASH_WINDOW` = 2, blijft voor smash-aanvallen). Oorzaak "dash-dance werkt niet": een Xbox-stick doet 3-4 frames over 0 → vol, venster 2 liet die flicks niet slagen (0/8 dashes bij 3-4-frames flicks). Langzaam duwen (≥ 5 frames) geeft nog steeds Walk / tilt-turn.
- **Dash uit Turn in elke frame:** een verse dash-flick in de kijkrichting geeft altijd Dash (smash-turn én, met `ucf_dashback`, tilt-turn). Voorheen werd een tilt-turn (11 frames) alleen op frame 1 gedasht: na een dash-stop veert de Xbox-stick een paar frames de andere kant op → Turn → opnieuw dashen lukte niet ("momentum kwijt, lastig terug te krijgen").
- **Dash uit RunBrake:** flick vooruit → Dash, flick achteruit → Turn(smash) → Dash (dashback tijdens skid). Wait/Walk/Dash hadden dit al.
- **Fast fall-buffer `FAST_FALL_BUFFER = 6`:** een omlaag-flick (zelfde drempel/venster als eerst) in de lucht blijft 6 frames "geladen" en geeft fast fall zodra vy < 0 wordt, ook als de stick al is teruggeveerd. Oorzaak: bij een short hop duurt de stijging maar ~10 frames en een tik valt vaak vlak vóór de apex; de check eiste dat vy < 0 én de flick (venster 4) tegelijk waar waren, dus een tik 4+ frames vóór de apex was verloren. Melee-gedrag (flick ná de apex) blijft werken; een flick ver vóór de apex of stick-omlaag-vasthouden geeft nog steeds geen fast fall. Buffer wordt gewist bij het verlaten van de grond en bij een double jump.
- **Run-turnaround (`Fighter.run_turn_intent()`, `RUN_TURN_DEBOUNCE = 5`):** oorzaak: de terugveer-overshoot van de Xbox-stick na het loslaten van de stick (even 0.3-0.6 de andere kant op) startte in Run/RunBrake direct een RunTurn (25+ frames, onderbreekbaar alleen met jump) en draaide de fighter om terwijl de speler wilde stoppen. Nu start RunTurn bij een flick tegen de run in (≥ 0.8) of na 5 frames vastgehouden terug-duw; anders gewoon RunBrake. Melee's RunTurn-duur (traag, tot 51 frames bij Marth) is ongewijzigd.
  - RunTurn is nu onderbreekbaar (alle ⚠️): voor het omdraaien stick weer vooruit → Run, stick neutraal → RunBrake (facing blijft); een nieuwe dash-flick (begonnen ná het binnenkomen) → Dash/Turn-dash; na het omdraaien meteen Run zodra de stick vooruit staat (niet wachten op `run_turn_frames`).

### Overige ⚠️-keuzes in M1
- Dash-dance gaat via een smash-turn van 1 frame (Dash → Turn(smash) → Dash; venster 4, zie Speeltest-feedback); pivot = smash-turn waarbij de stick op frame 1 al terug is (rest van de turn actionable, momentum glijdt met de traction-×2-regel).
- Dash-enter: is gr_vel in de dashrichting al groter dan initial dash, dan blijft die behouden.
- Stick los tijdens de dash: de dash/run-formule met stick 0 remt met traction (target 0).
- Run-accel zonder `run_accel_taper` (onbekend): zelfde formule als dash.
- RunTurn: remt met traction (×1), draait om bij gr_vel = 0, versnelt daarna met de run-formule; einde na ≥ `run_turn_frames` → Run (stick vooruit) of Wait.
- Tilt-turn duurt `turn_frames` = 11 en is (behalve via UCF op frame 1) niet te dashen; smash-turn is na frame 1 actionable.
- Walk: `walk_initial_velocity × |stick|` als beginsnelheid, dan `walk_acceleration` per frame.
- KneeBend met tap jump: short hop als stick-y tijdens frames 1..js−1 onder 0.6625 zakt.
- Platform drop: vy start op 0 (Melee `x46C` onbekend).
- Air dodge: geen decay op frame 0; decay op frames 1..29, vanaf frame 30 alleen gravity (geen drift, geen fast fall). Wavedash-grondsnelheid = 3.1·cos θ (≈ 2.92 bij de test-stick 75/−27).
- Special fall na air dodge: drift × 1.0 en landing lag 10 (⚠️ beide).
- `air_max_horizontal_velocity` en `ground_max_horizontal_velocity` = 3.5 (alleen als vangnet; boven max air speed remt de lucht met air_friction, `aerial_friction_oob` niet apart).

## Archetype-presets
`engine/fighter/archetypes/<id>.tres`. Alle ✅-waarden 1-op-1 uit `docs/melee-referentie.md` (tabel B1/B2); de rest is geschat (⚠️, ook vermeld in het `reference`-veld van elke preset).

| Preset (`id`) | Referentie | Waarom deze | Afwijkend/geschat ⚠️ |
|---|---|---|---|
| `allrounder` | Marth | gemiddeld in alles, lange wavedash | alleen de algemene ⚠️-velden |
| `fast_faller` | Fox | zware gravity, hoge fast fall, 3f jumpsquat | alleen de algemene ⚠️-velden |
| `heavyweight` | Ganondorf | gewicht 109, trage grond, 6f jumpsquat (Bowser 8f zou te traag voelen) | air friction 0.02 (alleen karakterpagina) |
| `floaty` | Peach (zonder float) | lage gravity/terminal, 1 luchtsprong (de 5 sprongen van Jigglypuff worden wel ondersteund via `air_jump_forces`) | dash initial 1.2 en accel 0.02/0.1 ✅ [P], air jump mult 0.7 ⚠️, intangible 4–19 ✅ |
| `lightweight` | Pikachu | lichtst van de complete referenties (80), snel, 3f jumpsquat | alleen de algemene ⚠️-velden |

Algemene velden (volgorde Marth / Fox / Ganon / Peach / Pikachu; ✅ [P] = uit de verificatie, rest ⚠️ geschat):

| Veld | Gekozen | Redenering |
|---|---|---|
| `ground_to_air_jump_momentum_multiplier` | Marth 0.8, Fox 0.83, Ganon 0.75, Peach 0.7, Pikachu 0.8 | ✅ [P] (docs/verificatie.md sectie 5) |
| `jump_h_initial_velocity` | 1.0 / 0.72 / 0.9 / 0.7 / 0.8 | ✅ [P] |
| `jump_h_max_velocity` | 1.2 / 1.7 / 1.8 / 1.1 / 1.8 | ✅ [P] |
| `air_jump_h_multiplier` | 1.0 / 0.9 / 1.0 / 0.9 / 0.8 | ✅ [P] |
| `walk_initial_velocity` / `walk_acceleration` | 0.08–0.2 / 0.05–0.1 | initial ✅ [P] (Ganon 0.08, Peach 0.2/0.1); ⚠️ Marth/Ganon walk-accel is in Melee 0, maar onze walk-formule wijkt af (accel 0 = nooit lopen), dus geschat gelaten |
| `turn_frames` | 11 | typische Turn-animatielengte |
| `run_brake_frames` | 26 / 18 / 28 / 23 / 20 | ✅ [P] RunBrake-animatie |
| `run_turn_frames` | 30 / 20 / 22 / 22 / 20 | ✅ [P] TurnRun-animatie; hier een minimum, remmen komt erbij |
| `squat_frames` / `squat_rv_frames` | 7 / 10 | typische animatielengtes |
| `normal_landing_lag` | 4 (Ganondorf 5) | ✅ [P] |
| ECB (`ecb_height`, `ecb_mid_y`, `ecb_half_width`) | 10–18 / 5–9 / 3.5–5 | geschat naar postuur; nog alleen visueel (F2) |

Gemeten wavedash-afstand (test-stick 75/−27, frame-perfect): Marth 47.5, Fox 34.9, Ganondorf 33.5, Pikachu 28.6, Peach 24.0 units — de volgorde (Marth lang, Peach kort) klopt met Melee.

### Speeltest 2: fast fall losser (afwijking van Melee)
- `MeleeStick.fast_fall_while_rising = true` (standaard): een verse flick omlaag in de lucht zet de fast fall **meteen** in, ook tijdens het stijgen. De gebruiker vond wachten tot de apex niet lekker voelen. ⚠️ Bewuste afwijking van Melee.
- Stick omlaag vasthouden vanaf de grond geeft nog steeds geen fast fall (er is geen verse flick in de lucht).
- `false` = puur Melee-gedrag (pas na de apex). De Melee-vergelijkingstests draaien met `false`; `_test_fast_fall_while_rising` test de losse variant.

### Besluit: Rivals-aanpak voor fast fall (vervangt "speeltest 2")
- `fast_fall_while_rising = false` (standaard): fast fall zoals Melee (na de apex), met de Xbox-leniency (`FAST_FALL_BUFFER`): een tik vlak vóór de apex telt nog.
- **Hitfall (M3):** tijdens de **hitlag van een eigen treffer** mag je fast fallen, ook tijdens het stijgen (zoals Rivals of Aether). **Niet** bij een treffer op een shield.
- De losse variant (`true`) blijft beschikbaar als schakelaar en wordt nog getest.

## M2-implementatie: ledge, teeter, respawn-platform, KO-API (`engine/fighter/`)
Status: gebouwd, na speeltest herzien ("ledge-fix", zie onder) en headless getest (`tests/test_ledge.gd`, 251 checks). Getallen staan in `FighterStats` (groep "Ledge", per character overschrijfbaar) of `FighterConst`; ✅ = Melee-bron (docs/verificatie.md sectie 3), ⚠️ = geschat.

### Character-lengte: `visual_height` 8–30 units
Toegestaan bereik `FighterStats.VISUAL_HEIGHT_MIN..MAX` = **8–30 units** (Melee-characters ~11–20; spelers mogen kleiner/groter). Alles aan de ledge schaalt mee: grab-box, hang-positie (uit het rig), getup-afstanden. Hurtboxes en ingebouwde ledge-/getup-attack-hitboxes schalen al met `visual_height`. Tests draaien op 8 / 15 / 30.

### Ledge grab (`Fighter.check_ledge_grab`, aangeroepen na `coll()` in luchtstates met `can_grab_ledge()`)
- Toegestane states: Fall, FallSpecial, Jump, JumpAerial, **DamageFall (tumble)** ✅ [N][W]. Niet: aerials, EscapeAir (na de animatie wel, dan FallSpecial), DamageFly (hitstun). Altijd: dalend (`vel.y + kb_vel.y < 0`) ✅, geen ledge-lock, niet al aan een ledge.
- Stick omlaag (≤ −0.6875, `LEDGE_GRAB_DOWN_BLOCK`) voorkomt de grab. ✅ regel, ⚠️ drempel (Melee ~0.66, ❓).
- Kijkrichting: naar de stage (`facing == −side`) ✅. Van de rand af rennen (rug naar de ledge) grabt nooit.
- **Bezette ledge: grab mislukt** (✅ `ftCliffCommon_80081298` → `ft_80082E3C`; geen ledge-steal/trump in Melee). Register: meta `ledge_occupants` op het stage-object, `Fighter.ledge_occupied_by_other()`.
- **Grab-box × `visual_height`** (Melee: per-character cliff-box `ledge_snap_x/y/height` × modelschaal ✅ structuur): ledge ligt tot `ledge_grab_front_ratio·h` (0.917; Fox 11 bij h = 12 [N]) vóór het midden, het midden mag `ledge_grab_back_ratio·h` (0.27 ⚠️) al onder de stage zitten (geen muur-collision), en de ledge ligt `ledge_grab_y_min_ratio..max_ratio · h` (**0.0**..1.458) boven de voeten. Bovengrens = Fox 17.5 bij h = 12 [N]. ⚠️ Ondergrens 0 i.p.v. Fox 8.5/12: Melee tilt de lucht-ECB-onderkant boven de voeten, waardoor je na van de rand glijden (wavedash/run achteruit) vrijwel meteen grabt; wij meten vanaf de voeten. Gevolg: wavedash achteruit van de rand → Fall → CliffCatch op het 2e luchtframe (getest voor alle presets × h 8/15/30).
- **Snap = handen op de hoek, uit het rig** (`LedgeGrip`, `engine/fighter/ledge_grip.gd`): forward kinematics over `Rig.BONES` met pose `cliff_wait` frame 0 (gedeelde poses + eigen poses van het character); greeppunt = midden van beide handpalmen (`PALM_PX` = pols + 6 px) + `GRIP_INSET` (−4, +6) rig-px (palm net binnen de rand, óp de bovenkant). Gecachet per `character_id` (gewist bij `CharacterVisual.reloaded`), geschaald met `visual_height / Rig.STAND_HEIGHT_PX`. `Fighter.ledge_grip()` = hoek t.o.v. de voeten (units), `ledge_hang_pos()` = voeten. Geen visuele offset meer: de visual-root = `pos`. Puur rekenwerk op pose-data, dus deterministisch en headless.
- Hang-pose (`cliff_wait`, ook begin van catch/getup/roll/attack/jump): armen schuin vooruit omhoog (upper_arm −146/−148, forearm −7/−6), zodat de handen vóór de borst liggen: handen op de hoek én borst/hoofd tegen de wand.
- Bij de catch: vel, kb_vel en gr_vel 0, alle sprongen terug, facing naar de stage.

### States
| State | Duur | Kern |
|---|---|---|
| CliffCatch | 7 frames ✅ (`ledge_catch_frames`, Link 3) | geen input, snap |
| CliffWait | max 660 frames < 100% (❓ wiki 11 s, NOTES 640), 480 vanaf 100% ✅ → automatisch loslaten | opties, zie onder |
| CliffClimb (getup) | 34 (Slow ≥ 100%: 60) ✅ [P] | `rise` 16 / 30 frames omhoog én naar de hoek (voeten op de rand), dan `0.8·h` de stage op ⚠️; intangible 1–31 (Slow 1–56) ✅ |
| CliffEscape (roll) | 50 (80) ✅ | rise 14 / 24, dan `1.9·h` ⚠️; intangible 1–35 (1–60) ✅ |
| CliffAttack | 55 (70) ✅ | beweegt als getup; hitbox op `hit` 24 / 40 ✅ (ingebouwd `MoveSet.builtin`); intangible 1–21 (1–45) ✅ |
| CliffJump | wacht 15 (21) ✅ aan de muur, dan Jump | intangible de hele wacht ✅; vy = `jump_v_initial_velocity × ledge_jump_vy_mult`, vx = `ledge_jump_vx` (1.1) naar de stage ⚠️ (Melee per character); double jump blijft |
| Loslaten | direct | Fall, vel 0, alle sprongen terug (`Fighter.ledge_drop()`) |

Getup-tabel: `FighterStats.LEDGE_OPTION_DEFAULTS`/`ledge_options` (frames, rise, dx × h, i0..i1, hit), per variant `low` (< 100%) en `high`; bron [P] gemiddeld Marth/Fox/Peach/Pikachu (Ganondorf wijkt af: climb-intangible tot f23, roll f25 — per character via `ledge_options`). De variant volgt `Fighter.percent >= Fighter.ledge_high_percent` (100 ✅). Positie tijdens een getup is een functie van het state-frame; het einde zet de fighter op de grond in Wait (`finish_ledge_move`).

Inputs in CliffWait (prioriteit): jump (knop of omhoog-flick/tap jump) → CliffJump; A → CliffAttack; shield (nieuw ingedrukt) → CliffEscape; stick naar de stage (≥ 0.5) of omhoog (≥ 0.6875, alleen zonder tap jump) → CliffClimb; stick omlaag of van de stage af (≥ 0.6875) → loslaten. Stick-richtingen tellen alleen als ze ná de grab zijn ingeduwd (`stick_timer ≤ ledge_hang_frames`). ⚠️ Volgorde en drempels gekozen.

### Intangibility en ledge-lock
- Generiek: `Fighter.intangible_frames` (telt per tick af, loopt door na state-wissels) en `Fighter.is_intangible()` = teller > 0 **of** `state.intangible()`.
- **Elke catch**: `intangible_frames = max(intangible_frames, 7 + 30)` ✅ (`ftColl_8007B760` bij CliffWait-start; geen "alleen na landen"-regel). Regrab/ledgestall dus mogelijk zoals Melee; een groter restant (respawn) blijft.
- **Eén `ledge_cooldown` = 30** ✅ na loslaten, na getup/roll/attack/ledge jump én na geraakt worden (ook als je niet aan de ledge hing; telt niet af tijdens hitlag).

### Grondstates aan de rand (wavedash naar de ledge)
`FighterState.stops_at_edge()`: alleen stilstaan en langzaam lopen stoppen aan de rand (Wait, Teeter, Walk < 0.75, Turn, Squat*, KneeBend ⚠️, grondaanvallen behalve dash attack ⚠️). Over de rand glijden: Dash, Run, **RunBrake**, **RunTurn** (⚠️ nieuw, Melee-gedrag volgens speeltest), Walk ≥ 0.75, Landing, LandingFallSpecial (wavedash/waveland), dash attack, Damage.

### Teeter
`StateTeeter`: Wait (en Walk dat aan de rand stopt, `FighterState.on_edge_stop`) → Teeter als de fighter precies aan een losse segmentrand staat én naar de afgrond kijkt (`Fighter.edge_side()`). Actionable zoals Wait (jump, dash — valt eraf —, squat, omdraaien); naar de rand duwen blijft Teeter; rug naar de afgrond = Wait. Pose: `teeter` als de rig die heeft, anders de walk-pose op frame 0 (`FighterState.pick_pose`). ⚠️ Melee-teeter (ECB-gebaseerd, ook bij andere facing) vereenvoudigd.

### KO-API en respawn
- `signal blast_ko(fighter, side)` met `side` ∈ `&"left"`, `&"right"`, `&"top"`, `&"bottom"` (grootste overschrijding van de `get_blast_zone()`-Rect2 bij een hoek), uitgezonden op het frame dat de fighter de zone verlaat, ná het inactief zetten (state `Dead`, `active = false`, `visible = false`; `sim_tick` doet dan niets). Een handler mag in het signaal al `respawn_at()` aanroepen.
- `auto_respawn` (standaard true): na het signaal meteen `respawn()` = `respawn_at(stage.get_respawn(player), 120)`. false: de fighter blijft weg tot `respawn_at()`/`spawn()`.
- `respawn_at(p, invincible_frames)`: zet hem op `p` in **RebirthWait** (geen gravity/collision, platform getekend onder de voeten), `intangible_frames = invincible_frames` (standaard 120 ⚠️). Eindigt op input (stick of knop, pas na 20 frames ⚠️) of na 300 frames ⚠️ (5 s) met Fall en alle sprongen terug; de invincibility loopt door tot ze op is.
- `var percent` met setter (klemt op ≥ 0) en `signal percent_changed(new_percent)`; verder niets.
- Sandbox: F6 wisselt stub ↔ echte Eindpunt (MatchCamera, bounds uit de stage), F7 zet auto-respawn aan/uit, CLI `--stage eindpunt`.

### Niet gedaan / open
- Geen muur-collision of ECB-onderkant-verschuiving; de grab-box heeft daarom ruime marges.
- Ledge-poses: sinds M3 gekoppeld aan de rig-poses `cliff_catch`, `cliff_wait`, `cliff_getup`, `cliff_roll`, `cliff_attack`, `cliff_jump`, `teeter`, `respawn_platform` (zie docs/combat.md, "M3-integratie").
- Ledge-getup-frames en intangible-vensters zijn geschat; met Melee-framedata te vervangen via `ledge_options`.

## M3-implementatie: gevecht in de fighter
Volledige beschrijving in `docs/combat.md`, sectie "M3-integratie" (tests: `tests/test_fighter_combat.gd`). Gebruikte waarden:

| Mechaniek | Waarde | Zekerheid |
|---|---|---|
| Smash-aanval met A: flick-venster | teller < 4 (`FighterConst.SMASH_ATTACK_WINDOW`; Melee `SMASH_WINDOW` 2) | ⚠️ Xbox-leniency |
| C-stick-drempel (smash/aerial) | 0.6625, vorige frame eronder | ⚠️ |
| JC usmash | A + stick-y ≥ 0.6625 (of C-stick omhoog) tijdens KneeBend | ✅ structuur, ⚠️ drempel |
| Smash charge | max 60 frames, damage × (1 + 0.3671·n/60) = ×1.3671 vol; houdt vast op move-frame 2 | ✅ 60 / 1.3671, ⚠️ frame |
| Jab-combo | volgende jab na laatste actieve frame + 1 als A opnieuw is ingedrukt | ⚠️ |
| L-cancel | L/R/Z (of analoog ≥ 0.3) ≤ 7 frames vóór de landing; lag = lcancel_lag of floor(lag/2), min 1 | ✅ (analoog ⚠️) |
| Auto-cancel-landing | normal_landing_lag | ✅ structuur |
| Hitlag | floor(d/3 + 3), aanvaller = slachtoffer, freeze van positie/timers | ⚠️ (zie combat.md) |
| SDI / ASDI | 6 units per flick ≥ 0.7 / 3 units op het laatste hitlag-frame (C-stick voorrang) | ⚠️ |
| DI | max 18°, stick op het laatste hitlag-frame | ✅ 18°, ⚠️ moment |
| Knockback-snelheid | apart `kb_vel` = KB·0.03, −0.051/frame; self-vel 0 bij de hit, gravity loopt door | ✅ |
| Hitstun | floor(KB·0.4) frames geen actie | ✅ |
| Tumble | KB ≥ 80 → DamageFly, na hitstun DamageFall (drift, fast fall, aerial, jump, air dodge) | ✅ |
| Tech | shield ≤ 20 frames vóór de grond; lockout 40 frames; in place 26 f / roll 40 f (28 units), intangible 1–20 | ✅ 20, rest ⚠️ |
| Missed tech | DownBound 26 f, DownWait max 180 f, getup stand 30 / roll 35 (26 units) / attack 49 f | ⚠️ |
| Crouch cancel | KB × 2/3; grounded-blijvende hit = geen flinch (blijft hurken) | ✅ 2/3, ⚠️ flinch-regel |
| ASDI omlaag | grounded, geen tumble, stick-y ≤ −0.7 → blijft op de grond | ⚠️ |
| Grond-bounce | tumble-launch de grond in → vy × −0.8 | ⚠️ |
| Hitfall | fast fall tijdens eigen hitlag na een echte treffer, ook tijdens stijgen (Rivals-besluit) | besluit |
| Rebound (clank) | 20 frames; aerials clanken niet | ⚠️ duur, ✅ regel |

## M4-implementatie: input van shield, OoS en grab
Volledige beschrijving en alle waarden in `docs/combat.md`, sectie "M4-implementatie" (tests: `tests/test_defense.gd`).

| Input | Waarde | Zekerheid |
|---|---|---|
| Shield aan | analoog ≥ 0.3 (`analog_shoulder_deadzone`) of digitale klik (= 1.0); lightshield-stand `s` = trigger | ✅ |
| Powershield | digitale klik, treffer in de eerste 4 frames van GuardOn | ⚠️ |
| Spotdodge uit shield | stick-y ≤ −0.7, teller < 4 | ⚠️ |
| Roll uit shield | stick-x ≥ 0.8, teller < 4 (Xbox-venster zoals dash) | ⚠️ |
| Shield drop (platform) | verse omlaag-flick (platform-drop-drempel 0.6875, venster 4, verificatie #20) in de notch −0.7 < y ≤ −0.6875; UCF ook schuin met \|x\| ≥ 0.4 | ✅ regel, ⚠️ zones |
| Grab | Z, of A met shield vast; Dash/Run = dash grab; jumpsquat = staande (JC) grab, ná de JC-usmash-check | ✅ |
| Throw-richting | stick ≥ 0.6625 (dominante as) of verse C-stick | ⚠️ |
| Grab-mash | elke nieuwe knop of verse stickrichting −6 frames van de grab-timer (90 + 1.7·%) | ⚠️ |
| Special-hook | B; up/down ≥ 0.6625, side ≥ 0.6 (dominante as) | ⚠️ |
