# Sonny Daylight — ontwerp

**Status:** AKKOORD (2026-10-10) — in aanbouw.

## Concept
De speler wilde "Blade, maar dan Eddie Murphy". Dat wordt een **origineel** character met die sfeer: een snelle,
acrobatische vampierjager met de energie van een snelpratende stand-up comedian. Geen bestaand personage en
geen echt persoon: eigen naam, eigen look, eigen move-namen, geen imitatie van iemands stem, lach of catchphrases.

- **Naam:** Sonny Daylight
- **Uiterlijk (origineel):** slank en gespierd, **mosterdgele bomberjack** vol zelfgenaaide knoflook-patches,
  wijde paarse broek, witte sneakers, een **flat cap** achterstevoren, een brede grijns met **één gouden tand**,
  een **ketting van knoflookbollen** om zijn nek. Op zijn rug een **zilveren sabel** met een knoflookbol als pommel. Geen lange jas, geen zonnebril.
- **Persoonlijkheid / animatiestijl:** idle-pose wiegt losjes en hij praat met zijn handen; altijd aan het grappen,
  zelfs midden in een gevecht. Taunt: hij haalt een microfoon tevoorschijn, tikt erop en zegt **"Is dit ding aan?"**
- **KO-effect:** een felle **zonsopgang-flits** met rondvliegende knoflookblaadjes en een "ba-dum-tss"-drumklap.

## Movement
- **Archetype:** Fast-faller (snel, scherp, 3-frame-jumpsquat).
- **Aanvulling:** wall jump (−5) — acrobatische vampierjager.

## Specials
| Special | Naam | Wat het doet | Sjabloon | S/K/B/V/U | Pts |
|---|---|---|---|---|---|
| Neutral-B | **Punchline** | Trekt zijn sabel en geeft één brede, snelle zwaardslag voor zich (disjoint, groot bereik). Werkt op de grond en in de lucht. | `dash_strike` (afstand 0) | 3/3/4/2/2 | 14 |
| Side-B | **Double Take** | Een schuine sprong opzij met een **sabelhaal** halverwege de sprong; daarna kan hij er in de lucht nog één doen (2× per airtime), weer met een haal. Raakt de eerste haal, dan kan de tweede sprong erachteraan komen. Niet helpless. | `multi_jump` (+ hit_data per sprong) | 2/2/3/2/6 | 15 |
| Up-B | **Crossbow Line** | Schiet een kruisboogpijl met touw schuin omhoog; raakt hij een ledge, dan trekt hij zich erheen. De pijl raakt ook tegenstanders. | `tether` | 2/1/3/1/5 | 12 |
| Down-B | **Ha, Gemist!** | Hij grijnst en wacht; wordt hij geraakt, dan ontwijkt hij lachend en prikt terug met een staak. | `counter` | 2/3/1/2/6 | 14 |

## Normals
Alle 13 aanvallen (jab t/m aerials) zijn **sabelaanvallen**: het zwaard geeft meer bereik (disjoint), in ruil
voor iets tragere startup. Per move: Snelheid −1, Bereik +1 t.o.v. de fast-faller-standaard (netto 0 punten).
Grab en throws blijven standaard (met de vrije hand).

| Move | Sabelversie | S/K/B/V (standaard → nieuw) | Pts |
|---|---|---|---|
| jab | snelle steek, dan een korte haal | 5/1/1/3 → 4/1/2/3 | 10 |
| ftilt | horizontale haal | 4/1/2/2 → 3/1/3/2 | 9 |
| utilt | boog boven het hoofd | 4/1/2/3 → 3/1/3/3 | 10 |
| dtilt | lage veeg langs de vloer | 4/1/1/2 → 3/1/2/2 | 8 |
| dash_attack | doorrennende steek | 3/1/1/1 → 2/1/2/1 | 6 |
| fsmash | grote neerwaartse klap, sterke punt | 3/3/2/1 → 2/3/3/1 | 9 |
| usmash | zwaai recht omhoog (kill) | 3/4/2/0 → 2/4/3/0 | 9 |
| dsmash | veeg voor en achter | 3/2/2/1 → 2/2/3/1 | 8 |
| nair | draai met de sabel rondom (sterk begin, zwak einde) | 4/1/1/3 → 3/1/2/3 | 9 |
| fair | snelle reeks halen vooruit (multi-hit) | 3/1/2/2 → 2/1/3/2 | 8 |
| bair | harde haal naar achteren | 4/3/1/3 → 3/3/2/3 | 11 |
| uair | boog omhoog (killer) | 4/3/1/2 → 3/3/2/2 | 10 |
| dair | steek recht omlaag (multi-hit drill) | 3/1/1/3 → 2/1/2/3 | 8 |

3 punten over.

## Puntentabel
| Onderdeel | Punten |
|---|---|
| Normals (fast-faller, sabelversie: S−1/B+1, netto 0) | 137 |
| Specials | 55 |
| Movement-aanvulling (wall jump) | 5 |
| **Totaal** | **197 / 200** |

## Wijzigingslog
- 2026-10-10: side-B krijgt een sabelhaal tijdens elke sprong (13 → 15 pt). Sabel blijft zilver.
- 2026-10-10: alle normals worden sabelaanvallen (meer bereik, iets trager; netto 0 punten).
- 2026-10-10: neutral-B wordt zwaardslag (Punchline), side-B wordt zijsprong met dubbele sprong (Double Take); waterpistool vervangen door sabel.
- 2026-10-10: eerste voorstel, op basis van "Blade, maar dan Eddie Murphy" → origineel character Sonny Daylight.
