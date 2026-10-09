# Standaard-movesets per archetype

Elk nieuw character begint met de standaard-moveset van zijn archetype. Alleen moves die het thema
anders vraagt worden opnieuw geprijsd en gebouwd. Scores per as volgens `docs/balans.md`,
omgerekend naar data met `docs/move-conversie.md`.

Notatie: **S/K/B/V** = Snelheid / Kracht / Bereik / Veiligheid (0–5).
- **Grab** scoort alleen S/B (snelheid, bereik). **Throws** alleen S/K.
- Normals-totaal ligt rond **140**, zodat er ~60 punten over zijn voor 4 specials en movement-aanvullingen.

Data staat in `engine/fighter/archetypes/<archetype>/moves/<move>.tres`.
Een character met eigen moves overschrijft per move in `characters/<id>/moves/<move>.tres`.

## Allrounder — totaal 148
Gebalanceerd, disjoint-achtig bereik, betrouwbare aerials.

| Move | S/K/B/V | Pts | Karakter |
|---|---|---|---|
| jab | 4/1/2/2 | 9 | 2-hit jab |
| ftilt | 3/2/3/2 | 10 | brede voorwaartse slag |
| utilt | 3/2/2/2 | 9 | boog boven het hoofd |
| dtilt | 3/1/2/3 | 9 | lage poke |
| dash_attack | 2/2/2/1 | 7 | doorrennende slag |
| fsmash | 1/4/3/1 | 9 | grote voorwaartse slag, sterke tip |
| usmash | 2/3/2/1 | 8 | opwaartse stoot |
| dsmash | 2/3/3/1 | 9 | voor- en achterzwaai |
| nair | 3/1/2/3 | 9 | draai rondom |
| fair | 3/2/3/3 | 11 | voorwaartse boog (kernmove) |
| bair | 3/3/2/2 | 10 | achterwaartse slag |
| uair | 3/2/2/3 | 10 | boog omhoog |
| dair | 1/3/2/1 | 7 | meteor onder |
| grab | 3/–/2/– | 5 | |
| fthrow | 3/1 | 4 | |
| bthrow | 2/2 | 4 | |
| uthrow | 3/1 | 4 | combo-starter |
| dthrow | 3/1 | 4 | |

## Fast-faller — totaal 137
Snel, laag vermogen per hit, sterke combo-aerials en combo-throws.

| Move | S/K/B/V | Pts | Karakter |
|---|---|---|---|
| jab | 5/1/1/3 | 10 | razendsnelle jab, rapid-jab-afsluiter |
| ftilt | 4/1/2/2 | 9 | snelle trap |
| utilt | 4/1/2/3 | 10 | combo-starter omhoog |
| dtilt | 4/1/1/2 | 8 | korte veeg |
| dash_attack | 3/1/1/1 | 6 | glijdende trap |
| fsmash | 3/3/2/1 | 9 | snelle killtrap |
| usmash | 3/4/2/0 | 9 | sterke opwaartse trap (kill) |
| dsmash | 3/2/2/1 | 8 | split-trap |
| nair | 4/1/1/3 | 9 | sex kick (sterk begin, zwak einde) |
| fair | 3/1/2/2 | 8 | multi-hit |
| bair | 4/3/1/3 | 11 | sterke achterwaartse trap |
| uair | 4/3/1/2 | 10 | killer omhoog |
| dair | 3/1/1/3 | 8 | multi-hit drill |
| grab | 3/–/1/– | 4 | |
| fthrow | 3/1 | 4 | |
| bthrow | 3/1 | 4 | |
| uthrow | 4/1 | 5 | combo-throw |
| dthrow | 4/1 | 5 | combo-throw |

## Zwaargewicht — totaal 139
Traag, enorm hard, groot bereik, onveilig.

| Move | S/K/B/V | Pts | Karakter |
|---|---|---|---|
| jab | 2/2/2/1 | 7 | zware stoot |
| ftilt | 2/3/3/1 | 9 | lange trap |
| utilt | 1/4/3/0 | 8 | trage maar verwoestende stamp/opwaartse slag |
| dtilt | 2/2/3/1 | 8 | lange lage veeg |
| dash_attack | 1/3/2/0 | 6 | schouderstoot |
| fsmash | 0/5/3/0 | 8 | gigantische klap |
| usmash | 1/5/2/0 | 8 | |
| dsmash | 1/4/3/0 | 8 | |
| nair | 2/3/2/2 | 9 | |
| fair | 1/4/3/1 | 9 | zware slag |
| bair | 2/4/2/2 | 10 | achterwaartse trap |
| uair | 2/3/2/2 | 9 | |
| dair | 1/5/2/0 | 8 | sterke stomp (meteor) |
| grab | 1/–/3/– | 4 | |
| fthrow | 2/3 | 5 | |
| bthrow | 2/3 | 5 | |
| uthrow | 2/2 | 4 | |
| dthrow | 2/2 | 4 | |

