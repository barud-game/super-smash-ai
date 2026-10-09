# Combat-kern (M3)

Kernmodules puur en deterministisch (`engine/combat/`, tests `tests/test_combat.gd`); de integratie in de fighter staat in
"M3-integratie" hieronder (tests `tests/test_fighter_combat.gd`).
Alles in frames (60 Hz) en Melee-units (y omhoog). Bronnen: `docs/movement.md` (Knockback), `docs/move-conversie.md` (§1, §6),
SmashWiki (Knockback, Sakurai angle, Shield stun, Hitlag, Directional influence). ⚠️ = niet exact geverifieerd.

## Modules
| Bestand | Rol |
|---|---|
| `move_data.gd` | `MoveData`: total_frames, IASA, landing lag, L-cancel lag, auto-cancel, `hitboxes`. `active_hitboxes(frame, origin, facing, owner, instance)` geeft `ActiveHitbox`es (offset.x gespiegeld met facing). |
| `hitbox_data.gd` | `HitboxData`: id (= prioriteit, laagste wint), group, start/end frame, offset, radius, damage, angle (361 ok), base_kb, kb_growth, set_kb (WDSK), element, shield_damage, hitlag_mult, clank, disjoint, grounded_only/aerial_only, ignores_shield. |
| `hurtbox_data.gd` | Capsule (a, b, radius) in fighter-lokale units, per deel `intangible`. `default_for_height()`. |
| `active_hitbox.gd` / `combat_target.gd` | Momentopnamen voor de resolver (wereldcoördinaten). Target: percent, weight, grounded, crouching, intangible, invincible, shield (centrum, radius, analoog). |
| `knockback.gd` / `knockback_result.gd` | Alle formules (zie onder). |
| `hit_resolver.gd` / `hit_event.gd` | `HitResolver.resolve(active, targets, already_hit) -> Result{hits, clanks}`. Geen side effects. |
| `hitbox_draw.gd` | Debug-tekenen van hitboxen, hurtboxes en shield in `_draw()`. |

## Formules
- `KB = ((((p/10 + p·d/20) · 200/(w+100) · 1.4) + 18) · g/100) + b`, `p` = percentage **na** de hit. Gecontroleerd tegen de kill-richtlijn (KB ≈ 190 bij w=100): Marth fsmash-tip 90%, Fox jab 410%, Bowser fsmash 78%.
- Set knockback (WDSK) ⚠️: `p/10 + p·d/20` wordt `1 + wdsk/2`, `g` = 100, `b` blijft opgeteld. Niet afhankelijk van percentage.
- Hitstun = `floor(KB·0.4)`; launch-snelheid = `KB·0.03` units/frame; decay 0.051/frame op de grootte (richting blijft; `Knockback.decay_step`).
- Hoek: facing links spiegelt `a → 180 − a`. **361-regel**: op de grond KB < 32 → 0° (blijft grounded, glijdt), anders 44°; in de lucht 45°. ⚠️ exacte grondgrens/hoeken uit SmashWiki (Sakurai angle).
- Tumble (DamageFly met tumble-animatie, geen actie tot hitstun voorbij): `KB ≥ 80` ⚠️ (Melee: knockback > 80 in KB-eenheden).
- Crouch cancel ✅: op de grond én crouching → `KB × 2/3` (hitstun en snelheid volgen de verlaagde KB). In Melee ook geen flinch-animatie bij heel lage KB; hier niet gemodelleerd.
- Smash-charge onderbroken ✅: slachtoffer laadt een smash op (`CombatTarget.charging`) → `KB × 1,2` (`Knockback.compute(..., victim_charging)`), na crouch cancel in dezelfde berekening. De fighter moet `charging` nog zetten (zie fighter-TODO in het rapport).
- Hitlag (✅ `ftCommon_CalcHitlag`) = `int(int(d/3 + 3) · mul)`, d = integer damage (afgekapt), cap **20** frames. Aanvaller: `mul` = hitbox.hitlag_mult. Slachtoffer: ook electric ×1,5 en (crouching) ×2/3. Overige elementen geen multiplier ✅. `Knockback.hitlag_frames(d, element, mult, victim, crouching)`; `HitEvent.attacker_hitlag` / `defender_hitlag` verschillen dus.
- Shieldstun ✅ = `floor(200/201 · (d·(0,65·(1−a) + 0,3)·1,5 + 2))`, `a = (s − 0,3)/0,7` geklemd 0..1 (`Knockback.shield_norm`), `s` = ruwe analoge shieldstand (digitaal = 1). Bij volle shield ≈ `floor(0,448·d+2)`; lichtste shield factor ≈ 0,95. Shield damage: `HitEvent.shield_damage` = `damage + hitbox.shield_damage` (ruw); de verdediger rekent × (0,7 + 0,65·(1 − a)) (M4, zie "M4-implementatie").
- DI ✅ (`ftCo_8008E5A4`): de launch-richting draait `18° · c·|c|`, c = stickcomponent loodrecht op de launch (kwadratisch, teken behouden; halve stick = 4,5°). `apply_di`, `di_angle_delta`.
- SDI ✅: tijdens hitlag, op de flick (stick van < 0,7 naar ≥ 0,7) verschuift de fighter `stick × 6` units (niet genormaliseerd: 0,7 → 4,2). ASDI: op het laatste hitlag-frame stick ≥ 0,7 → `stick × 3`. De fighter moet de offset zelf met collision-check toepassen.

