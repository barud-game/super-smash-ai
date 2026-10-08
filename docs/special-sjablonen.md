# Special-sjablonen

Spelers omschrijven hun specials in gewone taal. De director vertaalt zo'n omschrijving naar een
**sjabloon + instellingen** (een `specials/*.tres`), zonder nieuwe code. Alleen een mechaniek dat in geen
enkel sjabloon past wordt een eigen script (`special-builder`).

> Status: ontwerp (M3–M5-input). Alle frame-getallen zijn Melee-achtige richtwaarden en worden gekalibreerd
> tegen `docs/melee-referentie.md` en de validator. Geen code in dit document; het beschrijft wát er nodig is.
> Prijzen zijn voorlopig en horen bij `docs/balans.md` (assen 0–5, utility 0–10).

## 0. Gedeelde afspraken

### 0.1 Fasemodel
Elke special is een rij fases, alles in **frames** (60 Hz):

`startup → actief → einde (endlag)` en optioneel `charge`, `hold`, `follow-up`, `landing`.
Frame 1 is de eerste tick na de knopdruk. "Actief" = de move kan raken/werkt. Een fase kan per
grond/lucht andere lengtes hebben; instellingen noemen dat `_ground` / `_air`.

### 0.2 Gedeelde instellingen (gelden voor ieder sjabloon, tenzij anders vermeld)
| Instelling | Type / bereik | Betekenis |
|---|---|---|
| `startup_ground`, `startup_air` | int 3–40 | Frames tot de actieve fase |
| `active_frames` | int 1–60 | Duur actieve fase |
| `endlag_ground`, `endlag_air` | int 0–60 | Frames na actief tot actie mogelijk is |
| `air_allowed` / `ground_allowed` | bool | Mag in de lucht / op de grond. Anders: gebruik geblokkeerd |
| `momentum_air` | enum: `keep`, `scale`, `zero` | Behoud van snelheid bij start in de lucht |
| `momentum_scale` | float 0–1 | Bij `scale`: factor op x/y-snelheid bij start |
| `gravity_scale` | float 0–1.5 | Zwaartekracht tijdens de move (0 = zweeft) |
| `stick_control` | enum: `none`, `x_only`, `full` | Mag de speler tijdens de move sturen |
| `steer_max_angle` | float 0–90° | Maximale bocht per move bij sturen |
| `helpless_after` | bool | Special fall na afloop (geen actie in de lucht behalve driften) |
| `helpless_on_hit_only` | bool | Helpless pas als de move raakt of mist (zie sjabloon) |
| `landing_lag` | int 0–40 | Frames lag bij landen tijdens/na de move (altijd vast, geen L-cancel) |
| `ledge_snap` | enum: `none`, `during`, `end_only` | Mag de move de ledge grijpen |
| `ledge_snap_range` | float (Melee-units) 0–40 | Extra grijpbereik rond de ledge |
| `air_use_limit` | int 0–3 of `inf` | Gebruiken per airtime; reset bij landen, ledge-grab, hit, wall/respawn |
| `limit_resets_on_hit` | bool | Raken of geraakt worden herstelt de limiet |
| `armor` | `none` / `{venster, drempel}` | Zie 0.4 |
| `intangible` | `none` / `{venster, hoeveelheid}` | Zie 0.4 |
| `cancel_window` | `none` / `{van, tot, naar}` | Mag de move vroeg worden afgebroken (bijv. naar jump/shield) |
| `hit_data[]` | lijst hitboxes | Per hitbox: frame-venster, offset, straal, damage, hoek, base/scaling KB, hitlag, element, `disjoint`, `clank` |
| `sfx`, `vfx`, `anim_tag` | strings | Alleen presentatie |

Standaardwaarden: `momentum_air=keep`, `gravity_scale=1`, `stick_control=none`, `helpless_after=false`,
`ledge_snap=none`, `air_use_limit=inf`.

### 0.3 Altijd afgevangen randgevallen (gelden voor alle sjablonen)
- **Geraakt worden tijdens de move:** tenzij armor/intangible dekt, breekt de move af; alle gespawnde
  entities blijven bestaan tenzij het sjabloon anders zegt; charge wordt weggegooid (of bewaard, zie charge shot).
- **Ledge:** grijpen mag alleen als `ledge_snap` het toelaat, de speler niet omhoog beweegt boven de
  Melee-ledge-regels, en de ledge niet bezet is (bezette ledge = niet grijpen; zie bouwstenen).
- **Stage-rand / blastzone:** beweging stopt nooit "magisch" voor de blastzone; alleen het podium (solide
  blokken) beperkt. Dood door blastzone tijdens de move is normaal. Projectielen verdwijnen buiten de blastzone-marge.
- **Platforms:** door-platforms (pass-through) tellen alleen als vloer bij dalende beweging en zonder neergedrukte
  stick naar beneden; gespecificeerd per sjabloon of de move erdoorheen mag.
- **Landen:** landen tijdens de actieve of eindfase geeft `landing_lag` (of de grond-endlag als die lager is), niet beide.
- **Shield:** elke hitbox raakt shield met normale shield-regels (shield damage, shieldstun, pushback); de
  special mag shield-grabs/pushback niet omzeilen tenzij het sjabloon (grab) dat expliciet doet.
- **Dood / respawn / stocks:** alle entities van een fighter worden bij zijn dood opgeruimd; limieten resetten bij respawn.
- **Determinisme:** geen willekeur zonder seeded RNG; spawn-volgorde van entities is vast.
- **Pauze / hitlag:** timers van de move bevriezen tijdens hitlag van de eigen fighter; projectielen leven door tenzij zij zelf hitlag hebben.
- **Meerdere gebruikers:** per fighter-slot een identiteit zodat projectielen, tethers en traps weten van wie ze zijn (geen friendly fire in 1v1; in teams instelbaar).

### 0.4 Armor en intangibility (gedeelde parameters)
- **Armor:** `armor = {van_frame, tot_frame, max_damage}`. Hit met damage ≤ drempel wordt geabsorbeerd (wel damage,
  geen knockback/hitstun, korte hitlag); hoger → normaal geraakt en armor gebroken. Richtwaarde: drempel 5–12%.
  Grabs negeren armor tenzij `armor_vs_grab=true`.
- **Intangibility:** `intangible = {van, tot, deel}` waarbij `deel` = `all` (hurtbox uit) of `body_parts`. Max zinnige
  duur 8–20 frames per move; langer dan 20 → utility-toeslag. Ledge-intangibility is een apart bestaand systeem en telt niet mee.
- **Invincible start/einde bij bewegen:** vaak combineren met `no_hurt_on_ledge_during_snap`; zie teleport.

### 0.5 Hoe prijzen werkt (kort)
Elke special: kosten = som assen (S, K, B, V; elk 0–5) + utility (0–10). Gemiddeld ~8 voor normals; voor
specials is utility vaak de dominante term. Elke sjabloonsectie geeft een **prijs-richtlijn**: welke instelling
welke as beïnvloedt. Vuistregel voor utility (specials):

| Utility | Voorbeeld |
|---|---|
| 0–2 | Zwakke gimmick, nauwelijks effect op het spel |
| 3–5 | Duidelijk bruikbaar tool (projectiel, armor-move, kleine recovery) |
| 6–8 | Volwaardige recovery of sterke neutral-tool (reflector, counter, goede teleport) |
| 9–10 | Spelbepalend (onderschept bijna alles of recovery over bijna het hele scherm met weinig risico) |

Een character heeft **minstens één bruikbare recovery** (up-B of side-B met utility ≥ 5 in recovery-vorm); anders
meldt de validator een waarschuwing, geen fout.

---

## 1. Projectiel (`projectile`)

**Wat het doet:** schiet een of meer entities die vooruit (of in een boog) vliegen en bij contact schade en
knockback geven. De fighter staat vrij kort stil.
*"Ik gooi een vuurbal." · "Ik schiet een ijsstraal die langzaam over de grond glijdt." · "Ik gooi een boemerang die terugkomt."*

**Fases (grond):**
1. Startup 8–20 frames (animatie, geen projectiel).
2. Spawn-frame (1 frame) — projectiel verschijnt op `spawn_offset`.
3. Endlag 15–35 frames.
Lucht: zelfde startup, endlag 15–30 frames, `momentum_air=scale 0.5` standaard; landen in endlag → `landing_lag` 4–12 (geen helpless).

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `spawn_offset` | Vector2 (units) | Relatief aan fighter, draait mee met facing |
| `speed` | float 0.5–6 u/f | Melee: kleine bal ~1.5–2.5, snelle laser 4–6 |
| `angle` | float −90..90° | 0 = horizontaal; boven/onder voor hoek-projectielen |
| `angle_stick_aim` | bool | Eerste N frames stick bepaalt hoek (binnen `steer_max_angle`) |
| `gravity` | float 0–0.1 u/f² | 0 = recht, >0 = boog |
| `bounce` | enum: `none`, `floor`, `walls`, `both` + `bounce_count` 0–4 | |
| `lifetime` | int 20–300 frames | Of tot `max_range` 40–600 units |
| `size` | float 3–40 units straal | |
| `count` | int 1–5 | Per gebruik (spread via `spread_angle` 0–60°) |
| `max_alive` | int 1–5 | Per fighter tegelijk; nieuw gebruik geblokkeerd of vervangt oudste (`on_cap`: `block`/`replace`) |
| `pierce` | int 0–`inf` | Hoeveel targets het raakt voor het verdwijnt (0 = verdwijnt bij eerste hit) |
| `multi_hit` | `{hits, interval}` | Bijv. traag projectiel dat 3× raakt |
| `damage`, `kb_angle`, `kb_base`, `kb_scale` | per hitbox | Damage 2–12% richtwaarde (verdwijnende projectielen laag houden) |
| `is_transcendent` | bool | Clankt niet met andere projectielen (wel met reflect/absorb) |
| `reflectable`, `absorbable` | bool | Standaard true |
| `hitlag_mult` | float | Projectiel veroorzaakt minder hitlag dan melee (0.5–1) |
| `charge_link` | verwijst naar charge shot | Zie §2 |
| `follows_owner` | bool | Projectiel dat meebeweegt/zweeft rond de fighter (orbit) |

