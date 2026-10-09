# Verificatie van de ⚠️-punten tegen Melee-bronnen

Onderzoek, geen codewijzigingen. Datum: 2026-10-09. Doel: de ⚠️-waarden/regels uit `docs/movement.md`,
`docs/combat.md`, `docs/stage.md`, `docs/ui.md` en `docs/melee-referentie.md` controleren.

Zekerheid: ✅ bevestigd · ❌ wijkt af (aanbeveling gegeven) · ❓ niet gevonden / bronnen botsen.

## Bronnen en hun grenzen (lees dit eerst)
- **[D] doldecomp/melee** (commit `79b13a3`, `src/melee/ft/...`): bevat de **code** (formules, volgorde, voorwaarden),
  maar **niet** de data uit `PlCo.dat`. Constanten zoals `x154`, `x1A8`, `ledge_cooldown` staan er alleen als veldnaam
  (`src/melee/ft/types.h`, `struct ftCommonData`). Uitzonderingen met `@datvalue`: deadzones 0.28, smash-deadzone 0.25,
  shoulder 0.3, Z 0.35, shield-press 0.25, walk 0.18, tap-jump 0.6625 / venster 4, relaxed tap-jump 0.5625, run/dash-friction 1.0, friction boven walk-snelheid 2.0.
- **[W] SmashWiki** (ssbwiki.com): Knockback, Hitlag, Hitstun, Sakurai angle, Directional influence, Smash directional
  influence, Shield, Rebound, L-canceling, Tech, Tumble, Smash attack, Crouch cancel, Edge-grab, Air dodge, Landing lag.
- **[N] DreamsVibe/melee-web-fighter `NOTES.md` + `src/shared/attributes.ts`**: derde partij die tegen een echte NTSC 1.02-disc
  controleerde en `PlCo.dat` uitleest. Tweedehands, maar de enige bron voor PlCo-waarden. Deels afgeleid van de decomp.
- **[P] pfirsich/meleeDat2Json dat-dumps** (`https://melee.theshoemaker.de/dat-dumps/<Character>.json`): disc-dump per
  character: `ftCo_DatAttrs` + per animatie `numFrames` en de event-scripts (intangibility `bodyCollisionState`, hitboxen). Ground truth voor character-attributen en
  animatielengtes (let op: `numFrames` kan 1 hoger zijn dan de speelduur; ±1).
- **[L] libmelee `stages.py`**; **[S] cornerian/skirmish `docs/`** (decomp-afgeleide notities).

Geen enkele bron gaf `PlCo`-drempels voor fast fall, crouch, platform drop, run, dash-dance; die staan als ❓.

## Telling
**✅ 32 · ❌ 24 · ❓ 14** (70 rijen in sectie 2-6; bij gesplitste rijen telt het slechtste deel). Sectie 1 is een selectie van de ❌ voor prioritering.

## 1. Afwijkingen (❌), gesorteerd op impact op het speelgevoel

