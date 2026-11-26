extends Node3D
## Procedurally builds the whole Stage 1 site: the fenced front yard with the
## extraction van, the cursed house (porch, living room, hallway, raised study
## and ritual room), its lighting, occult markings and all physics clutter.
##
## World layout: +X is east, -Z is north. The street runs along the south edge,
## the house sits to the north and its front door faces south.

const Mats := preload("res://scripts/MaterialLibrary.gd")
const Occult := preload("res://scripts/OccultMarkings.gd")
const PropFactory := preload("res://scripts/PropFactory.gd")
const ExtractionVan := preload("res://scripts/ExtractionVan.gd")
const HingedDoor := preload("res://scripts/HingedDoor.gd")
const FlickerLight := preload("res://scripts/FlickerLight.gd")

const LAYOUT_SEED := 1313

## Height of the house floor and porch deck above the lawn.
const FLOOR_Y := 0.45
const WALL_HEIGHT := 3.4
const WALL_THICKNESS := 0.3
const DOOR_WIDTH := 2.4
const DOOR_HEIGHT := 2.5
## The study is a split level reached by a short flight of steps.
const STUDY_RAISE := 0.45

const HOUSE_WEST := -10.0
const HOUSE_EAST := 10.0
const HOUSE_NORTH := -24.0
const HOUSE_SOUTH := -4.0
const RITUAL_SPLIT := -15.0
const HALL_WEST := 0.0
const HALL_EAST := 4.0
const FRONT_DOOR_X := -4.0
const DAIS_CENTER := Vector3(0.0, FLOOR_Y, -19.5)
const DAIS_HEIGHT := 0.4

## Direction the moonlight travels (from the south-west, 35 degrees up).
const MOON_DIRECTION := Vector3(0.5774, -0.5774, -0.5774)
const MOON_COLOR := Color(0.55, 0.68, 1.0)
const LAMP_COLOR := Color(1.0, 0.70, 0.40)
const VAN_POSITION := Vector3(4.5, 0.0, 5.0)

var player_spawn := Transform3D(Basis.IDENTITY, Vector3(1.2, 0.1, 7.5))
var van: ExtractionVan
var front_doors: Array[HingedDoor] = []
var prop_count := 0

var _rng := RandomNumberGenerator.new()
var _grounds: StaticBody3D
var _house: StaticBody3D
var _decor: Node3D
var _lights: Node3D
var _props: Node3D
var _chalk: StandardMaterial3D
var _blood: StandardMaterial3D


func _ready() -> void:
	build()


func build() -> void:
	_rng.seed = LAYOUT_SEED
	_grounds = _new_body("Grounds")
	_house = _new_body("House")
	_decor = _new_group("Decor")
	_lights = _new_group("Lights")
	_props = _new_group("Props")
	_chalk = Occult.chalk_material(Color(0.86, 0.86, 0.80), 0.22)
	_blood = Occult.chalk_material(Color(0.75, 0.08, 0.05), 0.9)
	_build_grounds()
	_build_house_shell()
	_build_porch()
	_build_living_room()
	_build_hallway()
	_build_study()
	_build_ritual_room()
	_build_van()
	_build_triggers()
	_spawn_props()


# =============================================================================
# Yard
# =============================================================================

func _build_grounds() -> void:
	# Lawn slab: everything outdoors stands on y = 0.
	_span(_grounds, -26.0, 26.0, -1.0, 0.0, -32.0, 26.0, Mats.grass())
	# Street, kerb, driveway and footpaths are thin visual overlays on the slab.
	_span(_grounds, -26.0, 26.0, 0.0, 0.02, 14.0, 26.0, Mats.asphalt(), false)
	_span(_grounds, -26.0, 26.0, 0.0, 0.05, 13.6, 14.0, Mats.concrete(), false)
	_span(_grounds, 2.2, 6.8, 0.0, 0.025, -1.6, 13.6, Mats.concrete(), false)
	_span(_grounds, FRONT_DOOR_X - 0.9, FRONT_DOOR_X + 0.9, 0.0, 0.022, -0.3, 13.6, Mats.concrete(), false)
	_span(_grounds, FRONT_DOOR_X + 0.9, 2.2, 0.0, 0.02, 2.4, 3.8, Mats.concrete(), false)
	var paint := Mats.solid(Color(0.75, 0.68, 0.30), 0.8)
	var dash_x := -22.0
	while dash_x < 23.0:
		_span(_grounds, dash_x, dash_x + 2.0, 0.02, 0.024, 19.9, 20.1, paint, false)
		dash_x += 5.0
	# A dead hedge closes off the far side of the street.
	_span(_grounds, -26.0, 26.0, 0.0, 3.2, 23.0, 25.0, Mats.textured("hedge", Color(0.07, 0.11, 0.07), Color(0.02, 0.03, 0.02), Vector3(0.5, 0.5, 0.5), 1.0))

	_build_fence()
	# Invisible playfield bounds, taller than anything can be thrown.
	_collider_span(_grounds, -17.2, -16.9, 0.0, 9.0, -29.2, 23.0)
	_collider_span(_grounds, 16.9, 17.2, 0.0, 9.0, -29.2, 23.0)
	_collider_span(_grounds, -17.2, 17.2, 0.0, 9.0, -29.2, -28.9)
	_collider_span(_grounds, -17.2, 17.2, 0.0, 9.0, 22.6, 23.0)

	_tree(Vector3(-12.5, 0.0, 3.5), 6.2)
	_tree(Vector3(-14.0, 0.0, -12.5), 7.0)
	_tree(Vector3(13.2, 0.0, -1.5), 5.6)
	_tree(Vector3(12.0, 0.0, 9.5), 6.6)
	_tree(Vector3(-8.5, 0.0, 10.0), 5.2)
	_tree(Vector3(13.8, 0.0, -20.5), 7.4)
	_street_lamp(Vector3(-10.0, 0.0, 13.0))
	_mailbox(Vector3(1.4, 0.0, 12.9))
	_for_sale_sign(Vector3(-7.4, 0.0, 6.5))

	# Knee-high ground mist hugging the lawn (visible with volumetric fog).
	var mist := FogVolume.new()
	mist.name = "GroundMist"
	mist.size = Vector3(34.0, 1.8, 42.0)
	mist.position = Vector3(0.0, 0.9, -7.0)
	var mist_material := FogMaterial.new()
	mist_material.density = 0.05
	mist_material.albedo = Color(0.62, 0.70, 0.82)
	mist_material.height_falloff = 2.2
	mist_material.edge_fade = 0.3
	mist.material = mist_material
	_decor.add_child(mist)


func _build_fence() -> void:
	var iron := Mats.metal_dark()
	var pickets: Array[Vector3] = []
	var z := -29.0
	while z <= 13.6:
		pickets.append(Vector3(-17.0, 0.9, z))
		pickets.append(Vector3(17.0, 0.9, z))
		z += 0.45
	var x := -16.55
	while x < 17.0:
		pickets.append(Vector3(x, 0.9, -29.0))
		x += 0.45
	var picket := BoxMesh.new()
	picket.size = Vector3(0.04, 1.8, 0.04)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = picket
	multimesh.instance_count = pickets.size()
	for i in pickets.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pickets[i]))
	var fence := MultiMeshInstance3D.new()
	fence.name = "FencePickets"
	fence.multimesh = multimesh
	fence.material_override = iron
	_decor.add_child(fence)
	for rail_y: float in [0.3, 1.5]:
		_span(_decor, -17.03, -16.97, rail_y, rail_y + 0.06, -29.0, 13.6, iron, false)
		_span(_decor, 16.97, 17.03, rail_y, rail_y + 0.06, -29.0, 13.6, iron, false)
		_span(_decor, -17.0, 17.0, rail_y, rail_y + 0.06, -29.03, -28.97, iron, false)


func _tree(at: Vector3, height: float) -> void:
	var bark := Mats.bark()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.1
	trunk.bottom_radius = 0.3
	trunk.height = height
	trunk.radial_segments = 8
	_mesh(_decor, trunk, at + Vector3.UP * height * 0.5, bark)
	_collider_span(_grounds, at.x - 0.22, at.x + 0.22, 0.0, height, at.z - 0.22, at.z + 0.22)
	for i in 7:
		var length := _rng.randf_range(1.4, 2.8)
		var pivot := Node3D.new()
		pivot.position = at + Vector3.UP * height * _rng.randf_range(0.45, 0.97)
		pivot.rotation = Vector3(_rng.randf_range(0.6, 1.25), _rng.randf() * TAU, 0.0)
		_decor.add_child(pivot)
		var limb := CylinderMesh.new()
		limb.top_radius = 0.015
		limb.bottom_radius = 0.07
		limb.height = length
		limb.radial_segments = 5
		_mesh(pivot, limb, Vector3.UP * length * 0.5, bark)
		# One crooked twig per limb.
		var twig_pivot := Node3D.new()
		twig_pivot.position = Vector3.UP * length * _rng.randf_range(0.5, 0.8)
		twig_pivot.rotation = Vector3(_rng.randf_range(-0.9, 0.9), 0.0, _rng.randf_range(0.5, 1.0))
		pivot.add_child(twig_pivot)
		var twig := CylinderMesh.new()
		twig.top_radius = 0.008
		twig.bottom_radius = 0.03
		twig.height = length * 0.5
		twig.radial_segments = 4
		_mesh(twig_pivot, twig, Vector3.UP * length * 0.25, bark)


