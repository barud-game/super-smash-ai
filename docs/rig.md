# Rig: het gedeelde SVG-skelet

Eén skelet + één set animaties voor alle characters. Een character = een map `characters/<id>/art/` met
SVG-onderdelen. De code staat in `engine/visual/` (`rig.gd` = de definitie; **dit document en `rig.gd` moeten
gelijk blijven**). Alles hier is puur visueel: geen gameplay, physics of input.

Voorbeeld om te kopiëren: `characters/_dummy/art/` (houten oefenpop).

## 1. Maten en coördinaten

- **1 art-px = 1 game-px.** `UNIT_TO_PX = 7`, dus 7 art-px = 1 Melee-unit.
- Standaardhoogte (vloer tot kruin van het hoofd, rustpose): **156 px ≈ 22 Melee-units**. Een gedrongen of
  lang character mag afwijken door het hoofd/de romp groter of kleiner te tekenen, maar **de gewrichten
  (pivots) en botlengtes blijven gelijk**; hoogte-afwijking van ±15% is prima.
- Het character kijkt in de SVG **naar rechts** (+x). Links kijken = automatisch gespiegeld.
- y wijst omlaag (SVG-conventie). Oorsprong van het skelet = midden van de voeten op de grond.
- Rasteren: de SVG wordt op 2x gerasterd en op 0.5 getoond, dus scherp tot 2x zoom. Teken in de nominale
  canvasmaat hieronder; het `viewBox` moet gelijk zijn aan `0 0 <breedte> <hoogte>`.

## 2. Botten (hiërarchie)

```
root                      (voeten-midden op de grond)
└─ hip                    (0,-68)  bekken; hip beweegt omhoog/omlaag voor hurken, rotatie = hele lichaam (flips)
   ├─ torso               (0,-6)   t.o.v. hip
   │  ├─ head             (0,-38)  nek
   │  ├─ upper_arm_l/_r   (0,-34)  schouders
   │  │  └─ forearm_*     (0,26)   elleboog
   │  │     └─ hand_*     (0,24)   pols
   │  │        └─ weapon_r (0,6)   (alleen rechterhand) grip
   │  └─ cape             (-4,-34) hangt van de schouders, achter de romp
   ├─ thigh_l/_r          (0,0)    heupgewricht
   │  └─ shin_*           (0,32)   knie
   │     └─ foot_*        (0,31)   enkel
```

Botlengtes: bovenarm 26, onderarm 24, bovenbeen 32, onderbeen 31. `_r` = **nabije** kant (getekend vóór de romp),
`_l` = **verre** kant (achter de romp, automatisch ~25% donkerder getoond). In de rustpose hangen armen en benen
recht omlaag.

## 3. Onderdelen (SVG-bestanden)

Alle bestanden in `characters/<id>/art/<naam>.svg`. **Pivot = het gewricht** in canvas-px (linksboven = 0,0);
dat punt komt precies op de bot te liggen. Wat aan de ene kant van de pivot hangt, draait mee.

