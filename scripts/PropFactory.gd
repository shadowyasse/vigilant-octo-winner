extends RefCounted
## Builds the throwable clutter. Every prop is a RigidBody3D assembled from
## primitive meshes, with mass, friction and bounce tuned per object so light
## junk skitters when kicked and furniture has to be shouldered around.
## All props are built with their origin on the floor, centred under them.

const Mats := preload("res://scripts/MaterialLibrary.gd")
const FlickerLight := preload("res://scripts/FlickerLight.gd")

const BOOK_COLORS: Array[Color] = [
	Color(0.45, 0.10, 0.10), Color(0.10, 0.22, 0.36), Color(0.14, 0.30, 0.16),
	Color(0.36, 0.26, 0.10), Color(0.24, 0.12, 0.30), Color(0.12, 0.12, 0.13),
]
const PAINT_COLORS: Array[Color] = [
	Color(0.70, 0.08, 0.06), Color(0.85, 0.80, 0.70), Color(0.10, 0.35, 0.42), Color(0.90, 0.55, 0.08),
]


## Creates a prop by kind name. `lit` switches on the light of lamps and TVs.
static func create(kind: StringName, rng: RandomNumberGenerator, lit: bool = false) -> RigidBody3D:
	match kind:
		&"chair":
			return chair()
		&"box":
			return cardboard_box(rng)
		&"crate":
			return crate()
		&"table":
			return table(Vector3(1.3, 0.77, 0.75), 17.0, "Dining Table")
		&"coffee_table":
			return table(Vector3(0.95, 0.44, 0.55), 8.5, "Coffee Table")
		&"lamp":
			return floor_lamp(lit)
		&"book":
			return book(rng)
		&"paint_can":
			return paint_can(rng)
		&"sofa":
			return sofa()
		&"tv":
			return television(lit)
		&"cone":
			return traffic_cone()
	push_error("PropFactory: unknown prop kind '%s'" % kind)
	return null


static func chair() -> RigidBody3D:
	var body := _body("Wooden Chair", 5.5, 0.7, 0.1)
	var wood := Mats.prop_wood()
	_box(body, Vector3(0.44, 0.05, 0.44), Vector3(0.0, 0.46, 0.0), wood)
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			_box(body, Vector3(0.05, 0.44, 0.05), Vector3(x, 0.22, z), wood)
		_box(body, Vector3(0.05, 0.5, 0.05), Vector3(x, 0.73, 0.195), wood, false)
	_box(body, Vector3(0.38, 0.1, 0.03), Vector3(0.0, 0.9, 0.195), wood, false)
	_box(body, Vector3(0.38, 0.08, 0.03), Vector3(0.0, 0.7, 0.195), wood, false)
	var back := BoxShape3D.new()
	back.size = Vector3(0.44, 0.5, 0.05)
	_collider(body, back, Vector3(0.0, 0.73, 0.195))
	return body


static func cardboard_box(rng: RandomNumberGenerator) -> RigidBody3D:
	var size := Vector3(rng.randf_range(0.38, 0.7), rng.randf_range(0.3, 0.55), rng.randf_range(0.38, 0.6))
	var body := _body("Cardboard Box", clampf(size.x * size.y * size.z * 26.0, 1.4, 5.0), 0.62, 0.05, 0.6)
	_box(body, size, Vector3(0.0, size.y * 0.5, 0.0), Mats.cardboard())
	var tape := Mats.solid(Color(0.50, 0.38, 0.22), 0.5)
	_box(body, Vector3(size.x * 0.16, 0.004, size.z + 0.004), Vector3(0.0, size.y + 0.002, 0.0), tape, false)
	_box(body, Vector3(size.x * 0.16, size.y * 0.3, 0.004), Vector3(0.0, size.y * 0.85, size.z * 0.5 + 0.002), tape, false)
	_box(body, Vector3(size.x * 0.16, size.y * 0.3, 0.004), Vector3(0.0, size.y * 0.85, -size.z * 0.5 - 0.002), tape, false)
	return body


static func crate() -> RigidBody3D:
	var body := _body("Wooden Crate", 11.0, 0.75, 0.05)
	var size := 0.6
	_box(body, Vector3.ONE * size, Vector3(0.0, size * 0.5, 0.0), Mats.prop_wood())
	var frame := Mats.prop_wood_dark()
	var edge := 0.06
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(body, Vector3(edge, size + 0.01, edge), Vector3(sx * (size - edge) * 0.5, size * 0.5, sz * (size - edge) * 0.5) * Vector3(1.01, 1.0, 1.01), frame, false)
	for y: float in [edge * 0.5, size - edge * 0.5]:
		for side: float in [-1.0, 1.0]:
			_box(body, Vector3(size + 0.012, edge, edge), Vector3(0.0, y, side * (size - edge) * 0.505), frame, false)
			_box(body, Vector3(edge, edge, size + 0.012), Vector3(side * (size - edge) * 0.505, y, 0.0), frame, false)
	return body