**Randgevallen:**
- Spawn in een muur/solide blok: projectiel verdwijnt meteen of verschijnt aan de dichtstbijzijnde vrije kant (`spawn_blocked`: `fizzle`/`shift`). Kies `fizzle` voor eerlijkheid.
- Projectiel raakt de eigenaar: nooit. Wel eigen reflector/absorber van een bondgenoot (teams) via regels.
- **Projectiel vs projectiel:** hogere damage wint, gelijk = beide weg, `is_transcendent` negeert. Eén rekenregel overal (Melee: clank-regel op damage).
- **Reflect:** reflecteer draait richting om, eigenaar wisselt, damage ×1.5 (zie §6), lifetime reset.
- **Absorb:** verdwijnt, eigenaar van absorber krijgt effect (§12).
- **Shield:** raakt shield; verdwijnt of stuitert (`on_shield`: `vanish`/`pass`); schaal op shield-damage = damage.
- **Rand van stage:** verdwijnt bij blastzone; stuitert alleen als `bounce` dat zegt; niet door solide blokken.
- Door-platforms: genegeerd door rechte projectielen; boogprojectielen landen erop als `bounce`≠none.
- Fighter wordt geraakt tijdens startup: spawn gebeurt niet (geen gespaard projectiel).
- **Max-alive vol:** de special start wel de animatie maar spawnt niets, of is geblokkeerd; kies `block` (zichtbaar duidelijker).
- Hitlag van eigenaar bevriest geen bestaande projectielen.
- Veel projectielen (≥ 6 in totaal): performance-cap en oudste verwijderen.

**Prijs-richtlijn:**
- **Snelheid (S):** startup+spawn. ≤ 6f = 5, 7–10 = 4, 11–15 = 3, 16–20 = 2, 21+ = 1.
- **Kracht (K):** vrijwel altijd laag. Damage ≤ 4% / geen KB = 1; flinke KB (kill vanaf 150%) = 3; kill rond 100% = 4.
- **Bereik (B):** `speed × lifetime`/`max_range`. Korte afstand (<150u) = 1–2; halve stage = 3; heel scherm of pierce = 4–5; boog/stuiter +1.
- **Veiligheid (V):** endlag van eigenaar. ≤ 20f = 5 (veilig), 21–28 = 3–4, 29+ = 1–2. Projectiel dat de tegenstander afhoudt telt niet als veiligheid.
- **Utility:** 3–5 voor een standaard projectiel; +1 voor `count>1`, +1 voor `pierce`/multi-hit camping, +1 voor `gravity>0` dat gaten dekt; −1 als `max_alive=1` en lange endlag.
- Aanvullend: `is_transcendent` +1; `angle_stick_aim` +1; zeer traag projectiel dat als "muur" werkt +1 maar dan kracht/veiligheid laag.

---

## 2. Charge shot (`charge`)

**Wat het doet:** de speler houdt de knop (of houdt hem ingedrukt en laat los) om kracht op te bouwen; losgelaten geeft het een sterker effect. Kan een projectiel, een aanval of een buff versterken.
*"Ik laad een energiebal op, hoe langer hoe harder." · "Ik laad een stoot op en sla dan door het scherm."*

**Fases:**
1. Startup 5–12f (naar charge-pose).
2. **Charge-loop** 1 tot `charge_max` frames: fighter in charge-pose; knop vast.
3. Release: klein startup-venster 3–8f, daarna het effect (projectiel/hitbox) conform het gekoppelde sjabloon.
4. Endlag 12–30f (afhankelijk van lading, vaak vast).
Grond: fighter kan tijdens charge stilstaan (`charge_move`: `none`/`walk`). Lucht: `air_charge` toegestaan met zakken of vol momentum (`momentum_air=zero` of `scale 0.3`); standaard: lucht-charge toegestaan, helpless nee.

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `charge_min` | int 0–20 | Minimale lading voor loslaten, anders hakken mini-versie |
| `charge_max` | int 30–180 | Melee richtwaarde 60–120 voor "snelle" charges |
| `charge_stages` | int 1–4 of continu | Discrete niveaus of lineair interpoleren |
| `scale` | per niveau: damage ×, KB ×, size ×, speed × | Bijv. damage 5% → 25%, size ×1–×3 |
| `hold_cancel` | enum: `shield`, `jump`, `both`, `none` | Kan het opgebouwde charge opgeven; in Melee bewaren via shield |
| `charge_keep` | bool | Lading blijft bewaard bij cancel/schade (max `keep_frames` 0–300) |
| `auto_release` | bool | Vol = automatisch vuren, anders blijft vol staan |
| `auto_release_damage` | bool | Bij geraakt worden: afbreken, vuren of bewaren |
| `charge_move` | `none`/`walk`/`drift` | Stick tijdens charge |
| `charge_armor` | armor-spec | Optioneel (bijv. super armor bij vol); kost utility |
| `charge_signal` | vfx/sfx | Visueel/auditief niveau (voor tegenstander leesbaarheid, verplicht) |
| `linked_template` | `projectile`/`dash_strike`/`command_grab`/`transform` | Wat er loskomt |

**Randgevallen:**
- Geraakt worden tijdens charge: standaard charge verloren (`charge_keep=false`); stelt `charge_keep=true` dan blijft de lading (Melee-gevoel: wel bewaard bij cancel).
- Charge bij ledge: grond-charge blijft bestaan als fighter van de ledge valt? Nee — charge breekt af bij verlaten van de vloer tenzij `air_charge`.
- **Spelers wisselen van state** (shield/jump) tijdens charge: `hold_cancel` bepaalt of lading blijft.
- Loslaten in de eerste frames: minimum charge → "zwakke" versie, nooit niets doen.
- Lading en **lucht-landen**: bij landen tijdens charge in de lucht → naar grond-charge als `charge_continues_on_land`, anders afbreken.
- Meerdere charges tegelijk (twee projectielen): `max_alive` van het gekoppelde sjabloon geldt.
- Hitlag tijdens charge (door armor): charge-timer bevriest ook.
- Idle-/AFK-situatie: een volle charge die blijft staan mag gewoon (geen timeout), maar `auto_release` kan.
- Input-semantiek: loslaten van knop bij frame van state-wissel moet deterministisch zijn (zelfde frame-volgorde als overige input).

**Prijs-richtlijn:**
- **Snelheid:** tijd tot een *bruikbare* (niet-minimale) versie; meestal 2–3 omdat vol charge langzaam is. Vol-charge ≤ 40f = 4, 41–80 = 3, 81+ = 2.
- **Kracht:** volle versie bepaalt kracht: kill rond 80% = 5, 100% = 4, 120% = 3.
- **Bereik:** maximale hitbox/projectielgrootte; gekoppeld sjabloon bepaalt.
- **Veiligheid:** endlag + of de charge verloren gaat bij hit (`charge_keep=true` +1 V, want minder risico). Lange kwetsbare charge-pose zonder armor drukt V naar 1–2.
- **Utility:** 2–4 voor charge als bonus; `charge_armor` +2; `charge_keep` +1; lucht-charge +1.
- Totaal-regel: charge-sjablonen zijn goedkoper per niveau dan niet-chargebare versies van dezelfde kracht, omdat tijd de prijs is.

---

## 3. Teleport-recovery (`teleport`)

**Wat het doet:** de fighter verdwijnt kort en verschijnt op een andere plek, richting door stick bepaald (of vast); vaak als recovery.
*"Ik teleporteer omhoog." · "Ik flits in een richting naar plek waar ik naartoe stuur." · "Ik verdwijn in een rookwolk en kom ergens anders terug."*

**Fases (lucht, typisch):**
1. Startup 6–20f (verdwijn-animatie), optioneel intangible vanaf frame 1.
2. **Verdwenen-fase** 4–15f: onzichtbaar, geen hurtbox, geen collision, geen zwaartekracht; richting wordt vastgelegd aan het begin van deze fase of aan het eind (`direction_lock`: `start`/`end`).
3. Aankomst: fighter staat op `target`, 1–2f hitbox mogelijk (`arrival_hit` optioneel).
4. Endlag 15–40f; na afloop `helpless_after` (meestal true in de lucht).
Grond: korter, vaak zonder helpless; vorm: grond-teleport = reposition (zie §15).

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `distance` | float 40–260 u | Melee: korte teleport ~110–150, lang ~200–260 |
| `direction_mode` | enum: `fixed`, `stick_8dir`, `stick_free`, `stick_n_dir` | `n_dir` = bijv. 4 of 8 richtingen |
| `fixed_angle` | float 0–360° | Bij `fixed` |
| `stick_deadzone_dir` | richting zonder stick = `neutral_dir` (bijv. omhoog) | |
| `vanish_frames` | int 2–20 | |
| `arrival_frames` | int 0–10 | Intangible/aankomst |
| `intangible_start`..`intangible_end` | frames | Zie 0.4; meestal gehele verdwijnfase |
| `arrival_hitbox` | `none`/hit_data | Optioneel; kost kracht |
| `departure_hitbox` | `none`/hit_data | Optioneel (vertrek-explosie) |
| `ledge_snap` | `end_only` standaard | Grijp tijdens aankomst, niet tijdens verdwijnen |
| `ledge_snap_range` | 15–35 u | |
| `target_validation` | enum: `snap_to_valid`, `shorten`, `fizzle` | Wat bij ongeldige bestemming |
| `can_cross_walls` | bool | Door solide blokken heen teleporteren |
| `momentum_after` | enum: `zero`, `keep_pre`, `exit_velocity` + `exit_speed` | Na aankomst |
| `air_use_limit` | meestal 1 | |
| `landing_lag_after` | int | Als helpless en landen |

