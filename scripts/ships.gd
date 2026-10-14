extends Node3D
## Ships on the sea far below, each with a foam wake. They're pure scenery:
## they sail their own course while the whole sea streams past underneath us.
## That makes the background feel alive and makes our speed easy to read.

const WAKE := preload("res://shaders/wake.gdshader")

const TYPES := {
	# length, beam, hull height, hull colour, deck colour, cargo?
	"cargo": [16.0, 2.6, 0.9, Color(0.35, 0.08, 0.07), Color(0.3, 0.3, 0.28), true],
	"tanker": [19.0, 3.0, 0.8, Color(0.1, 0.12, 0.14), Color(0.45, 0.2, 0.12), false],
	"frigate": [10.0, 1.5, 0.7, Color(0.42, 0.45, 0.48), Color(0.36, 0.38, 0.4), false],
	"fishing": [3.6, 1.1, 0.5, Color(0.12, 0.3, 0.55), Color(0.85, 0.85, 0.8), false],
}
const CONTAINER_COLORS := [Color(0.7, 0.2, 0.12), Color(0.15, 0.35, 0.6), Color(0.2, 0.45, 0.25),
	Color(0.75, 0.6, 0.15), Color(0.5, 0.5, 0.52), Color(0.55, 0.15, 0.4)]

var sea_y := -22.0
var noise: Texture2D
var _ships: Array = []        # {node, dir: Vector3, speed}
var _rng := RandomNumberGenerator.new()
var _next := 0.0


func _ready() -> void:
	_rng.seed = 1976
	for k in 3:
		_spawn(_rng.randf_range(-40.0, 40.0))


func update(delta: float, sea_speed: float) -> void:
	_next -= delta * maxf(0.2, sea_speed / 9.0)
	if _next <= 0.0:
		_spawn(-95.0)
		_next = _rng.randf_range(4.0, 9.0)
	for s in _ships.duplicate():
		var n: Node3D = s.node
		n.position += s.dir * s.speed * delta + Vector3(0, 0, sea_speed * delta)
		n.rotation.z = sin(Time.get_ticks_msec() * 0.001 + n.position.x) * 0.02   # gentle roll
		if n.position.z > 110.0 or absf(n.position.x) > 140.0:
			n.queue_free()
			_ships.erase(s)


func _spawn(z: float) -> void:
	var keys := TYPES.keys()
	var kind: String = keys[_rng.randi_range(0, keys.size() - 1)]
	var t: Array = TYPES[kind]
	var length: float = t[0]
	var beam: float = t[1]
	var root := Node3D.new()
	root.add_child(_hull(length, beam, t[2], t[3], t[4]))
	if t[5]:
		_containers(root, length, beam, t[2])
	_bridge(root, length, beam, t[2], kind)
	root.add_child(_wake(length, beam))
	# Heading: mostly up or down the screen, a few at an angle. Bow is -Z.
	var heading := _rng.randf_range(-0.6, 0.6) + (PI if _rng.randf() < 0.5 else 0.0)
	root.rotation.y = heading
	root.position = Vector3(_rng.randf_range(-60.0, 60.0), sea_y + 0.02, z)
	add_child(root)
	_ships.append({"node": root, "dir": Vector3(-sin(heading), 0, -cos(heading)), "speed": _rng.randf_range(0.6, 1.6)})


## The hull: a pointed-bow outline extruded upward.
func _hull(length: float, beam: float, height: float, side: Color, deck: Color) -> MeshInstance3D:
	var hl := length / 2.0
	var hb := beam / 2.0
	var outline := [Vector2(0, -hl), Vector2(hb * 0.8, -hl + beam * 1.2), Vector2(hb, -hl + beam * 2.4),
		Vector2(hb, hl - 0.4), Vector2(hb * 0.8, hl), Vector2(-hb * 0.8, hl), Vector2(-hb, hl - 0.4),
		Vector2(-hb, -hl + beam * 2.4), Vector2(-hb * 0.8, -hl + beam * 1.2)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	st.set_color(deck)
	for k in range(1, outline.size() - 1):   # deck: a triangle fan
		st.add_vertex(Vector3(outline[0].x, height, outline[0].y))
		st.add_vertex(Vector3(outline[k].x, height, outline[k].y))
		st.add_vertex(Vector3(outline[k + 1].x, height, outline[k + 1].y))
	st.set_color(side)
	for k in outline.size():                 # sides
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % outline.size()]
		st.add_vertex(Vector3(a.x, 0, a.y))
		st.add_vertex(Vector3(b.x, 0, b.y))
		st.add_vertex(Vector3(b.x, height, b.y))
		st.add_vertex(Vector3(a.x, 0, a.y))
		st.add_vertex(Vector3(b.x, height, b.y))
		st.add_vertex(Vector3(a.x, height, a.y))
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var b := BoxMesh.new()
	b.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.8
	b.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = pos
	parent.add_child(mi)


func _containers(root: Node3D, length: float, beam: float, h: float) -> void:
	var rows := int((length - beam * 3.0) / 1.25)
	for r in rows:
		for c in 3:
			if _rng.randf() < 0.12:
				continue
			var col: Color = CONTAINER_COLORS[_rng.randi_range(0, CONTAINER_COLORS.size() - 1)]
			var stack := _rng.randi_range(1, 3)
			_box(root, Vector3(beam * 0.3, 0.35 * stack, 1.15),
				Vector3((c - 1) * beam * 0.31, h + 0.175 * stack, -length / 2.0 + beam * 2.2 + r * 1.25), col)


func _bridge(root: Node3D, length: float, beam: float, h: float, kind: String) -> void:
	var z := length / 2.0 - beam * 0.9
	if kind == "frigate":
		z = -length * 0.05
		_box(root, Vector3(beam * 0.7, 0.6, length * 0.3), Vector3(0, h + 0.3, z), Color(0.5, 0.53, 0.56))
		_box(root, Vector3(0.25, 0.25, 1.2), Vector3(0, h + 0.15, -length * 0.36), Color(0.3, 0.32, 0.34))
		return
	_box(root, Vector3(beam * 0.85, 0.9, beam * 0.7), Vector3(0, h + 0.45, z), Color(0.92, 0.92, 0.88))
	_box(root, Vector3(0.35, 0.6, 0.35), Vector3(0, h + 1.1, z + beam * 0.15), Color(0.15, 0.15, 0.15))


func _wake(length: float, beam: float) -> MeshInstance3D:
	var wl := length * 2.4 + 10.0
	var p := PlaneMesh.new()
	p.size = Vector2(wl * 0.75, wl)
	var mat := ShaderMaterial.new()
	mat.shader = WAKE
	mat.set_shader_parameter("noise_tex", noise)
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.03, length / 2.0 - 0.6 + wl / 2.0)
	return mi