## `size` is the overall footprint and height of the table.
static func table(size: Vector3, table_mass: float, display_name: String) -> RigidBody3D:
	var body := _body(display_name, table_mass, 0.8, 0.05)
	var wood := Mats.prop_wood_dark()
	var top_thickness := 0.06
	var leg := 0.07
	_box(body, Vector3(size.x, top_thickness, size.z), Vector3(0.0, size.y - top_thickness * 0.5, 0.0), wood)
	var leg_height := size.y - top_thickness
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(body, Vector3(leg, leg_height, leg), Vector3(sx * (size.x * 0.5 - leg), leg_height * 0.5, sz * (size.z * 0.5 - leg)), wood)
	return body


static func floor_lamp(lit: bool) -> RigidBody3D:
	var body := _body("Floor Lamp", 4.2, 0.75, 0.1, 0.5)
	# Weighted base: it stands on its own but topples when clipped.
	body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(0.0, 0.28, 0.0)
	var metal := Mats.metal_dark()
	_frustum(body, 0.15, 0.17, 0.035, Vector3(0.0, 0.0175, 0.0), metal)
	_frustum(body, 0.018, 0.018, 1.45, Vector3(0.0, 0.76, 0.0), metal, false)
	var pole := BoxShape3D.new()
	pole.size = Vector3(0.04, 1.45, 0.04)
	_collider(body, pole, Vector3(0.0, 0.76, 0.0))
	var shade_material: StandardMaterial3D
	if lit:
		shade_material = Mats.glow(Color(1.0, 0.72, 0.42), 1.6, true)
	else:
		shade_material = Mats.solid(Color(0.55, 0.50, 0.40), 0.95)
	_frustum(body, 0.11, 0.2, 0.26, Vector3(0.0, 1.55, 0.0), shade_material)
	if lit:
		var light := OmniLight3D.new()
		light.name = "Bulb"
		light.position = Vector3(0.0, 1.5, 0.0)
		light.light_color = Color(1.0, 0.70, 0.40)
		light.omni_range = 7.5
		light.omni_attenuation = 1.4
		light.shadow_enabled = true
		light.shadow_bias = 0.06
		light.light_volumetric_fog_energy = 1.5
		body.add_child(light)
		var flicker := FlickerLight.new()
		flicker.base_energy = 2.4
		flicker.flicker_amount = 0.35
		flicker.speed = 5.0
		flicker.dropout_rate = 0.12
		flicker.glow_material = shade_material
		flicker.glow_energy = 1.6
		light.add_child(flicker)
	return body


static func book(rng: RandomNumberGenerator) -> RigidBody3D:
	var body := _body("Occult Tome", 0.55, 0.55, 0.05, 0.8)
	var cover := Mats.solid(BOOK_COLORS[rng.randi() % BOOK_COLORS.size()], 0.8)
	var pages := Mats.solid(Color(0.80, 0.76, 0.64), 0.95)
	var size := Vector3(0.17, 0.045, 0.24)
	_box(body, Vector3(size.x, 0.006, size.z), Vector3(0.0, size.y - 0.003, 0.0), cover, false)
	_box(body, Vector3(size.x, 0.006, size.z), Vector3(0.0, 0.003, 0.0), cover, false)
	_box(body, Vector3(0.008, size.y, size.z), Vector3(-size.x * 0.5 + 0.004, size.y * 0.5, 0.0), cover, false)
	_box(body, Vector3(size.x - 0.014, size.y - 0.012, size.z - 0.012), Vector3(0.004, size.y * 0.5, 0.0), pages, false)
	var shape := BoxShape3D.new()
	shape.size = size
	_collider(body, shape, Vector3(0.0, size.y * 0.5, 0.0))
	return body


static func paint_can(rng: RandomNumberGenerator) -> RigidBody3D:
	var body := _body("Paint Can", 3.4, 0.5, 0.2, 0.15)
	var paint := Mats.solid(PAINT_COLORS[rng.randi() % PAINT_COLORS.size()], 0.6)
	_frustum(body, 0.085, 0.085, 0.19, Vector3(0.0, 0.095, 0.0), Mats.metal_bare())
	_frustum(body, 0.087, 0.087, 0.11, Vector3(0.0, 0.095, 0.0), paint, false)
	_frustum(body, 0.089, 0.089, 0.012, Vector3(0.0, 0.19, 0.0), Mats.metal_bare(), false)
	_frustum(body, 0.05, 0.05, 0.004, Vector3(0.0, 0.198, 0.0), paint, false)
	return body


