extends RefCounted
## All art, drawn in code. Jets are top-down silhouettes stored as the right
## half of an outline (nose first); `_mirror` builds the full polygon. The
## shapes are stylized on purpose: recognizable as a type of jet, never an
## exact copy of a real one.

const SEA := Color("0f1a2e")
const SEA_FLECK := Color("1c2c48")
const OUTER := Color("0a1222")
const LAND := Color("2c4a3a")
const LAND_EDGE := Color("e8e2c8")
const STRIP := Color("5d6460")
const CLOUD := Color("33466b")
const CLOUD_LIGHT := Color("41587f")
const HUD_TEXT := Color("cfe3ff")
const GOLD := Color("fac775")
const AMBER := Color("ef9f27")
const BOMB := Color("f09595")
const P_COLORS := [Color("b5d4f4"), Color("c0dd97")]   # Ace silver-blue, Deuce sage
const ROW_COLORS := {"A": Color("e24b4a"), "B": Color("d85a30"), "C": Color("ba7517")}

const HALVES := {
	# Interceptor: big intakes, trapezoid wings, twin tails.
	"foxbrat": [Vector2(0, -22), Vector2(4, -12), Vector2(6, -12), Vector2(6, -4), Vector2(17, 6),
		Vector2(17, 10), Vector2(6, 8), Vector2(6, 14), Vector2(10, 18), Vector2(10, 21), Vector2(4, 19), Vector2(0, 20)],
	# Light fighter: long nose, delta wing, small tailplane.
	"fishbowl": [Vector2(0, -20), Vector2(2.5, -12), Vector2(3, -4), Vector2(14, 9), Vector2(14, 11),
		Vector2(3.5, 9), Vector2(3.5, 13), Vector2(8, 17), Vector2(8, 18.5), Vector2(0, 17)],
}


static func _mirror(half: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in half:
		pts.append(p)
	for k in range(half.size() - 2, 0, -1):
		var p: Vector2 = half[k]
		pts.append(Vector2(-p.x, p.y))
	return pts


## Draw a jet. rot = 0 points it up the screen, PI points it down.
static func jet(ci: CanvasItem, shape: String, pos: Vector2, rot: float, col: Color, s := 1.0) -> void:
	var xf := Transform2D(rot, Vector2(s, s), 0.0, pos)
	var outline := _mirror(HALVES[shape])
	ci.draw_colored_polygon(xf * outline, col)
	var dark := col.darkened(0.35)
	ci.draw_polyline(xf * (outline + PackedVector2Array([outline[0]])), dark, 1.0)
	ci.draw_circle(xf * Vector2(0, -9), 2.2 * s, col.lightened(0.45))


static func afterburner(ci: CanvasItem, pos: Vector2, t: float, s := 1.0) -> void:
	var flick := 4.0 + 3.0 * absf(sin(t * 31.0))
	for side in [-3.5, 3.5]:
		ci.draw_colored_polygon(PackedVector2Array([
			pos + Vector2(side - 2.5, 20) * s, pos + Vector2(side + 2.5, 20) * s,
			pos + Vector2(side, 20 + flick + 4) * s]), AMBER)


static func parachute(ci: CanvasItem, pos: Vector2, col: Color) -> void:
	var canopy := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0
		canopy.append(pos + Vector2(cos(a) * 13.0, sin(a) * 9.0 - 14.0))
	ci.draw_colored_polygon(canopy, Color("f1efe8"))
	for k in [0, 6, 12]:
		ci.draw_line(canopy[k], pos, Color("b4b2a9"), 1.0)
	ci.draw_circle(pos, 3.5, col)


static func cloud_cell(ci: CanvasItem, cell: Vector2i, size: float, hp: int) -> void:
	# A soft dot per cell; neighbours overlap into a puffy cloud.
	var c := (Vector2(cell) + Vector2(0.5, 0.5)) * size
	ci.draw_circle(c, size * 0.8, CLOUD_LIGHT if hp >= 2 else CLOUD)