func _street_lamp(at: Vector3) -> void:
	var iron := Mats.metal_dark()
	_span(_grounds, at.x - 0.07, at.x + 0.07, 0.0, 5.2, at.z - 0.07, at.z + 0.07, iron)
	_span(_decor, at.x - 0.05, at.x + 0.05, 5.1, 5.2, at.z, at.z + 1.5, iron, false)
	_span(_decor, at.x - 0.16, at.x + 0.16, 4.98, 5.1, at.z + 1.1, at.z + 1.6, iron, false)
	var lens := Mats.glow(Color(1.0, 0.62, 0.25), 4.0, true)
	_span(_decor, at.x - 0.12, at.x + 0.12, 4.95, 4.98, at.z + 1.15, at.z + 1.55, lens, false)
	var light := SpotLight3D.new()
	light.name = "StreetLamp"
	light.position = Vector3(at.x, 4.9, at.z + 1.35)
	light.rotation.x = -PI * 0.5
	light.light_color = Color(1.0, 0.62, 0.25)
	light.light_volumetric_fog_energy = 2.2
	light.spot_range = 11.0
	light.spot_angle = 48.0
	light.spot_angle_attenuation = 0.6
	light.shadow_enabled = true
	_lights.add_child(light)
	_add_flicker(light, 6.0, 0.25, 7.0, 0.25, lens, 4.0)


func _mailbox(at: Vector3) -> void:
	_span(_grounds, at.x - 0.05, at.x + 0.05, 0.0, 1.05, at.z - 0.05, at.z + 0.05, Mats.trim_wood())
	_span(_decor, at.x - 0.13, at.x + 0.13, 1.05, 1.3, at.z - 0.25, at.z + 0.25, Mats.metal_dark(), false)
	_span(_decor, at.x + 0.13, at.x + 0.15, 1.15, 1.34, at.z + 0.1, at.z + 0.14, Mats.solid(Color(0.8, 0.1, 0.08), 0.6), false)
	_label(_decor, "13", 48, Vector3(at.x, 1.18, at.z + 0.256), 0.0, Color(0.9, 0.88, 0.8))


func _for_sale_sign(at: Vector3) -> void:
	var wood := Mats.trim_wood()
	_span(_grounds, at.x - 0.75, at.x - 0.65, 0.0, 1.9, at.z - 0.05, at.z + 0.05, wood)
	_span(_grounds, at.x + 0.65, at.x + 0.75, 0.0, 1.9, at.z - 0.05, at.z + 0.05, wood)
	_span(_grounds, at.x - 0.7, at.x + 0.7, 0.85, 1.8, at.z - 0.025, at.z + 0.025, Mats.solid(Color(0.80, 0.77, 0.66), 0.8))
	_label(_decor, "FOR SALE", 80, Vector3(at.x, 1.5, at.z + 0.03), 0.0, Color(0.6, 0.08, 0.06))
	_label(_decor, "MOTIVATED SELLER", 30, Vector3(at.x, 1.2, at.z + 0.03), 0.0, Color(0.12, 0.12, 0.12))
	_label(_decor, "(mildly haunted)", 26, Vector3(at.x, 1.02, at.z + 0.03), 0.0, Color(0.12, 0.12, 0.12))


# =============================================================================
# House shell
# =============================================================================

func _build_house_shell() -> void:
	var edge := WALL_THICKNESS * 0.5
	var siding := Mats.siding()
	var green := Mats.wallpaper_green()
	var panel := Mats.panel_wood()
	var plum := Mats.wallpaper_plum()
	var stone := Mats.wall_stone()
	var study_y := FLOOR_Y + STUDY_RAISE

	# Floors, one slab per room so each can carry its own surface.
	_span(_house, HOUSE_WEST - edge, HALL_WEST, 0.0, FLOOR_Y, RITUAL_SPLIT, HOUSE_SOUTH + edge, Mats.floor_wood())
	_span(_house, HALL_WEST, HALL_EAST - edge, 0.0, FLOOR_Y, RITUAL_SPLIT, HOUSE_SOUTH + edge, Mats.floor_hall())
	_span(_house, HALL_EAST - edge, HOUSE_EAST + edge, 0.0, study_y, RITUAL_SPLIT, HOUSE_SOUTH + edge, Mats.floor_wood())
	_span(_house, HOUSE_WEST - edge, HOUSE_EAST + edge, 0.0, FLOOR_Y, HOUSE_NORTH - edge, RITUAL_SPLIT, Mats.floor_stone())
	# Concrete footing so the raised floor does not show its planks outside.
	var footing := Mats.concrete()
	_span(_decor, HOUSE_WEST - edge - 0.06, HOUSE_EAST + edge + 0.06, 0.0, FLOOR_Y + 0.04, HOUSE_SOUTH + edge, HOUSE_SOUTH + edge + 0.06, footing, false)
	_span(_decor, HOUSE_WEST - edge - 0.06, HOUSE_EAST + edge + 0.06, 0.0, FLOOR_Y + 0.04, HOUSE_NORTH - edge - 0.06, HOUSE_NORTH - edge, footing, false)
	_span(_decor, HOUSE_WEST - edge - 0.06, HOUSE_WEST - edge, 0.0, FLOOR_Y + 0.04, HOUSE_NORTH - edge, HOUSE_SOUTH + edge, footing, false)
	_span(_decor, HOUSE_EAST + edge, HOUSE_EAST + edge + 0.06, 0.0, FLOOR_Y + 0.04, HOUSE_NORTH - edge, HOUSE_SOUTH + edge, footing, false)

	# Ceiling and a front-gabled roof.
	var ceiling_y := FLOOR_Y + WALL_HEIGHT
	_span(_house, HOUSE_WEST - edge, HOUSE_EAST + edge, ceiling_y, ceiling_y + 0.25, HOUSE_NORTH - edge, HOUSE_SOUTH + edge, Mats.plaster())
	var roof_base := ceiling_y + 0.25
	var roof_height := 4.6
	var house_center_z := (HOUSE_NORTH + HOUSE_SOUTH) * 0.5
	var roof := PrismMesh.new()
	roof.size = Vector3(HOUSE_EAST - HOUSE_WEST + 1.5, roof_height, HOUSE_SOUTH - HOUSE_NORTH + 1.3)
	var roof_position := Vector3(0.0, roof_base + roof_height * 0.5, house_center_z)
	_mesh(_house, roof, roof_position, Mats.shingles())
	var roof_collider := CollisionShape3D.new()
	roof_collider.shape = roof.create_convex_shape()
	roof_collider.position = roof_position
	_house.add_child(roof_collider)
	# Siding infill on both gable ends, with a dim attic window at the front.
	var gable := PrismMesh.new()
	gable.size = Vector3(roof.size.x * 0.9, roof_height * 0.9, 0.06)
	for end_z: float in [HOUSE_SOUTH + 0.66, HOUSE_NORTH - 0.66]:
		_mesh(_decor, gable, Vector3(0.0, roof_base + roof_height * 0.45, end_z), siding)
	var attic := CylinderMesh.new()
	attic.top_radius = 0.55
	attic.bottom_radius = 0.55
	attic.height = 0.05
	var attic_window := _mesh(_decor, attic, Vector3(0.0, roof_base + 1.5, HOUSE_SOUTH + 0.7), Mats.glow(Color(0.85, 0.45, 0.15), 0.9))
	attic_window.rotation.x = PI * 0.5
	_span(_decor, -0.6, 0.6, roof_base + 1.47, roof_base + 1.53, HOUSE_SOUTH + 0.7, HOUSE_SOUTH + 0.74, Mats.trim_wood(), false)
	_span(_decor, -0.03, 0.03, roof_base + 0.9, roof_base + 2.1, HOUSE_SOUTH + 0.7, HOUSE_SOUTH + 0.74, Mats.trim_wood(), false)
	_span(_house, -2.8, -1.8, roof_base, roof_base + 5.4, RITUAL_SPLIT - 0.2, RITUAL_SPLIT + 0.8, stone)

	# --- Exterior walls (split per room so each interior face gets its own finish).
	_wall(_house, true, HOUSE_SOUTH, HOUSE_WEST - edge, HALL_WEST, green, siding, FLOOR_Y, -1, [
		{"at": -8.2, "width": 1.5, "bottom": 0.95, "top": 2.45, "window": true},
		{"at": FRONT_DOOR_X, "width": DOOR_WIDTH, "top": DOOR_HEIGHT},
		{"at": -1.4, "width": 1.3, "bottom": 0.95, "top": 2.45, "window": true},
	])
	_wall(_house, true, HOUSE_SOUTH, HALL_WEST, HALL_EAST, panel, siding, FLOOR_Y, -1, [
		{"at": 2.0, "width": 1.2, "bottom": 1.1, "top": 2.5, "window": true, "boarded": true},
	])
	_wall(_house, true, HOUSE_SOUTH, HALL_EAST, HOUSE_EAST + edge, plum, siding, study_y, -1, [
		{"at": 7.0, "width": 1.8, "bottom": 1.35, "top": 2.9, "window": true},
	])
	_wall(_house, true, HOUSE_NORTH, HOUSE_WEST - edge, HOUSE_EAST + edge, siding, stone, FLOOR_Y, 1, [
		{"at": -5.5, "width": 1.6, "bottom": 0.9, "top": 2.9, "window": true},
		{"at": 5.5, "width": 1.6, "bottom": 0.9, "top": 2.9, "window": true},
	])
	_wall(_house, false, HOUSE_WEST, HOUSE_NORTH, RITUAL_SPLIT, siding, stone, FLOOR_Y, 1, [
		{"at": -19.5, "width": 1.6, "bottom": 0.9, "top": 2.9, "window": true},
	])
	_wall(_house, false, HOUSE_WEST, RITUAL_SPLIT, HOUSE_SOUTH, siding, green, FLOOR_Y, 1, [
		{"at": -9.0, "width": 1.8, "bottom": 0.95, "top": 2.45, "window": true},
	])
	_wall(_house, false, HOUSE_EAST, HOUSE_NORTH, RITUAL_SPLIT, stone, siding, FLOOR_Y, -1, [
		{"at": -19.5, "width": 1.6, "bottom": 0.9, "top": 2.9, "window": true},
	])
	_wall(_house, false, HOUSE_EAST, RITUAL_SPLIT, HOUSE_SOUTH, plum, siding, study_y, -1, [
		{"at": -8.5, "width": 1.8, "bottom": 1.35, "top": 2.9, "window": true, "boarded": true},
	])

	# --- Interior walls. Every doorway is wide enough to drag a thrashing demon through.
	_wall(_house, false, HALL_WEST, RITUAL_SPLIT, HOUSE_SOUTH, green, panel, FLOOR_Y, 0, [
		{"at": -9.5, "width": DOOR_WIDTH, "top": DOOR_HEIGHT},
	])
	_wall(_house, false, HALL_EAST, RITUAL_SPLIT, HOUSE_SOUTH, panel, plum, FLOOR_Y, 0, [
		{"at": -11.5, "width": DOOR_WIDTH, "top": DOOR_HEIGHT + STUDY_RAISE},
	])
	_wall(_house, true, RITUAL_SPLIT, HOUSE_WEST, HALL_WEST, stone, green, FLOOR_Y, 0, [
		{"at": -6.2, "width": 2.2, "top": DOOR_HEIGHT},
	])
	_wall(_house, true, RITUAL_SPLIT, HALL_WEST, HALL_EAST, stone, panel, FLOOR_Y, 0, [
		{"at": 2.0, "width": 2.6, "top": DOOR_HEIGHT + 0.2},
	])
	_wall(_house, true, RITUAL_SPLIT, HALL_EAST, HOUSE_EAST, stone, plum, FLOOR_Y, 0, [])

	# Steps up from the hallway into the study.
	_stairs(_house, Vector3(HALL_EAST - edge - 0.96, FLOOR_Y, -11.5), Vector3.RIGHT, DOOR_WIDTH, 3, 0.15, 0.32, Mats.trim_wood())


