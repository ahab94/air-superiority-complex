extends RefCounted
## Builds the parody jets as 3D meshes, in code.
##
## Each jet blends two or three real-world jet types, so it reads as "that
## kind of jet" without copying any one design. For example:
##   foxbrat  = boxy-intake twin-tail interceptor + clipped trapezoid wings
##   fishbowl = nose-cone intake + tailless delta wing
##   (the full list, with each blend, is in jets.gd)
##
## Optional parts: "canards" (a small planform ahead of the wing), "pods"
## (engine nacelles or tip tanks: [x, z front, z back, radius]), "props"
## (propeller discs: [x, z, radius]) and "tail_y" (lift the tailplane up the
## fin for a T-tail).
##
## Local axes: the nose points to -Z, up is +Y, right is +X. One unit is
## 10 field pixels. Parts are described as numbers in MODELS and assembled
## by SurfaceTool, Godot's helper for building a mesh triangle by triangle.

const SKIN := preload("res://shaders/jet_skin.gdshader")
const FLAME := preload("res://shaders/flame.gdshader")

const MODELS := {
	"foxbrat": {
		# fuselage cross-sections: [z, half width, half height]
		"body": [[-1.8, 0.0, 0.0], [-1.6, 0.07, 0.06], [-1.3, 0.14, 0.12], [-0.95, 0.19, 0.16],
			[-0.5, 0.21, 0.18], [0.6, 0.22, 0.18], [1.45, 0.24, 0.17], [1.66, 0.22, 0.15]],
		"canopy": [-1.05, 0.11, 0.3, 0.11],          # z, half width, half length, height
		"intakes": [[0.36, -0.85, 0.95, 0.16, 0.16]],  # x, z front, z back, half width, half height
		"wing": [[0.42, -0.2], [1.55, 0.45], [1.55, 0.78], [0.42, 0.98]],
		"tail": [[0.45, 1.12], [1.0, 1.42], [1.0, 1.66], [0.45, 1.66]],
		"fins": [[0.36, 0.82, 1.62, 0.8, 1.26, 1.62, 11.0]],  # x, base z0..z1, height, tip z0..z1, cant
		"nozzles": [[0.15, 1.66, 0.14]],             # x, z, radius
		"wing_t": 0.07,
	},
	"fishbowl": {
		"body": [[-1.72, 0.0, 0.0], [-1.6, 0.05, 0.05], [-1.56, 0.11, 0.11], [-1.2, 0.15, 0.15],
			[-0.5, 0.18, 0.19], [0.5, 0.18, 0.18], [1.3, 0.15, 0.15], [1.45, 0.14, 0.14]],
		"canopy": [-0.8, 0.09, 0.32, 0.12],
		"intakes": [],
		"wing": [[0.17, -0.25], [1.15, 1.0], [1.15, 1.12], [0.17, 1.12]],
		"tail": [],
		"fins": [[0.0, 0.45, 1.42, 0.78, 1.08, 1.42, 0.0]],
		"nozzles": [[0.0, 1.45, 0.13]],
		"wing_t": 0.06,
	},
	"dragon_laddie": {
		"body": [[-1.9, 0.0, 0.0], [-1.65, 0.08, 0.08], [-1.1, 0.16, 0.16], [0.5, 0.17, 0.17], [1.55, 0.1, 0.1], [1.9, 0.07, 0.07]],
		"canopy": [-1.15, 0.08, 0.22, 0.1],
		"intakes": [[0.18, -0.7, -0.2, 0.06, 0.08]],
		"wing": [[0.15, -0.25], [3.5, 0.02], [3.5, 0.24], [0.15, 0.4]],
		"tail": [[0.06, 1.48], [0.85, 1.62], [0.85, 1.78], [0.06, 1.8]],
		"fins": [[0.0, 1.05, 1.85, 0.72, 1.5, 1.85, 0.0]],
		"nozzles": [[0.0, 1.9, 0.07]],
		"wing_t": 0.04,
	},
	"butterknife": {
		"body": [[-1.62, 0.15, 0.15], [-1.3, 0.22, 0.22], [-0.6, 0.26, 0.27], [0.4, 0.25, 0.25], [1.2, 0.18, 0.18], [1.55, 0.15, 0.15]],
		"canopy": [-0.85, 0.12, 0.28, 0.14],
		"intakes": [],
		"wing": [[0.24, -0.35], [1.6, 0.45], [1.6, 0.75], [0.24, 0.55]],
		"tail": [[0.15, 1.0], [0.75, 1.35], [0.75, 1.5], [0.15, 1.5]],
		"fins": [[0.0, 0.6, 1.5, 0.7, 1.15, 1.5, 0.0]],
		"nozzles": [[0.0, 1.55, 0.15]],
		"wing_t": 0.07,
	},
	"fishcake": {
		"body": [[-1.42, 0.2, 0.2], [-1.1, 0.28, 0.28], [-0.3, 0.32, 0.32], [0.6, 0.26, 0.26], [1.3, 0.14, 0.14], [1.45, 0.12, 0.12]],
		"canopy": [-0.75, 0.13, 0.26, 0.15],
		"intakes": [],
		"wing": [[0.28, -0.2], [1.5, 0.55], [1.5, 0.8], [0.28, 0.55]],
		"tail": [[0.08, 1.15], [0.62, 1.35], [0.62, 1.48], [0.08, 1.45]],
		"tail_y": 0.55,
		"fins": [[0.0, 0.45, 1.45, 0.78, 1.0, 1.42, 0.0]],
		"nozzles": [[0.0, 1.45, 0.12]],
		"wing_t": 0.07,
	},
	"blackbirb": {
		"body": [[-2.6, 0.0, 0.0], [-2.2, 0.14, 0.06], [-1.6, 0.3, 0.1], [-0.8, 0.4, 0.13], [0.4, 0.45, 0.13], [1.6, 0.3, 0.1], [2.2, 0.15, 0.08]],
		"canopy": [-1.6, 0.09, 0.25, 0.1],
		"intakes": [],
		"wing": [[0.4, -0.6], [1.95, 1.3], [1.95, 1.85], [0.4, 1.9]],
		"tail": [],
		"pods": [[1.05, -0.9, 2.25, 0.24]],
		"fins": [[1.05, 1.15, 2.1, 0.62, 1.65, 2.05, -16.0]],
		"nozzles": [[1.05, 2.25, 0.2]],
		"wing_t": 0.06,
	},
	"pigeon": {
		"body": [[-2.0, 0.0, 0.0], [-1.7, 0.1, 0.1], [-1.1, 0.19, 0.18], [-0.2, 0.23, 0.2], [1.2, 0.22, 0.19], [1.7, 0.16, 0.15]],
		"canopy": [-1.15, 0.1, 0.32, 0.14],
		"intakes": [[0.0, -0.6, 0.4, 0.16, 0.12]],
		"wing": [[0.22, -0.15], [1.55, 0.75], [1.55, 0.95], [0.22, 1.0]],
		"canards": [[0.2, -0.85], [0.65, -0.58], [0.65, -0.45], [0.2, -0.5]],
		"tail": [[0.2, 1.2], [0.85, 1.5], [0.85, 1.65], [0.2, 1.65]],
		"fins": [[0.0, 0.75, 1.65, 0.85, 1.3, 1.6, 0.0]],
		"nozzles": [[0.0, 1.7, 0.15]],
		"wing_t": 0.06,
	},
	"tuba": {
		"body": [[-4.0, 0.0, 0.0], [-3.6, 0.35, 0.35], [-2.8, 0.55, 0.55], [2.4, 0.5, 0.5], [3.6, 0.25, 0.3], [4.0, 0.15, 0.2]],
		"canopy": [-3.2, 0.25, 0.4, 0.22],
		"intakes": [],
		"wing": [[0.5, -0.6], [5.6, 2.0], [5.6, 2.5], [0.5, 1.4]],
		"tail": [[0.2, 3.0], [1.9, 3.6], [1.9, 3.9], [0.2, 3.85]],
		"fins": [[0.0, 2.6, 3.9, 1.6, 3.4, 3.9, 0.0]],
		"pods": [[1.7, -0.7, 0.9, 0.3], [3.2, 0.1, 1.4, 0.26]],
		"props": [[1.7, -0.8, 1.1], [3.2, 0.0, 1.0]],
		"nozzles": [],
		"wing_t": 0.12,
	},
	"hawkward": {
		"body": [[-1.8, 0.0, 0.0], [-1.5, 0.12, 0.12], [-0.9, 0.22, 0.22], [0.2, 0.27, 0.25], [1.2, 0.2, 0.2], [1.6, 0.14, 0.14]],
		"canopy": [-1.05, 0.11, 0.3, 0.13],
		"intakes": [[0.3, -0.4, 0.3, 0.1, 0.1]],
		"wing": [[0.25, -0.45], [1.5, 0.45], [1.5, 0.75], [0.25, 0.45]],
		"tail": [[0.15, 1.05], [0.7, 1.35], [0.7, 1.5], [0.15, 1.45]],
		"tail_y": 0.25,
		"fins": [[0.0, 0.75, 1.55, 0.75, 1.2, 1.5, 0.0]],
		"nozzles": [[0.0, 1.6, 0.12]],
		"wing_t": 0.07,
	},
	"midge": {
		"body": [[-1.2, 0.0, 0.0], [-1.0, 0.09, 0.09], [-0.6, 0.16, 0.16], [0.3, 0.17, 0.17], [0.95, 0.1, 0.1], [1.1, 0.08, 0.08]],
		"canopy": [-0.55, 0.08, 0.2, 0.1],
		"intakes": [[0.2, -0.5, 0.0, 0.07, 0.08]],
		"wing": [[0.15, -0.25], [1.05, 0.35], [1.05, 0.55], [0.15, 0.4]],
		"tail": [[0.08, 0.75], [0.45, 0.95], [0.45, 1.05], [0.08, 1.05]],
		"fins": [[0.0, 0.5, 1.1, 0.5, 0.85, 1.1, 0.0]],
		"nozzles": [[0.0, 1.1, 0.08]],
		"wing_t": 0.05,
	},
	"starfrighter": {
		"body": [[-2.4, 0.0, 0.0], [-2.0, 0.06, 0.06], [-1.2, 0.15, 0.15], [-0.4, 0.19, 0.19], [1.3, 0.18, 0.18], [1.8, 0.15, 0.15]],
		"canopy": [-1.0, 0.09, 0.28, 0.12],
		"intakes": [[0.22, -0.6, 0.1, 0.08, 0.1]],
		"wing": [[0.18, 0.0], [0.95, 0.25], [0.95, 0.45], [0.18, 0.6]],
		"pods": [[0.98, -0.15, 0.8, 0.08]],
		"tail": [[0.05, 1.25], [0.6, 1.5], [0.6, 1.65], [0.05, 1.6]],
		"tail_y": 0.75,
		"fins": [[0.0, 0.8, 1.75, 0.78, 1.3, 1.65, 0.0]],
		"nozzles": [[0.0, 1.8, 0.15]],
		"wing_t": 0.04,
	},
	"raffle": {
		"body": [[-2.0, 0.0, 0.0], [-1.7, 0.1, 0.1], [-1.1, 0.18, 0.17], [-0.2, 0.24, 0.18], [1.2, 0.28, 0.17], [1.65, 0.24, 0.15]],
		"canopy": [-1.15, 0.1, 0.32, 0.13],
		"intakes": [[0.3, -0.6, 0.5, 0.12, 0.12]],
		"wing": [[0.3, -0.2], [1.5, 1.1], [1.5, 1.3], [0.3, 1.45]],
		"canards": [[0.2, -0.95], [0.75, -0.62], [0.75, -0.5], [0.2, -0.55]],
		"tail": [],
		"fins": [[0.0, 0.6, 1.6, 0.8, 1.2, 1.55, 0.0]],
		"nozzles": [[0.12, 1.65, 0.13]],
		"wing_t": 0.06,
	},
	"vigdragon": {
		"body": [[-2.0, 0.0, 0.0], [-1.7, 0.1, 0.1], [-1.0, 0.18, 0.18], [0.0, 0.22, 0.2], [1.3, 0.2, 0.18], [1.7, 0.17, 0.16]],
		"canopy": [-1.1, 0.1, 0.3, 0.14],
		"intakes": [[0.0, -0.5, 0.5, 0.17, 0.13]],
		"wing": [[0.22, -0.2], [1.45, 1.05], [1.45, 1.25], [0.22, 1.3]],
		"canards": [[0.18, -0.95], [0.7, -0.68], [0.7, -0.56], [0.18, -0.6]],
		"tail": [],
		"fins": [[0.0, 0.6, 1.7, 0.85, 1.25, 1.65, 0.0]],
		"nozzles": [[0.0, 1.7, 0.16]],
		"wing_t": 0.06,
	},
}