## HitResolver
1. **Clank** (`clank` aan, verschillende eigenaars, hitboxen overlappen): verschil in damage ≥ 9 → alleen de zwakste rebound en de sterkste blijft doorraken (`attacker_rebounds`/`defender_rebounds`); anders rebounden beide en raken ze niet meer. ⚠️ Melee-regel uit SmashWiki (rebound: ≥ 9% verschil; vergelijking op integer damage).
2. **Treffers** per doelwit, hitboxen gesorteerd op (owner, instance, id) voor determinisme. Overgeslagen: eigen fighter, `intangible`/`invincible` doelwit, intangible hurtbox, `grounded_only`/`aerial_only` mismatch, al geraakt (sleutel `owner:instance:group:target` in `already_hit`).
3. Per (owner, instance, doelwit) maximaal één `HitEvent` per frame: de hitbox met het laagste `id` wint (prioriteit).
4. Doelwit met `shielding` (en hitbox zonder `ignores_shield`, geen grab): overlapt de hitbox de shield-cirkel → `Kind.SHIELD` (geen knockback). Zo niet, dan cirkel-vs-capsule tegen de hurtboxes → `Kind.HIT` (**shield poke**: lijfdelen buiten een gekrompen bubble zijn raakbaar).
   Grab-hitboxes (`ActiveHitbox.is_grab`) clanken niet, negeren de shield, raken alleen `grabbable` doelwitten → `Kind.GRAB` (geen hitlag/knockback).
5. **De aanroeper** beheert `already_hit` (per move-instantie; leeg bij elke nieuwe aanval) en voegt `event.key` van elke HIT/SHIELD toe.

**Hitfall**: `HitEvent.attacker_hitfall_allowed` is `true` alleen bij `Kind.HIT` (niet bij SHIELD of CLANK); `is_shield_hit()` voor de zekerheid. Zie `docs/movement.md` "Besluit: Rivals-aanpak".

## M3-integratie in de Fighter (gebouwd)
Tests: `tests/test_fighter_combat.gd` (137 checks, twee fighters, gescripte input). ⚠️ = gekozen, niet uit Melee-data.
Constanten staan in `FighterConst` (sectie "Gevecht").

### Frame-volgorde (Sim)
1. Input samplen. 2. Alle entities `sim_tick` (fighters bewegen; een fighter in hitlag doet alleen `_hitlag_tick`).
3. **Post-tick `Sim.combat.step(entities)`** (`engine/combat/combat_system.gd`, `CombatSystem`): fighters gesorteerd op `player` →
`Fighter.active_hitboxes()` (leeg tijdens hitlag of na een rebound) + `combat_target()` → `HitResolver.resolve()` één keer
(already_hit van alle fighters samengevoegd; sleutels bevatten owner+instance) → clanks → aanvallers (`on_hit_landed`: hitlag,
hitfall-vlag, `already_hit`) → slachtoffers (`receive_hit`: percent + `percent_changed`, damage-state, hitlag, VFX/SFX).
Toepassen ná het resolven = trades symmetrisch. Tests roepen `CombatSystem.step()` zelf aan.
Gekozen voor een post-tick-hook i.p.v. een entity, zodat de volgorde (na álle fighters, ook als de MatchController zich
ertussen registreert) vastligt zonder registratievolgorde.

