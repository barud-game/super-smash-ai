# Validator

Headless tool dat moves en characters controleert tegen de balansregels (`docs/balans.md`) en de conversietabel
(`docs/move-conversie.md`). Code in `tools/validator/`, tests in `tests/test_validator.gd`.

## Gebruik

```
<godot_console> --headless --path . --script res://tools/validator/validate.gd -- --archetype <id>
<godot_console> --headless --path . --script res://tools/validator/validate.gd -- --character <id>
<godot_console> --headless --path . --script res://tools/validator/validate.gd -- --all
```

Opties kunnen gecombineerd worden (`--archetype allrounder --character ember`). `--json` print één JSON-regel
(`{"ok","fails","warns","passes","reports":[...]}`) in plaats van tekst; pak de regel die met `{` begint (Godot print eerst een banner).
Exit code: `0` als er geen FAIL is, `1` bij minstens één FAIL, `2` bij ontbrekende argumenten. WARN faalt nooit.

`--all` doet alle archetypes (mappen/`.tres` in `engine/fighter/archetypes/`) en alle characters in `characters/` (mappen die met `_` beginnen
worden overgeslagen). Eerst één keer `--headless --import` draaien als de class-cache ontbreekt (zie `tests/README.md`).

Uitvoer: één regel per move, `PASS|WARN|FAIL  <scope> <move> [S K B V]  <afwijkingen>`; afwijkingen noemen de gemeten waarde, het verwachte
getal en de score (bv. `startup 6, verwacht 5 voor S=4 (past bij score 3)`). Daarna een budgetregel per archetype/character en een samenvatting.

## Bestandsformaat

- Archetype: `engine/fighter/archetypes/<id>/moves/<move>.tres` (`MoveData`) + `scores.json` in dezelfde map.
  Move-namen: jab, ftilt, utilt, dtilt, dash_attack, fsmash, usmash, dsmash, nair, fair, bair, uair, dair, grab, fthrow, bthrow, uthrow, dthrow.