static var _cache := {}


## A ready-to-place jet: the mesh plus an afterburner flame per nozzle.
static func make(kind: String, skin: ShaderMaterial, flame_scale := 1.0) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.set_surface_override_material(0, skin)
	mi.set_surface_override_material(1, _glass())
	root.add_child(mi)
	var m: Dictionary = MODELS[kind]
	for nz in m.nozzles:
		for x in ([nz[0], -nz[0]] if nz[0] > 0.0 else [0.0]):
			root.add_child(_flame(Vector3(x, 0.0, nz[1]), nz[2] * 0.95, 1.1 * flame_scale))
	for pr in m.get("props", []):
		for x in [pr[0], -pr[0]]:
			root.add_child(_prop(Vector3(x, 0.05, pr[1]), pr[2]))
	# Navigation lights on the wingtips: red on the left, green on the right.
	# Tiny by day; at night they're how you spot a jet.
	var tip: Array = m.wing[1]
	for side in [-1.0, 1.0]:
		var dot := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.07
		sph.height = 0.14
		dot.mesh = sph
		dot.material_override = _nav_mat(Color(1.0, 0.15, 0.1) if side < 0 else Color(0.2, 1.0, 0.35))
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.position = Vector3(float(tip[0]) * side, 0.05, float(tip[1]) + 0.1)
		root.add_child(dot)
	return root


