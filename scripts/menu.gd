extends Node2D
## The menus: title, mission select, options, controls and pause. It draws
## itself over everything and tells the game what was chosen through the
## `chosen` signal. (A signal is Godot's way for a node to announce
## something without knowing who's listening; game.gd connects to it.)
##
## Keyboard (arrows/WASD, Enter/Space, Esc), gamepad (d-pad, A, B/Start) and
## mouse (hover + click) all work. Esc always goes back one level and never
## quits; quitting is only the title screen's "Quit".

signal chosen(what: String, arg: int)

const Levels := preload("res://scripts/levels.gd")
const Jets := preload("res://scripts/jets.gd")
const ACCENT := Color("fac775")
const TEXT := Color("e8eef8")
const DIM := Color("8fa3c0")

var screen := ""              # "", "title", "select", "options", "controls", "pause"
var sel := 0
var unlocked := 1
var coop := false
var settings := {"music": 7, "sfx": 8, "fullscreen": false}
var _back_to := "title"       # where Esc goes from options/controls
var _opened := -1
var _items: Array = []        # [label, action] for the current screen
var _rects: Array = []        # clickable rectangles, same order as _items
var _font: Font
var _t := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = 10
	visible = false


func open(s: String, select := 0) -> void:
	if s in ["options", "controls"]:
		_back_to = screen if screen != "" else "title"
	screen = s
	sel = select
	visible = true
	_opened = Engine.get_process_frames()
	_build()


func close() -> void:
	screen = ""
	visible = false


func _build() -> void:
	match screen:
		"title":
			_items = [["Campaign", "select"], ["Co-op: %s" % ("On (2 players)" if coop else "Off"), "coop"],
				["Options", "options"], ["Controls", "controls"], ["Quit", "quit"]]
		"select":
			_items = []
			for n in Levels.LIST.size():
				_items.append([Levels.LIST[n].name, "mission"])
		"pause":
			_items = [["Resume", "resume"], ["Restart mission", "restart"], ["Mission select", "select"],
				["Options", "options"], ["Main menu", "title"]]
		"options":
			_items = [["Music volume", "music"], ["Effects volume", "sfx"],
				["Fullscreen: %s" % ("On" if settings.fullscreen else "Off"), "fullscreen"], ["Back", "back"]]
		"controls":
			_items = [["Back", "back"]]
	sel = clampi(sel, 0, _items.size() - 1)


# --- input --------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if screen == "" or Engine.get_process_frames() == _opened:
		queue_redraw()
		return
	var up := _pressed(["p1_up", "p2_up"])
	var down := _pressed(["p1_down", "p2_down"])
	var left := _pressed(["p1_left", "p2_left"])
	var right := _pressed(["p1_right", "p2_right"])
	var ok := _pressed(["p1_fire", "p2_fire"])
	var back := Input.is_action_just_pressed("back")
	if up or down:
		sel = wrapi(sel + (1 if down else -1), 0, _items.size())
		chosen.emit("blip", 0)
	if (left or right) and screen == "options":
		_adjust(1 if right else -1)
	if back:
		_go_back()
	elif ok:
		_activate(sel)
	queue_redraw()


func _pressed(actions: Array) -> bool:
	for a in actions:
		if Input.is_action_just_pressed(a):
			return true
	return false


## Mouse: hover highlights, click activates.
func _input(event: InputEvent) -> void:
	if screen == "":
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		var pos: Vector2 = event.position
		for k in _rects.size():
			var r: Rect2 = _rects[k]
			if r.has_point(pos):
				if sel != k and event is InputEventMouseMotion:
					sel = k
					chosen.emit("blip", 0)
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					sel = k
					if screen == "options" and k < 2:
						_adjust(1 if pos.x > r.get_center().x else -1)
					else:
						_activate(k)
				break


func _go_back() -> void:
	match screen:
		"title":
			pass                      # Esc never quits
		"select", "controls":
			if screen == "controls":
				open(_back_to, 3)
			else:
				open("title")
		"options":
			_save()
			open(_back_to, 2 if _back_to == "title" else 3)
		"pause":
			chosen.emit("resume", 0)
	chosen.emit("blip", 0)


func _activate(k: int) -> void:
	var what: String = _items[k][1]
	chosen.emit("ok", 0)
	match what:
		"select":
			open("select", mini(unlocked - 1, Levels.LIST.size() - 1))
			if screen == "select":
				chosen.emit("to_select", 0)
		"coop":
			coop = not coop
			_build()
		"options", "controls":
			open(what)
		"quit":
			chosen.emit("quit", 0)
		"mission":
			if k < unlocked:
				chosen.emit("mission", k)
		"resume", "restart", "title":
			chosen.emit(what, 0)
		"fullscreen":
			settings.fullscreen = not settings.fullscreen
			_apply()
			_build()
		"music", "sfx":
			_adjust(1)
		"back":
			_go_back()


