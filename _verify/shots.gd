extends Node

const OUT := "/tmp/shots"
const FY := 0.45

var main: Node3D
var player: CharacterBody3D
var level: Node3D
var free_cam: Camera3D
var wanted: PackedStringArray


func _ready() -> void:
	wanted = OS.get_cmdline_user_args()
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	player = main.get("player")
	level = main.get("level")
	free_cam = Camera3D.new()
	free_cam.fov = 72.0
	free_cam.far = 300.0
	add_child(free_cam)
	await _settle(150)

	await _player_shot("01_spawn_tp", Vector3(1.2, 0.05, 7.5), 0.0, -0.05, false)
	await _free_shot("02_yard_overview", Vector3(-6.0, 3.4, 15.5), Vector3(0.5, 1.8, -4.0))
	await _free_shot("02b_yard_side", Vector3(13.5, 2.4, 9.0), Vector3(0.0, 1.6, -3.0))
	if _want("03"):
		var cone := _find("Traffic Cone", Vector3(2.7, 0, 1.3))
		await _place(Vector3(cone.global_position.x - 0.4, 0.05, cone.global_position.z + 2.2), 0.0, 0.0, true)
		await _aim_at(cone.global_position + Vector3(0, 0.25, 0))
		await _capture("03_crosshair_grabbable")
	if _want("04"):
		var door: Node3D = level.van.left_door
		await _place(level.van.global_position + Vector3(-0.9, 0.05, -5.4), PI, 0.0, true)
		await _aim_at(door.global_position + Vector3(0.6, 0.1, 0.0))
		await _capture("04_crosshair_door")
	await _free_shot("05a_van_front", Vector3(8.6, 1.7, 10.4), Vector3(4.5, 1.2, 5.0))
	level.van.left_door.interact()
	await _settle(70)
	await _free_shot("05_van_rear_open", Vector3(0.6, 1.9, -1.6), Vector3(4.5, 1.2, 3.0))
	await _free_shot("05b_van_interior", Vector3(4.5, 1.75, 0.2), Vector3(4.5, 1.4, 5.0))
	await _free_shot("06_porch", Vector3(-3.0, 1.7, 3.2), Vector3(-4.2, 1.8, -4.0))
	level.front_doors[0].interact()
	await _settle(60)
	await _player_shot("07_living_fp", Vector3(-3.6, FY + 0.05, -5.2), 0.55, -0.12, true)
	await _free_shot("08_living_wide", Vector3(-0.8, FY + 2.3, -4.8), Vector3(-6.5, FY + 0.6, -10.5))
	await _free_shot("08b_living_fireplace", Vector3(-7.5, FY + 1.6, -6.5), Vector3(-2.5, FY + 0.9, -13.5))
	if _want("09") or _want("10"):
		var chair := _find("Dining Chair", Vector3(-4.8, FY, -8.6))
		await _place(chair.global_position + Vector3(1.6, 0.05, 1.6), 0.0, 0.0, true)
		await _aim_at(chair.global_position + Vector3(0, 0.5, 0))
		Input.action_press("grab")
		await _settle(10)
		player.set("_pitch", 0.05)
		await _settle(40)
		await _capture("09_grab_fp")
		player.call("set_first_person", false)
		await _settle(40)
		await _capture("10_grab_tp")
		Input.action_release("grab")
		await _settle(20)
	await _player_shot("11_hall_tp", Vector3(2.0, FY + 0.05, -7.6), 0.0, -0.1, false)
	await _free_shot("11b_hall", Vector3(2.0, FY + 1.6, -4.9), Vector3(2.0, FY + 1.2, -14.0))
	await _free_shot("12_study", Vector3(4.8, FY + 0.45 + 1.9, -13.6), Vector3(8.2, FY + 0.9, -6.5))
	await _free_shot("13_ritual", Vector3(6.5, FY + 2.2, -15.9), Vector3(-1.0, FY + 0.6, -20.5))
	await _player_shot("14_ritual_fp", Vector3(2.0, FY + 0.05, -15.9), 0.35, -0.12, true)
	await _free_shot("14b_altar", Vector3(0.6, FY + 1.5, -20.6), Vector3(0.0, FY + 1.1, -23.6))
	if _want("15") or _want("16"):
		await _place(Vector3(-4.0, FY + 0.05, -2.4), PI, 0.0, false)
		player.call("set_flashlight", false)
		var fill := OmniLight3D.new()
		fill.position = Vector3(-4.0, FY + 1.9, -0.6)
		fill.light_energy = 1.6
		fill.omni_range = 6.0
		add_child(fill)
		await _settle(20)
		await _free_shot("15_exorcist_front", Vector3(-4.0, FY + 1.35, -0.6), Vector3(-4.0, FY + 1.05, -2.4))
		await _free_shot("16_exorcist_back", Vector3(-3.0, FY + 1.6, -3.9), Vector3(-4.0, FY + 1.0, -2.4))
		await _free_shot("16b_exorcist_side", Vector3(-5.9, FY + 1.3, -2.4), Vector3(-4.0, FY + 1.0, -2.4))
	if _want("17"):
		await _free_shot("17_squad", Vector3(8.6, 1.6, 2.2), Vector3(7.2, 1.0, -0.6))
	if _want("x"):
		# Free-form shot: -- x fx fy fz tx ty tz
		var a := wanted
		var i := a.find("x")
		await _free_shot("x", Vector3(float(a[i + 1]), float(a[i + 2]), float(a[i + 3])), Vector3(float(a[i + 4]), float(a[i + 5]), float(a[i + 6])))
	get_tree().quit()


func _find(display: String, near: Vector3) -> RigidBody3D:
	var best: RigidBody3D = null
	for node in get_tree().get_nodes_in_group("grabbable"):
		var rb := node as RigidBody3D
		if rb.get_meta("display_name", "") == display:
			if best == null or rb.global_position.distance_to(near) < best.global_position.distance_to(near):
				best = rb
	return best


func _want(shot: String) -> bool:
	if wanted.is_empty():
		return shot != "x"
	for w in wanted:
		if shot.begins_with(w) and w != "":
			return true
	return false


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _settle(count: int) -> void:
	get_viewport().disable_3d = true
	await _frames(count)
	get_viewport().disable_3d = false


func _place(at: Vector3, yaw: float, pitch: float, fp: bool) -> void:
	player.global_position = at
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	player.set("_pitch", pitch)
	player.call("set_first_person", fp)
	player.call("get_camera").make_current()
	await _settle(30)


func _aim_at(target: Vector3) -> void:
	var head: Node3D = player.get_node("Head")
	var dir := (target - head.global_position).normalized()
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.set("_pitch", asin(dir.y))
	await _settle(6)


func _player_shot(shot: String, at: Vector3, yaw: float, pitch: float, fp: bool) -> void:
	if not _want(shot):
		return
	await _place(at, yaw, pitch, fp)
	await _capture(shot)


func _free_shot(shot: String, from: Vector3, look_at_point: Vector3) -> void:
	if not _want(shot):
		return
	free_cam.global_position = from
	free_cam.look_at(look_at_point, Vector3.UP)
	free_cam.make_current()
	await _capture(shot)


func _capture(shot: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, shot])
	print("shot ", shot)
