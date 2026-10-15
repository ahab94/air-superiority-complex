extends Node3D
## Short-lived 3D effects: explosions, falling wrecks, splashes, muzzle
## flashes and vapour trails. scene3d.gd owns one of these and calls it.
##
## "airspeed" below is how fast still air (and anything left behind in it,
## like smoke) streams toward the bottom of the screen, in units/s. It changes
## with the throttle, so trails stretch out when you speed up.

const JetMesh := preload("res://scripts/jet_mesh.gd")

var sea_y := -22.0
var splash_count := 0        # the game polls this to play a splash sound
var _wrecks: Array = []      # {node, vel: Vector3, spin: Vector3, smoke}
var _drifters: Array = []    # things floating on the sea: [node, life left]
var _flashes: Array = []     # [node, life left]
var _puff: GradientTexture2D
var _flash_mat: StandardMaterial3D


## A new mission: drop every effect still playing from the last one (wrecks
## still falling from the title-screen demo would otherwise streak by).
func clear_all() -> void:
	for c in get_children():
		c.queue_free()
	# Wrecks are jet nodes that live in the 3D scene (not under fx), so free
	# them explicitly; otherwise they freeze mid-crash into the next mission.
	for w in _wrecks:
		if is_instance_valid(w.node):
			w.node.queue_free()
	_wrecks.clear()
	_drifters.clear()
	_flashes.clear()


func update(delta: float, airspeed: float, sea_speed: float) -> void:
	for w in _wrecks.duplicate():
		var n: Node3D = w.node
		var v: Vector3 = w.vel
		v.y -= 9.0 * delta          # falls...
		v.z += 3.0 * delta          # ...and drops behind us without thrust
		w.vel = v
		n.position += v * delta + Vector3(0, 0, airspeed * 0.15 * delta)
		n.rotation += w.spin * delta
		if n.position.y <= sea_y + 0.3:
			splash(Vector3(n.position.x, sea_y, n.position.z))
			_release_smoke(w.smoke)
			n.queue_free()
			_wrecks.erase(w)
	for d in _drifters.duplicate():
		var n: Node3D = d[0]
		n.position.z += sea_speed * delta
		d[1] -= delta
		if d[1] <= 0.0:
			n.queue_free()
			_drifters.erase(d)
	for f in _flashes.duplicate():
		f[1] -= delta
		if f[1] <= 0.0:
			f[0].queue_free()
			_flashes.erase(f)


# --- explosions and wrecks ---------------------------------------------------

func explode(at: Vector3, big: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	var s := 1.6 if big else 1.0
	root.add_child(_burst(26, 0.55, Vector2(3, 9) * s, Vector2(0.9, 2.2) * s,
		[Color(4.0, 3.4, 2.4, 1), Color(3.0, 1.2, 0.3, 0.9), Color(0.3, 0.12, 0.06, 0.0)], true, Vector3.ZERO))
	root.add_child(_burst(16, 0.7, Vector2(8, 16) * s, Vector2(0.15, 0.3),
		[Color(4.0, 3.0, 1.5, 1), Color(2.0, 0.6, 0.1, 0.0)], true, Vector3(0, -6, 4)))
	root.add_child(_burst(18, 1.8, Vector2(1, 4) * s, Vector2(1.4, 3.2) * s,
		[Color(0.25, 0.22, 0.2, 0.0), Color(0.22, 0.2, 0.19, 0.75), Color(0.35, 0.34, 0.33, 0.0)], false, Vector3(0, 0, 3)))
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.62, 0.3)
	flash.light_energy = 10.0 * s
	flash.omni_range = 14.0 * s
	root.add_child(flash)
	create_tween().tween_property(flash, "light_energy", 0.0, 0.35)
	get_tree().create_timer(2.6).timeout.connect(root.queue_free)


## A shot-down jet doesn't vanish: it tumbles away trailing fire and smoke
## and splashes into the sea far below. Takes ownership of `node`.
func wreck(node: Node3D, rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for c in node.get_children():
		if c.name.begins_with("Flame"):
			c.visible = false
	var smoke := _burst(140, 1.4, Vector2(0.3, 1.0), Vector2(0.45, 1.1),
		[Color(3.0, 1.4, 0.4, 0.9), Color(0.2, 0.18, 0.17, 0.7), Color(0.3, 0.3, 0.3, 0.0)], false, Vector3(0, 0.5, 6))
	smoke.one_shot = false
	smoke.explosiveness = 0.0
	smoke.local_coords = false   # particles stay in the air behind the wreck, making a trail
	node.add_child(smoke)
	_wrecks.append({
		"node": node, "smoke": smoke,
		"vel": Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(0.5, 2.5), rng.randf_range(-1.0, 1.5)),
		"spin": Vector3(rng.randf_range(-3, 3), rng.randf_range(-4, 4), rng.randf_range(-6, 6)),
	})