| Bestand | Verplicht | Canvas (b×h) | Pivot (x,y) | Oriëntatie in de SVG |
|---|---|---|---|---|
| `head.svg` | ja | 72×72 | 36,60 | Nek-onderkant op de pivot; hoofd erboven, kijkt naar rechts. Kruin ca. y=14, kin ca. y=56. Nek mag tot y=60 doorlopen |
| `torso.svg` | ja | 56×64 | 28,52 | Pivot = taille. Romp loopt omhoog tot de nek (y≈15), schouders op y≈18; tot y≈62 doorlopen (overlapt bekken) |
| `pelvis.svg` | ja | 44×26 | 22,12 | Bekken, midden op de heup. Wordt door `hip` aangestuurd |
| `upper_arm.svg` | ja | 24×40 | 12,8 | Schouder op de pivot, arm wijst **recht omlaag**; elleboog op y=34 (mag tot y≈38 doorlopen) |
| `forearm.svg` | ja | 22×38 | 11,8 | Elleboog op de pivot, wijst omlaag; pols op y=32 |
| `hand.svg` | ja | 20×20 | 10,6 | Pols op de pivot; vuist/hand eronder (middelpunt y≈12) |
| `thigh.svg` | ja | 28×48 | 14,8 | Heup op de pivot, been wijst omlaag; knie op y=40 |
| `shin.svg` | ja | 26×46 | 13,8 | Knie op de pivot, wijst omlaag; enkel op y=39 |
| `foot.svg` | ja | 44×20 | 12,10 | Enkel op de pivot, **voet wijst naar rechts**; zool (grondlijn) op y=15; hiel x≈4, teen x≈40 |
| `cape.svg` | nee | 56×100 | 46,6 | Cape/jas-achterpand/sjaalstaart: bevestigingspunt op de pivot, hangt **omlaag**, mag naar links (achter) wapperen |
| `hair_back.svg` | nee | 72×72 | 36,60 | Haar dat **achter** het hoofd (en achter de romp) hangt. Zelfde canvas als `head.svg` |
| `hair_front.svg` | nee | 72×72 | 36,60 | Haar/band/pony **over** het hoofd. Zelfde canvas en uitlijning als `head.svg` |
| `hat.svg` | nee | 72×72 | 36,60 | Hoed/helm/masker boven alles op het hoofd. Zelfde canvas als `head.svg` |
| `weapon.svg` | nee | 64×128 | 32,24 | Wapen/voorwerp in de **rechterhand**; greep op de pivot, voorwerp wijst **omlaag** (de hand/pols oriënteert het) |

### Links/rechts (verre kant)
Standaard gebruikt het rig **één bestand voor beide kanten** (`upper_arm.svg` voor `_l` én `_r`). Wil een character
een asymmetrisch onderdeel (bv. een handschoen links, een bandage rechts)? Maak dan `<naam>_l.svg` of `<naam>_r.svg`
(bv. `hand_r.svg`); dat overschrijft het gedeelde bestand voor die kant. Zelfde canvas en pivot.

### Tekenvolgorde (achter → voor)
`cape` · `hair_back` · verre arm (`upper_arm_l`, `forearm_l`, `hand_l`) · verre been (`thigh_l`, `shin_l`, `foot_l`) ·
`pelvis` · nabije been (`thigh_r`, `shin_r`, `foot_r`) · `torso` · `head` · `hair_front` · `hat` ·
nabije arm (`upper_arm_r`, `forearm_r`, `hand_r`) · `weapon`.
Consequentie voor de artist: het nabije been en de nabije arm worden **over** de romp getekend, dus ze moeten er
als losse delen goed uitzien; het onderste stuk van de romp (y 52–62) wordt door het bekken/bovenbeen overlapt.

### Gewrichten laten aansluiten
Bij elke rotatie moeten de uiteinden aansluiten zonder gat. Regel: **maak elk onderdeel aan het uiteinde dat naar het
volgende gewricht wijst afgerond (een cirkel met straal = halve dikte, gecentreerd op dat gewricht)** en laat het
~4–6 px voorbij het gewricht doorlopen, dan dekt het kind-onderdeel de naad. Kleding (mouwen, broekspijpen) volgt
dezelfde regel; een gat verschijnt anders bij elleboog/knie bij gebogen poses.

## 4. Stijl

- Platte kleurvlakken met een **donkere outline** (aanbevolen `#1b1b24`, 3 px, `stroke-linejoin="round"`,
  `stroke-linecap="round"`). Max. één highlight- en één schaduwtint per vlak.
- Leesbaar op klein formaat (in het spel is het character 156 px hoog): geen details kleiner dan ~3 px.
- Geen filters, blur, masks, `<text>`, ingesloten afbeeldingen of CSS-klassen; gewone `path`, `rect`, `circle`,
  `ellipse`, `polygon`, vlakke vullingen en simpele gradients werken. (Godot rastert met ThorVG.)
