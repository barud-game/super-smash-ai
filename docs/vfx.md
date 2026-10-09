# VFX

Puur visueel: geen gameplay, physics of input. Code in `engine/vfx/`, preview in `tools/vfx_preview/`,
test in `tests/test_vfx.gd`. Alles is getekend met `_draw()` (geen assets nodig).

## Timing en structuur
- Elk effect is een `VfxEffect` (Node2D) met `vfx_tick(frame)`, `age` en `duration` (in **Sim-frames**).
  Er is geen `_process`-timing: `VfxLayer` tickt alle effecten per sim-frame, dus pauze (P) en frame advance (.)
  bevriezen ze. Effecten tekenen zichzelf op basis van `age`.
- `VfxLayer` (Node2D) registreert zich bij `Sim` (`sim_tick`) tenzij `auto_register = false` (tests, preview).
  Zet hem in de wereld **zonder transform** (oorsprong); effectposities zijn dan wereld-pixels.
- Deeltjes-RNG is per effect geseed (`BASE_SEED + spawn-teller * 7919`), dus herhaalbaar; nooit `randf()`.
- Hitlag: effecten lopen door tijdens hitlag (de Sim tickt gewoon door), dus de flits speelt in de freeze.

## API van `VfxLayer` (posities in Melee-units, y omhoog)
| Functie | Opmerking |
|---|---|
| `spawn_hit(pos, strength 0..1, element, angle_deg, kill=false, hitbox_radius_units=-1)` | `element` = `VfxConst.EL_*` (NORMAL 0, FIRE 1, ELECTRIC 2, ICE 3, SLASH 4 = gelijk aan `HitboxData.Element`; DARK 5 extra). `angle_deg` = knockback-richting. `kill` = screen-flash; `hitbox_radius_units` (>0, optioneel) laat de spark de hitbox volgen |
| `spawn_shield_hit(pos, strength, color, angle_deg)` | zeshoekrimpel in schildkleur |
| `spawn_clank(pos)` | gekruiste vonken |
| `spawn_land_dust(pos, heavy)`, `spawn_jump_dust(pos)`, `spawn_dash_dust(pos, facing ±1)` | stof; `dust_enabled=false` dempt ze (geeft dan `null`) |
| `spawn_airdodge_trail(pos, angle_deg = NAN, color)` | ring + nabeelden; NAN = alleen ring |
| `spawn_launch_trail(target: Node2D, frames, color)` | rookspoor achter gelanceerde fighter; volgt `target` `frames` frames |
| `spawn_respawn(pos, player_color)` | lichtpilaar + ringen |
| `spawn_ko(character_id, pos, side, player_color, colors=[])` | zie KO; `side` = `VfxConst.SIDE_LEFT/RIGHT/TOP/BOTTOM` |
| `flash_screen(color, frames, max_alpha)` | schermflits (CanvasLayer 90) |
| `clear()`, `active_count()` | |

Instellingen: `camera: MatchCamera` (optioneel; dan geeft `spawn_hit` bij sterke hits en `spawn_ko` automatisch
screenshake), `ko_clamp_rect_units: Rect2` (zet op de camera bounds; KO-effecten worden dan op die rect geklemd
zodat ze in beeld blijven, want de blast zone ligt ver buiten beeld).

Hit-sterkte: neem bv. `clampf(damage_of_hit / 25.0, 0, 1)` of uit knockback (de fighter gebruikt `kb/160`).


## Maatvoering (Melee-verhoudingen)
Characters zijn 11-19 units hoog (allrounder 15 = 105 px; 1 unit = 7 px). Alle effecten zijn daarop geschaald
(constanten in `VfxConst`); in Melee is een spark ongeveer zo groot als de hitbox.

| Effect | Maat (straal / afmeting) |
|---|---|
| Hit-spark zwak (strength 0) | 2.2 units (15 px) |
| Hit-spark sterk (strength 1) | 5.5 units (38 px) = ~bovenlichaam; duur 8-14 frames |
| Kill-spark | sterk x 1.35 = 7.4 units (52 px), +3 frames, witte screen-flash |
| Met `hitbox_radius_units` | `clamp(hitbox_r*0.85 + strength*1.2, 2.2, 5.5)` units (kill daarna x1.35) |
| Schildhit | zeshoek ~1.7-4.5 units straal (`SHIELD_SCALE` 0.55) |
| Clank | ~3.5 units straal (`CLANK_SCALE` 0.6) |
| Stof | puffs 2-4 units (`DUST_SCALE` 0.65) |
| Airdodge-ring | ~5-6 units straal (`AIRDODGE_SCALE` 0.6) |
| Launch-trail | puffs ~0.7-1.5 units, op lichaamsmidden (`TRAIL_BODY_Y_PX` 52 px boven de voet) |
| Respawn | pilaar ~4 units breed, ~22 units hoog (`RESPAWN_SCALE` 0.6) |
| KO (default/dummy) | `KO_SCALE` 0.7: kern ~15 units (~1 character), pilaar ~60 units, ringen ~35 units; mag groot blijven (zichtbaar vanaf de blast zone) |

Screenshake (kleiner dan voorheen, want 1 unit is nu relatief meer): sterke hit 0.15-0.6 units, kill 0.9-1.5, KO 1.5.
`MatchCamera.hitlag_shake` (0.2-1.2 units) staat buiten dit terrein; overweeg die ~halveren als de hitlag-shake te heftig oogt.
## Screenshake (`MatchCamera`)
- `shake(intensity_units, frames)`: amplitude in Melee-units (0.5 klein, ~2 hard, ~2.4+ KO), lineair uitdovend over
  `frames`; zet `Camera2D.offset` (positie/zoom-smoothing blijft ongemoeid; gedeeld door zoom zodat de schermgrootte gelijk blijft).
  Een zwakkere shake vervangt een lopende sterkere niet.
