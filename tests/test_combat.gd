extends SceneTree
## Headless test voor engine/combat (knockback, hitlag, resolver, MoveData).
## Run: Godot --headless --path . --script res://tests/test_combat.gd

var _fails: int = 0
var _total: int = 0


func _initialize() -> void:
	_test_knockback()
	_test_angles()
	_test_di()
	_test_hitlag_shieldstun()
	_test_move_data()
	_test_resolver()
	_test_determinism()
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name)


func _near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _hb(id: int = 0, off: Vector2 = Vector2(5, 10), r: float = 3.0, dmg: float = 10.0) -> HitboxData:
	var h := HitboxData.new()
	h.id = id
	h.offset = off
	h.radius = r
	h.damage = dmg
	h.start_frame = 0
	h.end_frame = 5
	return h


func _target(id: int, pos: Vector2 = Vector2.ZERO) -> CombatTarget:
	var t := CombatTarget.new()
	t.id = id
	t.origin = pos
	t.hurtboxes = HurtboxData.default_for_height(16.0)
	t.grounded = true
	return t


func _hb_kb(target_kb: float) -> HitboxData:
	# BKB = target_kb en growth 0: KB = base.
	var h := HitboxData.new()
	h.base_kb = target_kb
	h.kb_growth = 0.0
	h.angle = 45.0
	return h


func _res(hit_boxes: Array[ActiveHitbox], targets: Array[CombatTarget], already: Dictionary = {}) -> HitResolver.Result:
	return HitResolver.resolve(hit_boxes, targets, already)


func _test_knockback() -> void:
	# Kill-richtlijn uit move-conversie.md (KB ~190 bij w=100): p = percentage na de hit.
	_check("Marth fsmash tip 90% -> ~190", _near(Knockback.raw_kb(90, 20, 100, 70, 80), 190.0, 1.0))
	_check("Fox jab 410% -> ~190", _near(Knockback.raw_kb(410, 4, 100, 100, 0), 190.0, 1.0))
	_check("Bowser fsmash 78% -> ~190", _near(Knockback.raw_kb(78, 24, 100, 100, 30), 190.0, 1.0))
	_check("Zwaarder = minder KB", Knockback.raw_kb(100, 10, 120, 100, 20) < Knockback.raw_kb(100, 10, 80, 100, 20))
	_check("set KB onafhankelijk van %", _near(Knockback.raw_kb(10, 5, 100, 100, 20, 30.0), Knockback.raw_kb(200, 5, 100, 100, 20, 30.0), 0.001))
	_check("hitstun floor(KB*0.4)", Knockback.hitstun_frames(100.0) == 40 and Knockback.hitstun_frames(77.9) == 31)
	_check("launch speed KB*0.03", _near(Knockback.launch_speed(100.0), 3.0, 0.0001))
	var v := Vector2(3, 0)
	var n: int = 0
	while v.length() > 0.0 and n < 1000:
		v = Knockback.decay_step(v)
		n += 1
	_check("decay 0.051/frame: 3.0 -> 0 in 59 frames", n == 59)
	var v2: Vector2 = Knockback.decay_step(Vector2(3, 4))
	_check("decay behoudt richting", _near(v2.length(), 5.0 - 0.051, 0.0001) and _near(v2.x / v2.y, 0.75, 0.0001))
	_check("tumble bij KB >= 80", Knockback.compute(_hb_kb(80.0), 1.0, 0.0, 100.0, false, false, 1).tumble)
	_check("geen tumble onder 80", not Knockback.compute(_hb_kb(70.0), 1.0, 0.0, 100.0, false, false, 1).tumble)
	var h := _hb_kb(60.0)
	var normal: KnockbackResult = Knockback.compute(h, 1.0, 0.0, 100.0, true, false, 1)
	var cc: KnockbackResult = Knockback.compute(h, 1.0, 0.0, 100.0, true, true, 1)
	_check("crouch cancel x2/3", cc.crouch_cancelled and _near(cc.kb, normal.kb * 2.0 / 3.0, 0.0001))
	_check("crouch cancel alleen op de grond", not Knockback.compute(h, 1.0, 0.0, 100.0, false, true, 1).crouch_cancelled)
	_check("crouch cancel verkort hitstun", cc.hitstun < normal.hitstun)


