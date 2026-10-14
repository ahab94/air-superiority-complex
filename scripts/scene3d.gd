extends Node3D
## The 3D view of the battle. It never changes the game; each frame it reads
## the simulation and moves 3D objects to match.
##
## Mapping: one 3D unit is 10 field pixels. The field's x becomes X and its
## y becomes Z (down the screen is +Z). All the action happens on the plane
## Y = 0. A perspective camera hangs straight above it, sized so that plane
## exactly fills the 480x720 field on screen. So the 2D HUD drawn on top
## lines up with the 3D jets. The sea sits far below (SEA_Y), which gives
## real depth: it moves slower than the jets, and their shadows fall on it.
##
## Jets never fly backwards. Moving up or down the screen reads as throttling
## up or back: the world streams past faster or slower, the afterburners
## flare or shrink, and vapour trails stretch. The scenery always moves forward.

const Sim := preload("res://scripts/sim.gd")
const Jets := preload("res://scripts/jets.gd")
const JetMesh := preload("res://scripts/jet_mesh.gd")
const Fx := preload("res://scripts/fx3d.gd")
const Ships := preload("res://scripts/ships.gd")
const OCEAN := preload("res://shaders/ocean.gdshader")
const LAND := preload("res://shaders/land.gdshader")
const RUNWAY := preload("res://shaders/runway.gdshader")
const CLOUD := preload("res://shaders/cloud.gdshader")
const TERRAIN := preload("res://shaders/terrain.gdshader")
const Look := preload("res://scripts/look3d.gd")

const CAM_H := 90.0                   # camera height above the action plane
const SEA_Y := -22.0
const K := (CAM_H - SEA_Y) / CAM_H    # how much bigger things at sea level must be to look the same size
const CRUISE := 11.0                  # how fast the world streams past at cruise, units/s
const SUN_DIR := Vector3(0.42, -1.0, 0.32)
const PLAYER_SCALE := 1.35            # models are drawn a bit larger than their hitboxes
const ENEMY_SCALE := 1.25

var cam: Camera3D
var noise: NoiseTexture2D
var ocean_mat: ShaderMaterial
var land: MeshInstance3D
var runway: MeshInstance3D
var fx: Node3D                        # fx3d.gd
var ships: Node3D                     # ships.gd
var players: Array = []
var chutes: Array = []
var enemy_nodes := {}                 # enemy id -> Node3D
var missile_nodes := {}               # missile id (ours or theirs) -> [Node3D, Trail]
var flare_nodes := {}                 # flare id -> [Node3D, Trail]
var dying_trails: Array = []          # missile trails still fading out
var shots: Array = []
var bombs: Array = []
var trails: Array = [[], []]          # per player: [left tip, right tip, exhaust]
var cloud_mm: MultiMeshInstance3D
var shadow_mm: MultiMeshInstance3D
var decor: Array = []                 # drifting scenery clouds
var skins := {}
var speed := CRUISE                   # current world speed (the throttle illusion)
var scroll := 0.0
var land_t := 0.0
var _cloud_sig := -1
var _prev := [Vector2.ZERO, Vector2.ZERO]
var _bank := [0.0, 0.0]
var _throttle := [0.0, 0.0]
var _jolt := [0.0, 0.0]               # player hit kick, decays
var _player_shape := ""
var _player_skins: Array = []
var _enemy_shape := ""
var _missile_mesh: Mesh
var _enemy_missile_mesh: Mesh
var _flare_mesh: Mesh
var _t := 0.0
var terrain: MeshInstance3D
var terrain_mat: ShaderMaterial
var ocean: MeshInstance3D
var site_nodes := {}                  # SAM site id -> Node3D
var target_nodes := {}                # photo target id -> Node3D
var _env: Environment
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _decor_mats: Array = []
var _terrain_h := 0.0
var _lightning := 0.0
var _storm := false
var _base_sun := 1.0
var lightning_level := 0.0            # 0..1, read by the HUD for a screen flash


static func to3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3((p.x - Sim.W / 2) / 10.0, y, (p.y - Sim.H / 2) / 10.0)


## The point at sea level that appears at the same spot on screen as p.
static func to_sea(p: Vector2, lift := 0.0) -> Vector3:
	var v := to3(p)
	return Vector3(v.x * K, SEA_Y + lift, v.z * K)