| # | Punt | Nu in project | Melee | Aanbeveling |
|---|---|---|---|---|
| 1 | **Ledge: bezette ledge** (L10) | tweede speler grabt, eerste valt (ledge steal) | grab **mislukt** als een ander de ledge bezet (`ftCliffCommon_80081298` -> `ft_80082E3C` geeft de bezetter terug -> `return false`); geen trump in Melee | `Fighter.check_ledge_grab`: weiger de grab als `ledge_occupants` gevuld is; verwijder `_lose_ledge_to()` voor de grab-flow |
| 2 | **Ledge: regrab-intangibility** (L3) | alleen na landen/geraakt worden weer nieuwe 30 frames (`ledge_intang_ready`) | **elke** catch geeft opnieuw 30 frames: `ftCo_8009A804` (CliffWait-start) roept `ftColl_8007B760(gobj, x49C)` = `max(huidig, 30)`; geen limiet per luchttijd. Ledgestall mogelijk | verwijder `ledge_intang_ready`-logica; bij elke CliffWait-start `intangible_frames = max(intangible_frames, 30)` |
| 3 | **DI-formule** (C12b) | hoek = 18° x (stick·loodrecht), lineair | `ftCo_8008E5A4`: hoek += 18° x **loodrecht²** (`f30 = (kb x stick)²/|kb|²`, teken uit kruisproduct). Halve stick = 1/4 effect | `Knockback.apply_di` en `di_angle_delta`: `c = clampf(dot, -1, 1)` -> `c * absf(c)` (of `c*c` met teken) |
| 4 | **Hitlag-formule** (C1) | `floor((d/3+3) * elem * hitbox_mult)`, zelfde voor beide | `ftCommon_CalcHitlag`: `int( int(dmg*(1/3) + 3) * mul )`, `dmg` is **integer**; dubbele floor | `Knockback.hitlag_frames`: `int(floor(floor(floor(d)/3.0+3.0) * m))` (d afkappen op heel getal) |
| 5 | **Hitlag: electric alleen slachtoffer; crouch x2/3; cap 20** (C2-C4) | electric voor beide, geen crouch-factor, geen cap | slachtoffer: electric 1.5 (`x1A4`), Squat/SquatWait x2/3 (`x1A0`, `CalcHitlag` testet `motion_id`); beide gecapt op `x194` = 20 [W] | `hit_resolver.gd`/`Knockback`: aparte `attacker_hitlag` (m=1) en `defender_hitlag` (electric, crouch); `mini(frames, 20)` |
| 6 | **Sprong-preset-waarden** (M7-M9) | zie tabel hieronder (g2a, h-initial, h-max, air_jump_h geschat) | disc-waarden per character [P] | pas de `.tres`-presets aan volgens de tabel in sectie 5; formule zelf klopt (`ftCo_800CB110`) |
| 7 | **Ledge-getup-frames** (L6-L9) | climb 33/43, roll 36/46, jump-start 5/9, intangible climb 1-23 | [P] `numFrames`/intangibility, quick (<100%) / slow: climb 33-35/59-60, **roll 49-51/79-80**, attack 55/70, jump-wacht 11-16/19-27; intangible tot f31/f56 (climb), f25-40/f55-71 (roll), f19-22/f34-54 (attack) | `FighterStats.LEDGE_OPTION_DEFAULTS`: zie tabel sectie 3 |
| 8 | **Ledge-cooldown** (L11) | 30 na loslaten, 54 na geraakt | **een** constante `ledge_cooldown` voor beide (`ftCo_Damage.c:603/ftCo_8008E908`, `ftCo_CliffWait`, `ftCo_CliffClimb`); waarde 30 [N] | `ledge_hit_cooldown` 54 -> 30 (of verwijder het veld) |
| 9 | **Missed tech: liggen** (C23) | `DOWN_WAIT_MAX = 180` | `ftCo_DownWait_Anim` telt `x424` af; **x424 = 220** [N] | `FighterConst.DOWN_WAIT_MAX` 180 -> 220 |
| 10 | **SDI-schaal** (C13) | 6 units in genormaliseerde stickrichting | `ftCo_Damage_OnEveryHitlag`: `pos += stick x 6` (**niet** genormaliseerd; 0.7 -> 4.2 units); vereist |stick| >= 0.7 en `stick-timer < 4` | `Knockback.sdi_offset`: `stick * SDI_DISTANCE` i.p.v. `stick.normalized() * ...` (zelfde voor ASDI x3) |
| 11 | **Shieldstun bij analoge shield** (C16) | `0.65*(1-a)+0.3`, `a` 0..1 | [W] `a = 0.65 * (1 - (s-0.3)/0.7)` met `s` 0.307..1 (lichtste shield = 0.95 factor) | `Knockback.shieldstun_frames`: normaliseer `s` met `(s-0.3)/0.7` (klem 0..1) |
| 12 | **Shield damage** (C17) | `damage + shield_damage` | [W] shield-HP 60, schade x0.7 (lightshield `a+0.7`), depletion 0.28/f, regen 0.07/f, na break 30 HP | bij shield-HP bouwen: `hp -= (damage + shield_damage) * mult`; nog niet geimplementeerd |
| 13 | **Ledge grab-box** (L1) | 0..14 voor, 4..24 boven voeten (alle characters) | per character `ledge_snap_x/y/height` (`ftData+0x44`); Fox 11 / 13 / 9, **x modelschaal** [N] | `ledge_grab_front` 14 -> 11, `y_min..y_max` 4..24 -> 8.5..17.5 (midden 13, hoogte 9) als default; of per character |
| 14 | **Ledge-catch vanuit tumble** (L13) | alleen Fall/FallSpecial/Jump/JumpAerial | ook `DamageFall` (tumble), Pass, CliffJump2, special-recovery-states; **niet** aerials, air dodge, `DamageFly` [N][W] | `can_grab_ledge()`: DamageFall toevoegen |
| 15 | **Smash-charge: KB x1.2 bij onderbreken** (C18) | niet gemodelleerd | `ftCo_Damage_CalcKnockback`: `kb *= kb_smashcharge_mul` (1.2 [W]) als slachtoffer laadt | in `Knockback.compute`/resolver: `target.charging` -> kb x1.2 |
| 16 | **RunBrake / RunTurn / Squat-lengtes** (M4) | RunBrake 22/24/22/18, RunTurn 28/30/28 | zie sectie 5 [P] | `run_brake_frames`, `run_turn_frames`, `squat_frames` per preset aanpassen |
| 17 | **Landing lag Ganondorf-preset** (M5) | 4 | Ganondorf 5 (Bowser 6, DK 5, Pichu 2, rest 4) [P] | `heavyweight.tres` `normal_landing_lag = 5` |
| 18 | **Walk-accel / Peach-dash** (M11) | Marth walk_accel 0.08, Ganon 0.05, Peach 0.06, Peach dash 1.3 en accel 0.02/0.06 | [P] zie sectie 5 | `.tres` presets aanpassen |
| 19 | **Getup roll/attack missed tech** (C22) | roll 35, attack 49 | roll 36, attack 50 (intangible tot f20-25 / f24-30) [P] | `GETUP_ROLL_FRAMES` 36, `GETUP_ATTACK_FRAMES` 50 (+-1, klein) |
| 20 | **Platform drop met shield** (M3) | `check_platform_drop` volgt alleen stick-flick | `ftCo_8009A080`: shield vast **en** verse omlaag-flick (zelfde `x464`/`x468` check) | controleer dat shield-variant ook de verse flick eist (nu beschreven als "L/R vast + onder-richting") |