static func _nav_mat(c: Color) -> StandardMaterial3D:
	var key := "nav_%s" % c.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c * 3.0
		_cache[key] = m
	return _cache[key]


## A spinning propeller seen as a blurred disc with faint blade streaks.
## scene3d.gd turns nodes named "Prop".
static func _prop(at: Vector3, r: float) -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.02
	disc.radial_segments = 24
	if not _cache.has("prop_mat"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.15, 0.5, 0.85, 1.0])
		g.colors = PackedColorArray([Color(0.1, 0.1, 0.1, 0.9), Color(0.2, 0.2, 0.2, 0.35), Color(0.3, 0.3, 0.3, 0.12), Color(0.3, 0.3, 0.3, 0.2), Color(0.3, 0.3, 0.3, 0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var pm := StandardMaterial3D.new()
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.albedo_texture = tex
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache.prop_mat = pm
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = _cache.prop_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.name = "Prop"
	return mi


static func skin(base: Color, camo: Color, camo_amount: float, insignia: Color, noise: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SKIN
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("camo_color", camo)
	mat.set_shader_parameter("camo_amount", camo_amount)
	mat.set_shader_parameter("insignia_color", insignia)
	mat.set_shader_parameter("noise_tex", noise)
	return mat


static func _glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache.glass
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.16, 0.26, 0.34)
	g.metallic = 0.25
	g.roughness = 0.08
	g.metallic_specular = 0.9
	g.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache.glass = g
	return g


static func _flame(at: Vector3, radius: float, length: float) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = length
	cone.radial_segments = 12
	cone.rings = 1
	var mat := ShaderMaterial.new()
	mat.shader = FLAME
	mat.set_shader_parameter("length", length)
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A cylinder stands along Y; tip it over so the point trails behind (+Z).
	mi.rotation.x = PI / 2
	mi.position = at + Vector3(0, 0, length / 2)
	mi.name = "Flame"
	return mi


static func _mesh(kind: String) -> ArrayMesh:
	if _cache.has(kind):
		return _cache[kind]
	var m: Dictionary = MODELS[kind]
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()

	# Surface 0: the painted skin.
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)            # the fuselage is smooth...
	_loft(st, m.body, 0.0, 0.0, false)
	for nz in m.nozzles:
		for x in ([nz[0], -nz[0]] if nz[0] > 0.0 else [0.0]):
			_loft(st, [[nz[1] - 0.25, nz[2], nz[2]], [nz[1], nz[2], nz[2]], [nz[1] + 0.06, nz[2] * 0.9, nz[2] * 0.9]], x, 0.0, false)
	for pod in m.get("pods", []):
		for x in [pod[0], -pod[0]]:
			var r: float = pod[3]
			_loft(st, [[pod[1] - 0.2, 0.0, 0.0], [pod[1], r * 0.7, r * 0.7], [pod[1] + 0.3, r, r],
				[pod[2] - 0.2, r, r], [pod[2], r * 0.85, r * 0.85]], x, 0.0, false)
	st.set_smooth_group(-1)           # ...wings, fins and intakes are flat-shaded
	var t: float = m.wing_t
	var tail_y: float = m.get("tail_y", 0.02)
	for side in [1.0, -1.0]:
		_plate(st, _flat(m.wing, side, -0.02), Vector3.UP, t)
		if not m.tail.is_empty():
			_plate(st, _flat(m.tail, side, tail_y), Vector3.UP, t * 0.8)
		if m.has("canards"):
			_plate(st, _flat(m.canards, side, 0.04), Vector3.UP, t * 0.7)
		for it in m.intakes:
			var x: float = it[0] * side
			var hw: float = it[3]
			var c := [Vector3(x - hw, 0, it[1]), Vector3(x + hw, 0, it[1]), Vector3(x + hw, 0, it[2]), Vector3(x - hw, 0, it[2])]
			_plate(st, c, Vector3.UP, it[4] * 2.0)
	for f in m.fins:
		for side in ([1.0, -1.0] if f[0] > 0.0 else [1.0]):
			var cant: float = deg_to_rad(f[6]) * side
			var base := Vector3(f[0] * side, 0.1, 0)
			var up := Vector3(sin(cant), cos(cant), 0)
			var c := [base + Vector3(0, 0, f[1]), base + Vector3(0, 0, f[2]),
				base + up * f[3] + Vector3(0, 0, f[5]), base + up * f[3] + Vector3(0, 0, f[4])]
			_plate(st, c, Vector3(cos(cant), -sin(cant), 0), 0.05)
	st.generate_normals()
	st.commit(mesh)

	# Surface 1: the canopy glass, a half ellipsoid on top of the nose.
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cz: float = m.canopy[0]
	var hw2: float = m.canopy[1]
	var hl: float = m.canopy[2]
	var ht: float = m.canopy[3]
	var secs: Array = []
	for k in 7:
		var u := -1.0 + 2.0 * k / 6.0
		var r := sqrt(maxf(0.0, 1.0 - u * u))
		secs.append([cz + u * hl, hw2 * r, ht * r])
	_loft(st, secs, 0.0, _body_top(m.body, cz) - 0.02, true)
	st.generate_normals()
	st.commit(mesh)

	_cache[kind] = mesh
	return mesh


static func _body_top(body: Array, z: float) -> float:
	for k in body.size() - 1:
		if z >= body[k][0] and z <= body[k + 1][0]:
			var u: float = (z - body[k][0]) / (body[k + 1][0] - body[k][0])
			return lerpf(body[k][2], body[k + 1][2], u)
	return 0.15


## Turn a planform [[x, z], ...] into 3D corners on one side.
static func _flat(pts: Array, side: float, y: float) -> Array:
	var out := []
	for p in pts:
		out.append(Vector3(p[0] * side, y, p[1]))
	return out


## A tube through elliptical cross-sections [z, half width, half height].
## `top_only` builds just the upper half (for the canopy bubble).
static func _loft(st: SurfaceTool, secs: Array, x: float, y: float, top_only: bool) -> void:
	var segs := 14
	var rings: Array = []
	for s in secs:
		var ring: Array = []
		for j in segs + 1:
			var a := (PI * j / segs) if top_only else (TAU * j / segs)
			ring.append(Vector3(x + cos(a) * s[1], y + sin(a) * s[2], s[0]))
		rings.append(ring)
	for i in rings.size() - 1:
		for j in segs:
			_quad(st, rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j])
	# Close the tail end with a fan.
	var last: Array = rings[-1]
	var c: Vector3 = Vector3(x, y, secs[-1][0])
	for j in segs:
		_tri(st, c, last[j + 1], last[j])


## A flat panel with thickness: the four corners, pushed both ways along `n`.
static func _plate(st: SurfaceTool, c: Array, n: Vector3, thick: float) -> void:
	var h := n * thick * 0.5
	var top: Array = []
	var bot: Array = []
	for p in c:
		top.append(p + h)
		bot.append(p - h)
	_quad(st, top[0], top[1], top[2], top[3])
	_quad(st, bot[3], bot[2], bot[1], bot[0])
	for k in 4:
		var k2 := (k + 1) % 4
		_quad(st, bot[k], bot[k2], top[k2], top[k])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