**Randgevallen:**
- **Bestemming in solide stage-blok:** `snap_to_valid` = dichtstbijzijnde vrije punt langs de lijn terug (korter), of `shorten`. Nooit in de vloer vast komen te zitten.
- **Bestemming buiten blastzone:** toegestaan (suïcide mogelijk) maar `clamp_to_blast_margin` voorkomt dat een speler door te veel afstand direct sterft op een ontbrekende stage — standaard `clamp` uit voor eerlijkheid (speler fout), maar documenteren.
- **Ledge:** aankomst binnen `ledge_snap_range` → ledge grabben als niet bezet; bezette ledge → fighter blijft zweven/valt.
- **Door platforms:** aankomst op platform als de lijn erdoorheen gaat? Regel: land op platform alleen als de aankomstpositie boven een platform ligt en de fighter van boven komt; anders valt hij erdoorheen. Vastleggen en testen.
- **Geraakt worden tijdens verdwijnen:** niet mogelijk (intangible); tijdens startup/endlag wel → afbreken. Hit op aankomstframe = normaal behandeld.
- **Stage-rand** laterale stages (geen muren): richting `stick_free` met `distance` blijft gelijk.
- **Tegenstander op de bestemming:** fighters overlappen of botsen niet; aankomst is toegestaan overlappen en duwt dan via de normale pushout.
- **Aankomst op een tegenstander-hitbox:** de aanval raakt normaal.
- **Special fall na teleport** in de lucht, behalve `helpless_after=false`; als de speler vóór aankomst de vloer raakt (grond-teleport) geen helpless.
- Meerdere teleports per airtime beperkt door `air_use_limit`.
- Invulling "momentum stopt": kies expliciet. `momentum_after=zero` is standaard; `keep_pre` geeft chaotische recoveries (kost veiligheid-punten niet maar vraagt tests).
- Wall-teleport bij `can_cross_walls=false`: stopt tegen blok (`shorten`).
- Teleporteren **onder** de stage zonder `can_cross_walls` is voor veel stages niet bedoeld — validator test een vaste set stages.

**Prijs-richtlijn:**
- **Snelheid:** startup tot verdwijnen; ≤ 8f = 5, 9–14 = 4, 15–20 = 3, 21+ = 2.
- **Kracht:** zonder hitbox 0; met arrival/departure-hitbox 1–3 (damage ≤ 8% / lage KB = 1, killtool = 3).
- **Bereik:** `distance` + richtingsvrijheid. 60–110 u = 2, 111–160 = 3, 161–220 = 4, 221+ = 5; `stick_free` +1 t.o.v. `fixed`.
- **Veiligheid:** intangible-duur + endlag + helpless. Lang intangible (≥ 12f) + endlag ≤ 20f = 5; veel endlag of laat-vulnerabel = 2–3.
- **Utility (recovery):** `distance` ×richting: vaste korte up-teleport 4–5, stick_8dir 150u 7, free 200u+ 8–9. `can_cross_walls` +1. `ledge_snap_range` ≥ 30: +1. `helpless_after=false` +1; `air_use_limit>1` +2 per extra.
- Een teleport met departure-hitbox en intangible start is een **sterke** move; houd de som bewust onder de som van losse "teleport zonder hitbox".

---

## 4. Multi-hit / rising recovery (`rising_multi`)

**Wat het doet:** de fighter schiet omhoog (of schuin) terwijl de aanval meerdere keren raakt; eindigt vaak met een sterke laatste hit. Recovery én aanval.
*"Ik draai omhoog en sla alles onderweg." · "Ik duik als een raket omhoog en klap erbovenop."*

**Fases (lucht):**
1. Startup 3–12f (vaak met korte intangible op een enkele frame — niet verplicht).
2. **Stijgen:** `rise_frames` 10–40f met velocity omhoog (en optioneel zijwaarts via stick); multi-hit hitbox elke `interval` 2–6f (`hits` 3–10).
3. **Finisher:** laatste hit (strong, optioneel hoek omhoog/uit) in 2–4 actieve frames.
4. Endlag 20–40f; helpless_after (standaard true), landing_lag 8–30f.
Grond: stijgt direct uit de grond (vlot, `ground_hop`), of `grounded_only_finisher` zonder rise; ledge-grab sterk gewenst.

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `rise_speed` | float 1–5 u/f | Of totale `rise_distance` 40–250 u |
| `rise_curve` | enum: `constant`, `decel`, `accel`, `burst_then_float` | Snelheid over tijd |
| `rise_angle` | float 60–90° | Horizontale component via stick |
| `h_control` | `none` / `x_only` / `full` | + `h_speed_max` 0–2 u/f |
| `hits` / `interval` | int, int | Multi-hit tussen-hits: lage damage 1–3% en lage KB/ pull-in |
| `multi_hit_kb` | KB-vector richting fighter (trek) of weg | Hoeveelheid trek bepaalt of ze erin blijven |
| `finisher` | hit_data | Damage 6–15%, sterke KB |
| `armor`, `intangible` | specs | Meestal alleen eerste 1–6 frames |
| `momentum_end` | `keep_vertical`, `zero` | Na einde stijgen |
| `ledge_snap` | `during` of `end_only` | Melee-achtig: tijdens |
| `helpless_after` | true standaard | Zie overige |
| `landing_lag` | 8–30 | Lang bij misbruik |
| `ground_variant` | bool | Zelfde als lucht met korte versie, krijgt endlag |

**Randgevallen:**
- **Botsing met plafond/solide blokken:** stijgen stopt (`ceiling_policy`: `stop_rise` / `bonk`); fighter blijft niet vastzitten; geen "boven de stage" gat.
- **Tegenstander wordt weggeduwd of meegetrokken:** pushout van fighters; multi-hit trek-KB mag nooit de tegenstander door de vloer of de ledge teleporten.
- **Ledge tijdens stijgen:** `during` = grab toegestaan zodra fighter naast de ledge is en stijgt; bij `end_only` alleen na afloop. Voorkomt "ledge-fly-by" bij `during` niet te sterk te maken: alleen als fighter niet omhoog beweegt boven de hoogte (Melee-regel: stijgende fighters grijpen alleen onder een bepaalde y).
- **Shield:** meerdere hits op shield leveren shield-damage per hit; geen "shield stab" bug-gedrag, wel gewone shield pushback.
- **Geraakt worden tijdens rise:** afbreken en normaal geraakt (behalve armor/intangible).
- **Stage-rand:** x-beweging stopt niet; wel laatste hit blijft onaangetast.
- **Special fall** na het einde: helpless tot landen of ledge-grab; als je op een ledge belandt geen helpless.
- **Door-platforms:** fighter stijgt erdoorheen, daalt landt erop in helpless.
- **Zelf-trap:** de multi-hit raakt een tegenstander die op de ledge hangt: normaal behandelen (ledge-intangible ten opzichte van hits).
- Per airtime maar 1 keer (`air_use_limit=1`).

**Prijs-richtlijn:**
- **Snelheid:** startup tot eerste hit (≤ 6f = 5; 7–10 = 4; 11–16 = 3).
- **Kracht:** finisher + hit-som. Killend rond 100–120% = 3; rond 80% = 5. Veel hits met totaal damage 12–20% +1.
- **Bereik:** `rise_distance` + horizontale controle (80–120 u = 2, 121–180 = 3, 181+ = 4; `h_control=full` +1).
- **Veiligheid:** endlag + landing_lag + helpless. Meestal 1–2 (onveilig); intangible-start +1.
- **Utility (recovery):** distance ×; `ledge_snap=during` +1; `helpless_after=false` +2; armor/intangible per 4f +1 (max +3).
- Combinatie "recovery > 180u én hoge kracht én veilig" valt in utility 9–10 met kosten ≥ 20: bewust duur houden.

---

## 5. Counter (`counter`)

**Wat het doet:** de fighter neemt een houding aan; wordt hij in een venster geraakt, dan voert hij een tegenaanval uit (vaak sterker dan de oorspronkelijke klap, met niet-geblokkeerde damage).
*"Ik pareer elke aanval en sla terug." · "Als iemand me raakt, ontwijk ik en kontroleer."*

**Fases:**
1. Startup 5–15f (haltung).
2. **Counter-venster** actief `counter_window` 8–30f: elke hit in `accepts_hit_types` triggert de counter.
3. **Counter-aanval:** 10–25f startup-tot-hit bij trigger (later dan normaal; de vijand is in hitstun-vrij); hitbox 2–6 frames. Zonder trigger: endlag `whiff_endlag` 20–50f (lang, straf).
Grond en lucht: lucht-variant optioneel; lucht-counter geeft `helpless_on_hit_only`/geen helpless.

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `counter_window` | frames `[van, tot]` | Duur 8–30f, begin vroeg |
| `trigger_types` | set: `melee`, `projectile`, `grab`, `elemental` | Standaard `melee`+`projectile`; `grab` aan = mogelijk onrealistisch |
| `min_damage` | float 0–10% | Alleen counteren boven drempel |
| `counter_damage` | formule: `base + mult × damage_geraakt`, cap | Mult 1.0–1.5, cap 20–40% |
| `counter_kb` | angle/base/scaling | Vast of geschaald naar ontvangen KB |
| `facing_mode` | `to_attacker`, `fixed` | Draai naar aanvaller |
| `invincible_on_trigger` | frames | Korte intangible |
| `counter_cooldown` | int 0–180 | Optioneel; gebruik na trigger |
| `grounded_only` | bool | Alleen op de grond |
| `damage_taken` | `none`, `reduced`, `full` | Standaard `none` (de klap zelf doet geen schade) |
| `projectile_reflect_on_trigger` | bool | Projectiel reflecteren i.p.v. alleen counteren (raakt reflector-sjabloon) |
| `armor_vs_grab` | bool | |
| `air_use_limit` | `inf` / 1 | |

