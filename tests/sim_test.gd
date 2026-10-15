extends SceneTree
## Rules tests plus the winnability gate: the autopilot must beat every
## mission solo and in co-op. Run: godot --headless --path . --script res://tests/sim_test.gd

const Sim := preload("res://scripts/sim.gd")
const Levels := preload("res://scripts/levels.gd")
const Autopilot := preload("res://scripts/autopilot.gd")

var failures := 0


func _init() -> void:
	_test_solo_hit_costs_a_life()
	_test_coop_rescue()
	_test_landing()
	_test_flameout()
	_test_deterministic()
	_test_missiles()
	_test_flares()
	_test_tea()
	_test_stealth_needs_awacs()
	for n in Levels.LIST.size():
		for players in [1, 2]:
			var r := play(n, players)
			print("mission %2d, %d player(s): %s %s in %.1fs, score %d, lives left %d" % [n + 1, players, r.result, r.reason, r.frames / 60.0, r.score, r.lives])
			_check(r.result == "win", "autopilot should beat mission %d with %d player(s)" % [n + 1, players])
	print("SIM OK" if failures == 0 else "SIM FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


static func play(n: int, players: int, max_seconds := 300) -> Dictionary:
	var sim = Sim.new(Levels.LIST[n], players)
	var pilot = Autopilot.new()
	while sim.result == "" and sim.frame < max_seconds * 60:
		sim.step([pilot.decide(sim, 0), pilot.decide(sim, 1)])
	return {"result": sim.result, "reason": sim.reason, "frames": sim.frame, "score": sim.score, "lives": sim.lives, "fuel": sim.fuel}


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _idle() -> Array:
	return [{}, {}]


func _test_solo_hit_costs_a_life() -> void:
	var sim = Sim.new(Levels.LIST[0], 1)
	sim.players[0].hp = 1
	sim.bombs = [{"pos": sim.players[0].pos, "vel": Vector2.ZERO}]
	sim.step(_idle())
	_check(not sim.players[0].alive and sim.lives == 2, "solo shoot-down should cost a spare life")
	for k in int(Sim.RESPAWN * 60) + 2:
		sim.step(_idle())
	_check(sim.players[0].alive, "solo player should respawn")


func _test_coop_rescue() -> void:
	var sim = Sim.new(Levels.LIST[0], 2)
	sim.players[0].hp = 1
	sim.bombs = [{"pos": sim.players[0].pos, "vel": Vector2.ZERO}]
	sim.step(_idle())
	_check(sim.players[0].has_chute and sim.lives == 3, "co-op hit should eject, not spend a life")
	sim.players[1].pos = sim.players[0].chute
	sim.step(_idle())
	_check(sim.players[0].alive and not sim.players[0].has_chute, "wingman should rescue the pilot")


func _test_landing() -> void:
	var sim = Sim.new(Levels.LIST[0], 1)
	sim.wave = Levels.LIST[0].waves.size() - 1
	sim.enemies.clear()
	sim.groups.clear()
	for k in 60 * 20:
		sim.players[0].pos = Vector2(sim.strip.x, Sim.PLAYER_Y)
		sim.players[0].invuln = 1.0
		sim.step(_idle())
		if sim.result != "":
			break
	_check(sim.result == "win" and sim.reason == "landed", "landing on the strip should win (got %s %s)" % [sim.result, sim.reason])


func _test_missiles() -> void:
	var sim = Sim.new(Levels.LIST[0], 1)
	for k in 200:   # let the first squadrons arrive
		sim.step(_idle())
	var before: int = sim.players[0].missiles
	var hold := [{"missile": true}, {}]
	for k in 90:
		sim.step(hold)
	var locked: int = sim.players[0].locks.size()
	_check(locked == int(sim.jet.locks), "holding should lock %d targets (got %d)" % [sim.jet.locks, locked])
	var kills: int = sim.kills
	sim.step(_idle())   # release: fire
	_check(sim.players[0].missiles == before - locked, "each lock should use one missile")
	for k in 120:
		sim.step(_idle())
	_check(sim.kills - kills >= locked, "each missile should kill its target (killed %d)" % [sim.kills - kills])
	var sim2 = Sim.new(Levels.LIST[0], 1)
	sim2.players[0].hp = 4
	sim2.players[0].pos = Vector2(240, Sim.PLAYER_Y)
	sim2.step([{"move": Vector2(1, 0)}, {}])
	var hurt_dx: float = sim2.players[0].pos.x - 240.0
	_check(hurt_dx < Sim.PLAYER_SPEED * Sim.DT * float(sim2.jet.agility) - 0.5, "a damaged jet should be slower")


func _test_flares() -> void:
	var sim = Sim.new(Levels.LIST[0], 1)
	var pos: Vector2 = sim.players[0].pos
	sim.enemy_missiles = [{"id": 999, "pos": pos + Vector2(0, -150), "vel": Vector2(0, 300), "target": 0, "decoy": -1, "t": 0.0}]
	var hp: int = sim.players[0].hp
	sim.step([{"flare": true}, {}])
	_check(sim.flares.size() == 2, "a flare drop should release 2 flares")
	sim.step([{"flare": true}, {}])
	_check(sim.flares.size() == 2, "flares should need to recharge before the next pair")
	_check(sim.enemy_missiles.is_empty() or sim.enemy_missiles[0].decoy >= 0, "a close missile should chase the flares")
	for k in 240:
		sim.step(_idle())
	_check(sim.players[0].hp == hp, "a decoyed missile should not hit (hp %d -> %d)" % [hp, sim.players[0].hp])
	var sim2 = Sim.new(Levels.LIST[0], 1)
	var p2: Vector2 = sim2.players[0].pos
	sim2.enemy_missiles = [{"id": 998, "pos": p2 + Vector2(0, -60), "vel": Vector2(0, 300), "target": 0, "decoy": -1, "t": 0.0}]
	for k in 30:
		sim2.step(_idle())
	_check(sim2.players[0].hp == hp - Sim.EMISSILE_DAMAGE, "an enemy missile hit should cost %d armor (got %d)" % [Sim.EMISSILE_DAMAGE, hp - sim2.players[0].hp])


func _test_tea() -> void:
	for side in [-1.0, 1.0]:
		var sim = Sim.new(Levels.LIST[8], 1)
		sim.players[0].hp = 1
		sim.bombs = [{"pos": sim.players[0].pos, "vel": Vector2.ZERO}]
		var got := ""
		for k in 60 * 30:
			sim.step([{"move": Vector2(side, 0)}, {}])
			for e in sim.events:
				if e.e in ["tea", "home"]:
					got = e.e
			sim.events.clear()
			if got != "":
				break
		var want := "home" if side < 0.0 else "tea"
		_check(got == want, "steering the parachute %s should end in %s (got '%s')" % ["left" if side < 0 else "right", want, got])


## Stealth is modern kit: cloaked squadrons only in waves with an AWACS, only
## in missions set after 2000, and never left cloaked once the AWACS is gone.
func _test_stealth_needs_awacs() -> void:
	for lv in Levels.LIST:
		for w in lv.waves:
			for spec in w:
				if spec.get("cloaked", false) or spec.get("awacs", false):
					_check(int(lv.year) >= 2000, "%s: AWACS/stealth only in modern missions" % lv.name)
				if spec.get("cloaked", false):
					_check(Sim._wave_has_awacs(w), "%s: a cloaked squadron without an AWACS" % lv.name)
	var sim = Sim.new(Levels.LIST[14], 1)
	for k in 120:
		sim.step(_idle())
	_check(sim.chain_up, "the kill chain should be up while the AWACS flies")
	for e in sim.enemies.duplicate():
		if e.get("awacs", false):
			sim.enemies.erase(e)
	sim.step(_idle())
	var still_hidden := false
	for e in sim.enemies:
		if not sim.hittable(e) and not e.get("phantom", false):
			still_hidden = true
	_check(not still_hidden, "no fighter may stay cloaked once every AWACS is down")


func _test_flameout() -> void:
	var sim = Sim.new(Levels.LIST[0], 1)
	sim.fuel = 0.001
	sim.step(_idle())
	_check(sim.result == "lose" and sim.reason == "flameout", "empty tank should lose")


func _test_deterministic() -> void:
	var a := play(0, 2, 30)
	var b := play(0, 2, 30)
	_check(a.hash() == b.hash(), "same inputs should give the same game")
