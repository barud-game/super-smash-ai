# Character-creatie: het gesprek

Geen formulier. Een speler maakt een character in een kort gesprek met Claude. Start met `/nieuw-character`.
Doel: **één zin van de speler → één voorstel van Claude → spelen.**

## Verloop: eerst voorstellen, dan vragen

1. **Eén open vraag.** "Wie wil je zijn?" — de speler beschrijft het in een paar woorden.
2. **Compleet voorstel.** Claude maakt meteen een volledig character:
   - naam, uiterlijk (kort beschreven), archetype + eventuele aanvullingen
   - de 4 specials, elk in één zin
   - welke normals afwijken van de standaard-moveset van het archetype
   - de puntentabel (≤ 200)
3. **Bijsturen.** De speler zegt wat anders moet ("up-B moet een teleport zijn"). Claude past aan en
   stelt bij budgetproblemen een ruil voor. Herhaal tot de speler akkoord geeft. Meestal 1–2 rondes.
4. **Direct spelbaar.** Na akkoord staat het character meteen in training mode met de standaard-moveset
   van het archetype en de SVG-look. Specials komen er via hot reload bij zodra ze af zijn.
5. **Bouwen** (parallel, zie hieronder), validator draaien, committen.
6. **Testen en bijstellen.** De speler speelt, geeft feedback in gewone taal, Claude past aan;
   de speler drukt in training mode op *reload* en speelt verder zonder herstart.

## Toon
- Nederlands, enthousiast maar kort.
- Nooit getallen of jargon aan de speler vragen; Claude vertaalt.
- Kan iets technisch nog niet, zeg dat eerlijk en stel het dichtstbijzijnde alternatief voor.
- **Characters zijn origineel.** Noemt een speler een bestaand personage (uit een film, game, strip),
  maak dan een eigen character met dezelfde sfeer/rol — nooit de herkenbare naam, kostuum of look kopiëren.
  Leg dat in één zin uit en ga door.

## Snelheid: wat we hergebruiken

| Onderdeel | Hergebruik | Nieuw per character |
|---|---|---|
| Movement | Archetype-preset | Alleen aanvullingen |
| Normals | **Standaard-moveset per archetype** (al gebalanceerd) | Alleen moves die het thema vraagt |
| Specials | **Special-sjablonen** met instellingen | Alleen echt nieuwe mechanieken als code |
| Uiterlijk | **Gedeeld skelet + gedeelde animaties** | SVG-onderdelen + kleuren |

### Special-sjablonen
Projectiel · charge shot · teleport-recovery · multi-hit recovery · counter · reflector ·
command grab · dash-strike · stall-then-fall · multi-jump recovery.
Een special die in een sjabloon past is **configuratie**, geen code.

## Wie doet wat (bouwfase)

| Werk | Wie |
|---|---|
| Gesprek, ontwerp, punten, ruilen, review | Hoofdchat (director) |
| SVG-onderdelen + preview | Subagent `svg-artist` (Sonnet 5.5) |
| Afwijkende normals → `MoveData` | Subagent `normals-builder` (Haiku 5.5) |
| Specials die niet in een sjabloon passen → GDScript | Subagent `special-builder` (Sonnet 5.5), één per special, parallel |
| Eigen KO-effect (bij de blast zone) | Subagent `ko-effect-builder` (Haiku 5.5) |
| Controle | Validator-script (budget, frame-bereiken, compileren, simulatietests) |

**Meerdere characters in één chat** mag: elk character krijgt zijn eigen set parallelle subagents.

**OP-characters:** wil de speler bewust over het budget, dan mag dat. Het character krijgt `op = true` in
`ontwerp.md`/stats en wordt op de character select duidelijk als OP gemarkeerd.

Subagents krijgen alleen `characters/<id>/ontwerp.md` en hun eigen opdracht.

### SVG-uiterlijk
- Elk character = set SVG-onderdelen (hoofd, romp, boven/onderarmen, boven/onderbenen, accessoires) op het
  gedeelde `Skeleton2D`. Animaties zitten op het skelet en gelden voor iedereen.
- `svg-artist` tekent de onderdelen, rendert een preview naar PNG en verbetert die; de director keurt de preview goed vóór de commit.

## Opslag per character: `characters/<id>/`
| Bestand | Inhoud |
|---|---|
| `ontwerp.md` | Concept, archetype, moves in gewone taal, puntentabel, wijzigingslog — **bron van waarheid** |
| `stats.tres` | `FighterStats` (archetype + aanvullingen) |
| `moves/*.tres` | Alleen normals die afwijken van de archetype-standaard |
| `specials/*.tres` / `*.gd` | Sjabloon-configuratie, of eigen script |
| `art/*.svg` | Lichaamsonderdelen |

Een nieuwe chat moet het character kunnen aanpassen door alleen `ontwerp.md` te lezen.
