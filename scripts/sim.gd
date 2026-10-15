extends RefCounted
## The whole game as plain data and rules: no nodes, no drawing, no input.
##
## Everything advances in fixed 1/60 s steps, and randomness comes from a
## RandomNumberGenerator seeded per level. So the same inputs always give the
## same game, which lets the tests and the autopilot run it at full speed
## without a window and see exactly what a player would see.
##
## Field coordinates: 480 x 720, portrait, y grows downward. Enemy squadrons
## fly in at the top, the players fly along the bottom band. Ground things
## (SAM sites, photo targets) are given in the same screen coordinates and
## slide down the screen as the ground scrolls past.
##
## Each mission turns on a few optional rules from its level data:
##   goal        "land" (clear the waves, then land), "clear", or "survive"
##               (last `duration` seconds; maybe photograph targets)
##   fuel_rate   the tank drains (0 = no fuel worries)
##   wind        {base, gust, period, turb}: pushes jets sideways
##   icing       jets slide: they take a moment to change direction
##   flak        {every, radius, warn, dmg, spread}: ground guns burst near you
##   sams        {every, range, shots}: missile sites scroll past and fire up
##   photos      {count, need, every, start}: overfly targets to photograph them
##   sanctuary_x enemies left of this line can't be engaged
##   bvr_line    enemies never come lower than this; it's a missile duel
##   enemy_guns  false = enemies fire missiles only
##   claims      count kills the way press offices do
##   combo       {window, need, bonus}: "five in a minute"
##   tea         being shot down means steering your parachute home
##   switch      {wave, jet_id, enemy_jet, banner}: change sides mid-mission
##   disguise    each wave you look like a slow bomber: enemies close in without
##               firing until you shoot (then a few seconds of double points)
##   roe         weapons hold until the enemy fires first; 3 violations = court martial
##   squadron flags: "from": "behind" (climbs up from below and shoots forward),
##               "awacs" (a radar plane), "cloaked" (stealthy while any AWACS
##               lives: can't be hit or locked, still shoots), "phantom" (an ace
##               that blinks in and out of existence)

const Jets := preload("res://scripts/jets.gd")

const W := 480.0
const H := 720.0
const DT := 1.0 / 60.0

const PLAYER_SPEED := 230.0
const PLAYER_ZONE_TOP := 600.0      # players can climb this high...
const PLAYER_ZONE_BOTTOM := 690.0   # ...and sink this low
const PLAYER_Y := 660.0             # where jets spawn and normally fly
const DAMAGE_SLOW := 0.35           # a wrecked jet handles this much worse
const GROUND_PX := 95.0             # how fast the ground slides down the screen at cruise

# Cannons: fast, explosive rounds. Both sides use them.
const SHOT_SPEED := 950.0
const BOMB_SPEED := 330.0           # enemy rounds
const BOMB_R := 3.0
const BURST_GAP := 0.09
const MAX_AIM := 0.32               # enemies can angle their guns this far off straight down
const HIT_FLASH := 0.1              # brief immunity after a hit, so one burst isn't instant death

const RANK_HP := {"A": 2, "B": 1, "C": 0}   # extra armor for veteran (A) and B squadrons
const POINTS := {"A": 150, "B": 80, "C": 50}
const BOSS_POINTS := 3000
const MARGIN := 22.0
const OVERRUN_Y := 560.0            # an enemy reaching this line means you lose
const CELL := 6.0                   # cloud cover is a grid of 6px cells
const CLOUD_HP := 3
const INVULN := 2.0
const RESPAWN := 1.2
const WAVE_DELAY := 1.5
const STRIP_HALF := Vector2(46, 70) # the landing strip
const STRIP_SPEED := 70.0
const RESCUE_RADIUS := 26.0
const ENTRY_DIST := 420.0           # squadrons start this far above their slots...
const ENTRY_TIME := 1.3             # ...and brake into place over this long

# Missiles: limited, lock-on, one hit kills (bosses just take a big hit).
const MISSILE_SPEED0 := 160.0
const MISSILE_ACCEL := 1100.0
const MISSILE_MAX := 760.0
const MISSILE_TURN := 5.5
const MISSILE_LIFE := 3.0
const MISSILE_HIT := 16.0
const BOSS_MISSILE_DMG := 15

# Enemy missiles: a warned lock first, then a launch.
const ENEMY_LOCK_TIME := 1.1
const EMISSILE_SPEED0 := 120.0
const EMISSILE_ACCEL := 520.0
const EMISSILE_MAX := 430.0
const EMISSILE_TURN := 2.4
const EMISSILE_LIFE := 4.0
const EMISSILE_DAMAGE := 6
const FLARE_LIFE := 2.4
const FLARE_RANGE := 280.0          # missiles this close to their target fall for a flare

# Afterburner heat (jets with a "boost").
const HEAT_UP := 0.32               # per second while boosting
const HEAT_DOWN := 0.2
const OVERHEAT_TIME := 2.5

const PHOTO_RADIUS := Vector2(34, 28)
const AMBUSH_TIME := 3.0            # double points after dropping the disguise
const LURE_SPEED := 30.0            # how fast fooled squadrons close in (px/s)
const LURE_MAX := 230.0
const REAR_CLIMB := 120.0           # px/s attackers from behind climb past us
const BRAKE_BONUS := 190.0          # ...plus this much while we pull back (they overshoot)
const ROE_LIMIT := 3
const SPECIAL_POINTS := {"awacs": 1000, "phantom": 1500}

## Squadron shapes, as offsets from the leader. They face down the screen,
## so the leader is at the front (lowest) and the others trail behind (up).
const SHAPES := {
	"solo": [Vector2(0, 0)],
	"pair": [Vector2(-16, 0), Vector2(16, -18)],
	"vic3": [Vector2(0, 0), Vector2(-30, -24), Vector2(30, -24)],
	"vic5": [Vector2(0, 0), Vector2(-30, -24), Vector2(30, -24), Vector2(-60, -48), Vector2(60, -48)],
	"line3": [Vector2(-44, 0), Vector2(0, 0), Vector2(44, 0)],
	"line4": [Vector2(-66, 0), Vector2(-22, 0), Vector2(22, 0), Vector2(66, 0)],
	"echelon4": [Vector2(-45, 33), Vector2(-15, 11), Vector2(15, -11), Vector2(45, -33)],
	"echelon4l": [Vector2(45, 33), Vector2(15, 11), Vector2(-15, -11), Vector2(-45, -33)],
	"box4": [Vector2(-22, 0), Vector2(22, 0), Vector2(-22, -36), Vector2(22, -36)],
	"finger4": [Vector2(0, 0), Vector2(-32, -20), Vector2(34, -14), Vector2(64, -30)],
}

