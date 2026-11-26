extends Node3D
## The Bind & Deliver extraction van: a blocky box van with a caged cargo bay,
## a loading ramp and two physically hinged rear doors (interact with F).
##
## Local frame: nose toward +Z, rear doors at -Z, wheels on y = 0.

signal cargo_loaded(body: RigidBody3D)

const Mats := preload("res://scripts/MaterialLibrary.gd")
const HingedDoor := preload("res://scripts/HingedDoor.gd")
const FlickerLight := preload("res://scripts/FlickerLight.gd")

const HALF_WIDTH := 1.25
const WALL := 0.1
const UNDERSIDE := 0.3
const FLOOR_TOP := 0.55
const ROOF_TOP := 2.75
const REAR_Z := -2.8
const PARTITION_Z := 0.6
const CAB_FRONT_Z := 2.0
const NOSE_Z := 2.9
const HOOD_TOP := 1.5
const RAMP_LENGTH := 1.9
const RAMP_HALF_WIDTH := 0.95
const DOOR_OPEN_DEGREES := 112.0

var left_door: HingedDoor
var right_door: HingedDoor
var cargo_zone: Area3D

var _body: StaticBody3D
var _beacon: OmniLight3D
var _beacon_material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = GameState.LAYER_WORLD
	_body.collision_mask = 0
	add_child(_body)
	_build_shell()
	_build_cab()
	_build_cage()
	_build_ramp()
	_build_lights()
	_build_branding()
	_build_doors()
	_build_cargo_zone()


func _process(delta: float) -> void:
	_time += delta
	# Lazy amber double-flash, like a recovery truck that has been idling for hours.
	var cycle := fmod(_time, 1.6)
	var flash := 1.0 if (cycle < 0.12 or (cycle > 0.24 and cycle < 0.36)) else 0.0
	_beacon.light_energy = lerpf(_beacon.light_energy, flash * 2.2, minf(1.0, delta * 30.0))
	_beacon_material.emission_energy_multiplier = 0.4 + _beacon.light_energy * 2.0


## True when both rear doors are (being driven) open.
func are_doors_open() -> bool:
	return left_door.is_open and right_door.is_open


func _build_shell() -> void:
	var paint := Mats.van_paint()
	var steel := Mats.metal_dark()
	# Cargo floor, walls and the roof that also covers the cab.
	_span(-HALF_WIDTH, HALF_WIDTH, UNDERSIDE, FLOOR_TOP, REAR_Z, PARTITION_Z, steel)
	_span(-HALF_WIDTH, -HALF_WIDTH + WALL, FLOOR_TOP, ROOF_TOP - WALL, REAR_Z, PARTITION_Z, paint)
	_span(HALF_WIDTH - WALL, HALF_WIDTH, FLOOR_TOP, ROOF_TOP - WALL, REAR_Z, PARTITION_Z, paint)
	_span(-HALF_WIDTH, HALF_WIDTH, ROOF_TOP - WALL, ROOF_TOP, REAR_Z, CAB_FRONT_Z, paint)
	# Chassis block: keeps loose props from vanishing under the van.
	_span(-HALF_WIDTH + 0.15, HALF_WIDTH - 0.15, 0.1, UNDERSIDE, REAR_Z + 0.05, NOSE_Z - 0.1, Mats.rubber(), false)
	_collider_span(-HALF_WIDTH + 0.1, HALF_WIDTH - 0.1, 0.0, UNDERSIDE, REAR_Z + 0.02, NOSE_Z)
	# Rubber mat and a hazard strip at the loading edge.
	_span(-HALF_WIDTH + WALL + 0.05, HALF_WIDTH - WALL - 0.05, FLOOR_TOP, FLOOR_TOP + 0.008, REAR_Z + 0.2, PARTITION_Z - 0.15, Mats.rubber(), false)
	_span(-HALF_WIDTH + WALL, HALF_WIDTH - WALL, FLOOR_TOP, FLOOR_TOP + 0.006, REAR_Z, REAR_Z + 0.14, Mats.solid(Color(0.92, 0.72, 0.05), 0.6), false)
	# Livery stripe down both flanks.
	var stripe := Mats.solid(Color(0.90, 0.36, 0.06), 0.5)
	for side: float in [-1.0, 1.0]:
		var x := side * (HALF_WIDTH + 0.004)
		_span(x - 0.004, x + 0.004, 1.02, 1.28, REAR_Z + 0.04, CAB_FRONT_Z - 0.04, stripe, false)
	# Wheels.
	var tyre := CylinderMesh.new()
	tyre.top_radius = 0.42
	tyre.bottom_radius = 0.42
	tyre.height = 0.3
	tyre.radial_segments = 18
	var hub := CylinderMesh.new()
	hub.top_radius = 0.2
	hub.bottom_radius = 0.2
	hub.height = 0.32
	hub.radial_segments = 12
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.75, 1.75]:
			var wheel := _mesh(tyre, Vector3(side * (HALF_WIDTH - 0.12), 0.42, z), Mats.rubber())
			wheel.rotation.z = PI * 0.5
			var cap := _mesh(hub, Vector3(side * (HALF_WIDTH - 0.12), 0.42, z), Mats.metal_bare())
			cap.rotation.z = PI * 0.5


