# Move-conversie: scores (0–5) → Melee-frame data

Mechanische conversietabel voor de `normals-builder` (Haiku). Input: per move vier scores
**Snelheid / Kracht / Bereik / Veiligheid** (0–5, zie `docs/balans.md` sectie 3). Output: concrete
getallen voor een `MoveData`. Alles in **frames** (60 Hz) en **Melee-units**.

> Status: eerste versie, gekalibreerd op echte Melee-data van Marth, Fox, Bowser en Jigglypuff
> (zie Bronnen). Waarden die geen gemeten data zijn maar ontwerpkeuzes/schattingen staan met **⚠️** gemarkeerd.

## 0. Werkwijze in 6 stappen (voor de builder)

Per move, met move-type `T` en scores `Sn, Kr, Be, Ve`:

1. **Startup** `S` = tabel §3 (rij `T`, kolom `Sn`).
2. **Active frames** `A` = tabel §4.2 (rij `T`, kolom `Be`). `last_active = S + A − 1`.
3. **Hitbox**: radius `r` en reach `R` uit §4.1 (kolom `Be`); plaats hitboxen volgens §4.3.
4. **Kracht**: `damage, BKB, KBG` = tabel §2 (groep van `T`, kolom `Kr`). Sourspot/late hit volgens §2.3.
5. **Veiligheid**: grondmoves → endlag via §5.1; aerials → landing lag + air-endlag via §5.2.
   `total_frames = last_active + endlag` (grond) of `last_active + air_endlag` (lucht). IASA = `total_frames`
   tenzij anders vermeld. Minimum `total_frames` = 10.
6. **Angle(s)** = standaardtabel §6 (tenzij de speler iets anders beschrijft).

Alle frames zijn 1-based: "hit frames 4–7" betekent dat de hitbox actief is op frames 4,5,6,7 → startup = 4.
Alle "tabel-lookups" zijn exact: score 3 = kolom 3, geen interpolatie.

## 1. Aannames en basisformules

- **Knockback** (uit `docs/movement.md`):
  `KB = ((((p/10 + p·d/20) · 200/(w+100) · 1.4) + 18) · g/100) + b`
  (`p` = % na de hit, `d` = damage, `w` = weight, `g` = KBG, `b` = BKB). Geen staling, geen charge, geen DI.
- **Kill-percentage (richtlijn)**: de move *killt* wanneer `KB ≥ 190` voor een **middengewicht (w = 100)** vanaf
  het **midden van de stage**, bij een (bijna) horizontale of schuine lancering. Bij `w = 100` is de factor
  `200/(w+100) = 1`, dus:
  `kill% = ((((190 − b)·100/g) − 18) / 1.4) / (0.1 + d/20)`.
  - Waarom 190 en niet de pure natuurkunde (`KB·0.03` snelheid, decay 0.051/frame → ~160 voor een zijkant van ~225 units)?
    Omdat DI, zwaartekracht en een niet-gecentreerde positie het in de praktijk lastiger maken. 190 komt het
    dichtst bij bekende Melee-ervaring (Marth-tip fsmash ≈ 90%, Fox usmash ≈ 90%, Bowser fsmash ≈ 78% op weight 100). ⚠️ Geen formele meting.
  - Gewicht: licht (w≈80) sterft ≈ 10% eerder, zwaar (w≈130) ≈ 15% later. Voor verticale kills (up-angles) komt
    er ≈ 10–20% bij. Dit zijn vuistregels. ⚠️
- **Shieldstun** (past exact op alle gemeten waarden): `shieldstun = floor(0.448·d + 2)` (volle shield-waarde; echte Melee
  is `floor(200/201 · (d·(a+0.3)·1.5 + 2))` met `a` de analoge shield-stand).
- **Hitlag** (attacker en defender): `floor(d/3 + 3)` frames (past op de data).
- **Shield-advantage** van een grondmove die op de **laatste actieve frame** raakt (de gunstigste case):
  `adv = shieldstun(d) − endlag`, met `endlag = total_frames − last_active`. Van een aerial die vlak voor de grond raakt:
  `adv ≈ shieldstun(d) − floor(landing_lag/2)` (L-cancel).
- **L-cancel**: landing lag halveert (naar beneden afgerond); input binnen 7 frames vóór landen.

## 2. Kracht → damage / BKB / KBG

### 2.1 Tabel (de gekozen `d, b, g` leveren de kill% in de laatste regel)