var level: Dictionary
var rng := RandomNumberGenerator.new()
var frame := 0
var elapsed := 0.0           # seconds of play
var jet: Dictionary          # the players' jet type, from jets.gd
var enemy_jet_id := "fishbowl"
var players: Array = []      # see _new_player()
var groups: Array = []       # squadrons of the current wave, see _start_wave()
var enemies: Array = []      # {id, group, off, kind, hp, max_hp, half, boss, missiles, pos}
var shots: Array = []        # player rounds {pos, owner}
var missiles: Array = []     # ours: {id, pos, vel, target (enemy id), owner, t}
var enemy_missiles: Array = []   # theirs: {id, pos, vel, target (player), decoy, t, from_ground}
var flares: Array = []       # {id, pos, vel, t}
var enemy_locks: Array = []  # warned locks: {shooter (enemy id) or site (site id), target, t}
var bombs: Array = []        # enemy rounds {pos, vel}
var flak: Array = []         # pending flak bursts {id, pos, t (seconds until it bursts)}
var sites: Array = []        # SAM sites on the ground {id, pos, shots, cd}
var targets: Array = []      # photo targets on the ground {id, pos, done, kind}
var clouds := {}             # Vector2i cell -> hit points left
var wave := -1
var next_id := 0             # every object gets an id so the 3D view can track it
var wave_delay := 0.0
var fuel := 100.0
var lives := 3               # spare jets, shared by both players
var score := 0
var kills := 0
var claims := 0              # what the press office announces
var enemy_claims := 0        # what the other side's press office announces
var photos := 0
var throttle := 0.0          # -1..1, from the pilots' stick (forward = faster)
var ground_speed := GROUND_PX
var ground_scroll := 0.0     # px the ground has moved
var phase := "fight"         # fight -> approach (land on the strip)
var strip := Vector2(W / 2, -STRIP_HALF.y)
var result := ""             # "" while playing, then "win" or "lose"
var reason := ""             # landed, cleared, survived, flameout, overrun, shot_down, photos
var _kill_times: Array = []
var _combo_done := -999.0
var _flak_t := 0.0
var _site_t := 0.0
var _target_t := 0.0
var _targets_made := 0
var disguised := false       # disguise missions: still looking like a bomber
var ambush_t := 0.0
var weapons_free := true     # ROE missions: false until the enemy fires first
var roe_violations := 0
var _roe_cool := 0.0
var chain_up := false        # an AWACS is alive, so cloaked squadrons are hidden
## Things that happened this step, for sound and effects. The game drains it.
var events: Array = []


func _init(level_data: Dictionary, player_count := 1) -> void:
	level = level_data
	jet = Jets.get_jet(String(level.get("jet_id", "foxbrat")))
	enemy_jet_id = String(level.get("enemy_jet", "fishbowl"))
	rng.seed = int(level.get("seed", 1))
	fuel = float(level.get("fuel", 100.0))
	lives = int(level.get("lives", 3))
	players = [_new_player(W * 0.5), _new_player(W * 0.5)]
	players[0].active = true
	players[0].alive = true
	if player_count >= 2:
		join(1)
	for c in level.get("clouds", []):
		_add_cloud(c)
	if level.has("photos"):
		_target_t = float(level.photos.get("every", 9.0)) - float(level.photos.get("start", 3.0))
	if not level.waves.is_empty():
		_start_wave(0)


func _new_player(x: float) -> Dictionary:
	return {
		"active": false, "alive": false, "out": false,
		"pos": Vector2(x, PLAYER_Y), "vel": Vector2.ZERO, "cooldown": 0.0, "invuln": 0.0, "barrel": 1.0,
		"hp": armor(), "missiles": int(jet.missiles), "flare_cd": 0.0, "locks": [], "lock_t": 0.0,
		"heat": 0.0, "overheat": 0.0, "boosting": false,
		"respawn": 0.0, "has_chute": false, "chute": Vector2.ZERO, "chute_vel": 0.0,
	}


func armor() -> int:
	return int(level.get("armor", jet.armor))


## 0 = pristine, 1 = about to fall apart.
func damage(p: Dictionary) -> float:
	return 1.0 - clampf(float(p.hp) / armor(), 0.0, 1.0)


func goal() -> String:
	return String(level.get("goal", "land"))


func time_left() -> float:
	return maxf(0.0, float(level.get("duration", 0.0)) - elapsed)


## Player 2 drops in. Solo play never needs this.
func join(i: int) -> void:
	var p: Dictionary = players[i]
	if p.active:
		return
	p.active = true
	p.alive = true
	p.hp = armor()
	p.invuln = INVULN
	var mate: Dictionary = players[1 - i]
	var mate_pos: Vector2 = mate.pos
	p.pos = Vector2(W * 0.7 if mate_pos.x < W / 2 else W * 0.3, PLAYER_Y)
	events.append({"e": "join", "i": i, "pos": p.pos})


func active_count() -> int:
	var n := 0
	for p in players:
		if p.active:
			n += 1
	return n


## inputs: one {move: Vector2 (-1..1), fire, missile, flare: bool} per player.
func step(inputs: Array) -> void:
	if result != "":
		return
	frame += 1
	elapsed += DT
	if goal() == "survive" and frame % 60 == 0:
		score += 25   # every second still flying counts
	_update_throttle(inputs)
	for i in 2:
		if players[i].active:
			_update_player(i, inputs[i] if i < inputs.size() else {})
	if phase == "fight":
		_update_squadrons()
	_update_shots()
	_update_missiles()
	_update_flares()
	_update_enemy_missiles()
	_update_bombs()
	_update_chutes(inputs)
	if phase == "fight":
		_update_enemy_fire()
		_update_flak()
		_update_ground()
		_update_waves()
	else:
		_update_landing()
	_update_fuel()
	_check_lost()


# --- the world moving past ---------------------------------------------------

## Pushing forward speeds the jets up: the ground slides past faster. Pulling
## back slows them. (Jets never fly backwards; see scene3d.gd.)
func _update_throttle(inputs: Array) -> void:
	var sum := 0.0
	var n := 0
	for i in 2:
		var p: Dictionary = players[i]
		if p.active and p.alive and i < inputs.size():
			var mv: Vector2 = inputs[i].get("move", Vector2.ZERO)
			sum += clampf(-mv.y, -1.0, 1.0)
			n += 1
	var target := sum / n if n > 0 else 0.0
	throttle = lerpf(throttle, target, 1.0 - exp(-4.0 * DT))
	if phase == "approach":
		ground_speed = STRIP_SPEED if strip.y < PLAYER_Y else 0.0
	else:
		ground_speed = GROUND_PX * (1.0 + 0.7 * throttle)
	ground_scroll += ground_speed * DT


