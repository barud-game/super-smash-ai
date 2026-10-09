# Specials: toolkit en sjablonen (M5)

Hoe een special (neutral/side/up/down-B) gebouwd wordt: als **configuratie** van een sjabloon (bijna altijd) of als
**eigen script** op dezelfde basisclass. Ontwerp en prijsregels: `docs/special-sjablonen.md` (de 16 sjablonen, randgevallen,
director-besluiten). Code: `engine/specials/`, states `engine/fighter/states/state_special*.gd`, tests `tests/test_specials.gd`,
validator `tools/validator/special_*.gd`. ⚠️ = eigen keuze, niet uit Melee-data.

## 1. Een special maken

### Config (standaard)
`characters/<id>/specials/<slot>.tres` (`slot` = `neutral`, `side`, `up`, `down`) met een `SpecialDef`:

| Veld | Betekenis |
|---|---|
| `templates` | 1 of 2 sjabloon-id's (max 2, director-besluit 1). `[0]` primair; `[1]` gekoppeld (zie §3) |
| `params` | instellingen van `templates[0]` + gedeelde instellingen (§0.2 van de sjablonen-doc). Varianten: `<key>_ground` / `<key>_air` |
| `linked_params` | instellingen van `templates[1]` (gedeelde sleutels vallen terug op `params`, sjabloon-standaarden gaan vóór) |
| `hitboxes` | rol -> `Array[HitboxData]` (zelfde formaat als `MoveData`; frames **relatief aan de fase** van de rol, `end_frame < 0` = de hele fase). Ontbrekende rol = standaard-hitbox uit `<prefix>damage/kb_angle/kb_base/kb_scale/size`; een **expliciet lege** rol = geen hitbox |
| `poses`, `vfx`, `sfx` | fase -> naam (presentatie; standaard-poses: `atk_special_*`, docs/rig.md) |
| `telegraph` | VFX-naam van de verplichte telegraaf (charge, buff, trap) |
| `ground_allowed`, `air_allowed` | gebruik op grond/lucht |
| `helpless_after`, `helpless_on_miss_only`, `landing_lag` | special fall na afloop in de lucht; vaste landing lag (geen L-cancel) |
| `ledge_snap` (`none`/`during`/`end_only`), `ledge_snap_range` | ledge-snap-hook |
| `air_use_limit` (-1 = onbeperkt), `limit_resets_on_hit` | per-airtime-limiet |
| `armor` `{from,to,max_damage}`, `intangible` `{from,to}`, `cancel_window` `{from,to,to_states}` | vensters in frames vanaf de knopdruk (0-based) |
| `scores` `{S,K,B,V,U}` | prijs; de validator vergelijkt ze met de parameters |
| `script_path` | optioneel eigen runner (zie hieronder) |

Instellingen die niet gezet zijn komen uit `DEFAULTS` van het sjabloon-script (de richtwaarden uit de sjablonen-doc).
Voorbeelden: `characters/_dummy/specials/` (gegenereerd door `tools/specials/gen_dummy_specials.gd`):
neutral = `charge`+`projectile`, side = `dash_strike`, up = `rising_multi`, down = `counter`.

### Eigen script (alleen als geen sjabloon past)
`characters/<id>/specials/<slot>.gd` (of `SpecialDef.script_path`) met `extends SpecialMove` — of `extends TplProjectile` enz.
om een sjabloon uit te breiden. De `.tres` blijft nodig (scores, slot, flags). Override-punten:

| Functie | Wanneer |
|---|---|
| `start()` | begin (zet fase/snelheden) |
| `step()` | elk frame (anim): fase-overgangen; `phase`, `phase_frame`, `frame` zijn al opgehoogd |
| `input()` | elk frame (iasa), na de cancel-check |
| `phys()` / `ground_phys()` / `air_phys()` | snelheden |
| `hitboxes()` | actieve hitboxes (`role_boxes(rol, t)`, `boxes(lijst, t, origin)`) |
| `on_land()`, `on_edge(side, gv)`, `wants_off_edge()`, `lands_on_platforms()` | grond/lucht |
| `intangible()`, `intercepting()`, `intercept(ev, bron)`, `armor_active()` | intangibility, armor, counter |
| `reflect_box()`, `absorb_box()`, `grab_box()` + `on_reflect/on_absorb/on_grab/on_grab_clank` | wereld-interacties |
| `ledge_snap_active()`, `is_end_phase()`, `helpless_now()`, `can_start()` | regels |
| `default_pose()`, `pose_timing()`, `on_exit()` | presentatie / opruimen (`interrupted` = geraakt) |