Groepen: **Jab** (jab 1 en finisher), **Normal** (f/u/d-tilt, dash attack, alle aerials), **Smash** (f/u/d-smash),
**Worp** (f/b/u/d-throw). `d/b/g` zijn voor de **hoofd-hitbox (sweetspot)**.

| Kr | Jab: d / b / g | Normal: d / b / g | Smash: d / b / g | Worp: d / b / g |
|---|---|---|---|---|
| 0 | 2 / 5 / 60 | 4 / 10 / 95 | 8 / 20 / 95 | 2 / 20 / 65 |
| 1 | 3 / 8 / 60 | 6 / 15 / 110 | 10 / 25 / 105 | 3 / 25 / 85 |
| 2 | 4 / 12 / 80 | 8 / 20 / 120 | 13 / 30 / 100 | 4 / 30 / 105 |
| 3 | 5 / 15 / 90 | 10 / 25 / 120 | 15 / 30 / 105 | 5 / 35 / 125 |
| 4 | 6 / 20 / 110 | 12 / 30 / 125 | 17 / 35 / 115 | 7 / 40 / 125 |
| 5 | 7 / 25 / 125 | 14 / 35 / 130 | 20 / 40 / 110 | 9 / 45 / 130 |
| **kill%** (w=100) | 0:~1040 · 1:~815 · 2:~490 · 3:~360 · 4:~245 · 5:~180 | 0:~410 · 1:~250 · 2:~175 · 3:~140 · 4:~110 · 5:~90 | 0:~230 · 1:~165 · 2:~135 · 3:~115 · 4:~90 · 5:~75 | 0:~870 · 1:~500 · 2:~320 · 3:~215 · 4:~160 · 5:~120 |

Score 0 betekent in de praktijk "killt niet binnen een realistisch percentage" (> 400%), maar de move doet nog wel schade.
De richtlijn "kracht 5 ≈ killt rond 80%" uit `balans.md` geldt letterlijk voor Smash (75%); voor andere groepen is
5 = "beste van het type" (Normal 90%, Jab 180%, Worp 120%).

Realiteitscheck (kill% op weight 100, 190-aanname): Fox jab 410%, Fox fair-hit 1: 210%, Fox utilt 107%, Fox usmash 89%,
Marth fsmash-tip 90%, Marth fair-tip 184%, Bowser fsmash 78%, Jigglypuff fsmash 101%.

### 2.2 Regels
- **Damage-plafond per type**: gemeten maxima: jab 6 (finisher 7), tilt 14, aerial 17, smash 24 (Bowser). Overschrijd de tabel niet.
- **Lage-percentage-knockback** `KB0 = 18·g/100 + b` bepaalt combo-gedrag (bv. Normal Kr 3: 47; Kr 5: 58). Wil de speler een
  "combo-move", trek dan BKB −10 en verhoog KBG niet; wil hij een "kill-move", houd de tabel aan.
- **Multi-hit** (drills, loops): de *kracht-score geldt voor de laatste hit*. Eerdere hits: `d = 1–3`, `b = 0–10`, `g = 100`, angle 361
  (of 270–290 voor een drill-dair), interval **3 frames** (gemeten: Fox dair, Jigglypuff dair, Bowser dair: hits op f, f+3, f+6 …).
  De active-frames in §4.2 gelden dan voor het hele hit-blok.

### 2.3 Sweetspot / sourspot / late hit
Gemeten patroon (Marth fair 13/10/9, Fox bair 15→9, Jigglypuff utilt/dsmash): sourspot of late hitbox heeft
**damage ×0,7 (afronden)**, **BKB −10 (min 0)**, **KBG gelijk**. Eén sweetspot per move (de tip op afstand `R − r`).

## 3. Snelheid → startup (eerste actieve frame)

Startup per move-type; kolom = score. Gemeten bereiken (Marth/Fox/Bowser/Jigglypuff) tussen haakjes in kolom "data".

