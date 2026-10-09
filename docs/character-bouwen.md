# Character bouwen — draaiboek voor de director

Dit is het complete stappenplan waarmee een **nieuwe chat** zonder voorkennis een character kan ontwerpen en bouwen.
Het gesprek met de speler staat in `docs/character-creatie.md`; de regels voor punten in `docs/balans.md`.
Voorbeeld van een af character: `characters/captain_pep/`.

## 0. Voor je begint
1. Lees `CLAUDE.md` (director-werkwijze, screenshot-regel, gebruikslimieten), `PLAN.md` (status),
   `docs/character-creatie.md`, `docs/balans.md`, `docs/standaard-movesets.md`, `docs/specials.md`, `docs/special-sjablonen.md`.
2. Check het gebruik (`get_usage`). Een character bouwen kost ~5–7 agent-runs; begin niet boven ~75% van een limiet.

## 1. Originaliteit (harde regel)
- Elk character is **origineel**: eigen naam, eigen uiterlijk, eigen move-namen.
- Noemt de speler een bestaand personage (game, film, strip): maak een eigen character met **dezelfde sfeer/speelstijl**.
  Mechanieken mogen lijken (bv. "trage stoot die vroeg killt"), de identiteit niet.
- **Geen verbasterde namen** (een paar letters veranderd, vertaald, of een rijmvorm van het origineel) en geen
  herkenbaar kostuum/embleem. Ook niet "als satire": satire mag alleen als het character een eigen identiteit heeft.
- Leg dit kort en vriendelijk uit en stel meteen een alternatief voor; niet preken.
  (Voorbeeld uit de praktijk: speler wilde een bekende racer; het werd **Captain Pep**, een eigen chaos-racer met
  eigen look, hamburger-neutral-B en racefiets-side-B.)

## 2. Gesprek → ontwerp (director, geen agents)
Volg `docs/character-creatie.md`: één open vraag, dan een compleet voorstel, dan bijsturen.
Schrijf het voorstel in `characters/_concepten/<id>/ontwerp.md` (map met `_` = niet in de roster en niet in de validator).
Inhoud van `ontwerp.md`: concept, uiterlijk, persoonlijkheid/taunt, archetype + aanvullingen, 4 specials
(naam, wat het doet, sjabloon(en), S/K/B/V/U), afwijkende normals (S/K/B/V), puntentabel, KO-effect, wijzigingslog.
**Pas bouwen na expliciet akkoord van de speler.**

## 3. Na akkoord: bestanden die de director zelf maakt
1. `git mv characters/_concepten/<id> characters/<id>` en zet de status in `ontwerp.md` op AKKOORD.
2. `characters/<id>/character.json` — id, name, archetype (zoals in balans.md), op, `visual_height` (8–30),
   tagline, `taunt_text`, colors (+ eventueel `taunt_props`). Volledig formaat: `docs/character-creatie.md`.
3. `characters/<id>/scores.json` — afwijkende normals (`"fair": {"S":..,"K":..,"B":..,"V":..}`), `specials`
   (`neutral_b/side_b/up_b/down_b` met S/K/B/V/U), `movement_extras` (namen uit balans.md sectie 2), `op`.
4. Optioneel `characters/<id>/stats.tres` alleen als archetype + aanvullingen niet volstaan.
5. Maak de mappen `moves/`, `specials/`, `art/` (+ `art/props/`), `ko_effect/`, eventueel `poses/`.

## 4. Agents starten (parallel, elk met een afgebakend terrein)
| Agent | Terrein | Opdracht |
|---|---|---|
| `svg-artist` | `characters/<id>/art/` (+ `props/`) | Alle rig-onderdelen + props, origineel, palette-swap-kleuren; levert preview-commando aan |
| `normals-builder` | `characters/<id>/moves/` | Alleen de afwijkende normals uit scores.json; validator draaien |
| `ko-effect-builder` | `characters/<id>/ko_effect/` | KO-effect volgens `docs/vfx.md` |
| `special-builder` (×1–4) | `characters/<id>/specials/` | Specials als `SpecialDef` (sjabloon-config, zie `docs/specials.md`), incl. prop-events en poses; eigen script alleen als geen sjabloon past |

Geef elke agent: het pad naar `ontwerp.md`, zijn terrein, en de regel "geen windowed runs, niet committen".
Specials kunnen pas als de benodigde props bestaan (prop-naam afspreken in de opdracht; de art mag parallel).

## 5. Controle (director)
1. Validator: `--headless --path . --script res://tools/validator/validate.gd -- --character <id>` → 0 FAIL.
2. Alle tests headless (zie `tests/README.md`), met timeout per suite.
3. **Waarschuw de gebruiker in de chat**, draai dan de preview-/screenshot-commando's van de agents
   (venster buiten beeld: `--position -20000,-20000`) en bekijk de PNG's. Terug naar de agent bij problemen.
4. Commit per onderdeel; werk `PLAN.md` en het wijzigingslog in `ontwerp.md` bij.

## 6. Speeltest en bijstellen
De speler test in Training (dummy = willekeurig ander character) of Fight. Feedback in gewone taal →
de director vertaalt naar score-/parameterwijzigingen binnen het budget, past `scores.json`/`ontwerp.md` aan en laat de
betreffende agent de data bijwerken. Validator + tests opnieuw, commit.