## Wind pushing jets sideways: a steady part, slow gusts and quick turbulence.
func wind_x() -> float:
	if not level.has("wind"):
		return 0.0
	var w: Dictionary = level.wind
	var t := elapsed
	return float(w.get("base", 0.0)) + float(w.get("gust", 0.0)) * sin(TAU * t / float(w.get("period", 6.0))) \
		+ float(w.get("turb", 0.0)) * 0.5 * (sin(t * 7.3) + sin(t * 11.9 + 1.7))


func turbulence_y() -> float:
	if not level.has("wind"):
		return 0.0
	return float(level.wind.get("turb", 0.0)) * 0.6 * sin(elapsed * 9.1 + 0.4) * sin(elapsed * 3.7)


# --- players -----------------------------------------------------------------

func _update_player(i: int, input: Dictionary) -> void:
	var p: Dictionary = players[i]
	if not p.alive:
		if p.respawn > 0.0 and not p.out:
			p.respawn -= DT
			if p.respawn <= 0.0:
				p.alive = true
				p.hp = armor()
				p.invuln = INVULN
				p.vel = Vector2.ZERO
				p.pos = Vector2(W * (0.5 if active_count() == 1 else 0.3 + 0.4 * i), PLAYER_Y)
				events.append({"e": "respawn", "i": i, "pos": p.pos})
		return
	var move: Vector2 = input.get("move", Vector2.ZERO)
	move = move.limit_length(1.0)
	# Afterburner (jets that have one): pushing forward hard heats the engine.
	var boost: float = jet.boost
	p.boosting = false
	if boost > 0.0:
		p.overheat = maxf(0.0, p.overheat - DT)
		if move.y < -0.5 and p.overheat <= 0.0:
			p.boosting = true
			p.heat = minf(1.0, p.heat + HEAT_UP * DT)
			if p.heat >= 1.0:
				p.overheat = OVERHEAT_TIME
				events.append({"e": "overheat", "i": i, "pos": p.pos})
		else:
			p.heat = maxf(0.0, p.heat - HEAT_DOWN * DT)
	move.x *= float(jet.agility)
	# A damaged (or overheated) jet is sluggish and won't hold a straight line.
	var dmg := damage(p)
	var slow := (1.0 - DAMAGE_SLOW * dmg) * (0.6 if p.overheat > 0.0 else 1.0)
	var want: Vector2 = move * PLAYER_SPEED * slow
	if level.get("icing", false):
		# Iced up: the jet answers the stick slowly and keeps sliding.
		p.vel = Vector2(p.vel).lerp(want, 1.0 - exp(-2.2 * DT))
	else:
		p.vel = want
	var pos: Vector2 = p.pos + Vector2(p.vel) * DT
	pos.x += sin(frame * 0.11 + i * 2.0) * dmg * dmg * 0.9
	pos.x += wind_x() * DT
	pos.y += turbulence_y() * DT
	var left := 16.0
	if level.has("sanctuary_x"):
		left = float(level.sanctuary_x) + 18.0   # we may not cross the river
	pos.x = clampf(pos.x, left, W - 16.0)
	pos.y = clampf(pos.y, PLAYER_ZONE_TOP, PLAYER_ZONE_BOTTOM)
	p.pos = pos
	p.cooldown = maxf(0.0, p.cooldown - DT)
	p.invuln = maxf(0.0, p.invuln - DT)
	var gun: float = jet.gun if level.get("player_guns", true) else 0.0
	var trigger: bool = input.get("fire", false) or (input.get("missile", false) and p.missiles > 0)
	if trigger and phase == "fight":
		_trigger_pulled(i)
	if gun > 0.0 and input.get("fire", false) and p.cooldown <= 0.0 and phase == "fight":
		# Twin cannons fire alternately from either side of the nose.
		p.barrel = -p.barrel
		var muzzle := pos + Vector2(4.0 * p.barrel, -18)
		shots.append({"pos": muzzle, "owner": i})
		p.cooldown = gun
		events.append({"e": "shoot", "i": i, "pos": muzzle})
	_update_locks(i, bool(input.get("missile", false)))
	p.flare_cd = maxf(0.0, p.flare_cd - DT)
	if input.get("flare", false) and p.flare_cd <= 0.0:
		_drop_flares(i)


## Pulling the trigger drops a disguise, and (under rules of engagement)
## counts as a violation if the enemy hasn't fired yet.
func _trigger_pulled(i: int) -> void:
	if disguised:
		disguised = false
		ambush_t = AMBUSH_TIME
		events.append({"e": "reveal", "i": i, "pos": players[i].pos})
	if level.get("roe", false) and not weapons_free and _roe_cool <= 0.0:
		roe_violations += 1
		_roe_cool = 1.5
		events.append({"e": "roe_violation", "i": i, "pos": players[i].pos, "n": roe_violations})
		if roe_violations >= ROE_LIMIT:
			_end("lose", "roe")


## Can this enemy be shot, locked or rammed by a missile right now?
func hittable(e: Dictionary) -> bool:
	if e.get("phantom", false) and e.get("ghost", false):
		return false
	if e.get("cloaked", false) and chain_up:
		return false
	return true


## Hold the missile button: the radar locks the nearest targets one at a
## time (up to the jet's lock limit). Let go: one missile per lock.
func _update_locks(i: int, held: bool) -> void:
	var p: Dictionary = players[i]
	var locks: Array = p.locks
	for id in locks.duplicate():
		var le := _find(id)
		if le.is_empty() or not hittable(le):
			locks.erase(id)
	if held and phase == "fight":
		if locks.size() < int(jet.locks) and locks.size() < p.missiles:
			p.lock_t += DT
			if p.lock_t >= float(jet.lock_time):
				var best: Dictionary = {}
				var best_d := INF
				var pos: Vector2 = p.pos
				for e in enemies:
					var ep: Vector2 = e.pos
					if ep.y < 30.0 or ep.y > pos.y or locks.has(e.id) or _targeted(e.id) or not engageable(ep) or not hittable(e):
						continue
					var d := pos.distance_to(ep)
					if d < best_d:
						best_d = d
						best = e
				if not best.is_empty():
					locks.append(best.id)
					p.lock_t = 0.0
					events.append({"e": "lock", "i": i, "id": best.id, "pos": best.pos})
		return
	p.lock_t = 0.0
	if locks.is_empty():
		return
	for k in locks.size():
		var spread := (k - (locks.size() - 1) / 2.0) * 0.5
		var from: Vector2 = p.pos + Vector2(10.0 * (1 if k % 2 == 0 else -1), 0)
		missiles.append({"id": next_id, "pos": from, "vel": Vector2(spread, -1).normalized() * MISSILE_SPEED0,
			"target": locks[k], "owner": i, "t": 0.0})
		next_id += 1
		p.missiles -= 1
		events.append({"e": "missile", "i": i, "pos": from, "id": locks[k]})
	locks.clear()