## Builds one straight wall with door and window openings cut out of it.
## `along_x` walls sit at z = `fixed` and run from x = `from` to `to`; otherwise
## the wall sits at x = `fixed` and runs along z. `mat_neg` / `mat_pos` face the
## negative / positive side of the fixed axis. `inward` is the side the room is
## on (+1 / -1) for exterior walls, or 0 for interior partitions.
## Opening keys: at, width, bottom (default 0), top, window, boarded.
func _wall(body: StaticBody3D, along_x: bool, fixed: float, from: float, to: float, mat_neg: Material,
		mat_pos: Material, room_floor: float, inward: int, openings: Array) -> void:
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	var cursor := from
	for opening: Dictionary in sorted:
		var half: float = opening["width"] * 0.5
		var start: float = opening["at"] - half
		var end: float = opening["at"] + half
		var bottom: float = opening.get("bottom", 0.0)
		var top: float = opening["top"]
		if start > cursor:
			_wall_piece(body, along_x, fixed, cursor, start, 0.0, WALL_HEIGHT, mat_neg, mat_pos)
		if bottom > 0.0:
			_wall_piece(body, along_x, fixed, start, end, 0.0, bottom, mat_neg, mat_pos)
		if top < WALL_HEIGHT:
			_wall_piece(body, along_x, fixed, start, end, top, WALL_HEIGHT, mat_neg, mat_pos)
		cursor = end
		if opening.get("window", false):
			_window(body, along_x, fixed, opening["at"], opening["width"], FLOOR_Y + bottom, FLOOR_Y + top, room_floor, inward, opening.get("boarded", false))
		else:
			_door_trim(along_x, fixed, opening["at"], opening["width"], FLOOR_Y + top)
	if cursor < to:
		_wall_piece(body, along_x, fixed, cursor, to, 0.0, WALL_HEIGHT, mat_neg, mat_pos)


## One rectangular chunk of wall: a single collider with a visual skin on each face.
func _wall_piece(body: StaticBody3D, along_x: bool, fixed: float, u0: float, u1: float, v0: float, v1: float,
		mat_neg: Material, mat_pos: Material) -> void:
	var length := u1 - u0
	var height := v1 - v0
	var mid_u := (u0 + u1) * 0.5
	var mid_y := FLOOR_Y + (v0 + v1) * 0.5
	_aligned_box(body, along_x, fixed, mid_u, mid_y, length, height, WALL_THICKNESS, null, true)
	var skin := WALL_THICKNESS * 0.5
	_aligned_box(body, along_x, fixed - skin * 0.5, mid_u, mid_y, length, height, skin, mat_neg, false)
	_aligned_box(body, along_x, fixed + skin * 0.5, mid_u, mid_y, length, height, skin, mat_pos, false)


## Box positioned in wall space: `u` runs along the wall, `depth` through it.
## A null material makes it collider-only.
func _aligned_box(body: Node3D, along_x: bool, fixed: float, u: float, y: float, u_size: float, y_size: float,
		depth: float, material: Material, solid: bool) -> MeshInstance3D:
	var center := Vector3(u, y, fixed) if along_x else Vector3(fixed, y, u)
	var size := Vector3(u_size, y_size, depth) if along_x else Vector3(depth, y_size, u_size)
	if material == null:
		_collider_box(body, center, size)
		return null
	return _box(body, center, size, material, solid)


func _door_trim(along_x: bool, fixed: float, at: float, width: float, top_y: float) -> void:
	var trim := Mats.trim_wood()
	var depth := WALL_THICKNESS + 0.08
	var bar := 0.09
	var height := top_y - FLOOR_Y
	for side: float in [-1.0, 1.0]:
		_aligned_box(_decor, along_x, fixed, at + side * (width * 0.5 - bar * 0.5 + 0.02), FLOOR_Y + height * 0.5, bar, height, depth, trim, false)
	_aligned_box(_decor, along_x, fixed, at, top_y - bar * 0.5 + 0.02, width + 0.04, bar, depth, trim, false)