### Moves laden (`MoveSet`, `engine/combat/move_set.gd`)
`Fighter.reload_moves()` (in `setup()` en `set_stats()`): alle `.tres` in `engine/fighter/archetypes/<archetype>/moves/`, per move
overschreven door `characters/<character_id>/moves/<move>.tres`. Archetype = `Fighter.archetype_id`, anders afgeleid uit de
stats-preset (`Archetypes.id_for_stats`), anders `character.json` (`Archetypes.id_for_character`), anders `allrounder`.
Ingebouwd als er geen bestand is: `ledge_attack` / `ledge_attack_slow` (8% / 10%, frames uit de ledge-opties) en `getup_attack`
(6%, voor en achter) ⚠️. Bestanden worden gecachet (`MoveSet.clear_cache()` voor hot reload).

### Input → move (Melee-volgorde: aanval vóór sprong)
| Waar | Input | Move |
|---|---|---|
| Wait, Walk, Turn, Squat(Wait), SquatRv, Teeter, IASA van een aanval | C-stick | f/u/dsmash (achteruit = omgedraaid) |
| idem | A + flick (≥ 0.8, teller < `SMASH_ATTACK_WINDOW` 4 ⚠️ Xbox-leniency; Melee 2) | f/u/dsmash |
| idem | A + stick (dominante as) | ftilt (achteruit = omgedraaid), utilt, dtilt |
| idem | A neutraal | jab |
| Dash | A / C-stick; A + omhoog-flick of C-stick omhoog | dash attack; usmash |
| Run | A / C-stick | dash attack |
| KneeBend | A + stick-y ≥ 0.6625 of C-stick omhoog | **JC usmash** (sprong vervalt) |
| Lucht (Jump, JumpAerial, Fall, DamageFall, IASA aerial) | A + stick / C-stick, t.o.v. facing | nair, fair, bair, uair, dair |
| overal (grond) | Z, of A met shield (analoog) vast | grab (`Grab`); uit Dash/Run dash grab (M4, zie "M4-implementatie") |
| overal | B | `check_special()`-hook (special-toolkit), vóór grab en aanvallen |
C-stick: één as ≥ 0.6625 en het vorige frame niet (⚠️ drempel).