| Type | 0 | 1 | 2 | 3 | 4 | 5 | data (min–max) |
|---|---|---|---|---|---|---|---|
| Jab 1 | 8 | 6 | 5 | 4 | 3 | 2 | 2–7 |
| F-tilt | 15 | 12 | 9 | 7 | 5 | 4 | 5–12 |
| U-tilt | 13 | 10 | 8 | 6 | 5 | 4 | 5–8 |
| D-tilt | 18 | 14 | 11 | 9 | 7 | 5 | 7–14 |
| Dash attack | 16 | 13 | 10 | 8 | 6 | 4 | 4–12 |
| F-smash | 28 | 21 | 16 | 13 | 11 | 9 | 10–29 |
| U-smash | 22 | 16 | 12 | 9 | 7 | 6 | 7–16 |
| D-smash | 16 | 13 | 10 | 8 | 6 | 5 | 5–14 |
| Nair | 12 | 10 | 8 | 6 | 5 | 4 | 4–8 |
| Fair | 15 | 12 | 9 | 7 | 6 | 4 | 4–8 |
| Bair | 15 | 12 | 9 | 8 | 6 | 4 | 4–9 |
| Uair | 18 | 14 | 10 | 8 | 6 | 4 | 5–22 |
| Dair | 16 | 12 | 9 | 7 | 5 | 4 | 5–14 |
| Grab (staand) | 12 | 10 | 8 | 7 | 6 | 5 | 6–8 |
| Worp (totale duur, zie §7) | 85 | 60 | 46 | 41 | 36 | 31 | 31–84 |

Smash-attacks: de smash-charge begint op frame 1; `S` is de eerste actieve frame na loslaten.
Dash grab = standing startup + 5. ⚠️ (Melee-data: 11–12 vs. 6–7.)
Een score 5 is "snelste in Melee" voor dat type; grenzen onder het gemeten minimum (bv. 3-frame aerials) zijn bewust niet gebruikt.

## 4. Bereik → hitbox-grootte, reach, active frames

### 4.1 Radius en reach
Radius `r` (Melee-units, uit full-hitbox-data: kleinste 1,96, typisch 3,1–3,9 voor wapen/ledemaat, grootste 7,84 bij Bowser):

| Be | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| radius `r` | 2,0 | 2,5 | 3,0 | 3,5 | 4,5 | 6,0 |

Reach `R` = afstand van het fighter-midden tot de **buitenste rand** van de verste hitbox (units). ⚠️ Geschat uit
modelafmetingen en ervaring; niet direct gemeten (de data geeft bone-relatieve offsets, geen wereld-afstand).

| Type | 0 | 1 | 2 | 3 | 4 | 5 | richting |
|---|---|---|---|---|---|---|---|
| Jab | 8 | 10 | 12 | 14 | 17 | 20 | vooruit |
| F-tilt | 10 | 12 | 15 | 18 | 22 | 26 | vooruit |
| U-tilt | 10 | 13 | 16 | 19 | 23 | 27 | omhoog (vanaf voeten) |
| D-tilt | 10 | 12 | 15 | 18 | 21 | 24 | vooruit, laag |
| Dash attack | 8 | 10 | 12 | 15 | 18 | 21 | vooruit |
| F-smash | 14 | 16 | 19 | 22 | 26 | 30 | vooruit |
| U-smash | 16 | 19 | 22 | 26 | 30 | 34 | omhoog (vanaf voeten) |
| D-smash | 12 | 14 | 17 | 20 | 23 | 26 | beide kanten |
| Nair | 8 | 10 | 12 | 14 | 17 | 20 | rondom |
| Fair | 12 | 14 | 17 | 20 | 24 | 28 | vooruit |
| Bair | 12 | 14 | 17 | 20 | 24 | 28 | achteruit |
| Uair | 14 | 17 | 20 | 23 | 27 | 31 | omhoog (vanaf voeten) |
| Dair | 12 | 14 | 17 | 20 | 24 | 28 | omlaag (vanaf voeten) |
| Grab | 8 | 10 | 12 | 14 | 17 | 20 | vooruit |

### 4.2 Active frames (aaneengesloten hit-blok; kolom = Bereik-score)
Lang actief = meer dekking. Gemeten spreiding (voorbeeld: Fox nair 28 f, Jigglypuff nair 23 f, Marth jab 4 f).

| Type | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Jab | 2 | 2 | 3 | 3 | 4 | 4 |
| F-tilt | 3 | 3 | 4 | 4 | 5 | 6 |
| U-tilt | 3 | 4 | 5 | 6 | 7 | 9 |
| D-tilt | 2 | 3 | 3 | 4 | 5 | 7 |
| Dash attack | 3 | 4 | 6 | 8 | 11 | 14 |
| F-smash | 3 | 4 | 5 | 7 | 9 | 11 |
| U-smash | 3 | 4 | 5 | 6 | 8 | 11 |
| D-smash | 2 | 3 | 4 | 5 | 6 | 8 |
| Nair | 3 | 5 | 8 | 12 | 18 | 26 |
| Fair | 3 | 4 | 4 | 6 | 10 | 16 |
| Bair | 3 | 4 | 5 | 7 | 10 | 14 |
| Uair | 3 | 4 | 4 | 5 | 6 | 8 |
| Dair (enkele hit) | 3 | 4 | 4 | 5 | 6 | 8 |
| Grab | 2 | 2 | 2 | 2 | 2 | 2 |