(Overige ❌ staan in de detailtabellen: RebirthWait-exit, respawn-positie, hang-/getup-details.)

## 2. Combat (priority 1)

| ID | Punt | Project (doc) | Melee-waarde | Bron | Zekerheid | Aanbeveling |
|---|---|---|---|---|---|---|
| C1 | Hitlag-formule | `floor((d/3+3)*mult)` (`combat.md`) | `int(int(dmg*1/3 + 3) * mul)`; `x198 = 1/3`, `x19C = 3`; dmg integer | [D] `ftcommon.c: ftCommon_CalcHitlag`; [N] | ❌ | zie #4 |
| C2 | Electric-multiplier | 1.5 voor beide | 1.5 alleen slachtoffer (`x1A4`); aanvaller 1 | [N], [W] Hitlag | ❌ | zie #5 |
| C3 | Overige element-multipliers | "overige = 1" | geen andere element-multiplier in Melee-hitlag | [W] Hitlag, [D] | ✅ | geen |
| C4 | Hitlag-cap | geen | 20 frames (`x194`, `fighter.c:2972`) | [D], [W] | ❌ | `mini(.., 20)` |
| C5 | Hitstun = floor(KB x 0.4) | 0.4 | `int(kb * x154)`, min 1 (`ftCo_8008DCE0`: `mv.co.damage.x0`); x154 = 0.4 | [D] `ftCo_Damage.c:287-293`, [W], [N] | ✅ | optioneel min 1 frame |
| C6 | Tumble-drempel | KB >= 80 | niveau 3 als `kb*0.4 >= x160` (= 32 frames = KB 80) | [D] `ftCo_Damage.c:294-307`, [W] Tumble (32 frames), Crouch cancel (60 -> 80) | ✅ | geen |
| C7 | 361-regel | grond: KB<32 -> 0°, anders 44°; lucht 45° | `ftCo_Damage_CalcAngle`: lucht `x144` (45°), grond `<x14C` (32) -> 0, lineair tot `x150` (32.1) naar `x148` (44°) | [D], [W] Sakurai angle | ✅ | geen (de 0.1-ramp is verwaarloosbaar) |
| C8 | Launch-snelheid 0.03, decay 0.051 | 0.03 / 0.051 | `x100` = 0.03, `x204` = 0.051 (langs eigen richting) | [D] `fighter.c:2197`, [W], [N] | ✅ | geen |
| C9 | KB-formule | zie `combat.md` | structuur identiek: `defense*attack*ratio*(0.01*kbg*(1.4*(2 - 2w/(1+w)) *(0.1p + 0.05pd) + 18) + bkb)`; **cap `x108`** | [D] `ftcoll.c: ftColl_80079AB0` | ✅ formule, cap ❓ | cap (waarde 2500 uit geheugen, niet gevonden) optioneel |
| C10 | WDSK-formule | `1 + wdsk/2`, g = 100, gewicht blijft meedoen | `x118` (=10) vervangt p; gewicht-term blijft; groei = die van de hitbox (`hit->x24`) | [D] `ftColl_80079AB0` (macro `KNOCKBACK`), [W] | ✅ | zorg dat WDSK-hitboxes in data growth 100 hebben |
| C11 | Crouch cancel x2/3 | 2/3 | `kb *= kb_squat_mul` voor motion Squat/SquatWait; 0.667 | [D] `ftCo_Damage_CalcKnockback`, [W] | ✅ | geen |
| C12a | DI max-hoek | 18° | `x1A8` = 18° ("ongeveer 18°") | [D] `ftCo_8008E5A4`, [W] | ✅ | geen |
| C12b | DI-formule | lineair in loodrechte stick | kwadratisch in loodrechte component | [D] `ftCo_8008E5A4` | ❌ | zie #3 |
| C13 | SDI | 6 units, genormaliseerd, flick <0.7 -> >=0.7 | `stick x 6` (`sdi_pos_scale`), min |stick| 0.7, timer-venster 4, vanaf 2e hitlag-frame | [D] `ftCo_Damage_OnEveryHitlag`; [N] (0.7, 4, 6) | ❌ | zie #10 |
| C14 | ASDI | 3 units, stick >= 0.7 | `stick x 3` (`x4BC`) op laatste hitlag-frame; C-stick overschrijft | [D] `ftCo_Damage_OnExitHitlag`, [W] | ✅ waarde (schaal zoals C13) | `stick*3` |
| C14b | L/R vast op hitlag-einde | niet gemodelleerd | `kb x x1AC` als L/R vast (waarde onbekend) | [D] `ftCo_Damage_OnExitHitlag` | ❓ | niets doen |
| C15 | Clank-regel (verschil 9) | verschil >= 9 -> alleen zwakste rebound | `(int)dmg_a - x3CC < (int)dmg_b` per kant; integer damage. [W]: "over 9%" | [D] `ftcoll.c: ftColl_8007699C`; [W] Rebound | ❓ (+-1) | laat staan; gebruik integer-damage |
| C16 | Shieldstun-formule | `floor(200/201*(d*(0.65(1-a)+0.3)*1.5+2))` | volle shield: `(d*0.3*1.5+2)*200/201` ✅; analoge schaal anders | [W] Shield | ❌ (analoog) | zie #11 |
| C17 | Shield damage / HP | `damage + shield_damage` | HP 60, x0.7 | [W] Shield | ❌ | zie #12 |
| C18a | Smash-charge-multiplier | x1.3671 bij 60 frames | 1.3671, max 60 frames | [W] Smash attack, [N] | ✅ | geen |
| C18b | KB x1.2 bij onderbreken | ontbreekt | 1.2 | [D] `kb_smashcharge_mul`, [W] | ❌ | zie #15 |
| C19 | L-cancel-venster | 7 | 7 (`x E4`), deler 2.0 (`x E8`), halveren naar beneden afgerond; input tijdens hitlag telt (tot 6 frames na hitlag) | [N] disc, [W] L-canceling | ✅ | geen |
| C20 | Tech-venster / lockout | 20 / 40 | 20 frames; geen tech als er in de 40 frames ervoor al L/R werd gedrukt (digitaal) | [W] Tech | ✅ | geen |
| C21 | Tech in place / roll | 26 f, intangible tot 20; roll 40 f | Passive 26, PassiveStandF/B 40; intangible event f0-f20 | [P] (Fox/Marth/Ganon/Peach) | ✅ | geen |
| C22 | DownBound / getups | bound 26; stand 30 (i22); roll 35 (i25); attack 49 (i26) | bound 26; stand 30 (i22-23); roll 36 (i20-25); attack 50 (hits f13-20, i tot f18-30) | [P] | stand/bound ✅, roll/attack ❌ klein | zie #19 |
| C23 | Missed-tech-liggen | max 180 | 220 | [N] (`x424`); [D] `ftCo_DownWait_Anim` | ❌ | zie #9 |
| C24 | Getup-opties | stand/roll/attack | DownStand, DownFoward/Back (roll), DownAttack, DownDamage; auto-getup na `x424` | [D] `ftCo_DownBound.c` | ✅ | geen |

