# Character-creatie: het gesprek

Geen formulier. Een speler maakt een character door met Claude te praten. Claude stelt vragen,
denkt mee, stelt voor, en implementeert. Start met de skill `/nieuw-character`.

## Verloop

1. **Concept.** Naam, uiterlijk, persoonlijkheid/thema. Eén of twee open vragen, niet meer.
2. **Movement.** Claude stelt op basis van het concept een archetype voor (zie `docs/balans.md`)
   en vraagt of de speler iets wil aanvullen (extra jump, glide, ...).
3. **Specials.** Per special één vraag: "Wat doet je up-B?" Claude vraagt door tot het duidelijk is
   (richting, raakt het, kan je ermee recoveren, wat gebeurt er na afloop?).
4. **Signature moves (optioneel).** "Zijn er andere moves waar je een idee voor hebt?"
   De rest vult Claude zelf in.
5. **Voorstel + budget.** Claude laat een kort overzicht zien met de puntentabel.
   Bij overschrijding stelt Claude ruilen voor. De speler keurt goed.
6. **Bouwen.** Claude implementeert (stats, move-data, specials), commit, en zet het character in training mode.
7. **Testen en bijstellen.** De speler speelt en geeft feedback in gewone taal. Claude past aan binnen het budget.

## Toon
- Nederlands, enthousiast maar kort. Eén vraag tegelijk.
- Geen getallen of jargon aan de speler vragen; Claude vertaalt.
- Wil de speler iets wat technisch nog niet kan, zeg dat eerlijk en stel het dichtstbijzijnde alternatief voor.
- Characters zijn origineel: geen bestaande Nintendo- of andere merkpersonages namaken.
  Wil een speler dat, stel dan een eigen variant voor.

## Opslag per character: `characters/<id>/`
| Bestand | Inhoud |
|---|---|
| `ontwerp.md` | Concept, archetype, elke move in gewone taal, puntentabel, wijzigingslog |
| `stats.tres` | `FighterStats` |
| `moves/*.tres` | `MoveData` per normal |
| `specials/*.gd` | Script per special (bouwt op de special-toolkit) |

`ontwerp.md` is de bron van waarheid: een nieuwe chat moet het character kunnen aanpassen
door alleen dat bestand te lezen.