func _build_cab() -> void:
	var paint := Mats.van_paint()
	var glass := Mats.glass_dark()
	var steel := Mats.metal_dark()
	_span(-HALF_WIDTH, HALF_WIDTH, UNDERSIDE, ROOF_TOP - WALL, PARTITION_Z, CAB_FRONT_Z, paint)
	_span(-HALF_WIDTH + 0.03, HALF_WIDTH - 0.03, UNDERSIDE, HOOD_TOP, CAB_FRONT_Z, NOSE_Z, paint)
	# Glazing sits a hair proud of the bodywork.
	_span(-HALF_WIDTH + 0.14, HALF_WIDTH - 0.14, HOOD_TOP + 0.12, ROOF_TOP - WALL - 0.14, CAB_FRONT_Z, CAB_FRONT_Z + 0.012, glass, false)
	for side: float in [-1.0, 1.0]:
		var x := side * (HALF_WIDTH + 0.006)
		_span(x - 0.006, x + 0.006, HOOD_TOP + 0.12, ROOF_TOP - WALL - 0.14, PARTITION_Z + 0.25, CAB_FRONT_Z - 0.18, glass, false)
		# Wing mirror.
		_span(x + side * 0.02 - 0.03, x + side * 0.02 + 0.03, HOOD_TOP + 0.2, HOOD_TOP + 0.5, CAB_FRONT_Z - 0.08, CAB_FRONT_Z + 0.04, steel, false)
	# Grille, bumpers and number plate.
	_span(-0.72, 0.72, 0.72, 1.22, NOSE_Z, NOSE_Z + 0.012, steel, false)
	for i in 5:
		var y := 0.78 + float(i) * 0.095
		_span(-0.68, 0.68, y, y + 0.03, NOSE_Z + 0.012, NOSE_Z + 0.02, Mats.metal_bare(), false)
	_span(-HALF_WIDTH, HALF_WIDTH, UNDERSIDE, UNDERSIDE + 0.24, NOSE_Z, NOSE_Z + 0.14, steel)
	_span(-0.26, 0.26, UNDERSIDE + 0.05, UNDERSIDE + 0.19, NOSE_Z + 0.14, NOSE_Z + 0.148, Mats.solid(Color(0.88, 0.85, 0.6), 0.6), false)