func _window(body: StaticBody3D, along_x: bool, fixed: float, at: float, width: float, bottom_y: float, top_y: float,
		room_floor: float, inward: int, boarded: bool) -> void:
	var trim := Mats.trim_wood()
	var height := top_y - bottom_y
	var mid_y := (bottom_y + top_y) * 0.5
	var depth := WALL_THICKNESS + 0.08
	var bar := 0.07
	# Frame, cross mullions and a grimy pane that still stops thrown furniture.
	_aligned_box(_decor, along_x, fixed, at, bottom_y + bar * 0.5, width, bar, depth + 0.06, trim, false)
	_aligned_box(_decor, along_x, fixed, at, top_y - bar * 0.5, width, bar, depth, trim, false)
	for side: float in [-1.0, 1.0]:
		_aligned_box(_decor, along_x, fixed, at + side * (width - bar) * 0.5, mid_y, bar, height, depth, trim, false)
	_aligned_box(_decor, along_x, fixed, at, mid_y, 0.045, height, 0.06, trim, false)
	_aligned_box(_decor, along_x, fixed, at, mid_y, width, 0.045, 0.06, trim, false)
	var pane := _aligned_box(_decor, along_x, fixed, at, mid_y, width, height, 0.02, Mats.glass_dusty(), false)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aligned_box(body, along_x, fixed, at, mid_y, width, height, 0.1, null, true)
	if inward == 0:
		return
	var inward_dir := (Vector3(0.0, 0.0, float(inward)) if along_x else Vector3(float(inward), 0.0, 0.0))
	var lateral := Vector3.RIGHT if along_x else Vector3.BACK
	var center := Vector3(at, mid_y, fixed) if along_x else Vector3(fixed, mid_y, at)
	if boarded:
		# Crooked planks nailed across the inside of the frame.
		var plank_mat := Mats.trim_wood()
		for i in 3:
			var plank := _aligned_box(_decor, along_x, fixed + float(inward) * (WALL_THICKNESS * 0.5 + 0.03), at,
					bottom_y + height * (0.22 + 0.28 * float(i)), width + 0.5, 0.16, 0.03, plank_mat, false)
			var skew := _rng.randf_range(-0.16, 0.16)
			if along_x:
				plank.rotation.z = skew
			else:
				plank.rotation.x = skew
	_moonbeam(center + inward_dir * (WALL_THICKNESS * 0.5 + 0.03), inward_dir, lateral, width - 0.14, height - 0.14, room_floor)


## Moonlight spilling through a window: a fan of additive sheets standing in for
## the light shaft, drifting dust motes, and (for windows the real moon cannot
## reach) a soft fill light pooling on the floor.
func _moonbeam(origin: Vector3, inward: Vector3, lateral: Vector3, width: float, height: float, room_floor: float) -> void:
	var moonlit := MOON_DIRECTION.dot(inward) > 0.0
	var direction := MOON_DIRECTION
	if not moonlit:
		# Mirror the moon across the wall so north and east windows still get a shaft.
		direction = MOON_DIRECTION - 2.0 * MOON_DIRECTION.dot(inward) * inward
	direction = direction.normalized()
	var drop := origin.y + height * 0.5 - room_floor
	var length := minf(drop / -direction.y, 7.5)

	# Many faint sheets, weakest at the rim, so they blend into one soft volume.
	var far := Color(MOON_COLOR.r, MOON_COLOR.g, MOON_COLOR.b, 0.0)
	var reach := direction * length
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 14
	for i in columns:
		var t := float(i) / float(columns - 1)
		var near := Color(MOON_COLOR.r, MOON_COLOR.g, MOON_COLOR.b, 0.02 * _rim_falloff(t))
		var offset := lateral * (t - 0.5) * width
		var top := origin + offset + Vector3.UP * height * 0.5
		var bottom := origin + offset - Vector3.UP * height * 0.5
		_shaft_quad(st, top, bottom, bottom + reach, top + reach, near, far)
	var rows := 12
	for i in rows:
		var t := float(i) / float(rows - 1)
		var near := Color(MOON_COLOR.r, MOON_COLOR.g, MOON_COLOR.b, 0.02 * _rim_falloff(t))
		var offset := Vector3.UP * (t - 0.5) * height
		var left := origin + offset - lateral * width * 0.5
		var right := origin + offset + lateral * width * 0.5
		_shaft_quad(st, left, right, right + reach, left + reach, near, far)
	var shaft := MeshInstance3D.new()
	shaft.name = "Moonbeam"
	shaft.mesh = st.commit()
	shaft.material_override = Mats.light_shaft()
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lights.add_child(shaft)

	var dust := CPUParticles3D.new()
	dust.name = "DustMotes"
	dust.transform = Transform3D(Basis.looking_at(direction, Vector3.UP), origin + reach * 0.45)
	dust.amount = 46
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.randomness = 1.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(width * 0.5, height * 0.45, length * 0.42)
	dust.direction = Vector3(0.3, -1.0, 0.2)
	dust.spread = 70.0
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.015
	dust.initial_velocity_max = 0.07
	dust.scale_amount_min = 0.014
	dust.scale_amount_max = 0.034
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	dust.color_ramp = fade
	var speck := QuadMesh.new()
	speck.size = Vector2.ONE
	dust.mesh = speck
	dust.material_override = Mats.dust_mote()
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lights.add_child(dust)

	if not moonlit:
		var fill := SpotLight3D.new()
		fill.name = "MoonFill"
		var setback := 3.0
		fill.transform = Transform3D(Basis.looking_at(direction, Vector3.UP), origin - direction * setback)
		fill.light_color = MOON_COLOR
		fill.light_energy = 2.2
		fill.light_volumetric_fog_energy = 0.0
		fill.spot_range = setback + length + 1.5
		fill.spot_angle = rad_to_deg(atan(maxf(width, height) * 0.55 / setback))
		fill.spot_attenuation = 0.4
		fill.spot_angle_attenuation = 0.5
		_lights.add_child(fill)


## 1 in the middle of the beam's cross-section, easing to 0.25 at its edges.
func _rim_falloff(t: float) -> float:
	return lerpf(0.25, 1.0, sin(t * PI))


func _shaft_quad(st: SurfaceTool, near_a: Vector3, near_b: Vector3, far_b: Vector3, far_a: Vector3, near: Color, far: Color) -> void:
	var corners := [near_a, near_b, far_b, near_a, far_b, far_a]
	var colors := [near, near, far, near, far, far]
	for i in 6:
		st.set_color(colors[i])
		st.add_vertex(corners[i])


## Visible steps with a hidden ramp laid along their nosings, so players glide
## up and dragged bodies do not snag on every riser. `start` is the foot of the
## first riser; `ascent` is the horizontal direction of travel going up.
func _stairs(body: StaticBody3D, start: Vector3, ascent: Vector3, width: float, steps: int, rise: float, run: float, material: Material) -> void:
	var total_run := run * float(steps)
	var total_rise := rise * float(steps)
	for i in steps:
		var near := run * float(i)
		var length := total_run - near
		var height := rise * float(i + 1)
		var center := start + ascent * (near + length * 0.5) + Vector3.UP * height * 0.5
		var size := Vector3(length, height, width) if absf(ascent.x) > 0.5 else Vector3(width, height, length)
		_box(body, center, size, material)
	var slope := ascent * total_run + Vector3.UP * total_rise
	var slope_dir := slope.normalized()
	var side := Vector3.UP.cross(ascent).normalized()
	var normal := slope_dir.cross(side).normalized()
	var thickness := 0.1
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, thickness, slope.length())
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = Transform3D(Basis(side, normal, slope_dir), start - ascent * run + slope * 0.5 - normal * thickness * 0.5)
	body.add_child(collider)


# =============================================================================
# Porch
# =============================================================================