func _ready() -> void:
	noise = _noise(256, 0.02, false, 7)
	_build_environment()
	_build_ocean()
	_build_terrain()
	_build_land()
	_build_pools()
	_build_decor()
	fx = Fx.new()
	fx.sea_y = SEA_Y
	add_child(fx)
	ships = Ships.new()
	ships.sea_y = SEA_Y
	ships.noise = noise
	add_child(ships)
	skins = {
		"ace": JetMesh.skin(Color(0.68, 0.7, 0.73), Color(0.5, 0.52, 0.55), 0.0, Color(0.25, 0.5, 0.95), noise),
		"deuce": JetMesh.skin(Color(0.56, 0.6, 0.5), Color(0.42, 0.47, 0.36), 0.7, Color(0.4, 0.75, 0.25), noise),
		"A": JetMesh.skin(Color(0.42, 0.45, 0.36), Color(0.28, 0.31, 0.24), 1.0, Color(0.8, 0.1, 0.08), noise),
		"B": JetMesh.skin(Color(0.56, 0.5, 0.4), Color(0.38, 0.35, 0.27), 1.0, Color(0.8, 0.1, 0.08), noise),
		"C": JetMesh.skin(Color(0.5, 0.53, 0.56), Color(0.36, 0.39, 0.42), 1.0, Color(0.8, 0.1, 0.08), noise),
	}
	for i in 2:
		trails[i] = [
			Fx.Trail.new(self, 0.6, 0.035, Color(1, 1, 1, 0.3)),
			Fx.Trail.new(self, 0.6, 0.035, Color(1, 1, 1, 0.3)),
			Fx.Trail.new(self, 1.2, 0.22, Color(0.85, 0.85, 0.88, 0.16)),
		]


func _noise(size: int, freq: float, normal: bool, seed_: int) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.seed = seed_
	fn.frequency = freq
	fn.fractal_octaves = 5
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = fn
	if normal:
		t.as_normal_map = true
		t.bump_strength = 5.0
	return t


# --- one-time setup ----------------------------------------------------------

func _build_environment() -> void:
	# WorldEnvironment holds the "camera film" settings for the whole scene:
	# sky light, tone mapping, bloom, haze, ambient occlusion and grading.
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.22, 0.42, 0.72)
	psm.sky_horizon_color = Color(0.62, 0.72, 0.84)
	psm.ground_bottom_color = Color(0.08, 0.14, 0.2)
	psm.ground_horizon_color = Color(0.5, 0.6, 0.7)
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true            # soft contact shadows in creases (wing roots, intakes)
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.66, 0.8)
	env.fog_density = 0.0005
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.1
	_env = env
	_sky = psm
	# The browser build uses the simpler "Compatibility" renderer, which comes
	# out darker and has less power to spare: brighten it, skip the costliest
	# extras, and use a smaller shadow map.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		env.tonemap_exposure = 1.3
		env.ssao_enabled = false
	if OS.has_feature("web"):
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		get_viewport().msaa_3d = Viewport.MSAA_2X
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)
	sun.basis = Basis.looking_at(SUN_DIR.normalized(), Vector3(0, 0, -1))
	_sun = sun

	cam = Camera3D.new()
	cam.position = Vector3(0, CAM_H, 0)
	cam.rotation = Vector3(-PI / 2, 0, 0)   # look straight down; screen-up is -Z
	cam.near = 1.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true


func _build_ocean() -> void:
	ocean_mat = ShaderMaterial.new()
	ocean_mat.shader = OCEAN
	ocean_mat.set_shader_parameter("wave_a", _noise(1024, 0.008, true, 1))
	ocean_mat.set_shader_parameter("wave_b", _noise(1024, 0.02, true, 2))
	ocean_mat.set_shader_parameter("foam_tex", _noise(256, 0.03, false, 3))
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 700)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = ocean_mat
	mi.position.y = SEA_Y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	ocean = mi


## The land for missions over solid ground: one big, finely divided plane so
## the shader can raise real hills and mountains out of it.
func _build_terrain() -> void:
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = TERRAIN
	terrain_mat.set_shader_parameter("noise_tex", _noise(512, 0.01, false, 11))
	terrain_mat.set_shader_parameter("detail_tex", _noise(256, 0.08, false, 12))
	var plane := PlaneMesh.new()
	plane.size = Vector2(380, 380)
	plane.subdivide_width = 220
	plane.subdivide_depth = 220
	terrain = MeshInstance3D.new()
	terrain.mesh = plane
	terrain.material_override = terrain_mat
	terrain.position.y = SEA_Y
	terrain.visible = false
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)


