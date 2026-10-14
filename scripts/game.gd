extends Node2D
## Runs Air Superiority Complex: reads input, steps the simulation, draws it,
## and shows the briefing and end cards. Game rules live in sim.gd; this
## script only feeds it input and draws the result.
##
## Controls (solo needs nothing special, co-op is opt-in):
##   Ace (P1):   WASD or Arrows to fly, Space for cannons, hold Left Shift
##               (or E) to lock missiles, release to fire. Gamepad 1.
##   Deuce (P2): press Enter (or A on gamepad 2) at any time to join.
##               After that, Arrows + Enter + Right Shift belong to Deuce.
##
## Dev flags (after --): --level=N (1-based), --players=2, --autopilot
## (the computer flies every active jet), --exit-on-end, --linger=S,
## --screenshot=path.png --wait=S, --portrait, --timeout=S.

const Sim := preload("res://scripts/sim.gd")
const Levels := preload("res://scripts/levels.gd")
const Autopilot := preload("res://scripts/autopilot.gd")
const Art := preload("res://scripts/art.gd")
const Scene3D := preload("res://scripts/scene3d.gd")
const Jets := preload("res://scripts/jets.gd")
const Sound := preload("res://scripts/sound.gd")
const Menu := preload("res://scripts/menu.gd")
const Touch := preload("res://scripts/touch.gd")
const POST := preload("res://shaders/post.gdshader")

const NAMES := ["Ace", "Deuce"]
const SAVE_PATH := "user://air_superiority_complex.cfg"

var sim
var pilot
var view                      # scene3d.gd: the 3D battle drawn under the HUD
var level_index := 0
var state := "brief"          # brief -> play -> end
var opts := {}
var autopilot := false
var start_players := 1
var _t := 0.0
var _state_t := 0.0
var _fx: Array = []           # short-lived effects {kind, pos, t, life}
var _shake := 0.0
var _font: Font
var _fs := 1.0                # field scale (field px -> screen px)
var _fo := Vector2.ZERO       # field origin on screen
var unlocked := 1             # missions available in the briefing (saved)
var _weather: Array = []      # 2D rain / snow / dust particles over the field
var _flash := 0.0             # white screen flash (photos, lightning)
var sound                     # sound.gd
var _lock_beep := 0.0
var _splashes := 0
var menu                      # menu.gd: title, mission select, options, pause
var _attract := 0             # which mission the title-screen demo is flying
var _scroll_prev := 0.0
var _scroll_now := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	opts = _parse_args()
	_setup_input()
	autopilot = opts.has("autopilot")
	start_players = int(opts.get("players", "1"))
	level_index = clampi(int(opts.get("level", "1")) - 1, 0, Levels.LIST.size() - 1)
	if opts.has("portrait"):
		DisplayServer.window_set_size(Vector2i(540, 960))
	if opts.has("screenshot"):
		_take_screenshot_later(String(opts.screenshot), float(opts.get("wait", "1.5")))
	if opts.has("timeout"):
		get_tree().create_timer(float(opts.timeout)).timeout.connect(func(): _finish("timeout"))
	view = Scene3D.new()
	add_child(view)
	sound = Sound.new()
	add_child(sound)
	menu = Menu.new()
	add_child(menu)
	menu.chosen.connect(_on_menu)
	# On-screen controls: on by themselves on touch screens (phones, tablets).
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 2
	var touch := Touch.new()
	touch.game = self
	touch.enabled = DisplayServer.is_touchscreen_available() or opts.has("touch")
	touch_layer.add_child(touch)
	add_child(touch_layer)
	_load_progress()
	if opts.has("all-missions") or opts.has("level") or autopilot:
		unlocked = Levels.LIST.size()
	menu.unlocked = unlocked
	if opts.has("no-music") or autopilot and not opts.has("music"):
		sound.music_on = false
	# Film look (vignette, grain, lens fringing): a full-screen rectangle on a
	# CanvasLayer below the HUD, so it covers the 3D view but not the text.
	var layer := CanvasLayer.new()
	layer.layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = POST
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)
	# Dev runs (a chosen level, autopilot, screenshots) go straight to the
	# briefing; a normal launch starts at the title screen.
	if opts.has("menu"):
		_to_title(String(opts.menu))      # dev: --menu=title|select|options|controls
	elif opts.has("level") or autopilot or opts.has("screenshot"):
		load_level(level_index)
	else:
		_to_title()


## The title screen: menus over a live demo dogfight flown by the autopilot.
func _to_title(screen := "title") -> void:
	_attract = randi() % unlocked
	start_players = 1
	load_level(_attract, "menu")
	sound.silence_loops()
	sound.music("lounge")
	menu.unlocked = unlocked
	menu.open(screen, level_index if screen == "select" else 0)


func _on_menu(what: String, arg: int) -> void:
	match what:
		"blip":
			sound.play("ui", -16.0)
		"ok":
			sound.play("ui", -8.0, 0.0, 1.3)
		"mission":
			menu.close()
			start_players = 2 if menu.coop else 1
			load_level(arg)
		"resume":
			menu.close()
			_set_state("play")
		"restart":
			menu.close()
			start_players = sim.active_count()
			load_level(level_index)
		"title":
			_to_title()
		"to_select":
			if state != "menu":
				_to_title("select")
		"quit":
			get_tree().quit()
		"save", "settings":
			_save_progress()


func load_level(n: int, st := "brief") -> void:
	level_index = n
	sim = Sim.new(Levels.LIST[n], start_players)
	pilot = Autopilot.new()
	view.reset(sim)
	_scroll_prev = 0.0
	_scroll_now = 0.0
	_make_weather()
	_fx.clear()
	_set_state(st)


func _set_state(s: String) -> void:
	state = s
	_state_t = 0.0