## May we shoot at something here? (Not across the sanctuary river.)
func engageable(pos: Vector2) -> bool:
	return not level.has("sanctuary_x") or pos.x > float(level.sanctuary_x)


func _targeted(id: int) -> bool:
	for m in missiles:
		if m.target == id:
			return true
	return false


func _damage_player(i: int, at: Vector2, amount := 1) -> void:
	var p: Dictionary = players[i]
	if not p.alive:
		return
	p.hp -= amount
	p.invuln = HIT_FLASH
	if level.get("claims", false):
		enemy_claims += amount
	events.append({"e": "player_damaged", "i": i, "pos": at, "hp": p.hp})
	if p.hp <= 0:
		_shoot_down(i)


func _shoot_down(i: int) -> void:
	var p: Dictionary = players[i]
	p.alive = false
	p.locks.clear()
	events.append({"e": "player_hit", "i": i, "pos": p.pos})
	var mate: Dictionary = players[1 - i]
	if (mate.active and mate.alive) or level.get("tea", false):
		# The pilot ejects. In co-op the wingman can fly through the chute to
		# get them back; on "tea" missions you steer it home yourself.
		p.has_chute = true
		p.chute = p.pos
		p.chute_vel = -110.0
	else:
		_lose_life(i)


func _lose_life(i: int) -> void:
	var p: Dictionary = players[i]
	if lives > 0:
		lives -= 1
		p.respawn = RESPAWN
	else:
		p.out = true


func _update_chutes(inputs: Array) -> void:
	var tea: bool = level.get("tea", false)
	for i in 2:
		var p: Dictionary = players[i]
		if not p.has_chute:
			continue
		p.chute_vel = minf(p.chute_vel + 70.0 * DT, 40.0 if tea else 32.0)
		var c: Vector2 = p.chute
		c.y += p.chute_vel * DT
		c.x += sin(frame * 0.05 + i) * 0.3 + wind_x() * DT * 0.5
		if tea and i < inputs.size():
			var mv: Vector2 = inputs[i].get("move", Vector2.ZERO)
			c.x = clampf(c.x + mv.x * 110.0 * DT, 10.0, W - 10.0)
		p.chute = c
		var mate: Dictionary = players[1 - i]
		var mate_pos: Vector2 = mate.pos
		if mate.alive and mate_pos.distance_to(c) < RESCUE_RADIUS:
			p.has_chute = false
			p.alive = true
			p.hp = maxi(3, armor() / 2)    # patched up, not good as new
			p.invuln = INVULN
			p.pos = Vector2(c.x, clampf(c.y, PLAYER_ZONE_TOP, PLAYER_ZONE_BOTTOM))
			score += 250
			events.append({"e": "rescue", "i": i, "pos": c})
		elif c.y > H - 30.0 and tea:
			p.has_chute = false
			var home_left: bool = String(level.get("home", "left")) == "left"
			if (c.x < W / 2) == home_left:
				events.append({"e": "home", "i": i, "pos": c})
			else:
				score += 500
				events.append({"e": "tea", "i": i, "pos": c})
			_lose_life(i)
		elif c.y > H + 20.0:
			p.has_chute = false
			_lose_life(i)


# --- flares ------------------------------------------------------------------

## A pair of burning flares, kicked out to either side and behind. Missiles
## already closing on this jet go after them instead. Unlimited, but the
## dispenser needs time to recharge between pairs.
func _drop_flares(i: int) -> void:
	var p: Dictionary = players[i]
	p.flare_cd = float(jet.flare_cd)
	var pos: Vector2 = p.pos
	var ids: Array = []
	for side in [-1.0, 1.0]:
		var dir := Vector2(side, 0.6).normalized()
		flares.append({"id": next_id, "pos": pos + Vector2(0, 10), "vel": dir * 150.0, "t": 0.0})
		ids.append(next_id)
		next_id += 1
	events.append({"e": "flares", "i": i, "pos": pos})
	for m in enemy_missiles:
		var mp: Vector2 = m.pos
		if m.target == i and m.decoy < 0 and mp.distance_to(pos) < FLARE_RANGE:
			m.decoy = ids[rng.randi_range(0, ids.size() - 1)]
			events.append({"e": "decoyed", "pos": mp})


func _update_flares() -> void:
	var keep: Array = []
	for f in flares:
		f.t += DT
		var v: Vector2 = f.vel
		v *= 0.96                      # air drag slows them...
		v.y += 60.0 * DT               # ...and we fly on, so they drop behind
		f.vel = v
		f.pos = Vector2(f.pos) + v * DT
		if f.t < FLARE_LIFE:
			keep.append(f)
	flares = keep


func _find_flare(id: int) -> Dictionary:
	for f in flares:
		if f.id == id:
			return f
	return {}


# --- our rounds and missiles -------------------------------------------------

func _update_shots() -> void:
	var keep: Array = []
	for s in shots:
		var from: Vector2 = s.pos
		var to := from + Vector2(0, -SHOT_SPEED * DT)
		s.pos = to
		if to.y < -10.0:
			continue
		if _hit_cloud(from, to):
			continue
		var hit := -1
		for k in enemies.size():
			var e: Dictionary = enemies[k]
			if not hittable(e):
				continue                # stealthy or a ghost: the round passes through
			var ep: Vector2 = e.pos
			var half: Vector2 = e.half
			if absf(ep.x - to.x) < half.x and to.y < ep.y + half.y and from.y > ep.y - half.y:
				hit = k
				break
		if hit < 0:
			keep.append(s)
			continue
		var e: Dictionary = enemies[hit]
		var ep: Vector2 = e.pos
		var half: Vector2 = e.half
		e.hp -= 1
		events.append({"e": "hit", "i": s.owner, "pos": Vector2(to.x, ep.y + half.y * 0.5), "id": e.id, "hp": e.hp})
		if e.hp <= 0:
			_kill(hit, int(s.owner))
	shots = keep