## Set the mission's light, sky, haze and ground.
func apply_look(level: Dictionary) -> void:
	var l: Dictionary = Look.LIGHTS.get(String(level.get("light", "day")), Look.LIGHTS.day)
	var sd: Vector3 = l.sun
	_sun.basis = Basis.looking_at(sd.normalized(), Vector3(0, 0, -1) if absf(sd.normalized().y) > 0.2 else Vector3.UP)
	_sun.light_color = l.sun_col
	_sun.light_energy = l.sun_e
	_base_sun = l.sun_e
	_sky.sky_top_color = l.sky_top
	_sky.sky_horizon_color = l.sky_hor
	_sky.ground_horizon_color = l.sky_hor
	_env.ambient_light_energy = l.amb
	_env.fog_light_color = l.fog
	_env.fog_density = l.fog_d
	_env.glow_intensity = l.glow
	for m in _decor_mats:
		m.set_shader_parameter("tint", l.cloud)
	_storm = String(level.get("light", "")) == "storm"
	var tname := String(level.get("terrain", "ocean"))
	var on_land: bool = Look.TERRAINS.has(tname)
	ocean.visible = not on_land
	terrain.visible = on_land
	ships.visible = not on_land
	if on_land:
		var t: Dictionary = Look.TERRAINS[tname]
		_terrain_h = float(t.height)
		terrain_mat.set_shader_parameter("biome", int(t.biome))
		terrain_mat.set_shader_parameter("height_amp", _terrain_h)
		terrain_mat.set_shader_parameter("lights", 1.0 if String(level.get("light", "")) == "night" else 0.0)
		terrain_mat.set_shader_parameter("wetness", 0.6 if String(level.get("weather", "")) == "rain" else 0.0)
		var rx := -9999.0
		if level.has("sanctuary_x"):
			rx = to_sea(Vector2(float(level.sanctuary_x) - 14.0, 0)).x
		terrain_mat.set_shader_parameter("river_x", rx)


func _build_land() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = LAND
	mat.set_shader_parameter("noise_tex", noise)
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	land = MeshInstance3D.new()
	land.mesh = plane
	land.material_override = mat
	land.visible = false
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)

	var rmat := ShaderMaterial.new()
	rmat.shader = RUNWAY
	rmat.set_shader_parameter("noise_tex", noise)
	var rp := PlaneMesh.new()
	rp.size = Vector2(Sim.STRIP_HALF.x * 2.0 / 10.0, Sim.STRIP_HALF.y * 2.0 / 10.0) * K
	runway = MeshInstance3D.new()
	runway.mesh = rp
	runway.material_override = rmat
	runway.visible = false
	add_child(runway)


func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _build_pools() -> void:
	# Cannon tracers: short glowing streaks (every round is drawn; at ~12 a
	# second per gun they read as a stream of fire).
	var cap := CapsuleMesh.new()
	cap.radius = 0.06
	cap.height = 1.4
	var shot_mat := _glow_mat(Color(1.0, 0.8, 0.35), 7.0)
	for k in 48:
		var mi := MeshInstance3D.new()
		mi.mesh = cap
		mi.material_override = shot_mat
		mi.rotation.x = PI / 2
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		shots.append(mi)
	var tr := CapsuleMesh.new()
	tr.radius = 0.08
	tr.height = 1.0
	var bomb_mat := _glow_mat(Color(1.0, 0.32, 0.18), 7.0)
	for k in 48:
		var mi := MeshInstance3D.new()
		mi.mesh = tr
		mi.material_override = bomb_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		bombs.append(mi)
	cloud_mm = _cloud_layer(Color(1, 1, 1), 0.92)
	shadow_mm = _cloud_layer(Color(0, 0, 0), 0.28)
	for i in 2:
		var chute := MeshInstance3D.new()
		var dome := SphereMesh.new()
		dome.radius = 1.3
		dome.height = 1.0
		dome.is_hemisphere = true
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(0.95, 0.5, 0.15) if i == 0 else Color(0.95, 0.92, 0.85)
		cm.roughness = 0.8
		chute.mesh = dome
		chute.material_override = cm
		chute.visible = false
		add_child(chute)
		chutes.append(chute)
	# Missile: a slim white body (capsule) with a hot glowing motor at the back.
	var body := CapsuleMesh.new()
	body.radius = 0.09
	body.height = 1.5
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.9, 0.9, 0.88)
	bm.roughness = 0.4
	body.material = bm
	_missile_mesh = body
	var ebody := CapsuleMesh.new()
	ebody.radius = 0.1
	ebody.height = 1.7
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.45, 0.5, 0.42)
	em.roughness = 0.5
	ebody.material = em
	_enemy_missile_mesh = ebody
	var flare := SphereMesh.new()
	flare.radius = 0.22
	flare.height = 0.44
	flare.material = _glow_mat(Color(1.0, 0.85, 0.6), 14.0)
	_flare_mesh = flare


