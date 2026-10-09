extends SceneTree
## Validator-CLI. Zie docs/validator.md.
## <godot> --headless --path . --script res://tools/validator/validate.gd -- [--archetype <id> | --character <id> | --all] [--json]

const Validator := preload("res://tools/validator/validator.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var v: RefCounted = Validator.new()
	var json_out := args.has("--json")
	var reports: Array = []
	var i := 0
	var any := false
	while i < args.size():
		match args[i]:
			"--archetype":
				i += 1
				reports.append(v.validate_archetype(args[i] if i < args.size() else ""))
				any = true
			"--character":
				i += 1
				reports.append(v.validate_character(args[i] if i < args.size() else ""))
				any = true
			"--all":
				for id in v.archetype_ids():
					reports.append(v.validate_archetype(id))
				for id in v.character_ids():
					reports.append(v.validate_character(id))
				any = true
		i += 1
	if not any:
		print("Gebruik: --archetype <id> | --character <id> | --all  [--json]")
		quit(2)
		return
	var fails := 0
	var warns := 0
	var passes := 0
	for rep in reports:
		for r in rep["results"]:
			match r["status"]:
				"FAIL": fails += 1
				"WARN": warns += 1
				_: passes += 1
		var b: Dictionary = rep["budget"]
		if not b.is_empty() and b["status"] == "FAIL":
			fails += 1
	if json_out:
		print(JSON.stringify({"ok": fails == 0, "fails": fails, "warns": warns, "passes": passes, "reports": reports}))
	else:
		for rep in reports:
			for r in rep["results"]:
				print(_line(r))
			var b: Dictionary = rep["budget"]
			if not b.is_empty():
				print("%s  %s  %s" % [b["status"], rep["scope"], b["msg"]])
		print("")
		print("Samenvatting: %d PASS, %d WARN, %d FAIL" % [passes, warns, fails])
	quit(1 if fails > 0 else 0)


func _line(r: Dictionary) -> String:
	var sc: Dictionary = r["scores"]
	var tag := ""
	if not sc.is_empty():
		var parts: PackedStringArray = []
		for a in ["S", "K", "B", "V", "U"]:
			if sc.has(a):
				parts.append("%s%d" % [a, int(sc[a])])
		tag = " [" + " ".join(parts) + "]"
	var s := "%-4s  %s %s%s" % [r["status"], r["scope"], r["move"], tag]
	if not r["fails"].is_empty():
		s += "  " + "; ".join(r["fails"])
	if not r["warns"].is_empty():
		s += "  (warn: " + "; ".join(r["warns"]) + ")"
	return s
