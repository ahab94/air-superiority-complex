extends RefCounted
## Per-mission look: the light (time of day and weather), and the ground
## objects that matter to the rules: SAM sites and photo targets.
## scene3d.gd calls these; the numbers here are only about appearance.

## Light presets: sun direction, colour and strength; ambient sky; haze.
const LIGHTS := {
	"day": {"sun": Vector3(0.42, -1.0, 0.32), "sun_col": Color(1.0, 0.95, 0.86), "sun_e": 1.35,
		"sky_top": Color(0.22, 0.42, 0.72), "sky_hor": Color(0.62, 0.72, 0.84), "amb": 0.55,
		"fog": Color(0.55, 0.66, 0.8), "fog_d": 0.0005, "glow": 0.55, "cloud": Color(1, 1, 1), "cloud_a": 0.75},
	"dusk": {"sun": Vector3(0.95, -0.42, 0.25), "sun_col": Color(1.0, 0.74, 0.52), "sun_e": 1.2,
		"sky_top": Color(0.3, 0.3, 0.55), "sky_hor": Color(0.95, 0.6, 0.45), "amb": 0.45,
		"fog": Color(0.85, 0.55, 0.42), "fog_d": 0.0012, "glow": 0.7, "cloud": Color(1.0, 0.78, 0.66), "cloud_a": 0.7},
	"overcast": {"sun": Vector3(0.2, -1.0, 0.25), "sun_col": Color(0.9, 0.93, 1.0), "sun_e": 0.55,
		"sky_top": Color(0.55, 0.58, 0.62), "sky_hor": Color(0.7, 0.72, 0.75), "amb": 0.95,
		"fog": Color(0.72, 0.75, 0.8), "fog_d": 0.0022, "glow": 0.4, "cloud": Color(0.85, 0.87, 0.9), "cloud_a": 0.85},
	"storm": {"sun": Vector3(0.3, -1.0, 0.2), "sun_col": Color(0.75, 0.82, 0.95), "sun_e": 0.4,
		"sky_top": Color(0.25, 0.3, 0.35), "sky_hor": Color(0.38, 0.42, 0.45), "amb": 0.7,
		"fog": Color(0.3, 0.35, 0.38), "fog_d": 0.0035, "glow": 0.5, "cloud": Color(0.55, 0.58, 0.62), "cloud_a": 0.9},
	"night": {"sun": Vector3(-0.35, -1.0, 0.4), "sun_col": Color(0.6, 0.7, 1.0), "sun_e": 0.55,
		"sky_top": Color(0.08, 0.12, 0.25), "sky_hor": Color(0.14, 0.18, 0.3), "amb": 0.5,
		"fog": Color(0.05, 0.07, 0.14), "fog_d": 0.0018, "glow": 0.9, "cloud": Color(0.3, 0.33, 0.42), "cloud_a": 0.6},
	"arctic": {"sun": Vector3(0.7, -0.6, 0.45), "sun_col": Color(1.0, 0.97, 0.92), "sun_e": 1.15,
		"sky_top": Color(0.4, 0.6, 0.85), "sky_hor": Color(0.8, 0.88, 0.95), "amb": 0.8,
		"fog": Color(0.75, 0.85, 0.95), "fog_d": 0.001, "glow": 0.5, "cloud": Color(1, 1, 1), "cloud_a": 0.8},
}

## Terrain settings: shader biome number, height (for real relief), wetness.
const TERRAINS := {
	"steppe": {"biome": 1, "height": 0.0},
	"winter": {"biome": 2, "height": 4.0},
	"desert": {"biome": 3, "height": 3.0},
	"arctic": {"biome": 4, "height": 0.0},
	"plains": {"biome": 5, "height": 0.0},
	"jungle": {"biome": 6, "height": 1.5},
	"mountains": {"biome": 7, "height": 16.0},
	"cloudsea": {"biome": 8, "height": 5.0},
	"karst": {"biome": 9, "height": 9.0},
}


static func box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, emissive := 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.8
	if emissive > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emissive
	b.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = pos
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	c.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.position = pos
	parent.add_child(mi)
	return mi


## A SAM site: a sandbagged ring, a launcher with missiles on rails, a radar
## van, and a warning light that blinks red while it's locking on.
static func sam_site() -> Node3D:
	var root := Node3D.new()
	var ring := cyl(root, 3.2, 0.3, Vector3(0, 0.15, 0), Color(0.45, 0.4, 0.3))
	ring.scale = Vector3(1, 1, 1)
	cyl(root, 2.6, 0.32, Vector3(0, 0.17, 0), Color(0.3, 0.3, 0.26))
	box(root, Vector3(1.6, 0.4, 2.2), Vector3(0, 0.5, 0), Color(0.3, 0.34, 0.24))
	for x in [-0.45, 0.45]:
		box(root, Vector3(0.22, 0.22, 2.4), Vector3(x, 0.9, -0.1), Color(0.88, 0.88, 0.85))
	box(root, Vector3(1.2, 0.8, 1.8), Vector3(2.6, 0.4, 2.2), Color(0.35, 0.38, 0.28))
	cyl(root, 0.7, 0.08, Vector3(2.6, 1.0, 2.2), Color(0.6, 0.6, 0.58))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.15, 0.1)
	light.light_energy = 0.0
	light.omni_range = 6.0
	light.position = Vector3(0, 2.0, 0)
	light.name = "Warn"
	root.add_child(light)
	return root


## Photo targets: a factory with smoking chimneys, an airfield, a rocket on
## its pad, or a big radar dish.
static func photo_target(kind: String) -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(9, 0.1, 7), Vector3(0, 0.05, 0), Color(0.42, 0.42, 0.4))
	match kind:
		"factory":
			box(root, Vector3(5, 1.4, 3), Vector3(-1, 0.7, 0.5), Color(0.55, 0.32, 0.25))
			box(root, Vector3(2.5, 1.0, 2), Vector3(2.6, 0.5, -1.5), Color(0.5, 0.5, 0.48))
			for x in [-2.5, -1.0, 0.5]:
				cyl(root, 0.35, 3.5, Vector3(x, 1.75, -1.6), Color(0.4, 0.35, 0.33))
		"airfield":
			box(root, Vector3(2.0, 0.12, 8), Vector3(-2, 0.1, 0), Color(0.2, 0.2, 0.21))
			for z in [-2.0, 1.0]:
				box(root, Vector3(2.6, 1.2, 2.0), Vector3(2.0, 0.6, z), Color(0.5, 0.52, 0.5))
		"launch_pad":
			cyl(root, 2.5, 0.2, Vector3(0, 0.1, 0), Color(0.6, 0.6, 0.6))
			box(root, Vector3(0.6, 5.0, 0.6), Vector3(1.4, 2.5, 0), Color(0.7, 0.3, 0.2))
			cyl(root, 0.4, 4.5, Vector3(0, 2.25, 0), Color(0.92, 0.92, 0.9))
		_:
			cyl(root, 2.2, 0.15, Vector3(0, 2.5, 0), Color(0.85, 0.85, 0.83)).rotation.x = 0.6
			box(root, Vector3(0.5, 2.5, 0.5), Vector3(0, 1.25, 0), Color(0.5, 0.5, 0.5))
			box(root, Vector3(2, 1, 1.5), Vector3(2.5, 0.5, 1.5), Color(0.35, 0.4, 0.3))
	return root