### States
| State | Kern |
|---|---|
| `Attack` | grond, MoveData-gestuurd. move-frame = state_frame − charge. Einde → Wait (dtilt met stick omlaag → SquatWait). IASA → Wait-interrupts. Dash attack glijdt (traction ×1) en mag van de rand; rest stopt aan de rand ⚠️. |
| Smash charge | op move-frame `SMASH_CHARGE_FRAME` = 2 ⚠️ blijft de move staan zolang A vast is, max 60 frames ✅; damage × (1 + 0.3671·charge/60) → ×1.3671 ✅. C-stick-smash laadt alleen met A vast. Pose: `atk_<x>smash_charge`, bij loslaten `atk_<x>smash` vanaf de charge-houding. |
| Jab-combo | A (nieuw) tijdens jab N zet jab N+1 klaar als `jab2`/`jab3` bestaat; start na laatste actieve frame + 1 ⚠️. Multi-hit-jabs (groepen in één `jab.tres`) spelen gewoon helemaal af. Rapid jab: nog niet. |
| `AttackAir` | drift/gravity/fast fall lopen door; einde → Fall; geen ledge grab. Landen: auto-cancel → `normal_landing_lag`; anders `landing_lag`, of bij L-cancel `lcancel_lag` (0 → floor(lag/2), min 1) → `Landing` (debug toont "fair 20, L-cancel"). |
| L-cancel | LT/RT (digitaal of analoog ≥ 0.3), RB/Z binnen 7 frames vóór én op het landingsframe ✅. Hitlag-frames tellen gewoon mee (Melee verruimt; hier niet apart) ⚠️. |
| Hitlag | `Fighter.hitlag_frames` = `HitEvent.attacker_hitlag` / `defender_hitlag` (zie Formules; slachtoffer: electric, crouch). Geen beweging, state_frame/timers bevroren. Slachtoffer: SDI per frame (flick ≥ 0.7: stick×6 units), op het laatste frame ASDI (stick×3, C-stick heeft voorrang) en DI (stick, max 18°, kwadratisch), daarna de launch. Grond-SDI blijft op het segment; lucht-SDI gaat niet door de vloer. |
| Launch | `kb_vel` apart van `vel` (zoals Melee): positie += vel + kb_vel, kb_vel −0.051/frame (in elke state). Self-vel op 0 bij de hit; gravity werkt door. Grond + `stays_grounded` (361 met KB < 32, of ⚠️ ASDI omlaag zonder tumble) → glijden met gr_vel. Grond + tumble de grond in → vy gespiegeld ×0.8 ⚠️ (grond-bounce). |
| `Damage` | hitstun zonder tumble (KB < 80): N = floor(KB·0.4) frames geen actie, frame N+1 actionable. Grond: wrijving; lucht: gravity, geen drift/fast fall. Landen: hitstun loopt door. Pose damage_low/mid/high bij KB < 30 / < 55 / rest ⚠️. Van de rand glijden eindigt de hitstun ⚠️. |
| `DamageFly` | tumble (KB ≥ 80): hitstun zonder acties, dan `DamageFall`. Pose damage_fly → tumble. Launch-trail-VFX. |
| `DamageFall` | tumble na hitstun: drift + fast fall; alleen aerial, double jump, air dodge (een shield-druk is hier dus een air dodge, zoals Melee); ledge grab mag. |
| Tech | neerkomen in DamageFly/DamageFall met een shield-druk ≤ 20 frames ervoor ✅ (lockout 40 frames na een druk ⚠️): stick-x ≥ 0.5 → tech roll die kant op (40 f, 28 units, intangible 1–20 ⚠️), anders tech in place (26 f, intangible 1–20 ⚠️). |
| Missed tech | `DownBound` (26 f ⚠️, kwetsbaar) → `DownWait` (liggen, lage hurtbox; max 180 f ⚠️) → `DownGetup`: A = getup attack (49 f, intangible 1–26), stick links/rechts = roll (35 f, 26 units, 1–25), stick omhoog/jump = opstaan (30 f, 1–22) ⚠️. |
| Crouch cancel | Squat/SquatWait op de grond: KB × 2/3 (via `CombatTarget.crouching`). Blijft de hit grounded (`stays_grounded`), dan geen flinch: blijft hurken en glijdt (na DI) ⚠️. Anders gewone Damage/DamageFly. |
| Hitfall | aanvaller in de lucht, in de hitlag van een echte treffer (`HitEvent.attacker_hitfall_allowed`): een omlaag-flick (fast-fall-drempel/-venster) zet `fastfalling`, ook tijdens stijgen; na de hitlag vy = −fast_fall_velocity. Niet na een clank (`on_clank`) of shield-hit, en niet bij een whiff. |
| Clank | alleen tussen grondaanvallen (`HitResolver.resolve(..., no_clank)` met de eigenaren die in de lucht zijn: aerials traden, Melee). Hitlag voor beide; rebound-kant raakt niets meer en gaat op de grond naar `Rebound` (20 f ⚠️). Clank-VFX + SFX `hit_weak` ⚠️ (geen eigen recept). |
| `CliffAttack` | hitboxes uit `ledge_attack(_slow)`; TODO uit M2 vervangen. |
| Treffer algemeen | ledge loslaten met `release_ledge(stats.ledge_cooldown)` (één cooldown van 30, zelfde als loslaten ✅), fast fall uit, `last_hit_by`. |