func _build_porch() -> void:
	var wood := Mats.trim_wood()
	var west := FRONT_DOOR_X - 3.5
	var east := FRONT_DOOR_X + 3.5
	var north := HOUSE_SOUTH + WALL_THICKNESS * 0.5
	var south := -1.2
	_span(_house, west, east, 0.0, FLOOR_Y, north, south, Mats.floor_hall())
	_stairs(_house, Vector3(FRONT_DOOR_X, 0.0, south + 0.9), Vector3.FORWARD, 3.0, 3, 0.15, 0.3, wood)
	# Posts, roof and railings (the steps are left open).
	var roof_y := FLOOR_Y + 2.9
	for post_x: float in [west + 0.1, FRONT_DOOR_X - 1.6, FRONT_DOOR_X + 1.6, east - 0.1]:
		_span(_house, post_x - 0.07, post_x + 0.07, FLOOR_Y, roof_y, south - 0.17, south - 0.03, wood)
	_span(_house, west - 0.4, east + 0.4, roof_y, roof_y + 0.14, north, south + 0.45, Mats.shingles())
	var rail_top := FLOOR_Y + 0.95
	_porch_rail(west + 0.04, west + 0.12, north, south - 0.03, rail_top)
	_porch_rail(east - 0.12, east - 0.04, north, south - 0.03, rail_top)
	_porch_rail(west + 0.1, FRONT_DOOR_X - 1.6, south - 0.14, south - 0.06, rail_top)
	_porch_rail(FRONT_DOOR_X + 1.6, east - 0.1, south - 0.14, south - 0.06, rail_top)

	# Lantern by the door: the first warm, unreliable light the crew sees.
	var lantern_at := Vector3(FRONT_DOOR_X + 1.58, FLOOR_Y + 2.2, north + 0.14)
	_box(_decor, lantern_at + Vector3(0.0, 0.16, -0.06), Vector3(0.2, 0.05, 0.22), Mats.metal_dark(), false)
	var flame := Mats.glow(LAMP_COLOR, 3.5, true)
	_box(_decor, lantern_at, Vector3(0.13, 0.24, 0.13), flame, false).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lantern := OmniLight3D.new()
	lantern.name = "PorchLantern"
	lantern.position = lantern_at + Vector3(0.0, 0.0, 0.15)
	lantern.light_color = LAMP_COLOR
	lantern.omni_range = 8.0
	lantern.omni_attenuation = 1.3
	lantern.light_volumetric_fog_energy = 1.6
	lantern.shadow_enabled = true
	_lights.add_child(lantern)
	_add_flicker(lantern, 2.6, 0.45, 6.0, 0.3, flame, 3.5)

	# Condemned notice nailed up beside the door.
	var notice_x := FRONT_DOOR_X - 2.2
	_box(_decor, Vector3(notice_x, FLOOR_Y + 1.65, north + 0.015), Vector3(1.0, 0.62, 0.03), Mats.solid(Color(0.82, 0.70, 0.14), 0.8), false)
	_label(_decor, "CONDEMNED", 44, Vector3(notice_x, FLOOR_Y + 1.76, north + 0.034), 0.0, Color(0.08, 0.08, 0.08))
	_label(_decor, "BY ORDER OF THE PARISH", 16, Vector3(notice_x, FLOOR_Y + 1.52, north + 0.034), 0.0, Color(0.08, 0.08, 0.08))

	_build_front_doors()


func _porch_rail(x0: float, x1: float, z0: float, z1: float, top_y: float) -> void:
	var wood := Mats.trim_wood()
	# One collider for the whole run; cap rail and mid rail as visuals.
	_collider_span(_house, x0, x1, FLOOR_Y, top_y, z0, z1)
	_span(_decor, x0 - 0.02, x1 + 0.02, top_y - 0.07, top_y, z0 - 0.02, z1 + 0.02, wood, false)
	_span(_decor, x0, x1, FLOOR_Y + 0.4, FLOOR_Y + 0.46, z0, z1, wood, false)
	var along_x := (x1 - x0) > (z1 - z0)
	var cursor := (x0 if along_x else z0) + 0.15
	var limit := x1 if along_x else z1
	while cursor < limit:
		if along_x:
			_span(_decor, cursor - 0.025, cursor + 0.025, FLOOR_Y, top_y - 0.07, z0 + 0.015, z1 - 0.015, wood, false)
		else:
			_span(_decor, x0 + 0.015, x1 - 0.015, FLOOR_Y, top_y - 0.07, cursor - 0.025, cursor + 0.025, wood, false)
		cursor += 0.3


## Double front doors on real hinges. They open inward on F and can be barged.
func _build_front_doors() -> void:
	var leaf_width := DOOR_WIDTH * 0.5 - 0.03
	var leaf_height := DOOR_HEIGHT - 0.08
	var wood := Mats.trim_wood(false)
	var brass := Mats.solid(Color(0.75, 0.58, 0.22), 0.35, 0.9)
	for mirrored: bool in [false, true]:
		var door: HingedDoor = HingedDoor.new()
		door.name = "FrontDoorRight" if mirrored else "FrontDoorLeft"
		door.noun = "front doors"
		door.open_angle = deg_to_rad(-100.0 if mirrored else 100.0)
		door.configure(leaf_width, leaf_height, 0.06, 18.0, wood)
		var hinge_x := FRONT_DOOR_X + (DOOR_WIDTH * 0.5 - 0.02) * (1.0 if mirrored else -1.0)
		door.position = Vector3(hinge_x, FLOOR_Y + 0.03 + leaf_height * 0.5, HOUSE_SOUTH)
		door.rotation.y = PI if mirrored else 0.0
		# Raised panels and a knob on each face.
		for panel_y: float in [0.5, -0.55]:
			_box(door, Vector3(leaf_width * 0.5, panel_y, 0.0), Vector3(leaf_width * 0.7, 0.8, 0.076), Mats.prop_wood_dark(), false)
		for face: float in [-1.0, 1.0]:
			var knob := SphereMesh.new()
			knob.radius = 0.045
			knob.height = 0.09
			_mesh(door, knob, Vector3(leaf_width - 0.12, -0.1, face * 0.07), brass)
		add_child(door)
		door.hinge_to(_house)
		front_doors.append(door)
	front_doors[0].partner = front_doors[1]
	front_doors[1].partner = front_doors[0]


# =============================================================================
# Rooms
# =============================================================================

func _build_living_room() -> void:
	var stone := Mats.wall_stone()
	var wall_z := RITUAL_SPLIT + WALL_THICKNESS * 0.5
	# Fireplace on the north wall with a bed of sullen embers.
	_span(_house, -3.4, -1.2, FLOOR_Y, FLOOR_Y + 1.35, wall_z, wall_z + 0.55, stone)
	_span(_house, -3.0, -1.6, FLOOR_Y + 1.35, FLOOR_Y + WALL_HEIGHT, wall_z, wall_z + 0.4, stone)
	_span(_decor, -3.55, -1.05, FLOOR_Y + 1.35, FLOOR_Y + 1.43, wall_z, wall_z + 0.68, Mats.trim_wood(), false)
	_span(_decor, -2.9, -1.7, FLOOR_Y, FLOOR_Y + 0.9, wall_z + 0.55, wall_z + 0.56, Mats.solid(Color(0.01, 0.01, 0.01), 1.0), false)
	var embers := Mats.glow(Color(1.0, 0.32, 0.06), 2.5, true)
	_span(_decor, -2.75, -1.85, FLOOR_Y, FLOOR_Y + 0.1, wall_z + 0.56, wall_z + 0.72, embers, false).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fire := OmniLight3D.new()
	fire.name = "Embers"
	fire.position = Vector3(-2.3, FLOOR_Y + 0.35, wall_z + 1.0)
	fire.light_color = Color(1.0, 0.38, 0.10)
	fire.omni_range = 5.5
	fire.omni_attenuation = 1.5
	_lights.add_child(fire)
	_add_flicker(fire, 1.4, 0.6, 3.5, 0.0, embers, 2.5)

	# Ceiling beams, a threadbare rug and crooked pictures.
	for beam_z: float in [-6.5, -9.5, -12.5]:
		_span(_decor, HOUSE_WEST + 0.15, HALL_WEST - 0.15, FLOOR_Y + WALL_HEIGHT - 0.22, FLOOR_Y + WALL_HEIGHT, beam_z - 0.11, beam_z + 0.11, Mats.trim_wood(), false)
	_span(_decor, -4.6, -0.6, FLOOR_Y, FLOOR_Y + 0.012, -13.6, -10.6, Mats.textured("rug", Color(0.36, 0.12, 0.12), Color(0.14, 0.05, 0.07), Vector3(1.2, 1.2, 1.2), 1.0), false)
	_picture(Vector3(HOUSE_WEST + 0.17, FLOOR_Y + 1.9, -12.6), Vector3.RIGHT, 0.12)
	_picture(Vector3(HOUSE_WEST + 0.17, FLOOR_Y + 1.8, -5.6), Vector3.RIGHT, -0.2)
	_picture(Vector3(HALL_WEST - 0.17, FLOOR_Y + 1.85, -12.9), Vector3.LEFT, 0.07)

	_pendant_lamp(Vector3(-5.5, FLOOR_Y + WALL_HEIGHT, -9.0), 0.75, 2.6, true, 0.18)

	# Chalk work: a half-finished circle on the boards and a daubed sigil on the wall.
	_floor_marking(Occult.pentagram(1.4, _chalk, 11), Vector3(-6.3, FLOOR_Y, -7.6))
	_wall_marking(Occult.sigil(1.3, _blood, 5), Vector3(HALL_WEST - 0.16, FLOOR_Y + 1.75, -6.3), Vector3.LEFT)


