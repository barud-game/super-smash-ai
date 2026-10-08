# Stage: Eindpunt

Eén vlakke stage zonder platforms, met de afmetingen van Melee's Final Destination.
Alles in **Melee-units** (x rechts, y omhoog, y=0 = bovenkant grond); renderen via `Units.to_px`.
Rects zijn `Rect2(links, onder, breedte, hoogte)` in units (onder < boven).

## Waarden (`stages/eindpunt/eindpunt.tres`)
| Waarde | Eindpunt | Bron / zekerheid |
|---|---|---|
| Grond (solid) | x = -85.5657 .. 85.5657, y = 0 | libmelee stage-tabel (rand-x 85.5657); breedte ≈ 171 units |
| Ledges | (±85.5657, 0), side -1 / +1 | gelijk aan de rand van de grond; ⚠️ de grijp-snap-offset t.o.v. dit punt is aan de fighter-agent |
| Blast zone | links -246, rechts 246, boven 188, onder -140 | libmelee (`-246, 246, 188, -140`); orde L/R/boven/onder is afgeleid uit tekens |
| Camera bounds | x -200..200, y -85..140 | ⚠️ geschat (16:9, rond de stage); echte Melee-waarden niet gevonden |
| Spawns (P1..P4) | (-30,0) (30,0) (-60,0) (60,0) | ⚠️ geschat |
| Respawns | (0, 60) voor alle 4 | ⚠️ geschat; het respawn-platform zelf volgt later |

Opmerking: websearch gaf de rand-x (85.5657) en blast zones; camera bounds en spawns zijn niet
gevonden en dus placeholders om later bij te stellen in de `.tres` (geen code-wijziging nodig).

## Data-klassen (`engine/stage/`)
- `StageData` (Resource): `stage_name`, `ground_segments: Array[StageSegment]`, `ledges: Array[StageLedge]`,
  `blast_zone: Rect2`, `camera_bounds: Rect2`, `spawns`, `respawns: Array[Vector2]`; hulpfuncties `left()`, `right()`.
- `StageSegment`: `a`, `b` (units), `type` (`SOLID` / `PLATFORM`).
- `StageLedge`: `position` (units), `side` (-1 links, +1 rechts).

## API (`Stage`, `engine/stage/stage.gd`; geen physics, alleen data)
- `get_ground_segments() -> Array[StageSegment]`
- `get_ledges() -> Array[StageLedge]`
- `get_blast_zone() -> Rect2`, `get_camera_bounds() -> Rect2`
- `get_spawn(i) -> Vector2`, `get_respawn(i) -> Vector2` (i 0-based, wrapt rond)
- `data: StageData` is direct beschikbaar.

Debug-tekening (alleen met `Sim.debug_hitboxes`): ledges (geel), blast zone (rood), camera bounds (groen),
grondlijn (cyaan) en spawns (wit).

## Visuals
Donkere kosmische lucht: verloop op een `CanvasLayer` (-10), drie sterlagen en één nevellaag als
`Parallax2D` (scroll-schaal 0.04 / 0.08 / 0.12 / 0.25), trage nevel-drift (puur visueel, via `_process`),
en een romp met gloeiende bovenrand. Lage contrast achtergrond zodat characters afsteken.

## Camera (`engine/camera/match_camera.gd`)
`MatchCamera` (Camera2D): `set_targets(Array[Node2D])`, `set_bounds_units(Rect2)`.
Zoomt zodat alle targets + `margin_units` (28) passen, geklemd op `min_zoom`/`max_zoom` (0.4 / 1.4) en nooit
verder uit dan de bounds toelaten; positie blijft binnen bounds; smoothing per physics-frame
(pos 0.08, zoom 0.05). `compute_goal()` geeft doel zonder smoothing (testbaar).
Testscène: `stages/eindpunt/stage_test.tscn` (opties na `--`: `--shot pad.png --frame N [--wide] [--debug]`, `--check`).

## Tests
`tests/test_stage.gd` (data) en `stage_test.tscn -- --check` (API + camera binnen bounds).
