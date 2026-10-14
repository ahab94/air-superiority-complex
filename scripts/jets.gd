extends RefCounted
## What each parody jet can do. The rules (sim.gd), the autopilot, the
## briefing card and the 3D models all read this one table, so a new jet is
## one entry here plus a shape in jet_mesh.gd.
##
## Like the aircraft in big open-world games, each jet blends 2-3 real-world
## jet *types* ("blend"), and its numbers lean toward what that type is good at.
##
##   agility    sideways speed multiplier (how quickly it slides across)
##   armor      hits it can take when you fly it (as an enemy: armor / 3)
##   gun        seconds between cannon rounds; 0 = unarmed
##   missiles   missiles carried per sortie
##   locks      how many targets one missile salvo can lock
##   lock_time  seconds to acquire each lock
##   flare_cd   seconds for the flare dispenser to recharge (flares are unlimited)
##   boost      how hard its afterburner pushes chasing missiles back (px/s); 0 = none
##   hitbox     half-size in field pixels
##   burst, fire, missile_every   how the AI flies it: rounds per burst,
##              seconds between bursts, seconds between missile locks
##   paint      optional base colour for the players' version (else silver / sage)

const JETS := {
	"foxbrat": {
		"name": "MyG-52 Foxbrat", "maker": "Mikoyanov", "shape": "foxbrat",
		"blend": "boxy-intake twin-tail interceptor + clipped trapezoid wings",
		"agility": 0.85, "armor": 12, "gun": 0.1, "missiles": 4, "locks": 2, "lock_time": 0.45,
		"flare_cd": 3.0, "boost": 0.0, "hitbox": Vector2(12, 14),
		"burst": 4, "fire": 2.6, "missile_every": 10.0,
		"blurb": "Built to go very fast in a straight line. Turning is a group decision.",
	},
	"fishbowl": {
		"name": "MyG-12 Fishbowl", "maker": "Mikoyanov", "shape": "fishbowl",
		"blend": "nose-cone intake + tailless delta wing",
		"agility": 1.15, "armor": 9, "gun": 0.08, "missiles": 2, "locks": 2, "lock_time": 0.35,
		"flare_cd": 2.5, "boost": 0.0, "hitbox": Vector2(11, 13),
		"burst": 4, "fire": 2.4, "missile_every": 9.0,
		"blurb": "Small, nimble, cheap. Comes in very large numbers.",
	},
	"dragon_laddie": {
		"name": "2-U Dragon Laddie", "maker": "Lockjaw Marvin", "shape": "dragon_laddie",
		"blend": "high-altitude spy body + sailplane wings",
		"agility": 0.75, "armor": 8, "gun": 0.0, "missiles": 0, "locks": 0, "lock_time": 1.0,
		"flare_cd": 2.0, "boost": 0.0, "hitbox": Vector2(12, 12),
		"burst": 0, "fire": 99.0, "missile_every": 99.0, "paint": Color(0.16, 0.17, 0.19),
		"blurb": "Armament: one camera. Defence: being very high up, allegedly.",
	},
	"butterknife": {
		"name": "68-F Butterknife", "maker": "North Amerigan", "shape": "butterknife",
		"blend": "early swept-wing nose-intake fighter + a longer swept wing",
		"agility": 1.0, "armor": 10, "gun": 0.085, "missiles": 2, "locks": 1, "lock_time": 0.4,
		"flare_cd": 3.0, "boost": 0.0, "hitbox": Vector2(12, 13),
		"burst": 5, "fire": 2.4, "missile_every": 12.0,
		"blurb": "Six machine guns and a can-do attitude.",
	},
	"fishcake": {
		"name": "MyG-51 Fishcake", "maker": "Mikoyanov", "shape": "fishcake",
		"blend": "high swept tail + barrel-shaped fuselage",
		"agility": 1.0, "armor": 9, "gun": 0.12, "missiles": 0, "locks": 0, "lock_time": 1.0,
		"flare_cd": 3.0, "boost": 0.0, "hitbox": Vector2(12, 12),
		"burst": 3, "fire": 2.0, "missile_every": 0.0,
		"blurb": "Big cannons, small manners.",
	},
	"blackbirb": {
		"name": "RS-17 Blackbirb", "maker": "Lockjaw Skunkery", "shape": "blackbirb",
		"blend": "chined Mach-3 spy body + mid-wing engine nacelles",
		"agility": 0.8, "armor": 9, "gun": 0.0, "missiles": 0, "locks": 0, "lock_time": 1.0,
		"flare_cd": 2.5, "boost": 300.0, "hitbox": Vector2(13, 18),
		"burst": 0, "fire": 99.0, "missile_every": 99.0, "paint": Color(0.06, 0.06, 0.08),
		"blurb": "Armament: none. Defence: being somewhere else, quickly.",
	},
	"pigeon": {
		"name": "PF-61 Fighting Pigeon", "maker": "Lockjaw Marvin", "shape": "pigeon",
		"blend": "lightweight belly-intake fighter + small canards",
		"agility": 1.1, "armor": 11, "gun": 0.075, "missiles": 4, "locks": 2, "lock_time": 0.35,
		"flare_cd": 2.5, "boost": 0.0, "hitbox": Vector2(12, 14),
		"burst": 5, "fire": 2.2, "missile_every": 8.0,
		"blurb": "Agile, sleek, and very proud of it. Coos under heavy g.",
	},
	"tuba": {
		"name": "UT-59 Tuba Grizzly", "maker": "Tupolove", "shape": "tuba",
		"blend": "contra-prop strategic bomber + long swept heavy-bomber wing",
		"agility": 0.3, "armor": 150, "gun": 0.1, "missiles": 0, "locks": 0, "lock_time": 1.0,
		"flare_cd": 4.0, "boost": 0.0, "hitbox": Vector2(64, 38),
		"burst": 6, "fire": 1.0, "missile_every": 0.0,
		"blurb": "Loud enough to hear from orbit. Has tail guns and feelings.",
	},
	"hawkward": {
		"name": "Hawkward Poacher", "maker": "Hawkward", "shape": "hawkward",
		"blend": "wing-root intakes + mid-set swept tail",
		"agility": 1.0, "armor": 10, "gun": 0.09, "missiles": 2, "locks": 1, "lock_time": 0.45,
		"flare_cd": 3.0, "boost": 0.0, "hitbox": Vector2(12, 13),
		"burst": 4, "fire": 2.3, "missile_every": 14.0,
		"blurb": "Graceful, reliable, slightly apologetic.",
	},
	"midge": {
		"name": "Fallin' Midge", "maker": "Fallin'", "shape": "midge",
		"blend": "tiny lightweight fighter, shrunk in the wash",
		"agility": 1.35, "armor": 7, "gun": 0.07, "missiles": 2, "locks": 2, "lock_time": 0.3,
		"flare_cd": 2.2, "boost": 0.0, "hitbox": Vector2(8, 10),
		"burst": 4, "fire": 2.0, "missile_every": 12.0,
		"blurb": "So small the enemy keeps checking its windscreen for bugs.",
	},
	"starfrighter": {
		"name": "401-F Starfrighter", "maker": "Lockjaw", "shape": "starfrighter",
		"blend": "needle-nosed T-tail interceptor with stub wings",
		"agility": 0.8, "armor": 9, "gun": 0.08, "missiles": 2, "locks": 2, "lock_time": 0.4,
		"flare_cd": 3.0, "boost": 0.0, "hitbox": Vector2(10, 16),
		"burst": 4, "fire": 2.4, "missile_every": 6.0,
		"blurb": "A missile with a man in it, as the brochure said.",
	},
	"raffle": {
		"name": "Dassalt Raffle", "maker": "Dassalt", "shape": "raffle",
		"blend": "close-coupled canard delta + chin intakes",
		"agility": 1.05, "armor": 12, "gun": 0.08, "missiles": 8, "locks": 4, "lock_time": 0.3,
		"flare_cd": 2.0, "boost": 0.0, "hitbox": Vector2(12, 14),
		"burst": 4, "fire": 2.4, "missile_every": 5.0,
		"blurb": "Every ticket's a winner. Some assembly delays.",
	},
	"vigdragon": {
		"name": "C-01J Mildly Vigorous Dragon", "maker": "Dragonia Aero", "shape": "vigdragon",
		"blend": "single-engine canard delta + belly intake",
		"agility": 1.05, "armor": 12, "gun": 0.08, "missiles": 8, "locks": 4, "lock_time": 0.3,
		"flare_cd": 2.0, "boost": 0.0, "hitbox": Vector2(12, 14),
		"burst": 4, "fire": 2.4, "missile_every": 5.0,
		"blurb": "Some assembly required. Instructions in three languages, none yours.",
	},
}


static func get_jet(id: String) -> Dictionary:
	return JETS.get(id, JETS.fishbowl)


## How tough a jet is when the AI flies it.
static func enemy_hp(j: Dictionary) -> int:
	var a := int(j.armor)
	return a if a > 50 else int(ceil(a / 3.0))


## Briefing-card pips (out of 5) derived from the numbers.
static func pips(id: String) -> Dictionary:
	var j := get_jet(id)
	var gun: float = j.gun
	return {
		"Agility": clampi(int(round(float(j.agility) * 4.0 - 1.0)), 1, 5),
		"Armor": clampi(int(round(float(j.armor) / 2.5)), 1, 5),
		"Cannon": 0 if gun <= 0.0 else clampi(int(round(0.5 / gun)), 1, 5),
		"Missiles": clampi(int(j.missiles) / 2 + (1 if int(j.missiles) > 0 else 0), 0, 5),
		"Flares": clampi(int(round(9.0 / float(j.flare_cd))), 1, 5),
	}
