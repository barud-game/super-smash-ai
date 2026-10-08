# UI: menu's, roster en instellingen

Alles in `ui/`, plus `engine/roster/` (CharacterRegistry) en `engine/match/match_rules.gd`.
Stijl: donker kosmisch (`ui/common/ui_style.gd` heeft kleuren en tekenhulpjes), schermen zijn 1280x720 en
worden in het midden van het venster gezet (`MenuScreen.stage`).

## Schermflow

```
Main menu ──Fight────────┐
          ──Training─────┴─> Character select ──(beide klaar: A/Start)──> ui/match_stub.tscn (later: echte match)
          ──Instellingen──> Settings            (B = terug naar vorig scherm; stub: B -> character select)
          ──Sandbox (alleen debug-builds)──> scenes/sandbox.tscn
          ──Afsluiten
```

- `run/main_scene` = `res://ui/main_menu/main_menu.tscn`.
- **Fight**: P1 en P2 kiezen elk. **Training**: alleen P1 kiest; de dummy wordt bij het starten een willekeurig
  *ander* character (is er maar één, dan hetzelfde).
- De keuzes staan in autoload `MatchSetup` (`mode`, `picks[0..1]` = character-id's, `was_random[]`, `rules`).
  De match-scène leest daar. `rules` is een `MatchRules` (4 stocks, 8 min, items uit, sudden death aan; alleen data).

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
`MenuNav.keep_sim_running()` zet `Sim` weer aan als de P-toets hem pauzeerde (anders stopt de input-sampling).
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
Gameplay leest `Settings.tap_jump_enabled(player)` en `Settings.rumble`; `Sfx` mag `Settings.sfx_volume` gebruiken.

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