## 3. Ledge (priority 2)

| ID | Punt | Project | Melee | Bron | Zekerheid | Aanbeveling |
|---|---|---|---|---|---|---|
| L1 | Grab-box | 0..14 x, 4..24 y | Fox: reikt 11 voor ECB, midden 13, hoogte 9, x modelschaal; per character | [N] (NOTES "Ledges"), [D] `ftData_x44_t` (`ledge_snap_x/y/height`), [S] | ❌ | zie #13 |
| L2 | Catch-intangibility | 7 + 30 = 37 | CliffCatch (8 anim-frames, `body2` vanaf f0) + 30 bij CliffWait (`x49C`) | [D] `ftCo_8009A804`, [P], [W] | ✅ | geen |
| L3 | Regrab-intangibility | alleen na landen/hit | elke catch 30 (max-regel) | [D] `ftColl_8007B760`, [N], [W] Edge-grab (ledgestall) | ❌ | zie #2 |
| L4 | Max hangtijd | 660 (<100%), 480 | `<x488` (100) ? `x48C` : `x490`; [W] 11 s / 8 s; [N] 640 / 480 | [D] `ftCo_8009A804`, [W], [N] | ❓ (660 vs 640) | blijf bij 660 tenzij disc-check; 480 is consistent |
| L5 | Percent-grens quick/slow | `>= 100` | `percent < x488` -> quick; x488 = 100 | [D], [N] | ✅ | geen |
| L6 | Getup (climb) | 33 / 43; intangible 1-23 / 1-13 | quick 33-35, slow 59-60; intangible tot f31 (Ganon f23) / f56 | [P] | ❌ | zie #7; tabel hieronder |
| L7 | Roll | 36 / 46; intangible tot 26 | quick 49-51, slow 79-80; intangible tot f25-39 / f55-71 | [P] | ❌ | idem |
| L8 | Ledge attack | 55 / 70; hit 25 / 35; intangible 1-20 / 1-10 | quick 54-55, hit f22-25, intangible tot f19-22; slow 69-70, hit f37-57, intangible tot f34-54 | [P] | ✅ duur/hit, slow-intangible ❌ | slow-intangible 10 -> ~45 |
| L9 | Ledge jump | start 5 / 9, vx 1.1 | CliffJump1 15-16 frames quick (Peach 11), 19-27 slow, intangible vanaf f0; `ledge_jump_horizontal/vertical` per character (Fox 1.1/4.0, Marth 1.0/2.4) | [P] | ❌ | `CliffJump` startup 5 -> 15 (9 -> 21); gebruik per-character `ledgejump*` |
| L10 | Ledge steal | grab slaagt, vorige valt | grab mislukt bij bezette ledge | [D] `ftCliffCommon_80081298`, `ft_80082E3C`; [W] (trump is Smash 4) | ❌ | zie #1 |
| L11 | Cooldown | 30 / 54 | 1 constante `ledge_cooldown` (30), afgeteld per frame buiten hitlag; geldt na loslaten, hit en getup-eind | [D] `fighter.c:2168`, `ftCo_Damage.c:603`, [N] | ❌ | zie #8 |
| L12 | Down-blokkade | stick-y <= -0.6875 | `y <= -x480`; waarde ~0.66 ("holding down past 0.66") | [D] `ftcliffcommon.c:28`, [N] | ❓ | proefsgewijs 0.6625 |
| L13 | Kijkrichting + vallen | stage-richting, vy<0 | facing moet naar binnen; positie moet dalen; geen grab als ECB-clamp | [S] ledges.md, [D] | ✅ | geen |
| L14 | Toegestane states | zie #14 | idem | [N] | ❌ | zie #14 |