func _test_angles() -> void:
	_check("361 grond lage KB -> 0", Knockback.resolve_angle(361, 20.0, true) == 0.0)
	_check("361 grond KB>=32 -> 44", Knockback.resolve_angle(361, 32.0, true) == 44.0)
	_check("361 lucht -> 45", Knockback.resolve_angle(361, 10.0, false) == 45.0)
	_check("normale hoek ongewijzigd", Knockback.resolve_angle(80, 10.0, false) == 80.0)
	var h := HitboxData.new()
	h.angle = 30.0
	h.kb_growth = 0.0
	h.base_kb = 50.0
	var r: KnockbackResult = Knockback.compute(h, 1, 0, 100, false, false, 1)
	var l: KnockbackResult = Knockback.compute(h, 1, 0, 100, false, false, -1)
	_check("facing links spiegelt x", _near(r.launch_vel.x, -l.launch_vel.x, 0.0001) and _near(r.launch_vel.y, l.launch_vel.y, 0.0001))
	_check("launch speed = kb*0.03", _near(r.launch_vel.length(), 1.5, 0.0001))
	var g: KnockbackResult = Knockback.compute(_hb_kb(20.0), 1, 0, 100, true, false, 1)
	_check("grond + omhoog-hoek wordt gelanceerd", not g.stays_grounded)
	var flat := HitboxData.new()
	flat.angle = 361.0
	flat.kb_growth = 0.0
	flat.base_kb = 20.0
	var f: KnockbackResult = Knockback.compute(flat, 1, 0, 100, true, false, 1)
	_check("361 laag op de grond blijft grounded", f.stays_grounded and f.angle == 0.0)


func _test_di() -> void:
	var v := Vector2(2, 0)
	_check("DI zonder stick = geen verandering", Knockback.apply_di(v, Vector2.ZERO).is_equal_approx(v))
	_check("DI parallel aan launch = geen verandering", Knockback.apply_di(v, Vector2(1, 0)).is_equal_approx(v))
	var up: Vector2 = Knockback.apply_di(v, Vector2(0, 1))
	_check("DI max 18 graden", _near(rad_to_deg(up.angle()), 18.0, 0.001) and _near(up.length(), 2.0, 0.0001))
	var dn: Vector2 = Knockback.apply_di(v, Vector2(0, -1))
	_check("DI andere kant -18", _near(rad_to_deg(dn.angle()), -18.0, 0.001))
	_check("DI nooit meer dan 18 (overshoot)", absf(Knockback.di_angle_delta(v, Vector2(0, 5))) <= 18.0)
	_check("DI half stick = 4.5 graden (kwadratisch)", _near(Knockback.di_angle_delta(v, Vector2(0, 0.5)), 4.5, 0.001))
	_check("DI half stick omlaag = -4.5 (teken blijft)", _near(Knockback.di_angle_delta(v, Vector2(0, -0.5)), -4.5, 0.001))
	_check("DI apply_di half stick = 4.5 graden", _near(rad_to_deg(Knockback.apply_di(v, Vector2(0, 0.5)).angle()), 4.5, 0.001))
	_check("SDI stick 0.8 = 4.8 units (niet genormaliseerd)", Knockback.sdi_offset(Vector2.ZERO, Vector2(0.8, 0)).is_equal_approx(Vector2(4.8, 0)))
	_check("SDI diagonaal = stick x 6", Knockback.sdi_offset(Vector2.ZERO, Vector2(0.75, 0.75)).is_equal_approx(Vector2(4.5, 4.5)))
	_check("ASDI stick 0.8 = 2.4 units", Knockback.asdi_offset(Vector2(0, -0.8)).is_equal_approx(Vector2(0, -2.4)))
	_check("SDI flick = 6 units", Knockback.sdi_offset(Vector2.ZERO, Vector2(1, 0)).is_equal_approx(Vector2(6, 0)))
	_check("SDI vastgehouden stick = niets", Knockback.sdi_offset(Vector2(1, 0), Vector2(1, 0)) == Vector2.ZERO)
	_check("ASDI = 3 units", Knockback.asdi_offset(Vector2(0, -1)).is_equal_approx(Vector2(0, -3)))
	_check("ASDI onder drempel = niets", Knockback.asdi_offset(Vector2(0.3, 0)) == Vector2.ZERO)


