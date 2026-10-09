# Plan

## Huidige status
> Bijwerken aan het eind van elke sessie.

- **Fase (2026-10-09, gestopt op 5-uurslimiet):** M0 ✅, M1 ✅, M2 ledges gebouwd, M3 gevecht in de fighter gebouwd
  (137 tests), M6 wedstrijd + HUD + VFX gebouwd. Standaard-movesets 90/90 PASS in de validator. Wacht op speeltest.
- **Volgende (in deze volgorde):**
  1. **Fix aerial-hoogtes:** short-hop-fair raakt geen staande tegenstander → aerial-hitboxes lager
     (afspraak 8 in `docs/standaard-movesets.md` aanpassen naar ~35% van `visual_height`, onderste box lager),
     validator + 5 movesets bijwerken, test toevoegen "SH-fair raakt staande fighter".
  2. **Fix VFX-grootte:** hit-spark is ~2× character-hoogte; schalen naar het Melee-formaat (zie screenshot-review).
  3. **`docs/verificatie.md` doorvoeren** (✅ 32 · ❌ 24 · ❓ 14). Top-afwijkingen: geen ledge-steal (bezette ledge =
     grab faalt), regrab geeft elke keer 30 intangible frames (ledgestall), DI kwadratisch (`c*|c|`), hitlag
     `int(int(d/3+3)*mul)` + electric alleen slachtoffer + crouch ×2/3 + cap 20, preset-waarden (sectie 5),
     ledge-getup-frames (sectie 3), ledge-cooldown 30, missed-tech lig 220, SDI ×6 / ASDI ×3, ledge-grab vanuit tumble.
  4. **M4 verdediging:** shield + lightshield + shield-HP/break, shieldstun voor de verdediger, OoS-opties,
     rolls, spotdodge, grab/dash grab/pummel/throws (hook `check_grab()`), grab-release.
  5. **Special-sjablonen/toolkit** (`docs/special-sjablonen.md`, bouwstenen-lijst).
  6. **M7:** eerste character **Captain Pep** (voorstel in `characters/_concepten/captain_pep/ontwerp.md`, wacht op akkoord gebruiker).
- **Gebouwd (overzicht):** sim + input (`engine/sim.gd`, `engine/input/`), fighter + states (`engine/fighter/`),
  combat-modules (`engine/combat/`, `docs/combat.md`), rig + poses (`engine/visual/`, `docs/rig.md`),
  stage Eindpunt + camera, SFX, VFX (`docs/vfx.md`), menu's + character select, wedstrijd/HUD/results/training
  (`engine/match/`, `ui/`), validator (`tools/validator/`, `docs/validator.md`), standaard-movesets
  (`engine/fighter/archetypes/*/moves/`, `docs/standaard-movesets.md`). Tests: `tests/README.md`.
- **Speeltest-historie:** M1 test 1 → Xbox-leniency (dash-flick 4, fast-fall-buffer 6, run-turn-debounce 5).
  Fast fall: Rivals-aanpak (Melee + hitfall). Characters verkleind naar Melee-formaat (`visual_height` per archetype).