func _adjust(d: int) -> void:
	var key: String = _items[sel][1]
	if key in ["music", "sfx"]:
		settings[key] = clampi(int(settings[key]) + d, 0, 10)
		_apply()
	elif key == "fullscreen":
		settings.fullscreen = not settings.fullscreen
		_apply()
		_build()


## Push settings into the audio buses and the window.
func _apply() -> void:
	for pair in [["Music", "music", -11.0], ["SFX", "sfx", -3.0], ["Ambience", "sfx", -8.0]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			var v: float = float(settings[pair[1]]) / 10.0
			AudioServer.set_bus_volume_db(i, pair[2] + linear_to_db(maxf(v, 0.001)) + 4.0)
			AudioServer.set_bus_mute(i, v <= 0.0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	chosen.emit("settings", 0)


func load_settings(cfg: ConfigFile) -> void:
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])
	_apply()


func _save() -> void:
	chosen.emit("save", 0)


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	if screen == "":
		return
	var vs := get_viewport_rect().size
	var s := minf(vs.x / 1280.0, vs.y / 720.0)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.04, 0.08, 0.62 if screen != "pause" else 0.5))
	_rects.clear()
	match screen:
		"title": _draw_title(vs, s)
		"select": _draw_select(vs, s)
		"pause": _draw_list(vs, s, "PAUSED", "Esc to resume")
		"options": _draw_options(vs, s)
		"controls": _draw_controls(vs, s)


func _str(pos: Vector2, text: String, size: float, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_font, pos, text, align, width, int(size), col)


