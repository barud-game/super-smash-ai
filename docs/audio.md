# Audio: gegenereerde geluidseffecten

Alle sfx worden **procedureel** gegenereerd uit JSON-recepten; er zijn geen audiobestanden.
Geluid is puur presentatie: het raakt de sim/gameplay nooit (eigen RNG voor pitch-variatie).

## Onderdelen
| Bestand | Rol |
|---|---|
| `engine/audio/sfx_synth.gd` (`SfxSynth`) | recept -> samples -> `AudioStreamWAV` (16-bit, 44,1 kHz, mono). Deterministisch. |
| `engine/audio/sfx_bank.gd` (`SfxBank`) | recepten laden, streams cachen, character-override lookup, lijst `NAMES`. |
| `engine/audio/sfx.gd` (autoload `Sfx`) | afspelen via een pool van 16 `AudioStreamPlayer`s. |
| `engine/audio/recipes/<naam>.json` | de recepten. |
| `tools/sfx_preview/sfx_preview.tscn` | bladeren, afspelen, golfvorm zien, exporteren naar `.wav`. |
| `tests/test_audio.gd` | headless test (lengte, clipping, determinisme). |

## Gebruik
```gdscript
Sfx.play("hit_strong")                       # standaard
Sfx.play("hit_weak", 0.05)                   # +-5% pitch-variatie (alleen audio)
Sfx.play("jump", 0.03, -2.0)                 # + volume_db
Sfx.play("jump", 0.0, 0.0, "mijn_character") # zoekt eerst characters/mijn_character/sfx/jump.json
Sfx.preload_all()                            # alles vooraf genereren (laadscherm)
```
Streams worden bij de eerste keer gegenereerd (enkele ms tot tientallen ms) en daarna gecachet.

## Geluiden (`SfxBank.NAMES`)
hit_weak, hit_medium, hit_strong, hit_kill, shield_hit, shield_break, grab, throw, jump, double_jump,
land, land_heavy, airdodge, wavedash_slide, dash, ledge_grab, ko_blast, respawn, menu_move,
menu_confirm, menu_back, countdown_tick, go.

## Character-override
`SfxBank` zoekt `res://characters/<id>/sfx/<naam>.json` en valt terug op de standaardrecepten.
Zelfde formaat als hieronder; nog geen character heeft overrides.

## Receptformaat
```json
{
  "duration": 0.2, "seed": 12, "volume_db": 0, "peak": 0.89,
  "layers": [ { ...laag... } ],
  "master": { "drive": 1.0, "lp": 6000 }
}
```
- `duration` seconden (totaal, 0.01 – 3). `seed` voor de ruis (deterministisch). `volume_db` wordt door `Sfx.play` opgeteld.
- `peak` = doelpiek na normalisatie (standaard 0.89, nooit clippen). Lagen bepalen dus alleen de verhouding; het
  eindniveau stel je met `volume_db` in.
- `master`: optioneel `lp` (laagdoorlaat in Hz op de mix) en `drive` (tanh-saturatie op de mix).

Laag (`layers[]`), alle velden optioneel behalve `osc`:
| Veld | Betekenis |
|---|---|
| `osc` | `sine`, `square`, `saw`, `tri`, `noise` |
| `freq` | getal of `[start, eind]` in Hz; glijdt exponentieel (pitch-envelope) |
| `curve` | tijdvervorming van de glijding: <1 = snel in het begin, >1 = laat |
| `duty` | pulsbreedte van `square` (0.05–0.95) |
| `delay`, `len` | start en lengte van de laag in seconden (voor opeenvolgende noten / lagen) |
| `env` | `[attack, decay, sustain, release]` in s / niveau; `pow` = kromming van de decay (2 = percussief) |
| `gain` | niveau van de laag |
| `vib` | `[Hz, semitonen]` vibrato |
| `filter` | `{ "type": "lp"/"hp"/"bp", "cutoff": [begin, eind] of getal, "q": 0.7 }` (state-variable, cutoff glijdt) |
| `bits` | bitcrush naar N bits (retro-grit) |
| `hold` | sample-rate reductie (elke N-de sample vasthouden) |
| `drive` | distortion (tanh) |

## Nieuw recept toevoegen
1. Maak `engine/audio/recipes/<naam>.json`.
2. Voeg `<naam>` toe aan `SfxBank.NAMES` (en dus aan test en preview).
3. Open `tools/sfx_preview/sfx_preview.tscn` (F6), blader ernaartoe, `R` herlaadt na een wijziging.
4. Draai `tests/test_audio.gd`.

Tips: een goede hit = korte ruisburst met dalend lowpass + lage sinus met snelle pitch-drop (de "dreun")
+ een beetje bitcrush. Een "smash" (hit_kill/ko_blast) krijgt een lange lage sinus met `drive`.
Filter-cutoff is intern begrensd op ~7 kHz (SVF-stabiliteit).

## Verificatie
`tests/test_audio.gd` draait headless: elk recept wordt gegenereerd, duur <= 1.5 s, peak <= 1.0, niet stil,
alle samples eindig, twee keer renderen geeft identieke bytes.

```
Godot_console.exe --headless --path . --script res://tests/test_audio.gd
```

**Let op:** de geluiden zijn alleen numeriek gecontroleerd (piek, RMS, duur), niet beluisterd. Beoordeel ze
op het gehoor met de preview-tool en pas recepten aan (volume_db, pitch, bits, filter) waar nodig.
Exports (`E` / `Shift+E`) komen in `tools/sfx_preview/out/` (in `.gitignore`).