**Randgevallen:**
- **Multi-hit tijdens het venster:** counter triggert op de eerste hit; verdere hits van dezelfde attack worden genegeerd/gemist (`instance_id`) zodat er geen dubbele trigger is.
- **Projectielen:** toegestaan trigger geeft de counter richting eigenaar; als de eigenaar buiten bereik is, `miss`.
- **Grabs:** meeste counters werken niet tegen grabs → grab doorbreekt het venster; stel `trigger_types` expliciet in.
- **Meerdere aanvallers tegelijk (teams):** counter richt zich op de dichtstbijzijnde of laatste raker; hitboxen kiezen consequent.
- **Shield:** aanval op shield telt niet als trigger (fighter heeft geen shield tijdens counter).
- **Ledge/stage-rand:** counter voert geen beweging uit (geen valpartij) tenzij `counter_move` is gedefinieerd.
- **Cooldown + lucht:** `air_use_limit` verhindert spam in de lucht.
- **Gebroken counter:** aanvaller raakt een intangible-counter-hitbox die zijn sterkte omlaag duwt? Niet in v1.
- **Hitlag:** counter-trigger heeft eigen hitlag; beide fighters bevroren, daarna tegenaanval.
- Timing-verschil: counter-aanval moet op 60 Hz exact reproduceerbaar; vensters bevatten geen delta-afhankelijkheid.

**Prijs-richtlijn:**
- **Snelheid:** startup tot aanvang venster, niet de counter-aanval zelf. ≤ 6 = 5; 7–10 = 4; 11–15 = 3.
- **Kracht:** counter-damage/KB: `mult ≥ 1.4 / kill vanaf 100%` = 4–5, `mult 1.0` = 2–3.
- **Bereik:** hitbox van de tegenaanval (0–5) — groot/disjoint +1.
- **Veiligheid:** whiff-endlag: ≤ 25f = 4, 26–40 = 2–3, 41+ = 1. Als trigger → tegenaanval heeft weinig endlag, +1.
- **Utility:** 5–8. Venster lang (≥ 20f) +1; `trigger_types` incl. projectiel +1; air-counter +1; grab-immune venster +1.

---

## 6. Reflector (`reflector`)

**Wat het doet:** een hitbox/schild-vlak voor de fighter dat projectielen terugkaatst (en mogelijk melee duwt). Meestal geen melee-trigger.
*"Ik zet een spiegelschild op dat kogels terugkaatst." · "Ik zwaai een schild-ring die alles terugduwt."*

**Fases:**
1. Startup 3–10f.
2. **Reflect-actief** `reflect_frames` 8–40f: `reflect_box` actief.
3. Endlag 10–35f; vaak geen verplichte endlag bij annuleren.
Lucht: stationair in lucht, `gravity_scale` 0.8–1 tijdens move, of een kleine hop mogelijk.

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `reflect_box` | shape: offset/straal of rechthoek | Gewoonlijk groot voor de fighter, 30–70u |
| `reflect_window` | frames | Soms kortere kern dan zichtbare animatie |
| `damage_mult` | float 1.0–2.0 | Melee: ×1.5 |
| `speed_mult` | float 1.0–2.0 | Melee: +~1.0x–2x |
| `owner_swap` | bool | Standaard true; reflect maakt de nieuwe eigenaar de reflector |
| `reflect_melee_push` | bool + `push_kb` | Ook tegenstander wegduwen (hitbox) |
| `reflect_all_types` | bool | Alleen reflecteerbare projectielen |
| `reflect_limit` | per projectiel, bijv. max 3 keer heen en weer | Voorkomt eindeloze loops |
| `facing` | `front`/`both` | |
| `intangible_tail` | frames | Optioneel |
| `air_use_limit` | | |
| `cancel_window` | `shield`/`jump` | Mag vroeg stoppen? |

**Randgevallen:**
- **Niet-reflecteerbaar projectiel** (`reflectable=false`): box doet niets (of doet damage/hitlag?). Standaard: genegeerd, projectiel gaat door.
- **Projectiel dat de eigenaar zelf raakt na reflect:** eigenaar-swap voorkomt self-hit; projectiel verdwijnt bij `reflect_limit`.
- **Gelijktijdige reflect:** twee reflectors elk reflecteren hetzelfde projectiel: eerste in tick-volgorde wint, tweede ziet nieuwe eigenaar → terug naar de eerste; limiet stopt het.
- **Reflect op rand van stage:** projectiel keert om en verdwijnt bij blastzone.
- **Reflect van multi-hit projectiel:** elke hit-trigger reflect → het hele projectiel reflecteert.
- **Hits op de fighter:** reflect heeft geen hurtbox-bescherming tenzij `armor`/`intangible` gezet; melee raakt gewoon.
- **Hitlag:** reflect veroorzaakt kleine hitlag op het projectiel (niet op fighter).
- **Reflector + absorber samen:** niet; aparte sjablonen.
- **Eigen projectiel** reflect: negeren.

**Prijs-richtlijn:**
- **Snelheid:** 4–5 (startup ≤ 8f).
- **Kracht:** 0–2 zonder melee-push; met push 2–4.
- **Bereik:** `reflect_box` grootte: <35u = 1, 35–55 = 2, 56+ = 3–4; `both` facing +1.
- **Veiligheid:** endlag: ≤ 20f = 4; 21–30 = 3; 31+ = 2. Reflect-window lang + weinig endlag = 5.
- **Utility:** 4–6 voor standaard reflector; +1 per extra: `damage_mult ≥ 1.7`, `reflect_melee_push`, `speed_mult ≥ 1.7`. −1 als `reflect_limit=1`.

---

## 7. Command grab (`command_grab`)

**Wat het doet:** een grab-box die bij contact de tegenstander vastgrijpt en een vaste aanval of worp uitvoert; negeert shield.
*"Ik pak iemand en gooi hem weg." · "Ik trek iemand vlakbij, en sla hem kapot."*

**Fases (grond):**
1. Startup 8–25f.
2. **Grab-actief** 2–6f (grab-box).
3. Bij raak: **hold** `hold_frames` 6–40f (met optionele pummel); daarna **throw** (vaste KB).
4. Bij mis: endlag 20–50f (lang).
Lucht: lucht-command-grab bestaat; bij mislukken helpless/landing_lag. Bij raak in de lucht: ledge-regels (zie randgevallen).

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `grab_box` | shape + offset (u) | Bereik 20–70u; geen schade |
| `grab_active` | frames | |
| `grab_type` | `grounded_only`, `airborne_only`, `both` | Wie je kunt pakken |
| `ignores_shield` | bool | Standaard true |
| `vs_airborne` | bool | |
| `hold_action` | enum: `none`, `pummel`, `auto_hits`, `carry` | Wat gebeurt in hold |
| `pummel_hits` / `damage` | | |
| `throw` | hit_data (angle, KB, damage) | Vaste aanval |
| `throw_stick_directions` | optioneel 4 varianten | Zo wordt het meer dan één move |
| `breakout` | `none` / `mash` | Breakout-frames |
| `grab_release_ledge` | | |
| `hold_height` | | |
| `travel` | beweging tijdens startup | Kan combineren met command dash (§15) |
| `miss_endlag` | int | |
| `air_miss_helpless` | bool | |

**Randgevallen:**
- **Tegenstander in de lucht, ledge-hanger, op platform:** pakken alleen als `vs_airborne`/ledge expliciet. Ledge-hangende fighters zijn gewoonlijk niet grijpbaar tenzij `grab_ledge=true`.
- **Tegenstander in shield:** doorbreekt shield (shield schakelt uit, grab beweegt).
- **Tegenstander in invulnerability/intangible:** grab mist.
- **Grab-clank:** twee grab-boxen die gelijk raken: beide vallen terug in neutral-ish ("grab-trade" = beide mis).
- **Tegenstander gaat in `held`-state:** fighter krijgt hold-animatie en kan niet meer geraakt worden door derde partij tenzij teams.
- **Throw richting stage-rand/ muur:** KB wordt niet "geplakt"; normale botsing.
- **Throw uit de stage:** valide; mogelijk direct kill (`throw_kill`).
- **Eigen hit tijdens hold:** hold breekt als vasthouder geraakt wordt (alleen via teams/derde partij).
- **Armor/intangible**: grab-box heeft geen immuniteit, tenzij ingesteld.
- **Shield-grab-achtige onderbreking:** niet mogelijk tijdens de hold.

**Prijs-richtlijn:**
- **Snelheid:** startup: ≤ 9f = 5; 10–15 = 4; 16–22 = 3; 23+ = 2.
- **Kracht:** throw-kracht: kill rond 100% = 4; combo-startend/laag = 1–2; kill rond 70% = 5.
- **Bereik:** `grab_box` + travel: kort <30u = 1; 30–50 = 2; 51–70 = 3; met travel +1.
- **Veiligheid:** miss-endlag (command-grabs missen vaak): ≤ 25f = 4; 26–40 = 2; 41+ = 1.
- **Utility:** 4–6 (shield-breaker); +1 airborne-grab; +1 hold_action pummel; +2 lucht-variant die ook recovery is.