func _draw_title(vs: Vector2, s: float) -> void:
	var cx := vs.x * 0.5
	var y := vs.y * 0.24
	_str(Vector2(0, y), "AIR SUPERIORITY", 64 * s, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_str(Vector2(0, y + 62 * s), "COMPLEX", 64 * s, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_str(Vector2(0, y + 100 * s), "Stories from a bar. Some of them true.", 18 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_menu_items(Vector2(cx - 170 * s, y + 160 * s), 340 * s, s)
	_str(Vector2(0, vs.y - 24 * s), "↑↓ choose · Enter select · Esc back", 14 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_list(vs: Vector2, s: float, title: String, hint: String) -> void:
	var cx := vs.x * 0.5
	var y := vs.y * 0.3
	_str(Vector2(0, y), title, 44 * s, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_menu_items(Vector2(cx - 170 * s, y + 50 * s), 340 * s, s)
	_str(Vector2(0, vs.y - 24 * s), hint, 14 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _menu_items(at: Vector2, w: float, s: float) -> void:
	var h := 46.0 * s
	for k in _items.size():
		var r := Rect2(at + Vector2(0, k * (h + 8 * s)), Vector2(w, h))
		_rects.append(r)
		var on := k == sel
		draw_rect(r, Color(1, 1, 1, 0.12) if on else Color(1, 1, 1, 0.04))
		if on:
			draw_rect(Rect2(r.position, Vector2(4 * s, h)), ACCENT)
		_str(r.position + Vector2(0, h * 0.66), String(_items[k][0]), 22 * s, ACCENT if on else TEXT, HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_select(vs: Vector2, s: float) -> void:
	_str(Vector2(60 * s, 70 * s), "MISSIONS", 40 * s, TEXT)
	_str(Vector2(60 * s, 98 * s), "%d of %d unlocked" % [unlocked, Levels.LIST.size()], 15 * s, DIM)
	var x := 60.0 * s
	var y := 130.0 * s
	var w := 460.0 * s
	var h := 38.0 * s
	var chapter := -1
	for k in _items.size():
		var lv: Dictionary = Levels.LIST[k]
		if int(lv.chapter) != chapter:
			chapter = int(lv.chapter)
			y += 10 * s
			_str(Vector2(x, y + 14 * s), "CHAPTER %d · %s" % [chapter + 1, String(Levels.CHAPTERS[chapter]).to_upper()], 13 * s, ACCENT)
			y += 22 * s
		var r := Rect2(Vector2(x, y), Vector2(w, h))
		_rects.append(r)
		var on := k == sel
		var locked := k >= unlocked
		draw_rect(r, Color(1, 1, 1, 0.12) if on else Color(1, 1, 1, 0.035))
		if on:
			draw_rect(Rect2(r.position, Vector2(4 * s, h)), ACCENT)
		var col := DIM if locked else (ACCENT if on else TEXT)
		_str(r.position + Vector2(18 * s, h * 0.66), "%2d   %s" % [k + 1, "Locked" if locked else String(lv.name)], 19 * s, col)
		_str(r.position + Vector2(0, h * 0.66), str(lv.year), 15 * s, DIM, HORIZONTAL_ALIGNMENT_RIGHT, w - 14 * s)
		y += h + 6 * s
	# Details of the highlighted mission.
	var lv: Dictionary = Levels.LIST[sel]
	var dx := 580.0 * s
	var dw := vs.x - dx - 60 * s
	var dy := 150.0 * s
	draw_rect(Rect2(dx - 20 * s, dy - 40 * s, dw + 40 * s, 470 * s), Color(0.08, 0.13, 0.22, 0.85))
	if sel >= unlocked:
		_str(Vector2(dx, dy), "Locked", 34 * s, DIM)
		_str(Vector2(dx, dy + 40 * s), "Win mission %d to unlock this one." % sel, 17 * s, DIM)
	else:
		var jet := Jets.get_jet(String(lv.jet_id))
		_str(Vector2(dx, dy), String(lv.name), 34 * s, TEXT)
		_str(Vector2(dx, dy + 30 * s), "%d · flying for %s" % [lv.year, lv.country], 16 * s, DIM)
		var rows := [["Jet", String(jet.name)], ["Terrain", String(lv.terrain).capitalize()],
			["Light", String(lv.light).capitalize()], ["New", String(lv.new)]]
		var ry := dy + 70 * s
		for row in rows:
			_str(Vector2(dx, ry), row[0], 16 * s, DIM)
			_str(Vector2(dx + 110 * s, ry), row[1], 16 * s, TEXT, HORIZONTAL_ALIGNMENT_LEFT, dw - 110 * s)
			ry += 28 * s
		draw_multiline_string(_font, Vector2(dx, ry + 20 * s), "\"" + String(lv.quote) + "\"", HORIZONTAL_ALIGNMENT_LEFT, dw, int(16 * s), -1, Color("d3d1c7"))
	_str(Vector2(0, vs.y - 24 * s), "↑↓ choose · Enter fly · Esc back", 14 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_options(vs: Vector2, s: float) -> void:
	var cx := vs.x * 0.5
	var y := vs.y * 0.28
	_str(Vector2(0, y), "OPTIONS", 44 * s, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var w := 460.0 * s
	var h := 46.0 * s
	for k in _items.size():
		var r := Rect2(Vector2(cx - w / 2, y + 50 * s + k * (h + 8 * s)), Vector2(w, h))
		_rects.append(r)
		var on := k == sel
		draw_rect(r, Color(1, 1, 1, 0.12) if on else Color(1, 1, 1, 0.04))
		if on:
			draw_rect(Rect2(r.position, Vector2(4 * s, h)), ACCENT)
		var col := ACCENT if on else TEXT
		var key: String = _items[k][1]
		if key in ["music", "sfx"]:
			_str(r.position + Vector2(20 * s, h * 0.66), String(_items[k][0]), 20 * s, col)
			var v: int = settings[key]
			for b in 10:
				var br := Rect2(r.position + Vector2(w - 20 * s - (10 - b) * 18 * s, h * 0.3), Vector2(13 * s, h * 0.4))
				draw_rect(br, ACCENT if b < v else Color(1, 1, 1, 0.15))
		else:
			_str(r.position + Vector2(0, h * 0.66), String(_items[k][0]), 20 * s, col, HORIZONTAL_ALIGNMENT_CENTER, w)
	_str(Vector2(0, vs.y - 24 * s), "←→ adjust · Esc back", 14 * s, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_controls(vs: Vector2, s: float) -> void:
	var y := vs.y * 0.18
	_str(Vector2(0, y), "CONTROLS", 44 * s, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var rows := [
		["", "Ace (player 1)", "Deuce (player 2, optional)"],
		["Fly", "WASD (or arrows when solo)", "Arrow keys"],
		["Cannons", "Space", "Enter"],
		["Missiles (hold to lock, release)", "Left Shift or E", "Right Shift"],
		["Flares", "F or Q", "/"],
		["Join mid-mission", "", "Enter"],
		["Gamepad", "Pad 1: stick, A, X / LB, B / Y", "Pad 2: same"],
		["Pause / back", "Esc (pad: Start)", ""],
		["Music on/off", "M", ""],
	]
	var x0 := vs.x * 0.5 - 520 * s
	var cols := [0.0, 330.0 * s, 700.0 * s]
	y += 60 * s
	for k in rows.size():
		for c in 3:
			_str(Vector2(x0 + cols[c], y), String(rows[k][c]), 17 * s, ACCENT if k == 0 or c == 0 else TEXT)
		y += 34 * s
	_rects.append(Rect2(Vector2(vs.x * 0.5 - 100 * s, y + 20 * s), Vector2(200 * s, 44 * s)))
	draw_rect(_rects[0], Color(1, 1, 1, 0.12))
	_str(_rects[0].position + Vector2(0, 30 * s), "Back", 20 * s, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 200 * s)
