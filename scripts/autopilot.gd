extends RefCounted
## A computer pilot. It plays the real rules through the same input a person
## gives ({move, fire, missile, flare}), so if it can beat a mission, the
## mission is winnable. It's the "every level is winnable" test, the AI
## wingman for solo players, and the camera operator for trailers.
##
## Each step it scores a row of candidate x positions: how far each is from
## the spot it wants to be (under a target, over a photo site, on the
## runway), whether anything would hit it on the way there (enemy rounds fly
## straight, flak bursts are marked in advance, missiles roughly), and how
## crowded it is next to the wingman. Then it steers to the best one.

const Sim := preload("res://scripts/sim.gd")
const HORIZON := 45          # frames of forecast (0.75 s)
const SAFETY := 4.0          # extra pixels of margin around the hitbox

var _last_x := [-1.0, -1.0]
var _holding := [false, false]   # holding the missile button to build locks
## For trailer gags: fly without dodging, shooting or flares, and steer the
## parachute to the wrong side.
var reckless := false
## A human-like pilot for measuring difficulty: reacts only every few frames,
## aims a little off, sees danger late, and sometimes forgets the flares.
var rookie := false
var _rng := RandomNumberGenerator.new()
var _held := [{}, {}]
var _hold_frames := [0, 0]


func _init() -> void:
	_rng.seed = 7


func decide(sim, i: int) -> Dictionary:
	if rookie:
		# Reaction time: keep the last decision for a few frames.
		_hold_frames[i] -= 1
		if _hold_frames[i] > 0 and not _held[i].is_empty():
			return _held[i]
		_hold_frames[i] = 9
		var d := _decide(sim, i)
		if d.flare and _rng.randf() < 0.45:
			d.flare = false          # panicked and forgot
		_held[i] = d
		return d
	return _decide(sim, i)


