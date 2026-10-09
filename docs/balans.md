# Balans: het 200-puntensysteem

De speler bedenkt alleen **wat** moves doen. Claude bepaalt de **getallen** (frames, damage, knockback)
en houdt het eerlijk met een budget van **200 punten** per character.

> Status: eerste versie. Wordt gekalibreerd in M5 door Melee-referentiecharacters te "prijzen".

## 1. Movement-archetype (gratis basis)

Elke speler kiest één archetype. De afwegingen zitten al in het archetype, dus dit kost niets.
Exacte stats worden in M1 ingevuld op basis van Melee-referentiewaarden.

| Archetype | Gevoel | Sterk | Zwak |
|---|---|---|---|
| **Zwaargewicht** | Groot, traag, onverwoestbaar | Overleeft lang, harde klappen | Combo-food, trage jumpsquat, slechte recovery |
| **Allrounder** | Middel in alles | Geen echte zwaktes | Geen echte uitblinkers |
| **Fast-faller** | Snel, scherp, agressief | Snelle dash, 3-frame jumpsquat, lange wavedash | Wordt makkelijk gecombood, sterft vroeg horizontaal |
| **Floaty** | Zweverig, luchtgevecht | Air drift, lange aerial-tijd, overleeft verticaal | Traag naar de grond, makkelijk te jugglen |
| **Lichtgewicht** | Klein en razendsnel | Kleinste hurtbox, snelste grondbeweging | Sterft heel vroeg |

Elk archetype heeft ook een **standaard-moveset** (alle normals, al geprijsd en gebalanceerd).
Een nieuw character begint daarmee; alleen afwijkende moves worden opnieuw geprijsd.

### Lengte
Elk character heeft een `visual_height` (vloer tot kruin, Melee-units). Toegestaan: **8–30 units** (archetypes: 11–19).
Groot zijn is een eigen nadeel (grotere hurtbox) en kost niets. **Kleiner dan het archetype** maakt je moeilijker te raken
en kost **−2 per unit** onder de archetype-lengte. De validator rekent dat mee in het budget (`height_cost`, `Validator.HEIGHT_COST_PER_UNIT`): archetype 12, character 9 = 3 units = 6 punten. De lengte komt uit `visual_height` in `character.json` (buiten 8–30 wordt hij geklemd en geeft de validator een FAIL). Alle systemen (ledge, hitboxes, hurtboxes, VFX) schalen mee met de lengte.

## 2. Aanvullingen op movement (kosten punten)

Spelers mogen aanvullen. Een aanvulling kost punten, een nadeel levert punten op.
Voorbeelden (prijzen voorlopig):

| Aanvulling | Punten |
|---|---|
| Extra midair jump | −15 per jump |
| Wall jump | −5 |
| Glide | −10 |
| Langere wavedash (lagere traction) | −5 |
| Snellere jumpsquat (−1 frame) | −8 |
| Zwaarder binnen archetype | −5 |
| Lichter binnen archetype | +5 |
| Geen double jump | +20 |
| Tragere dash | +5 |

### Naam -> effect in de engine

De sleutel in `movement_extras` van `scores.json` (waarde = punten uit de tabel hierboven) bepaalt welke stat-aanpassing
`CharacterLoader.stats_for(id)` op de archetype-preset toepast (`engine/roster/character_loader.gd`, tabel `EXTRAS`).
Aliassen (Engels) staan tussen haakjes. Een onbekende sleutel geeft een waarschuwing en doet niets (validator: WARN).

| Naam | Effect op `FighterStats` | Referentie / opmerking |
|---|---|---|
| `zwaarder` (`heavier`) | `weight` × 1,10 ⚠️ | Fox 75 -> 82,5 |
| `lichter` (`lighter`) | `weight` × 0,90 ⚠️ | Fox 75 -> 67,5 |
| `extra_jump` | `air_jumps` + 1 (zelfde `air_jump_v_multiplier`) | Melee: Jigglypuff 5 sprongen |
| `geen_double_jump` (`no_double_jump`) | `air_jumps` = 0 | |
| `snellere_jumpsquat` | `jumpsquat_frames` − 1, minimaal 2 ⚠️ | Fox/Falco 3 frames; 2 bestaat niet in Melee |
| `tragere_dash` (`slower_dash`) | `dash_initial_velocity` × 0,8 en `dash_accel_additional` × 0,85 ⚠️ | run speed ongemoeid |
| `langere_wavedash` (`longer_wavedash`) | `traction` × 0,8 ⚠️ | minder wrijving = langere slide (ook elke andere sliding) |
| `glide` | `stats.glide = true` | ⚠️ alleen vlag, mechaniek nog niet gebouwd |
| `wall_jump` (`walljump`) | `stats.wall_jump = true` | ⚠️ alleen vlag, stages hebben nog geen muren |

Volgorde in `stats_for`: preset (kopie) -> `visual_height` uit `character.json` (8–30, geklemd + waarschuwing) -> extras in de
volgorde van `scores.json`. Een `characters/<id>/stats.tres` vervangt dit alles (volledige override).

## 3. Moves

22 moves per character:
- **Specials (4):** neutral-B, side-B, up-B, down-B
- **Grond (8):** jab, f-tilt, u-tilt, d-tilt, dash attack, f-smash, u-smash, d-smash
- **Lucht (5):** nair, fair, bair, uair, dair
- **Grab (5):** grab, f-throw, b-throw, u-throw, d-throw

Elke move scoort Claude op vier assen (0–5):

| As | 0 | 5 |
|---|---|---|
| **Snelheid** | 20+ frames startup | frame 1–3 |
| **Kracht** | ~niets | killt rond 80% |
| **Bereik** | piepkleine hitbox | groot, disjoint, of projectiel over het hele scherm |
| **Veiligheid** | enorme endlag | vrijwel safe on shield |

Specials krijgen daarnaast **Utility (0–10)**: recovery-afstand, projectiel, armor, counter, reflector,
command grab, teleport, etc.

De conversie van scores naar concrete frame data, hitboxen en knockback staat in `docs/move-conversie.md`.

**Throws** scoren alleen op Snelheid en Kracht (max 10); Bereik en Veiligheid tellen niet mee.
**Grab** scoort alleen op Snelheid en Bereik (max 10). De standaard-movesets per archetype staan in
`docs/standaard-movesets.md` (normals ~140 punten, dus ~60 over voor specials en aanvullingen).

**Kosten van een move = som van de assen.** Een "gemiddelde" move kost ~8. De 22 moves samen,
plus de movement-aanvullingen, moeten **≤ 200** uitkomen.

## OP-characters
Een speler mag bewust boven de 200 gaan, voor de lol. Dan: `op = true`, de puntentabel toont het totaal,
en de character select markeert het character duidelijk als OP. Wel alle andere regels (sanity, validator).

## 4. Regels voor Claude
- De speler noemt nooit getallen; Claude vertaalt een omschrijving ("supersnelle maar zwakke jab") naar scores.
- Gaat het over budget, dan stelt Claude een **ruil** voor ("je up-B wordt zo goed dat ik je smashes iets
  trager maak — akkoord?"). De speler beslist wat er inlevert.
- Moves die de speler niet beschrijft, vult Claude zelf in, passend bij archetype en thema.
- Geen move mag 0 op álle assen hebben, en geen move mag 5 op alle vier de basisassen hebben.
- Het eindoverzicht met de puntentabel wordt opgeslagen in `characters/<id>/ontwerp.md`.