func _cloud_layer(tint: Color, opacity: float) -> MultiMeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = CLOUD
	mat.set_shader_parameter("noise_tex", noise)
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("tint", tint)
	var puff := PlaneMesh.new()
	puff.size = Vector2(2.0, 2.0)
	puff.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = puff
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Scenery clouds at different heights. They all stand still in the air, so
## they move at the same world speed; perspective alone makes the near ones
## sweep past faster than the far ones (parallax), which sells the depth.
func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in 16:
		var high := k < 3
		var mat := ShaderMaterial.new()
		mat.shader = CLOUD
		mat.set_shader_parameter("noise_tex", noise)
		mat.set_shader_parameter("opacity", 0.18 if high else 0.75)
		_decor_mats.append(mat)
		var p := PlaneMesh.new()
		var s := rng.randf_range(14, 22) if high else rng.randf_range(8, 16)
		p.size = Vector2(s, s * rng.randf_range(0.6, 0.9))
		var mi := MeshInstance3D.new()
		mi.mesh = p
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var y := 30.0 if high else rng.randf_range(-17.0, -9.0)
		mi.position = Vector3(rng.randf_range(-70, 70), y, rng.randf_range(-80, 80))
		mi.rotation.y = rng.randf_range(0, TAU)
		add_child(mi)
		decor.append(mi)


# --- per level ---------------------------------------------------------------

func reset(sim) -> void:
	for id in enemy_nodes:
		enemy_nodes[id].queue_free()
	enemy_nodes.clear()
	for d in [missile_nodes, flare_nodes]:
		for id in d:
			d[id][0].queue_free()
			dying_trails.append(d[id][1])
		d.clear()
	apply_look(sim.level)
	_make_players(sim.jet)
	for d in [site_nodes, target_nodes]:
		for id in d:
			d[id].queue_free()
		d.clear()
	land.visible = false
	runway.visible = false
	land_t = 0.0
	_last_scroll = 0.0
	_cloud_sig = -1
	for i in 2:
		_prev[i] = sim.players[i].pos
		_set_damage(players[i], 0.0)
		for tr in trails[i]:
			tr.clear()


## (Re)build the players' jets for a jet type, with its own paint if it has one.
func _make_players(jet: Dictionary) -> void:
	for p in players:
		p.queue_free()
	var ace: ShaderMaterial = skins.ace
	var deuce: ShaderMaterial = skins.deuce
	if jet.has("paint"):
		var paint: Color = jet.paint
		ace = JetMesh.skin(paint, paint.darkened(0.2), 0.0, Color(0.25, 0.5, 0.95), noise)
		deuce = JetMesh.skin(paint.lightened(0.08), paint.darkened(0.25), 0.4, Color(0.4, 0.75, 0.25), noise)
	players = [JetMesh.make(String(jet.shape), ace), JetMesh.make(String(jet.shape), deuce)]
	for p in players:
		p.scale = Vector3.ONE * PLAYER_SCALE
		add_child(p)
	_player_shape = String(jet.shape)
	_player_skins = [ace, deuce]


## Fit the camera so the action plane fills exactly the 2D field rectangle.
func fit(vs: Vector2) -> void:
	if vs.x / vs.y >= Sim.W / Sim.H:
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.fov = rad_to_deg(2.0 * atan((Sim.H / 20.0) / CAM_H))
	else:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = rad_to_deg(2.0 * atan((Sim.W / 20.0) / CAM_H))


## React to things that happened in the simulation this step.
func handle(e: Dictionary, sim) -> void:
	match e.e:
		"kill":
			var p: Vector2 = e.pos
			fx.explode(to3(p, 0.5), false)
			var id: int = e.id
			if enemy_nodes.has(id):
				var node: Node3D = enemy_nodes[id]
				enemy_nodes.erase(id)
				fx.wreck(node, id)
		"hit":
			var p: Vector2 = e.pos
			fx.impact(to3(p, 0.6))
			var id: int = e.id
			if enemy_nodes.has(id):
				var node: Node3D = enemy_nodes[id]
				node.set_meta("jolt", 1.0)
		"player_damaged":
			var p: Vector2 = e.pos
			fx.impact(to3(p, 0.6))
			_jolt[int(e.i)] = 1.0
		"player_hit":
			var p: Vector2 = e.pos
			fx.explode(to3(p, 0.5), true)
			var i: int = e.i
			var w := JetMesh.make(_player_shape, _player_skins[i])
			w.scale = Vector3.ONE * PLAYER_SCALE
			add_child(w)
			w.position = to3(p)
			fx.wreck(w, sim.frame)
			_set_damage(players[i], 0.0)
		"respawn", "rescue":
			_set_damage(players[int(e.i)], 0.0)
		"puff":
			if sim.frame % 2 == 0:   # every other one, so sustained fire doesn't drown the cloud
				fx.cloud_pop(to3(e.pos, 1.0))
		"shoot":
			var p: Vector2 = e.pos
			fx.muzzle(to3(p + Vector2(0, -6), 0.3), false)
		"enemy_shoot":
			var p: Vector2 = e.pos
			fx.muzzle(to3(p, 0.3), false)
		"missile":
			var p: Vector2 = e.pos
			fx.muzzle(to3(p, 0.2), true)
		"enemy_missile":
			var p: Vector2 = e.pos
			if e.get("ground", false):
				fx.muzzle(to_h(p, SEA_Y + _terrain_h * 0.3 + 1.5), true)
			else:
				fx.muzzle(to3(p, 0.2), true)
		"flak":
			var p: Vector2 = e.pos
			fx.flak_burst(to3(p, 0.3))
		"switch":
			_make_players(sim.jet)
		"emissile_gone":
			var p: Vector2 = e.pos
			fx.impact(to3(p, 0.4))
		"emissile_hit":
			var p: Vector2 = e.pos
			fx.explode(to3(p, 0.6), false)
			_jolt[int(e.i)] = 1.6


