extends SceneTree
## Headless test voor de VFX. Draaien:
##   Godot_console.exe --headless --path . --script res://tests/test_vfx.gd

var _fails: int = 0
var _total: int = 0


func _initialize() -> void:
	_test_spawn_and_cleanup()
	_test_ko()
	_test_shake()
	_test_determinism()
	_test_flash()
	print("")
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name)


func _layer() -> VfxLayer:
	var l := VfxLayer.new()
	l.auto_register = false
	root.add_child(l)
	return l


func _run_frames(l: VfxLayer, n: int) -> void:
	for f in n:
		l.vfx_tick(f)


func _test_spawn_and_cleanup() -> void:
	var l: VfxLayer = _layer()
	var target := Node2D.new()
	root.add_child(target)
	var made: Array[VfxEffect] = []
	for el in 6:
		made.append(l.spawn_hit(Vector2(10, 5), float(el) / 5.0, el, 40.0 * el))
	made.append(l.spawn_hit(Vector2(0, 0), 1.0, 0, 0.0, true))
	made.append(l.spawn_hit(Vector2(0, 0), 5.0, 0, 0.0))        # strength buiten bereik wordt geklemd
	made.append(l.spawn_shield_hit(Vector2(0, 10), 0.5))
	made.append(l.spawn_clank(Vector2(0, 10)))
	made.append(l.spawn_land_dust(Vector2.ZERO, true))
	made.append(l.spawn_land_dust(Vector2.ZERO, false))
	made.append(l.spawn_jump_dust(Vector2.ZERO))
	made.append(l.spawn_dash_dust(Vector2.ZERO, -1))
	made.append(l.spawn_airdodge_trail(Vector2.ZERO, 30.0))
	made.append(l.spawn_airdodge_trail(Vector2.ZERO))
	made.append(l.spawn_launch_trail(target, 40))
	made.append(l.spawn_respawn(Vector2(0, 60)))
	var ok: bool = true
	for e in made:
		if e == null:
			ok = false
	check("alle spawn-functies leveren een effect", ok)
	check("active_count klopt", l.active_count() == made.size())
	check("hit klemt strength", (made[7] as HitEffect).strength == 1.0)
	check("positie via Units (y omhoog)", (made[0] as HitEffect).position == Units.to_px(Vector2(10, 5)))
	var longest: int = 0
	for e in made:
		longest = maxi(longest, e.duration)
	check("alle effecten korter dan 90 frames", longest <= 90)
	_run_frames(l, 1)
	check("na 1 frame nog actief", l.active_count() == made.size())
	_run_frames(l, 100)
	check("effecten ruimen zichzelf op", l.active_count() == 0)
	# trail: target verdwijnt halverwege, geen fouten
	var t2 := Node2D.new()
	root.add_child(t2)
	l.spawn_launch_trail(t2, 40)
	_run_frames(l, 5)
	t2.free()
	_run_frames(l, 80)
	check("launch trail overleeft verdwenen target", l.active_count() == 0)
	# dust uit
	l.dust_enabled = false
	check("dust uitgeschakeld", l.spawn_jump_dust(Vector2.ZERO) == null)
	l.clear()
	check("clear leegt alles", l.active_count() == 0)
	# frozen: zonder vfx_tick verandert niets
	var h: HitEffect = l.spawn_hit(Vector2.ZERO, 0.5)
	var a0: int = h.age
	check("zonder tick geen voortgang (pauze)", h.age == a0 and a0 == 0)
	l.queue_free()
	target.queue_free()