# --- input -------------------------------------------------------------------

## Input actions are made in code so the controls live in one place. Godot's
## InputMap maps named actions to keys and gamepad buttons; the game then asks
## "is p1_fire pressed?" instead of checking keys.
func _setup_input() -> void:
	var keys := {
		"p1_left": [KEY_A], "p1_right": [KEY_D], "p1_up": [KEY_W], "p1_down": [KEY_S], "p1_fire": [KEY_SPACE],
		"p2_left": [KEY_LEFT], "p2_right": [KEY_RIGHT], "p2_up": [KEY_UP], "p2_down": [KEY_DOWN], "p2_fire": [KEY_ENTER, KEY_KP_ENTER],
		"p1_missile": [KEY_E], "p1_flare": [KEY_F, KEY_Q], "p2_flare": [KEY_SLASH], "music": [KEY_M],
		"retry": [KEY_R], "back": [KEY_ESCAPE, KEY_BACKSPACE],
	}
	for action in keys:
		InputMap.add_action(action, 0.3)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# Left Shift locks for Ace, Right Shift for Deuce.
	InputMap.add_action("p2_missile", 0.3)
	for pair in [["p1_missile", KEY_LOCATION_LEFT], ["p2_missile", KEY_LOCATION_RIGHT]]:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_SHIFT
		ev.location = pair[1]
		InputMap.action_add_event(pair[0], ev)
	# Gamepad 1 drives Ace, gamepad 2 drives Deuce.
	for i in 2:
		var pre := "p%d_" % (i + 1)
		_pad_axis(pre + "left", i, JOY_AXIS_LEFT_X, -1.0)
		_pad_axis(pre + "right", i, JOY_AXIS_LEFT_X, 1.0)
		_pad_axis(pre + "up", i, JOY_AXIS_LEFT_Y, -1.0)
		_pad_axis(pre + "down", i, JOY_AXIS_LEFT_Y, 1.0)
		for b in [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER]:
			var ev := InputEventJoypadButton.new()
			ev.device = i
			ev.button_index = b
			InputMap.action_add_event(pre + "fire", ev)
		var start := InputEventJoypadButton.new()
		start.device = i
		start.button_index = JOY_BUTTON_START
		InputMap.action_add_event("back", start)
		for b in [JOY_BUTTON_B, JOY_BUTTON_Y]:
			var ev := InputEventJoypadButton.new()
			ev.device = i
			ev.button_index = b
			InputMap.action_add_event(pre + "flare", ev)
		for b in [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER]:
			var ev := InputEventJoypadButton.new()
			ev.device = i
			ev.button_index = b
			InputMap.action_add_event(pre + "missile", ev)
		for pair in [["left", JOY_BUTTON_DPAD_LEFT], ["right", JOY_BUTTON_DPAD_RIGHT], ["up", JOY_BUTTON_DPAD_UP], ["down", JOY_BUTTON_DPAD_DOWN]]:
			var ev := InputEventJoypadButton.new()
			ev.device = i
			ev.button_index = pair[1]
			InputMap.action_add_event(pre + pair[0], ev)