Samenvatting getup-tabel (aanbevolen defaults, bron [P], gemiddeld Marth/Fox/Peach/Pikachu; Ganondorf wijkt af: climb-intangible tot f23, roll f25):

| optie | quick (<100%) frames / intangible-einde | slow (>=100%) frames / intangible-einde |
|---|---|---|
| climb | 34 / f31 | 60 / f56 |
| roll | 50 / f35 | 80 / f60 |
| attack | 55 / f21 (hit f24) | 70 / f45 (hit f40) |
| jump (wacht) | 15 / hele wachttijd | 21 / hele wachttijd |

## 4. Respawn (priority 3)

| ID | Punt | Project | Melee | Bron | Zekerheid | Aanbeveling |
|---|---|---|---|---|---|---|
| R1 | Platform max-tijd | 300 f (5 s) | `rebirth_wait` (PlCo); [W] "5 seconden" | [D] `ftCo_RebirthWait_Anim`, [W] Rebirth platform (niet Melee-specifiek) | ✅ (waarde uit wiki) | geen |
| R2 | Invincibility na platform | 120 | `x5D8` toegepast bij uitlopen **en** bij input (`ftColl_8007B7A4`); [W] 2 s = 120 | [D] ft_0D4D.c, [W] | ✅ | geen |
| R3 | Daling naar platform | instant `RebirthWait` | `Rebirth`-state interpoleert `rebirth_countdown` frames naar de platformpositie, niet onderbreekbaar | [D] `ftCo_Rebirth_Phys/Anim` | ❌ (structuur), duur ❓ | optioneel: descent-fase (waarde onbekend; ~ twee seconden geschat) |
| R4 | Min. 20 frames voor exit | 20 | geen minimum zichtbaar in `ftCo_RebirthWait_IASA` (special, jump, attack, shield, stick -> `Fall_Enter`) | [D] | ❓ | laat 20 staan (vangt het geplakte-input-geval) |
| R5 | Vertraging KO -> respawn | 120 (`ui.md`) | niet in decomp-data/wiki gevonden | - | ❓ | laten |
| R6 | Respawn-positie | (0, 60) voor allen | platforms staan van links naar rechts als P3, P4, P1, P2; coordinaten niet gevonden | [W] FD-pagina | ❓ | per speler spreiden (-?, 0, +?) |