func _build_cage() -> void:
	var bar := Mats.metal_bare()
	var steel := Mats.metal_dark()
	var cargo_top := ROOF_TOP - WALL
	# Bulkhead between the cab and the bay: solid below, bars above.
	_span(-HALF_WIDTH + WALL, HALF_WIDTH - WALL, FLOOR_TOP, 1.35, PARTITION_Z - 0.08, PARTITION_Z, steel)
	_collider_span(-HALF_WIDTH + WALL, HALF_WIDTH - WALL, 1.35, cargo_top, PARTITION_Z - 0.08, PARTITION_Z)
	var bulkhead_bar := BoxMesh.new()
	bulkhead_bar.size = Vector3(0.03, cargo_top - 1.35, 0.03)
	var x := -HALF_WIDTH + WALL + 0.09
	while x < HALF_WIDTH - WALL:
		_mesh(bulkhead_bar, Vector3(x, (cargo_top + 1.35) * 0.5, PARTITION_Z - 0.04), bar)
		x += 0.16
	_span(-HALF_WIDTH + WALL, HALF_WIDTH - WALL, 1.98, 2.02, PARTITION_Z - 0.06, PARTITION_Z - 0.02, bar, false)
	# Containment bars lining both walls of the bay.
	var upright := BoxMesh.new()
	upright.size = Vector3(0.028, cargo_top - FLOOR_TOP - 0.06, 0.028)
	var rail := BoxMesh.new()
	rail.size = Vector3(0.028, 0.028, PARTITION_Z - REAR_Z - 0.3)
	for side: float in [-1.0, 1.0]:
		var bar_x := side * (HALF_WIDTH - WALL - 0.035)
		var z := REAR_Z + 0.28
		while z < PARTITION_Z - 0.2:
			_mesh(upright, Vector3(bar_x, (cargo_top + FLOOR_TOP) * 0.5, z), bar)
			z += 0.37
		for y: float in [FLOOR_TOP + 0.4, FLOOR_TOP + 1.05, FLOOR_TOP + 1.7]:
			_mesh(rail, Vector3(bar_x - side * 0.02, y, (REAR_Z + PARTITION_Z) * 0.5), bar)
	# Roof ribs.
	for z: float in [-2.2, -1.1, 0.0]:
		_span(-HALF_WIDTH + WALL, HALF_WIDTH - WALL, cargo_top - 0.05, cargo_top, z - 0.03, z + 0.03, steel, false)


func _build_ramp() -> void:
	# One solid wedge is both the visible ramp and its collider, so nothing can roll underneath.
	var wedge := PrismMesh.new()
	wedge.size = Vector3(RAMP_LENGTH, FLOOR_TOP, RAMP_HALF_WIDTH * 2.0)
	wedge.left_to_right = 1.0
	var ramp_position := Vector3(0.0, FLOOR_TOP * 0.5, REAR_Z - RAMP_LENGTH * 0.5)
	# Turn the prism so its tall edge meets the cargo floor.
	var ramp_basis := Basis(Vector3.UP, -PI * 0.5)
	var ramp := _mesh(wedge, ramp_position, Mats.metal_dark())
	ramp.basis = ramp_basis
	var collider := CollisionShape3D.new()
	collider.shape = wedge.create_convex_shape()
	collider.transform = Transform3D(ramp_basis, ramp_position)
	_body.add_child(collider)
	# Hazard-yellow edge rails laid along the slope.
	var slope := atan2(FLOOR_TOP, RAMP_LENGTH)
	var rail := BoxMesh.new()
	rail.size = Vector3(0.07, 0.02, Vector2(RAMP_LENGTH, FLOOR_TOP).length())
	for side: float in [-1.0, 1.0]:
		var strip := _mesh(rail, ramp_position + Vector3(side * (RAMP_HALF_WIDTH - 0.035), 0.012, 0.0), Mats.solid(Color(0.92, 0.72, 0.05), 0.6))
		strip.rotation.x = -slope