func _test_hitlag_shieldstun() -> void:
	_check("hitlag d=4 -> 4", Knockback.hitlag_frames(4.0) == 4)
	_check("hitlag d=20 -> 9", Knockback.hitlag_frames(20.0) == 9)
	_check("hitlag electric: aanvaller geen x1.5 (d=20 -> 9)", Knockback.hitlag_frames(20.0, HitboxData.Element.ELECTRIC) == 9)
	_check("hitlag electric slachtoffer int(9*1.5) = 13", Knockback.hitlag_frames(20.0, HitboxData.Element.ELECTRIC, 1.0, true) == 13)
	_check("hitlag mult 0.5", Knockback.hitlag_frames(20.0, HitboxData.Element.NORMAL, 0.5) == 4)
	_check("hitlag integer damage (3.9 -> 3 -> 4)", Knockback.hitlag_frames(3.9) == 4 and Knockback.hitlag_frames(5.9) == 4 and Knockback.hitlag_frames(6.0) == 5)
	_check("hitlag crouch slachtoffer x2/3 (d=20: int(9*2/3)=6)", Knockback.hitlag_frames(20.0, HitboxData.Element.NORMAL, 1.0, true, true) == 6)
	_check("hitlag crouch telt niet voor aanvaller", Knockback.hitlag_frames(20.0, HitboxData.Element.NORMAL, 1.0, false, true) == 9)
	_check("hitlag cap 20", Knockback.hitlag_frames(60.0, HitboxData.Element.ELECTRIC, 1.0, true) == 20 and Knockback.hitlag_frames(90.0) == 20)
	_check("hitlag vlak onder cap: d=45 -> 18", Knockback.hitlag_frames(45.0) == 18)
	# Resolver: slachtoffer-hitlag apart van aanvaller-hitlag
	var el: HitboxData = _hb(0, Vector2.ZERO, 3.0, 20.0)
	el.element = HitboxData.Element.ELECTRIC
	var tv := _target(2)
	var er: HitResolver.Result = _res([_ah(el, 1, 1, Vector2(0, 8))], [tv])
	_check("resolver: electric aanvaller 9, slachtoffer 13", er.hits.size() == 1 and er.hits[0].attacker_hitlag == 9 and er.hits[0].defender_hitlag == 13)
	var tc := _target(2)
	tc.crouching = true
	var cr: HitResolver.Result = _res([_ah(_hb(0, Vector2.ZERO, 3.0, 20.0), 1, 1, Vector2(0, 8))], [tc])
	_check("resolver: crouching slachtoffer 6, aanvaller 9", cr.hits.size() == 1 and cr.hits[0].attacker_hitlag == 9 and cr.hits[0].defender_hitlag == 6)
	# Shieldstun analoog: (s - 0.3)/0.7
	_check("shield_norm", _near(Knockback.shield_norm(1.0), 1.0, 0.0001) and _near(Knockback.shield_norm(0.65), 0.5, 0.0001) and Knockback.shield_norm(0.2) == 0.0)
	_check("shieldstun s=0.65 d=20: a=0.5", Knockback.shieldstun_frames(20.0, 0.65) == int(floor(200.0 / 201.0 * (20.0 * (0.65 * 0.5 + 0.3) * 1.5 + 2.0))))
	_check("shieldstun s=0.307 factor ~0.95 (d=20)", Knockback.shieldstun_frames(20.0, 0.307) == int(floor(200.0 / 201.0 * (20.0 * (0.65 * 0.99 + 0.3) * 1.5 + 2.0))))
	# Smash-charge x1.2 voor het slachtoffer
	var ch: HitboxData = _hb_kb(60.0)
	var k0: KnockbackResult = Knockback.compute(ch, 1.0, 0.0, 100.0, false, false, 1)
	var k1: KnockbackResult = Knockback.compute(ch, 1.0, 0.0, 100.0, false, false, 1, true)
	_check("charging slachtoffer KB x1.2", _near(k1.kb, k0.kb * 1.2, 0.0001) and k1.hitstun >= k0.hitstun)
	var tch := _target(2)
	tch.charging = true
	var chr: HitResolver.Result = _res([_ah(_hb(0, Vector2.ZERO, 3.0, 20.0), 1, 1, Vector2(0, 8))], [tch])
	var chn: HitResolver.Result = _res([_ah(_hb(0, Vector2.ZERO, 3.0, 20.0), 1, 1, Vector2(0, 8))], [_target(2)])
	_check("resolver geeft CombatTarget.charging door", chr.hits.size() == 1 and _near(chr.hits[0].knockback.kb, chn.hits[0].knockback.kb * 1.2, 0.0001))
	for d in [4.0, 10.0, 13.0, 20.0, 24.0]:
		_check("shieldstun d=%d volle shield = floor(0.448d+2)" % int(d), Knockback.shieldstun_frames(d, 1.0) == int(floor(0.448 * d + 2.0)))
	_check("lichte shield = meer shieldstun", Knockback.shieldstun_frames(20.0, 0.0) > Knockback.shieldstun_frames(20.0, 1.0))