func _release_smoke(smoke: GPUParticles3D) -> void:
	# Let the trail finish fading instead of popping out of existence.
	var keep := smoke.global_transform
	smoke.get_parent().remove_child(smoke)
	add_child(smoke)
	smoke.global_transform = keep
	smoke.emitting = false
	get_tree().create_timer(1.6).timeout.connect(smoke.queue_free)


func splash(at: Vector3) -> void:
	splash_count += 1
	var root := Node3D.new()
	add_child(root)
	root.position = at
	var spray := _burst(40, 1.3, Vector2(6, 13), Vector2(0.5, 1.4),
		[Color(1, 1, 1, 0.95), Color(0.9, 0.95, 1, 0.6), Color(1, 1, 1, 0)], false, Vector3(0, -16, 0))
	(spray.process_material as ParticleProcessMaterial).spread = 25.0
	root.add_child(spray)
	# A ring of foam that spreads and fades, and drifts away with the sea.
	var foam := MeshInstance3D.new()
	var ring := PlaneMesh.new()
	ring.size = Vector2(2.5, 2.5)
	foam.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _ring_texture()
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.85)
	foam.material_override = mat
	foam.position = Vector3(0, 0.15, 0)
	root.add_child(foam)
	var tw := create_tween().set_parallel()
	tw.tween_property(foam, "scale", Vector3(2.4, 1, 2.4), 3.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 3.0)
	_drifters.append([root, 3.2])


## Explosive cannon round going off on a jet: a small fireball, sparks,
## and a puff of smoke.
func impact(at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	root.add_child(_burst(8, 0.25, Vector2(1, 3), Vector2(0.35, 0.8),
		[Color(4.0, 3.2, 2.0, 1), Color(2.5, 0.9, 0.2, 0.8), Color(0.2, 0.1, 0.05, 0.0)], true, Vector3.ZERO))
	root.add_child(_burst(10, 0.35, Vector2(6, 14), Vector2(0.06, 0.14),
		[Color(5.0, 4.0, 2.0, 1), Color(3.0, 1.0, 0.2, 0.0)], true, Vector3(0, -8, 5)))
	root.add_child(_burst(4, 0.9, Vector2(0.5, 1.5), Vector2(0.5, 1.0),
		[Color(0.3, 0.28, 0.26, 0.0), Color(0.3, 0.28, 0.26, 0.5), Color(0.4, 0.4, 0.4, 0.0)], false, Vector3(0, 0, 6)))
	get_tree().create_timer(1.2).timeout.connect(root.queue_free)


## Flak: a ground shell bursting at our altitude: a sharp flash and a
## lingering ball of black smoke.
func flak_burst(at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	root.add_child(_burst(10, 0.3, Vector2(2, 5), Vector2(0.6, 1.4),
		[Color(4.0, 3.0, 1.6, 1), Color(2.0, 0.8, 0.2, 0.6), Color(0.1, 0.05, 0.02, 0.0)], true, Vector3.ZERO))
	root.add_child(_burst(16, 2.2, Vector2(0.5, 2.5), Vector2(1.4, 2.8),
		[Color(0.08, 0.08, 0.08, 0.0), Color(0.1, 0.1, 0.1, 0.85), Color(0.2, 0.2, 0.2, 0.0)], false, Vector3(0, 0, 5)))
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.7, 0.4)
	flash.light_energy = 6.0
	flash.omni_range = 9.0
	root.add_child(flash)
	create_tween().tween_property(flash, "light_energy", 0.0, 0.25)
	get_tree().create_timer(2.6).timeout.connect(root.queue_free)


## A round bursting inside cloud cover: a dull flash in the white.
func cloud_pop(at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	root.add_child(_burst(5, 0.3, Vector2(1, 2), Vector2(0.4, 0.9),
		[Color(2.5, 2.0, 1.4, 0.8), Color(1.0, 0.9, 0.8, 0.0)], true, Vector3.ZERO))
	get_tree().create_timer(0.6).timeout.connect(root.queue_free)


## Smoke (and later fire) pouring from a damaged jet. Returned emitter stays
## attached to the jet; its particles are left behind in the air.
func damage_smoke(fire: bool) -> GPUParticles3D:
	var cols := [Color(3.0, 1.3, 0.3, 0.9), Color(0.25, 0.2, 0.18, 0.7), Color(0.3, 0.3, 0.3, 0.0)] if fire \
		else [Color(0.35, 0.34, 0.33, 0.0), Color(0.3, 0.3, 0.3, 0.55), Color(0.45, 0.45, 0.45, 0.0)]
	var gp := _burst(110 if fire else 90, 1.1, Vector2(0.2, 0.8), Vector2(0.3, 0.7) if fire else Vector2(0.35, 0.85), cols, false, Vector3(0, 0.6, 0))
	gp.one_shot = false
	gp.explosiveness = 0.0
	gp.local_coords = false
	return gp


# --- muzzle flashes ----------------------------------------------------------

func muzzle(at: Vector3, big: bool) -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_mat.albedo_texture = _puff_texture()
		_flash_mat.albedo_color = Color(4.0, 3.0, 1.4)
	var q := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(1.6, 1.6) * (1.4 if big else 1.0)
	q.mesh = p
	q.material_override = _flash_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = at
	q.rotation.y = randf() * TAU
	add_child(q)
	_flashes.append([q, 0.05])


# --- particles helper --------------------------------------------------------

## One burst of camera-facing soft sprites. GPUParticles3D simulates them on
## the graphics card; the colour ramp fades each one over its life.
func _burst(amount: int, life: float, vel: Vector2, size: Vector2, colors: Array, glow: bool, gravity: Vector3) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = gravity
	pm.damping_min = 2.0
	pm.damping_max = 6.0
	pm.scale_min = size.x
	pm.scale_max = size.y
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 1.4))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0]) if colors.size() == 3 else PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray(colors)
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.angle_min = 0.0
	pm.angle_max = 360.0

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if glow else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff_texture()
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var quad := QuadMesh.new()
	quad.material = mat

	var gp := GPUParticles3D.new()
	gp.amount = amount
	gp.lifetime = life
	gp.one_shot = true
	gp.explosiveness = 0.95
	gp.process_material = pm
	gp.draw_pass_1 = quad
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	gp.emitting = true
	return gp