func _build_lights() -> void:
	# Headlights: emissive lenses plus fog-cutting spots.
	var lens := Mats.glow(Color(1.0, 0.94, 0.78), 6.0)
	for side: float in [-1.0, 1.0]:
		_span(side * 0.95 - 0.17, side * 0.95 + 0.17, 0.92, 1.14, NOSE_Z, NOSE_Z + 0.03, lens, false)
		var beam := SpotLight3D.new()
		beam.name = "Headlight"
		beam.position = Vector3(side * 0.95, 1.03, NOSE_Z + 0.1)
		beam.rotation = Vector3(deg_to_rad(-5.0), PI, 0.0)
		beam.light_color = Color(1.0, 0.93, 0.80)
		beam.light_energy = 6.0
		beam.light_volumetric_fog_energy = 1.0
		beam.spot_range = 30.0
		beam.spot_angle = 30.0
		beam.spot_attenuation = 1.1
		beam.spot_angle_attenuation = 0.7
		beam.shadow_enabled = true
		add_child(beam)
	# Tail lights wash the loading area in red.
	var tail := Mats.glow(Color(1.0, 0.08, 0.04), 4.0)
	for side: float in [-1.0, 1.0]:
		_span(side * 1.1 - 0.11, side * 1.1 + 0.11, UNDERSIDE + 0.06, UNDERSIDE + 0.2, REAR_Z - 0.02, REAR_Z, tail, false)
	var tail_glow := OmniLight3D.new()
	tail_glow.name = "TailGlow"
	tail_glow.position = Vector3(0.0, 0.5, REAR_Z - 2.3)
	tail_glow.light_color = Color(1.0, 0.12, 0.06)
	tail_glow.light_energy = 0.7
	tail_glow.omni_range = 5.5
	add_child(tail_glow)
	# Work light above the doors, aimed down the ramp.
	_span(-0.2, 0.2, ROOF_TOP, ROOF_TOP + 0.1, REAR_Z + 0.02, REAR_Z + 0.2, Mats.metal_dark(), false)
	_span(-0.15, 0.15, ROOF_TOP + 0.01, ROOF_TOP + 0.09, REAR_Z, REAR_Z + 0.02, Mats.glow(Color(0.82, 0.92, 1.0), 4.0), false)
	var work := SpotLight3D.new()
	work.name = "WorkLight"
	work.position = Vector3(0.0, ROOF_TOP + 0.08, REAR_Z - 0.2)
	work.rotation.x = deg_to_rad(-52.0)
	work.light_color = Color(0.80, 0.90, 1.0)
	work.light_energy = 4.0
	work.light_volumetric_fog_energy = 1.2
	work.spot_range = 11.0
	work.spot_angle = 52.0
	work.spot_angle_attenuation = 0.8
	work.shadow_enabled = true
	add_child(work)
	# Bay strip lights so the cage reads as the goal from across the yard.
	var strip := Mats.glow(Color(0.55, 0.95, 0.90), 2.5)
	for side: float in [-1.0, 1.0]:
		var x := side * (HALF_WIDTH - WALL - 0.08)
		_span(x - 0.025, x + 0.025, ROOF_TOP - WALL - 0.03, ROOF_TOP - WALL, REAR_Z + 0.2, PARTITION_Z - 0.2, strip, false)
	var bay := OmniLight3D.new()
	bay.name = "BayLight"
	bay.position = Vector3(0.0, ROOF_TOP - WALL - 0.3, -1.1)
	bay.light_color = Color(0.60, 0.95, 0.90)
	bay.omni_range = 4.5
	bay.omni_attenuation = 1.3
	bay.light_volumetric_fog_energy = 0.6
	add_child(bay)
	var bay_flicker := FlickerLight.new()
	bay_flicker.base_energy = 1.3
	bay_flicker.flicker_amount = 0.2
	bay_flicker.speed = 9.0
	bay_flicker.dropout_rate = 0.05
	bay.add_child(bay_flicker)
	# Roof beacon.
	_span(-0.5, 0.5, ROOF_TOP, ROOF_TOP + 0.07, 1.05, 1.35, Mats.metal_dark(), false)
	_beacon_material = Mats.glow(Color(1.0, 0.55, 0.05), 0.4, true)
	for side: float in [-1.0, 1.0]:
		_span(side * 0.32 - 0.14, side * 0.32 + 0.14, ROOF_TOP + 0.07, ROOF_TOP + 0.2, 1.1, 1.3, _beacon_material, false)
	_beacon = OmniLight3D.new()
	_beacon.name = "Beacon"
	_beacon.position = Vector3(0.0, ROOF_TOP + 0.45, 1.2)
	_beacon.light_color = Color(1.0, 0.55, 0.08)
	_beacon.light_energy = 0.0
	_beacon.omni_range = 11.0
	_beacon.light_volumetric_fog_energy = 2.0
	add_child(_beacon)


func _build_branding() -> void:
	for side: float in [-1.0, 1.0]:
		var facing := side * PI * 0.5
		var x := side * (HALF_WIDTH + 0.012)
		_label("BIND & DELIVER", 96, Vector3(x, 2.05, -1.1), facing, Color(0.10, 0.20, 0.24))
		_label("LICENSED DEMON REMOVAL", 34, Vector3(x, 1.68, -1.1), facing, Color(0.16, 0.16, 0.16))
		_label("NO SOUL TOO SMALL", 26, Vector3(x, 1.15, -1.1), facing, Color(0.98, 0.95, 0.88))