### Hurtboxes
`Fighter.hurtboxes()`: `HurtboxData.default_for_height(visual_height)` (benen, romp, hoofd); `hurtbox_shape()` per state:
"crouch" (Squat*, dtilt: laag), "lie" (DownBound/DownWait/begin getup: liggende capsule). Intangible via `is_intangible()`
(ledge, air dodge, getups, tech, respawn) → `CombatTarget.intangible`.

### Visuals, VFX, SFX
- Aanvalsposes: `play_timed(atk_<move>, startup, active, total)` met startup = eerste 0-based actieve frame (`StateAttack.timing_for`);
  `jab` → `atk_jab1`. Een nieuwe aanval herstart de pose (ook dezelfde move). `FighterState.pose_timing()`.
- Combat-poses: damage_low/mid/high, damage_fly, tumble, tech, tech_roll, missed_tech_lie, getup_from_lie, roll_forward/back.
- Ledge: CliffCatch → `cliff_catch`, CliffWait → `cliff_wait`, CliffClimb → `cliff_getup`, CliffEscape → `cliff_roll`,
  CliffAttack → `cliff_attack` (play_timed op de hitbox), CliffJump → `cliff_jump`, Teeter → `teeter`, RebirthWait → `respawn_platform`.
  De hang-positie komt uit het rig: `LedgeGrip` (`engine/fighter/ledge_grip.gd`) rekent met forward kinematics de handpalmen
  in de `cliff_wait`-pose uit; `Fighter.ledge_grip()` schaalt dat met `visual_height` en `ledge_hang_pos()` zet de voeten zo dat
  de handen precies op de ledge-hoek liggen (elke lengte 8–30). Geen visual-offset meer nodig.
- Hitlag-jitter van het slachtoffer: `VfxConst.hitlag_jitter(frames, 1.5 + 0.35·d px, max 9)`.
- VfxLayer: `Fighter.vfx`, anders de eerste node in groep `vfx_layer`. Hit-spark (`spawn_hit`, sterkte KB/160, element, hoek),
  kill-flash als de launch zonder én met ±18° DI de blast zone haalt (`Fighter.predict_ko`), launch-trail bij tumble,
  land-/jump-/dash-dust, airdodge-trail. Geen respawn/KO-effect (doet de MatchController).
- SFX: `hit_weak` / `hit_medium` (d ≥ 7 of KB ≥ 40) / `hit_strong` (tumble) / `hit_kill`, `jump`, `double_jump`, `land`,
  `land_heavy` (fast fall of vy ≤ −2.8), `airdodge`, `dash`, `ledge_grab`.
- F2: `Fighter` tekent ECB, hurtboxes (geel, blauw = intangible) en de hitboxes van het laatste actieve frame (rood) in een
  `CombatDebug`-child boven de visual.

### Sandbox
F8 = P2 dummy (lege inputbron), F9/F10 = % van P2 −/+ 10. `--demo-fight --hitboxes --p2-percent 110` speelt een SH-fast-fall-fair.

### Nog niet
Rapid jab, staling, jab reset, wall/ceiling-bounce,
hitstun-cancel, aparte L-cancel-verruiming tijdens hitlag, per-element effecten, reverse hits.

Projectielen/reflect, armor, shield tilt (bubble verschuiven met de stick), pushback voor de aanvaller op shield.

## M4-implementatie: verdediging (gebouwd)
Tests: `tests/test_defense.gd` (313 checks: shield, lightshield, shieldstun, HP/break/dizzy, shield poke, powershield, OoS,
shield drop, rolls/spotdodge per archetype × lengte 8/15/30, grab/dash grab/whiff, pummel, release, alle throws per archetype,
throw-DI, throw → tumble → tech, special-hook, determinisme). Constanten in `FighterConst` (sectie "Verdediging"), per-archetype
waarden in `FighterStats` (groep "Verdediging"). ✅ = bron (verificatie/SmashWiki), ⚠️ = gekozen of niet geverifieerd.

