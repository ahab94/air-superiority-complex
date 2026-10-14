extends SceneTree
## Renders the parody jets close up, from above and at an angle, to a PNG.
## godot --path . --script res://tools/jet_preview.gd -- --out=path.png
const JetMesh := preload("res://scripts/jet_mesh.gd")

func _init() -> void:
	var out := "user://jets.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var root := Node3D.new()
	get_root().add_child(root)
	var fn := FastNoiseLite.new()
	var nt := NoiseTexture2D.new()
	nt.noise = fn
	nt.seamless = true
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.3, 0.45)
	env.ambient_light_color = Color(0.6, 0.7, 0.8)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	root.add_child(sun)
	sun.basis = Basis.looking_at(Vector3(0.42, -1.0, 0.32).normalized(), Vector3(0, 0, -1))
	var skins := [
		JetMesh.skin(Color(0.68, 0.7, 0.73), Color(0.5, 0.52, 0.55), 0.0, Color(0.25, 0.5, 0.95), nt),
		JetMesh.skin(Color(0.42, 0.45, 0.36), Color(0.28, 0.31, 0.24), 1.0, Color(0.8, 0.1, 0.08), nt),
	]
	var kinds := JetMesh.MODELS.keys()
	for k in kinds.size():
		var top := JetMesh.make(kinds[k], skins[k % 2])
		var s := 0.45 if kinds[k] == "tuba" else 1.0
		top.scale = Vector3.ONE * s
		top.position = Vector3(-10.0 + (k % 5) * 5.0, 0, -6.0 + (k / 5) * 5.5)
		root.add_child(top)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 22, 0)
	cam.rotation = Vector3(-PI / 2, 0, 0)
	cam.fov = 45
	root.add_child(cam)
	cam.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