## Missiles accelerate, steer toward their target with a limited turn rate,
## and pick a new one if theirs is already gone. Any jet they touch dies.
func _update_missiles() -> void:
	var keep: Array = []
	for m in missiles:
		m.t += DT
		var vel: Vector2 = m.vel
		var pos: Vector2 = m.pos
		var target := _find(m.target)
		if not target.is_empty() and not hittable(target):
			target = {}
		if target.is_empty() and not enemies.is_empty():
			var best_d := INF
			for e in enemies:
				var d := pos.distance_to(e.pos)
				if d < best_d and engageable(e.pos) and hittable(e):
					best_d = d
					target = e
			if not target.is_empty():
				m.target = target.id
		var speed := minf(vel.length() + MISSILE_ACCEL * DT, MISSILE_MAX)
		if not target.is_empty():
			var want := (Vector2(target.pos) - pos).angle()
			var turn := clampf(angle_difference(vel.angle(), want), -MISSILE_TURN * DT, MISSILE_TURN * DT)
			vel = Vector2.from_angle(vel.angle() + turn)
		vel = vel.normalized() * speed
		pos += vel * DT
		m.vel = vel
		m.pos = pos
		if not engageable(pos):
			events.append({"e": "roe", "pos": pos})   # rules of engagement: self-destruct at the river
			continue
		var hit := -1
		for k in enemies.size():
			var e: Dictionary = enemies[k]
			if hittable(e) and pos.distance_to(e.pos) < MISSILE_HIT + Vector2(e.half).x * 0.5:
				hit = k
				break
		if hit >= 0:
			var e: Dictionary = enemies[hit]
			events.append({"e": "missile_hit", "i": m.owner, "pos": pos, "id": e.id})
			if (e.boss or e.get("awacs", false) or e.get("phantom", false)) and e.hp > BOSS_MISSILE_DMG:
				e.hp -= BOSS_MISSILE_DMG
				events.append({"e": "hit", "i": m.owner, "pos": pos, "id": e.id, "hp": e.hp})
			else:
				_kill(hit, int(m.owner))
			continue
		if m.t > MISSILE_LIFE or pos.y < -40.0 or pos.y > H + 40.0 or pos.x < -40.0 or pos.x > W + 40.0:
			continue
		keep.append(m)
	missiles = keep


func _kill(index: int, owner: int) -> void:
	var e: Dictionary = enemies[index]
	enemies.remove_at(index)
	kills += 1
	var pts: int = BOSS_POINTS if e.boss else int(POINTS.get(e.kind, 50))
	for k in SPECIAL_POINTS:
		if e.get(k, false):
			pts = SPECIAL_POINTS[k]
	if ambush_t > 0.0:
		pts *= 2
	score += pts
	if level.get("claims", false):
		# The press office rounds up. Generously.
		claims += 1 + rng.randi_range(0, 2) + (5 if e.boss else 0)
	events.append({"e": "kill", "i": owner, "pos": e.pos, "kind": e.kind, "id": e.id, "boss": e.boss})
	if level.has("combo"):
		var c: Dictionary = level.combo
		_kill_times.append(elapsed)
		while not _kill_times.is_empty() and elapsed - float(_kill_times[0]) > float(c.window):
			_kill_times.pop_front()
		if _kill_times.size() >= int(c.need) and elapsed - _combo_done > float(c.window):
			_combo_done = elapsed
			score += int(c.bonus)
			events.append({"e": "combo", "pos": e.pos})


# --- enemy fire --------------------------------------------------------------

func _update_bombs() -> void:
	var keep: Array = []
	for b in bombs:
		var from: Vector2 = b.pos
		var vel: Vector2 = b.vel
		var to := from + vel * DT
		b.pos = to
		if to.y > H + 10.0 or to.x < -10.0 or to.x > W + 10.0:
			continue
		if _hit_cloud(from, to):
			continue
		var hit := false
		for i in 2:
			var p: Dictionary = players[i]
			if not (p.active and p.alive) or p.invuln > 0.0:
				continue
			var pp: Vector2 = p.pos
			var half: Vector2 = jet.hitbox
			if absf(pp.x - to.x) < half.x + BOMB_R and absf(pp.y - to.y) < half.y + BOMB_R:
				_damage_player(i, to)
				hit = true
				break
		if not hit:
			keep.append(b)
	bombs = keep


## Enemy missiles chase a player (or the flare that fooled them). A jet on
## afterburner simply outruns them: they fall back down the screen.
func _update_enemy_missiles() -> void:
	var keep: Array = []
	for m in enemy_missiles:
		m.t += DT
		var pos: Vector2 = m.pos
		var vel: Vector2 = m.vel
		var aim := Vector2.INF
		if m.decoy >= 0:
			var f := _find_flare(m.decoy)
			if f.is_empty():
				events.append({"e": "emissile_gone", "pos": pos, "id": m.id})
				continue
			aim = f.pos
		else:
			var p: Dictionary = players[m.target]
			if p.alive:
				aim = p.pos
		var speed := minf(vel.length() + EMISSILE_ACCEL * DT, EMISSILE_MAX)
		if aim != Vector2.INF:
			var turn := clampf(angle_difference(vel.angle(), (aim - pos).angle()), -EMISSILE_TURN * DT, EMISSILE_TURN * DT)
			vel = Vector2.from_angle(vel.angle() + turn)
		vel = vel.normalized() * speed
		pos += vel * DT
		var tp: Dictionary = players[m.target]
		if tp.boosting:
			pos.y += float(jet.boost) * DT
		m.pos = pos
		m.vel = vel
		if m.decoy >= 0 and pos.distance_to(aim) < 10.0:
			events.append({"e": "emissile_gone", "pos": pos, "id": m.id})
			continue
		var hit := -1
		for i in 2:
			var p: Dictionary = players[i]
			# A missile chasing a flare is fused for the flare, not the jet.
			if m.decoy < 0 and p.active and p.alive and p.invuln <= HIT_FLASH and pos.distance_to(p.pos) < 16.0:
				hit = i
				break
		if hit >= 0:
			events.append({"e": "emissile_hit", "i": hit, "pos": pos, "id": m.id})
			players[hit].invuln = 0.0
			_damage_player(hit, pos, EMISSILE_DAMAGE)
			continue
		if m.t > EMISSILE_LIFE or pos.y > H + 40.0 or pos.y < -60.0 or pos.x < -40.0 or pos.x > W + 40.0:
			events.append({"e": "emissile_gone", "pos": pos, "id": m.id})
			continue
		keep.append(m)
	enemy_missiles = keep


## Each squadron fires bursts on its own clock, from whichever of its jets has
## the best line on a player. Guns can angle a little toward the target.
func _update_enemy_fire() -> void:
	var cap := int(level.get("max_bombs", 28))
	_update_enemy_locks()
	var guns: bool = level.get("enemy_guns", true)
	if disguised:
		return                      # they think we're a lumbering bomber: no need to shoot yet
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		if not group_formed(g):
			continue
		_maybe_lock(gi, g)
		if not guns:
			continue
		if g.burst > 0:
			g.burst_t -= DT
			if g.burst_t <= 0.0:
				var shooter := _find(g.shooter)
				if shooter.is_empty() or bombs.size() >= cap:
					g.burst = 0
				else:
					_fire_round(shooter)
					g.burst -= 1
					g.burst_t = BURST_GAP
			continue
		g.fire_t += DT
		if g.fire_t < float(g.fire):
			continue
		g.fire_t = rng.randf_range(-0.4, 0.2) * float(g.fire)
		var target := _random_target()
		if target == Vector2.INF:
			continue
		var best: Dictionary = {}
		for e in enemies:
			if e.group == gi and (best.is_empty() or absf(e.pos.x - target.x) < absf(best.pos.x - target.x)):
				best = e
		if best.is_empty():
			continue
		g.shooter = best.id
		g.burst = int(g.jet.burst)
		g.burst_t = 0.0