# --- every frame -------------------------------------------------------------

var scroll_px := -1.0                 # smoothed ground scroll, set by the game each frame
var flow := 0.0                       # how fast the world moved this very frame (units/s)
var _last_scroll := 0.0
var _ground_shift := 0.0              # px of scroll since the last rules step

func sync(sim, delta: float, shake: Vector2) -> void:
	_t += delta
	delta = maxf(delta, 0.0001)
	cam.h_offset = shake.x
	cam.v_offset = shake.y
	# The world streams past at the speed the rules say (it follows the
	# pilots' throttle), converted from screen pixels to world units at sea level.
	var target: float = sim.ground_speed / 10.0 * K
	if sim.result != "":
		target = 0.0 if sim.result == "win" else speed
	speed = lerpf(speed, target, 1.0 - exp(-8.0 * delta))
	var px: float = scroll_px if scroll_px >= 0.0 else sim.ground_scroll
	scroll = px / 10.0 * K
	# Everything that stands still in the world (ground objects, ships, clouds,
	# smoke left hanging in the air) must move by exactly how far the ground
	# moved this frame, or it slides and jitters against the terrain.
	var d := scroll - _last_scroll
	if d < 0.0 or d > 30.0:
		d = 0.0                       # a new level started; don't fling things
	_last_scroll = scroll
	flow = d / delta
	# Ground objects come from the 60 Hz rules; shift them by the part of the
	# scroll that happened since the last rules step.
	_ground_shift = px - sim.ground_scroll
	_sync_players(sim, delta)
	ocean_mat.set_shader_parameter("scroll", scroll)
	# Keep the terrain mesh's vertices glued to the land: slide the mesh with
	# the scroll and snap it back by exactly one grid cell. Otherwise the
	# vertices stay put while the hills slide through them and the relief
	# "swims" (it shimmers like filming a CRT).
	var cell: float = 380.0 / 220.0
	terrain.position.z = fposmod(scroll, cell)
	terrain_mat.set_shader_parameter("scroll", scroll)
	_weather_flash(delta)
	for n in decor:
		n.position.z += flow * delta
		if n.position.z > 85.0:
			n.position.z -= 170.0
			n.position.x = fmod(n.position.x * 7.31 + 53.0, 140.0) - 70.0
	fx.update(delta, flow, flow)
	ships.update(delta, flow)
	_sync_enemies(sim, delta)
	_sync_bullets(sim)
	_sync_missiles(sim, delta)
	_sync_clouds(sim)
	_sync_land(sim)
	_sync_ground(sim)


## The point at height h that appears at the same spot on screen as p.
static func to_h(p: Vector2, h: float) -> Vector3:
	var v := to3(p)
	var k := (CAM_H - h) / CAM_H
	return Vector3(v.x * k, h, v.z * k)


## SAM sites and photo targets sit on the ground and scroll with it.
func _sync_ground(sim) -> void:
	var lift := SEA_Y + _terrain_h * 0.55 + 0.2
	var seen := {}
	for s in sim.sites:
		var id: int = s.id
		seen[id] = true
		if not site_nodes.has(id):
			site_nodes[id] = Look.sam_site()
			add_child(site_nodes[id])
		var node: Node3D = site_nodes[id]
		node.position = to_h(Vector2(s.pos) + Vector2(0, _ground_shift), lift)
		var locking := false
		for l in sim.enemy_locks:
			if l.has("site") and l.site == id:
				locking = true
		(node.get_node("Warn") as OmniLight3D).light_energy = 4.0 if locking and fmod(_t, 0.25) < 0.12 else 0.0
	for id in site_nodes.keys():
		if not seen.has(id):
			site_nodes[id].queue_free()
			site_nodes.erase(id)
	seen.clear()
	for t in sim.targets:
		var id: int = t.id
		seen[id] = true
		if not target_nodes.has(id):
			target_nodes[id] = Look.photo_target(String(t.kind))
			add_child(target_nodes[id])
		target_nodes[id].position = to_h(Vector2(t.pos) + Vector2(0, _ground_shift), lift)
	for id in target_nodes.keys():
		if not seen.has(id):
			target_nodes[id].queue_free()
			target_nodes.erase(id)


