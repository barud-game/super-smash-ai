---
name: nieuw-character
description: Start of hervat het gesprek waarin een speler een eigen Super Smash AI-character bedenkt, en implementeer het daarna. Gebruik als iemand een nieuw character wil maken of een bestaand character wil aanpassen.
---

# Nieuw character maken

1. Lees `CLAUDE.md`, `docs/character-creatie.md` en `docs/balans.md`.
2. Bestaat er al een map `characters/<id>/` voor dit character? Lees dan `ontwerp.md` en ga verder waar het gebleven is.
3. Check in `PLAN.md` of M5 (character-systeem) al af is. Zo niet: voer het gesprek wel, sla het
   ontwerp op in `characters/<id>/ontwerp.md`, en zeg dat bouwen kan zodra de engine zover is.
4. Voer het gesprek volgens `docs/character-creatie.md` — **één vraag per bericht**, Nederlands.
5. Laat het voorstel + puntentabel zien en vraag om akkoord voordat je bouwt.
6. Na akkoord: schrijf `ontwerp.md`, implementeer stats/moves/specials, test in training mode,
   werk `PLAN.md` bij en commit.