---

## 8. Dash-strike (`dash_strike`)

**Wat het doet:** de fighter schiet horizontaal met hoge snelheid vooruit en raakt onderweg of aan het eind; kan eindigen met een sterke klap.
*"Ik stoot vooruit met mijn schouder." · "Ik flits met een zwaard door de tegenstander heen."*

**Fases (grond):**
1. Startup 5–20f.
2. **Dash** `dash_frames` 6–25f: velocity `dash_speed` 2–8 u/f; actieve hitbox tijdens/aan eind.
3. Endlag 15–40f; wrijving/afremmen via `slide`.
Lucht: `momentum_air=scale`; dash blijft horizontaal (of gekozen hoek); `helpless_after` optioneel; `landing_lag` 10–25. Dash kan van de grond afkomen en eindigen in de lucht (`leave_ground`).

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `dash_speed` | float 2–8 u/f | |
| `dash_frames` | int 6–25 | Of `dash_distance` 60–250u |
| `dash_angle` | float −60..60° | + `stick_aim` |
| `ends_with` | enum: `stop`, `slide`, `finisher_hit` | |
| `hitbox_mode` | `during` (multi-hit door), `end_only`, `first_contact_stop` | Stopt dash als geraakt? |
| `passes_through` | bool | Dash ongehinderd door fighters (hit zonder stoppen) |
| `intangible` | tijdens dash | |
| `armor` | tijdens dash | |
| `cliff_stop` | bool | Stop aan stage-rand voor vallen |
| `ledge_snap` | `during` mogelijk |
| `slide_friction` | | |
| `air_use_limit` | | |
| `helpless_after_air` | | |

**Randgevallen:**
- **Rand van stage (grond):** `cliff_stop=false` = fighter glijdt van de stage af en gaat in de lucht (geen helpless); `true` stopt vóór rand.
- **Wall:** dash stopt bij solide muur, geen clip.
- **Botsing met fighter:** `passes_through=false` → stopt bij contact, hit; `true` → doorgaan, dan hitbox kan dezelfde fighter niet 2× raken (`hit_once_per_target`).
- **Shield geraakt:** pushback/stun; dash stopt tenzij `passes_through`.
- **Platforms:** op de grond stoppen niet bij door-platforms.
- **Lucht-start:** `gravity_scale` 0–1 voor de dash (hoogte behouden) om de ledge te bereiken.
- **Geraakt tijdens dash:** onderbroken tenzij armor/intangible.
- **Projectielen:** dash in projectiel → normale hit (of reflecteert/absorb bij speciale vorm).
- **Combo met meerdere dash-strikes na elkaar** begrensd via `air_use_limit`.
- Stop op de ledge-snap: dash stopt als fighter de ledge grabt.

**Prijs-richtlijn:**
- **Snelheid:** startup tot eerste actieve frame.
- **Kracht:** hit(s) en finisher.
- **Bereik:** `dash_distance`: <70u = 1, 70–120 = 2, 121–180 = 3, 181–240 = 4, 241+ = 5.
- **Veiligheid:** endlag + of de move on-shield safe is (pushback-verhouding). Lange `slide` helpt niet; `hit_once` zonder pushback, ≤ 25f = 4.
- **Utility:** 3–5 als aanvalstool; 6–8 als recovery-dash (lucht, `gravity_scale` laag, `distance` ≥ 150u, `ledge_snap`). `passes_through` +1; intangible/armor +1 per 5f (max +3).

---

## 9. Stall-then-fall (`stall_fall`)

**Wat het doet:** de fighter blijft in de lucht hangen of zakt langzaam (stall) en valt daarna snel met een aanval; ook een mid-air dive of hop-plus-slam.
*"Ik zweef even en laat me dan vallen met een klap." · "Ik spring omhoog en sla recht naar beneden."*

**Fases (lucht):**
1. Startup 5–15f.
2. **Stall** `stall_frames` 10–50f: `gravity_scale` 0–0.2, snelheid x vast of door stick.
3. **Fall** `fall_speed` 3–6 u/f naar beneden (of schuin): hitbox actief (`fall_hitbox`).
4. **Landing:** bij landen eigen landing-hitbox (shockwave) en `landing_lag` 10–30f; als de speler de vloer niet raakt blijft hij in de val tot actie.
Grond: grondvariant = hop (`ground_hop` voor de stall) of niet toegestaan.

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `stall_frames` | int 10–50 | |
| `stall_gravity` | float 0–0.2 | |
| `stall_hitbox` | `none`/hit_data | Optioneel tijdens stall |
| `stall_h_control` | `none/x_only/full` | |
| `fall_trigger` | enum: `auto`, `button_release`, `stick_down` | Spelerscontrole |
| `fall_speed` | float 3–6 u/f | |
| `fall_direction` | `down` / `angled` + hoek | |
| `landing_hitbox` | hit_data | Shockwave op landing |
| `landing_lag` | int 10–30 | |
| `fall_end_action` | `landing` / `bounce` (springt terug) | |
| `ledge_snap` | `none` meestal | |
| `armor_in_fall` | | |
| `air_use_limit` | 1 | |
| `can_cancel_fall` | bool | Afbreken in de val mogelijk |

**Randgevallen:**
- **Landen op door-platform:** val stopt op platform; door-platform door stick? `fall_through_platform=false` standaard.
- **Val van de stage af:** niets landt, de val gaat door tot actie/blastzone (spike-gevaar voor eigenaar); `fall_to_death_protection` niet — speler moet oppassen.
- **Hit tijdens stall:** onderbreekt; krijgt stall-bevriezing niet.
- **Landing-lag en L-cancel:** landing_lag is vast; geen L-cancel op specials.
- **Combineren met multi-jump:** stall niet hergebruiken na val (`air_use_limit`).
- **Hit tijdens val:** zelfde.
- **Ledge:** grijpen niet toegestaan tijdens val (`none`), wel na stall.
- **Raken van tegenstander tijdens val:** bounce/stop? `hitbox_mode`: `pierce` (doorvallen) of `stop_on_hit` (hitlag, dan landing-lag minder).
- **Fast-fall interactie:** de val is vast; fast fall wordt niet bovenop gestapeld.
- **Stage-rand onder:** plek met blastzone onder (diepe val) — val stopt niet.

**Prijs-richtlijn:**
- **Snelheid:** 2–4 (stall maakt traag), snelle variant 4–5.
- **Kracht:** landing-/val-hit (meteoor spike) 3–5; geen hit 0.
- **Bereik:** stall+val-pad vs. tegenstanders; 2–3 standaard.
- **Veiligheid:** landing_lag + onderdeel stall vulnerable. 2–3 meestal; mits `armor_in_fall` +1.
- **Utility:** 3–5 als aanval; 5–7 als recovery (stall behoudt hoogte, `stall_h_control=full` +1). `fall_trigger=button_release` +1.

---

## 10. Multi-jump recovery (`multi_jump`)

**Wat het doet:** extra sprongen, flaps, hover of glijdt in de lucht om te herstellen. Meestal geen hitbox; puur recovery.
*"Ik klapwiek met vleugels om terug te komen." · "Ik kan drie keer extra springen." · "Ik zweef langzaam naar de stage."*

**Varianten:**
- **flap:** één extra sprong met (`flap_power`, `h_drift`) per gebruik.
- **hover:** gedurende `hover_frames` de val vertragen (`hover_gravity_scale` 0–0.3).
- **glide:** horizontale vlucht met glide-profiel `glide_fall_speed` 0.3–1.0, `glide_h_speed` 1–3.

**Fases (flap):** startup 3–6f (sprongfase), actief `flap_frames` 8–20f (velocity omhoog + drift), eindig → normale val met gelimiteerde actie; geen helpless.

**Instellingen:**
| Instelling | Type / bereik | Opmerking |
|---|---|---|
| `kind` | `flap`, `hover`, `glide` | |
| `count` | int 1–6 | Aantal flaps per airtime (reset bij landen) |
| `flap_power` | float 1.5–4 u/f initieel | Per flap kan dalen (`power_decay` 0–50%) |
| `h_drift` | float 0.5–2 | |
| `hover_frames` | int 20–180 | Of `hover_energy` (verbruikt per frame) |
| `glide_*` | | |
| `cooldown_between` | frames 0–12 | |
| `uses_special_button` | bool | Of via jump-knop (extra jumps uit `docs/balans.md` §2 zijn al een aanvulling) |
| `helpless_after` | false standaard | |
| `can_attack_during` | bool | Aanvallen tijdens hover/glide |
| `ledge_snap` | `during` | |
| `resets_on` | landing/ledge/hit | Gewoon |
| `air_use_limit` | = `count` | |

**Randgevallen:**
- **Overlap met extra midair jumps** uit balans.md: dezelfde `count`-mechaniek; kies de ene, niet beide voor dezelfde actie. Zet `uses_special_button=true` om het special-flap te maken.
- **Hit tijdens flap:** onderbreekt; resterende flaps blijven.
- **Hover + fast-fall:** fast-fall breekt hover.
- **Ledge:** grijpen mogelijk zodra in snap-range; hover raakt ledge-hang uit.
- **Plafond:** stoppen.
- **Platforms:** doorheen omhoog, aan de bovenkant landen.
- **Hover-energie** resettend bij landing/hit? `resets_on` instelling.
- **Glide + muren:** fighter botst en valt; geen wall-climb tenzij `wall_cling`.