## Storm missions: now and then the sky lights up.
func _weather_flash(delta: float) -> void:
	if not _storm:
		return
	_lightning = maxf(0.0, _lightning - delta * 3.0)
	if _lightning <= 0.0 and randf() < delta * 0.18:
		_lightning = 1.0
	var flash := _lightning * (0.6 + 0.4 * sin(_t * 60.0))
	_sun.light_energy = _base_sun + flash * 3.0
	lightning_level = flash


## The more damaged a jet is, the harder it fights to stay level: it rocks,
## twitches and yaws, kicks when hit, and its engine coughs.
func _struggle(dmg: float, seed_: float, jolt: float) -> Vector3:
	var shake := dmg * dmg
	var roll := sin(_t * 7.3 + seed_) * 0.28 * shake + sin(_t * 17.0 + seed_ * 2.0) * 0.1 * shake + jolt * 0.5 * sin(seed_ * 9.0 + _t * 40.0)
	var pitch := sin(_t * 5.1 + seed_ * 1.7) * 0.08 * shake + jolt * 0.15
	var yaw := sin(_t * 3.3 + seed_ * 0.7) * 0.12 * shake
	return Vector3(pitch, yaw, roll)


## Smoke at a third damage, fire at two thirds. The emitters stay on the jet;
## their particles are left behind in the air.
func _set_damage(node: Node3D, dmg: float) -> void:
	if node == null:
		return
	var smoke: GPUParticles3D = node.get_meta("smoke") if node.has_meta("smoke") else null
	var fire: GPUParticles3D = node.get_meta("fire") if node.has_meta("fire") else null
	if dmg >= 0.3 and smoke == null:
		smoke = fx.damage_smoke(false)
		smoke.position = Vector3(0.5, 0.2, 0.8)
		node.add_child(smoke)
		node.set_meta("smoke", smoke)
	if dmg >= 0.65 and fire == null:
		fire = fx.damage_smoke(true)
		fire.position = Vector3(-0.4, 0.2, 0.5)
		node.add_child(fire)
		node.set_meta("fire", fire)
	for em in [smoke, fire]:
		if em != null:
			em.emitting = dmg >= 0.3 and (em == smoke or dmg >= 0.65)
			# Particles leave at the speed the air streams past.
			var pm: ParticleProcessMaterial = em.process_material
			pm.direction = Vector3(0, 0.2, 1)
			pm.spread = 12.0
			pm.initial_velocity_min = speed * 0.8
			pm.initial_velocity_max = speed * 1.0


func _engine_power(dmg: float, seed_: float) -> float:
	# A hurt engine coughs: short dropouts that get more frequent with damage.
	var cough := 1.0
	if dmg > 0.45 and sin(_t * 6.0 + seed_) * sin(_t * 2.3 + seed_ * 3.0) > 1.0 - dmg:
		cough = 0.25
	return cough * (1.0 - 0.3 * dmg)


func _sync_players(sim, delta: float) -> void:
	var landing: bool = sim.result == "win"
	if landing:
		land_t += delta
	var e := smoothstep(0.0, 1.0, land_t / 1.8)
	for i in 2:
		var p: Dictionary = sim.players[i]
		var node: Node3D = players[i]
		var pos: Vector2 = p.pos
		var flying: bool = p.active and p.alive
		node.visible = flying and not (p.invuln > 0.3 and fmod(_t, 0.2) < 0.07)
		var prev: Vector2 = _prev[i]
		var v := (pos - prev) / delta / Sim.PLAYER_SPEED
		_prev[i] = pos
		# Sideways speed becomes a bank; up/down speed becomes throttle.
		_bank[i] = lerpf(_bank[i], clampf(v.x, -1.0, 1.0) * -0.7, 1.0 - exp(-10.0 * delta))
		var thr_target := clampf(-v.y, -1.0, 1.0) if flying else 0.0
		_throttle[i] = lerpf(_throttle[i], thr_target, 1.0 - exp(-6.0 * delta))
		_jolt[i] = maxf(0.0, _jolt[i] - delta * 5.0)
		var dmg: float = sim.damage(p) if flying else 0.0
		var wob := _struggle(dmg, i * 3.1, _jolt[i])
		node.rotation = Vector3(-_throttle[i] * 0.06, 0, _bank[i]) + wob
		var kick: Vector3 = Vector3(sin(_t * 50.0) * 0.25, 0, 0.35) * _jolt[i]
		node.position = (to3(pos).lerp(to_sea(pos, 0.6), e) if landing else to3(pos)) + kick
		_set_damage(node, dmg)
		var burn: float = (1.0 + 0.9 * _throttle[i]) * _engine_power(dmg, i * 5.0)
		for f in node.get_children():
			if f.name.begins_with("Flame"):
				f.visible = e < 0.4
				f.scale = Vector3(1.0, maxf(0.25, burn), 1.0)
				(f.material_override as ShaderMaterial).set_shader_parameter("power", maxf(0.3, burn))
		# Vapour: wingtip trails show when pulling hard (banking or boosting).
		var tr: Array = trails[i]
		var pull := clampf(absf(_bank[i]) * 1.4 + maxf(_throttle[i], 0.0) * 0.5 - 0.3, 0.0, 1.0)
		var on := 1.0 if node.visible else 0.0
		tr[0].update(node.to_global(Vector3(-1.5, 0, 0.75)), pull * on, flow, delta)
		tr[1].update(node.to_global(Vector3(1.5, 0, 0.75)), pull * on, flow, delta)
		tr[2].update(node.to_global(Vector3(0, 0, 2.2)), on * (1.0 - e), flow, delta)
		var chute: MeshInstance3D = chutes[i]
		chute.visible = p.has_chute
		if p.has_chute:
			chute.position = to3(p.chute, 1.5)
			chute.rotation.z = sin(_t * 2.0 + i) * 0.15


