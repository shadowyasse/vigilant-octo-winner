extends RefCounted
## Shared procedural materials. Everything is generated from engine resources
## (FastNoiseLite, gradients) so the project ships with no texture files.
## Results are cached by key, so repeated calls return the same resource.

static var _cache: Dictionary = {}


## Plain PBR colour.
static func solid(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "solid:%s:%.2f:%.2f" % [color.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	_cache[key] = mat
	return mat


## Self-lit surface (bulbs, lenses, embers). Not cached when `unique` so callers can animate it.
static func glow(color: Color, energy: float = 2.0, unique: bool = false) -> StandardMaterial3D:
	var key := "glow:%s:%.2f" % [color.to_html(), energy]
	if not unique and _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	if not unique:
		_cache[key] = mat
	return mat


## Noise-tinted triplanar surface. `world` keeps the pattern continuous across
## static geometry; moving props pass false so the pattern travels with them.
static func textured(key: String, light: Color, dark: Color, uv_scale: Vector3, roughness: float = 0.9,
		world: bool = true, frequency: float = 0.03, bump: float = 0.0) -> StandardMaterial3D:
	var cache_key := "tex:%s:%s" % [key, world]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = absi(hash(key)) % 100000
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, dark)
	ramp.set_color(1, light)
	var albedo := NoiseTexture2D.new()
	albedo.width = 256
	albedo.height = 256
	albedo.seamless = true
	albedo.generate_mipmaps = true
	albedo.noise = noise
	albedo.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = albedo
	mat.roughness = roughness
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = world
	mat.uv1_scale = uv_scale
	if bump > 0.0:
		var normal := NoiseTexture2D.new()
		normal.width = 256
		normal.height = 256
		normal.seamless = true
		normal.generate_mipmaps = true
		normal.noise = noise
		normal.as_normal_map = true
		normal.bump_strength = 6.0
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = bump
	_cache[cache_key] = mat
	return mat


# --- Architecture -----------------------------------------------------------

static func floor_wood() -> StandardMaterial3D:
	return textured("floor_wood", Color(0.34, 0.22, 0.13), Color(0.13, 0.08, 0.05), Vector3(2.6, 1.0, 0.16), 0.72, true, 0.035, 0.5)


static func floor_hall() -> StandardMaterial3D:
	return textured("floor_hall", Color(0.22, 0.15, 0.11), Color(0.08, 0.05, 0.04), Vector3(0.16, 1.0, 2.6), 0.7, true, 0.035, 0.5)


static func floor_stone() -> StandardMaterial3D:
	return textured("floor_stone", Color(0.30, 0.30, 0.33), Color(0.10, 0.10, 0.12), Vector3(0.35, 0.35, 0.35), 0.95, true, 0.02, 0.9)


static func wallpaper_green() -> StandardMaterial3D:
	return textured("wall_green", Color(0.30, 0.36, 0.27), Color(0.15, 0.19, 0.14), Vector3(0.5, 0.12, 0.5), 0.95, true, 0.02)


static func wallpaper_plum() -> StandardMaterial3D:
	return textured("wall_plum", Color(0.36, 0.20, 0.24), Color(0.17, 0.09, 0.12), Vector3(0.5, 0.12, 0.5), 0.95, true, 0.02)


static func panel_wood() -> StandardMaterial3D:
	return textured("wall_panel", Color(0.28, 0.19, 0.12), Color(0.12, 0.08, 0.05), Vector3(1.6, 0.12, 1.6), 0.8, true, 0.03, 0.3)


static func wall_stone() -> StandardMaterial3D:
	return textured("wall_stone", Color(0.23, 0.22, 0.25), Color(0.07, 0.07, 0.09), Vector3(0.3, 0.3, 0.3), 0.97, true, 0.025, 1.0)


static func siding() -> StandardMaterial3D:
	return textured("siding", Color(0.36, 0.38, 0.40), Color(0.17, 0.19, 0.22), Vector3(0.12, 2.4, 0.12), 0.9, true, 0.03, 0.4)


static func plaster() -> StandardMaterial3D:
	return textured("plaster", Color(0.42, 0.40, 0.36), Color(0.24, 0.23, 0.21), Vector3(0.25, 0.25, 0.25), 0.97, true, 0.02)


static func shingles() -> StandardMaterial3D:
	return textured("shingles", Color(0.16, 0.14, 0.15), Color(0.06, 0.05, 0.06), Vector3(0.5, 1.5, 0.5), 0.95, true, 0.04, 0.6)


static func trim_wood(world: bool = true) -> StandardMaterial3D:
	return textured("trim_wood", Color(0.24, 0.15, 0.09), Color(0.09, 0.05, 0.03), Vector3(2.0, 0.3, 2.0), 0.75, world, 0.04)


static func concrete() -> StandardMaterial3D:
	return textured("concrete", Color(0.40, 0.40, 0.39), Color(0.22, 0.22, 0.22), Vector3(0.3, 0.3, 0.3), 0.96, true, 0.03, 0.4)


static func grass() -> StandardMaterial3D:
	return textured("grass", Color(0.15, 0.22, 0.11), Color(0.05, 0.08, 0.05), Vector3(0.22, 0.22, 0.22), 1.0, true, 0.045, 0.6)


static func asphalt() -> StandardMaterial3D:
	return textured("asphalt", Color(0.15, 0.15, 0.16), Color(0.06, 0.06, 0.07), Vector3(0.6, 0.6, 0.6), 0.93, true, 0.06, 0.5)


static func bark() -> StandardMaterial3D:
	return textured("bark", Color(0.17, 0.13, 0.10), Color(0.05, 0.04, 0.03), Vector3(2.0, 0.3, 2.0), 1.0, true, 0.04, 0.8)


## Grimy, mostly transparent window glass.
static func glass_dusty() -> StandardMaterial3D:
	if _cache.has("glass_dusty"):
		return _cache["glass_dusty"]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	noise.seed = 77
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.45, 0.52, 0.60, 0.05))
	ramp.set_color(1, Color(0.62, 0.62, 0.56, 0.40))
	var grime := NoiseTexture2D.new()
	grime.width = 256
	grime.height = 256
	grime.seamless = true
	grime.noise = noise
	grime.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = grime
	mat.roughness = 0.25
	mat.metallic = 0.1
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.7, 0.7, 0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["glass_dusty"] = mat
	return mat


