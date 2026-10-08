# Super Smash AI — context voor Claude

Lees dit eerst. Dit bestand is het geheugen van het project tussen chats.

## Wat is dit
Een 2D platform fighter in **Godot 4.6 (GDScript)** die zo dicht mogelijk als **Super Smash Bros. Melee** moet voelen.
Prioriteit #1 is **movement**: dash-dance, wavedash, short hop, fast fall, L-cancel, ledge play.

**De twist:** er is geen vaste roster. Spelers bedenken hun eigen character in een **gesprek met Claude**
(geen formulier/sheet). Claude ontwerpt, balanceert (200-puntenbudget) en implementeert het character.
Zie `docs/character-creatie.md` en de skill `/nieuw-character`.

- Repo: https://github.com/barud-game/super-smash-ai (public)
- Taal met de gebruiker: **Nederlands**. Code/identifiers: Engels.
- Characters zijn altijd **origineel** — nooit Nintendo-personages, -namen of -art namaken.

## Belangrijke documenten
| Bestand | Inhoud |
|---|---|
| `PLAN.md` | Mijlpalen + **huidige status** (bijwerken na elke sessie!) |
| `docs/movement.md` | Melee-physics die we nabouwen (units, formules, timings) |
| `docs/balans.md` | 200-puntensysteem, archetypes, prijsregels |
| `docs/character-creatie.md` | Hoe het gesprek met een speler verloopt |
| `characters/<id>/` | Eén map per character (ontwerp + data + specials) |

## Kernregels voor de engine
- **Vaste tick van 60 Hz.** Alle gameplay in `_physics_process`, alles in **frames**, nooit in seconden/delta.
- **Melee-units.** Physics rekent in Melee-units per frame; pas bij renderen schalen (`UNIT_TO_PX`).
  Zo kunnen Melee-waarden (gravity, speeds, knockback-decay 0.051, etc.) 1-op-1 worden overgenomen.
- **Eigen physics**: geen ingebouwde Godot physics-respons; collision alleen voor detectie/snapping.
- **Stick-kwantisatie** naar het Melee-raster (-80..80, deadzones, smash-drempels) vóór de gameplay input leest.
- **State machine** per fighter: één class per state. Universele states zitten in de basis-`Fighter`,
  characters leveren alleen stats, move-data en special-scripts.
- **Data-driven moves**: normals = `MoveData` Resources; specials = scripts gebouwd uit de special-toolkit.
- Determinisme bewaren (geen `randf()` in gameplay zonder seeded RNG) — houdt rollback later mogelijk.

## Input
2× XInput-controller. A=attack, X=special, Y/B=jump, LT/RT=shield (analoog), RB=Z, rechterstick=C-stick.

## Werkafspraken
- Na elke sessie: **status in `PLAN.md` bijwerken** en committen, zodat de volgende chat weet waar we zijn.
- Commits klein en beschrijvend; push naar `main` tenzij anders afgesproken.
- Nieuwe Melee-mechaniek nagebouwd? Leg de gebruikte waarden/formule vast in `docs/movement.md`.