func _sync_enemies(sim, delta: float) -> void:
	var seen := {}
	for e in sim.enemies:
		var id: int = e.id
		seen[id] = true
		var target := to3(e.pos)
		var node: Node3D
		if not enemy_nodes.has(id):
			var shape: String = Jets.get_jet(String(e.jet)).shape
			node = JetMesh.make(shape, skins.get(e.kind, skins.C), 0.7)
			node.scale = Vector3.ONE * ENEMY_SCALE * (1.3 if e.boss else 1.0)
			add_child(node)
			node.position = target
			node.set_meta("vel", Vector3.ZERO)
			node.set_meta("jolt", 0.0)
			enemy_nodes[id] = node
		node = enemy_nodes[id]
		var dmg := 1.0 - float(e.hp) / float(e.max_hp)
		var jolt: float = maxf(0.0, float(node.get_meta("jolt")) - delta * 5.0)
		node.set_meta("jolt", jolt)
		# Glide toward the squadron's position; a hurt jet lags its slot and
		# sags out of formation.
		var before := node.position
		var sag := Vector3(sin(_t * 1.3 + id) * 0.6, 0, -0.8) * dmg * dmg
		node.position = node.position.lerp(target + sag, 1.0 - exp(-14.0 * delta)) + Vector3(0, 0, -0.3) * jolt
		var vel: Vector3 = (node.position - before) / delta
		var sm: Vector3 = (node.get_meta("vel") as Vector3).lerp(vel, 1.0 - exp(-8.0 * delta))
		node.set_meta("vel", sm)
		# Bank into turns so sideways motion reads as weaving.
		var wob := _struggle(dmg, float(id), jolt)
		node.rotation = Vector3(0, PI + clampf(sm.x * 0.04, -0.25, 0.25), clampf(sm.x * 0.12, -0.6, 0.6) + sin(_t * 1.7 + id) * 0.05) + wob
		_set_damage(node, dmg)
		# Afterburners blaze while they dive in, then settle; damage makes them cough.
		var burn := clampf(1.0 + sm.z * 0.05, 0.6, 3.0) * _engine_power(dmg, float(id))
		for f in node.get_children():
			if f.name.begins_with("Flame"):
				f.scale = Vector3(1.0, maxf(0.3, burn), 1.0)
				(f.material_override as ShaderMaterial).set_shader_parameter("power", burn)
	for id in enemy_nodes.keys():
		if not seen.has(id):
			enemy_nodes[id].queue_free()
			enemy_nodes.erase(id)


func _sync_bullets(sim) -> void:
	for k in shots.size():
		var mi: MeshInstance3D = shots[k]
		mi.visible = k < sim.shots.size()
		if mi.visible:
			mi.position = to3(sim.shots[k].pos + Vector2(0, 6))
	for k in bombs.size():
		var mi: MeshInstance3D = bombs[k]
		mi.visible = k < sim.bombs.size()
		if mi.visible:
			var b: Dictionary = sim.bombs[k]
			var v: Vector2 = b.vel
			mi.position = to3(b.pos)
			# Point the tracer along its flight path.
			mi.rotation = Vector3(PI / 2, 0, 0)
			mi.rotate_y(-atan2(v.x, v.y))