func _build_hallway() -> void:
	# Runner carpet and a stopped grandfather clock.
	_span(_decor, 1.2, 2.8, FLOOR_Y, FLOOR_Y + 0.012, -14.4, -4.8, Mats.textured("runner", Color(0.20, 0.24, 0.30), Color(0.08, 0.09, 0.13), Vector3(1.2, 1.2, 1.2), 1.0), false)
	var wood := Mats.prop_wood_dark()
	_span(_house, 0.2, 0.75, FLOOR_Y, FLOOR_Y + 2.2, -4.7, -4.2, wood)
	_span(_decor, 0.15, 0.8, FLOOR_Y + 2.2, FLOOR_Y + 2.32, -4.75, -4.18, wood, false)
	var face := CylinderMesh.new()
	face.top_radius = 0.2
	face.bottom_radius = 0.2
	face.height = 0.02
	var clock_face := _mesh(_decor, face, Vector3(0.475, FLOOR_Y + 1.85, -4.71), Mats.solid(Color(0.80, 0.76, 0.62), 0.6))
	clock_face.rotation.x = PI * 0.5
	_span(_decor, 0.465, 0.485, FLOOR_Y + 1.85, FLOOR_Y + 2.0, -4.73, -4.722, Mats.metal_dark(), false)

	_pendant_lamp(Vector3(2.0, FLOOR_Y + WALL_HEIGHT, -6.4), 0.6, 2.0, true, 0.4)
	_pendant_lamp(Vector3(2.0, FLOOR_Y + WALL_HEIGHT, -12.8), 0.6, 1.6, false, 0.9)

	# A trail of wards leading toward the ritual room.
	_floor_marking(Occult.rune_circle(0.5, _chalk, 21), Vector3(2.0, FLOOR_Y + 0.012, -6.0))
	_floor_marking(Occult.rune_circle(0.42, _chalk, 22), Vector3(1.6, FLOOR_Y + 0.012, -8.4))
	_floor_marking(Occult.rune_circle(0.55, _chalk, 23), Vector3(2.3, FLOOR_Y + 0.012, -10.8))
	_floor_marking(Occult.rune_circle(0.48, _blood, 24), Vector3(2.0, FLOOR_Y + 0.012, -13.6))
	_wall_marking(Occult.rune_row(6, 0.3, _chalk, 25), Vector3(HALL_WEST + 0.16, FLOOR_Y + 1.6, -6.4), Vector3.RIGHT)


func _build_study() -> void:
	var study_y := FLOOR_Y + STUDY_RAISE
	var wall_z := RITUAL_SPLIT + WALL_THICKNESS * 0.5
	_bookshelf(5.4, wall_z, study_y)
	_bookshelf(7.5, wall_z, study_y)
	_span(_decor, 5.2, 8.8, study_y, study_y + 0.012, -10.2, -6.2, Mats.textured("study_rug", Color(0.16, 0.24, 0.18), Color(0.06, 0.09, 0.08), Vector3(1.2, 1.2, 1.2), 1.0), false)
	_picture(Vector3(HALL_EAST + 0.17, study_y + 1.7, -6.5), Vector3.RIGHT, 0.15)
	_pendant_lamp(Vector3(7.0, FLOOR_Y + WALL_HEIGHT, -9.0), 0.45, 2.2, true, 0.25)
	_floor_marking(Occult.rune_circle(0.95, _chalk, 31), Vector3(6.2, study_y, -12.3))
	_wall_marking(Occult.rune_row(7, 0.32, _blood, 32), Vector3(HOUSE_EAST - 0.16, study_y + 1.0, -12.2), Vector3.LEFT)
	_wall_marking(Occult.sigil(0.9, _chalk, 33), Vector3(9.3, study_y + 1.6, wall_z + 0.012), Vector3.BACK)


func _build_ritual_room() -> void:
	var stone := Mats.wall_stone()
	# Round dais with sloped sides: an elevated stage the demon will have to be dragged off.
	var dais := CylinderMesh.new()
	dais.top_radius = 2.95
	dais.bottom_radius = 3.75
	dais.height = DAIS_HEIGHT
	dais.radial_segments = 28
	dais.rings = 1
	var dais_position := DAIS_CENTER + Vector3.UP * DAIS_HEIGHT * 0.5
	_mesh(_house, dais, dais_position, Mats.floor_stone())
	var dais_collider := CollisionShape3D.new()
	dais_collider.shape = dais.create_convex_shape()
	dais_collider.position = dais_position
	_house.add_child(dais_collider)

	# The main event: a pulsing summoning circle ringed with candles.
	var dais_top := DAIS_CENTER + Vector3.UP * DAIS_HEIGHT
	var ember := Occult.chalk_material(Color(1.0, 0.16, 0.06), 3.0)
	_floor_marking(Occult.pentagram(2.6, ember, 41), dais_top)
	var heart := OmniLight3D.new()
	heart.name = "PentagramGlow"
	heart.position = dais_top + Vector3.UP * 0.6
	heart.light_color = Color(1.0, 0.14, 0.05)
	heart.omni_range = 9.0
	heart.omni_attenuation = 1.2
	heart.light_volumetric_fog_energy = 2.5
	_lights.add_child(heart)
	_add_flicker(heart, 2.2, 0.75, 0.9, 0.0, ember, 3.4)
	for i in 5:
		var angle := -PI * 0.5 + TAU * float(i) / 5.0
		_candle(dais_top + Vector3(cos(angle), 0.0, sin(angle)) * 2.78, _rng.randf_range(0.14, 0.3), true)
	var haze := FogVolume.new()
	haze.name = "RitualHaze"
	haze.size = Vector3(8.0, 1.4, 8.0)
	haze.position = dais_top + Vector3.UP * 0.6
	var haze_material := FogMaterial.new()
	haze_material.density = 0.22
	haze_material.albedo = Color(0.75, 0.25, 0.2)
	haze_material.emission = Color(0.10, 0.008, 0.004)
	haze_material.height_falloff = 1.6
	haze_material.edge_fade = 0.5
	haze.material = haze_material
	_decor.add_child(haze)

	# Chains hang over the circle from the ceiling.
	var chain := Mats.metal_dark()
	for i in 4:
		var angle := PI * 0.25 + TAU * float(i) / 4.0
		var at := DAIS_CENTER + Vector3(cos(angle), 0.0, sin(angle)) * 1.6
		var drop := _rng.randf_range(0.9, 1.5)
		_span(_decor, at.x - 0.015, at.x + 0.015, FLOOR_Y + WALL_HEIGHT - drop, FLOOR_Y + WALL_HEIGHT, at.z - 0.015, at.z + 0.015, chain, false)
		_span(_decor, at.x - 0.05, at.x + 0.05, FLOOR_Y + WALL_HEIGHT - drop - 0.08, FLOOR_Y + WALL_HEIGHT - drop, at.z - 0.015, at.z + 0.015, chain, false)

	# Pillars.
	for pillar_x: float in [-6.6, 6.6]:
		for pillar_z: float in [-17.2, -21.8]:
			_span(_house, pillar_x - 0.3, pillar_x + 0.3, FLOOR_Y, FLOOR_Y + WALL_HEIGHT, pillar_z - 0.3, pillar_z + 0.3, stone)
			_span(_decor, pillar_x - 0.42, pillar_x + 0.42, FLOOR_Y, FLOOR_Y + 0.25, pillar_z - 0.42, pillar_z + 0.42, stone, false)
			_span(_decor, pillar_x - 0.42, pillar_x + 0.42, FLOOR_Y + WALL_HEIGHT - 0.25, FLOOR_Y + WALL_HEIGHT, pillar_z - 0.42, pillar_z + 0.42, stone, false)

	# Altar against the north wall, under a glowing sigil.
	var wall_z := HOUSE_NORTH + WALL_THICKNESS * 0.5
	_span(_house, -1.2, 1.2, FLOOR_Y, FLOOR_Y + 0.95, wall_z, wall_z + 0.9, stone)
	_span(_decor, -1.32, 1.32, FLOOR_Y + 0.95, FLOOR_Y + 1.04, wall_z, wall_z + 1.0, Mats.floor_stone(), false)
	_span(_decor, -0.45, 0.45, FLOOR_Y + 1.04, FLOOR_Y + 1.05, wall_z, wall_z + 1.02, Mats.solid(Color(0.35, 0.03, 0.04), 0.9), false)
	var altar_top := FLOOR_Y + 1.04
	_candle(Vector3(-0.95, altar_top, wall_z + 0.45), 0.26, true)
	_candle(Vector3(0.95, altar_top, wall_z + 0.45), 0.2, true)
	_candle(Vector3(-0.75, altar_top, wall_z + 0.7), 0.12, false)
	var skull := SphereMesh.new()
	skull.radius = 0.11
	skull.height = 0.2
	_mesh(_decor, skull, Vector3(0.0, altar_top + 0.11, wall_z + 0.5), Mats.solid(Color(0.78, 0.74, 0.62), 0.7))
	for eye_x: float in [-0.04, 0.04]:
		_box(_decor, Vector3(eye_x, altar_top + 0.12, wall_z + 0.6), Vector3(0.035, 0.035, 0.03), Mats.solid(Color(0.02, 0.02, 0.02), 1.0), false)
	var mark := Occult.chalk_material(Color(1.0, 0.16, 0.06), 1.6)
	_wall_marking(Occult.sigil(1.7, mark, 42), Vector3(0.0, FLOOR_Y + 2.25, wall_z + 0.012), Vector3.BACK)
	_wall_marking(Occult.rune_row(8, 0.34, _blood, 43), Vector3(HOUSE_WEST + 0.16, FLOOR_Y + 1.5, -22.4), Vector3.RIGHT)
	_wall_marking(Occult.rune_row(8, 0.34, _blood, 44), Vector3(HOUSE_EAST - 0.16, FLOOR_Y + 1.5, -16.8), Vector3.LEFT)
	_floor_marking(Occult.rune_circle(0.8, _chalk, 45), Vector3(-7.2, FLOOR_Y, -19.4))
	_floor_marking(Occult.rune_circle(0.7, _chalk, 46), Vector3(7.4, FLOOR_Y, -22.0))