### 4.3 Hitbox-plaatsing (vooruit/omhoog/omlaag langs de move-richting)
- Aantal hitboxen: Be 0–1 → 1 box; Be 2–3 → 2 boxen; Be 4–5 → 3 boxen.
- Tip-box (sweetspot) middelpunt op afstand `R − r`; tweede box op `(R − r)/2`; derde box op `0,15·R` (dicht bij het lichaam).
  Alle boxen: radius `r`. Boxen anders dan de tip zijn sourspots (§2.3).
- Hoogte (voor horizontale moves): hitbox-y op **8 units** boven de voeten (tilts/smashes/dash), **2** voor d-tilt/d-smash.
  Aerials: y = lichaamsmidden van het character. ⚠️ ontwerpkeuze.
- **Disjoint** (hitbox raakt geen hurtbox van de eigenaar): Be ≥ 4. Disjoint-moves mogen clanken met andere hitboxen (`clang`/`rebound` aan, zoals
  alle gemeten wapen-hitboxen); Be ≤ 3 gebruikt `clang` zonder disjoint.

## 5. Veiligheid → endlag / shield-advantage / landing lag

### 5.1 Grondmoves (jab, tilts, dash attack, smashes)
Doel-`adv` is de shield-advantage bij een late-hit (laatste actieve frame). Endlag volgt direct:

`endlag = shieldstun(d) − adv_doel`, met `shieldstun(d) = floor(0,448·d + 2)` en `d` = damage van de **sourspot/late box** (§2.3); `adv_doel` negatief
dus endlag = shieldstun + |adv_doel|. `total_frames = last_active + endlag`.

| Ve | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Jab `adv_doel` | −22 | −18 | −14 | −11 | −8 | −5 |
| Tilt / dash attack | −24 | −18 | −13 | −9 | −6 | −3 |
| Smash | −36 | −30 | −24 | −18 | −13 | −8 |

Gemeten ter controle (late-hit): Fox jab −10 (Ve 3), Fox utilt −6 (4), Fox ftilt −12 (2), Marth utilt −14 (2), Marth ftilt −19 (1),
Marth fsmash −27 (1), Bowser fsmash −21 (2), Fox fsmash −10 (4), Marth dsmash −34 (0). Echt "safe" (Ve 5, ≥ −3) komt in Melee
nauwelijks voor op de grond; het is dus een zeldzame premium-score. ⚠️ Rekenbeperking: multi-hit smashes wijken af.

### 5.2 Aerials
Landing lag in frames (L-cancelled = `floor(LL/2)`); `air_endlag` = frames tussen `last_active` en einde animatie.

| Ve | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Landing lag (normaal) | 40 | 30 | 24 | 20 | 15 | 12 |
| L-cancelled | 20 | 15 | 12 | 10 | 7 | 6 |
| `air_endlag` (`total = last_active + air_endlag`) | 46 | 38 | 32 | 26 | 22 | 18 |

Gemeten landing lag: 15 (Marth fair/nair/uair, Fox nair), 18 (Fox uair/dair), 20 (Fox bair, Jigglypuff nair/fair/bair/uair, Marth…),
22 (Fox fair), 24 (Marth bair), 30 (Bowser nair/fair/uair, Jigglypuff dair), 32 (Marth dair), 35 (Bowser bair), 40 (Bowser dair).
Ve 5 (12 frames) ligt onder het gemeten minimum (15); bewuste extrapolatie. ⚠️
`air_endlag` gemeten 17–50 (mediaan ≈ 27), grofweg gekoppeld aan landing lag.

**Auto-cancel**: geen landing lag voor frames `< S` (voor de hitbox) en voor frames `> last_active + 12`. ⚠️ (gemeten: +3 tot +20, mediaan ≈ +12).

## 6. Standaard launch-angles per move-type

Angle is gemeten t.o.v. de kijkrichting van de aanvaller: **0 = vooruit, 90 = omhoog, 180 = achteruit, 270 = omlaag**. Bij de
bair wordt de hit achter de aanvaller gespiegeld (angle blijft 361 / 'weg van de aanvaller').

