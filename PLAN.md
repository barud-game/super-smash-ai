# Plan

## Huidige status
> Bijwerken aan het eind van elke sessie.

- **Fase:** M0 gebouwd (headless geverifieerd, 33/33 tests). Wacht op handmatige test met 2 controllers.
- **Laatste sessie (2026-10-08):** planning, director-werkwijze + agents, M0 door `engine-builder`.
- **Code-overzicht:** `engine/sim.gd` (klok, frame advance), `engine/input/` (InputManager, MeleeStick,
  InputFrame, InputHistory), `engine/units.gd` (UNIT_TO_PX = 7), `ui/debug_overlay/`, `scenes/sandbox.tscn`,
  tests: zie `tests/README.md`.
- **Open punten:** ⚠️-waarden in `docs/movement.md` verifiëren; F2-hitboxweergave is nog een lege hook.
- **Volgende stap:** M1 — movement.

## Besluiten
- **Visuals:** SVG's (Godot importeert ze native). Characters zijn originele ontwerpen.
- **Menu:** main menu met *Training* en *Fight*.
- **Stage:** één vlakke stage zonder platforms (Final Destination-achtig, eigen ontwerp).
- **Scope:** lokaal, 2 spelers, voor de lol — geen online/delen/competitieve balans voorlopig.
- **Director-model:** de hoofdchat plant, delegeert, reviewt en commit; agents (`.claude/agents/`) doen het werk.
  Sonnet 5.5 = engine, specials, SVG; Haiku 5.5 = normals. Een validator controleert budget, frame-bereiken en simulaties.
- **Snelle character-creatie:** voorstel-eerst gesprek, standaard-moveset per archetype, special-sjablonen,
  gedeeld SVG-skelet met gedeelde animaties, hot reload in training mode.

## Mijlpalen

| # | Mijlpaal | Klaar als | Status |
|---|---|---|---|
| M0 | Fundament | Godot-project, 60 Hz-tick, 2× XInput met Melee-stickraster, debug overlay (frame, state, hitboxes), frame advance | 🟨 handmatige controllertest |
| M1 | **Movement** | Dash-dance, run, jumpsquat/short hop, fast fall, air drift, wavedash/waveland, platform drop — voelt als Melee | ⬜ |
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
