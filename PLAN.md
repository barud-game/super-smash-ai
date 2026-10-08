# Plan

## Huidige status
> Bijwerken aan het eind van elke sessie.

- **Fase:** M1 movement ✅ (gebruiker: "het werkt allemaal"; fast fall op verzoek losser). Volgende: combat afmaken (M3) en ledges (M2).
- **Laatste sessie (2026-10-08):** planning, agents, M0, M1, rig, stage, SFX, menu's. Speeltest 1: dash-dance te strikt,
  fast fall bij short hop faalde, run turnaround bleef hangen → opgelost met Xbox-leniency (`DASH_FLICK_WINDOW=4`,
  `FAST_FALL_BUFFER=6`, `RUN_TURN_DEBOUNCE=5` in `melee_stick.gd`). Wavedash, platform drop, run, walk, hops: goed.
- **Onaf:** `engine/combat/` (M3-kernmodules: MoveData, HitboxData, Knockback, HitResolver, hitbox_draw) — agent werd
  afgebroken; bestanden staan er (niet gecommit), `tests/test_combat.gd` en `docs/combat.md` ontbreken nog. Afmaken + reviewen.
- **Tweede controller** nog niet bevestigd door de gebruiker.
- **Code-overzicht:** `engine/sim.gd` (klok, frame advance), `engine/input/` (InputManager, MeleeStick,
  InputFrame, InputHistory), `engine/units.gd` (UNIT_TO_PX = 7), `ui/debug_overlay/`, `scenes/sandbox.tscn`,
  tests: zie `tests/README.md`.
- **Ook al gebouwd (vooruit op M2/M6):** SVG-rig + dummy (`engine/visual/`, `docs/rig.md`), stage Eindpunt + camera
  (`engine/stage/`, `engine/camera/`, `docs/stage.md`), SFX (`engine/audio/`, `docs/audio.md`), menu-schil
  (`ui/`, `engine/roster/`, `docs/ui.md`). Ontwerp: `docs/special-sjablonen.md`, `docs/move-conversie.md`.
- **Open punten:**
  - ⚠️-waarden in `docs/movement.md` verifiëren; F2-hitboxweergave is nog een lege hook.
  - `Sim` pauzeert op de P-toets, ook in menu's/zoekveld (nu omzeild met `MenuNav.keep_sim_running()`): debug-toetsen
    in `Sim` alleen tijdens een match/sandbox laten werken.
  - Y en B zijn allebei `BTN_JUMP`, dus beide = "terug" in menu's. Prima voor nu.
  - `Settings.sfx_volume` wordt nog niet door `Sfx` toegepast. Geen code roept `Sfx` al aan in gameplay.
  - Stage: camera bounds en spawns zijn ⚠️ geschat. Ledge-snap-logica hoort bij de fighter (M2).
  - SFX moeten nog op het gehoor beoordeeld worden door de gebruiker.
- **Volgende stap:** feedback speeltest M1 verwerken; ledge-mechaniek (M2) en combat-kern (M3) starten. Sandbox: main menu → Sandbox (debug), F3/F4 = archetype wisselen, F5 = reset.

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
| M3 | Gevecht | Hitbox/hurtbox per frame, Melee-knockbackformule, hitstun, hitlag, DI/SDI/ASDI, L-cancel, test-moveset | ⬜ |
| M4 | Verdediging | Shield + lightshield, shieldstun, shield break, rolls, spot dodge, grabs/pummel/throws, teching | ⬜ |
| M5 | Character-systeem | Archetypes + standaard-movesets, 200-puntenbalans + validator, special-sjablonen/toolkit, SVG-skelet + gedeelde animaties, characters laden uit map + hot reload | ⬜ |
| M6 | Menu & match | Main menu (Training / Fight), training mode, 2 spelers, stocks, respawn, HUD, match-einde | ⬜ |
| M7 | Eerste character | Eerste custom character via `/nieuw-character`, end-to-end | ⬜ |

## Later
- Simpele 2D-animatie (Skeleton2D) per character
- CPU-tegenstander
- Rollback netcode