func _decide(sim, i: int) -> Dictionary:
	var out := {"move": Vector2.ZERO, "fire": false, "missile": false, "flare": false}
	var p: Dictionary = sim.players[i]
	if not p.alive:
		_holding[i] = false
		if p.has_chute and sim.level.get("tea", false):
			# Steer the parachute home (and away from the tea).
			var home_left: bool = String(sim.level.get("home", "left")) == "left"
			if reckless:
				home_left = not home_left
			var home_x: float = Sim.W * (0.25 if home_left else 0.75)
			out.move = Vector2(clampf((home_x - Vector2(p.chute).x) / 20.0, -1.0, 1.0), 0)
		return out
	var pos: Vector2 = p.pos
	var mate: Dictionary = sim.players[1 - i]
	var mate_on: bool = mate.active and mate.alive
	var mate_pos: Vector2 = mate.pos
	var goal_y := Sim.PLAYER_Y
	var aim_x := pos.x
	var jet: Dictionary = sim.jet
	var armed: bool = float(jet.gun) > 0.0 or int(jet.missiles) > 0

	if mate.active and mate.has_chute:
		# Catch the wingman's parachute first: it saves a jet.
		var c: Vector2 = mate.chute
		aim_x = c.x
		goal_y = clampf(c.y, Sim.PLAYER_ZONE_TOP, Sim.PLAYER_ZONE_BOTTOM)
	elif sim.phase == "approach":
		aim_x = sim.strip.x + ((-14.0 if i == 0 else 14.0) if mate_on else 0.0)
	else:
		var photo = _next_photo(sim, i)
		if photo != null:
			aim_x = Vector2(photo.pos).x
		elif armed:
			var target = _pick_target(sim, pos, mate_pos if mate_on else Vector2(-999, 0))
			if target != null:
				aim_x = _lead(sim, pos, target).x
				if rookie:
					aim_x += _rng.randf_range(-14.0, 14.0)
		else:
			aim_x = Sim.W * (0.35 if i == 0 else 0.65)

	var best_x := pos.x
	var best_cost := INF
	var x := 16.0
	while x <= Sim.W - 16.0:
		var cost := absf(x - aim_x)
		if _last_x[i] >= 0.0:
			cost += 0.25 * absf(x - _last_x[i])   # don't dither between two spots
		if mate_on:
			cost += maxf(0.0, 40.0 - absf(x - mate_pos.x)) * 3.0
		var hit := -1 if reckless else _first_hit(sim, pos, Vector2(x, goal_y), jet)
		if hit >= 0:
			cost += (2500.0 if rookie else 10000.0) + (HORIZON - hit) * 100.0
		if cost < best_cost:
			best_cost = cost
			best_x = x
		x += 8.0
	_last_x[i] = best_x

	var agility: float = jet.agility
	var step_x: float = Sim.PLAYER_SPEED * Sim.DT * agility
	var step_y := Sim.PLAYER_SPEED * Sim.DT
	var mx := clampf((best_x - pos.x) / step_x, -1.0, 1.0)
	if sim.level.get("icing", false):
		# Sliding: steer by the error, but brake against the current drift.
		var v: Vector2 = p.vel
		mx = clampf((best_x - pos.x) / 40.0 - v.x / (Sim.PLAYER_SPEED * agility) * 1.6, -1.0, 1.0)
	# Lean into the wind so it doesn't push us off the spot.
	var wind: float = sim.wind_x()
	mx = clampf(mx - wind / (Sim.PLAYER_SPEED * agility), -1.0, 1.0)
	out.move = Vector2(mx, clampf((goal_y - pos.y) / step_y, -1.0, 1.0))

	var threats: Array = sim.threats_to(i)
	var closest := INF
	for m in threats:
		closest = minf(closest, Vector2(m.pos).distance_to(pos))
	# Afterburner jets run from missiles, but not into an overheat.
	if float(jet.boost) > 0.0 and closest < 300.0 and float(p.heat) < 0.85 and float(p.overheat) <= 0.0:
		out.move.y = -1.0
	if closest < 200.0 and float(p.flare_cd) <= 0.0 and not reckless:
		out.flare = true

	# Patience: under weapons-hold, wait for them to shoot first; in disguise,
	# let them get close before springing the ambush.
	var hold: bool = sim.level.get("roe", false) and not sim.weapons_free
	if sim.disguised:
		var low := 0.0
		for e in sim.enemies:
			low = maxf(low, Vector2(e.pos).y)
		hold = hold or low < 330.0
	if sim.phase == "fight" and armed and not reckless and not hold:
		if float(jet.gun) > 0.0 and sim.level.get("player_guns", true) and not sim.cloud_between(pos.x, pos.y - 20.0, 0.0):
			for e in sim.enemies:
				if sim.engageable(e.pos) and sim.hittable(e) and absf(_lead(sim, pos, e).x - pos.x) < Vector2(e.half).x - 2.0:
					out.fire = true
					break
		out.missile = _missile_plan(sim, i, p)
	return out


## The next photo site worth flying over: not yet photographed, still ahead.
func _next_photo(sim, i: int):
	var best = null
	var best_y := -INF
	for t in sim.targets:
		var tp: Vector2 = t.pos
		if t.done or tp.y > Sim.PLAYER_Y + 10.0:
			continue
		# In co-op, split them: each takes the ones on its half.
		var mate: Dictionary = sim.players[1 - i]
		if mate.active and mate.alive and ((tp.x < Sim.W / 2) != (i == 0)):
			continue
		if tp.y > best_y:
			best_y = tp.y
			best = t
	return best