## Floaty — totaal 140
Sterk in de lucht, zwakker op de grond.

| Move | S/K/B/V | Pts | Karakter |
|---|---|---|---|
| jab | 3/1/2/2 | 8 | |
| ftilt | 3/2/2/2 | 9 | |
| utilt | 3/2/3/2 | 10 | brede boog omhoog |
| dtilt | 3/1/2/2 | 8 | |
| dash_attack | 2/2/2/1 | 7 | |
| fsmash | 1/4/2/1 | 8 | |
| usmash | 2/3/2/1 | 8 | |
| dsmash | 2/3/2/1 | 8 | |
| nair | 4/2/2/4 | 12 | sex kick, uitstekend uit shield |
| fair | 3/3/3/3 | 12 | |
| bair | 3/3/2/4 | 12 | veilige wall-of-pain-bair |
| uair | 3/2/3/3 | 11 | |
| dair | 2/2/2/3 | 9 | multi-hit |
| grab | 2/–/2/– | 4 | |
| fthrow | 2/2 | 4 | |
| bthrow | 2/2 | 4 | |
| uthrow | 2/1 | 3 | |
| dthrow | 2/1 | 3 | |

## Lichtgewicht — totaal 142
Snelst van allemaal, zwak, klein bereik, veilig.

| Move | S/K/B/V | Pts | Karakter |
|---|---|---|---|
| jab | 5/0/1/3 | 9 | |
| ftilt | 4/1/2/3 | 10 | |
| utilt | 5/1/1/3 | 10 | |
| dtilt | 4/1/1/3 | 9 | |
| dash_attack | 4/1/2/1 | 8 | |
| fsmash | 2/3/2/1 | 8 | |
| usmash | 3/3/2/1 | 9 | |
| dsmash | 3/2/2/2 | 9 | |
| nair | 4/1/1/3 | 9 | |
| fair | 4/2/1/3 | 10 | |
| bair | 4/2/1/3 | 10 | |
| uair | 4/2/2/3 | 11 | |
| dair | 3/2/1/2 | 8 | |
| grab | 4/–/1/– | 5 | |
| fthrow | 3/1 | 4 | |
| bthrow | 3/1 | 4 | |
| uthrow | 3/1 | 4 | |
| dthrow | 4/1 | 5 | |

## Afspraken voor alle movesets (director)
Gelden voor archetypes én characters. De validator controleert ze.

1. **Hoeken** zijn relatief aan de kijkrichting (0° = vooruit, 90° = omhoog). Een move die naar
   **achteren** lanceert heeft een hoek > 90° (bv. bthrow 135°, achterkant van dsmash 135° of 160°).
   Standaard throws: fthrow 45°, **bthrow 135°**, uthrow 90°, dthrow 80° (combo-throws 70–85°).
2. **Grab-whiff:** totale duur = laatste actieve frame + 23 (dash grab later: +7). Grab heeft geen Veiligheid-score.
3. **Throws:** de launch-hitbox zit op de vasthoudpositie = de punt van de grab-hitbox, radius 3.0.
   Launch-frame = round(totaal × 0.5). Geen Bereik/Veiligheid-score.
4. **Pummel** staat niet in MoveData; komt in de grab-logica (M4), standaard 2–3 damage.
5. **Sourspot** = round(0.7 × damage) (half omhoog), BKB −10. Shieldstun voor de veiligheid-berekening gebruikt de sourspot.
6. **Multi-hit:** groep 0 = de kleine hits (d 1–2, BKB ≤ 10, hoek 361 of naar de laatste hit toe), laatste groep = de finisher met de Kracht-waarde.
7. **"Sterk begin, zwak einde"** (sex kick): zelfde positie, twee frame-blokken; late blok = sourspot-regel.
8. **Hoogtes:** horizontale moves op ~55% van `visual_height`, lage moves (dtilt/dsmash) op y=2, aerials op ~50%,
   omhoog/omlaag gemeten vanaf de voeten.