Klaar met de move: `finish()` (helpless/Fall/Wait, of de sequentie naar `templates[1]`). Parameters: `p/pf/pi_/pb/ps(key, default)`.

## 2. Bouwstenen (API)

| Bouwsteen (sjablonen-doc) | Waar |
|---|---|
| 1 fase-machine, 22 landing, 23 cancel | `SpecialMove`: `set_phase`, `finish`, `land_with_lag`, `_check_cancel`; hitlag bevriest alles (Fighter tickt de state dan niet) |
| 2 hitboxes per frame | `SpecialMove.boxes/role_boxes/hits_or_default/scaled`; via `StateSpecial.hitboxes()` in dezelfde `CombatSystem`-resolve als normals |
| 3 velocity | `set_velocity`, `scale_velocity`, `apply_gravity(scale)`, `gravity_scale`, `momentum_air` (keep/scale/zero) |
| 4 stick-aim | `SpecialAim.direction(stick, mode, facing, neutral_angle, n)`, `steer_angle`, `dir_from_angle`, `slot_from_stick` |
| 5, 6 projectielen | `SpecialProjectile` (lifetime, max_range, boog, stuiter, pierce, multi-hit, orbit, blast zone, solide blokken) + `SpecialWorld` (clank: hogere damage wint, gelijk = beide weg, transcendent negeert; reflect; absorb; shield via `Fighter.on_shield_hit`) |
| 7 armor, 8 intangible, 9 counter | `SpecialDef.armor/intangible`; `intercepting()` + `SpecialWorld._intercepts` (zie §4) |
| 10 reflect-box, 11 absorb-box | `reflect_box()` / `absorb_box()` -> `SpecialWorld._reflect_absorb` |
| 12 grab-box / held | `grab_box()` -> `SpecialWorld._grab_boxes` (negeert shield, grab-trade = beide mis); slachtoffer in `StateSpecialHeld` (id `SpecialHeld`, breakout per mash); worp via `SpecialMove.apply_direct_hit` |
| 13 helpless | bestaande `FallSpecial`/`LandingFallSpecial` met `landing_lag` |
| 14 ledge-snap | `SpecialGeometry.try_ledge_snap(f, extra_range, allow_rising)` -> `Fighter.grab_ledge` (bezet, lock, regrab-intangibility: bestaand systeem) |
| 15 per-airtime-limieten | `SpecialKit.air_uses`, `can_use`, `reset_air_limits(reason)` (land/ledge/hit/respawn; `"wall_jump"` via API) |
| 16 teleport/reposition | `SpecialGeometry.resolve_target(segs, from, to, snap_to_valid/shorten/fizzle, cross_walls)`, `TELEPORT_MAX_DISTANCE` 260 |
| 17 charge | `TplCharge` + `SpecialKit.store_charge/take_charge`; `SpecialMove.set_charge(ratio)` schaalt damage/kb/size/speed (`scale_*`, `charge_stages`) |
| 18 trap | `SpecialTrap` (drop/stick/throw_arc, arm_time, contact/proximity/timer/owner_signal, hp, chain, cap 8 per eigenaar) |
| 19 tether | `SpecialHook` (ledge/fighter-anker, swept check) + `TplTether` |
| 20 stat-modifiers | `SpecialKit.add_buff/remove_buff/mult` (stats: kopie van de preset × modifiers; `move_swap` in `Fighter.moves`) |
| 21 follow-up-venster | `TplCommandDash` (input-buffer, chain_limit, special -> `templates[1]`) |
| 24 identiteit, 25 determinisme | `owner_id` = `Fighter.player`; entity-instanties vanaf 1 000 000; vaste spawn-volgorde; geen RNG |
| 27 debug | `StateSpecial.debug_name()`, `SpecialWorld.events`, `SpecialKit.fx_log` |
| 28 presentatie | `present(fase)` (vfx/sfx uit de def), `telegraph()`; VFX via `VfxLayer.spawn_special_fx(naam, pos, facing, speler)` als die bestaat (nog te bouwen), anders alleen gelogd |

