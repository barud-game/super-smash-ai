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
