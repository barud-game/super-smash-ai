# Melee-referentie: character-attributen (NTSC 1.02)

Alleen feiten/getallen. ✅ = bron gevonden en consistent, ⚠️ = bron onduidelijk/tegenstrijdig of afgeleid, — = niet betrouwbaar gevonden (niet gegokt).
Eenheden: Melee-units per frame (snelheid) en per frame² (accel/gravity/traction). Bronnen [S#] onderaan.
Mechaniek en formules: `docs/movement.md`.

## Tabel B1 — Verticaal en gewicht

| Character | Weight | Gravity | Terminal v. | Fast fall v. | Jumpsquat (fr) | Full hop v0 | Short hop v0 | Air jump mult. (→ v) | Aantal air jumps |
|---|---|---|---|---|---|---|---|---|---|
| Fox | 75 ✅ | 0.23 ✅ | 2.8 ✅ | 3.4 ✅ | 3 ✅ | 3.68 ✅ | 2.1 ✅ | 1.2 (4.416) ✅ | 1 ✅ |
| Falco | 80 ✅ | 0.17 ✅ | 3.1 ✅ | 3.5 ✅ | 5 ✅ | 4.1 ✅ | 1.9 ✅ | 0.94 (3.854) ✅ | 1 ✅ |
| Marth | 87 ✅ | 0.085 ✅ | 2.2 ✅ | 2.5 ✅ | 4 ✅ | 2.4 ✅ | 1.5 ✅ | 0.88 (2.112) ✅ | 1 ✅ |
| Captain Falcon | 104 ✅ | 0.13 ✅ | 2.9 ✅ | 3.5 ✅ | 4 ✅ | 3.1 ✅ | 1.9 ✅ | 0.9 (2.79) ✅ | 1 ✅ |
| Peach | 90 ✅ | 0.08 ✅ | 1.5 ✅ | 2.0 ✅ | 5 ✅ | 2.2 ✅ | 1.6 ✅ | 0.7 (1.54) ⚠️ | 1 ✅ (+ float) |
| Jigglypuff | 60 ✅ | 0.064 ✅ | 1.3 ✅ | 1.6 ✅ | 5 ✅ | 1.6 ✅ | 1.05 ✅ | 0 → vaste forces 1.65 / 1.59 / 1.47 / 1.36 / 1.25 ✅ | 5 ✅ |
| Bowser | 117 ✅ | 0.13 ✅ | 1.9 ✅ | 2.4 ✅ | 8 ✅ | 2.8 ✅ | 1.6 ✅ | 1.0 (2.8) ✅ | 1 ✅ |
| Ganondorf | 109 ✅ | 0.13 ✅ | 2.0 ✅ | 2.6 ✅ | 6 ✅ | 2.6 ✅ | 2.0 ✅ | 0.95 (2.47) ✅ | 1 ✅ |
| Pikachu | 80 ✅ | 0.11 ✅ | 1.9 ✅ | 2.7 ✅ | 3 ✅ | 2.6 ✅ | 1.7 ✅ | 1.0 (2.6) ✅ | 1 ✅ |
| Sheik | 90 ✅ | 0.12 ✅ | 2.13 ⚠️ | 3.0 ⚠️ | 3 ✅ | 2.8 ✅ | 2.14 ✅ | 1.1 (3.08) ✅ | 1 ✅ |

Controle: voor alle 10 characters reproduceert `hoogte = Σ_{n≥0, v0−g·n>0}(v0 − g·n)` exact de gepubliceerde hop-hoogtes (full: Fox 31.28, Falco 51.5, Marth 35.09, Falcon 38.52, Peach 31.36, Puff 20.8, Bowser 31.57, Ganon 27.3, Pikachu 32.04, Sheik 34.08; short: 10.65 / 11.58 / 13.995 / 14.85 / 16.8 / 9.146 / 10.66 / 16.4 / 14 / 20.16) — dat bevestigt gravity en v0 tegelijk. Voor Sheik klopt dit alleen met gravity 0.12 (de karakterpagina noemt 0.13, de gravity-pagina 0.12; 0.12 ✅).
Sheik terminal/fast-fall (2.13 / 3.0) staan alleen op de karakterpagina en komen identiek voor bij Link; ⚠️ mogelijk overgenomen/verwisseld.
Peach air jump 1.54 heeft op SmashWiki een onverklaard sterretje ⚠️.

## Tabel B2 — Horizontaal (grond en lucht)

| Character | Initial dash v | Dash-duur (fr) | Dash accel base / additional | Run speed (dash max v) | Walk max v | Traction | Air accel base / additional (a / b) | Max air speed | Air friction |
|---|---|---|---|---|---|---|---|---|---|
| Fox | 1.9 ✅ | 11 ✅ | 0.02 / 0.10 ✅ | 2.2 ✅ | 1.6 ✅ | 0.08 ✅ | 0.02 / 0.06 ✅ | 0.83 ✅ | 0.02 ✅ |
| Falco | 1.9 ✅ | 11 ✅ | 0.02 / 0.10 ✅ | 1.5 ✅ | 1.4 ✅ | 0.08 ✅ | 0.02 / 0.05 ✅ | 0.83 ✅ | 0.02 ✅ |
| Marth | 1.5 ✅ | 15 ✅ | 0 / 0.06 ✅ | 1.8 ✅ | 1.6 ✅ | 0.06 ✅ | 0.02 / 0.03 ✅ | 0.9 ✅ (PAL 0.85) | 0.005 ✅ |
| Captain Falcon | 2.0 ✅ | 15 ✅ | 0.01 / 0.15 ✅ | 2.3 ✅ | 0.85 ✅ | 0.08 ✅ | 0.02 / 0.04 ✅ | 1.12 ✅ | 0.01 ✅ |
| Peach | 1.2 ⚠️ (bronnen: 1.2 / 1.3) | 15 ⚠️ | — | 1.3 ⚠️ (bron A: 1.2, bron B: 1.3) | 0.85 ✅ | 0.1 ✅ | 0.01 / 0.06 ✅ | 1.1 ✅ | 0.005 ✅ |
| Jigglypuff | 1.4 ✅ | 13 ✅ | 0.02 / 0.065 ✅ | 1.1 ✅ | 0.7 ✅ | 0.09 ✅ | 0.19 / 0.09 ✅ | 1.35 ✅ | 0.05 ✅ |
| Bowser | 1.0 ✅ | 13 ✅ | 0.02 / 0.04 ✅ | 1.5 ✅ | 0.65 ✅ | 0.06 ✅ | 0.02 / 0.03 ✅ | 0.8 ✅ | 0.01 ✅ |
| Ganondorf | 1.3 ✅ | 15 ✅ | 0.01 / 0.08 ✅ | 1.35 ✅ | 0.73 ✅ | 0.07 ✅ | 0.02 / 0.04 ✅ | 0.78 ✅ | 0.02 ⚠️ (alleen karakterpagina) |
| Pikachu | 1.8 ✅ | 13 ✅ | 0.02 / 0.08 ✅ | 1.8 ✅ | 1.24 ✅ | 0.09 ✅ | 0.02 / 0.03 ✅ | 0.85 ✅ | 0.01 ✅ |
| Sheik | 1.7 ✅ | 7 ✅ | 0.02 / 0.10 ✅ | 1.8 ✅ | 1.2 ✅ | 0.08 ✅ | 0.02 / 0.04 ✅ | 0.8 ✅ | 0.04 ✅ |

Betekenis kolommen (veldnamen in `ftCo_DatAttrs`, doldecomp [S12]):
- Dash accel: `accel = stick·additional + sign·base`; target = `stick·run speed`.
- Air accel: `accel = stick·additional + sign·base` (a = base, b = additional); target = `stick·max air speed`; zonder stick remt `air friction`.
- Max accel = base + additional.
- Weight in de knockback-formule: zie `docs/movement.md`.

## Tabel B3 — Open (niet betrouwbaar gevonden, dus leeg gelaten)

| Attribuut | Status |
|---|---|
| `ground_to_air_jump_momentum_multiplier`, `jump_h_initial_velocity`, `jump_h_max_velocity` per character | — Bestaan zeker (formule uit decomp, zie movement.md), maar de getallen zitten alleen in Pl*.dat. Een forum noemt “0.6–0.75, per character” (onbevestigd) [S17]. |
| `air_jump_h_multiplier` per character | — |
| `normal_landing_lag` en `landingair*_lag` per character | — (4 frames is gangbaar; niet geverifieerd) |
| `standing_turn_frames`, `max_run_brake_frames`, `run_accel_taper_gain`, `walk_accel_*` | — |
| `air_max_horizontal_velocity`, `aerial_friction_oob` | — |
| Sheik terminal/fast fall bevestiging | ⚠️ zie B1 |
| `escapeair_force` 3.1 en `escapeair_decay` 0.9 | ⚠️ uit geheugen/community, niet in tekstbron bevestigd; structuur wél uit decomp |
| Stickdrempels fast fall / crouch / platform drop en dash-smash-venster | ⚠️ zie `docs/movement.md` |

## Bronnenlijst
Toegang tussen 2026-10 (alleen getallen/mechaniek overgenomen).

- [S1] SmashWiki — Dash (Melee-tabel initial dash/run/duur/accel; pivot-turn; run turnaround): https://www.ssbwiki.com/Dash
- [S2] SmashWiki — Jump (jumpsquat-tabel, full-hop jump force/hoogte): https://www.ssbwiki.com/Jump
- [S3] SmashWiki — Traction (tractionwaarden; ×2 boven walk speed; geldt niet in Dash/RunBrake): https://ssbwiki.com/Traction
- [S4] SmashWiki — Walk (walk speeds): https://ssbwiki.com/Walk
- [S5] SmashWiki — Short hop (venster = jumpsquat − 1; short-hop-tabel): https://ssbwiki.com/Short_hop
- [S6] CarVac, MeleeConchRuleset (stickcoördinaten, deadzone ≤ 0.275, tap jump Y ≥ 0.6625, dash |X| ≥ 0.8, cirkel straal 80): https://github.com/CarVac/MeleeConchRuleset/blob/main/ruleset.md
- [S7] SmashWiki — Double jump (air jump multipliers/forces, Jigglypuff 5 jumps): https://ssbwiki.com/Double_jump
- [S8] SmashWiki — Gravity: https://ssbwiki.com/Gravity
- [S9] SmashWiki — Fast fall (terminal en fast-fall-speeds): https://ssbwiki.com/Fast_fall
- [S10] SmashWiki — Air acceleration (base/additional), Air speed (max air speed), Air friction: https://ssbwiki.com/Air_acceleration , https://ssbwiki.com/Air_speed , https://ssbwiki.com/Air_friction
- [S11] SmashWiki — Air dodge (duur 49, intangible 4–29): https://www.ssbwiki.com/Air_dodge
- [S12] doldecomp/melee (gedecompileerde broncode: `ftCommonData` PlCo-waarden 0.28 deadzone / 0.6625 tap jump / 4 frames / 0.5625; `ftCo_DatAttrs` veldnamen; logica van Dash, Run, RunBrake, KneeBend, Jump, JumpAerial, EscapeAir, FallSpecial, Landing, LandingAir, Pass, ftcommon.c, ft_084E.c, ftcliffcommon.c): https://github.com/doldecomp/melee
- [S13] SmashWiki — Wavedash (10 frames landing, ideale hoek 17.1°, traction-effect): https://www.ssbwiki.com/Wavedash
- [S14] SmashWiki — L-canceling (7 frames, halveert lag): https://www.ssbwiki.com/L-canceling
- [S15] SmashWiki — Ledge (30 frames + grab-animatie invincibility, max hang 11 s / 8 s): https://www.ssbwiki.com/Ledge
- [S16] SmashBoards — 2 framing basics (54 frames ledge-lock na hit; geciteerd via zoekresultaat, niet zelf ingezien): https://SMASHBoards.com/threads/2-framing-basics.455295/
- [S17] SmashBoards — Aerial Momentum (ground-to-air-momentum, onbevestigde schatting; niet toegankelijk, alleen via zoeksamenvatting): https://smashboards.com/threads/aerial-momentum.362652/
- Karakterpagina’s SmashWiki (NTSC-statstabellen, gebruikt voor kruiscontrole): https://www.ssbwiki.com/Fox_(SSBM) en idem voor Falco, Marth, Captain_Falcon, Peach, Jigglypuff, Bowser, Ganondorf, Pikachu, Sheik.
- SmashWiki — Weight (weights): https://ssbwiki.com/Weight

Niet bereikbaar of zonder bruikbare Melee-data: srk.shib.live (bot-bescherming), opensa.dantarion.com (verbinding geweigerd), meleeframedata.com/ikneedata.com niet geraadpleegd.