func _test_move_data() -> void:
	var m := MoveData.new()
	m.total_frames = 40
	m.landing_lag = 20
	m.lcancel_lag = 10
	m.autocancel_before = 4
	m.autocancel_after = 30
	var h := _hb(0, Vector2(6, 8))
	h.start_frame = 5
	h.end_frame = 8
	h.late_from = 7
	m.hitboxes = [h]
	_check("hitbox niet actief voor start", m.active_hitboxes(4, Vector2.ZERO, 1, 0, 1).is_empty())
	_check("hitbox actief op start en einde", m.active_hitboxes(5, Vector2.ZERO, 1, 0, 1).size() == 1 and m.active_hitboxes(8, Vector2.ZERO, 1, 0, 1).size() == 1)
	_check("hitbox niet actief na einde", m.active_hitboxes(9, Vector2.ZERO, 1, 0, 1).is_empty())
	var right: Array[ActiveHitbox] = m.active_hitboxes(5, Vector2(100, 0), 1, 0, 1)
	var left: Array[ActiveHitbox] = m.active_hitboxes(5, Vector2(100, 0), -1, 0, 1)
	_check("facing spiegelt offset", right[0].pos == Vector2(106, 8) and left[0].pos == Vector2(94, 8))
	_check("late-vlag", not right[0].late and m.active_hitboxes(7, Vector2.ZERO, 1, 0, 1)[0].late)
	_check("landing lag normaal", m.landing_lag_at(15, false) == 20)
	_check("landing lag L-cancel", m.landing_lag_at(15, true) == 10)
	_check("auto-cancel vroeg en laat", m.landing_lag_at(2, false) == 0 and m.landing_lag_at(31, false) == 0)
	_check("IASA default = total_frames", m.iasa_frame() == 40)
	var hr := HurtboxData.make(Vector2(2, 0), Vector2(2, 10), 3.0)
	_check("hurtbox spiegelt met facing", hr.world_a(Vector2.ZERO, -1) == Vector2(-2, 0))


func _ah(d: HitboxData, owner: int, inst: int, pos: Vector2, facing: int = 1) -> ActiveHitbox:
	return ActiveHitbox.make(d, owner, inst, pos, facing)