**Prijs-richtlijn:**
- **Snelheid:** 5 (meestal direct); meerdere flaps benadrukken geen snelheid.
- **Kracht:** 0.
- **Bereik:** totale `count × flap_power`-reikwijdte: 1 flap = 1–2; 3–4 flaps = 3–4; hover groot = 4–5.
- **Veiligheid:** niet helpless + weinig endlag = 5.
- **Utility:** per extra flap +2 (consistent met −15 pt voor een extra jump in balans.md); hover 6–8; glide 6–7; `can_attack_during` +1. Een `flap`-special met 1 flap is gelijk aan extra jump (−15) en moet dezelfde prijs hebben.

---

## 11. Tether / grapple (`tether`)

**Wat het doet:** schiet een haak/draad die een ledge, platform of tegenstander vastgrijpt en trekt de fighter (of tegenstander) erheen.
*"Ik gooi een touw en trek mezelf omhoog." · "Ik haak een tegenstander en trek hem naar me toe."*

**Fases:**
1. Startup 8–18f.
2. **Extend:** haak vliegt `tether_speed` 5–15 u/f naar `max_length` 50–300u in `tether_angle`; hitbox op de haak optioneel.
3. **Latch:** bij contact met `anchor_types` (ledge, solide wand, platform-onderkant, fighter) kloppen; 2–6f.
4. **Pull:** fighter naar anker (`pull_mode`: `self`, `opponent`, `both`) met `pull_speed` 2–10 u/f of tot-contact.
5. Endlag 10–30f; bij mis lange endlag 25–45f + `helpless_after` (lucht, mis).

**Instellingen:**
| Instelling | Type / bereik |
|---|---|
| `max_length` | 40–300 u |
| `extend_speed` | 5–15 u/f |
| `angle` | vast of stick (`aim_mode`) |
| `anchor_types` | set |
| `pull_mode` | `self`/`opponent`/`both` |
| `pull_speed` | |
| `hold_swing` | optioneel pendelbeweging na vasthaken |
| `ledge_only` | bool (klassieke tether-recovery) |
| `tether_ledge_limit` | int; Melee-achtig: beperk herhaald hangen |
| `hit_on_hook` | hit_data |
| `release_action` | `drop`, `jump_from`, `throw` |
| `miss_endlag`, `helpless_on_miss` | |
| `cancel_on_hit` | |
| `air_use_limit` | |

**Randgevallen:**
- **Ledge bezet:** haak grijpt niet of grijpt gewoon (en duwt de ander eraf?): v1: grijpt niet — haakt wel aan wand (`ledge_occupied`: `fail`).
- **Ledge-tether-limiet:** herhaaldelijk tethers aan dezelfde ledge verlagen/ontnemen de intangible (Melee-regel: ledge-grab-limiet na N keer). Hergebruik het gedeelde ledge-systeem.
- **Muren:** haakt aan wand en trekt; geen glitch door tegelnaad.
- **Platforms:** onderkant alleen als `anchor_types` bevat `platform_underside`.
- **Pull verhindert door obstakel:** pull stopt bij botsing.
- **Pull van tegenstander:** botsing met stage; vloer wordt gerespecteerd; geen clip.
- **Geraakt worden tijdens extend/pull:** afbreken, tether weg.
- **Meerdere tethers:** `max_alive=1` per fighter.
- **Tegenstander in shield of intangible:** mislukt.
- **Stage-rand/blastzone:** haak eindigt bij `max_length`; verdwijnt buiten blastzone.
- **Pull naar boven:** bij einde pull y-speed behouden of nul (`momentum_after`).

**Prijs-richtlijn:**
- **Snelheid:** startup tot haak verschijnt.
- **Kracht:** hit_on_hook 0–2, pull-opponent damage 2–6.
- **Bereik:** `max_length`: <80u = 1–2; 80–150 = 3; 150–220 = 4; 221+ = 5.
- **Veiligheid:** miss-endlag + helpless op mis: 1–2; ledge-only tether (pakt altijd) 3–4.
- **Utility:** `ledge_only` recovery 5–7; free-aim anker 8–9; `pull_opponent` combo-/neutral-tool 4–6. Per extra anker-type +1.

---

## 12. Absorber (`absorber`)

**Wat het doet:** een veld/houding die projectielen opneemt. Absorbeert en geeft de fighter iets terug (genezing, charge, buff).
*"Ik absorbeer kogels en word er sterker van." · "Ik zuig energie op en genees mezelf."*

**Fases:** startup 4–12f; **absorb-actief** `absorb_frames` 10–40f; endlag 10–35f. Lucht: stationair met gravity 1.

**Instellingen:**
| Instelling | Type / bereik |
|---|---|
| `absorb_box` | shape |
| `absorb_types` | `projectile`, `elemental`, `melee_hit_contrib` |
| `gain` | `heal` (damage −= x), `charge` (vult sjabloon-charge), `buff` (tijdelijke boost), `meter` |
| `gain_formula` | `damage_projectile × mult`, cap |
| `max_heal_per_use` | 0–25% |
| `max_absorbs` | per gebruik |
| `overflow` | `waste`/`damage` |
| `buff_link` | verwijst naar transform-buff (§14) |
| `cooldown_after` | |

**Randgevallen:**
- **Niet-absorbeerbare projectielen:** `absorbable=false` → genegeerd of vernietigd? Standaard: genegeerd.
- **Heal onder 0%:** damage minimaal 0.
- **Bij buff-stapeling:** volgens transform-buff `stack_rule`.
- **Absorber vs reflector:** eerste in volgorde wint; vermijd door scene order.
- **Fighter geraakt:** absorb heeft geen melee-bescherming tenzij `armor`.
- **Meerdere projectielen tegelijk:** elk afzonderlijk; `max_absorbs` limiteert.
- **Multi-hit projectielen:** één keer absorberen, hele projectiel weg.
- **Dood:** buff vervalt bij respawn.
- **Misbruik healen:** `heal_cap_per_stock` om infinite stalling te voorkomen.

**Prijs-richtlijn:**
- **Snelheid:** 4–5.
- **Kracht:** 0 (+ buff kan boost).
- **Bereik:** `absorb_box` 1–3.
- **Veiligheid:** endlag; 3–4.
- **Utility:** 3–6; heal ≥ 8% per absorb +2; buff koppeling +1; absorb melee +2 (dan is het een counter-achtige).

---

## 13. Trap / mine (`trap`)

**Wat het doet:** legt een object op de grond/in de lucht dat later activeert (bij aanraking of na timer). Wordt bijgehouden per fighter.
*"Ik leg een mijn." · "Ik plaats een val die ontploft als iemand erop stapt." · "Ik laat een bom vallen."*

**Fases:** startup 8–20f; **place** (spawn); endlag 15–35f. De trap leeft los: `arm_time` 0–90f, dan actief tot `lifetime` of trigger; activatie → hitbox 2–10f.

**Instellingen:**
| Instelling | Type / bereik |
|---|---|
| `place_offset` | Vector2 |
| `place_mode` | `drop` (valt), `stick` (blijft op plek), `throw_arc` |
| `size` | |
| `arm_time` | 0–90f |
| `trigger` | `contact_enemy`, `timer`, `owner_signal` (herhaal knop), `proximity` |
| `trigger_radius` | |
| `lifetime` | 120–900f of `inf` |
| `max_alive` | 1–4 + `on_cap` |
| `visible_to_enemy` | bool (altijd true voor eerlijkheid) |
| `explode_hit` | hit_data (damage 8–25%, KB, eventueel `hit_once`) |
| `knockable_by_enemy` | bool, hp |
| `owner_can_trigger` | bool |
| `stage_stick` | `floor`, `walls`, `ceiling`, `any` |

**Randgevallen:**
- **Plaatsen in solide blok:** `fizzle`/`shift`; plaatsen midden in de lucht → valt (drop).
- **Plaatsen op het podium dat later verdwijnt:** trap valt mee of vervalt.
- **Trap + tegenstander-spawn (respawn-platform):** trap negeert respawn-invincibility; niet triggeren.
- **Reflect/absorb van de explosie:** de explosie is een projectiel-achtige hitbox (`reflectable` standaard false).
- **Meerdere traps:** chain-reaction aan of uit (`chain`).
- **Cap:** `max_alive` hanteren; oudste verwijderen is standaard bij `replace`.
- **Dood eigenaar:** traps blijven, of opruimen (`clear_on_owner_death` standaard true).
- **Trap onder door-platform:** blijft op platform of valt door? Specificeren: stick op platform-bovenkant.
- **Ledge:** traps plaatsen op de ledge? Alleen op solide oppervlak.
- **Triggeren door eigen fighter of teamgenoot:** instelbaar.
- **Tegenstander ontwijkt via intangible:** geen trigger tijdens intangible.
- **Performance/spam:** hard cap totaal 8 per match-slot.

**Prijs-richtlijn:**
- **Snelheid:** 3–5.
- **Kracht:** explosie 2–4.
- **Bereik:** zone-vorm en ontwijkbaarheid. Zichtbare, kleine trap = 1–2; sterk zonegebied = 3.
- **Veiligheid:** endlag + gebruiksspam. 3–4.
- **Utility:** 4–6; `max_alive>1` +1; `owner_signal` +1; `place_mode=stick` op muur/plafond +1; onzichtbaar mag niet (v1).

---

## 14. Transform-buff (`buff`)

**Wat het doet:** verandert tijdelijk de stats of regels van de fighter (sneller, sterker, zwaarder, andere normals, lucht-bonus) of wisselt van modus.
*"Ik word een reus en sla harder." · "Ik laad op en ben tijdelijk veel sneller." · "Ik wissel tussen zwaard en geweer."*

**Fases:** startup 10–30f; **transform** 5–15f (geen controle, mogelijk intangible); buff-duur `duration` 180–900f of tot geraakt; endlag 10–25f. Wisselen terug: automatisch of via zelfde special.

