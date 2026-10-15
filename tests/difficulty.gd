extends SceneTree
## Difficulty curve: a "rookie" autopilot (slow reactions, sloppy aim, late
## dodges, forgetful with flares) flies every mission a few times; the hits it
## takes per minute should climb steadily from mission 1 to the last.
## Run: godot --headless --path . --script res://tests/difficulty.gd
const Sim := preload("res://scripts/sim.gd")
const Levels := preload("res://scripts/levels.gd")
const Autopilot := preload("res://scripts/autopilot.gd")

func _init() -> void:
	for n in Levels.LIST.size():
		var hits := 0.0
		var lost := 0
		var wins := 0
		var secs := 0.0
		for run in 3:
			var level: Dictionary = Levels.LIST[n].duplicate(true)
			level.seed = int(level.seed) + run * 101
			var sim = Sim.new(level, 1)
			var ap = Autopilot.new()
			ap.rookie = true
			ap._rng.seed = 7 + run
			while sim.result == "" and sim.frame < 60 * 150:
				sim.step([ap.decide(sim, 0), ap.decide(sim, 1)])
				sim.events.clear()
			hits += sim.damage_taken
			lost += int(level.get("lives", 3)) - sim.lives + (1 if sim.result == "lose" else 0)
			wins += 1 if sim.result == "win" else 0
			secs += sim.elapsed
		print("DIFF %2d %-24s armor lost/min %5.1f  jets lost %4.1f  wins %d/3  (%.0fs avg)" % [n + 1, Levels.LIST[n].name, hits / (secs / 60.0), lost / 3.0, wins, secs / 3.0])
	quit()
