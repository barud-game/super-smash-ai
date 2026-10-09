---
name: nieuw-character
description: Start of hervat het gesprek waarin een speler een eigen Super Smash AI-character bedenkt, en bouw het daarna met agents. Gebruik als iemand een nieuw character wil maken of een bestaand character wil aanpassen.
---

# Nieuw character maken

Volg **`docs/character-bouwen.md`** (het complete draaiboek). Kort:

1. Lees `CLAUDE.md`, `PLAN.md`, `docs/character-bouwen.md`, `docs/character-creatie.md`, `docs/balans.md`.
   Check `get_usage`.
2. Bestaat er al `characters/<id>/` of `characters/_concepten/<id>/`? Lees `ontwerp.md` en ga verder waar het gebleven is.
3. Vraag: **"Wie wil je zijn?"** — wacht op het antwoord.
4. Doe meteen een **compleet voorstel** (naam, look, archetype + aanvullingen, 4 specials met sjabloon, afwijkende
   normals, taunt, KO-effect, puntentabel ≤ 200) en schrijf het in `characters/_concepten/<id>/ontwerp.md`.
   **Origineel:** bestaand personage genoemd → eigen character met dezelfde sfeer; geen verbasterde namen of kostuums.
5. Stuur bij tot de speler **akkoord** zegt (ruilen bij budgetproblemen; OP alleen als de speler het wil).
6. Na akkoord: bestanden maken (stap 3 van het draaiboek), agents parallel starten (stap 4), controleren
   (validator, tests, screenshots **na waarschuwing**), committen, `PLAN.md` bijwerken.
7. Laat de speler testen en stel bij.
