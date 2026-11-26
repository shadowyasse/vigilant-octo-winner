extends SceneTree
## Headless gameplay regression for Stage 1: boots the real game and plays the
## objective chain through the player's own input paths.
##   godot --headless --path . -s tools/smoke_test.gd
## Exits 0 when every check passes, 1 otherwise.

var _main: Node
var _player: CharacterBody3D
var _state: Node
var _van: Node3D
var _prop: RigidBody3D
var _tick := 0
var _step := 0
var _step_tick := 0
var _failures := 0
var _rear := Vector3.ZERO
var _outward := Vector3.ZERO


func _initialize() -> void:
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	_state = root.get_node("GameState")


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if not detail.is_empty() else ""])
	if not ok:
		_failures += 1


func _next() -> void:
	_step += 1
	_step_tick = 0


func _place(at: Vector3, look_at_point: Vector3, pitch: float = 0.0) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	var flat := look_at_point - at
	_player.rotation.y = atan2(-flat.x, -flat.z)
	_player.set("_pitch", pitch)


func _done(step: StringName) -> bool:
	return _state.call("is_step_done", step)


func _physics_process(_delta: float) -> bool:
	_tick += 1
	_step_tick += 1
	if _player == null:
		_player = _main.get("player")
		_van = (_main.get("level") as Node).get("van")
		return false
	match _step:
		0:  # settle
			if _step_tick == 40:
				_check("player stands at spawn", _player.is_on_floor(), str(_player.global_position))
				_check("contract starts empty", not _done(&"open_van") and not _done(&"load_cargo"))
				var left: Node3D = _van.get("left_door")
				var right: Node3D = _van.get("right_door")
				_rear = (left.global_position + right.global_position) * 0.5
				_outward = (_rear - _van.global_position) * Vector3(1, 0, 1)
				_outward = _outward.normalized()
				# Stand on the ramp foot, look at the left leaf.
				_place(Vector3(_rear.x, 0.1, _rear.z) + _outward * 3.4, left.global_position)
				_next()
		1:  # open the rear doors with F
			if _step_tick == 20:
				var left: Node3D = _van.get("left_door")
				var eye := _player.global_position + Vector3.UP * 1.62
				var target := left.global_position.lerp(_rear, 0.5)
				# The third-person camera sits over the right shoulder; line that up with the door.
				var shoulder := (-_outward).cross(Vector3.UP) * 0.7
				_player.global_position = Vector3(target.x, _player.global_position.y, target.z) + _outward * 2.2 - shoulder
				eye = _player.global_position + Vector3.UP * 1.62
				_player.rotation.y = atan2(_outward.x, _outward.z)
				_player.set("_pitch", atan2(target.y - eye.y - 0.1, 2.2))
			if _step_tick == 30:
				_check("rear door is targetable", _player.get("_aim_interactable") != null, str(_player.get("_aim_prompt")))
				var press := InputEventAction.new()
				press.action = &"interact"
				press.pressed = true
				Input.parse_input_event(press)
			if _step_tick == 150:
				_check("F opens both rear doors", _van.get("left_door").get("is_open") and _van.get("right_door").get("is_open"))
				_check("objective: open van", _done(&"open_van"))
				var swing: float = absf((_van.get("left_door") as Node3D).rotation.y)
				_check("door leaf physically swung", swing > 0.8, "%.2f rad" % swing)
				_next()
		2:  # pick a light prop, set it at the ramp foot and grab it
			if _step_tick == 1:
				for node in get_nodes_in_group(&"grabbable"):
					var body := node as RigidBody3D
					if body and not body.freeze and body.mass <= 6.0 and body.mass >= 1.0:
						_prop = body
						break
				_check("found a grabbable prop", _prop != null, str(_prop.get_meta(&"display_name", _prop.name)) if _prop else "")
				_place(Vector3(_rear.x, 0.1, _rear.z) + _outward * 4.6, _rear)
				_prop.global_position = _player.global_position - _outward * 1.4 + (-_outward).cross(Vector3.UP) * 0.7 + Vector3.UP * 0.6
				_prop.linear_velocity = Vector3.ZERO
				_prop.angular_velocity = Vector3.ZERO
			if _step_tick == 50:
				var eye := _player.global_position + Vector3.UP * 1.62
				var to := _prop.global_position - eye - (-_outward).cross(Vector3.UP) * 0.7
				_player.set("_pitch", atan2(to.y, Vector2(to.x, to.z).length()))
			if _step_tick == 60:
				Input.action_press(&"grab")
			if _step_tick == 75:
				_check("LMB grabs the prop", _player.call("get_held") == _prop, str(_player.get("_aim_prompt")))
				_player.set("_pitch", -0.15)
			if _step_tick == 110:
				var tether: Node3D = _player.get_node("GrabTether")
				_check("grab tether is drawn", tether.visible)
				_check("prop is carried, not frozen", not _prop.freeze and _prop.global_position.y > 0.7, str(_prop.global_position))
				_next()
		3:  # haul it up the ramp into the cargo bay
			if _step_tick == 1:
				Input.action_press(&"move_forward")
			if _step_tick == 200:
				Input.action_release(&"move_forward")
				_check("walked up the ramp into the bay without snagging", _player.global_position.y > 0.5 and (_player.global_position - _rear).dot(-_outward) > 0.3,
						"player %s rear %s" % [_player.global_position, _rear])
				_check("objective: cargo loaded", _done(&"load_cargo"))
				_check("still holding after the haul", _player.call("get_held") == _prop)
				_next()
		4:  # throw
			if _step_tick == 5:
				var press := InputEventAction.new()
				press.action = &"throw"
				press.pressed = true
				Input.parse_input_event(press)
			if _step_tick == 9:
				Input.action_release(&"grab")
				_check("RMB throws the prop", _player.call("get_held") == null and _prop.linear_velocity.length() > 3.0, "%.1f m/s" % _prop.linear_velocity.length())
				_next()
		5:  # house objectives
			if _step_tick == 1:
				_place(Vector3(-5.0, 0.6, -9.0), Vector3(-5.0, 0.6, -20.0))
			if _step_tick == 30:
				_check("objective: enter house", _done(&"enter_house"))
				_check("floor holds inside the house", _player.is_on_floor(), str(_player.global_position))
				_place(Vector3(0.0, 0.6, -19.5), Vector3(0.0, 0.6, -30.0))
			if _step_tick == 60:
				_check("objective: ritual room", _done(&"find_ritual"))
				_check("contract complete", _state.call("is_contract_complete"))
				_next()
		6:  # camera, lamp, crouch, jump
			if _step_tick == 5:
				Input.action_press(&"crouch")
			if _step_tick == 1:
				for action: StringName in [&"toggle_camera", &"toggle_flashlight"]:
					var press := InputEventAction.new()
					press.action = action
					press.pressed = true
					Input.parse_input_event(press)

			if _step_tick == 40:
				_check("V switches to first person", _player.get("first_person") == true)
				_check("T switches the headlamp off", _player.get("flashlight_on") == false and not (_player.get_node("Head/Flashlight") as Node3D).visible)
				var capsule := (_player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
				_check("Ctrl crouches", capsule.height < 1.25, "%.2f m" % capsule.height)
				Input.action_release(&"crouch")
			if _step_tick == 80:
				Input.action_press(&"jump")
			if _step_tick == 84:
				Input.action_release(&"jump")
				_check("Space jumps", _player.velocity.y > 2.0, "%.1f m/s" % _player.velocity.y)
			if _step_tick == 100:
				var crew := 0
				for child in _main.get_children():
					if String(child.name).begins_with("Crew"):
						crew += 1
				_check("squad of three is on site", crew == 3)
				var loader := root.get_node("ModelLoader")
				_check("no missing models", int(loader.call("get_missing_count")) == 0, "%d loaded" % int(loader.call("get_loaded_count")))
				print("RESULT %s (%d failed)" % ["OK" if _failures == 0 else "FAILED", _failures])
				quit(0 if _failures == 0 else 1)
				return true
	if _tick > 3000:
		print("RESULT TIMEOUT at step ", _step)
		quit(1)
		return true
	return false