## Every so often a squadron picks a jet with a missile left and starts a
## lock on a player. The lock is announced (MISSILE LOCK) before launch.
func _maybe_lock(gi: int, g: Dictionary) -> void:
	if float(g.missile_every) <= 0.0:
		return
	g.missile_t += DT
	if g.missile_t < float(g.missile_every):
		return
	g.missile_t = rng.randf_range(-0.3, 0.1) * float(g.missile_every)
	var target := _random_player()
	if target < 0:
		return
	for e in enemies:
		if e.group == gi and int(e.missiles) > 0 and not _locking(e.id):
			e.missiles -= 1
			enemy_locks.append({"shooter": e.id, "target": target, "t": 0.0})
			events.append({"e": "enemy_lock", "i": target, "id": e.id, "pos": e.pos})
			return


func _random_player() -> int:
	var alive: Array = []
	for i in 2:
		if players[i].active and players[i].alive:
			alive.append(i)
	if alive.is_empty():
		return -1
	return alive[rng.randi_range(0, alive.size() - 1)]


func _locking(id: int) -> bool:
	for l in enemy_locks:
		if l.has("shooter") and l.shooter == id:
			return true
	return false


func _update_enemy_locks() -> void:
	var keep: Array = []
	for l in enemy_locks:
		l.t += DT
		var from := Vector2.INF
		if l.has("site"):
			var s := _find_site(l.site)
			if not s.is_empty():
				from = s.pos
		else:
			var e := _find(l.shooter)
			if not e.is_empty():
				from = Vector2(e.pos) + Vector2(0, 16)
		if from == Vector2.INF or not players[l.target].alive:
			continue   # shooter gone (or target gone) before launch
		if l.t < ENEMY_LOCK_TIME:
			keep.append(l)
			continue
		var ground: bool = l.has("site")
		var dir := Vector2(0, 1) if not ground else (Vector2(players[l.target].pos) - from).normalized()
		enemy_missiles.append({"id": next_id, "pos": from, "vel": dir * EMISSILE_SPEED0,
			"target": l.target, "decoy": -1, "t": 0.0, "from_ground": ground})
		_enemy_fired()
		events.append({"e": "enemy_missile", "i": l.target, "pos": from, "id": next_id, "ground": ground})
		next_id += 1
	enemy_locks = keep


## Is a live missile coming for player i? (HUD + autopilot)
func threats_to(i: int) -> Array:
	var out: Array = []
	for m in enemy_missiles:
		if m.target == i and m.decoy < 0:
			out.append(m)
	return out


func _find(id: int) -> Dictionary:
	for e in enemies:
		if e.id == id:
			return e
	return {}


func _random_target() -> Vector2:
	var i := _random_player()
	return Vector2.INF if i < 0 else players[i].pos


func _fire_round(e: Dictionary) -> void:
	var from: Vector2 = e.pos + Vector2(0, 14)
	if e.has("guns"):
		var guns: Array = e.guns
		from = Vector2(e.pos) + Vector2(guns[rng.randi_range(0, guns.size() - 1)])
	var target := Vector2(from.x, H)
	var nearest := INF
	for p in players:
		if p.active and p.alive and absf(p.pos.x - from.x) < nearest:
			nearest = absf(p.pos.x - from.x)
			target = p.pos
	if e.get("rear", false):
		# Attackers from behind face up the screen and fire forward (up),
		# but only while we're still in front of them.
		from = Vector2(e.pos) + Vector2(0, -14)
		if target.y > from.y - 20.0:
			return
		var up_ang := clampf(atan2(target.x - from.x, from.y - target.y), -MAX_AIM, MAX_AIM)
		bombs.append({"pos": from, "vel": Vector2(sin(up_ang), -cos(up_ang)) * BOMB_SPEED})
	else:
		var ang := clampf(atan2(target.x - from.x, target.y - from.y), -MAX_AIM, MAX_AIM)
		bombs.append({"pos": from, "vel": Vector2(sin(ang), cos(ang)) * BOMB_SPEED})
	_enemy_fired()
	events.append({"e": "enemy_shoot", "pos": from, "id": e.id})


func _enemy_fired() -> void:
	if not weapons_free:
		weapons_free = true
		events.append({"e": "weapons_free"})


# --- ground: flak, SAM sites, photo targets ----------------------------------

## Flak: ground guns aim near a jet. The burst is marked a moment ahead (the
## gunners are good, not psychic), then explodes and hurts anything close.
func _update_flak() -> void:
	if not level.has("flak"):
		return
	var f: Dictionary = level.flak
	_flak_t += DT
	if _flak_t >= float(f.every):
		_flak_t = rng.randf_range(-0.3, 0.2) * float(f.every)
		var i := _random_player()
		if i >= 0:
			var p: Dictionary = players[i]
			var spread: float = f.get("spread", 60.0)
			var at: Vector2 = Vector2(p.pos) + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.4, spread * 0.3))
			flak.append({"id": next_id, "pos": at, "t": float(f.warn)})
			next_id += 1
	var keep: Array = []
	for b in flak:
		b.t -= DT
		if b.t > 0.0:
			keep.append(b)
			continue
		var bp: Vector2 = b.pos
		events.append({"e": "flak", "pos": bp, "id": b.id})
		for i in 2:
			var p: Dictionary = players[i]
			if p.active and p.alive and p.invuln <= HIT_FLASH and bp.distance_to(p.pos) < float(f.radius):
				p.invuln = 0.0
				_damage_player(i, bp, int(f.dmg))
	flak = keep


