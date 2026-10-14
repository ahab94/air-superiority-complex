extends SceneTree

func _init() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	print("SMOKE OK" if main.has_method("load_level") else "SMOKE FAILED")
	main.free()
	quit(0)