static func sofa() -> RigidBody3D:
	var body := _body("Moth-Eaten Sofa", 44.0, 0.7, 0.0, 0.8)
	var fabric := Mats.upholstery()
	_box(body, Vector3(2.0, 0.46, 0.85), Vector3(0.0, 0.23, 0.0), fabric)
	_box(body, Vector3(2.0, 0.5, 0.22), Vector3(0.0, 0.71, 0.315), fabric)
	for sx: float in [-1.0, 1.0]:
		_box(body, Vector3(0.2, 0.26, 0.85), Vector3(sx * 0.9, 0.59, 0.0), fabric)
		_box(body, Vector3(0.76, 0.1, 0.6), Vector3(sx * 0.4, 0.5, -0.1), fabric, false)
	return body


static func television(lit: bool) -> RigidBody3D:
	var body := _body("Old Television", 13.0, 0.7, 0.05)
	_box(body, Vector3(0.62, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), Mats.solid(Color(0.14, 0.11, 0.09), 0.6))
	var screen_material: StandardMaterial3D
	if lit:
		screen_material = Mats.glow(Color(0.55, 0.70, 0.95), 2.2, true)
	else:
		screen_material = Mats.glass_dark()
	_box(body, Vector3(0.46, 0.34, 0.01), Vector3(-0.05, 0.27, -0.252), screen_material, false)
	_box(body, Vector3(0.06, 0.3, 0.01), Vector3(0.24, 0.27, -0.252), Mats.metal_dark(), false)
	for sx: float in [-1.0, 1.0]:
		_box(body, Vector3(0.012, 0.45, 0.012), Vector3(sx * 0.1, 0.7, 0.1), Mats.metal_bare(), false, Vector3(0.0, 0.0, -sx * 0.45))
	if lit:
		var light := OmniLight3D.new()
		light.name = "ScreenGlow"
		light.position = Vector3(0.0, 0.3, -0.5)
		light.light_color = Color(0.50, 0.66, 1.0)
		light.omni_range = 5.0
		light.omni_attenuation = 1.6
		body.add_child(light)
		var flicker := FlickerLight.new()
		flicker.base_energy = 1.3
		flicker.flicker_amount = 0.75
		flicker.speed = 22.0
		flicker.glow_material = screen_material
		flicker.glow_energy = 2.2
		light.add_child(flicker)
	return body


static func traffic_cone() -> RigidBody3D:
	var body := _body("Traffic Cone", 1.3, 0.8, 0.25, 0.4)
	var orange := Mats.solid(Color(0.95, 0.35, 0.05), 0.7)
	_box(body, Vector3(0.36, 0.03, 0.36), Vector3(0.0, 0.015, 0.0), orange)
	_frustum(body, 0.03, 0.13, 0.5, Vector3(0.0, 0.28, 0.0), orange)
	_frustum(body, 0.072, 0.095, 0.1, Vector3(0.0, 0.33, 0.0), Mats.solid(Color(0.9, 0.9, 0.88), 0.5), false)
	return body


# --- Assembly helpers -------------------------------------------------------

static func _body(display_name: String, body_mass: float, friction: float, bounce: float, angular_damping: float = 0.3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = display_name.replace(" ", "").replace("-", "")
	body.mass = body_mass
	var surface := PhysicsMaterial.new()
	surface.friction = friction
	surface.bounce = bounce
	body.physics_material_override = surface
	body.collision_layer = GameState.LAYER_PROP
	body.collision_mask = GameState.LAYER_WORLD | GameState.LAYER_PLAYER | GameState.LAYER_PROP | GameState.LAYER_INTERACT
	body.linear_damp = 0.05
	body.angular_damp = angular_damping
	# Small, fast things are the ones that would tunnel through a wall when thrown.
	body.continuous_cd = body_mass < 4.0
	body.add_to_group(GameState.GROUP_GRABBABLE)
	body.set_meta(&"display_name", display_name)
	return body


static func _collider(body: RigidBody3D, shape: Shape3D, at: Vector3) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	body.add_child(collider)


static func _box(body: RigidBody3D, size: Vector3, at: Vector3, material: Material, solid: bool = true, euler: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation = euler
	body.add_child(instance)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_collider(body, shape, at)


## Cylinder or cone section. Collides as a convex hull, which rolls and stacks
## far more reliably than a true cylinder shape.
static func _frustum(body: RigidBody3D, top_radius: float, bottom_radius: float, height: float, at: Vector3, material: Material, solid: bool = true) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	body.add_child(instance)
	if solid:
		var points := PackedVector3Array()
		var sides := 10
		for i in sides:
			var angle := TAU * float(i) / float(sides)
			points.append(Vector3(cos(angle) * top_radius, height * 0.5, sin(angle) * top_radius))
			points.append(Vector3(cos(angle) * bottom_radius, -height * 0.5, sin(angle) * bottom_radius))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		_collider(body, shape, at)