## Additive, unshaded material that reads its colour and fade from vertex colours.
static func light_shaft() -> StandardMaterial3D:
	if _cache.has("light_shaft"):
		return _cache["light_shaft"]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1)
	# Melt away near the lens and where the sheets cut into floors and furniture,
	# so the stack of planes reads as one soft volume.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 0.8
	mat.distance_fade_max_distance = 4.0
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.7
	_cache["light_shaft"] = mat
	return mat


## Billboarded speck used by the dust-mote particle systems.
static func dust_mote() -> StandardMaterial3D:
	if _cache.has("dust_mote"):
		return _cache["dust_mote"]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.85, 0.9, 1.0, 0.7)
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.gradient = falloff
	mat.albedo_texture = dot
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 0.3
	mat.distance_fade_max_distance = 1.6
	_cache["dust_mote"] = mat
	return mat


# --- Props and vehicle ------------------------------------------------------

static func prop_wood() -> StandardMaterial3D:
	return textured("prop_wood", Color(0.46, 0.30, 0.17), Color(0.22, 0.13, 0.07), Vector3(3.0, 0.5, 3.0), 0.7, false, 0.04)


static func prop_wood_dark() -> StandardMaterial3D:
	return textured("prop_wood_dark", Color(0.26, 0.16, 0.10), Color(0.10, 0.06, 0.04), Vector3(3.0, 0.5, 3.0), 0.65, false, 0.04)


static func cardboard() -> StandardMaterial3D:
	return textured("cardboard", Color(0.62, 0.47, 0.30), Color(0.44, 0.32, 0.20), Vector3(1.2, 1.2, 1.2), 0.95, false, 0.05)


static func upholstery() -> StandardMaterial3D:
	return textured("upholstery", Color(0.33, 0.14, 0.13), Color(0.16, 0.06, 0.06), Vector3(1.5, 1.5, 1.5), 1.0, false, 0.06, 0.5)


static func metal_dark() -> StandardMaterial3D:
	return solid(Color(0.10, 0.11, 0.12), 0.45, 0.8)


static func metal_bare() -> StandardMaterial3D:
	return solid(Color(0.55, 0.57, 0.60), 0.35, 0.9)


static func rubber() -> StandardMaterial3D:
	return solid(Color(0.035, 0.035, 0.04), 0.95, 0.0)


static func van_paint() -> StandardMaterial3D:
	return textured("van_paint", Color(0.80, 0.79, 0.72), Color(0.68, 0.67, 0.61), Vector3(0.25, 0.25, 0.25), 0.45, false, 0.02)


static func glass_dark() -> StandardMaterial3D:
	return solid(Color(0.02, 0.03, 0.04), 0.08, 0.6)
