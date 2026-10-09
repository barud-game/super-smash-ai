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

## Bouwstatus (2026-10-10)
- ✅ Art (rig-onderdelen, `weapon.svg` zilveren sabel, props microfoon/kruisboog/pijl_touw) — **nog niet visueel gecontroleerd** (preview-commando's: zie hieronder).
- ✅ 13 sabel-normals in `moves/` (validator PASS; geen disjoint, want Bereik ≤ 3 volgens move-conversie.md; element SLASH).
- ✅ Specials in `specials/` (`side.gd` = eigen runner op `TplMultiJump` met vaste schuine richting + haal-hitbox; generator `gen_specials.gd`).
- ✅ KO-effect `ko_effect/ko_effect.gd` (headless 14/14).
- ⚠️ Validator 2 FAIL (`special_def/neutral` B=4, `special_def/side` S=2/K=2): schattingsregels in `tools/validator/special_validator.gd`
  kennen geen hitbox-bereik bij `dash_strike` afstand 0 en geen hitbox bij `multi_jump`. Validator aanpassen, niet de scores.
- ⬜ Wall jump: `stats.wall_jump` wordt gezet maar de engine heeft nog geen wall-jump-state.
- ⬜ Prop-events (kruisboog/pijl bij up-B, microfoon bij taunt) koppelen zodra `prop_event.gd` gecommit is.
- ⬜ Eigen pose `atk_special_slash` voor Double Take (nu `atk_special_spin`).
- ⬜ Screenshots (director, na waarschuwing): `tools/preview/preview.tscn -- --character sonny_daylight [--poses atk_jab1,atk_fair,atk_fsmash,atk_usmash --maxf 5] --out tools/preview/out/sonny_daylight[_atk].png`
  en `tools/vfx_preview/vfx_preview.tscn -- --effect ko --character sonny_daylight --side left --out <png>` (altijd `--position -20000,-20000`).

## Wijzigingslog
- 2026-10-10: side-B krijgt een sabelhaal tijdens elke sprong (13 → 15 pt). Sabel blijft zilver.
- 2026-10-10: alle normals worden sabelaanvallen (meer bereik, iets trager; netto 0 punten).
- 2026-10-10: neutral-B wordt zwaardslag (Punchline), side-B wordt zijsprong met dubbele sprong (Double Take); waterpistool vervangen door sabel.
- 2026-10-10: eerste voorstel, op basis van "Blade, maar dan Eddie Murphy" → origineel character Sonny Daylight.