- **Open punten:**
  - ⚠️-waarden in `docs/movement.md`, `docs/combat.md`, `docs/stage.md` (camera bounds/spawns), respawn-timings.
  - Y en B zijn allebei `BTN_JUMP` (beide = terug in menu's). D-pad zit niet in `InputFrame` (training leest hem direct).
  - Gebruiker moet nog: tweede controller bevestigen, SFX op het gehoor beoordelen, ledges + wedstrijd speeltesten.
  - Sommige aerial-poses (fair/dair) mogen dynamischer.
- **Sandbox:** main menu → Sandbox (debug). F3/F4 archetype, F5 reset, F6 stub/Eindpunt, F7 auto-respawn.

## Besluiten
- **Visuals:** SVG's (Godot importeert ze native). Characters zijn originele ontwerpen.
- **Menu:** main menu met *Training* en *Fight*.
- **Stage:** één vlakke stage zonder platforms (Final Destination-achtig, eigen ontwerp).
- **Scope:** lokaal, 2 spelers, voor de lol — geen online/delen/competitieve balans voorlopig.
- **Director-model:** de hoofdchat plant, delegeert, reviewt en commit; agents (`.claude/agents/`) doen het werk.
  Sonnet 5.5 = engine, specials, SVG; Haiku 5.5 = normals. Een validator controleert budget, frame-bereiken en simulaties.
- **Besturing:** UCF-gedrag (o.a. betrouwbare dashback en shield drop), tap-jump aan (uit te zetten in instellingen),
  LT/RT/RB doen allemaal L-cancel.
- **Match:** 4 stocks, 8 minuten, geen items, sudden death bij gelijkspel. Pauze en L+R+A+Start precies als Melee.
- **Character select:** elk gemaakt character is een eigen pick; moet schalen naar ~100 (grid met pagina's/zoeken,
  automatisch ontdekt uit `characters/`). Mirror matches toegestaan, kleur per speler.
  **OP-characters** (buiten 200-budget) staan duidelijk gemarkeerd op de character select.
- **Training:** bare bones. De dummy is een willekeurig ander character.
- **Feedback:** gegenereerde simpele SFX; Melee-stijl hit-effecten (hitlag-shake, flits, screenshake bij harde kills).
  Elk character krijgt een **eigen KO-effect**, gemaakt door een Haiku-agent bij het aanmaken van het character.
- **Stage-thema:** zwevend platform in een donkere kosmische lucht (keuze director).
- **Budget:** blijft 200 (Melee-top-tiers komen op ~215–225 uit, dus sterke characters vragen keuzes; OP-optie bestaat).
- **Eerste character (M7):** de gebruiker wil Captain Falcon. Wordt een **origineel** character met die speelstijl:
  snelle, zware racer-brawler met krachtige vuurstoot en knie-achtige aerial. Eigen naam en uiterlijk;
  movement-stats mogen op de Falcon-referentiewaarden gebaseerd zijn.
- **Testen:** de gebruiker test op gevoel; agents draaien automatische vergelijkingstests tegen Melee-waarden.
- **Snelle character-creatie:** voorstel-eerst gesprek, standaard-moveset per archetype, special-sjablonen,
  gedeeld SVG-skelet met gedeelde animaties, hot reload in training mode.

## Mijlpalen

| # | Mijlpaal | Klaar als | Status |
|---|---|---|---|
| M0 | Fundament | Godot-project, 60 Hz-tick, 2× XInput met Melee-stickraster, debug overlay (frame, state, hitboxes), frame advance | 🟨 handmatige controllertest |
| M1 | **Movement** | Dash-dance, run, jumpsquat/short hop, fast fall, air drift, wavedash/waveland, platform drop — voelt als Melee | ✅ |
| M2 | Stage | Vlakke stage (FD-achtig, eigen ontwerp), ledges (snap, hang, getups, invincibility), blast zones, camera | ⬜ |
| M3 | Gevecht | Hitbox/hurtbox per frame, Melee-knockbackformule, hitstun, hitlag, DI/SDI/ASDI, L-cancel, test-moveset, **hitfall** (fast fall tijdens hitlag van eigen treffer, niet op shield — Rivals-aanpak) | ⬜ |
| M4 | Verdediging | Shield + lightshield, shieldstun, shield break, rolls, spot dodge, grabs/pummel/throws, teching | ⬜ |
| M5 | Character-systeem | Archetypes + standaard-movesets, 200-puntenbalans + validator, special-sjablonen/toolkit, SVG-skelet + gedeelde animaties, characters laden uit map + hot reload | ⬜ |
| M6 | Menu & match | Main menu (Training / Fight), training mode, 2 spelers, stocks, respawn, HUD, match-einde | ⬜ |
| M7 | Eerste character | Eerste custom character via `/nieuw-character`, end-to-end | ⬜ |

## Later
- Simpele 2D-animatie (Skeleton2D) per character
- CPU-tegenstander
- Rollback netcode