## 5. Movement (priority 4)

| ID | Punt | Project | Melee | Bron | Zekerheid | Aanbeveling |
|---|---|---|---|---|---|---|
| M1 | Fast-fall-drempel/venster | 0.6625 / 4 | structuur: `vy < 0` strikt, `y <= -x88`, stick-timer `< x8C` (`ftCommon_CheckFallFast`); waarden niet gevonden | [D] `ftcommon.c:511` | ❓ waarde, ✅ regel | geen |
| M2 | Crouch-drempel | 0.6875 | `y < -x90` (`ftCo_Squat_CheckInput`); waarde onbekend | [D] | ❓ | geen |
| M3 | Platform-drop | 0.6875 / 4, `vy = x46C` | `y <= -x464`, timer `< x468`, op platform; shield-variant eist dezelfde verse flick; `pass_delay x470` | [D] `ftCo_Pass.c` | ❓ waarde; shield-regel ❌ | zie #20 |
| M4 | RunBrake / RunTurn / Turn | brake 18-24, runturn 20-30, turn 11 | RunBrake = anim: Fox 18, Marth 26, Ganon 28, Peach 23, Pikachu 20; TurnRun: 20 / 30 / 22 / 22 / 20; Turn-anim 12, omdraai-moment `standing_turn_frames`: Fox 4, Marth 6, Ganon 7, Peach 6, Pikachu 4; Squat 8, SquatRv 8-10; `max_run_brake_frames` = 30 voor allen | [P], [D] `ftCo_RunBrake_Enter`, `ftCo_Turn_Enter_Basic` | ❌ | preset-velden bijwerken; `turn_frames` 11 mag (anim 12) |
| M5 | Landing lag 4 | 4 | `normal_landing_lag`: 4 voor Fox/Marth/Peach/Pikachu/Falco/Sheik, Ganondorf/DK 5, Bowser 6, Pichu 2 | [P], [W] Landing lag | ✅ (generiek) / ❌ Ganondorf | zie #17 |
| M6a | Airdodge-kracht/decay | 3.1 / 0.9 | `escapeair_force` 3.1, `escapeair_decay` 0.9 (elke frame x0.9 tot event "skip decay") | [N] disc, [D] `ftCo_EscapeAir_Phys` | ✅ | geen |
| M6b | Airdodge-duur/intangible | 49 f, intangible 4-29 (Peach 4-19) | anim 50; `body2` f4-f30 (Peach/Zelda f20) | [P], [W] | ✅ | geen |
| M6c | Landing lag na airdodge | 10 | `x344` = 10, special-fall `mobility x340` | [N], [W] | ✅ (10), mobility ❓ | geen |
| M7 | Ground->air momentum | formule + 0.7/0.75 | formule `vx = clamp(self_vel*g2a*mul + stick*hInit*mul, +-hMax*mul)`; `vy x= x438` | [D] `ftCo_800CB110` | ✅ formule, ❌ waarden | tabel hieronder |
| M8 | Jump h-initial / h-max | zie tabel | zie tabel | [P] | ❌ | tabel |
| M9 | Double jump h (`air_jump_h`) | 0.85-1.0 | `air_jump_h_multiplier` ("doubleJumpMomentum") per character | [D] `ftCo_JumpAerial.c`, [P] | ❌ | tabel |
| M10 | Dash/smash-drempel + venster | 0.8 / 2 (4 voor Xbox) | `x3C` = 0.8, venster `x40` = 2 | [N] | ✅ | Xbox-leniency blijft bewuste afwijking |
| M11 | Tap-jump / relaxed | 0.6625 / 4, 0.5625 | idem | [D] `@datvalue` | ✅ | geen |
| M12 | Turn-drempel | 0.2875 | `x34` = -0.25 (effectief eerste rasterstap na deadzone 0.28) | [N], [D] `ftCo_800C97A8` | ✅ | geen |
| M13 | Run-drempel | 0.62 | `x58`, waarde onbekend | [D] | ❓ | geen |
| M14 | Teeter-drempel | 0.75 | Teeter-modus stopt aan de rand onder stick 0.75 | [N] | ✅ | geen |
| M15 | Deadzones / trigger | 0.28 / 0.25 / 0.3 / 0.35 / 0.25 | idem | [D] `@datvalue` | ✅ | geen |
| M16 | Walk-accel | zie tabel | per character [P] | [P] | ❌ | zie #18 |

