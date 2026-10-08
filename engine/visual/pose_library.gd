class_name PoseLibrary
extends RefCounted
## Laadt poses uit JSON. Gedeelde poses: res://engine/visual/poses/*.json.
## Een character mag er eigen/overschreven poses bij leggen in res://characters/<id>/poses/*.json.
## Elk JSON-bestand: { "<pose_naam>": { loop, blend, interp, length, keys: [...] }, ... }

const SHARED_DIR: String = "res://engine/visual/poses"

var poses: Dictionary = {}   # naam -> Pose
var errors: PackedStringArray = PackedStringArray()


func load_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for f in files:
		if f.get_extension() != "json":
			continue
		_load_file(dir_path.path_join(f))


func _load_file(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("Pose-bestand is geen geldige JSON-dictionary: " + path)
		return
	for pose_name: String in parsed:
		if pose_name.begins_with("_"):
			continue   # commentaar/metadata
		poses[pose_name] = Pose.from_dict(pose_name, parsed[pose_name])


static func load_for(character_id: String) -> PoseLibrary:
	var lib := PoseLibrary.new()
	lib.load_dir(SHARED_DIR)
	if character_id != "":
		lib.load_dir("res://characters/%s/poses" % character_id)
	return lib
