extends Node2D
## On-screen controls for phones and tablets: a floating stick on the left
## half of the screen, and Fire / Missile / Flare buttons plus Pause on the
## right. They turn on by themselves on a touch screen (or with --touch).
##
## Each control presses the same input action a key would (p1_fire,
## p1_left...), so the game can't tell a thumb from a keyboard. Godot's
## Input.action_press(name, strength) lets the stick press "left" by 60%, so
## it steers smoothly, not just on/off.
##
## Multi-touch: every finger has an index; we remember which control each
## finger is holding, so you can steer and fire at the same time.

const ACCENT := Color("fac775")

var enabled := false
var game                       # game.gd, to know the current state
var _fingers := {}             # finger index -> "stick" | action name
var _stick_center := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _tap_release: Array = []   # actions to let go of on the next frame
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = 5


func _scale() -> float:
	var vs := get_viewport_rect().size
	return clampf(minf(vs.x, vs.y) / 720.0, 0.6, 2.0)


## Button layout, in screen pixels: name -> [center, radius, action, label].
func _buttons() -> Dictionary:
	var vs := get_viewport_rect().size
	var s := _scale()
	var r := 62.0 * s
	var base := Vector2(vs.x - 110 * s, vs.y - 120 * s)
	return {
		"fire": [base, r * 1.15, "p1_fire", "FIRE"],
		"missile": [base + Vector2(-150 * s, 30 * s), r * 0.85, "p1_missile", "MISSILE"],
		"flare": [base + Vector2(-40 * s, -150 * s), r * 0.75, "p1_flare", "FLARE"],
		"pause": [Vector2(vs.x - 50 * s, 60 * s), 34 * s, "back", "II"],
	}


func _active() -> bool:
	return enabled and game != null and game.state in ["play", "brief", "end"] and game.menu.screen == ""


func _process(_delta: float) -> void:
	for a in _tap_release:
		Input.action_release(a)
	_tap_release.clear()
	if not _active() and not _fingers.is_empty():
		_release_all()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if _fingers.get(d.index, "") == "stick":
			_stick_pos = d.position
			_apply_stick()


func _touch_down(index: int, pos: Vector2) -> void:
	# On the briefing and end cards, any tap means "go" (like Space).
	if game.state != "play":
		for b in [_buttons().pause]:
			if pos.distance_to(b[0]) < b[1]:
				_tap("back")
				return
		_tap("p1_fire")
		return
	for key in _buttons():
		var b: Array = _buttons()[key]
		if pos.distance_to(b[0]) < b[1] * 1.15:
			if key == "pause":
				_tap("back")
			else:
				Input.action_press(b[2])
				_fingers[index] = b[2]
			return
	if pos.x < get_viewport_rect().size.x * 0.55:
		_fingers[index] = "stick"
		_stick_center = pos
		_stick_pos = pos
		_apply_stick()


func _touch_up(index: int) -> void:
	if not _fingers.has(index):
		return
	var what: String = _fingers[index]
	_fingers.erase(index)
	if what == "stick":
		_stick_pos = _stick_center
		_apply_stick()
	else:
		Input.action_release(what)


func _release_all() -> void:
	for i in _fingers:
		if _fingers[i] != "stick":
			Input.action_release(_fingers[i])
	_fingers.clear()
	_stick_pos = _stick_center
	_apply_stick()


func _tap(action: String) -> void:
	Input.action_press(action)
	_tap_release.append(action)


## The stick's offset becomes four action strengths (0..1), like an analog pad.
func _apply_stick() -> void:
	var max_r := 80.0 * _scale()
	var v := (_stick_pos - _stick_center) / max_r
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < 0.12:
		v = Vector2.ZERO
	for pair in [["p1_left", -v.x], ["p1_right", v.x], ["p1_up", -v.y], ["p1_down", v.y]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


func _draw() -> void:
	if not _active():
		return
	var s := _scale()
	if game.state != "play":
		var vs := get_viewport_rect().size
		draw_string(_font, Vector2(0, vs.y - 40 * s), "Tap anywhere to continue", HORIZONTAL_ALIGNMENT_CENTER, vs.x, int(20 * s), Color(1, 1, 1, 0.8))
	else:
		# Stick: a ring where the thumb landed (or a hint where it would go).
		var held := _fingers.values().has("stick")
		var c := _stick_center if held else Vector2(140 * s, get_viewport_rect().size.y - 160 * s)
		var k := _stick_pos if held else c
		draw_circle(c, 80 * s, Color(1, 1, 1, 0.08))
		draw_arc(c, 80 * s, 0, TAU, 48, Color(1, 1, 1, 0.3), 2.0 * s)
		draw_circle(k, 34 * s, Color(1, 1, 1, 0.35 if held else 0.18))
		if not held:
			draw_string(_font, c + Vector2(-80 * s, 110 * s), "drag to fly", HORIZONTAL_ALIGNMENT_CENTER, 160 * s, int(14 * s), Color(1, 1, 1, 0.5))
	for key in _buttons():
		if game.state != "play" and key != "pause":
			continue
		var b: Array = _buttons()[key]
		var down := _fingers.values().has(b[2])
		var col := ACCENT if key == "fire" else Color(0.8, 0.9, 1.0)
		if key == "flare" and game.sim != null and float(game.sim.players[0].flare_cd) > 0.0:
			col = Color(1, 1, 1, 0.4)
		draw_circle(b[0], b[1], Color(col, 0.35 if down else 0.15))
		draw_arc(b[0], b[1], 0, TAU, 40, Color(col, 0.7), 2.5 * s)
		var fs := int((16.0 if key != "pause" else 20.0) * s)
		draw_string(_font, b[0] + Vector2(-b[1], fs * 0.35), String(b[3]), HORIZONTAL_ALIGNMENT_CENTER, b[1] * 2.0, fs, Color(col, 0.95))