- `scores.json`: `{"jab": {"S":4,"K":1,"B":2,"V":2}, ...}`; throws alleen `S`,`K`; grab alleen `S`,`B`.
- Character: `characters/<id>/character.json` (veld `archetype`: `Allrounder`, `Fast-faller`, `Zwaargewicht`, `Floaty`, `Lichtgewicht` of de
  id's `heavyweight`/`lightweight`/`fast_faller`...), `characters/<id>/scores.json` en optioneel `characters/<id>/moves/*.tres`.
  Extra velden in `scores.json`: `"specials": {"neutral_b": {"S","K","B","V","U"}, "side_b", "up_b", "down_b"}`,
  `"movement_extras": {"extra_jump": -15, ...}`, `"op": false` (valt terug op `op` uit character.json).
  Moves zonder eigen `.tres` komen van het archetype (scores en budget); alleen eigen moves worden gevalideerd.

## Conversietabel = data

`tools/validator/conversion_table.gd` is de conversietabel van `docs/move-conversie.md` als data (startup, active, radius, reach, d/b/g, shield-advantage,
landing lag, worp-duur, angles, ...). **Bij elke wijziging in `docs/move-conversie.md` moet dit bestand mee (en andersom).** De validator bevat zelf
geen getallen uit de tabel.

## Wat wordt gecontroleerd (FAIL tenzij anders vermeld)

Frame-conventie: `MoveData`-frames zijn 0-based, de tabel is 1-based. `startup = min(start_frame) + 1`, `last_active = max(end_frame) + 1`,
`endlag = iasa_frame() - last_active` (`FRAME_BASE` in `validator.gd`).

Per grond-/luchtmove, tegen de score (exacte tabelwaarde, geen interpolatie):
- **Snelheid**: startup. **Worp**: `total_frames`; lanceerframe `round(total*0,5)` (WARN, ontwerpkeuze).
- **Bereik**: max-radius (±0,05), reach in de richting van het type (±1,5 unit; zie `REACH_DIR`), active frames van het eerste hit-blok (hitboxen met gap ≤ 3 frames = één blok). Disjoint-verwachting vanaf B ≥ 4 (WARN).
- **Kracht**: damage/BKB/KBG van de hoofd-hitbox (laatste hit-groep, hoogste damage); damage-plafond (jab 7, tilt 14, aerial 17, smash 24, worp 9);
  sourspot ×0,7 / BKB −10 (WARN); angle uit §6 (WARN).
- **Veiligheid grond**: shield-advantage op de laatste actieve frame `floor(0,448·d+2) − endlag` (d van de late hitbox) tegen de doelwaarde (±1).
  **Aerial**: landing lag, L-cancel-lag (= floor(LL/2)), `air_endlag` (±1), auto-cancel niet tijdens hitbox-frames (ontbreken = WARN).
- **Grab**: geen damage, `ignores_shield`, BKB 0/KBG 100 (WARN).
- **Sanity**: ≥ 1 hitbox; frames binnen `total_frames`/iasa; geen negatieve waarden/NaN; radius > 0; `total_frames` ≥ 10; offsets voor facing = +1
  (vooruit-moves niet achter de fighter, bair niet ervoor); aerials hebben `aerial=true` en landing lag, grondmoves niet; unieke hitbox-id's (WARN).
- **Scores**: alle assen aanwezig en in 0..5, niet alles 0, niet S/K/B/V alle vijf (specials: U 0..10; alles-0 incl. U).
- **Special-definities** (`characters/<id>/specials/<slot>.tres`, regel `special_def/<slot>`): sjablonen, parameterbereiken, director-besluiten en scores tegen de prijs-richtlijn; zie `docs/specials.md` §5 (`special_validator.gd`, `special_table.gd`).

## Afspraken van de director (`docs/standaard-movesets.md`)

- **Lengte-schaal (afspraak 9).** `validate_move(..., visual_height, grab)`; `visual_height` komt uit `engine/fighter/archetypes/<id>.tres`
  (of `visual_height` in `character.json`, anders 15). Reach = `positie langs de as / (visual_height / 15) + radius`; de radius schaalt niet.
  Definitie van de as (`REACH_DIR` in `conversion_table.gd`), altijd t.o.v. de fighter-oorsprong (de voeten):
  - utilt, usmash, uair: `+y` (omhoog, vanaf de voeten); dair: `-y` (omlaag, vanaf de voeten);
  - jab, ftilt, dtilt, dash attack, fsmash, grab, fair: `+x`; bair: `-x`; nair, dsmash: `|x|` (rondom) - aerials horizontaal vanaf het lichaamsmidden (x = 0).
- **Hoeken (afspraak 1, WARN).** Een hitbox met `offset.x < 0` en elke bthrow moet `angle > 90` hebben; 361 telt als vooruit (relatief aan de
  kijkrichting) en geeft ook een WARN. bair en de achterkant van nair/dsmash dus 135 (of 160). Bthrow-standaard 135.
- **Grab-whiff (afspraak 2, FAIL).** `total_frames = (max end_frame + 1) + 23` (dezelfde 1-based telling als bij `endlag`). Dash grab telt niet mee.
- **Throws (afspraak 3).** Launch-hitbox: radius 3,0 (FAIL), offset = de grab-tip (verste grab-hitbox, WARN; alleen als de grab bekend is),
  launch-frame `round(total x 0,5)` (WARN).
- **Rondom (afspraak 10, FAIL).** nair en dsmash: minimaal een box met `x > 0` en een met `x < 0`.
- **Sourspot en sex kick (afspraken 5 en 7, WARN).** Per hit-groep zijn alle boxen die van de sterkste box verschillen sourspots:
  damage `round(0,7 x d)`, BKB -10 (min 0), KBG gelijk. Een box op dezelfde positie die later start (zelfde groep) is het late blok van
  een sex kick en moet dezelfde regel volgen ("sex-kick late blok").
- **Multi-hit (afspraak 6, WARN).** Alle groepen voor de laatste: damage 1-2, BKB <= 10, hoek 361 (of gelijk aan de finisher; 270-290 bij dair).
- **Hoogtes (afspraak 8, WARN).** jab/ftilt/dash/fsmash/grab: y ~ 0,55 x visual_height (+-12%); nair/fair/bair: elke box op 15-40% van visual_height (doel 30%) en de onderste box <= 35% (onder de heup; `HEIGHT_AERIAL_*` in `conversion_table.gd`);
  dtilt/dsmash: y = 2 (+-1).

## Budget

- Archetype: som van de normals (S+K+B+V; throws S+K; grab S+B) ≤ 200.
- Character: normals (eigen of van het archetype) + specials (S+K+B+V+U) + movement-extras ≤ 200. Extras zijn punten uit `balans.md` sectie 2:
  `extra_jump: -15` kost 15, een nadeel zoals `no_double_jump: 20` levert 20 op (kosten = −som van de waarden).
- `op: true`: boven 200 is toegestaan en geeft alleen een `OP:`-melding (blijft PASS); alle andere regels blijven gelden.

## Bekende beperkingen

Reach en kill-percentages zijn schattingen (⚠️ in move-conversie.md). Multi-hit, projectielen en specials-gedrag worden niet gemeten; specials
worden alleen op scorebereik en budget gecontroleerd.
