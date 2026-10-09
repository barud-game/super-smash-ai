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

Mappen die met `_` beginnen zijn geen spelbare characters (`_dummy` = oefenpop/voorbeeld, `_concepten` = nog niet akkoord).
Alles hieronder wordt door `CharacterLoader` (`engine/roster/character_loader.gd`) en de engine gelezen; match, training en sandbox
gebruiken dezelfde code.

| Bestand / map | Inhoud | Verplicht |
|---|---|---|
| `ontwerp.md` | Concept, archetype, moves in gewone taal, puntentabel, wijzigingslog — **bron van waarheid** | ja |
| `character.json` | Manifest: naam, archetype, lengte, taunt, kleuren (zie hieronder) | ja |
| `scores.json` | Scores voor afwijkende moves, specials en `movement_extras` (zie hieronder) | ja |
| `stats.tres` | `FighterStats` die de archetype-preset **volledig vervangt** (negeert `visual_height` en `movement_extras`) | nee |
| `moves/<move>.tres` | `MoveData` voor alleen de normals die afwijken; elke aanwezige move overschrijft de archetype-move (jab, ftilt, utilt, dtilt, dash_attack, fsmash, usmash, dsmash, nair, fair, bair, uair, dair, grab, fthrow, bthrow, uthrow, dthrow; ook `ledge_attack`/`getup_attack`) | nee |
| `specials/<slot>.tres` (+ `<slot>.gd`) | `SpecialDef` per slot (`neutral`, `side`, `up`, `down`); eigen script alleen als geen sjabloon past. Een `SpecialDef` kan `prop_events` hebben (docs/specials.md §7) | ja (4 slots) |
| `art/*.svg` | Lichaamsonderdelen van het rig (docs/rig.md §3) | ja |
| `art/props/<naam>.svg` | Losse rekwisieten voor specials en taunt (docs/rig.md §9); optioneel `art/props/props.json` met pivots | nee |
| `poses/*.json` | Eigen of overschreven poses, **per naam** (bv. een eigen `taunt`); docs/rig.md §6 | nee |
| `ko_effect/ko_effect.gd` | Eigen KO-effect (docs/vfx.md) | nee (standaard KO-effect) |
| `sfx/<naam>.json` | Eigen geluidsrecepten (docs/audio.md) | nee |

### `character.json`

```json
{
  "id": "captain_pep",
  "name": "Captain Pep",
  "archetype": "Fast-faller",
  "op": false,
  "visual_height": 14.0,
  "tagline": "Korte zin onder de naam op de character select.",
  "taunt_text": "DA'S PAS SPUL!",
  "taunt_frames": 80,
  "taunt_props": [ { "prop": "zoutvaatje", "attach": "hand_l", "from_frame": 8, "to_frame": 40 } ],
  "colors": { "primary": "#7b2fbf", "secondary": "#7dff3a", "accent": "#1b1b1f" }
}
```

| Veld | Betekenis |
|---|---|
| `id` | = mapnaam (anders wordt de mapnaam gebruikt, met waarschuwing) |
| `name` | Weergavenaam |
| `archetype` | `Zwaargewicht`, `Allrounder`, `Fast-faller`, `Floaty` of `Lichtgewicht` — bepaalt de movement-preset én de standaard-moveset |
| `op` | `true` = bewust buiten het 200-budget (character select toont OP) |
| `visual_height` | Lengte vloer-kruin in Melee-units, **8–30** (buiten het bereik: geklemd + waarschuwing; validator FAIL). Standaard: die van het archetype (11–19). Kleiner dan het archetype kost −2 per unit |
| `tagline` | Max. ~2 regels voor het spelerspaneel |
| `taunt_text` | Tekst in het wolkje boven het hoofd tijdens de taunt (max. ~28 tekens; leeg = geen wolkje) |
| `taunt_frames` | Duur van de taunt, 30–180 (standaard 80) |
| `taunt_props` | Lijst prop-events (zelfde formaat als `SpecialDef.prop_events`, frames = taunt-frames, 0 = eerste taunt-frame) |
| `colors.primary/secondary/accent` | Hex; UI-accent (niet de spelerskleur van het rig) |

Het formaat van het manifest voor de UI staat ook in `docs/ui.md`.

### `scores.json`

```json
{
  "fair": {"S": 3, "K": 5, "B": 1, "V": 2},
  "specials": {
    "neutral_b": {"S": 0, "K": 5, "B": 2, "V": 0, "U": 2},
    "side_b": {...}, "up_b": {...}, "down_b": {...}
  },
  "movement_extras": {"zwaarder": -5},
  "op": false
}
```

Een move-sleutel (`jab`, `fair`, ...) staat er alleen als er ook een `moves/<move>.tres` is. `movement_extras`: naam -> punten;
de naam bepaalt het effect op de stats (tabel in `docs/balans.md` sectie 2).

### Tekst en pose van de taunt
Taunt = D-pad omhoog / toets `T` (alleen vanuit stilstaan op de grond; niet cancelbaar). Pose `taunt`: standaard de gedeelde pose
(`engine/visual/poses/combat.json`, 80 frames: neus afvegen, dan beide armen omhoog); een character levert een eigen pose met
de naam `taunt` in `poses/*.json` (overschrijft de gedeelde, docs/rig.md §6). De pose wordt uitgerekt/ingekrompen naar `taunt_frames`.

Een nieuwe chat moet het character kunnen aanpassen door alleen `ontwerp.md` te lezen.

**Concepten:** een voorstel waar de speler nog geen akkoord op gaf staat in `characters/_concepten/<id>/ontwerp.md`.
Mappen die met `_` beginnen worden overgeslagen door de character select en de validator.
Na akkoord: verplaats naar `characters/<id>/` en bouw.
