extends SceneTree

func _initialize() -> void:
	for key: String in OS.get_cmdline_user_args():
		var scene: PackedScene = load("res://assets/models/%s.glb" % key)
		var root := scene.instantiate()
		var groups := {}
		for child in root.get_children():
			var n := String(child.name)
			var parts := n.split("_")
			var prefix := "_".join(parts.slice(0, mini(parts.size(), 5)))
			if not groups.has(prefix):
				groups[prefix] = []
			var p: Vector3 = child.position if child is Node3D else Vector3.ZERO
			groups[prefix].append("%s@%.1f,%.1f,%.1f" % ["_".join(parts.slice(5)), p.x, p.y, p.z])
		print("## ", key)
		for g: String in groups:
			print(g, ": ", " ".join(groups[g]).left(230))
		root.free()
	quit()