func _update_ground() -> void:
	var dy := ground_speed * DT
	# SAM sites roll past below; each fires (after a warned lock) at a jet in range.
	if level.has("sams"):
		var cfg: Dictionary = level.sams
		_site_t += DT
		if _site_t >= float(cfg.every):
			_site_t = rng.randf_range(-0.4, 0.2) * float(cfg.every)
			sites.append({"id": next_id, "pos": Vector2(rng.randf_range(50.0, W - 50.0), -30.0),
				"shots": int(cfg.get("shots", 1)), "cd": rng.randf_range(0.0, 1.0)})
			next_id += 1
	var keep: Array = []
	for s in sites:
		s.pos = Vector2(s.pos) + Vector2(0, dy)
		var sp: Vector2 = s.pos
		s.cd -= DT
		if s.shots > 0 and s.cd <= 0.0 and sp.y > 60.0 and sp.y < 560.0:
			var i := _random_player()
			if i >= 0 and sp.distance_to(players[i].pos) < float(level.sams.get("range", 420.0)):
				s.shots -= 1
				s.cd = 2.2
				enemy_locks.append({"site": s.id, "target": i, "t": 0.0})
				events.append({"e": "enemy_lock", "i": i, "id": s.id, "pos": sp, "ground": true})
		if sp.y < H + 40.0:
			keep.append(s)
	sites = keep
	# Photo targets: fly over one to photograph it.
	if level.has("photos"):
		var cfg: Dictionary = level.photos
		_target_t += DT
		if _targets_made < int(cfg.count) and _target_t >= float(cfg.every):
			_target_t = 0.0
			_targets_made += 1
			var kinds := ["factory", "airfield", "launch_pad", "radar"]
			targets.append({"id": next_id, "pos": Vector2(rng.randf_range(70.0, W - 70.0), -40.0), "done": false,
				"kind": kinds[rng.randi_range(0, kinds.size() - 1)]})
			next_id += 1
	var tkeep: Array = []
	for t in targets:
		t.pos = Vector2(t.pos) + Vector2(0, dy)
		var tp: Vector2 = t.pos
		if not t.done:
			for i in 2:
				var p: Dictionary = players[i]
				if p.active and p.alive and absf(Vector2(p.pos).x - tp.x) < PHOTO_RADIUS.x and absf(Vector2(p.pos).y - tp.y) < PHOTO_RADIUS.y:
					t.done = true
					photos += 1
					score += 400
					events.append({"e": "photo", "i": i, "pos": tp, "id": t.id})
					break
		if tp.y < H + 40.0:
			tkeep.append(t)
		elif not t.done:
			events.append({"e": "photo_missed", "pos": tp})
	targets = tkeep


func _find_site(id: int) -> Dictionary:
	for s in sites:
		if s.id == id:
			return s
	return {}


# --- clouds (cover that both sides' rounds chew through) ---------------------

func _add_cloud(center: Vector2) -> void:
	for cx in range(-6, 7):
		for cy in range(-3, 4):
			if pow(cx / 6.5, 2) + pow(cy / 3.0, 2) <= 1.0:
				var p := center + Vector2(cx, cy) * CELL
				clouds[cell_of(p)] = CLOUD_HP


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


## Rounds move many cells per step, so sample the whole path.
func _hit_cloud(from: Vector2, to: Vector2) -> bool:
	if clouds.is_empty():
		return false
	var n := int(ceil(from.distance_to(to) / 3.0))
	for k in n + 1:
		var c := cell_of(from.lerp(to, float(k) / maxf(1.0, n)))
		if clouds.has(c):
			clouds[c] -= 1
			if clouds[c] <= 0:
				clouds.erase(c)
			events.append({"e": "puff", "pos": (Vector2(c) + Vector2(0.5, 0.5)) * CELL})
			return true
	return false


## Is there cloud cover in this column between two heights? (for the autopilot)
func cloud_between(x: float, y_low: float, y_high: float) -> bool:
	if clouds.is_empty():
		return false
	var y := y_low
	while y > y_high:
		if clouds.has(cell_of(Vector2(x, y))):
			return true
		y -= CELL
	return false


# --- squadrons ---------------------------------------------------------------

## A wave is a list of squadrons. Each one: shape, kind (A/B/C), jet, x and y
## of its slot, a movement ("weave", "figure8" or "hold"), amp/freq of that
## movement, descent (px/s it creeps down), delay before it arrives, and fire
## (seconds between bursts). "boss": true makes a single big jet.
func _start_wave(n: int) -> void:
	wave = n
	groups.clear()
	enemies.clear()
	if level.has("switch") and int(level.switch.wave) == n:
		_switch_sides()
	elif level.get("rearm_each_wave", false) and n > 0:
		for p in players:
			p.missiles = int(jet.missiles)
		events.append({"e": "rearm"})
	disguised = level.get("disguise", false)
	weapons_free = not level.get("roe", false)
	var list: Array = level.waves[n]
	for g in list.size():
		var spec: Dictionary = list[g]
		var kind: String = spec.get("kind", "C")
		var jid := String(spec.get("jet", enemy_jet_id))
		var ej := Jets.get_jet(jid)
		var boss: bool = spec.get("boss", false)
		groups.append({
			"jet": ej,
			"x": float(spec.get("x", W / 2)), "y": float(spec.get("y", 120.0)),
			"move": String(spec.get("move", "weave")), "amp": float(spec.get("amp", 40.0)),
			"freq": float(spec.get("freq", 0.8)), "phase": float(spec.get("phase", 0.0)),
			"descent": float(spec.get("descent", 0.0 if level.has("bvr_line") else 2.5)), "delay": float(spec.get("delay", 0.0)),
			"fire": float(spec.get("fire", ej.fire)), "fire_t": 0.0, "t": 0.0,
			"burst": 0, "burst_t": 0.0, "shooter": -1,
			"missile_every": float(spec.get("missile_every", level.get("missile_every", ej.missile_every))),
			# Missile clocks start part-charged so the first lock comes soon after arrival.
			"missile_t": float(spec.get("missile_t", float(spec.get("missile_every", level.get("missile_every", ej.missile_every))) * 0.55)),
			"rear": String(spec.get("from", "front")) == "behind", "ry": H + 140.0 + float(spec.get("delay", 0.0)) * 120.0,
			"climb": float(spec.get("climb", REAR_CLIMB)), "lure": 0.0,
		})
		for off in SHAPES[spec.get("shape", "solo" if boss else "vic3")]:
			var hp := Jets.enemy_hp(ej) + int(RANK_HP.get(kind, 0))
			var e := {"id": next_id, "group": g, "off": off, "kind": kind, "hp": hp, "max_hp": hp,
				"half": ej.hitbox, "boss": boss, "jet": jid,
				"missiles": int(level.get("enemy_missiles", 1)), "pos": Vector2.ZERO}
			if boss:
				e.guns = [Vector2(-46, 6), Vector2(46, 6), Vector2(0, -36), Vector2(0, 40)]
			for flag in ["awacs", "cloaked", "phantom"]:
				if spec.get(flag, false):
					e[flag] = true
			if spec.get("from", "") == "behind":
				e.rear = true
			if e.get("phantom", false):
				e.ghost = false
				e.phase_t = 2.4
				e.jump = Vector2.ZERO
				e.hp = 14
				e.max_hp = 14
			e.pos = enemy_pos_in(e, 0.0)
			enemies.append(e)
			next_id += 1
	events.append({"e": "wave", "n": n})