var _ring: GradientTexture2D

## A thin bright ring with a clear middle: spreading foam from a splash.
func _ring_texture() -> GradientTexture2D:
	if _ring == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 0.88, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		_ring = GradientTexture2D.new()
		_ring.gradient = g
		_ring.fill = GradientTexture2D.FILL_RADIAL
		_ring.fill_from = Vector2(0.5, 0.5)
		_ring.fill_to = Vector2(1.0, 0.5)
		_ring.width = 128
		_ring.height = 128
	return _ring


func _puff_texture() -> GradientTexture2D:
	if _puff == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_puff = GradientTexture2D.new()
		_puff.gradient = g
		_puff.fill = GradientTexture2D.FILL_RADIAL
		_puff.fill_from = Vector2(0.5, 0.5)
		_puff.fill_to = Vector2(1.0, 0.5)
		_puff.width = 128
		_puff.height = 128
	return _puff


# --- vapour trails -----------------------------------------------------------

## A ribbon left behind in the air: each frame a new point is added at the
## source, and older points stream toward the bottom of the screen with the
## air, fading out. ImmediateMesh lets us rebuild the ribbon every frame.
class Trail:
	var mesh := ImmediateMesh.new()
	var node := MeshInstance3D.new()
	var pts: Array = []        # [position, age, strength]
	var life: float
	var width: float
	var color: Color

	func _init(parent: Node3D, life_: float, width_: float, color_: Color) -> void:
		life = life_
		width = width_
		color = color_
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		node.mesh = mesh
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)

	func update(head: Vector3, strength: float, airspeed: float, delta: float) -> void:
		for p in pts:
			p[0].z += airspeed * delta
			p[1] += delta
		while not pts.is_empty() and pts[-1][1] > life:
			pts.pop_back()
		pts.push_front([head, 0.0, strength])
		_rebuild()

	## No new points: what's left drifts away and fades (missile gone).
	func fade(airspeed: float, delta: float) -> bool:
		for p in pts:
			p[0].z += airspeed * delta
			p[1] += delta
		while not pts.is_empty() and pts[-1][1] > life:
			pts.pop_back()
		_rebuild()
		return not pts.is_empty()

	func _rebuild() -> void:
		mesh.clear_surfaces()
		if pts.size() < 2:
			return
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for p in pts:
			var k: float = p[1] / life
			var w := width * (0.4 + k * 1.6)
			var c := color
			c.a = color.a * float(p[2]) * (1.0 - k) * minf(1.0, p[1] * 20.0)
			mesh.surface_set_color(c)
			mesh.surface_add_vertex(p[0] + Vector3(-w, 0, 0))
			mesh.surface_set_color(c)
			mesh.surface_add_vertex(p[0] + Vector3(w, 0, 0))
		mesh.surface_end()

	func clear() -> void:
		pts.clear()
		mesh.clear_surfaces()
