# Kade Torque — ontwerp

**Status:** VOORSTEL — wacht op akkoord van de speler. Nog niet bouwen.

## Concept
De speler wil "Captain Falcon". Dat is een Nintendo-personage, dus dit is een **eigen character met die speelstijl**:
een snelle, zware racer-brawler met een vernietigende vuurstoot en een knie die als een donderslag binnenkomt.

- **Naam:** Kade Torque
- **Uiterlijk:** rijder in een oranje-zwart racepak met witte startnummer-strepen, wit helm met smal groen vizier,
  korte zwarte sjaal die achter hem wappert, zware handschoen met uitlaatpijpjes op de rechterhand
  (daar komt de vuurstoot uit). Breed, gespierd silhouet.
- **Speelstijl:** snelste run van het spel, valt hard, wordt makkelijk gecombood, maar elke treffer doet pijn.
  Punish-machine: één fout van de tegenstander = een gigantische combo of een kill.
- **KO-effect:** uitlaatvlammen en een geblokte finishvlag-burst.

## Movement
- **Archetype:** Fast-faller (snel, valt hard, 3-frame-jumpsquat).
- **Aanvulling:** zwaarder binnen het archetype (−5) — kan meer hebben dan een typische fast-faller.
- Stats op basis van de Falcon-referentiewaarden in `docs/melee-referentie.md` (snelste dash/run, hoge gravity).

## Specials
| Special | Naam | Wat het doet | Sjabloon | S/K/B/V/U | Pts |
|---|---|---|---|---|---|
| Neutral-B | **Nitrostoot** | Trage, enorme vuurstoot; kan zich in de startup omdraaien. Killt heel vroeg, maar elke whiff is straf. | `dash_strike` (afstand 0) | 0/5/2/0/2 | 9 |
| Side-B | **Ramkoers** | Vlammende sprint naar voren met één harde klap. In de lucht een licht stijgende ramaanval, daarna helpless. | `dash_strike` | 2/3/3/1/4 | 13 |
| Up-B | **Haakgreep** | Stijgt op en grijpt wie hij raakt; die ontploft in een vuurwolk. Recovery. Mist hij, dan gaat hij helpless. | `rising_multi` + `command_grab` | 2/2/2/1/6 (+2 combi) | 15 |
| Down-B | **Vlamtrap** | Grond: glijdende vuurtrap. Lucht: schuine duiktrap omlaag (stall-then-fall), die hem ook helpt terugkomen bij de ledge. | `stall_fall` | 3/3/2/1/3 | 12 |

## Normals
Standaard fast-faller-moveset, met één signature move:
| Move | Wijziging | S/K/B/V | Pts (standaard → nieuw) |
|---|---|---|---|
| fair | **Donderknie**: piepkleine sweetspot op het eerste actieve frame met enorme kracht (bliksem-element), de rest is een zwakke sourspot | 3/5/1/2 | 8 → 11 |

## Puntentabel
| Onderdeel | Punten |
|---|---|
| Normals (fast-faller 137, fair +3) | 140 |
| Specials | 49 |
| Movement-aanvulling (zwaarder) | 5 |
| **Totaal** | **194 / 200** |

## Wijzigingslog
- 2026-10-09: eerste voorstel door de director.