func _test_resolver() -> void:
	var t := _target(2)
	var hit: ActiveHitbox = _ah(_hb(0, Vector2(0, 8), 3.0), 1, 1, Vector2(0, 8))
	var res: HitResolver.Result = _res([hit], [t])
	_check("overlap geeft HIT", res.hits.size() == 1 and res.hits[0].kind == HitEvent.Kind.HIT and res.hits[0].defender == 2)
	_check("HIT: knockback + hitfall toegestaan", res.hits[0].knockback != null and res.hits[0].attacker_hitfall_allowed and not res.hits[0].is_shield_hit())
	_check("hitlag gelijk voor beide", res.hits[0].attacker_hitlag == res.hits[0].defender_hitlag and res.hits[0].attacker_hitlag > 0)
	_check("geen overlap = geen hit", _res([_ah(_hb(), 1, 1, Vector2(50, 8))], [t]).hits.is_empty())
	_check("eigen hurtbox genegeerd", _res([_ah(_hb(), 2, 1, Vector2(0, 8))], [t]).hits.is_empty())
	_check("cirkel-capsule afstand", HitResolver.circle_hits_capsule(Vector2(4, 5), 1.5, Vector2(0, 0), Vector2(0, 10), 3.0)
		and not HitResolver.circle_hits_capsule(Vector2(6, 5), 1.5, Vector2(0, 0), Vector2(0, 10), 3.0))
	var already: Dictionary = {res.hits[0].key: true}
	_check("already_hit voorkomt herhaling", _res([hit], [t], already).hits.is_empty())
	var g1: HitboxData = _hb(1, Vector2(0, 8), 3.0)
	g1.group = 1
	_check("andere groep raakt wel", _res([_ah(g1, 1, 1, Vector2(0, 8))], [t], already).hits.size() == 1)
	_check("nieuwe move-instantie raakt wel", _res([_ah(_hb(), 1, 2, Vector2(0, 8))], [t], already).hits.size() == 1)
	var hi: ActiveHitbox = _ah(_hb(3, Vector2(0, 8), 3.0, 4.0), 1, 1, Vector2(0, 8))
	var lo: ActiveHitbox = _ah(_hb(1, Vector2(0, 9), 3.0, 12.0), 1, 1, Vector2(0, 9))
	var pr: HitResolver.Result = _res([hi, lo], [t])
	_check("prioriteit: één hit, laagste id", pr.hits.size() == 1 and pr.hits[0].hitbox.data.id == 1)
	_check("raakt meerdere doelwitten", _res([hit], [t, _target(3)]).hits.size() == 2)
	# Clank
	var a: ActiveHitbox = _ah(_hb(0, Vector2.ZERO, 4.0, 10.0), 1, 1, Vector2(20, 8))
	var b: ActiveHitbox = _ah(_hb(0, Vector2.ZERO, 4.0, 12.0), 3, 1, Vector2(24, 8), -1)
	var cl: HitResolver.Result = _res([a, b], [])
	_check("clank: gelijkwaardig, beide rebounden", cl.clanks.size() == 1 and cl.clanks[0].attacker_rebounds and cl.clanks[0].defender_rebounds)
	var strong: ActiveHitbox = _ah(_hb(0, Vector2.ZERO, 4.0, 25.0), 3, 1, Vector2(24, 8), -1)
	var cl2: HitResolver.Result = _res([a, strong], [])
	_check("clank: verschil >= 9, alleen zwakste rebound", cl2.clanks.size() == 1 and cl2.clanks[0].attacker_rebounds and not cl2.clanks[0].defender_rebounds)
	var victim := _target(9, Vector2(24, 0))
	var cl3: HitResolver.Result = _res([a, strong], [victim])
	_check("sterkere hitbox raakt na clank nog door", cl3.hits.size() == 1 and cl3.hits[0].attacker == 3)
	_check("na onderlinge clank raken beide niet", _res([a, b], [victim]).hits.is_empty())
	var nc: HitboxData = _hb(0, Vector2.ZERO, 4.0, 10.0)
	nc.clank = false
	_check("clank=false clankt niet", _res([_ah(nc, 1, 1, Vector2(20, 8)), b], []).clanks.is_empty())
	_check("geen clank binnen eigen hitboxen", _res([a, _ah(_hb(1, Vector2.ZERO, 4.0, 10.0), 1, 1, Vector2(21, 8))], []).clanks.is_empty())
	# Shield
	var s := _target(2)
	s.shielding = true
	s.shield_center = Vector2(0, 8)
	s.shield_radius = 10.0
	s.shield_analog = 1.0
	var sr: HitResolver.Result = _res([_ah(_hb(0, Vector2.ZERO, 3.0, 20.0), 1, 1, Vector2(11, 8))], [s])
	_check("shield-hit: SHIELD zonder knockback, geen hitfall", sr.hits.size() == 1 and sr.hits[0].kind == HitEvent.Kind.SHIELD and sr.hits[0].knockback == null
		and sr.hits[0].is_shield_hit() and not sr.hits[0].attacker_hitfall_allowed)
	_check("shield-hit: shieldstun + shield damage", sr.hits[0].shield_stun == Knockback.shieldstun_frames(20.0, 1.0) and sr.hits[0].shield_damage >= 20.0)
	var gr := _hb(0, Vector2.ZERO, 3.0, 5.0)
	gr.ignores_shield = true
	var gres: HitResolver.Result = _res([_ah(gr, 1, 1, Vector2(0, 8))], [s])
	_check("ignores_shield raakt de hurtbox", gres.hits.size() == 1 and gres.hits[0].kind == HitEvent.Kind.HIT)
	_check("shield-radius begrenst", _res([_ah(_hb(0, Vector2.ZERO, 3.0, 20.0), 1, 1, Vector2(30, 8))], [s]).hits.is_empty())
	# Intangible / invincible
	var it := _target(2)
	it.intangible = true
	_check("intangible doelwit genegeerd", _res([hit], [it]).hits.is_empty())
	var iv := _target(2)
	iv.invincible = true
	_check("invincible doelwit genegeerd", _res([hit], [iv]).hits.is_empty())
	var ih := _target(2)
	for hbx in ih.hurtboxes:
		hbx.intangible = true
	_check("alle hurtboxes intangible = geen hit", _res([hit], [ih]).hits.is_empty())
	var go: HitboxData = _hb(0, Vector2(0, 8), 3.0)
	go.grounded_only = true
	var air := _target(2)
	air.grounded = false
	_check("grounded_only raakt geen luchtdoel", _res([_ah(go, 1, 1, Vector2(0, 8))], [air]).hits.is_empty())
	_check("grounded_only raakt grounddoel", _res([_ah(go, 1, 1, Vector2(0, 8))], [t]).hits.size() == 1)
	var tp := _target(2)
	tp.percent = 50.0
	_check("resolver-KB groeit met percentage", _res([hit], [tp]).hits[0].knockback.kb > res.hits[0].knockback.kb)


func _determinism_run() -> String:
	var boxes: Array[ActiveHitbox] = []
	for i in 6:
		boxes.append(_ah(_hb(i % 3, Vector2(0, 5 + i), 3.0, 4.0 + i), i % 2 + 1, i, Vector2(i * 2, 8)))
	var targets: Array[CombatTarget] = [_target(7), _target(8, Vector2(3, 0))]
	var r: HitResolver.Result = HitResolver.resolve(boxes, targets)
	var s: String = ""
	for e in r.hits:
		s += "%s:%d>%d:%.4f;" % [e.key, e.attacker, e.defender, e.knockback.kb if e.knockback else -1.0]
	for e in r.clanks:
		s += "C%d%d;" % [e.attacker, e.defender]
	return s


func _test_determinism() -> void:
	var a: String = _determinism_run()
	var b: String = _determinism_run()
	_check("resolver deterministisch", a == b and a != "")