- Een SVG met een afwijkende canvasmaat geeft een waarschuwing; ontbrekende verplichte onderdelen een foutmelding.

## 5. Kleuren, varianten en spelers (palette swap)

Elk character heeft zijn eigen kleuren in de SVG's, **plus teamaccenten** die per speler wisselen zodat speler 1 en 2
altijd te onderscheiden zijn. Gebruik daarvoor in de SVG precies deze gereserveerde kleuren (6-cijferig hex, kleine
letters, in `fill`/`stroke`):

| Gereserveerd | Betekenis | Speler 1 (rood) | Speler 2 (blauw) | Speler 3 (groen) | Speler 4 (geel) |
|---|---|---|---|---|---|
| `#ff00ff` | teamkleur, hoofdtint | `#e5423b` | `#3b7be5` | `#3fb85a` | `#e5b93b` |
| `#a000a0` | teamkleur, schaduw | `#9a1f2a` | `#1f3f9a` | `#1d6e33` | `#9a7414` |
| `#ff99ff` | teamkleur, highlight | `#ff958c` | `#8cb8ff` | `#97e8a8` | `#ffe28c` |

Regels voor de artist:
- Elk character gebruikt de teamkleur op **minstens één groot, goed zichtbaar onderdeel** (sjaal, band, riem, mouwen,
  cape, schoenen...), zodat het in een gevecht direct leesbaar is wie wie is. De rest van het kostuum **niet** in
  teamkleur, anders verlies je de eigen identiteit.
- Gebruik de gereserveerde kleuren nooit voor iets anders (ook niet "bijna" magenta).
- Tint voor de verre kant en spiegeling gebeuren automatisch; teken niet twee varianten.
- Latere varianten (alternatieve kostuums) komen als extra palette-sets in `Rig.PLAYER_PALETTES`/later per character;
  dat vraagt geen aanpassing van de SVG's.

## 6. Poses en animaties

JSON in `engine/visual/poses/*.json` (gedeeld, voor iedereen). Een character mag eigen of overschreven poses leggen in
`characters/<id>/poses/*.json`. Bestand = `{ "<pose>": {...}, ... }`; namen die met `_` beginnen worden genegeerd.

```json
"walk": {
  "loop": true,            // herhaalt; length = de periode in frames
  "length": 36,            // frames (60 Hz). Zonder loop: standaard de tijd van de laatste key
  "blend": 4,              // frames crossfade vanuit de vorige pose bij play()
  "interp": "spline",      // "linear" | "spline" (standaard: spline bij loop, linear anders)
  "keys": [
    { "t": 0,
      "r": { "thigh_r": -26, "shin_r": 6 },   // rotatie in graden per bot (ontbrekend = 0 = rust)
      "o": { "hip": [0, 3] },                  // offset in px t.o.v. rustpositie
      "drop": 4 }                              // optioneel: heup zakt 4 px, benen krijgen automatisch passende hoeken
  ]
}
```

- **Rotatie-conventie:** Godot, positief = kloksgewijs op het scherm (character kijkt rechts).
  Romp/hoofd: `+` = voorover. Arm/been (hangen omlaag): `+` = naar **achteren** zwaaien, `-` = naar voren.
  `shin +` = knie buigt, `forearm -` = elleboog buigt, `foot +` = neus omlaag. `hip` rotatie draait het hele lichaam
  om de heup (flips). De offset van `hip` verplaatst het hele lichaam t.o.v. de voeten (hurken).
- `drop` zorgt dat de voeten bij hurken/landen plat onder de heup blijven (twee-botten-IK, alleen verticaal);
  expliciete rotaties in dezelfde key winnen.
- Beschikbare botnamen voor `r`/`o`: `hip torso head upper_arm_l/r forearm_l/r hand_l/r thigh_l/r shin_l/r foot_l/r cape weapon_r`.