func _sync_missiles(sim, delta: float) -> void:
	var seen := {}
	for m in sim.missiles + sim.enemy_missiles:
		var id: int = m.id
		seen[id] = true
		if not missile_nodes.has(id):
			var theirs: bool = m.has("decoy")
			var root := Node3D.new()
			var body := MeshInstance3D.new()
			body.mesh = _enemy_missile_mesh if theirs else _missile_mesh
			body.rotation.x = PI / 2
			root.add_child(body)
			var motor := OmniLight3D.new()
			motor.light_color = Color(1.0, 0.7, 0.4)
			motor.light_energy = 2.0
			motor.omni_range = 4.0
			motor.position = Vector3(0, 0, 0.8)
			root.add_child(motor)
			add_child(root)
			missile_nodes[id] = [root, Fx.Trail.new(self, 1.8, 0.26 if theirs else 0.2, Color(0.92, 0.92, 0.92, 0.65))]
		var node: Node3D = missile_nodes[id][0]
		var v: Vector2 = m.vel
		node.position = to3(m.pos, 0.4)
		if m.get("from_ground", false):
			# Climbing up from the launcher to our altitude over its first second.
			var k := smoothstep(0.0, 1.0, float(m.t) / 1.0)
			node.position = to_h(m.pos, lerpf(SEA_Y + _terrain_h * 0.55 + 1.5, 0.4, k))
		node.rotation = Vector3(0, -atan2(v.x, -v.y), 0)
		var trail = missile_nodes[id][1]
		trail.update(node.to_global(Vector3(0, 0, 0.8)), 1.0, flow, delta)
	for id in missile_nodes.keys():
		if not seen.has(id):
			missile_nodes[id][0].queue_free()
			dying_trails.append(missile_nodes[id][1])
			missile_nodes.erase(id)
	_sync_flares(sim, delta)
	for tr in dying_trails.duplicate():
		if not tr.fade(flow, delta):
			tr.node.queue_free()
			dying_trails.erase(tr)


## Flares: white-hot burning points that light up everything near them,
## each trailing smoke as it falls away behind the jet.
func _sync_flares(sim, delta: float) -> void:
	var seen := {}
	for f in sim.flares:
		var id: int = f.id
		seen[id] = true
		if not flare_nodes.has(id):
			var root := Node3D.new()
			var ball := MeshInstance3D.new()
			ball.mesh = _flare_mesh
			ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(ball)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.8, 0.55)
			light.light_energy = 3.0
			light.omni_range = 7.0
			root.add_child(light)
			add_child(root)
			flare_nodes[id] = [root, Fx.Trail.new(self, 1.0, 0.12, Color(0.95, 0.95, 0.95, 0.5))]
		var node: Node3D = flare_nodes[id][0]
		node.position = to3(f.pos, 0.3)
		var life := 1.0 - float(f.t) / Sim.FLARE_LIFE
		var flick := 0.7 + 0.3 * sin(_t * 41.0 + id)
		node.scale = Vector3.ONE * (0.6 + 0.6 * life) * flick
		(node.get_child(1) as OmniLight3D).light_energy = 3.0 * life * flick
		flare_nodes[id][1].update(node.position, life, flow, delta)
	for id in flare_nodes.keys():
		if not seen.has(id):
			flare_nodes[id][0].queue_free()
			dying_trails.append(flare_nodes[id][1])
			flare_nodes.erase(id)


func _sync_clouds(sim) -> void:
	var sig: int = sim.clouds.size() * 3
	for c in sim.clouds:
		sig += int(sim.clouds[c])
	if sig == _cloud_sig:
		return
	_cloud_sig = sig
	var cells: Array = sim.clouds.keys()
	var sun := SUN_DIR.normalized()
	for mmi in [cloud_mm, shadow_mm]:
		var mm: MultiMesh = mmi.multimesh
		mm.instance_count = cells.size()
		for k in cells.size():
			var c: Vector2i = cells[k]
			var h := float(((c.x * 73856093) ^ (c.y * 19349663)) & 1023) / 1023.0
			var centre := (Vector2(c) + Vector2(0.5, 0.5)) * Sim.CELL
			var pos := to3(centre, 0.8 + h * 0.6)
			if mmi == shadow_mm:
				# Where the sun would cast this puff's shadow on the sea.
				pos = pos + sun * ((SEA_Y + 0.3 - pos.y) / sun.y)
			var basis := Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * (0.9 + h * 0.5) * (K if mmi == shadow_mm else 1.0))
			mm.set_instance_transform(k, Transform3D(basis, pos))
			var hp: int = sim.clouds[c]
			mm.set_instance_color(k, Color(1, 1, 1, clampf(float(hp) / Sim.CLOUD_HP, 0.3, 1.0)))


func _sync_land(sim) -> void:
	var on: bool = sim.phase == "approach"
	land.visible = on
	runway.visible = on
	if not on:
		return
	var strip: Vector2 = Vector2(sim.strip) + Vector2(0, _ground_shift)
	var coast_y := strip.y + Sim.STRIP_HALF.y + 40.0
	land.position = to_sea(Vector2(Sim.W / 2, coast_y), 0.08)
	runway.position = to_sea(strip, 0.14)