### Shield
| Onderdeel | Waarde | Zekerheid |
|---|---|---|
| Aan | analoge trigger ≥ 0.3 (`SHIELD_ON_THRESHOLD`) of digitale klik (`BTN_SHIELD`, = 1.0); grond-actionable states (Wait, Walk, Turn, Teeter, Squat*, Run, RunBrake, IASA van aanvallen). Niet uit Dash. Lucht = air dodge | ✅ 0.3; ⚠️ Dash/Run-keuze |
| States | `GuardOn` (8 f, minimale shield-tijd) → `Guard` → `GuardOff` (15 f, geen acties, shield niet meer op). `GuardSetOff` = shieldstun | 15 ✅, 8 ⚠️ |
| Shield-HP | max 60, slijt 0.28/frame in GuardOn/Guard, herstelt 0.07/frame daarbuiten, na break weer 30 | ✅ [W] |
| Shield-schade | `(damage + shield_damage) × (0.7 + 0.65·(1 − a))`, `a = shield_norm(s)`: vol ×0.7, lichtste ×1.35 | ✅ vol, lightshield-factor volgens verificatie C17 |
| Shieldstun | `Knockback.shieldstun_frames(d, s)` met de analoge stand `s` (`CombatTarget.shield_analog = Fighter.shield_value()`); telt ná de hitlag | ✅ |
| Hitlag verdediger | `HitEvent.defender_hitlag`, met shield-SDI/ASDI | ✅ structuur |
| Pushback | `gr_vel = min(0.3 + d·(0.65·(1−a)+0.3)·0.15, 2.2)` weg van de hitbox, remt met traction ×1; lightshield = meer | ⚠️ getallen, ✅ richting |
| Bubble | straal = `shield_size_ratio (0.62) · visual_height · (0.15 + 0.85·hp/60) · (1 + 0.3·(1−a))`, middelpunt 0.5·h boven de voeten; spelerskleur, doorschijnender bij lightshield, wit tijdens powershield (`Fighter._draw_shield`) | ⚠️ |
| Shield poke | hitbox die de bubble niet raakt maar wel een hurtbox → gewone HIT | ✅ structuur |
| Powershield | digitale klik, treffer binnen de eerste 4 frames van GuardOn: geen schade, stun, pushback of hitlag voor de verdediger. Alleen analoog = geen powershield. Reflecteert niets | ⚠️ venster 4 (Melee fysiek mogelijk 2) |
| Shield break | HP ≤ 0 (slijten of treffer) → `ShieldBreak` (vy 2.5, geen drift/acties) → landen → `ShieldBreakDown` (30 f, liggend) → `Dizzy` | ⚠️ vy/30 |
| Dizzy | `max(400 − percent, 120)` frames, geen acties | ⚠️ formule; mashen verkort niet |
| Aanvaller | hitlag op shield, geen hitfall (M3) | ✅ |

