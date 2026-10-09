# UI: menu's, roster en instellingen

Alles in `ui/` (menu's, `ui/match/`, `ui/hud/`, `ui/results/`), plus `engine/roster/` (CharacterRegistry) en `engine/match/` (match-logica).
Stijl: donker kosmisch (`ui/common/ui_style.gd` heeft kleuren en tekenhulpjes), schermen zijn 1280x720 en
worden in het midden van het venster gezet (`MenuScreen.stage`).

## Schermflow

```
Main menu ──Fight────────┐
          ──Training─────┴─> Character select ──(beide klaar: A/Start)──> ui/match/match.tscn ──(einde)──> ui/results/results.tscn
          ──Instellingen──> Settings            (B = terug naar vorig scherm)                  A = rematch, B = select
                                                  match: L+R+A+Start (in de pauze) -> character select
          ──Sandbox (alleen debug-builds)──> scenes/sandbox.tscn
          ──Afsluiten
```

- `run/main_scene` = `res://ui/main_menu/main_menu.tscn`.
- **Fight**: P1 en P2 kiezen elk. **Training**: alleen P1 kiest; de dummy wordt bij het starten een willekeurig
  *ander* character (is er maar één, dan hetzelfde).
- De keuzes staan in autoload `MatchSetup` (`mode`, `picks[0..1]` = character-id's, `was_random[]`, `rules`).
  `MatchController` leest daar. `rules` is een `MatchRules` (4 stocks, 8 min, items uit, sudden death aan; alleen data).

## Bediening

Alle schermen lezen `InputManager.history(p)` via `MenuNav` (`ui/common/menu_nav.gd`), één keer per physics-frame:

| Actie | Controller | Toetsenbord (speler 1) |
|---|---|---|
| Richting (herhaalt na 22 frames, daarna elke 6) | linkerstick | pijlen / WASD |
| Bevestigen | A | Enter / J |
| Terug | B of Y | Esc / Backspace / Spatie |
| Secundair (filter wisselen) | X | Tab |
| Start | Start | — |
| Pagina vorige / volgende | LT / RT of RB | PageUp / PageDown |

Wat bij het openen van een scherm al ingedrukt is (de A waarmee je binnenkwam) telt niet als nieuwe druk.
Muis: hoveren selecteert, klikken activeert; op de character select kiest klikken voor speler 1, het wiel bladert.
Het zoekveld: `/` of Ctrl+F; Esc/Enter verlaat het. Terwijl je typt is speler 1 gedempt.
`Sim`-debugtoetsen (P, `.`, Back, RB) werken alleen met `Sim.debug_context` (sandbox en training); menu's zetten dat uit en draaien nooit gepauzeerd.
Beperking: toetsenbord werkt alleen voor speler 1; speler 2 heeft een controller nodig.

Geluiden: `UiStyle.sfx("menu_move" | "menu_confirm" | "menu_back" | "menu_start")` roept `Sfx.play(naam)` aan
als de autoload `Sfx` bestaat (anders niets).

## Character select

- Grid van 7x3 per pagina; tegel 0 is altijd **Random**. Schaalt naar honderd characters (pagina's, zoeken, filter).
- Portretten: `PortraitCache` rendert per character één keer een `CharacterVisual` (idle) naar een SubViewport; de
  spelerspanelen tonen een groot live portret in de spelerskleur (P1 rood, P2 blauw).
- Filter (X of klik op de chip): Alle -> elk archetype dat voorkomt -> Alleen OP. Zoeken op naam, id, archetype, tagline.
- **OP-characters** hebben een gouden rand met pulserende rode gloed en een "OP"-badge (ook in het spelerspaneel).
- Token: A plaatst het token ("KLAAR"), B pakt het terug (B zonder token = terug naar het hoofdmenu, alleen P1).
  Zijn alle benodigde spelers klaar, dan verschijnt de ready-balk; A of Start begint. Mirror matches mogen.
- Random wordt bij het plaatsen van het token vastgelegd (uit de zichtbare/gefilterde lijst) en getoond.

## Manifest: `characters/<id>/character.json`

Klein bestand naast `art/`; de map is de bron van het id. Alles behalve de map zelf is optioneel (fouten worden
waarschuwingen, het character blijft bruikbaar).

```json
{
  "id": "_dummy",
  "name": "Houten Pop",
  "archetype": "Allrounder",
  "op": false,
  "tagline": "Korte zin voor onder de naam.",
  "colors": { "primary": "#c9a26b", "secondary": "#6b4a2a" }
}
```

| Veld | Betekenis |
|---|---|
| `id` | Moet gelijk zijn aan de mapnaam (anders wordt de mapnaam gebruikt, met waarschuwing) |
| `name` | Weergavenaam (standaard: mapnaam netjes gemaakt) |
| `archetype` | `Zwaargewicht`, `Allrounder`, `Fast-faller`, `Floaty` of `Lichtgewicht` (zie `docs/balans.md`) |
| `op` | `true` = buiten het 200-budget; wordt op de select gemarkeerd (standaard `false`) |
| `tagline` | Max. ~2 regels, getoond in het spelerspaneel |
| `visual_height` | Lengte in Melee-units, 8–30 (zie `docs/balans.md`); standaard die van het archetype |
| `taunt_text`, `taunt_frames`, `taunt_props` | Taunt-wolkje, duur (30–180) en rekwisieten; zie `docs/character-creatie.md` (Opslag per character) |
| `colors.primary/secondary` | Hex; accent van tegel en paneel (niet de spelerskleur van het rig) |

**Ontdekking** (`CharacterRegistry`, autoload): mappen onder `res://characters/` zonder `_`-prefix zijn spelbaar;
`_dummy` doet alleen mee als `include_dummy` aan staat (standaard: debug-builds). Een map zonder `character.json`
maar met `art/` telt mee met afgeleide gegevens; een map zonder beide wordt genegeerd.
`CharacterRegistry.rescan()` leest alles opnieuw (hot reload; emit `rescanned`, de select herbouwt zichzelf).
API: `characters`, `get_info(id)`, `has_character(id)`, `ids()`, `archetypes_in_use()`, `random_id(rng, exclude)`.
Het `/nieuw-character`-proces moet dus `character.json` aanmaken.

## Instellingen (autoload `Settings`, `user://settings.cfg`)

`tap_jump[p]` (standaard aan, per speler), `rumble`, `master_volume`, `sfx_volume` (0..1), `fullscreen`.
Setters slaan direct op, passen master-volume en fullscreen toe en sturen `changed`.
Gameplay leest `Settings.tap_jump_enabled(player)` en `Settings.rumble`; `Sfx.play` past `Settings.sfx_volume` toe (0 = stil).

## Nieuw scherm maken

1. `ui/<naam>/<naam>.gd` met `extends MenuScreen`; `.tscn` met één root-`Control` (full rect) en dat script
   (kopieer `ui/main_menu/main_menu.tscn`).
2. Bouw de UI in `_build()` als children van `stage` (1280x720). Gebruik `MenuList` voor lijsten,
   `add_hint_bar("…")` voor de voetregel, `UiStyle` voor kleuren/tekst.
3. Reageer in `_on_act(player, act)` op `MenuNav.Act.*`; wissel van scherm met `go("res://…")`.
   Per-frame werk in `_tick()` (loopt in `_physics_process`). `active_players` bepaalt welke spelers worden gepold.
4. Voeg het scherm toe aan `tests/test_ui.gd` (instantiëren) en maak een screenshot (zie onder).

## Screenshots en tests

```
Godot_console.exe --path . res://tools/ui_shot/ui_shot.tscn -- --scene res://ui/main_menu/main_menu.tscn --out C:/pad/menu.png
```
Windowed (headless rendert niet). Opties: `--wait <frames>`, `--mode training`, `--lock1 x [--move1 n]`, `--lock2 x`.
Voorbeelden staan in `ui/screenshots/`.

Test: `Godot_console.exe --headless --path . --script res://tests/test_ui.gd` (registry, manifest, settings,
MatchRules, MenuNav, schermen). Let op: in `--script`-modus bestaan autoload-namen niet als globals bij het compileren;
vandaar dat `MenuNav` zijn autoloads via de scene tree opzoekt.

## Match (M6)

Scène `ui/match/match.tscn` (root = `MatchController`, `engine/match/match_controller.gd`). Leest `MatchSetup` (mode, picks,
rules). Opbouw: stage Eindpunt, 2 `Fighter`s op `stage.get_spawn(i)` (`auto_respawn = false`), `MatchCamera` op de levende
fighters, `MatchHud`. Movement-stats via het `archetype` uit `character.json` -> `Archetypes.load_stats` (onbekend = Allrounder).
Pure logica zit in `MatchState` (stocks, KO/fall/SD-tellers, timer, einde, tiebreak) en is los testbaar; `MatchResult.last`
houdt de uitslag voor het results-scherm.

**Tikken**: de controller is een Sim-entity (`sim_tick`, registreert zich ná de fighters) en loopt dus op sim-frames.
Constanten (frames): countdown 3-2-1 = 3x60 (`countdown_tick` per cijfer, `go` bij start), "GO!" 45 frames zichtbaar,
`RESPAWN_DELAY` 120 ⚠️, `RESPAWN_INVINCIBLE` 120 ⚠️, `TRAINING_RESPAWN_DELAY` 45, `END_DELAY` 150 (GAME!/TIME! -> results).
Tijdens countdown en einde staat de input van de fighters op een blanco `InputHistory` (en die van de training-dummy altijd).

**Flow**: `blast_ko(fighter, side)` -> (in de eigen sim_tick afgehandeld) stock eraf, fighter uit de Sim en onzichtbaar,
camera volgt alleen de levenden, na `RESPAWN_DELAY` `respawn_at(stage.get_respawn(i), RESPAWN_INVINCIBLE)` en % = 0.
Einde (`MatchState.evaluate`): één speler over wint; beide op 0 of tijd op en alles gelijk -> **sudden death** (beide 1 stock op 300%,
nieuwe countdown, geen timer; blijft herhalen bij gelijktijdige val). Tijd op: meeste stocks, dan laagste %. Zet je
`rules.sudden_death` uit, dan is het een gelijkspel (winnaar -1).
KO/SD-telling: een val telt als KO voor de tegenstander als het % van het slachtoffer ≤ `HIT_MEMORY` (300 frames) geleden
steeg (via `percent_changed`), anders als SD (zelfvernietiging). Heeft de fighter geen `percent_changed`, dan is elke val een KO.

**Pauze (Melee)**: Start (controller) of Enter/Esc (toetsenbord, P1) pauzeert zodra de match loopt (niet in de countdown) via
`Sim.set_paused(true)` + overlay; alleen de speler die pauzeerde kan hervatten (Start) of stoppen (**L+R+A+Start**, triggers >= 0,7;
toetsenbord: Q) -> `MatchResult.last = null`, terug naar de character select. Tijdens de pauze sampelt de controller zelf de input
(de Sim doet dat dan niet). `process_pause_input(p, frame)` is de testbare kern.

**HUD** (`ui/hud/match_hud.gd`, CanvasLayer 20): per speler onderaan een schuine plaat met mini-portret (`PortraitCache`, idle in
spelerskleur), naam, **damage %** (kleur wit -> geel -> oranje -> rood -> donkerrood op 0/40/90/140/220%, schudt 14 frames bij
toename; geteld in sim-frames, dus bevroren in de pauze) en stock-iconen eronder; timer bovenaan (laatste 10 s rood);
banners (3-2-1, GO!, GAME!/TIME!, SUDDEN DEATH) en de pauze-overlay.

**Training** (`mode == training`): dummy = de gekozen andere character, krijgt nooit input; oneindige stocks (val kost niets,
respawn na 45 frames), geen timer, einde nooit. Besturing speler 1: D-pad omhoog/omlaag = dummy-% +-10, links = reset posities,
rechts = dummy-% 0 (toetsenbord F7/F6, F8, F9); hint-balk bovenin. `Sim.debug_context` staat aan (P/`.`/Back werken).

**Results** (`ui/results/results.tscn`): winnaar groot in spelerskleur (gelijkspel: beide), per speler KO's / Falls / SD's,
stocks en %. A/Start = rematch (zelfde `MatchSetup`), B = character select.

## Screenshots van de match

```
Godot_console.exe --path . res://tools/match_shot/match_shot.tscn -- --out C:/pad/x.png [--frames 260] [--mode training]
    [--pct1 37 --pct2 128] [--stocks1 n --stocks2 n] [--pause] | [--results --winner 0|1|-1]
```
Voorbeelden: `ui/screenshots/match_hud.png`, `match_countdown.png`, `match_pause.png`, `match_training.png`, `results.png`, `results_draw.png`.
Test: `Godot_console.exe --headless --path . --script res://tests/test_match.gd` (MatchState, controller met fake fighters,
pauze-regels, training, `Sim`-debugtoetsen, Sfx-volume, plus één integratie met echte Fighters).

## VFX in de wedstrijd

De `MatchController` bouwt een `VfxLayer` (kind van de controller, geen transform = oorsprong, effecten rekenen in wereld-px).
- `layer.camera` = de `MatchCamera` (shake bij KO/sterke hits); `layer.ko_clamp_rect_units` start als de camera bounds van de stage.
- **Vinden voor gameplay-code** (fighters, een toekomstig `CombatSystem`): groep `"vfx_layer"`, dus
  `get_tree().get_first_node_in_group(MatchController.VFX_GROUP)`. Fighters met een `vfx`-eigenschap krijgen de layer direct toegewezen
  (`"vfx" in fighter`). `controller.vfx` is dezelfde layer.
- **KO** (`blast_ko`): `spawn_ko(character_id, pos, side, spelerskleur)` op het punt waar de fighter de blast zone verliet (pos en zijde worden bij het
  signaal vastgelegd), naast SFX `ko_blast`; de layer schudt de camera zelf. Vlak voor het spawnen wordt `ko_clamp_rect_units` gezet op het
  *zichtbare* camerabeeld (ingekrompen, binnen de bounds): de camera zit dicht op de fighters, dus klemmen op de bounds zou het effect buiten beeld zetten.
- **Respawn**: `spawn_respawn(respawn-punt, spelerskleur)`. Let op: spawnt de fighter zelf ook een respawn-effect, dan komt het dubbel.
- **Einde door KO**: `ENDING` duurt minstens `END_DELAY` frames en wacht daarna tot het laatste KO-effect klaar is (max `END_KO_WAIT_MAX` = 90 extra frames).
- **GAME!/TIME!-banner**: HUD toont hem tijdens `ENDING`; bij het einde klinkt SFX `go` (⚠️ placeholder voor een eigen stem).