- `hitlag_shake(hitlag_frames, strength 0..1)`: helper bovenop `shake`.
- Ticking via `Sim.frame_advanced` (auto) of handmatig `shake_tick()`; `reset_shake()` zet RNG-seed en state terug.
- Eigen seeded RNG (`SHAKE_SEED`), dus deterministisch en los van gameplay.
- Voor fighter-visuals (Melee schudt de fighter tijdens hitlag, niet de camera): `VfxConst.hitlag_jitter(frames_left, strength_px)`
  geeft een deterministische pixel-offset voor het sprite.

## KO-effect-specificatie (voor de `ko-effect-builder`)
Elk character kan een eigen KO-effect hebben; zonder valt `VfxLayer.spawn_ko` terug op `DefaultKoEffect`
(lichtzuil + stralen + ringen + vonken in spelerskleur).

**Bestanden** (alleen in `characters/<id>/ko_effect/`):
- `ko_effect.gd` met `extends KoEffect` (verplicht), of
- `ko_effect.tscn` met als root-node een script dat `KoEffect` uitbreidt (optioneel; heeft voorrang boven `.gd`).
Een bestand dat geen `KoEffect` is, wordt genegeerd (waarschuwing, fallback).

**Basisclass `KoEffect`** (`engine/vfx/ko_effect.gd`). Beschikbaar in je script:
| Veld | Betekenis |
|---|---|
| `dir: Vector2` | eenheidsvector **de stage in** (Godot-px, y omlaag). Links-blast zone -> RIGHT, rechts -> LEFT, boven -> DOWN, onder -> UP |
| `perp: Vector2` | haaks op `dir` (langs de rand) |
| `side: int` | `VfxConst.SIDE_*` |
| `player_color: Color` | kleur van de speler (poort/team); gebruik die zichtbaar (band, gloed, kern) |
| `colors: PackedColorArray` | character-kleuren uit `character.json` (`primary()`, `secondary()` helpers) |
| `character_id: String` | |
| `rng: RandomNumberGenerator` | geseed; **alleen** deze gebruiken, nooit `randf()` |
| `age`, `duration` | frames; `progress()` = 0..1 |

Lokale ruimte: de oorsprong is het punt waar de fighter de blast zone uitvloog (geklemd op de camera bounds);
y omlaag, 1 unit = 7 px (een character van 15 units = 105 px; vergelijk daarmee). Het effect moet dus uit de rand de stage in wijzen (denk aan `dir`).

**Schrijf twee dingen:**
1. `func _on_ko_setup() -> void` — eenmalig: zet `duration` en bouw deeltjes-arrays met `rng`.
2. `func _draw_ko(t: float, f: int) -> void` — tekent frame `f` (`t = f / duration`). Pure functie van `f`/`t` en de arrays
   (geen state muteren in draw). Hulpen uit `VfxEffect`: `disc`, `draw_ring`, `draw_spike`, `draw_star`, `with_alpha`,
   `ease_out`, `ease_out3`, plus alle `draw_*` van Node2D.

**Grenzen**
- `duration` 60-90 frames (hard geklemd op `VfxConst.KO_MAX_FRAMES = 90`). Typische opbouw: flits 0-8, uitbarsting 8-40, uitdoven tot 0 aan het einde.
- Grootte: binnen ~500 px (~70 units, `KO_MAX_RADIUS_PX`) rond de oorsprong; de default-KO is ~1 character hoog (kern ~15 units = ~105 px straal), pilaar max ~430 px. Het moet vanaf de blast zone leesbaar blijven op een 1280x720-scherm (zoom 0.4-1.4): kern/flits ~70-105 px straal, uitbarsting tot ~350 px. Maak het niet kleiner dan ongeveer een character (105 px) of het verdwijnt in de zoom-uit.
- Laatste frame moet (bijna) onzichtbaar zijn (alpha -> 0, kern krimpt naar 0).
- Alleen visueel; geen nodes spawnen, geen audio, geen gameplay. Geen logo's of merken.
- Gebruik character- en spelerskleur, en een eigen vorm die bij het thema past (vuur, ijs, bloemblaadjes, glitch, ...).

**Voorbeeld:** `characters/_dummy/ko_effect/ko_effect.gd` (houtsplinters, zaagselwolk, band in spelerskleur, flits).

## Preview-tool
Windowed (headless rendert niet), schrijft een contactsheet-PNG:

    Godot_console.exe --path . res://tools/vfx_preview/vfx_preview.tscn -- --effect ko --character _dummy --side right --out C:/pad/ko.png

Opties: `--effect hit|hit_fire|hit_electric|hit_ice|hit_dark|hit_slash|hit_kill|elements|shield|clank|dust|airdodge|trail|respawn|ko`,
`--character <id>` (ko; leeg `""` = fallback), `--side left|right|top|bottom`, `--strength 0..1`,
`--frames "0,3,6,10"`, `--cols N`, `--scale F`, `--ref 0|1` (silhouet van een character van 15 units als maatstaf, standaard aan; voeten op de grondlijn, hits spawnen op lichaamsmidden). Zonder `--out` landt de PNG in `user://vfx_preview.png`.
Elke cel is 360x300 px, het effect staat gecentreerd (KO: richting de stage verschoven) op een donkere achtergrond met grondlijn.
Previews van de standaardeffecten staan in `tools/vfx_preview/out/`.

## Test
    Godot_console.exe --headless --path . --script res://tests/test_vfx.gd
Controleert alle spawn-functies, opruimen na de duur, KO-fallback/dummy/clamp, shake-determinisme, seed-determinisme en screen-flash.
