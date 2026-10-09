# Combat-kern (M3)

Puur, deterministisch, zonder fighter-integratie. Code in `engine/combat/`, tests in `tests/test_combat.gd`.
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
- Crouch cancel: op de grond én crouching → `KB × 2/3` (hitstun en snelheid volgen de verlaagde KB). ⚠️ In Melee ook geen flinch-animatie bij heel lage KB; hier niet gemodelleerd.
- Hitlag = `floor((d/3 + 3) · element_mult · hitbox.hitlag_mult)`; electric 1,5; overige elementen 1 ⚠️ (fire/ice/slash-multiplier zit niet in Melee-hitlag; effect/flinch kan later). Zelfde hitlag voor aanvaller en verdediger.
- Shieldstun = `floor(200/201 · (d·(0,65·(1−a) + 0,3)·1,5 + 2))`, `a` = analoge shieldstand (1 = vol). Bij volle shield ≈ `floor(0,448·d+2)` (test). Shield damage = `damage + hitbox.shield_damage` ⚠️ (geen shield-pushback of -schaling).
- DI: de launch-richting draait max **18°**, evenredig met de stickcomponent loodrecht op de launch (`apply_di`, `di_angle_delta`). ⚠️ Melee kent een kleine deadzone en rekent op hitstun-frame 1; hier lineair.
- SDI ⚠️: tijdens hitlag, op de flick (stick van < 0,7 naar ≥ 0,7) 6 units in stickrichting. ASDI: op het laatste hitlag-frame stick ≥ 0,7 → 3 units. De fighter moet de offset zelf met collision-check toepassen.

## HitResolver
1. **Clank** (`clank` aan, verschillende eigenaars, hitboxen overlappen): verschil in damage ≥ 9 → alleen de zwakste rebound en de sterkste blijft doorraken (`attacker_rebounds`/`defender_rebounds`); anders rebounden beide en raken ze niet meer. ⚠️ Melee-regel uit SmashWiki (rebound: ≥ 9% verschil).
2. **Treffers** per doelwit, hitboxen gesorteerd op (owner, instance, id) voor determinisme. Overgeslagen: eigen fighter, `intangible`/`invincible` doelwit, intangible hurtbox, `grounded_only`/`aerial_only` mismatch, al geraakt (sleutel `owner:instance:group:target` in `already_hit`).
3. Per (owner, instance, doelwit) maximaal één `HitEvent` per frame: de hitbox met het laagste `id` wint (prioriteit).
4. Doelwit met `shielding` (en hitbox zonder `ignores_shield`): geraakt als de hitbox de shield-cirkel overlapt → `Kind.SHIELD` (geen knockback), anders cirkel-vs-capsule tegen de hurtboxes → `Kind.HIT` met `KnockbackResult`.
5. **De aanroeper** beheert `already_hit` (per move-instantie; leeg bij elke nieuwe aanval) en voegt `event.key` van elke HIT/SHIELD toe.

**Hitfall**: `HitEvent.attacker_hitfall_allowed` is `true` alleen bij `Kind.HIT` (niet bij SHIELD of CLANK); `is_shield_hit()` voor de zekerheid. Zie `docs/movement.md` "Besluit: Rivals-aanpak".

## Integratieplan voor de Fighter (nog te doen)
**Nieuwe/aan te passen states** (universeel in `Fighter`):
- `Attack` (state_frame = move-frame; vraagt `MoveData.active_hitboxes()` per frame; eindigt op `iasa_frame()`/`total_frames`; aerial landing → `landing_lag_at()`, L-cancel bij shield-druk ≤ 7 frames voor landing ⚠️).
- `DamageFly`/hitstun: `hitstun` frames, velocity = `launch_vel` met `Knockback.decay_step` per frame; DI toegepast bij binnenkomst op `launch_vel`. Grounded + `stays_grounded` → `DamageGround` (glijden met wrijving, geen lucht).
- `DamageFall` (tumble, `KB ≥ 80`): na de launch of bij tumble; alleen air-drift beperkt; wall/floor-bounce en tech-input (shield binnen ~20 frames vóór de grond, ⚠️ venster) → `Tech`/`TechRoll`/`MissedTech` (liggen, getup).
- Hitlag-freeze: fighter slaat gameplay-frame over (positie, state_frame, timers bevroren) voor `*_hitlag` frames; wel input lezen voor SDI/ASDI, DI-input bij het laatste hitlag-frame, en hitfall.
- Hitfall: tijdens eigen hitlag na `attacker_hitfall_allowed` mag een verse flick omlaag fast fall zetten (ook tijdens stijgen); de fast-fall-vlag wordt daarna in de gewone airborne-state toegepast.
- Crouch cancel: `crouching` vlag naar `CombatTarget`; bij `crouch_cancelled` korte hitstun, blijft in crouch.
- Shield: `SHIELD`-event → shieldstun (state_frame wacht `shield_stun` frames), shield-HP −`shield_damage`; hitlag ook hier.

**Frame-volgorde in `Sim` per `_physics_process`:**
1. Input lezen/kwantiseren (bestaand).
2. Alle fighters: één `step()` (movement + state-logica + hitlag-countdown); hitboxen volgen de nieuwe positie/state_frame.
3. Per fighter `ActiveHitbox`es verzamelen (deterministisch gesorteerd op fighter-id) en `CombatTarget`-snapshots maken.
4. `HitResolver.resolve(...)` eenmaal voor alle fighters, met per attacker de `already_hit`-set (gecombineerd).
5. Events toepassen in vaste volgorde (clanks, dan hits): damage/percent, `KnockbackResult` → target-state (DamageFly/Tumble/Ground), hitlag voor beide, `key` toevoegen aan `already_hit`, hitfall-vlag bij aanvaller, shieldstun/-damage.
6. Blast-zone/KO, camera, UI (bestaand).
Toepassen na resolven (stap 5) zorgt dat alle fighters in dezelfde frame symmetrisch worden behandeld (trades).

## Bewust niet (nog) gedaan
Staling, charge, projectielen/reflect, armor, grabs/throws als aparte flow, wall/ceiling-bounce, shield-pushback en -HP, per-element effecten, reverse hits (hit-richting op basis van positie i.p.v. facing).
