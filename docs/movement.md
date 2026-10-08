# Melee-physics referentie

Alles wat we van Melee nabouwen, met de waarden die we gebruiken.
Waarden met ⚠️ zijn nog niet geverifieerd — eerst checken tegen frame-data-bronnen vóór we erop tunen.

## Basis
- 60 frames per seconde. Alle timings in frames.
- Posities/snelheden in **Melee-units** (per frame). Renderen via `UNIT_TO_PX`.

## Input (stick)
Geïmplementeerd in `engine/input/` (M0). Constanten staan in `MeleeStick`.
- Stick wordt gekwantiseerd naar −80..80 per as (`GRID = 80`, genormaliseerd: stap 1/80). Ruwe stick wordt eerst op de eenheidscirkel geclamped, daarna naar nul afgekapt (nooit buiten straal 80).
- ⚠️ Deadzone `DEADZONE = 23` (≈ 0.2875), per as: |waarde| < 23 → 0.
- ⚠️ Smash-input: stick van onder `SMASH_LOW = 0.3` naar ≥ `SMASH_HIGH = 0.8` binnen N frames (N als argument van `stick_smashed_x/y(N)`) → dash / smash attack / tap-jump. Venster per move nog niet bepaald (Melee: ~2–3 frames).
- Analoge trigger 0..1 → lightshield. ⚠️ Digitale "volledig ingedrukt"-bit vanaf `TRIGGER_FULL = 0.95`.
- Historie: ringbuffer van 32 `InputFrame`s per speler (`InputHistory`) met `pressed/released/held`.
- Layout (XInput): A=attack, X=special, Y/B=jump, LT/RT=shield, RB=Z, rechterstick=C-stick, Start=start. Toetsenbord speler 1: WASD=stick, pijltjes=C-stick, J=A, K=special, Space=jump, L=shield, I=Z.
- Schaal: `UNIT_TO_PX = 7.0` (`engine/units.gd`); ±85 units = 1190 px.

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
