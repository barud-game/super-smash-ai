# Performance

Doel: simulatie + rendering ruim binnen 16.6 ms per frame (60 Hz), ook in een volle match, **zonder gedragswijziging**
(determinisme: dezelfde input geeft bit-voor-bit dezelfde posities, %, states).

## De bench draaien

```
<godot_console> --headless --path . --script res://tools/bench/bench.gd -- [opties]
```

| Optie | Betekenis |
|---|---|
| `--frames N` | sim-frames na de countdown (standaard 3600 = 1 minuut) |
| `--p1 ID --p2 ID` | characters (standaard `_dummy` vs `_dummy`; die heeft vaste, stabiele specials) |
| `--check` | vergelijk de snapshot-hash met `tools/bench/golden.json`; exit 1 bij verschil |
| `--write-golden` | schrijf de hash als nieuwe golden (alleen na een **bewuste** gedragswijziging) |
| `--skip-real` | alleen de gemeten run (koude start: geen eerdere run die caches vult) |
| `--no-hud`, `--json PAD` | zonder HUD / metingen als JSON |

De bench bouwt een echte `MatchController` (stage, 2 fighters, camera, VFX-laag, HUD) en laat 3600 frames **gescripte,
drukke input** lopen (vooraf berekend uit een vaste seed, state-onafhankelijk): naderen, dash, jumps, jab/tilts/smashes,
aerials, alle vier de specials, shield/lightshield, grab+pummel+throw, C-stick. Elke 240 frames krijgt een speler veel %
(launches, KO's, respawns, KO-effecten); elke 100 frames worden de fighters bij elkaar gezet als ze te ver uit elkaar zijn.
De bench meldt de dekking (state-wissels, treffers, hoe vaak de fighters dicht bij elkaar waren).

Twee runs: (1) de echte `Sim._advance()` (alleen hash), (2) een gespiegelde loop die per subsysteem de tijd meet
(`input`, `fighters`, `combat`, `specials`, `vfx`, `match`). Aanvullende sleutels komen uit `Perf` (`engine/perf.gd`):
`visual` (= `Fighter._update_visual`, zit **in** `fighters` en in `combat`), `hud` (= HUD-teken, 0 op frames zonder
redraw). `engine_rest` = wandkloktijd van het frame min onze sim = node-`_process`, draw-recording en de wachttijd van de
headless loop (zie beperkingen). Beide runs moeten dezelfde hash geven (anders lekt er state tussen runs, of wijkt de
gespiegelde loop af van `Sim._advance`). Tijdens `--check` zonder golden voor een andere combinatie (`--p1`, `--frames`)
faalt de bench; maak er dan eerst een met `--write-golden`.

### Determinisme-check

`tools/bench/golden.json` bevat de SHA-256 van alle per-frame snapshots (`Fighter.snapshot()` + hitlag + stocks +
fase + special-entities: serial/pos/vel/alive/age) voor `_dummy|_dummy|3600`. Deze golden is gemaakt met de engine **vóór**
de performance-pass (git HEAD `5b853bd` + alleen de bench-hooks). Na elke engine-wijziging: `--check` moet slagen. Verandert
je wijziging bewust gedrag (nieuwe move, andere formule), dan komt er een nieuwe golden in dezelfde commit.
De hash hangt af van de data van `_dummy` (moves, specials); verander die niet zonder de golden te vernieuwen.

## Resultaten (3600 frames, `_dummy` vs `_dummy`, HUD aan)

Gemeten op de dev-pc, headless. Tijden in **ms per frame**: gemiddelde / p99 / max. Basis = git HEAD vóór de pass.

Koude start (`--skip-real`: eerste match na het opstarten, wat een speler echt meemaakt):

| Subsysteem | Basis | Na |
|---|---|---|
| input | 0.006 / 0.015 / 0.12 | 0.006 / 0.015 / 0.14 |
| fighters (incl. visual) | 0.305 / 0.71 / **31.9** | 0.226 / 0.60 / 1.12 |
|  waarvan visual (pose + rig) | 0.178 / 0.44 / 0.69 | 0.139 / 0.36 / 0.61 |
| combat-resolve | 0.136 / 0.17 / **169.3** | 0.023 / 0.12 / 0.74 |
| specials-wereld | 0.056 / 0.19 / 0.35 | 0.044 / 0.16 / 0.31 |
| vfx-laag | 0.004 / 0.012 / 0.15 | 0.004 / 0.012 / 0.08 |
| match-controller | 0.081 / 0.02 / **171.6** | 0.013 / 0.03 / 0.85 |
| **sim totaal** | **0.601 / 0.93 / 172.2** | **0.333 / 0.75 / 1.35** |
| HUD (gemiddeld over alle frames) | 0.155 / 0.32 / 4.5 | 0.041 / 0.32 / 4.6 |

Warme start (tweede run in hetzelfde proces, caches gevuld):

| | Basis | Na |
|---|---|---|
| sim totaal | 0.431 / 0.90 / 10.1 | 0.334 / 0.74 / 1.39 |
| fighters / visual | 0.272 / 0.179 | 0.228 / 0.140 |
| combat | 0.064 / 0.19 / 0.78 | 0.023 / 0.11 / 0.73 |
| specials | 0.056 | 0.045 |
| HUD | 0.134 | 0.015 |

Belangrijkste bevinding: de **gemiddelde** sim-kosten waren al klein (0.4-0.6 ms van 16.6). Het echte probleem was
**hitches bij het eerste gebruik**: 13 frames > 5 ms in de eerste minuut, tot 170 ms (eerste KO), 70 ms (eerste respawn),
46 ms/24 ms (eerste treffers), 32 ms (eerste special). Oorzaak: `SfxBank` synthetiseert elk geluid pas bij de eerste
`Sfx.play` (`Sfx.preload_all` bestond maar werd nergens aangeroepen), KO-effect/special-scripts worden pas bij het eerste
gebruik geladen, en `LedgeGrip` parste bij de eerste ledge-grab alle pose-JSON opnieuw (10-25 ms). Nu geen enkel frame > 2 ms.

Objecten: start ~10150, einde ~10500 (stabiel, geen lek; de groei zit in tijdelijke VFX/entities). Statisch geheugen:
+4 MB per minuut; de koude start laat +147 MB zien die in de eerste frames ontstaat (waarschijnlijk font/SVG-textures;
niet onderzocht, geen groei daarna).

## Wat er veranderd is (zonder gedragswijziging; hash identiek)

- **Warm-up bij matchstart** (`MatchController._warm_up`): alle geluiden (`Sfx.preload_all` voor standaard + beide picks),
  KO-effect-scripts (`VfxLayer.warm_ko_effect`), special-definities/-scripts (`Specials.warm`). `SfxBank` deelt nu één stream
  per recept-pad (characters zonder eigen recept synthetiseren niet opnieuw).
- **LedgeGrip** wordt direct gevuld uit de al geladen `CharacterVisual.library` (geen tweede `PoseLibrary.load_for`).
- **CombatSystem.step**: hitboxen één keer per fighter verzameld (waren 2x), `CombatTarget`/already-hit/no-clank alleen
  gebouwd als er hitboxen zijn; geen `sort_custom` voor 2 fighters. **HitResolver**: geen string-keys per hitbox x doelwit
  (`Vector3i` voor "al geraakt dit frame", `hit_key` alleen als `already_hit` niet leeg is).
- **Fighter.hurtboxes()** gecachet per vorm + `visual_height` (waren 3 nieuwe `Resource`s per aanroep, meerdere aanroepen per frame).
- **Fighter._update_visual**: geen `"%d|%s"`-string per frame, scale/facing/position alleen bij verandering, en de overlay-
  nodes (shield, tekstwolk, debug, respawn-platform) herschilderen alleen als ze iets tonen (of net iets toonden).
- **CharacterVisual**: pose-sample in hergebruikte dictionaries (`Pose.sample_into`), dichte per-bot-arrays in `Pose`
  (geen dictionary-lookups per bot per key), `_apply` zet alleen botten die veranderden en slaat het hele sampelen over bij
  zelfde pose + zelfde frame (hitlag, houdposes), `set_props` zonder `str()` als er geen props zijn.
- **MatchHud**: redraw alleen als de getekende staat veranderde (signatuur van % / stocks / timer-seconde / countdown /
  banners / schud-animatie / pauze), niet elk frame.
- **SpecialWorld.step**: vroeg klaar zonder entities en zonder fighter in een special-state; fighters alleen sorteren als de
  volgorde niet klopt. **SpecialKit.poll**: één `state_name()`, geen `keys()`-kopieën van lege dictionaries.
- **Sim._advance**: hergebruikte tick-buffer i.p.v. `_entities.duplicate()` per frame.
- **VfxLayer**: maximaal 64 gelijktijdige effecten (oudste niet-KO-effect valt weg; KO-effecten nooit).
- **Meetinfrastructuur**: `engine/perf.gd` (`Perf.begin/end/count`, uit = 1 bool-check), `InputManager.scripted_source`
  (gescripte input voor bench/tests), probes `visual` in `Fighter._update_visual` en `hud` in `MatchHud._draw_all`.

## Regels voor performance-vriendelijke code (voor toekomstige agents)

1. **Geen nieuwe objecten per frame in hot paths** (`sim_tick`, states, `CombatSystem`, `HitResolver`, `SpecialWorld`, `_update_visual`,
   `vfx_tick`). Geen `Resource.new()`/`Dictionary`/`Array`/`str()`/`"%d" % x` per frame als een cache, hergebruikte buffer of
   integer-sleutel (`Vector3i`) volstaat. `Resource`s (HurtboxData, HitboxData) zijn zwaarder dan `RefCounted`; cache ze.
2. **Laad en bouw niets lui midden in een sim-frame**: scripts (`load()`), `.tres`, JSON, geluiden (`SfxBank`), SVG-rasters,
   `PoseLibrary.load_for` horen in de opbouwfase (`MatchController._ready/_warm_up`, `Fighter.setup`). Nieuw character met eigen
   assets (KO-effect, specials, sfx-recepten, props)? Zorg dat `_warm_up` ze laadt. Controleer met de bench (`--skip-real`)
   dat er geen `HITCH`-regels verschijnen.
3. **Cache `get_node`/`has_method`/`get_meta`-lookups** in een member (zie `Fighter._sim_node`); doe ze niet elk frame.
4. **Presentatie alleen bijwerken bij verandering**: `queue_redraw()` alleen als de inhoud veranderde (of net leeg moet),
   node-properties (`position`, `scale`, `rotation`, `modulate`, `visible`) alleen zetten als de waarde anders is: elke set
   triggert transform-/redraw-werk in de engine. HUD-achtige dingen: bouw een signatuur en vergelijk.
5. **Sorteer niet per frame** wat al gesorteerd is (controleer eerst; `sort_custom` maakt een Callable en is niet stabiel).
6. **Vroeg afhaken**: bouw dure structuren (CombatTarget, hurtbox-lijsten, already-hit-merges) pas als er iets is om te
   vergelijken (bv. `boxes.is_empty()` eerst).
7. **Begrens alles wat kan groeien**: effecten (`VfxLayer.MAX_EFFECTS`), entities (`SpecialWorld.GLOBAL_ENTITY_CAP`), logs.
8. **Gameplay blijft deterministisch**: een optimalisatie mag het resultaat nooit veranderen. Draai `bench --check` na elke
   wijziging in `engine/`. Gebruik geen `randf()`/`Time` in gameplay; `Perf` en `Time.get_ticks_usec` alleen voor meten.
9. Meten in code: `var t := Perf.begin()` ... `Perf.end(&"naam", t)` (kost niets als `Perf.enabled` uit staat); de bench
   toont onbekende sleutels automatisch onder de tabel.

## Beperkingen van de meting en resterende risico's

- Headless gebruikt een dummy-renderer: **GPU-kosten (draw calls, fill-rate, SVG-texturegrootte, `Skeleton2D`-updates in de
  echte renderer) zijn niet gemeten.** De `frame_total` van de bench (~6.9 ms) is vooral de wachttijd van de headless
  hoofdlus (lege iteratie ≈ 6.9 ms, gekalibreerd) en zegt niets over een windowed frame. Zinvol is alleen `sim_total`,
  `hud`, `visual` en de per-subsysteem tabel. Een windowed profielrun (Godot-profiler/monitors: draw calls, objecten) moet
  nog gedaan worden door de gebruiker.
- De sim kost ~0.35 ms gemiddeld voor 2 fighters; daar zit nog ~60% in de pose-berekening (`visual`, ~0.14 ms) en de
  state-machine. Een 4-spelers- of item-uitbreiding schaalt lineair; dan loont het om `state.pose()` (string-opbouw per frame)
  en `Pose.sample_into` verder te cachen, en per-fighter `_read_segments()` (nieuwe dictionaries per frame) te cachen met
  een stage-versie.
- `_read_segments`/`_read_ledges`/`SpecialGeometry.segments` bouwen nog elk frame nieuwe dictionaries uit de stage; niet
  gecachet omdat tests en toekomstige bewegende platforms de segmenten kunnen muteren (cache vereist een versieteller).
- De bench dekt `_dummy`-specials (charge/projectile, dash_strike, rising_multi, counter). Specials van andere characters
  (zwaardere sjablonen: trap, tether, spin) en 4 spelers zijn niet gemeten; draai `--p1 ID --p2 ID` na het bouwen van een character
  en vergelijk `specials`/`fighters` met de tabel hierboven.
- Eenmalige koude-start-kosten die nog bestaan (niet in een sim-frame): `Sfx.preload_all` bij matchstart (synthese van ~25 geluiden, niet apart gemeten;
  valt in het laadmoment/de countdown), eerste HUD-glyphs (4.5 ms).
