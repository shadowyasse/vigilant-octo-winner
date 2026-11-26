extends SceneTree

func _initialize() -> void:
	var loader: Node = root.get_node("ModelLoader")
	loader.verbose = false
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/asset_manifest.json"))
	for entry: Dictionary in manifest["models"]:
		var key := "%s/%s" % [entry["category"], entry["name"]]
		var model: Node3D = loader.instance(key)
		var box: AABB = loader.get_aabb(model)
		var line := "%s  %.2fx%.2fx%.2f" % [key, box.size.x, box.size.y, box.size.z]
		if loader.is_fallback(model):
			line += "  FALLBACK"
		var meshes: Array = []
		_meshes(model, meshes)
		if meshes.size() > 1 and meshes.size() <= 40:
			var parts := PackedStringArray()
			for m: MeshInstance3D in meshes:
				var a := m.get_aabb()
				var s := (m.global_transform.basis if m.is_inside_tree() else Basis.IDENTITY)
				parts.append("%s(%.2f,%.2f,%.2f)" % [m.name, a.size.x, a.size.y, a.size.z])
			line += "  parts: " + " ".join(parts)
		elif meshes.size() > 40:
			line += "  parts: %d meshes e.g. %s" % [meshes.size(), meshes[0].name]
		print(line)
		model.free()
	print(loader.report())
	quit()

func _meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_meshes(child, out)