### Movement-poses (M1)
`idle` (adem, loop) · `walk` (loop 36f) · `dash` (loop 20f) · `run` (loop 28f) · `skid` · `turn` · `crouch` ·
`jumpsquat` · `jump` (opwaarts) · `fall` (loop) · `fastfall` · `jump_aerial` (double-jump flip, 30f) · `airdodge` ·
`land` · `landfall` (landing-fall/helpless land) · `wavedash` (slide). De fighter kiest de pose-naam uit zijn state;
`CharacterVisual.play()` valt bij een onbekende naam terug op `idle` (met één waarschuwing).

### Naamgeving aanvallen (M3, nog niet gebouwd)
`atk_<move>` in `engine/visual/poses/attacks.json`, bv. `atk_jab1`, `atk_ftilt`, `atk_utilt`, `atk_dtilt`, `atk_fsmash`,
`atk_usmash`, `atk_dsmash`, `atk_nair`, `atk_fair`, `atk_bair`, `atk_uair`, `atk_dair`, `atk_grab`, `atk_throw_f`,
`atk_special_n`, `atk_special_s`, `atk_special_u`, `atk_special_d`. Hitstun/defensie: `hit`, `shield`, `roll`, `spotdodge`,
`ledge_hang`, `ledge_getup`, `dead`.

## 7. Gebruik in code

```gdscript
var cv := CharacterVisual.new()
cv.character_id = "_dummy"     # leest res://characters/_dummy/art/
cv.player_index = 0            # 0 = speler 1 (rood), 1 = speler 2 (blauw), ...
cv.position = Units.to_px(fighter_pos_in_units)   # voeten-midden
add_child(cv)

# per sim-frame (vanuit de fighter, in _physics_process):
cv.facing = fighter.facing                    # +1 / -1
cv.play(fighter.state_name, false)            # zelfde state blijft doorlopen; nieuwe state start vanaf frame 0
cv.tick(fighter.state_frame)                  # expliciete frame: deterministisch, werkt met frame advance
# loop-animaties die op snelheid horen te lopen: cv.tick(frame, speed_factor)

cv.reload()   # hot reload: leest SVG's en poses opnieuw van schijf (training mode)
```

- `CharacterVisual` heeft **geen eigen klok**; hij beweegt alleen als de fighter `tick` aanroept.
- Fouten: `cv.is_valid`, `cv.errors`, `cv.warnings` (ook als `push_error`/`push_warning`). Ontbrekende optionele
  onderdelen worden gewoon weggelaten; ontbrekende verplichte geven een duidelijke fout met het verwachte pad.
- SVG's worden bij runtime ingelezen met `Image.load_svg_from_string` (geen editor-import nodig), dus hot reload werkt
  ook voor nieuwe/gewijzigde bestanden. Let op: voor een geëxporteerde build moeten `*.svg` en `*.json` in de
  export-filters staan.

## 8. Preview en viewer

**Contactsheet naar PNG** (windowed; `--headless` rendert niet). Vanuit de repo-root:

```
"C:\Users\yassi\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe" --path . res://tools/preview/preview.tscn -- --character _dummy --out C:/Users/yassi/Documents/super-smash-ai/tools/preview/out/_dummy.png
```

Toont speler 1 (rechts kijkend) en speler 2 (links kijkend) naast elkaar plus alle movement-poses op sleutelframes
(speler-1-kleuren, of `--player 2`). Het venster sluit zichzelf. Exit code 1 bij fouten in het character
(foutmeldingen op stderr). Bekijk de PNG met de Read-tool. `--out` is een absoluut pad (zonder: `user://preview_<id>.png`).

Eén pose groot bekijken:
```
... preview.tscn -- --character _dummy --pose walk --frames 0,9,18,27 --zoom 1.6 --player 2 --out <pad>.png
```

**Pose-viewer** in de editor: open `tools/preview/pose_viewer.tscn` en druk op F6. Pijltjes links/rechts = pose,
omhoog/omlaag = tempo, spatie = pauze, `,` `.` = frame, F = spiegelen, P = spelerskleur, C = ander character, R = herladen.

**Tests:** `Godot_console.exe --headless --path . --script res://tests/test_visual.gd`.
