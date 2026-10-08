# Plan

## Huidige status
> Bijwerken aan het eind van elke sessie.

- **Fase:** planning afgerond, M0 nog niet gestart.
- **Laatste sessie (2026-10-08):** repo opgezet, plan, balanssysteem en character-gesprek vastgelegd.
- **Volgende stap:** M0 — Godot-project, 60 Hz-loop, XInput + stick-kwantisatie, debug overlay.

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
| M0 | Fundament | Godot-project, 60 Hz-tick, 2× XInput met Melee-stickraster, debug overlay (frame, state, hitboxes), frame advance | ⬜ |
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