**Instellingen:**
| Instelling | Type / bereik |
|---|---|
| `duration` | frames of `until_hit`/`until_stock_lost` |
| `modifiers` | map: `walk_speed_mult`, `run_speed_mult`, `air_speed_mult`, `jump_height_mult`, `weight_mult`, `damage_dealt_mult`, `kb_dealt_mult`, `damage_taken_mult`, `fall_speed_mult`, `attack_speed_mult`; elk 0.6–1.6 |
| `move_swap` | verwijst naar alternatieve MoveData (andere normals) |
| `trade_off` | modificators die ook nadelen (bijv. langzamer) |
| `stack_rule` | `refresh`, `stack_max N`, `block` |
| `cooldown` | frames 0–1800 |
| `use_limit_per_stock` | int |
| `end_lag_on_expire` | frames |
| `armor_during` | |
| `meter_based` | bool (gedurende `meter_cost`) |
| `reverts_on_death` | true |
| `visual_state` | verplicht (tegenstander ziet buff) |

**Randgevallen:**
- **Buff + hitlag:** duur loopt niet door tijdens hitlag, of wel? Kies `tick_during_hitlag=false`.
- **Modificator-stapeling met archetype-stats en andere buffs:** vaste volgorde: base → archetype → buff.
- **Move-swap tijdens move:** wisselen pas bij neutral of na de move.
- **Dood / respawn:** buff weg.
- **Gewicht-wijziging en KB/damage-berekening:** gebruikt effectieve waarde per hit-moment.
- **Hitbox-schaal:** `size_mult` verandert hurtbox; check ledge/platform-clipping bij groeien.
- **Aan de rand/ledge:** vergroting botst met solide blok; fighter wordt uitgeduwd, geen clip.
- **Cooldown na einde of per stock:** zichtbaar in HUD.
- **Netto-zwaar combinatie:** bovengrens van de totale modificator-som door validator.

**Prijs-richtlijn:**
- Geen directe assen; waarde = bonus × duur − kosten. **Utility** 3–8:
  - +20% snelheid, 10 s = 3; +30% damage/KB, 10 s = 5; armor tijdens duur = +2.
  - Nadeel (`damage_taken_mult>1`, `weight_mult<1`) geeft punten terug (1 punt per 10% nadeel).
- **Snelheid** van de startup: 3–4 (traag); **Veiligheid** 2–3 (lange startup);
- **Kracht/Bereik** 0 voor de special zelf; maar bonussen op andere moves worden meegeprijsd in **die** moves of in utility (vuistregel: elke +10% op alle moves = +1 utility).
- Cooldown ≥ 600f: −1 utility; use_limit_per_stock=1: −1.

---

## 15. Command dash met follow-up (`command_dash`)

**Wat het doet:** een korte, snelle reposition (dash, hop, slide, spring terug) waarna de speler kiest uit follow-ups (aanval, grab, cancel, nogmaals gebruiken).
*"Ik schiet naar voren en kan dan slaan of pakken." · "Ik glij weg en kom tegen de muur terug."*

**Fases:**
1. Startup 4–12f.
2. **Move** `move_frames` 8–20f, velocity vast (of stick), geen of een lichte hitbox.
3. **Follow-up window** `window` 6–20f: input bepaalt `follow_up`: `A` (aanval), `grab`, `special` (zelfde sjabloon), `none` → endlag.
4. Follow-up fases: ieder een eigen mini-move (hit_data).
5. Endlag 15–30f; lucht: `helpless_after` optioneel.
Grond: hop/slide; lucht: kan gravity_scale en momentum overschrijven.

**Instellingen:**
| Instelling | Type / bereik |
|---|---|
| `move_kind` | `dash`, `hop`, `slide`, `backstep` |
| `distance` / `speed` | 40–180 u |
| `direction` | `forward`/`back`/`stick` |
| `follow_ups` | lijst `{input, move}` |
| `window` | frames |
| `default_follow_up` | geen / auto |
| `cancel_on_follow_up` | bool |
| `invincible` | tijdens move |
| `chain_limit` | int 1–3 |
| `air_use_limit` | |
| `ledge_snap` | `end_only` |
| `cliff_stop` | |

**Randgevallen:**
- **Input-buffer:** follow-up input buffer 2–6f om “drukken net voor het venster” toe te laten.
- **Window wordt niet geannuleerd door hit op tegenstander (hitlag):** window bevriest tijdens hitlag.
- **Follow-up onmogelijk (lucht/ledge):** terugval op `none`.
- **Chain-limiet** per airtime.
- **Rand van stage:** cliff-stop als `cliff_stop`.
- **Direction flip:** facing wisselt na move bij `backstep`.
- **Follow-up als eigen special-sjabloon** (bijv. command grab): sjabloon-instellingen bij follow-up volgen dat sjabloon.

**Prijs-richtlijn:**
- Som van move + follow-ups: elke follow-up wordt als eigen (kleine) move geprijsd, plus de basis (utility 2–4).
- **Snelheid** van het totaal = startup tot eerste hit/actie; **Veiligheid** baat bij `invincible` en korte endlag.
- Meer opties = hogere **utility** (+1 per follow-up, max +3); `chain_limit>1` +1.

---

## 16. Spin / tornado (`spin`)

**Wat het doet:** de fighter draait/wervelt met meerdere hits rondom zich; kan grond of lucht, met optionele horizontale of verticale beweging en `lift`.
*"Ik draai als een tornado en kom omhoog." · "Ik spin rond en sla iedereen om me heen."*

**Fases:**
1. Startup 3–12f.
2. **Spin-loop** `spin_frames` 15–90f: multi-hit hitbox rond (`hit_every` 3–8f), optionele beweging.
3. Slot: eindhit (sterk) 3–5f.
4. Endlag 15–35f.
Lucht: optionele `rise_speed` (zie §4), `h_control`; `helpless_after` true; grond: draai kan schuiven.

**Instellingen:**
| Instelling | Type / bereik |
|---|---|
| `spin_frames` | 15–90 |
| `hit_every` / `hits` | |
| `radius` | 20–70u |
| `h_speed` | 0–3 u/f (`stick_control`) |
| `rise_speed` | 0–2.5 u/f optioneel |
| `pull_in` | KB-vector naar spinner |
| `ender_hit` | hit_data |
| `loop_extend` | knop herhalen = extra loop? `hold_extend` 0–3 loops |
| `armor/intangible` | |
| `ground_slide_friction` | |
| `landing_lag` | |

**Randgevallen:**
- **Multi-hit op shield**: shield-damage per hit; geen shield-poke exploit.
- **Meerdere tegenstanders (teams)**: elke fighter eigen `hit_once_per_interval`.
- **Ledge:** aanvallende fighter mag ledge grabben `during` of `end_only`.
- **Land/uit-lucht wisselen midden in spin:** grond ↔ lucht-modus consistent; velocity wordt hergeschaald.
- **Pull-in botst met muur**: ten opzichte van muur gestopt.
- **Rise + plafond:** zie §4.
- **Hold-extend:** maximaal aantal loops.
- **Geraakt worden:** afbreken tenzij armor.

**Prijs-richtlijn:**
- Zoals §4 voor rise (bereik/utility). Pure draaiende ring (geen rise): Bereik 3–4 (radius), Kracht 2–3, Veiligheid 2–3, Utility 3–4. Met `rise`: utility 6–8 als recovery. `hold_extend` +1.

---

## 17. Gedeelde bouwsteen: "armor/intangible-move" (modifier, geen eigen sjabloon)
Armor of invincibility kunnen aan elke special hangen via 0.4. Prijs: armor 8–12% drempel over ≥ 8f = +2 utility; intangible per 4f = +1 (max +3).

---

# Beslisboom: van omschrijving naar sjabloon

Doorloop in volgorde; de eerste die klopt, wint. Combineer waar nodig (bijv. "laad een vuurbal op" = `charge` → `projectile`).

1. **Er komt iets los dat zelfstandig vliegt/ligt?**
   - Vliegt weg in een richting → `projectile` (hoek/bocht/stuiter/meerdere = instellingen).
   - Blijft liggen en gaat later af → `trap`.
   - Is een haak/draad die iets vastgrijpt en trekt → `tether`.
2. **Moet de speler lang indrukken voor meer kracht?** → wikkel in `charge` om het gevonden sjabloon.
3. **Verandert de plek zonder tussenliggende beweging (verdwijnen/verschijnen)?** → `teleport`.
4. **Beweegt de fighter zelf, en met welk doel?**
   - Horizontaal vooruit op snelheid → `dash_strike` (met vervolg: `command_dash`).
   - Omhoog/schuin omhoog met meerdere hits → `rising_multi`; draaiend rondom → `spin`.
   - Blijft hangen en valt daarna → `stall_fall`.
   - Extra sprongen/zweven/glijden → `multi_jump`.
5. **Reageert de special op wat de tegenstander doet?**
   - Slaat terug na een klap → `counter`.
   - Kaatst projectielen terug → `reflector`.
   - Neemt projectielen op en krijgt er iets van → `absorber`.
6. **Pakt de special de tegenstander vast?** → `command_grab`.
7. **Verandert de fighter tijdelijk (stats/modus)?** → `buff`.
8. **Past het in meer dan één?** Pak het primaire (wat de speler als *doel* noemt) en gebruik het tweede als:
   - instelling (bijv. `armor`, `hit_data` op de dash),
   - `follow_up` (command_dash),
   - of `charge`/`buff`-wikkel.

