extends SceneTree
## Compiles every script in the project and reports failures.
## Run: godot --headless --path . -s res://tests/check_scripts.gd


func _initialize() -> void:
	var failures := 0
	var files := _collect("res://scripts") + _collect("res://resources")
	for path in files:
		var s := load(path) as GDScript
		if s == null or not s.can_instantiate():
			print("FAIL ", path)
			failures += 1
	print("Checked %d scripts, %d failures" % [files.size(), failures])
	quit(1 if failures > 0 else 0)


func _collect(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		out.append_array(_collect(dir_path.path_join(d)))
	return out
