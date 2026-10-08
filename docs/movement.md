# Melee-physics referentie

Alles wat we van Melee nabouwen, met de waarden die we gebruiken.
Waarden met ⚠️ zijn nog niet geverifieerd — eerst checken tegen frame-data-bronnen vóór we erop tunen.

## Basis
- 60 frames per seconde. Alle timings in frames.
- Posities/snelheden in **Melee-units** (per frame). Renderen via `UNIT_TO_PX`.

## Input (stick)
- Stick wordt gekwantiseerd naar −80..80 per as (genormaliseerd: stap 1/80).
- ⚠️ Deadzone ≈ 0.2875 (23/80).
- ⚠️ Smash-input: stick van (bijna) neutraal naar ≥ 0.8 binnen enkele frames → dash / smash attack / tap-jump.
- Analoge trigger → lightshield.

## Grond
- Dash: initiële snelheid + acceleratie tot dash speed; dash-dance door binnen het dash-window terug te tikken.
- Run na het initiële dash-window, turnaround met skid.
- Traction bepaalt afremmen én wavedash-lengte.

## Lucht
- **Jumpsquat**: 3–8 frames afhankelijk van character. Jump losgelaten vóór einde jumpsquat → short hop.
- Gravity + terminal velocity per character.
- **Fast fall**: alleen bij neerwaartse/geen verticale snelheid (na de apex), stick naar beneden → fast-fall speed.
- Air drift: air acceleration + max air speed per character.

## Air dodge / wavedash
- Directionele air dodge met vaste beginsnelheid ⚠️ (3.1) die per frame afneemt.
- Air dodge in de grond → landing met ⚠️ 10 frames landing lag, horizontale snelheid blijft → glijden (wavedash).
- Na air dodge: special fall (helpless).

## Landing
- Landing lag per aerial; **L-cancel** (shield binnen 7 frames vóór landing) halveert die.

## Knockback (Melee-formule)
```
KB = ((((p/10 + p*d/20) * 200/(w+100) * 1.4) + 18) * g/100) + b
```
- `p` = percentage ná de hit, `d` = damage van de hit, `w` = weight, `g` = knockback growth, `b` = base knockback.
- Hitstun = `floor(KB * 0.4)` frames.
- Lanceersnelheid = `KB * 0.03`, neemt af met 0.051 per frame.
- Hitlag ⚠️ = `floor((d/3 + 3) * multiplier)` frames.
- DI: tot 18° verandering van de lanceerhoek.