func _pad_axis(action: String, device: int, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _human_input(i: int) -> Dictionary:
	var pre := "p%d_" % (i + 1)
	var move := Input.get_vector(pre + "left", pre + "right", pre + "up", pre + "down")
	var fire := Input.is_action_pressed(pre + "fire")
	var missile := Input.is_action_pressed(pre + "missile")
	var flare := Input.is_action_pressed(pre + "flare")
	if i == 0 and not sim.players[1].active:
		# Solo: the arrow keys (and Right Shift) fly Ace too, until Deuce joins.
		move = (move + Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")).limit_length(1.0)
		missile = missile or Input.is_action_pressed("p2_missile")
		flare = flare or Input.is_action_pressed("p2_flare")
	return {"move": move, "fire": fire, "missile": missile, "flare": flare}


# --- main loop ---------------------------------------------------------------

## _physics_process runs at a fixed 60 Hz (project setting), exactly one sim
## step per call, so game speed doesn't depend on the display's frame rate.
func _physics_process(delta: float) -> void:
	_t += delta
	_state_t += delta
	var back: bool = Input.is_action_just_pressed("back") and menu.screen == ""
	if Input.is_action_just_pressed("music"):
		sound.toggle_music()
	match state:
		"menu":
			# Title-screen demo: the autopilot flies, silently, forever.
			sim.step([pilot.decide(sim, 0), pilot.decide(sim, 1)])
			for e in sim.events:
				view.handle(e, sim)
			sim.events.clear()
			if sim.result != "":
				_attract = (_attract + 1) % unlocked
				load_level(_attract, "menu")
		"paused":
			pass
		"brief":
			if back:
				_to_title("select")
				return
			var go := Input.is_action_just_pressed("p1_fire") or Input.is_action_just_pressed("p2_fire")
			if Input.is_action_just_pressed("p2_fire") and not autopilot:
				sim.join(1)
			sound.music("lounge")
			sound.silence_loops()
			if go or (autopilot and _state_t > 1.2):
				_set_state("play")
				sound.play("ui", -6.0)
				sound.music("cold_war" if int(sim.level.chapter) == 0 else "subcontinent")
		"play":
			if back and not autopilot:
				# Esc pauses (and opens the pause menu); it never quits.
				_set_state("paused")
				sound.silence_loops()
				menu.open("pause")
				return
			if not sim.players[1].active and Input.is_action_just_pressed("p2_fire"):
				sim.join(1)
			var inputs: Array = []
			for i in 2:
				inputs.append(pilot.decide(sim, i) if autopilot else _human_input(i))
			sim.step(inputs)
			_consume_events()
			_update_audio(delta)
			if sim.result != "":
				_set_state("end")
				sound.silence_loops()
				sound.music("")
				sound.play("win" if sim.result == "win" else "lose", -2.0)
				if sim.result == "win" and level_index + 2 > unlocked:
					unlocked = mini(level_index + 2, Levels.LIST.size())
					menu.unlocked = unlocked
					_save_progress()
				if opts.has("exit-on-end"):
					print("RESULT %s level=%d players=%d reason=%s time=%.1f score=%d lives=%d" % [
						sim.result, level_index + 1, sim.active_count(), sim.reason, sim.frame / 60.0, sim.score, sim.lives])
					get_tree().create_timer(float(opts.get("linger", "0"))).timeout.connect(func(): get_tree().quit())
		"end":
			if back:
				_to_title("select")
				return
			if _state_t > 0.8 and (Input.is_action_just_pressed("p1_fire") or Input.is_action_just_pressed("retry")):
				var next := level_index
				if sim.result == "win" and level_index + 1 < Levels.LIST.size():
					next += 1
				start_players = sim.active_count()
				load_level(next)
	_update_fx(delta)
	_update_weather(delta)
	_scroll_prev = _scroll_now
	_scroll_now = sim.ground_scroll


## Drawing happens every display frame (120 Hz on some screens), while the
## rules step at 60 Hz. Blend the ground scroll between the last two steps so
## the landscape glides instead of stepping.
func _process(delta: float) -> void:
	var a := Engine.get_physics_interpolation_fraction()
	view.scroll_px = lerpf(_scroll_prev, _scroll_now, a)
	var shake := Vector2(sin(_t * 90.0), cos(_t * 77.0)) * 0.5 * _shake / 0.35
	view.sync(sim, delta, shake)
	queue_redraw()


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		unlocked = clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, Levels.LIST.size())
		menu.load_settings(cfg)


func _save_progress() -> void:
	if autopilot:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	for k in menu.settings:
		cfg.set_value("settings", k, menu.settings[k])
	cfg.save(SAVE_PATH)


func _finish(why: String) -> void:
	print("RESULT %s level=%d" % [why, level_index + 1])
	get_tree().quit()


## Engine, weather and warning loops follow the state of the fight.
func _update_audio(delta: float) -> void:
	var alive := false
	var boosting := false
	var warn := false
	var locking := false
	for i in 2:
		var p: Dictionary = sim.players[i]
		if p.active and p.alive:
			alive = true
			boosting = boosting or p.boosting
			locking = locking or float(p.lock_t) > 0.0
			if not sim.threats_to(i).is_empty():
				warn = true
	for l in sim.enemy_locks:
		if sim.players[l.target].alive:
			warn = true
	var thr: float = sim.throttle
	sound.loop("engine", (-15.0 + 5.0 * maxf(thr, 0.0) + (4.0 if boosting else 0.0)) if alive else -80.0,
		0.9 + 0.22 * thr + (0.25 if boosting else 0.0))
	var lv: Dictionary = sim.level
	sound.loop("rain", -4.0 if String(lv.get("weather", "")) == "rain" else -80.0)
	var windy: bool = lv.has("wind") or String(lv.get("terrain", "")) in ["arctic", "winter", "mountains"]
	sound.loop("wind", (-10.0 + absf(sim.wind_x()) * 0.06) if windy else -80.0)
	sound.loop("warning", -9.0 if warn else -80.0)
	# The seeker's growl while a lock is building.
	_lock_beep -= delta
	if locking and _lock_beep <= 0.0:
		_lock_beep = 0.14
		sound.play("lock_tone", -14.0)
	if view.fx.splash_count != _splashes:
		_splashes = view.fx.splash_count
		sound.play("splash", -14.0, 0.1)


func _event_sound(e: Dictionary) -> void:
	match e.e:
		"shoot": sound.gun(false)
		"enemy_shoot": sound.gun(true)
		"hit": sound.play("hit", -12.0, 0.12)
		"player_damaged": sound.play("hurt", -5.0, 0.08)
		"kill": sound.play("bigboom" if e.get("boss", false) else "boom", -4.0 if e.get("boss", false) else -7.0, 0.12)
		"player_hit": sound.play("bigboom", -2.0)
		"missile": sound.play("missile", -6.0, 0.06)
		"lock": sound.play("lock_ok", -9.0)
		"enemy_missile": sound.play("sam" if e.get("ground", false) else "missile", -7.0 if e.get("ground", false) else -11.0, 0.08, 0.85)
		"missile_hit": sound.play("boom", -5.0, 0.1)
		"emissile_hit": sound.play("bigboom", -3.0)
		"emissile_gone": sound.play("pop", -15.0, 0.15)
		"flares": sound.play("flare", -7.0, 0.08)
		"flak": sound.play("flak", -7.0, 0.15)
		"photo": sound.play("shutter", -4.0)
		"photo_missed": sound.play("missed", -8.0)
		"overheat": sound.play("overheat", -8.0)
		"combo": sound.play("kaching", -4.0)
		"switch":
			sound.play("stamp", -4.0)
			sound.play("kaching", -6.0)
		"tea": sound.play("tea", -2.0)
		"home", "respawn": sound.play("ui", -8.0)
		"wave_clear": sound.play("clear", -6.0)
		"approach": sound.play("approach", -6.0)
		"rescue": sound.play("rescue", -6.0)
		"join": sound.play("join", -6.0)
		"rearm": sound.play("lock_ok", -10.0)


func _consume_events() -> void:
	for e in sim.events:
		view.handle(e, sim)
		_event_sound(e)
		match e.e:
			"kill":
				_fx.append({"kind": "points", "pos": e.pos, "t": 0.0, "life": 0.7, "text": "+%d" % Sim.POINTS.get(e.kind, 10)})
			"player_hit":
				_shake = 0.35
			"player_damaged":
				_shake = maxf(_shake, 0.12)
			"missile_hit":
				_shake = maxf(_shake, 0.15)
			"emissile_hit":
				_shake = 0.3
			"decoyed":
				_fx.append({"kind": "points", "pos": e.pos, "t": 0.0, "life": 0.8, "text": "DECOYED"})
			"flak":
				_shake = maxf(_shake, 0.08)
			"photo":
				_flash = 1.0
				_fx.append({"kind": "points", "pos": e.pos, "t": 0.0, "life": 1.2, "text": "PHOTO %d" % sim.photos})
			"photo_missed":
				_fx.append({"kind": "banner", "pos": Vector2(Sim.W / 2, 330), "t": 0.0, "life": 1.2, "text": "Missed one"})
			"overheat":
				_fx.append({"kind": "banner", "pos": Vector2(Sim.W / 2, 330), "t": 0.0, "life": 1.6, "text": "ENGINE OVERHEAT"})
			"combo":
				_fx.append({"kind": "banner", "pos": Vector2(Sim.W / 2, 300), "t": 0.0, "life": 2.2, "text": "FIVE IN A MINUTE*"})
				_fx.append({"kind": "banner_small", "pos": Vector2(Sim.W / 2, 324), "t": 0.0, "life": 2.2, "text": "*figures disputed"})
			"switch":
				_fx.append({"kind": "banner", "pos": Vector2(Sim.W / 2, 300), "t": 0.0, "life": 3.0, "text": "Contract renegotiated"})
				_fx.append({"kind": "banner_small", "pos": Vector2(Sim.W / 2, 324), "t": 0.0, "life": 3.0, "text": String(e.text)})
			"rearm":
				_fx.append({"kind": "banner_small", "pos": Vector2(Sim.W / 2, 340), "t": 0.0, "life": 1.6, "text": "Missiles re-armed"})
			"tea":
				_fx.append({"kind": "banner", "pos": Vector2(Sim.W / 2, 300), "t": 0.0, "life": 3.0, "text": "Coffee with the neighbours"})
				_fx.append({"kind": "banner_small", "pos": Vector2(Sim.W / 2, 324), "t": 0.0, "life": 3.0, "text": "Two sugars. Very polite. Back in two days. Goodwill +500"})
			"home":
				_fx.append({"kind": "banner_small", "pos": Vector2(Sim.W / 2, 324), "t": 0.0, "life": 2.0, "text": "Landed on home soil. No coffee."})
			"roe":
				_fx.append({"kind": "points", "pos": e.pos, "t": 0.0, "life": 0.9, "text": "ROE: NO FIRE ACROSS"})
			"rescue":
				_fx.append({"kind": "points", "pos": e.pos, "t": 0.0, "life": 1.0, "text": "RESCUE +250"})
			"join":
				_fx.append({"kind": "banner", "pos": Vector2(Sim.W / 2, 300), "t": 0.0, "life": 1.6, "text": "Deuce joins the formation"})
			"wave_clear":
				_fx.append({"kind": "banner", "pos": Vector2(Sim.W / 2, 300), "t": 0.0, "life": 1.4, "text": "Wave clear"})
			"approach":
				_fx.append({"kind": "banner", "pos": Vector2(Sim.W / 2, 300), "t": 0.0, "life": 2.0, "text": "Land on the strip"})
	sim.events.clear()


func _update_fx(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	var keep: Array = []
	for f in _fx:
		f.t += delta
		if f.t < f.life:
			keep.append(f)
	_fx = keep


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var vs := get_viewport_rect().size
	_fs = minf(vs.x / Sim.W, vs.y / Sim.H)
	_fo = (vs - Vector2(Sim.W, Sim.H) * _fs) / 2.0
	view.fit(vs)
	# Dim the 3D scene outside the playfield so the eye stays on the action.
	draw_rect(Rect2(0, 0, _fo.x, vs.y), Color(0.03, 0.05, 0.1, 0.72))
	draw_rect(Rect2(vs.x - _fo.x, 0, _fo.x, vs.y), Color(0.03, 0.05, 0.1, 0.72))
	draw_rect(Rect2(0, 0, vs.x, _fo.y), Color(0.03, 0.05, 0.1, 0.72))
	draw_rect(Rect2(0, vs.y - _fo.y, vs.x, _fo.y), Color(0.03, 0.05, 0.1, 0.72))
	_field()
	if state == "menu":
		# Title-screen demo: just the world, no HUD; the menu draws on top.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_draw_field()
	_draw_hud()
	if state == "brief":
		_draw_brief()
	elif state == "end" and _state_t > 0.6:
		_draw_end()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_side(vs)


## Switch drawing into field coordinates.
func _field() -> void:
	draw_set_transform(_fo, 0.0, Vector2(_fs, _fs))


## Text is drawn in screen pixels (crisp at any size), positioned in field units.
func _text(p: Vector2, s: String, size: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(_font, _fo + p * _fs, s, align, width * _fs if width > 0 else -1.0, int(size * _fs), col)
	_field()


func _para(p: Vector2, s: String, size: float, col: Color, width: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_multiline_string(_font, _fo + p * _fs, s, align, width * _fs, int(size * _fs), -1, col)
	var h := _font.get_multiline_string_size(s, align, width * _fs, int(size * _fs)).y / _fs
	_field()
	return h


## The 3D view draws the world; only labels that float over it are 2D.
func _draw_field() -> void:
	_draw_weather()
	_draw_zones()
	for i in 2:
		var p: Dictionary = sim.players[i]
		if p.has_chute:
			_text(p.chute + Vector2(-40, 30), "Catch " + NAMES[i] + "!", 11, Art.P_COLORS[i], HORIZONTAL_ALIGNMENT_CENTER, 80)
		if p.active and p.alive and state == "play":
			_draw_gauges(i, p)
	for f in _fx:
		_draw_fx(f)


## Mission zones and ground markers drawn over the 3D view.
func _draw_zones() -> void:
	var lv: Dictionary = sim.level
	if lv.has("sanctuary_x"):
		var sx: float = lv.sanctuary_x
		draw_rect(Rect2(0, 28, sx, Sim.H - 58), Color(0.9, 0.2, 0.15, 0.1))
		var y := 40.0
		while y < Sim.H - 40:
			draw_line(Vector2(0, y), Vector2(sx, y - sx * 0.6), Color(0.9, 0.3, 0.2, 0.12), 2.0)
			y += 26.0
		draw_line(Vector2(sx, 28), Vector2(sx, Sim.H - 30), Color(1, 0.4, 0.3, 0.6), 2.0)
		_text(Vector2(0, 70), "SANCTUARY", 11, Color(1, 0.6, 0.5, 0.9), HORIZONTAL_ALIGNMENT_CENTER, sx)
		_text(Vector2(0, 84), "no fire across", 9, Color(1, 0.6, 0.5, 0.8), HORIZONTAL_ALIGNMENT_CENTER, sx)
	if lv.has("bvr_line"):
		var by: float = lv.bvr_line
		draw_dashed_line(Vector2(0, by), Vector2(Sim.W, by), Color(1, 0.85, 0.4, 0.55), 2.0, 10.0)
		_text(Vector2(8, by - 6), "THE LINE", 10, Color(1, 0.85, 0.4, 0.8))
		_text(Vector2(Sim.W - 150, by + 14), "(nobody crosses it)", 9, Color(1, 0.85, 0.4, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 140)
	# Flak: a ring tightens on where the shell will burst.
	for f in sim.flak:
		var k: float = clampf(float(f.t) / float(lv.flak.warn), 0.0, 1.0)
		var r: float = float(lv.flak.radius) * (1.0 + k * 0.8)
		var a := 0.35 + 0.5 * (1.0 - k)
		draw_arc(f.pos, r, 0, TAU, 32, Color(1, 0.45, 0.2, a), 2.0)
		draw_circle(f.pos, 2.5, Color(1, 0.45, 0.2, a))
	# Photo targets: green brackets until photographed.
	for t in sim.targets:
		var tp: Vector2 = t.pos
		var c := Color(0.5, 1.0, 0.6, 0.85) if not t.done else Color(1, 1, 1, 0.35)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var q: Vector2 = tp + corner * Vector2(Sim.PHOTO_RADIUS)
			draw_line(q, q - Vector2(corner.x * 8, 0), c, 2.0)
			draw_line(q, q - Vector2(0, corner.y * 8), c, 2.0)
		_text(tp + Vector2(-40, -Sim.PHOTO_RADIUS.y - 6), "PHOTO" if not t.done else "GOT IT", 9, c, HORIZONTAL_ALIGNMENT_CENTER, 80)
	# Tea missions: which half is home while a parachute is coming down.
	if lv.get("tea", false):
		for p in sim.players:
			if p.has_chute:
				draw_dashed_line(Vector2(Sim.W / 2, 40), Vector2(Sim.W / 2, Sim.H - 30), Color(1, 1, 1, 0.4), 1.5, 8.0)
				var home_left: bool = String(lv.get("home", "left")) == "left"
				_text(Vector2(0, Sim.H - 44), "HOME" if home_left else "COFFEE", 12, Color("9fe1cb") if home_left else Art.GOLD, HORIZONTAL_ALIGNMENT_CENTER, Sim.W / 2)
				_text(Vector2(Sim.W / 2, Sim.H - 44), "COFFEE" if home_left else "HOME", 12, Art.GOLD if home_left else Color("9fe1cb"), HORIZONTAL_ALIGNMENT_CENTER, Sim.W / 2)
				_text(p.chute + Vector2(-60, -30), "steer: left / right", 9, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 120)
				break


## Rain, snow and dust drift over the field; storms flash.
func _make_weather() -> void:
	_weather.clear()
	var kind := String(sim.level.get("weather", "none"))
	var n: int = {"rain": 140, "snow": 110, "dust": 26}.get(kind, 0)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for k in n:
		_weather.append({"pos": Vector2(r.randf() * Sim.W, r.randf() * Sim.H), "s": r.randf_range(0.6, 1.4), "ph": r.randf() * TAU})


func _update_weather(delta: float) -> void:
	var kind := String(sim.level.get("weather", "none"))
	var wind: float = sim.wind_x()
	var fly: float = sim.ground_speed / Sim.GROUND_PX
	for w in _weather:
		var p: Vector2 = w.pos
		match kind:
			"rain":
				p += Vector2(wind * 1.5 - 60.0, 900.0 * fly) * delta * float(w.s)
			"snow":
				p += Vector2(wind + sin(_t * 1.3 + float(w.ph)) * 20.0, 110.0 * fly) * delta * float(w.s)
			"dust":
				p += Vector2(140.0 + wind, 60.0 * fly) * delta * float(w.s)
		w.pos = Vector2(fposmod(p.x, Sim.W), fposmod(p.y, Sim.H))
	_flash = maxf(0.0, _flash - delta * 4.0)


func _draw_weather() -> void:
	var kind := String(sim.level.get("weather", "none"))
	for w in _weather:
		var p: Vector2 = w.pos
		match kind:
			"rain":
				draw_line(p, p + Vector2(-2.0, 16.0) * float(w.s), Color(0.8, 0.85, 0.95, 0.35), 1.0)
			"snow":
				draw_circle(p, 1.2 + float(w.s), Color(1, 1, 1, 0.75))
			"dust":
				draw_circle(p, 40.0 * float(w.s), Color(0.8, 0.62, 0.42, 0.06))
	if kind == "dust":
		draw_rect(Rect2(0, 0, Sim.W, Sim.H), Color(0.75, 0.55, 0.35, 0.07))
	var flash: float = maxf(_flash, float(view.lightning_level))
	if flash > 0.0:
		draw_rect(Rect2(0, 0, Sim.W, Sim.H), Color(1, 1, 1, flash * 0.35))


## Under each jet: armor bar and missile pips. Over locked targets: brackets.
func _draw_gauges(i: int, p: Dictionary) -> void:
	var pos: Vector2 = p.pos
	var frac: float = 1.0 - sim.damage(p)
	var col := Color("9fe1cb") if frac > 0.6 else (Art.AMBER if frac > 0.3 else Color("e24b4a"))
	draw_rect(Rect2(pos.x - 18, pos.y + 22, 36, 3), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(pos.x - 18, pos.y + 22, 36 * frac, 3), col)
	for k in int(sim.jet.missiles):
		var have: bool = k < int(p.missiles)
		draw_rect(Rect2(pos.x - 18 + k * 7, pos.y + 27, 5, 3), Color("f1efe8") if have else Color(1, 1, 1, 0.15))
	# Afterburner heat (jets that have one).
	if float(sim.jet.boost) > 0.0:
		var heat: float = p.heat
		var hc := Color("e24b4a") if float(p.overheat) > 0.0 else Color(1.0, 0.55 + 0.4 * (1.0 - heat), 0.2)
		draw_rect(Rect2(pos.x - 18, pos.y + 32, 36, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(pos.x - 18, pos.y + 32, 36 * heat, 3), hc)
		if float(p.overheat) > 0.0 and fmod(_t, 0.3) < 0.18:
			_text(pos + Vector2(-40, 50), "OVERHEAT", 9, hc, HORIZONTAL_ALIGNMENT_CENTER, 80)
		elif p.boosting:
			_text(pos + Vector2(-40, 50), "AFTERBURNER", 9, Color(1, 0.75, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 80)
	# Flare dispenser: a small gauge that refills; gold when ready.
	var ready: float = 1.0 - float(p.flare_cd) / float(sim.jet.flare_cd)
	var fc := Color("fac775") if ready >= 1.0 else Color(1, 1, 1, 0.35)
	draw_rect(Rect2(pos.x + 4, pos.y + 27, 14, 3), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(pos.x + 4, pos.y + 27, 14 * ready, 3), fc)
	# Missile warning: locks being built on us, and missiles in the air.
	var warn := false
	for l in sim.enemy_locks:
		if l.target == i:
			warn = true
			var sp := pos
			if l.has("site"):
				var site: Dictionary = sim._find_site(l.site)
				if not site.is_empty():
					sp = Vector2(site.pos) + Vector2(0, view._ground_shift)
			else:
				var shooter: Dictionary = sim._find(l.shooter)
				if not shooter.is_empty():
					sp = shooter.pos
			draw_dashed_line(sp, pos, Color(1, 0.35, 0.3, 0.45), 1.5, 6.0)
	var incoming: Array = sim.threats_to(i)
	for m in incoming:
		warn = true
		var mp: Vector2 = m.pos
		var dir := (mp - pos).normalized()
		var tip := pos + dir * 34.0
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 9 + dir.orthogonal() * 5, tip - dir * 9 - dir.orthogonal() * 5]), Color("ff4a3a"))
	if warn and fmod(_t, 0.3) < 0.18:
		_text(pos + Vector2(-50, -46), "MISSILE LOCK" if incoming.is_empty() else ("MISSILE! FLARES (F)" if float(p.flare_cd) <= 0.0 else "MISSILE! BREAK!"), 10, Color("ff4a3a"), HORIZONTAL_ALIGNMENT_CENTER, 100)
	var locks: Array = p.locks
	var pc: Color = Art.P_COLORS[i]
	for id in locks:
		for e in sim.enemies:
			if e.id == id:
				var ep: Vector2 = e.pos
				var r := 18.0 + 2.0 * sin(_t * 12.0)
				for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var corner: Vector2 = ep + c * r
					draw_line(corner, corner - Vector2(c.x * 7, 0), Color("ff5a4a"), 2.0)
					draw_line(corner, corner - Vector2(0, c.y * 7), Color("ff5a4a"), 2.0)
				_text(ep + Vector2(-20, r + 12), "LOCK", 9, Color("ff5a4a"), HORIZONTAL_ALIGNMENT_CENTER, 40)
	if p.lock_t > 0.0:
		# Seeker tone sweeping: a ring that closes as the next lock builds.
		var k: float = p.lock_t / float(sim.jet.lock_time)
		draw_arc(pos + Vector2(0, -40), 14.0, -PI / 2, -PI / 2 + TAU * k, 24, pc, 2.0)
		_text(pos + Vector2(-30, -58), "LOCKING", 9, pc, HORIZONTAL_ALIGNMENT_CENTER, 60)


func _draw_fx(f: Dictionary) -> void:
	var k: float = f.t / f.life
	var pos: Vector2 = f.pos
	match f.kind:
		"boom":
			var r := (24.0 if f.get("big", false) else 16.0) * (0.4 + k)
			draw_circle(pos, r, Color(Art.AMBER, 1.0 - k))
			draw_circle(pos, r * 0.55, Color(Art.GOLD, 1.0 - k))
			for d in 6:
				var a := d * TAU / 6.0 + 0.4
				draw_rect(Rect2(pos + Vector2(cos(a), sin(a)) * r * 1.4, Vector2(3, 3)), Color(Color("888780"), 1.0 - k))
		"puff":
			draw_circle(pos + Vector2(3, 3), 5.0 * (1.0 + k), Color(Art.CLOUD_LIGHT, 0.8 - 0.8 * k))
		"points":
			_text(pos + Vector2(-40, -14 - 20 * k), f.text, 11, Color(Art.GOLD, 1.0 - k), HORIZONTAL_ALIGNMENT_CENTER, 80)
		"banner_small":
			var a := clampf(minf(f.t * 4.0, (f.life - f.t) * 3.0), 0.0, 1.0)
			_text(Vector2(0, pos.y), f.text, 12, Color(Art.HUD_TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, Sim.W)
		"banner":
			var a := clampf(minf(f.t * 4.0, (f.life - f.t) * 3.0), 0.0, 1.0)
			_text(Vector2(0, pos.y), f.text, 22, Color(Art.HUD_TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, Sim.W)


func _draw_hud() -> void:
	var lv: Dictionary = sim.level
	draw_rect(Rect2(0, 0, Sim.W, 28), Color(Art.OUTER, 0.7))
	_text(Vector2(10, 19), "M%d · %s" % [level_index + 1, String(lv.name).to_upper()], 12, Art.HUD_TEXT)
	_text(Vector2(Sim.W - 210, 19), "SCORE %06d" % sim.score, 12, Art.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	draw_rect(Rect2(0, Sim.H - 30, Sim.W, 30), Color(Art.OUTER, 0.7))
	if float(lv.get("fuel_rate", 0.0)) > 0.0:
		_text(Vector2(10, Sim.H - 10), "FUEL", 12, Art.HUD_TEXT)
		var full: float = lv.get("fuel", 100.0)
		var frac: float = sim.fuel / full
		draw_rect(Rect2(48, Sim.H - 21, 120, 10), Color("1c2a44"))
		var col := Art.AMBER if frac < 0.35 else Color("9fe1cb")
		if frac < 0.2 and fmod(_t, 0.5) < 0.25:
			col = Color("e24b4a")
		draw_rect(Rect2(48, Sim.H - 21, 120 * frac, 10), col)
		if frac < 0.35:
			_text(Vector2(176, Sim.H - 10), "FUMES", 12, col)
	else:
		_text(Vector2(10, Sim.H - 10), String(sim.jet.name).to_upper(), 11, Color(Art.HUD_TEXT, 0.8))
	for k in sim.lives:
		Art.jet(self, "foxbrat", Vector2(Sim.W - 18 - k * 20, Sim.H - 15), 0.0, Art.P_COLORS[0], 0.4)
	# Objective line under the top bar.
	var obj := ""
	match sim.goal():
		"survive":
			var tl: float = sim.time_left()
			obj = "TIME %d:%02d" % [int(tl) / 60, int(tl) % 60]
			if lv.has("photos"):
				obj += "   PHOTOS %d/%d" % [sim.photos, int(lv.photos.need)]
		_:
			if sim.phase == "approach":
				obj = "LAND ON THE STRIP"
			elif not lv.waves.is_empty():
				obj = "WAVE %d/%d" % [sim.wave + 1, lv.waves.size()]
	_text(Vector2(10, 42), obj, 11, Color(Art.HUD_TEXT, 0.9))
	if lv.get("claims", false):
		_text(Vector2(Sim.W - 290, 42), "KILLS %d · CLAIMED %d" % [sim.kills, sim.claims], 11, Art.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 280)
	if lv.has("wind"):
		var wx: float = sim.wind_x()
		var cx := Sim.W - 60.0
		var len := clampf(wx * 0.35, -40.0, 40.0)
		_text(Vector2(cx - 80, 58), "WIND", 9, Color(Art.HUD_TEXT, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, 60)
		draw_line(Vector2(cx, 55), Vector2(cx + len, 55), Color(0.8, 0.9, 1.0, 0.8), 2.0)
		draw_circle(Vector2(cx + len, 55), 2.5, Color(0.8, 0.9, 1.0, 0.8))
	if not sim.players[1].active and state == "play" and fmod(_t, 1.2) < 0.8:
		_text(Vector2(0, 46), "P2: press Enter to join", 11, Color(Art.HUD_TEXT, 0.7), HORIZONTAL_ALIGNMENT_CENTER, Sim.W)


func _card(y: float, h: float) -> Rect2:
	draw_rect(Rect2(0, 0, Sim.W, Sim.H), Color(0, 0, 0, 0.55))
	var r := Rect2(36, y, Sim.W - 72, h)
	draw_rect(r, Color("16233c"))
	draw_rect(r, Color("41587f"), false, 1.5)
	return r


func _draw_brief() -> void:
	var lv: Dictionary = sim.level
	var r := _card(90, 500)
	var x := r.position.x + 22
	var w := r.size.x - 44
	var y := r.position.y + 34
	_text(Vector2(x, y), "Chapter %d · %s" % [lv.chapter + 1, Levels.CHAPTERS[lv.chapter]], 11, Color("9fb4d4"))
	_text(Vector2(x, y + 16), "Mission %d · %s" % [level_index + 1, lv.year], 11, Color("9fb4d4"))
	_text(Vector2(x, y + 46), String(lv.name), 26, Color.WHITE)
	y += 70
	y += _para(Vector2(x, y), "\"" + String(lv.quote) + "\"", 13, Color("d3d1c7"), w) + 16
	var jet: Dictionary = sim.jet
	var stats: Dictionary = Jets.pips(String(lv.get("jet_id", "foxbrat")))
	var rows := [["Jet", jet.name], ["Maker", jet.maker], ["Flying for", lv.country]]
	for row in rows:
		_text(Vector2(x, y), row[0], 12, Color("9fb4d4"))
		_text(Vector2(x, y), String(row[1]), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, w)
		y += 19
	for s in stats:
		_text(Vector2(x, y), String(s).capitalize(), 12, Color("9fb4d4"))
		for k in 5:   # five pips, filled up to the stat
			draw_rect(Rect2(x + w - 5 * 14 + k * 14, y - 9, 11, 8), Art.GOLD if k < int(stats[s]) else Color("2c3b58"))
		y += 19
	y += 8
	y += _para(Vector2(x, y), String(lv.goal_text), 12, Color("d3d1c7"), w) + 10
	var badge := "New: " + String(lv.new)
	var bw := _font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _fs)).x / _fs + 16.0
	draw_rect(Rect2(x, y - 2, bw, 22), Color("633806"))
	_text(Vector2(x + 8, y + 13), badge, 12, Art.GOLD)
	if fmod(_t, 1.0) < 0.75:
		_text(Vector2(r.position.x, r.end.y - 34), "Space to fly", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(Vector2(r.position.x, r.end.y - 14), "Enter: a friend joins as Deuce (optional)", 11, Color("9fb4d4"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if unlocked > 1:
		_text(Vector2(r.position.x, r.position.y - 10), "Esc: back to mission select", 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_end() -> void:
	var lv: Dictionary = sim.level
	var won: bool = sim.result == "win"
	var claims: bool = lv.get("claims", false)
	var r := _card(120 if claims else 150, 480 if claims else 400)
	var x := r.position.x + 22
	var w := r.size.x - 44
	var y := r.position.y + 40
	_text(Vector2(x, y), "Mission complete" if won else "Mission failed", 24, Art.GOLD if won else Color("f09595"))
	y += 26
	var stats := "Score %d · %d kills" % [sim.score, sim.kills]
	if float(lv.get("fuel_rate", 0.0)) > 0.0:
		stats += " · %.0f%% fuel left" % sim.fuel
	if lv.has("photos"):
		stats += " · %d photos" % sim.photos
	_text(Vector2(x, y), stats, 12, Color("9fb4d4"))
	y += 26
	if claims:
		# Dueling press releases: each side's Ministry of Claims reports.
		var us := String(lv.get("country", "Us")).get_slice(" ", 0)
		var them := String(lv.get("enemy_country", "Them"))
		var ours: int = sim.claims + (12 if won else 4)
		var theirs: int = sim.enemy_claims + sim.kills / 2 + 7
		draw_rect(Rect2(x, y - 14, w, 64), Color(1, 1, 1, 0.05))
		y += _para(Vector2(x + 8, y), "%s Ministry of Claims: \"%d enemy jets destroyed. Our losses: none.\"" % [us, ours], 12, Color("9fe1cb"), w - 16) + 4
		y += _para(Vector2(x + 8, y), "%s Ministry of Claims: \"%d enemy jets destroyed, including %d we've never heard of. Our losses: also none.\"" % [them, theirs, maxi(2, theirs / 4)], 12, Color("f5c4b3"), w - 16) + 14
		_text(Vector2(x, y), "(Actual kills: %d. Nobody asked.)" % sim.kills, 10, Color("9fb4d4"))
		y += 20
	if won:
		_text(Vector2(x, y), "The real story", 12, Color("9fb4d4"))
		y += 18
		y += _para(Vector2(x, y), String(lv.real_story), 13, Color.WHITE, w) + 14
		y += _para(Vector2(x, y), "Bartender: \"" + String(lv.bartender) + "\"", 13, Color("d3d1c7"), w)
	else:
		y += _para(Vector2(x, y), String(lv.fail.get(sim.reason, "That didn't go well.")), 14, Color.WHITE, w)
	_text(Vector2(r.position.x, r.end.y - 18), "Space: continue · R: retry · Esc: missions", 12, Color("9fb4d4"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## In a wide window, the space beside the field shows controls and the pilots.
func _draw_side(vs: Vector2) -> void:
	var side := _fo.x
	if side < 160:
		return
	var fsz := int(13 * _fs)
	var y := _fo.y + 60 * _fs
	draw_string(_font, Vector2(side * 0.5 - 90 * _fs, y), "AIR SUPERIORITY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * _fs), Color.WHITE)
	draw_string(_font, Vector2(side * 0.5 - 90 * _fs, y + 24 * _fs), "COMPLEX", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * _fs), Art.GOLD)
	var lines := ["Ace: WASD or Arrows", "Space: cannons", "Hold Shift: lock missiles,", "release to fire", "F: flares", "", "Deuce: Enter to join,", "then Arrows, Enter,", "Right Shift, /", "", "Gamepads work too", "Esc: pause menu"]
	for k in lines.size():
		draw_string(_font, Vector2(side * 0.5 - 90 * _fs, y + (70 + k * 20) * _fs), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color("9fb4d4"))
	var rx := vs.x - side
	for i in 2:
		var p: Dictionary = sim.players[i]
		var status := "flying" if p.alive else ("ejected" if p.has_chute else ("out" if p.out else "respawning"))
		if not p.active:
			status = "at the bar (Enter to join)"
		draw_string(_font, Vector2(rx + 30 * _fs, y + i * 46 * _fs), NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * _fs), Art.P_COLORS[i])
		draw_string(_font, Vector2(rx + 30 * _fs, y + (i * 46 + 18) * _fs), status, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color("9fb4d4"))
	draw_string(_font, Vector2(rx + 30 * _fs, y + 120 * _fs), "Kills: %d" % sim.kills, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Art.HUD_TEXT)
	draw_string(_font, Vector2(rx + 30 * _fs, y + 140 * _fs), "Spare jets: %d" % sim.lives, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Art.HUD_TEXT)


# --- dev helpers -------------------------------------------------------------

func _parse_args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var eq := s.find("=")
		if eq >= 0:
			d[s.substr(0, eq)] = s.substr(eq + 1)
		else:
			d[s] = "1"
	return d


func _take_screenshot_later(path: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ", path)
	get_tree().quit()
