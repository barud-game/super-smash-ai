---
name: nieuw-character
description: Start of hervat het gesprek waarin een speler een eigen Super Smash AI-character bedenkt, en implementeer het daarna. Gebruik als iemand een nieuw character wil maken of een bestaand character wil aanpassen.
---

# Nieuw character maken

1. Lees `CLAUDE.md`, `docs/character-creatie.md` en `docs/balans.md`.
2. Bestaat `characters/<id>/` al? Lees `ontwerp.md` en ga verder waar het gebleven is.
3. Check in `PLAN.md` welke onderdelen al bestaan (archetypes, sjablonen, skelet, validator).
   Ontbreekt iets: voer het gesprek wel, sla `ontwerp.md` op, en zeg wat er nog niet gebouwd kan worden.
4. Vraag: **"Wie wil je zijn?"** — en wacht op het antwoord.
5. Doe meteen een **compleet voorstel**: naam, look, archetype (+aanvullingen), 4 specials in één zin,
   afwijkende normals, puntentabel ≤ 200. Bekend personage genoemd → eigen variant met dezelfde sfeer.
6. Stuur bij tot de speler akkoord geeft. Bij budgetproblemen: stel een ruil voor.
7. Na akkoord:
   - schrijf `ontwerp.md` en `stats.tres`; specials die in een sjabloon passen: configureer zelf
   - start parallel: `svg-artist` voor het uiterlijk, `normals-builder` voor afwijkende normals,
     `special-builder` per eigen special
   - review: bekijk de SVG-preview, lees de special-code
   - draai de validator, los fouten op, werk `PLAN.md` bij, commit
8. Laat de speler testen in training mode (reload-knop), pas aan op feedback.