### Uit shield (GuardOn/Guard, `Fighter.check_oos`)
| Input | Actie | Zekerheid |
|---|---|---|
| A of Z | staande grab | ✅ |
| jump / tap jump | KneeBend: daar JC usmash (A + omhoog / C-stick omhoog), up-B (special-hook) of JC grab | ✅ structuur |
| verse omlaag-flick op een platform | shield drop: vanilla alleen in de notch −0.7 < y ≤ −0.6875; UCF (`ucf_shield_drop`, aan) ook schuin omlaag met \|x\| ≥ 0.4 | ✅ regel (verificatie #20), ⚠️ UCF-zone |
| omlaag-flick ≤ −0.7, venster 4 | spotdodge (`EscapeN`) | ⚠️ |
| x-flick ≥ 0.8, venster 4 | roll vooruit/achteruit (`Escape`) | ⚠️ (Xbox-leniency venster) |

### Rolls en spotdodge (per archetype in de presets)
| Preset | spotdodge totaal / intangible | roll totaal / intangible / afstand × h |
|---|---|---|
| allrounder (Marth) | 27 / 2–16 | 35 / 4–19 / 1.9 |
| fast_faller (Fox) | 23 / 2–15 | 35 / 4–19 / 2.0 |
| heavyweight (Ganondorf) | 27 / 2–16 | 40 / 4–20 / 1.5 |
| floaty (Peach) | 27 / 2–17 | 35 / 4–19 / 1.7 |
| lightweight (Pikachu) | 25 / 2–15 | 35 / 4–19 / 2.2 |
Alle ⚠️ (Melee-orde van grootte, niet per character nagemeten). Roll beweegt gelijkmatig over de eerste `roll_frames − 8` frames,
stopt aan de rand; een forward roll eindigt omgedraaid ✅. Poses `roll_forward`/`roll_back` (28 f) en `spotdodge` (26 f) worden op de duur geschaald.

### Grab, pummel, throws
| Onderdeel | Waarde | Zekerheid |
|---|---|---|
| Grab | Z, of A met shield vast; move `grab` uit de moveset; whiff = `total_frames` | moveset |
| Dash grab | uit Dash/Run (en Z): hitboxes + duur +7 frames, bereik ×1.2, glijdt met traction ×1. JC grab (jumpsquat) = staande grab | afspraak 2 (+7), ⚠️ ×1.2 |
| Grab-hitbox | `ActiveHitbox.is_grab`: negeert shield, clankt niet, alleen `grabbable` doelwitten, niet intangible. Grijper die zelf geraakt wordt grijpt niet; twee tegelijk: laagste speler wint | ✅ / ⚠️ tie-regel |
| Vasthouden | victim-voeten op grab-tip + 0.1 × `visual_height` van de victim, kijkt naar de holder (`GrabHold` / `Grabbed`); throw/pummel pas na 4 frames | ⚠️ |
| Grab-timer | `90 + 1.7·percent` frames; elke mash-input (nieuwe knop of verse stickrichting) −6 | ⚠️ (structuur ✅) |
| Release | grond: beide `GrabRelease` 30 f, victim weggeduwd (1.0), holder 0.5; in de lucht gegrepen: victim springt omhoog (vy 2.0), direct actionable | ⚠️ |
| Pummel | A, 24 f, damage `pummel_damage` (3 / Fox 2 / Pikachu 2) op frame 6, kan niet missen, hitlag beide, geen SDI | ⚠️ (afspraak 4: 2–3) |
| Throws | stick ≥ 0.6625 (dominante as) of verse C-stick t.o.v. de kijkrichting → f/b/u/dthrow. Launch op het `start_frame` van de throw-hitbox (= round(totaal × 0.5), afspraak 3) met die hitbox-data (victim-gewicht/-percent, hoek t.o.v. de holder); kan niet missen; DI wel, SDI/ASDI niet. Achterwaartse hoeken (90–270) zetten de victim eerst achter de holder | afspraak 3 / ✅ DI |
| Verbreken | holder of victim verlaat de grab-familie (geraakt, KO) → de ander naar zijn release | ✅ structuur |
Pummel-treffer en throw-launch worden in de combat-stap toegepast (`CombatSystem.step` stap 0, `Fighter.apply_grab_actions`),
zodat holder en victim hun hitlag symmetrisch krijgen. Tech chase: throw → DamageFly → tech/missed tech werkt (getest).

### Special-hook
`Fighter.check_special()` wordt aangeroepen vanuit `check_ground_attack` (Wait/Walk/Turn/Teeter/Squat*/IASA), `check_dash_attack`
(Dash/Run), `check_jc_usmash` (KneeBend, dus up-B uit shield) en `check_aerial` (alle lucht-actionable states). Zonder
`special_hook` doet B niets. `special_input()` = `{dir: neutral/side/up/down, back, grounded}` (up/down ≥ 0.6625, side ≥ 0.6 ⚠️).

### Visuals, VFX, SFX
Poses: GuardOn/Guard/GuardOff `shield`, GuardSetOff `shield_stun`, Escape `roll_forward/back`, EscapeN `spotdodge`, ShieldBreak
`tumble`, ShieldBreakDown `missed_tech_lie`, Dizzy `shield_break_dizzy`, Grab `atk_grab(_dash)` (play_timed), GrabHold `atk_grab_hold`,
Pummel `atk_pummel`, Throw `atk_<x>throw` (marks.active = launch), Grabbed `grabbed`, Thrown `thrown`, GrabRelease `damage_low`.
VFX: `spawn_shield_hit` (spelerskleur; wit bij powershield; groot bij break). SFX: `shield_hit`, `shield_break`, `grab`, `throw`, pummel `hit_weak`.
Sandbox: `--defense-demo shield|lightshield|grab|throw`.