# =============================================================================
# Van, triggers and clutter
# =============================================================================

func _build_van() -> void:
	van = ExtractionVan.new()
	van.name = "ExtractionVan"
	van.position = VAN_POSITION
	add_child(van)


func _build_triggers() -> void:
	_trigger(GameState.STEP_ENTER_HOUSE, HOUSE_WEST + 0.4, HALL_WEST - 0.4, FLOOR_Y, FLOOR_Y + 2.6, RITUAL_SPLIT + 0.4, HOUSE_SOUTH - 0.7)
	_trigger(GameState.STEP_FIND_RITUAL, HOUSE_WEST + 0.4, HOUSE_EAST - 0.4, FLOOR_Y, FLOOR_Y + 2.6, HOUSE_NORTH + 0.4, RITUAL_SPLIT - 0.7)


func _trigger(step: StringName, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	var area := Area3D.new()
	area.name = "Trigger_%s" % step
	area.collision_layer = 0
	area.collision_mask = GameState.LAYER_PLAYER
	area.monitorable = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(x1 - x0, y1 - y0, z1 - z0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	area.add_child(collider)
	area.position = Vector3(x0 + x1, y0 + y1, z0 + z1) * 0.5
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group(GameState.GROUP_PLAYER):
			GameState.complete_step(step))


func _spawn_props() -> void:
	var fy := FLOOR_Y
	var sy := FLOOR_Y + STUDY_RAISE

	# --- Front yard and porch.
	_prop(&"cone", Vector3(2.7, 0.0, 1.3))
	_prop(&"cone", Vector3(6.4, 0.0, 0.9))
	_prop(&"cone", Vector3(2.5, 0.0, 9.0), 20.0, Vector3(88.0, 0.0, 0.0), 0.2)
	_prop(&"crate", Vector3(7.6, 0.0, 2.6), 14.0)
	_prop(&"paint_can", Vector3(7.5, 0.62, 2.7))
	_prop(&"box", Vector3(-6.7, 0.0, 0.6), 30.0)
	_prop(&"box", Vector3(-6.6, fy, -2.6), -12.0)
	_prop(&"chair", Vector3(-1.4, fy, -2.7), 200.0)
	_prop(&"paint_can", Vector3(-2.2, fy, -1.8))

	# --- Living room: an interrupted dinner party.
	_prop(&"sofa", Vector3(-2.6, fy, -11.2), 4.0)
	_prop(&"coffee_table", Vector3(-2.6, fy, -12.6), 8.0)
	_prop(&"table", Vector3(-6.4, fy, -7.4), 25.0, Vector3(0.0, 0.0, 96.0), 0.75)
	_prop(&"chair", Vector3(-7.9, fy, -6.4), 110.0)
	_prop(&"chair", Vector3(-4.8, fy, -8.6), -60.0)
	_prop(&"chair", Vector3(-7.4, fy, -9.6), 40.0, Vector3(92.0, 0.0, 0.0), 0.3)
	_prop(&"chair", Vector3(-5.9, fy, -6.9), -150.0, Vector3(0.0, 0.0, -94.0), 0.3)
	_prop(&"crate", Vector3(-9.0, fy, -4.9), 40.0)
	_prop(&"tv", Vector3(-9.0, fy + 0.62, -4.9), -45.0, Vector3.ZERO, 0.02, true)
	_prop(&"lamp", Vector3(-9.1, fy, -14.0), 0.0, Vector3.ZERO, 0.02, true)
	_prop(&"lamp", Vector3(-3.4, fy, -7.0), 70.0, Vector3(0.0, 0.0, 86.0), 0.25)
	_prop(&"box", Vector3(-1.1, fy, -5.0), 10.0)
	_prop(&"box", Vector3(-1.2, fy + 0.6, -5.1), -25.0)
	_prop(&"box", Vector3(-0.9, fy, -6.5), 50.0)
	_prop(&"box", Vector3(-8.6, fy, -11.2), 15.0)
	_prop(&"paint_can", Vector3(-7.6, fy, -8.2))
	_prop(&"paint_can", Vector3(-5.3, fy, -7.0), 0.0, Vector3(90.0, 0.0, 0.0), 0.12)
	_prop(&"book", Vector3(-2.7, fy + 0.46, -12.5), 20.0)
	_prop(&"book", Vector3(-2.4, fy + 0.46, -12.75), -40.0)
	_prop(&"book", Vector3(-3.9, fy, -9.9), 75.0)
	_prop(&"book", Vector3(-6.9, fy, -11.9), 130.0)
	_prop(&"book", Vector3(-8.0, fy, -13.0), 10.0)

	# --- Hallway.
	_prop(&"box", Vector3(3.2, fy, -5.0), 5.0)
	_prop(&"box", Vector3(3.1, fy + 0.6, -5.1), 35.0)
	_prop(&"box", Vector3(3.3, fy, -6.4), -20.0)
	_prop(&"chair", Vector3(0.9, fy, -7.2), 30.0, Vector3(90.0, 0.0, 0.0), 0.3)
	_prop(&"paint_can", Vector3(0.7, fy, -13.9))
	_prop(&"paint_can", Vector3(1.0, fy, -14.3))
	_prop(&"book", Vector3(2.6, fy, -9.4), 60.0)
	_prop(&"book", Vector3(1.5, fy, -12.0), -30.0)

	# --- Study.
	_prop(&"table", Vector3(7.8, sy, -6.6), 90.0)
	_prop(&"chair", Vector3(6.6, sy, -6.6), 95.0)
	_prop(&"chair", Vector3(8.6, sy, -10.6), 0.0, Vector3(0.0, 0.0, 92.0), 0.3)
	_prop(&"lamp", Vector3(9.3, sy, -4.9), 0.0, Vector3.ZERO, 0.02, true)
	_prop(&"crate", Vector3(4.9, sy, -5.0), -8.0)
	_prop(&"box", Vector3(4.9, sy + 0.62, -5.0), 22.0)
	_prop(&"box", Vector3(5.2, sy, -6.4), 40.0)
	_prop(&"book", Vector3(7.7, sy + 0.79, -6.3), 15.0)
	_prop(&"book", Vector3(7.75, sy + 0.84, -6.32), -10.0)
	_prop(&"book", Vector3(7.9, sy + 0.79, -7.0), 80.0)
	_prop(&"book", Vector3(5.6, sy, -13.4), 35.0)
	_prop(&"book", Vector3(6.3, sy, -13.7), -70.0)
	_prop(&"book", Vector3(7.6, sy, -13.2), 5.0)
	_prop(&"book", Vector3(8.4, sy, -12.6), 150.0)
	_prop(&"book", Vector3(6.9, sy, -11.0), -15.0)

	# --- Ritual room.
	_prop(&"chair", Vector3(-4.4, fy, -17.0), 60.0, Vector3(90.0, 0.0, 0.0), 0.3)
	_prop(&"chair", Vector3(4.6, fy, -21.6), -120.0, Vector3(0.0, 0.0, 95.0), 0.3)
	_prop(&"chair", Vector3(4.2, fy, -16.6), 215.0)
	_prop(&"coffee_table", Vector3(-8.2, fy, -22.2), 30.0, Vector3(0.0, 0.0, 180.0), 0.5)
	_prop(&"paint_can", Vector3(-3.9, fy, -20.6))
	_prop(&"paint_can", Vector3(-4.2, fy, -21.0))
	_prop(&"paint_can", Vector3(3.9, fy, -18.4), 0.0, Vector3(90.0, 0.0, 0.0), 0.12)
	_prop(&"box", Vector3(8.6, fy, -16.3), 12.0)
	_prop(&"box", Vector3(8.4, fy, -17.6), -35.0)
	_prop(&"crate", Vector3(-8.8, fy, -16.2), 5.0)
	_prop(&"book", Vector3(0.45, fy + 1.06, HOUSE_NORTH + 0.6), 25.0)
	_prop(&"book", Vector3(-2.4, fy, -22.6), 100.0)
	_prop(&"book", Vector3(2.2, fy, -23.0), -50.0)


## Spawns one clutter prop. `lift` raises the spawn point so tipped-over props
## start clear of the floor and settle under gravity.
func _prop(kind: StringName, at: Vector3, yaw_degrees: float = 0.0, tilt_degrees: Vector3 = Vector3.ZERO,
		lift: float = 0.02, lit: bool = false) -> RigidBody3D:
	var prop := PropFactory.create(kind, _rng, lit)
	if prop == null:
		return null
	prop.position = at + Vector3.UP * lift
	prop.rotation = Vector3(deg_to_rad(tilt_degrees.x), deg_to_rad(yaw_degrees), deg_to_rad(tilt_degrees.z))
	_props.add_child(prop, true)
	prop_count += 1
	return prop


# =============================================================================
# Set dressing helpers
# =============================================================================

## Hanging ceiling lamp with a failing bulb. `at` is the ceiling fixing point.
func _pendant_lamp(at: Vector3, drop: float, energy: float, shadows: bool, dropout_rate: float) -> void:
	var metal := Mats.metal_dark()
	var cord := CylinderMesh.new()
	cord.top_radius = 0.012
	cord.bottom_radius = 0.012
	cord.height = drop
	cord.radial_segments = 6
	_mesh(_decor, cord, at + Vector3.DOWN * drop * 0.5, metal)
	var shade := CylinderMesh.new()
	shade.top_radius = 0.05
	shade.bottom_radius = 0.26
	shade.height = 0.2
	shade.radial_segments = 16
	# The shade would throw a hard black disc across the ceiling, so it casts no shadow.
	_mesh(_decor, shade, at + Vector3.DOWN * (drop + 0.1), metal).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb_material := Mats.glow(LAMP_COLOR, 4.0, true)
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	_mesh(_decor, bulb, at + Vector3.DOWN * (drop + 0.2), bulb_material).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "PendantLamp"
	light.position = at + Vector3.DOWN * (drop + 0.3)
	light.light_color = LAMP_COLOR
	light.omni_range = 10.5
	light.omni_attenuation = 1.25
	light.light_volumetric_fog_energy = 1.4
	light.shadow_enabled = shadows
	light.shadow_bias = 0.06
	_lights.add_child(light)
	_add_flicker(light, energy, 0.35, 6.5, dropout_rate, bulb_material, 4.0)


func _candle(at: Vector3, height: float, lit: bool) -> void:
	var wax := CylinderMesh.new()
	wax.top_radius = 0.03
	wax.bottom_radius = 0.036
	wax.height = height
	wax.radial_segments = 8
	_mesh(_decor, wax, at + Vector3.UP * height * 0.5, Mats.solid(Color(0.72, 0.66, 0.52), 0.6))
	if not lit:
		return
	var flame_material := Mats.glow(Color(1.0, 0.62, 0.22), 5.0, true)
	var flame := SphereMesh.new()
	flame.radius = 0.016
	flame.height = 0.07
	_mesh(_decor, flame, at + Vector3.UP * (height + 0.04), flame_material).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "Candle"
	light.position = at + Vector3.UP * (height + 0.1)
	light.light_color = Color(1.0, 0.58, 0.24)
	light.omni_range = 3.2
	light.omni_attenuation = 1.6
	_lights.add_child(light)
	_add_flicker(light, 0.7, 0.55, 9.0, 0.0, flame_material, 5.0)


func _add_flicker(light: Light3D, energy: float, amount: float, speed: float, dropout_rate: float,
		glow_material: StandardMaterial3D = null, glow_energy: float = 3.0) -> void:
	var flicker := FlickerLight.new()
	flicker.base_energy = energy
	flicker.flicker_amount = amount
	flicker.speed = speed
	flicker.dropout_rate = dropout_rate
	flicker.glow_material = glow_material
	flicker.glow_energy = glow_energy
	light.light_energy = energy
	light.add_child(flicker)


## Bookcase standing against a north wall, stuffed with (static) spines.
func _bookshelf(center_x: float, wall_z: float, floor_y: float) -> void:
	var wood := Mats.prop_wood_dark()
	var width := 1.9
	var height := 2.4
	var depth := 0.38
	var x0 := center_x - width * 0.5
	_collider_span(_house, x0, x0 + width, floor_y, floor_y + height, wall_z, wall_z + depth)
	_span(_decor, x0, x0 + width, floor_y, floor_y + height, wall_z, wall_z + 0.04, wood, false)
	for side_x: float in [x0, x0 + width - 0.05]:
		_span(_decor, side_x, side_x + 0.05, floor_y, floor_y + height, wall_z, wall_z + depth, wood, false)
	var shelves := 5
	for i in shelves + 1:
		var shelf_y := floor_y + (height - 0.05) * float(i) / float(shelves)
		_span(_decor, x0, x0 + width, shelf_y, shelf_y + 0.05, wall_z, wall_z + depth, wood, false)
		if i == shelves:
			break
		# Blocks of spines with gaps where tomes have been pulled out.
		var cursor := x0 + 0.08
		while cursor < x0 + width - 0.35:
			var block := _rng.randf_range(0.14, 0.42)
			if _rng.randf() < 0.78:
				var spine_height := _rng.randf_range(0.26, 0.38)
				var color: Color = PropFactory.BOOK_COLORS[_rng.randi() % PropFactory.BOOK_COLORS.size()]
				_span(_decor, cursor, cursor + block, shelf_y + 0.05, shelf_y + 0.05 + spine_height, wall_z + 0.08, wall_z + depth - 0.05, Mats.solid(color.darkened(_rng.randf_range(0.0, 0.3)), 0.85), false)
			cursor += block + 0.02


## Framed picture hung askew. `facing` is the wall normal pointing into the room.
func _picture(at: Vector3, facing: Vector3, roll: float) -> void:
	var pivot := Node3D.new()
	pivot.transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), at)
	pivot.rotate_object_local(Vector3.BACK, roll)
	_decor.add_child(pivot)
	_box(pivot, Vector3.ZERO, Vector3(0.8, 1.0, 0.04), Mats.trim_wood(false), false)
	_box(pivot, Vector3(0.0, 0.0, 0.012), Vector3(0.66, 0.86, 0.03), Mats.textured("portrait", Color(0.30, 0.26, 0.20), Color(0.03, 0.03, 0.04), Vector3(1.6, 1.6, 1.6), 0.6, false, 0.02), false)


