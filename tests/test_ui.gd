extends SceneTree
## Headless UI-test: registry, manifest, settings, MatchRules, MenuNav en het instantiëren van de schermen.
##   Godot_console.exe --headless --path . --script res://tests/test_ui.gd
## Exit code 0 = alles geslaagd.

var _fails: int = 0
var _total: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name)


func _run() -> void:
	var reg: Node = root.get_node("/root/CharacterRegistry")
	var settings: Node = root.get_node("/root/Settings")
	var setup: Node = root.get_node("/root/MatchSetup")

	# --- registry
	reg.include_dummy = true
	reg.rescan()
	var dummy: CharacterInfo = reg.get_info("_dummy")
	check("registry vindt _dummy", dummy != null)
	check("_dummy manifest: naam", dummy != null and dummy.display_name == "Houten Pop")
	check("_dummy manifest: archetype + niet OP", dummy != null and dummy.archetype == "Allrounder" and not dummy.op)
	check("_dummy heeft art", dummy != null and dummy.has_art and dummy.has_manifest)
	reg.include_dummy = false
	reg.rescan()
	check("_dummy weg als include_dummy uit", reg.get_info("_dummy") == null)
	reg.include_dummy = true
	reg.rescan()

	# --- manifest parsen
	var m: CharacterInfo = reg.parse_manifest(
		'{"id":"x","name":"Xena","archetype":"Floaty","op":true,"tagline":"hi","colors":{"primary":"#ff0000"}}', "x")
	check("manifest: velden", m.display_name == "Xena" and m.archetype == "Floaty" and m.op and m.tagline == "hi")
	check("manifest: kleur", m.color_primary == Color("ff0000") and m.warnings.is_empty())
	var bad: CharacterInfo = reg.parse_manifest("{kapot", "kapot_map")
	check("manifest: kapotte json geeft fallback", bad.id == "kapot_map" and bad.display_name == "Kapot Map" and not bad.warnings.is_empty())
	var odd: CharacterInfo = reg.parse_manifest('{"archetype":"Onbekend","colors":{"primary":"zzz"}}', "o")
	check("manifest: waarschuwingen bij onbekend archetype/kleur", odd.warnings.size() == 2)
	check("matches() zoekt op naam", m.matches("xen") and not m.matches("qqq") and m.matches(""))

	# --- scan van een eigen map (hot reload / underscore-regel)
	var base: String = "user://test_roster"
	DirAccess.make_dir_recursive_absolute(base + "/goed/art")
	DirAccess.make_dir_recursive_absolute(base + "/_verborgen/art")
	DirAccess.make_dir_recursive_absolute(base + "/leeg")
	var f := FileAccess.open(base + "/goed/character.json", FileAccess.WRITE)
	f.store_string('{"name":"Goed","archetype":"Zwaargewicht","op":true}')
	f.close()
	reg.rescan(base)
	check("rescan: alleen goede map, geen _ en geen lege map", reg.characters.size() == 1 and reg.get_info("goed") != null)
	check("rescan: OP-vlag", reg.get_info("goed").op)
	reg.rescan()
	check("rescan terug naar echte roster", reg.get_info("_dummy") != null)
	_rm_rf(base)

	# --- random_id
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	check("random_id geeft bestaand id", reg.has_character(reg.random_id(rng)))

	# --- settings
	settings.path = "user://settings_test.cfg"
	settings.reset_defaults()
	check("settings: tap-jump standaard aan", settings.tap_jump_enabled(0) and settings.tap_jump_enabled(1))
	settings.set_tap_jump(1, false)
	settings.set_rumble(false)
	settings.set_master_volume(0.4)
	settings.set_sfx_volume(0.7)
	settings.set_fullscreen(false)
	settings.tap_jump[0] = true
	settings.tap_jump[1] = true
	settings.rumble = true
	settings.master_volume = 1.0
	settings.sfx_volume = 1.0
	check("settings: load zet waarden terug", settings.load_settings() == OK
		and settings.tap_jump == [true, false] and not settings.rumble
		and is_equal_approx(settings.master_volume, 0.4) and is_equal_approx(settings.sfx_volume, 0.7))
	settings.reset_defaults()
	DirAccess.remove_absolute(settings.path)
	settings.path = settings.DEFAULT_PATH

	# --- match rules
	var rules := MatchRules.new()
	check("MatchRules standaard: 4 stocks / 8 min / geen items / sudden death",
		rules.stocks == 4 and rules.time_minutes == 8 and not rules.items and rules.sudden_death)
	check("MatchRules.time_frames", rules.time_frames() == 8 * 60 * 60)

	# --- MenuNav (herhaalvertraging)
	var nav := MenuNav.new()
	var hist: InputHistory = root.get_node("/root/InputManager").history(0)
	nav.poll(0)   # primen
	var right := InputFrame.new()
	right.stick = Vector2i(80, 0)
	hist.push(right)
	nav.poll(0)
	var acts: Array[int] = []
	var first: Array[int] = nav.poll(0) # 2e frame ingedrukt: geen nieuwe actie
	check("MenuNav: ingedrukt houden herhaalt niet meteen", first.is_empty())
	var repeats: int = 0
	for i in 40:
		hist.push(right)
		repeats += nav.poll(0).count(MenuNav.Act.RIGHT)
	check("MenuNav: herhaling na vertraging", repeats >= 2 and repeats <= 4)
	hist.push(InputFrame.new())
	nav.poll(0)
	hist.push(right)
	check("MenuNav: opnieuw indrukken geeft meteen actie", nav.poll(0).has(MenuNav.Act.RIGHT))
	var a_press := InputFrame.new()
	a_press.buttons = InputFrame.BTN_ATTACK
	hist.push(InputFrame.new())
	nav.poll(0)
	hist.push(a_press)
	check("MenuNav: A = CONFIRM", nav.poll(0).has(MenuNav.Act.CONFIRM))
	hist.push(InputFrame.new())
	nav.poll(0)

	# --- schermen instantiëren
	setup.reset()
	for path in ["res://ui/main_menu/main_menu.tscn", "res://ui/settings/settings_menu.tscn",
			"res://ui/match/match.tscn", "res://ui/character_select/character_select.tscn"]:
		var packed: PackedScene = load(path)
		check("laadt " + path, packed != null)
		var inst: Node = packed.instantiate()
		root.add_child(inst)
		for i in 3:
			await process_frame
		check("draait 3 frames: " + path, is_instance_valid(inst) and inst.is_inside_tree())
		inst.queue_free()
		await process_frame

	# --- character select: lock-logica
	setup.mode = "fight"
	var cs: Node = load("res://ui/character_select/character_select.tscn").instantiate()
	root.add_child(cs)
	await process_frame
	check("select: Random-tegel + characters", cs.entries.size() == reg.characters.size() + 1 and cs.entries[0] == null)
	cs._confirm(0)
	check("select: P1 locked, nog niet klaar", cs.locked[0] and not cs._ready_to_start())
	cs._confirm(1)
	check("select: mirror toegestaan, beide klaar", cs._ready_to_start() and cs.locked_id[0] == cs.locked_id[1])
	cs._back(1)
	check("select: B pakt token terug", not cs.locked[1])
	cs.query = "pop"
	cs._rebuild_entries()
	check("select: zoeken filtert", cs.entries.size() == 2)
	cs.query = "zzzzqq"
	cs._rebuild_entries()
	check("select: zoeken zonder resultaat laat alleen Random", cs.entries.size() == 1)
	cs.query = ""
	cs.filter = "__op"
	cs._rebuild_entries()
	check("select: OP-filter", cs.entries.size() == 1 + reg.characters.filter(func(c: CharacterInfo) -> bool: return c.op).size())
	cs.queue_free()
	await process_frame

	# --- training: alleen P1
	setup.mode = "training"
	var tr: Node = load("res://ui/character_select/character_select.tscn").instantiate()
	root.add_child(tr)
	await process_frame
	check("training: alleen speler 1 actief", tr.active_players == [0])
	tr._confirm(0)
	check("training: klaar na P1-keuze", tr._ready_to_start())
	tr.queue_free()
	await process_frame
	setup.reset()

	print("")
	print("%d/%d checks geslaagd" % [_total - _fails, _total])
	quit(1 if _fails > 0 else 0)


func _rm_rf(path: String) -> void:
	var da: DirAccess = DirAccess.open(path)
	if da == null:
		return
	for d in da.get_directories():
		_rm_rf(path + "/" + d)
	for fl in da.get_files():
		DirAccess.remove_absolute(path + "/" + fl)
	DirAccess.remove_absolute(path)