## Mid-mission defection (the contract was renegotiated).
func _switch_sides() -> void:
	var sw: Dictionary = level.switch
	var old_armor := armor()
	jet = Jets.get_jet(String(sw.jet_id))
	enemy_jet_id = String(sw.enemy_jet)
	for p in players:
		p.hp = int(ceil(float(p.hp) / old_armor * armor()))
		p.missiles = int(jet.missiles)
		p.locks.clear()
	events.append({"e": "switch", "text": String(sw.get("banner", "Ace switches sides."))})


## Where a squadron's leader slot is, `t` seconds into its life.
## First it dives in from above and brakes (ease-out), then it flies its path.
func group_anchor(g: Dictionary, t: float) -> Vector2:
	var local := t - float(g.delay)
	var u := clampf(local / ENTRY_TIME, 0.0, 1.0)
	var entry := ENTRY_DIST * pow(1.0 - u, 3.0)
	var flown := maxf(0.0, local - ENTRY_TIME)
	var x: float = g.x
	var y: float = g.y + float(g.descent) * flown - entry + float(g.get("lure", 0.0))
	if g.get("rear", false):
		# Climbing up from behind: its height is integrated each step (it
		# depends on our throttle), so forecast it at its current climb rate.
		y = float(g.ry) - float(g.get("rate", g.climb)) * (t - float(g.t))
	var a: float = g.freq * flown + float(g.phase)
	match String(g.move):
		"weave":
			x += float(g.amp) * sin(a)
		"figure8":
			x += float(g.amp) * sin(a)
			y += float(g.amp) * 0.22 * sin(2.0 * a)
	return Vector2(x, y)


## Exact forecast of where an enemy will be `ahead` seconds from now.
func enemy_pos_in(e: Dictionary, ahead: float) -> Vector2:
	var g: Dictionary = groups[e.group]
	var off: Vector2 = e.off
	if e.get("rear", false):
		off.y = -off.y          # formation trails below the leader when climbing
	var p := group_anchor(g, float(g.t) + ahead) + off + Vector2(e.get("jump", Vector2.ZERO))
	if level.has("bvr_line"):
		p.y = minf(p.y, float(level.bvr_line) - 20.0)
	return Vector2(clampf(p.x, MARGIN, W - MARGIN), p.y)


func group_formed(g: Dictionary) -> bool:
	return float(g.t) >= float(g.delay) + ENTRY_TIME


func _update_squadrons() -> void:
	ambush_t = maxf(0.0, ambush_t - DT)
	_roe_cool = maxf(0.0, _roe_cool - DT)
	for g in groups:
		g.t += DT
		if disguised:
			# Fooled: they close in on the "bomber" for an easy kill.
			g.lure = minf(float(g.lure) + LURE_SPEED * DT, LURE_MAX)
		if g.rear:
			# Pulling back (air brake) makes them overshoot faster.
			g.rate = float(g.climb) + maxf(0.0, -throttle) * BRAKE_BONUS
			g.ry = float(g.ry) - float(g.rate) * DT
			if float(g.ry) < -140.0:
				g.ry = H + 140.0      # missed us: loop round for another pass
	if disguised:
		var low := 0.0
		for e in enemies:
			low = maxf(low, Vector2(e.pos).y)
		# Too close for too long: they notice the "bomber" has guns.
		for g in groups:
			if float(g.lure) >= LURE_MAX and low > 430.0:
				disguised = false
				events.append({"e": "spotted"})
				break
	# The phantom ace: solid for a while, then fades out and reappears elsewhere.
	for e in enemies:
		if e.get("phantom", false):
			e.phase_t -= DT
			if e.phase_t <= 0.0:
				e.ghost = not e.ghost
				e.phase_t = 1.6 if e.ghost else 2.6
				if not e.ghost:
					e.jump = Vector2(rng.randf_range(-130.0, 130.0), rng.randf_range(-30.0, 90.0))
				events.append({"e": "phantom", "ghost": e.ghost, "pos": e.pos, "id": e.id})
	for e in enemies:
		e.pos = enemy_pos_in(e, 0.0)
	# Kill chain: while any AWACS flies, cloaked squadrons stay hidden.
	var up := false
	for e in enemies:
		if e.get("awacs", false):
			up = true
	if chain_up and not up:
		events.append({"e": "unveil"})
	chain_up = up


func _update_waves() -> void:
	if level.waves.is_empty() or not enemies.is_empty():
		return
	if wave_delay <= 0.0:
		wave_delay = WAVE_DELAY
		events.append({"e": "wave_clear", "n": wave})
	wave_delay -= DT
	if wave_delay > 0.0:
		return
	wave_delay = 0.0
	if wave + 1 < level.waves.size():
		_start_wave(wave + 1)
	elif goal() == "land":
		phase = "approach"
		clouds.clear()   # the clouds part as the coast comes into view
		events.append({"e": "approach"})
	elif goal() == "clear":
		_end("win", "cleared")


# --- landing, fuel, defeat ---------------------------------------------------

func _update_landing() -> void:
	if strip.y < PLAYER_Y:
		strip.y = minf(PLAYER_Y, strip.y + STRIP_SPEED * DT)
		return
	var any_alive := false
	for p in players:
		if p.active and p.alive:
			any_alive = true
			if not on_strip(p.pos):
				return
	if any_alive:
		score += int(fuel) * 20
		_end("win", "landed")


func on_strip(pos: Vector2) -> bool:
	return absf(pos.x - strip.x) < STRIP_HALF.x - 10.0 and absf(pos.y - strip.y) < STRIP_HALF.y


func _update_fuel() -> void:
	var rate: float = level.get("fuel_rate", 0.0)
	if rate <= 0.0:
		return
	fuel -= rate * DT
	if fuel <= 0.0:
		fuel = 0.0
		_end("lose", "flameout")


func _check_lost() -> void:
	if result != "":
		return
	if goal() == "survive" and elapsed >= float(level.get("duration", 60.0)):
		var need := int(level.photos.need) if level.has("photos") else 0
		if photos >= need:
			_end("win", "survived")
		else:
			_end("lose", "photos")
		return
	if goal() != "survive":
		for e in enemies:
			if not e.get("rear", false) and Vector2(e.pos).y + Vector2(e.half).y >= OVERRUN_Y:
				_end("lose", "overrun")
				return
	for p in players:
		if p.active and not p.out:
			return
	_end("lose", "shot_down")


func _end(r: String, why: String) -> void:
	result = r
	reason = why
	events.append({"e": r, "reason": why})