Preset-vergelijking (bron [P]; kolom "nu" = onze `.tres`):

| Preset (ref) | g2a nu -> Melee | h-initial nu -> Melee | h-max nu -> Melee | air_jump_h nu -> Melee | walk init/accel nu -> Melee | RunBrake / TurnRun nu -> Melee |
|---|---|---|---|---|---|---|
| allrounder (Marth) | 0.7 -> **0.8** | 0.9 -> **1.0** | 1.5 -> **1.2** | 1.0 -> 1.0 ✅ | 0.15/0.08 -> 0.15/**0** | 22/28 -> **26/30** |
| fast_faller (Fox) | 0.75 -> **0.83** | 0.72 ✅ | 1.7 ✅ | 0.9 ✅ | 0.2/0.1 ✅ | 18/20 ✅ |
| heavyweight (Ganondorf) | 0.7 -> **0.75** | 0.8 -> **0.9** | 1.2 -> **1.8** | 0.85 -> **1.0** | 0.1/0.05 -> **0.08/0** | 24/30 -> **28/22**; landing 4 -> **5** |
| floaty (Peach) | 0.7 ✅ | 0.8 -> **0.7** | 1.1 ✅ | 1.0 -> **0.9** | 0.1/0.06 -> **0.2/0.1** | 22/28 -> **23/22**; dash_initial 1.3 -> **1.2**; dash accel 0.02/0.06 -> **0.02/0.1** |
| lightweight (Pikachu) | 0.75 -> **0.8** | 0.9 -> **0.8** | 1.5 -> **1.8** | 0.9 -> **0.8** | 0.15/0.1 ✅ | 18/20 -> **20/20** |

Gewoon bevestigd in dezelfde dump: Fox/Marth/Ganon/Peach/Pikachu gravity, terminal, fast fall, weight, walk-max, dash-initial (behalve Peach), jumpsquat, ledge-jump-kolommen in `docs/melee-referentie.md`.
`standing_turn_frames` (4/6/7/6/4) en Turn-anim (12) zijn nu "niet verzameld" in `movement.md`: dit is de ontbrekende waarde.

## 6. Stage (priority 5)

| ID | Punt | Project | Melee | Bron | Zekerheid | Aanbeveling |
|---|---|---|---|---|---|---|
| S1 | FD rand-x | 85.5657 | 85.5657 (+ hangpositie 88.4735) | [L] `stages.py` | ✅ | geen |
| S2 | Blast zones | -246/246/188/-140 | idem (L, R, boven, onder) | [L] | ✅ | geen |
| S3 | Camera bounds | x -200..200, y -85..140 | niet gevonden (stage-`.dat`, niet in decomp/libmelee) | - | ❓ | laten |
| S4 | Spawns P1..P4 | (-30,0) (30,0) (-60,0) (60,0) | niet gevonden | - | ❓ | laten |
| S5 | Respawn-platforms | (0,60) allen | volgorde L->R: P3, P4, P1, P2; coordinaten niet gevonden | [W] FD-pagina | ❓ | spreid ze in die volgorde |

## 7. Wat de decomp nog oplevert voor latere sessies
- `ftCo_Damage_CalcAngle`, `ftCo_Damage_CalcKnockback`, `ftCo_8008E5A4` (DI), `ftCo_Damage_OnEveryHitlag` / `OnExitHitlag` (SDI/ASDI) en `ftCliffCommon_80081298` (ledge-grab) zijn kleine, goed leesbare functies; vertaal ze 1-op-1.
- Waarden uit `PlCo.dat` kun je zelf uitlezen met de offsets in `struct ftCommonData` (`types.h`) uit een eigen NTSC 1.02-disc;
  DreamsVibe/melee-web-fighter `src/shared/attributes.ts` bevat een bruikbare offset->naam-lijst (onder meer `0x88` fast fall, `0x90` squat, `0x464-0x470` platform pass, `0x480-0x49C` ledge, `0x4B0-0x4C0` SDI, `0x424` down wait, `0x5D0-0x5D8` rebirth). Zonder disc blijven die ❓.
- `[P]` bevat voor alle 24 characters attributen + animatielengtes + intangibility-events; handig voor `characters/*` en voor `LEDGE_OPTION_DEFAULTS`.