func _floor_marking(marking: MeshInstance3D, at: Vector3) -> void:
	marking.position = at + Vector3.UP * 0.008
	_decor.add_child(marking)


## Stands a flat marking up against a wall whose normal is `facing`.
func _wall_marking(marking: MeshInstance3D, at: Vector3, facing: Vector3) -> void:
	marking.transform = Transform3D(Basis(Quaternion(Vector3.UP, facing)), at)
	_decor.add_child(marking)


# =============================================================================
# Geometry helpers
# =============================================================================

func _new_body(body_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = GameState.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	return body


func _new_group(group_name: String) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	add_child(group)
	return group


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


## Box by centre and size. With `solid`, `parent` must be a physics body.
func _box(parent: Node3D, center: Vector3, size: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	if solid:
		_collider_box(parent, center, size)
	return _mesh(parent, mesh, center, material)


## Box by min/max corners.
func _span(parent: Node3D, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, material: Material, solid: bool = true) -> MeshInstance3D:
	return _box(parent, Vector3(x0 + x1, y0 + y1, z0 + z1) * 0.5, Vector3(x1 - x0, y1 - y0, z1 - z0), material, solid)


func _collider_box(body: Node3D, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = center
	body.add_child(collider)


func _collider_span(body: Node3D, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	_collider_box(body, Vector3(x0 + x1, y0 + y1, z0 + z1) * 0.5, Vector3(x1 - x0, y1 - y0, z1 - z0))


func _label(parent: Node3D, text: String, font_size: int, at: Vector3, yaw: float, color: Color) -> void:
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
	parent.add_child(label)