## 3. Combinaties (max 2 sjablonen)
- `charge` + X: de charge-loop eindigt met `start_linked(ratio)`; X krijgt de lading via `set_charge`.
- `command_dash` + X: de follow-up `"special"` start X.
- Elk ander paar: **sequentie** — X start als `templates[0]` klaar is (bv. `dash_strike` -> `command_grab`).
Prijs: +2 utility (validator waarschuwt als U < 3).

## 4. Frame-volgorde en aansluiting

Per sim-frame: fighters `sim_tick` (de special-state draait anim/iasa/phys/coll) -> **`SpecialWorld.step()`** (kits pollen,
entities ticken, clank/reflect/absorb, traps, grabs, armor/counter, entity-hits) -> `CombatSystem.step()` (normals én de
hitboxes van special-states). De wereld is één Node2D per stage (meta `special_world` op het stage-object), registreert zich bij
`Sim` en zet zichzelf achter alle fighters in de tick-volgorde.

**Armor/counter zonder combat-hook:** tijdens een armor-/counter-venster geeft `StateSpecial.intangible()` true, zodat
`CombatSystem` de fighter overslaat; `SpecialWorld._intercepts` legt dan zelf alle inkomende hitboxes (fighters en entities)
tegen de hurtbox (via `HitResolver`), past armor (damage + hitlag, geen KB; boven de drempel: gewone hit) of de counter toe
en geeft de aanvaller zijn hitlag (`on_hit_landed`). Gevolg: **M4-grabs missen** tijdens zo'n venster (counters werken
volgens director-besluit 6 niet tegen grabs; `armor_vs_grab` bestaat daardoor niet). Zie open punten.

### Aansluiten in het spel (nog te doen door de director)
De M4-hook `Fighter.special_hook` is er al; `Specials.attach(fighter)` zet hem op `Specials.hook`. Eén regel per fighter,
na `setup()` en nadat `stage` gezet is (MatchController/sandbox, of onderaan `Fighter.setup()`):
```gdscript
Specials.attach(self)        # in Fighter.setup(), na reload_moves(); of Specials.attach(f) waar fighters gemaakt worden
```
Meer is niet nodig: states worden geregistreerd, limieten resetten via polling, entities worden opgeruimd bij dood.
Bij match-einde: `SpecialWorld.dispose(stage)`.

## 5. Validator
`tools/validator/special_validator.gd` (regels als data in `special_table.gd`), aangeroepen door `validate_character` voor elke
`characters/<id>/specials/<slot>.tres` (regel `special_def/<slot>`):
- FAIL: onbekend slot/sjabloon, > 2 sjablonen, parameter buiten bereik (tabellen uit de sjablonen-doc), teleport `distance` > 260,
  charge/buff/trap zonder `telegraph`, onzichtbare trap, multi_jump zonder `air_use_limit`, score buiten bereik,
  score ≥ 3 punten naast de prijs-richtlijn.
- WARN: score 2 naast de prijs-richtlijn, combinatie zonder +2 U, lucht-recovery (up/side) zonder helpless en U < 7,
  armor-drempel > 12%, intangible > 20 frames, scores in `.tres` ≠ `scores.json`, geen recovery (up/side met U ≥ 5).
- De prijs-richtlijn wordt geschat waar de doc een drempeltabel geeft (S uit startup, B uit afstand/bereik, V uit endlag;
  K alleen "0" voor moves zonder hitbox). Kracht uit knockback wordt (nog) niet gemeten.

## 6. Afwijkingen / keuzes ⚠️
- Solide blokken: stage-data kent alleen bovenvlakken; een SOLID-segment = blok van `SOLID_DEPTH` 30 units diep.
- Ledge-snap tijdens stijgen: alleen met de voeten onder de ledge; specials grijpen ook achterwaarts (fighter draait).
- Slot-drempels: up/down vanaf stick-y 0.6625, side vanaf |x| 0.6 (= M4 `special_input()`).
- Projectiel-hitlag: standaard `hitlag_mult` 0.75, het projectiel zelf bevriest niet (`self_hitlag` uit).
- Reflect/absorb/grab/reflect-radius zijn stralen (units), niet de "30–70u" uit de doc (die lijken diameters/veel te groot).
- Dode entities blijven 120 frames als object bestaan (graveyard) voordat ze worden vrijgegeven.
- Buff-modifiers `damage_dealt_mult`/`kb_dealt_mult` werken alleen op specials (normals hebben een hook nodig), `armor_during` niet.