| Type | Standaard | Variant (sourspot / speciale wens) | Gemeten |
|---|---|---|---|
| Jab 1 | **361** | 70–83 (omhoog-poppen, Fox/Bowser) | 361, 70, 83, 361 |
| F-tilt | **361** | 30–45 (schuin omhoog) | 361 bij alle vier |
| U-tilt | **100** (tip 85–110, licht naar achter) | 84–96 | 110/85, 110/84, 100, 96 |
| D-tilt | **80** (pop-up) | 20–30 (laag/horizontaal), 361 | 30, 70–90, 361, 20 |
| Dash attack | **361** | 72–80 (pop-up), 110 | 110/361, 72, 80, 361 |
| F-smash | **361** | 60–70 (late hit) | 361 bij alle vier |
| U-smash | **90** | 75–80 | 90, 80, 90, 90 |
| D-smash | **361** | 25 (laag, vooruit), 0 (Jigglypuff) | 25/361, 75/361, 0 |
| Nair | **361** | 80–90 (late hit, omhoog) | 361 bij alle vier |
| Fair | **361** | 67 (tip, schuin omhoog) | 361/67, 361, 361/24, 361 |
| Bair | **361** | – | 361 bij alle vier |
| Uair | **90** | 80–85 | 90/80, 85/92, 85, 90 |
| Dair (enkele hit) | **290** (meteor/spike) | 361 (geen spike), 270 | 290 (Marth, Fox), 270–290 |
| F-throw | **45** | 50–55 | 50, 45, 45, 55 |
| B-throw | **45** (t.o.v. worprichting) | 56 | 56 (Fox); 135-achtige hoeken bij andere characters ⚠️ |
| U-throw | **90** | 70–93 | 93, 90, 70, 90 |
| D-throw | **80** (combo) | 270 (grond-bounce, Fox) / 135 | 135, 270, 50, 80 |

### 6.1 Sakurai-angle (361)
Angle **361** is geen echte hoek maar een regel:
- Tegenstander **op de grond**: als `KB < 32` → lancering onder **0°** (plat, de tegenstander glijdt weg en blijft grounded). Bij `KB ≥ 32` →
  **44°** (schuin omhoog, in Melee 44, niet 45).
- Tegenstander **in de lucht**: altijd **45°**.
Het geeft jabs/tilts/smashes een natuurlijke "schuin-omhoog" kill-baan zonder dat de builder een hoek kiest, en houdt lage-schade-hits laag
(combo-vriendelijk). Dit is de default voor alle horizontale moves. Implementatie: bepaal `KB` met §1, kies dan 0°/44°/45°.

## 7. Grab en worpen

**Grab** (4 assen): Snelheid → startup §3; Bereik → `r`/`R` §4 (hitboxen als Grab-rij, geen damage, angle 361, `BKB 0`, `KBG 100`; gemeten);
Veiligheid → whiff-duur (totale animatie):

| Ve | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| Grab whiff total | 45 | 39 | 35 | 32 | 29 | 26 |

(gemeten 29 voor Marth/Fox/Jigglypuff, 39 voor Bowser; 26 is extrapolatie ⚠️). Kracht → **pummel**-damage per pummel:
`1 · 1 · 2 · 3 · 3 · 4`% voor Kr 0–5 (gemeten 3% bij Marth/Ganon). ⚠️

**Worpen** (f/b/u/d): kolom "Worp" in §2.1 voor `d/b/g`; angles §6; **totale duur** (vanaf het begin van de worp-animatie) uit §3 (rij "Worp").
De worp **lanceert op frame `round(total × 0,5)`** (⚠️ ontwerpkeuze; per-frame lanceertijden zijn niet in de bron).
Gemeten totalen: Fox 33–43, Marth 31–44, Jigglypuff 35–41, Bowser 59–84.
Open punt voor de director: een worp heeft geen echte Bereik/Veiligheid. Voorstel: worpen scoren alleen **Snelheid + Kracht** (max 10) —
dit moet nog in `balans.md` worden vastgelegd. ⚠️

## 8. Voorbeelden (sanity-check)

Score = hoogste/dichtstbijzijnde tabelwaarde (startup: "≤"; kill%: kolom met kleinste ≥; adv/landing lag: dichtstbij).

