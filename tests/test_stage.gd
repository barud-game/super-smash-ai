extends SceneTree
## Headless test voor StageData van Eindpunt.
## Run: Godot --headless --path . --script res://tests/test_stage.gd

var _fails: int = 0


func _initialize() -> void:
	var d: StageData = load("res://stages/eindpunt/eindpunt.tres")
	_check("data geladen", d != null)
	if d == null:
		quit(1)
		return
	_check("naam", d.stage_name == "Eindpunt")
	_check("1 solid segment", d.ground_segments.size() == 1 and d.ground_segments[0].type == StageSegment.Type.SOLID)
	_check("2 ledges", d.ledges.size() == 2)
	var l: StageLedge = d.ledges[0]
	var r: StageLedge = d.ledges[1]
	_check("ledges symmetrisch", is_equal_approx(l.position.x, -r.position.x) and is_equal_approx(l.position.y, r.position.y))
	_check("ledge zijden", l.side == -1 and r.side == 1)
	_check("ledges op segment-uiteinden", is_equal_approx(r.position.x, d.right()) and is_equal_approx(l.position.x, d.left()))
	var bz: Rect2 = d.blast_zone
	_check("blast zone omvat stage", bz.has_point(Vector2(d.left(), 0)) and bz.has_point(Vector2(d.right(), 0)))
	_check("blast zone buiten stage", bz.position.x < d.left() and bz.end.x > d.right() and bz.position.y < 0 and bz.end.y > 0)
	_check("blast zone symmetrisch in x", is_equal_approx(bz.position.x, -bz.end.x))
	_check("camera bounds binnen blast zone", bz.encloses(d.camera_bounds))
	_check("camera bounds omvat stage", d.camera_bounds.position.x < d.left() and d.camera_bounds.end.x > d.right())
	var spawns_ok: bool = d.spawns.size() == 4
	for p: Vector2 in d.spawns:
		spawns_ok = spawns_ok and p.x > d.left() and p.x < d.right()
	_check("4 spawns op de stage", spawns_ok)
	var resp_ok: bool = d.respawns.size() == 4
	for p: Vector2 in d.respawns:
		resp_ok = resp_ok and p.y > 0.0
	_check("respawns boven grond", resp_ok)
	# Stage-API en camera: zie stage_test.tscn -- --check (Sim-autoload nodig).
	print("%d fails" % _fails)
	quit(1 if _fails > 0 else 0)


func _check(n: String, c: bool) -> void:
	if not c:
		_fails += 1
	print(("PASS  " if c else "FAIL  ") + n)
