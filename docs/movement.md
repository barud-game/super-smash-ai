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

- **Afwijking code:** `SMASH_LOW = 0.3` bestaat in Melee niet als zodanig. Melee’s equivalent is de “frames sinds deadzone verlaten”-teller. Voor de engine: houd per as een teller bij die op 0 begint wanneer |waarde| van < deadzone naar ≥ deadzone gaat (en die blijft tellen/saturaten), en laat `stick_smashed(N)`/dash/tap-jump/fast-fall testen op `|waarde| ≥ drempel && teller < N`. De flick moet dus *vanuit de deadzone* beginnen en snel genoeg de drempel halen; langzaam voorbij de drempel dwingen geeft tilt/walk.
- **Afwijking code:** `SMASH_HIGH = 0.8` ligt op het raster gelijk aan de echte drempel (0.79 → 64/80 = 0.8). ✅ praktisch correct, ⚠️ exacte float.
- Analoge trigger: `shield_press_threshold = 0.25`, `analog_shoulder_deadzone = 0.3`, `z_press_analog_value = 0.35`. [S12] ✅ — lightshield begint rond 0.25–0.3. Air dodge, tech en L-cancel gebruiken de **digitale** L/R-bit (hardware “klik”, volledig ingedrukt). `TRIGGER_FULL = 0.95` is een redelijke benadering voor XInput (⚠️ er bestaat geen vaste Melee-analoge drempel voor de digitale klik). Powershield-venster: `powershield_input_window` frames na trigger ≠ 0 (waarde onbekend ⚠️).
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

## Ledge (documentatie voor M2)
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

## Samenvatting afwijkingen t.o.v. de code in `engine/input/melee_stick.gd`
| Constante | Code | Melee | Oordeel |
|---|---|---|---|
| `GRID` | 80 | cirkel straal 80 | ✅ correct |
| `DEADZONE` | 23 (per as, <23 → 0) | 0.28 per as ⇒ ≥ 23/80 actief | ✅ correct |
| `SMASH_HIGH` | 0.8 | 0.79 ⇒ 64/80 = 0.8 op raster | ✅ praktisch correct (⚠️ float) |
| `SMASH_LOW` | 0.3 | bestaat niet; Melee gebruikt teller “frames sinds deadzone verlaten” < venster (dash/smash ≈ 2, tap jump 4) | ⚠️ afwijkend mechanisme |
| `TRIGGER_FULL` | 0.95 | digitale hardware-klik; analoog shield vanaf 0.25–0.3, Z-analoog 0.35 | ⚠️ benadering |