## Save missiles for when they matter: a crowded sky, a boss, a hurt jet, or a
## missile-heavy loadout. Hold the button until the locks are full (or
## nothing more can be locked), then let go.
func _missile_plan(sim, i: int, p: Dictionary) -> bool:
	var locks: Array = p.locks
	var jet: Dictionary = sim.jet
	if _holding[i]:
		var full: bool = locks.size() >= int(jet.locks) or locks.size() >= int(p.missiles)
		# Fire when the locks are full, or when no further target can be found.
		var stalled: bool = not locks.is_empty() and float(p.lock_t) > float(jet.lock_time) * 1.5
		if full or stalled:
			_holding[i] = false
			return false
		return true
	if int(p.missiles) <= 0 or int(jet.locks) <= 0:
		return false
	var formed := 0
	var boss := false
	for e in sim.enemies:
		if Vector2(e.pos).y > 40.0 and sim.engageable(e.pos) and sim.hittable(e):
			formed += 1
			boss = boss or e.boss or e.get("awacs", false) or e.get("phantom", false)
	var hurt: bool = sim.damage(p) > 0.5
	var no_guns: bool = not sim.level.get("player_guns", true)
	var plenty: bool = int(p.missiles) > 4 or no_guns
	if formed >= 9 or (boss and formed >= 1) or (hurt and formed >= 3) or (plenty and formed >= (1 if no_guns else 2)):
		_holding[i] = true
		return true
	return false


## The lowest jets are the most urgent; nearer ones are cheaper to reach. With
## a wingman, leave the jets on their side to them.
func _pick_target(sim, pos: Vector2, mate_pos: Vector2):
	var best = null
	var best_cost := INF
	for e in sim.enemies:
		var ep: Vector2 = e.pos
		if ep.y < 20.0 or not sim.engageable(ep) or not sim.hittable(e):
			continue
		var cost := absf(ep.x - pos.x) + (Sim.OVERRUN_Y - ep.y) * 0.5 + minf(float(e.hp), 12.0) * 6.0
		if e.get("awacs", false):
			cost -= 400.0           # break the kill chain first
		if e.get("rear", false) and ep.y > pos.y:
			cost += 500.0           # still behind us: can't shoot backwards
		cost += maxf(0.0, absf(ep.x - pos.x) - absf(ep.x - mate_pos.x)) * 0.8
		if sim.cloud_between(ep.x, Sim.PLAYER_Y - 20.0, ep.y):
			cost += 80.0
		if cost < best_cost:
			best_cost = cost
			best = e
	return best


## Where a jet will be when a round fired now reaches its height.
func _lead(sim, pos: Vector2, e) -> Vector2:
	var ep: Vector2 = e.pos
	var flight := maxf(0.0, (pos.y - 18.0 - ep.y) / Sim.SHOT_SPEED)
	return sim.enemy_pos_in(e, flight)


## Fly from `from` toward `to` at full speed while everything else moves on;
## return the first frame something hits, or -1 if the path is clear.
func _first_hit(sim, from: Vector2, to: Vector2, jet: Dictionary) -> int:
	var hb: Vector2 = jet.hitbox
	var reach := Vector2(hb.x + Sim.BOMB_R + SAFETY, hb.y + Sim.BOMB_R + SAFETY)
	var speed := Sim.PLAYER_SPEED * Sim.DT
	var agility: float = jet.agility
	var flak_r := 0.0
	if sim.level.has("flak"):
		flak_r = float(sim.level.flak.radius) + 8.0
	var pos := from
	for f in range(1, (16 if rookie else HORIZON) + 1):
		var d := to - pos
		d.x /= agility
		var stepv := d.limit_length(speed)
		stepv.x *= agility
		pos += stepv
		var t := Sim.DT * f
		for b in sim.bombs:
			var bp: Vector2 = b.pos
			var bv: Vector2 = b.vel
			var at := bp + bv * t
			if absf(at.x - pos.x) < reach.x and absf(at.y - pos.y) < reach.y:
				return f
		# Flak bursts are marked before they go off: be elsewhere when they do.
		for fl in sim.flak:
			if absf(float(fl.t) - t) < Sim.DT * 1.5 and Vector2(fl.pos).distance_to(pos) < flak_r:
				return f
		# Missiles home, so this straight-line guess is rough; it still
		# pushes the jet to break sideways across a missile's path.
		for m in sim.enemy_missiles:
			if m.decoy >= 0:
				continue
			var mp: Vector2 = m.pos
			var mv: Vector2 = m.vel
			if (mp + mv * t).distance_to(pos) < 22.0:
				return f
	return -1