func _test_ko() -> void:
	var l: VfxLayer = _layer()
	var pc := Color(1, 0.3, 0.3)
	var fb: KoEffect = l.spawn_ko("bestaat_niet", Vector2(-246, 20), VfxConst.SIDE_LEFT, pc)
	check("KO fallback is DefaultKoEffect", fb is DefaultKoEffect)
	check("KO fallback met lege id", l.spawn_ko("", Vector2(0, 188), VfxConst.SIDE_TOP, pc) is DefaultKoEffect)
	var dm: KoEffect = l.spawn_ko("_dummy", Vector2(246, 0), VfxConst.SIDE_RIGHT, pc)
	check("dummy heeft eigen KO-effect", dm != null and not (dm is DefaultKoEffect) and dm.character_id == "_dummy")
	check("dummy KO leest karakterkleuren", dm.primary().is_equal_approx(Color.html("#c9a26b")))
	check("KO richting links -> naar rechts", fb.dir == Vector2.RIGHT and dm.dir == Vector2.LEFT)
	check("KO duur <= 90", fb.duration <= VfxConst.KO_MAX_FRAMES and dm.duration <= VfxConst.KO_MAX_FRAMES)
	for side in 4:
		var e: KoEffect = l.spawn_ko("_dummy", Vector2.ZERO, side, pc)
		check("KO zijde %d heeft richting naar binnen" % side, e.dir == VfxConst.inward_dir(side) and e.dir.length() > 0.99)
	_run_frames(l, 100)
	check("KO-effecten ruimen zichzelf op", l.active_count() == 0)
	# klemmen op camera bounds
	l.ko_clamp_rect_units = Rect2(-200, -85, 400, 225)
	var cl: KoEffect = l.spawn_ko("", Vector2(-246, 300), VfxConst.SIDE_LEFT, pc)
	check("KO geklemd op rect", cl.position.is_equal_approx(Units.to_px(Vector2(-200, 140))))
	# een te lang effect wordt geklemd
	var src := GDScript.new()
	src.source_code = "extends KoEffect\nfunc _on_ko_setup() -> void:\n\tduration = 500\n"
	src.reload()
	var long_ko: KoEffect = src.new()
	long_ko.setup_ko(Vector2.ZERO, 0, pc, PackedColorArray())
	check("duur geklemd op %d" % VfxConst.KO_MAX_FRAMES, long_ko.duration == VfxConst.KO_MAX_FRAMES)
	long_ko.free()
	l.queue_free()


func _shake_run(cam: MatchCamera) -> Array[Vector2]:
	cam.reset_shake()
	cam.shake(2.0, 10)
	var out: Array[Vector2] = []
	for i in 12:
		cam.shake_tick()
		out.append(cam.offset)
	return out


func _test_shake() -> void:
	var a := MatchCamera.new()
	var b := MatchCamera.new()
	var ra: Array[Vector2] = _shake_run(a)
	var rb: Array[Vector2] = _shake_run(b)
	check("shake deterministisch (2 camera's)", ra == rb)
	var rc: Array[Vector2] = _shake_run(a)
	check("shake herhaalbaar na reset", ra == rc)
	check("shake beweegt het beeld", ra[0] != Vector2.ZERO)
	check("shake dooft uit naar nul", ra[11] == Vector2.ZERO and a.shake_amplitude_units() == 0.0)
	a.reset_shake()
	a.shake(2.0, 10)
	var amp0: float = a.shake_amplitude_units()
	a.shake_tick()
	a.shake_tick()
	check("amplitude daalt lineair", a.shake_amplitude_units() < amp0)
	a.shake(0.5, 10)
	check("zwakkere shake vervangt sterkere niet", a.shake_amplitude_units() > 0.5)
	a.reset_shake()
	a.hitlag_shake(8, 1.0)
	check("hitlag_shake start een shake", a.shake_amplitude_units() > 0.0)
	a.free()
	b.free()
	var j1: Vector2 = VfxConst.hitlag_jitter(5, 3.0)
	check("hitlag_jitter deterministisch", j1 == VfxConst.hitlag_jitter(5, 3.0) and VfxConst.hitlag_jitter(4, 3.0) != j1)


func _test_determinism() -> void:
	var l1: VfxLayer = _layer()
	var l2: VfxLayer = _layer()
	var h1: HitEffect = l1.spawn_hit(Vector2.ZERO, 0.7, VfxConst.EL_FIRE, 20.0)
	var h2: HitEffect = l2.spawn_hit(Vector2.ZERO, 0.7, VfxConst.EL_FIRE, 20.0)
	check("hit-effect deterministisch (zelfde seed)", h1._spikes == h2._spikes and h1._bits == h2._bits)
	var k1: KoEffect = l1.spawn_ko("_dummy", Vector2.ZERO, 0, Color.RED)
	var k2: KoEffect = l2.spawn_ko("_dummy", Vector2.ZERO, 0, Color.RED)
	check("KO-effect deterministisch", k1._splinters == k2._splinters)
	l1.queue_free()
	l2.queue_free()


func _test_flash() -> void:
	var l: VfxLayer = _layer()
	check("geen flash in rust", l.current_flash_alpha() == 0.0)
	l.spawn_hit(Vector2.ZERO, 1.0, 0, 0.0, true)
	var a0: float = l.current_flash_alpha()
	check("kill-hit geeft screen-flash", a0 > 0.2)
	l.vfx_tick(0)
	check("flash dooft uit", l.current_flash_alpha() < a0)
	_run_frames(l, 40)
	check("flash weg na duur", l.current_flash_alpha() == 0.0)
	l.queue_free()