| Move (echt Melee) | Data | Scores Sn/Kr/Be/Ve = som |
|---|---|---|
| **Fox jab 1** | startup 2, actief 2–3, IASA 16/17; d4, a70, b0, g100; r≈3,3; kill ≈ 410%; adv −10 | 5 / 2 / 1 / 3 = **11** |
| **Marth f-smash (tip)** | startup 10, actief 10–13, IASA 48; d20, a361, b80, g70; r 3,9; kill ≈ 90%; adv −27 | 4 / 4 / 5 / 1 = **14** |
| **Bowser f-smash** | startup 29, actief 29–33, IASA 66; d24, a361, b30, g100; r 6,3–7,8; kill ≈ 78%; adv −21 | 0 / 5 / 4 / 2 = **11** |
| **Marth f-air (tip)** | startup 4, actief 4–7, total 33; landing lag 15 (L-cancel 7); d13, a67, b42, g70; kill ≈ 184%; reach ≈ 24 | 5 / 2 / 4 / 4 = **15** |

Terugrekenen (Fox jab 1 uit de tabel met 5/2/1/3): S = 2; A = 2 (Be 1); `d,b,g` = 4/12/80 (Kr 2); `r` = 2,5; `R` = 10; shieldstun(4) = 3, `adv_doel` −11 → endlag 14;
`last_active` = 3 → `total_frames` = 17. Dat zit vlak bij de echte Fox jab (17).

## 9. Is het 200-puntenbudget realistisch?

Ik heb 13 normals (jab, tilts, dash, smashes, aerials) van vier characters gescoord met deze tabellen (zonder Bereik; Bereik geschat):

| Character | gem. Sn+Kr+Ve | + Bereik (schatting) | gem. per move |
|---|---|---|---|
| Fox | 8,8 | ≈ 2 | ≈ 10,8 |
| Marth | 6,9 | ≈ 3,5 | ≈ 10,3 |
| Jigglypuff | 6,5 | ≈ 1,5 | ≈ 8,0 |
| Bowser | 4,6 | ≈ 3 | ≈ 7,6 |

Met worpen/grab (~30 totaal) en vier specials (~12 elk = ~48) komt een Fox of Marth op ≈ 215–225, een Jigglypuff of Bowser op ≈ 180–190.
Dus: **~8 per gemiddelde move klopt voor een gemiddeld tot onderdoorsnee Melee-character; 200 is dan de bovenkant van "middenmoot"
en dwingt toppers (Fox/Marth) tot echte keuzes.** Wil je dat spelers Fox-niveau kunnen bouwen, verhoog dan naar ~215–220; wil je een
strakkere afweging, houd 200.

## 10. Onzekerheden

- **Reach `R`** en **hoogte** zijn geschat, niet gemeten (data geeft bone-offsets).
- **Kill-drempel 190** is een gekalibreerde aanname, geen simulatie.
- Worp-lanceerframe, dash-grab, auto-cancel-offset (+12) en `air_endlag` zijn grof (⚠️ in de tekst).
- Steekproef: vier characters (Marth, Fox, Bowser, Jigglypuff); Falco en Ganondorf alleen via SmashWiki-samenvattingen als kruiscontrole.
  Geen Captain Falcon, Peach of Ice Climbers.
- Veiligheid Ve 5 en snelheid Sn 5 liggen op/onder het gemeten extreem: bewust beperkt tot Melee-realisme.
- Multi-hit en projectielen zitten niet in deze tabel (specials vallen onder de special-toolkit).

## Bronnen

- Per-move hitbox-/frame-data uit de Melee-gamefiles (extractie door pfirsich, gehost door theshoemaker):
  `https://melee.theshoemaker.de/framedata-txt/<Character>/<move>.txt` en `.../framedata-txt-fullhitboxes/...` (Marth, Fox, Bowser, Jigglypuff).
  Tool: https://github.com/pfirsich/meleeFrameDataExtractor (en https://github.com/pfirsich/meleeDat2Json)
- SmashWiki: Marth (SSBM), Fox (SSBM), Falco (SSBM), Ganondorf (SSBM), Jigglypuff (SSBM) — damage/frames (kruiscontrole);
  https://www.ssbwiki.com/Sakurai_angle ; https://www.ssbwiki.com/Shield_stun ; https://www.ssbwiki.com/Knockback ; https://www.ssbwiki.com/L-canceling ; https://www.ssbwiki.com/Unit
- Geprobeerd maar niet bruikbaar: meleeframedata.com (verlopen certificaat), ikneedata.com (alleen out-of-shield-heatmaps).
- `docs/movement.md` (knockback-formule, decay, L-cancel).
