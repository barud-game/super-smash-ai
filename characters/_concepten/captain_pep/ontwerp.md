# Captain Pep — ontwerp

**Status:** VOORSTEL — wacht op akkoord van de speler. Nog niet bouwen.

## Concept
Een uitgerangeerde straatracer die nooit meer van de pep af is gekomen. Hyperactief, trillerig en onvoorspelbaar,
maar als hij raakt, raakt hij keihard. Een eigen, origineel character: speelstijl van een snelle, zware racer-brawler,
maar geen kopie van een bestaand personage (eigen naam, uiterlijk en move-namen).

- **Naam:** Captain Pep
- **Uiterlijk (origineel):** mager en pezig, te grote **paars-gifgroene trainingsjas** over een vlekkerig racepakje,
  een **gebarsten motorhelm die scheef op zijn achterhoofd hangt**, verwilderd stekelhaar eronder, wallen onder
  wijd opengesperde ogen, zonnebril met één glas, en een **pleister op zijn neus**. Bovenarmen met afgebladderde
  racestickers. Geen cape, geen embleem.
- **Persoonlijkheid / animatiestijl:** idle-pose trilt en wipt, hij kijkt schichtig om zich heen; zijn taunt is
  zenuwachtig zijn neus afvegen en "IK BEN ER KLAAR VOOR" roepen. Na zijn grote stoot moet hij even bijkomen.
- **KO-effect:** een explosie van glitterpoeder en rondtollende pilletjes-confetti met een "pling".

## Movement
- **Archetype:** Fast-faller (snel, valt hard, 3-frame-jumpsquat).
- **Aanvulling:** zwaarder binnen het archetype (−5).
- Movement-stats gebaseerd op de referentie van een snelle zware racer in `docs/melee-referentie.md` (snelste run, hoge gravity).

## Specials
| Special | Naam | Wat het doet | Sjabloon | S/K/B/V/U | Pts |
|---|---|---|---|---|---|
| Neutral-B | **Last Shot** | Trage, enorme stoot; kan zich tijdens de startup omdraaien. Killt heel vroeg; na afloop staat hij even te hijgen (extra endlag). | `dash_strike` (afstand 0) | 0/5/2/0/2 | 9 |
| Side-B | **Panic Rush** | Wilde sprint naar voren met één harde klap. In de lucht een licht stijgende ramaanval, daarna helpless. | `dash_strike` | 2/3/3/1/4 | 13 |
| Up-B | **Grabby Hands** | Schiet omhoog en grijpt wie hij raakt; die ontploft in een paarse vonkenwolk. Recovery. Mist hij, dan helpless. | `rising_multi` + `command_grab` | 2/2/2/1/6 (+2 combi) | 15 |
| Down-B | **Stumble Kick** | Grond: glijdende trap. Lucht: schuine duiktrap omlaag (stall-then-fall), helpt ook terug naar de ledge. | `stall_fall` | 3/3/2/1/3 | 12 |

## Normals
Standaard fast-faller-moveset, met één signature move:
| Move | Wijziging | S/K/B/V | Pts (standaard → nieuw) |
|---|---|---|---|
| fair | **Jitter Knee**: piepkleine sweetspot op het eerste actieve frame met enorme kracht (electric-element), de rest is een zwakke sourspot | 3/5/1/2 | 8 → 11 |

## Puntentabel
| Onderdeel | Punten |
|---|---|
| Normals (fast-faller 137, fair +3) | 140 |
| Specials | 49 |
| Movement-aanvulling (zwaarder) | 5 |
| **Totaal** | **194 / 200** |

## Wijzigingslog
- 2026-10-09: eerste voorstel ("Kade Torque").
- 2026-10-09: speler koos thema en naam **Captain Pep** (Engels) (verslaafde chaos-racer); uiterlijk en move-namen origineel gemaakt.
