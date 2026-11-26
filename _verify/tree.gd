extends SceneTree

func _initialize() -> void:
	for key: String in OS.get_cmdline_user_args():
		var scene: PackedScene = load("res://assets/models/%s.glb" % key)
		var root := scene.instantiate()
		print("## ", key)
		_dump(root, 0)
		root.free()
	quit()

func _dump(node: Node, depth: int) -> void:
	if depth > 3:
		return
	var info := ""
	if node is MeshInstance3D:
		var a: AABB = node.get_aabb()
		info = " mesh(%.2f,%.2f,%.2f)@(%.2f,%.2f,%.2f) surf=%d" % [a.size.x, a.size.y, a.size.z, a.get_center().x, a.get_center().y, a.get_center().z, node.mesh.get_surface_count()]
	if node is Node3D and node.position.length() > 0.001:
		info += " pos(%.2f,%.2f,%.2f)" % [node.position.x, node.position.y, node.position.z]
	if node is Node3D and (node.scale - Vector3.ONE).length() > 0.01:
		info += " scale(%.2f)" % node.scale.x
	var kids := node.get_child_count()
	print("  ".repeat(depth), node.name, " [", node.get_class(), "]", info, (" kids=%d" % kids) if kids > 0 else "")
	var shown := 0
	for child in node.get_children():
		if shown >= 14:
			print("  ".repeat(depth + 1), "...")
			break
		_dump(child, depth + 1)
		shown += 1