func _build_doors() -> void:
	var angle := deg_to_rad(DOOR_OPEN_DEGREES)
	left_door = _make_door("RearDoorLeft", -(HALF_WIDTH - 0.02), false, angle)
	right_door = _make_door("RearDoorRight", HALF_WIDTH - 0.02, true, -angle)
	left_door.partner = right_door
	right_door.partner = left_door
	left_door.toggled.connect(_on_doors_toggled)


func _make_door(door_name: String, hinge_x: float, mirrored: bool, open_angle: float) -> HingedDoor:
	var width := HALF_WIDTH - 0.035
	var bottom := FLOOR_TOP - 0.1
	var top := ROOF_TOP - 0.02
	var height := top - bottom
	var thickness := 0.07
	var door: HingedDoor = HingedDoor.new()
	door.name = door_name
	door.noun = "rear doors"
	door.open_angle = open_angle
	door.configure(width, height, thickness, 16.0, Mats.van_paint())
	door.position = Vector3(hinge_x, (top + bottom) * 0.5, REAR_Z - thickness * 0.5 - 0.01)
	door.rotation.y = PI if mirrored else 0.0
	# Detail meshes are slightly thicker than the leaf so they show on both faces.
	_door_detail(door, Vector3(width * 0.62, height * 0.26, thickness + 0.006), Vector3(width * 0.5, height * 0.2, 0.0), Mats.glass_dark())
	_door_detail(door, Vector3(width * 0.94, 0.2, thickness + 0.004), Vector3(width * 0.5, -height * 0.3, 0.0), Mats.solid(Color(0.90, 0.36, 0.06), 0.5))
	# The handle goes on whichever face points away from the bay.
	var outside := 1.0 if mirrored else -1.0
	_door_detail(door, Vector3(0.05, 0.3, 0.05), Vector3(width - 0.1, -0.08, outside * (thickness * 0.5 + 0.02)), Mats.metal_bare())
	add_child(door)
	door.hinge_to(_body)
	return door


func _door_detail(door: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	door.add_child(instance)


func _build_cargo_zone() -> void:
	cargo_zone = Area3D.new()
	cargo_zone.name = "CargoZone"
	cargo_zone.collision_layer = 0
	cargo_zone.collision_mask = GameState.LAYER_PROP
	cargo_zone.monitorable = false
	var shape := BoxShape3D.new()
	shape.size = Vector3((HALF_WIDTH - WALL) * 2.0 - 0.1, ROOF_TOP - WALL - FLOOR_TOP - 0.1, PARTITION_Z - REAR_Z - 0.35)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, (ROOF_TOP - WALL + FLOOR_TOP) * 0.5, (PARTITION_Z + REAR_Z) * 0.5 + 0.1)
	cargo_zone.add_child(collider)
	add_child(cargo_zone)
	cargo_zone.body_entered.connect(_on_cargo_entered)


func _on_doors_toggled(open: bool) -> void:
	if open:
		GameState.complete_step(GameState.STEP_OPEN_VAN)


func _on_cargo_entered(body: Node3D) -> void:
	var prop := body as RigidBody3D
	if prop and prop.is_in_group(GameState.GROUP_GRABBABLE):
		cargo_loaded.emit(prop)
		GameState.complete_step(GameState.STEP_LOAD_CARGO)


# --- Assembly helpers -------------------------------------------------------

func _mesh(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	_body.add_child(instance)
	return instance


## Axis-aligned box given by its min/max corners, optionally with a matching collider.
func _span(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, material: Material, solid: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(x1 - x0, y1 - y0, z1 - z0)
	if solid:
		_collider_span(x0, x1, y0, y1, z0, z1)
	return _mesh(mesh, Vector3(x0 + x1, y0 + y1, z0 + z1) * 0.5, material)


func _collider_span(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(x1 - x0, y1 - y0, z1 - z0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(x0 + x1, y0 + y1, z0 + z1) * 0.5
	_body.add_child(collider)


func _label(text: String, font_size: int, at: Vector3, yaw: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.004
	label.outline_size = 0
	label.modulate = color
	label.shaded = true
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.position = at
	label.rotation.y = yaw
	add_child(label)