**Wanneer wordt het eigen code?** Als minstens één klopt:
- de special **wijzigt een regel** van het spel (bijv. omwisselen van plaats met de tegenstander, tijd vertragen, stage veranderen);
- een **nieuw object met eigen gedrag** (AI-companion, schip dat de speler bestuurt, bewegende platforms);
- **de besturing wordt tijdelijk anders** (speler stuurt een projectiel met de stick, tweede lichaam);
- **meer dan twee sjablonen** moeten diep met elkaar verweven worden, en `follow_up`/wikkelen schiet tekort;
- de gewenste waarde valt buiten alle **bereiken** hierboven (bijv. teleporteert 600 u).
Dan: eerst eerlijk zeggen tegen de speler, nabije sjabloon-variant voorstellen, en anders `special-builder` met alleen de bouwstenen uit de volgende sectie.

Een vuistregel: kan de speler het in één zin zeggen zonder het woord "terwijl", dan past het meestal in één sjabloon. "Terwijl" wijst op combinatie of eigen code.

---

# Benodigde engine-bouwstenen

Dit is wat de engine gedeeld moet bieden zodat bovenstaande sjablonen configuratie zijn. Voor M3–M5. Beschrijft wát, niet hoe.

1. **Move-runner / fase-machine voor specials** — frame-teller per fase, fases uit data (`startup`, `loop`, `active`, `end`, `window`), vroege overgangen (cancel), grond- en lucht-varianten van dezelfde special, hitlag-bevriezing van de timer.
2. **Hitbox spawnen per frame** — data-gedreven lijst hitboxes (vorm, offset, straal, frame-venster, damage, hoek, base/scaling KB, hitlag, element, `hit_once_per_target`, `multi_hit interval`, `disjoint`, `clank`, `shield_damage`). Dezelfde bouwsteen als normals.
3. **Velocity zetten / schalen / vastzetten** — directe set van x/y, schalen van huidige velocity, `gravity_scale`, vaste lengte-beweging (`distance`), richting uit stick of vast; wrijving/afremmen; momentum behouden of nul.
4. **Stick-aim helper** — gekwantiseerde stick (uit M0) omzetten naar vaste N-richtingen of een vrije hoek, met deadzone-standaardrichting en maximale stuurhoek.
5. **Projectiel-entity** — eigen entiteit met owner, hitbox, beweging (rechte lijn, boog, stuiter), lifetime/max-range, size, max-alive per owner, transcendent, reflect/absorb-vlaggen, pierce/multi-hit, opruimen bij dood/stock-verlies, spawn-validatie tegen solide blokken.
6. **Projectiel-interacties** — clank-regel tussen projectielen (damage-vergelijking), reflect (eigenaar wisselen, damage/snelheid-multiplier, reflect-limiet), absorb (verwijderen + callback), shield-raak.
7. **Armor-venster** — drempelwaarde per frame-venster, hitlag-zonder-KB, grab-negeren-optie, gebroken armor bij hoge damage.
8. **Intangibility-/invincibility-venster** — hurtbox uit, per lichaamsdeel, los van ledge-intangibility en respawn-invincibility.
9. **Counter-window** — hit-intercept dat vóór damage/KB-toepassing ingrijpt, `instance_id` zodat multi-hits één keer triggeren, damage/KB van de geraakte hit beschikbaar voor de tegenactie, `trigger_types` filter.
10. **Reflect-box** — gebied met venster, reflecteert/duwt entities en eigenaar-swap; zelfde infrastructuur als hitbox maar met "entity-effect".
11. **Absorb-box** — gebied dat entities consumeert en een effect aanroept (heal, charge, buff).
12. **Grab-box / grab-state** — grijpen met shield-negatie, `held` state voor slachtoffer (geen hurtbox/controle), release en throw met vaste KB, breakout-optie, ledge/airborne-regels, grab-clank.
13. **Helpless-state (special fall)** — alleen driften, geen acties, geen jump, landing_lag; opheffen bij grond, ledge-grab, respawn of geraakt worden; per special in/uitschakelbaar.
14. **Ledge-snap-hook** — door elke special aan/uit te zetten per fase, met bereik, ledge-bezet-check, de gedeelde ledge-grab-limiet (herhaald grijpen) en de Melee-regels voor stijgende fighters.
15. **Per-airtime-limieten** — tellers per fighter per special-slot; reset-gebeurtenissen (landen, ledge-grab, hit/geraakt, respawn, wall-jump indien relevant); uitleesbaar voor HUD/AI.
16. **Teleport-/reposition-service** — positie verplaatsen langs een lijn met botsing tegen solide blokken (`shorten`/`snap_to_valid`/`fizzle`), blastzone-regels, platform-regels, overlap-pushout.
17. **Charge-systeem** — knop-houd-state, minimum/maximum, stage-interpolatie, bewaar-opties, visuele/auditieve staten, koppeling aan projectiel/hit/buff-schaal.
18. **Trap-/persistente-entity-systeem** — owner, arm-timer, trigger-types (contact/proximity/timer/signaal), cap per owner en globaal, opruimen.
19. **Tether-/anker-systeem** — raycast of bewegende haak, anker-typen, pull-beweging (zelf/tegenstander), ledge-bezet-regel, ledge-grab-limiet.
20. **Stat-modifier-systeem (buff)** — gelaagde multipliers (base → archetype → buff), duur/cooldown/stack-regels, move-swap, reset bij dood, HUD-indicator.
21. **Follow-up/input-window** — keuzevenster met input-buffer, bevriezing in hitlag, terugval-regels.
22. **Gedeelde landing-afhandeling** — landing_lag vast per special, landings-hitbox, platform-doorval-regels, “land tijdens fase X”.
23. **Cancel-systeem** — vroegtijdig stoppen naar shield/jump/idle in een venster, met bewaar-regels (charge).
24. **Eigenaar-/identiteit-model** — per fighter-slot een id; hitboxen, projectielen, traps, tethers verwijzen ernaar (voor friendly-fire, reflect-swap, opruimen).
25. **Deterministische RNG + vaste update-volgorde** voor entities (spawn, collision, reflect).
26. **Validator-uitbreidingen** — leest sjabloon-configuratie: bereikcontrole (vensters/frames), puntenberekening uit de formules hierboven, sanity-tests (recovery aanwezig, geen oneindige loops, geen clip in stage-geometrie), simulatietest per sjabloon (spawn, whiff, hit, shield, ledge).
27. **Debug/oefenstand-weergave** — hitbox/reflect/absorb/grab-boxen, armor/intangible-balkjes, per-airtime-teller en entity-lijst in de debug-overlay en training mode.
28. **Presentatie-haken** — `anim_tag`, vfx/sfx per fase, verplichte telegraaf voor charge/buff/trap (leesbaarheid voor de tegenstander).

---

# Open vragen voor de director
1. Mogen specials **buiten de 4 slots** meer dan één sjabloon combineren (bv. `charge` + `projectile` + `buff`), en hoeveel telt dat voor de prijs?
2. Is **teleport door stage-geometrie** standaard toegestaan? Houden we een globale cap `distance ≤ 260u`?
3. **Eerlijkheidsregels**: onzichtbare traps verbieden (voorstel: verplicht zichtbaar), en een verplicht **telegraaf**-venster per charge/buff?
4. **Helpless:** standaard aan voor alle luchtrecoveries? Prijs van `helpless_after=false` (voorstel +2 utility) akkoord?
5. **Ledge-regels:** nemen we Melee's ledge-grab-limiet en bezette-ledge-gedrag 1-op-1 over (in movement.md), en geldt dat ook voor tethers?
6. **Counter:** mogen counters tegen **grabs** en **projectielen** werken? (Voorstel: projectielen ja, grabs nee.)
7. **Prijsijking:** moeten specials dezelfde "som van assen"-formule gebruiken als normals, of een apart utility-budget?
8. **Teams/2v2**: bestaat het in v1? Beïnvloedt friendly-fire, reflect en absorb. Voorstel: v1 alleen 1v1.
9. **Buff:** is het toegestaan om normals te wisselen (move-swap) binnen een sjabloon, of is dat altijd eigen code?
10. **Spel-regels** voor `air_use_limit`-reset: ook na wall-jump / bij ledge-grab, en na geraakt worden (Melee: ja)?

---

## Besluiten van de director (2026-10-08)
Deze besluiten gaan vóór wat hierboven als open vraag staat.

1. **Combineren:** een special mag maximaal **2 sjablonen** combineren (bv. `charge` + `projectile`). Prijs = som van de assen van het resultaat, +2 utility voor de combinatie.
2. **Teleport door geometrie:** toegestaan (zoals in Melee). Globale cap 260 units afstand; tunen in M5.
3. **Eerlijkheid:** onzichtbare traps zijn verboden. `charge`, `buff` en `trap` hebben altijd een zichtbare telegraaf.
4. **Helpless:** standaard **aan** bij recoveries in de lucht. `helpless_after = false` kost +2 utility.
5. **Ledges:** Melee-regels 1-op-1 (grab-limiet, bezette ledge, regrab-invincibility), ook voor tethers.
6. **Counters:** werken tegen projectielen, niet tegen grabs.
7. **Prijs:** specials gebruiken dezelfde som-van-assen als normals, plus de aparte utility-as (0–10).
8. **Modus:** v1 is alleen **1v1**. Geen teams, dus geen friendly fire.
9. **Move-swap in `buff`:** toegestaan als de vervangende moves zelf data of sjablonen zijn; anders eigen code.
10. **`air_use_limit`-reset:** bij landen, ledge grab, geraakt worden en wall jump.

Status: eerste versie. De frame-bereiken worden in M5 getoetst aan `docs/melee-referentie.md` en `docs/move-conversie.md`, en §12–§16 worden dan opgeschoond.
