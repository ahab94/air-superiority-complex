extends RefCounted
## Mission data. Each mission is a dictionary; sim.gd reads the gameplay keys,
## scene3d.gd the look (terrain, light, weather), and game.gd the story.
##
## Waves are lists of squadrons (see sim.gd _start_wave). Optional rules
## (wind, flak, SAM sites, photos, sanctuary...) are listed at the top of sim.gd.
##
## Every jet, country and maker name is made up; designations are flipped
## parodies, and every jet blends 2-3 jet types (jets.gd).
## Real history appears only in "real_story". Bordaria and Borderia are
## satirised equally: every joke at one has a twin aimed at the other.
##
## Look keys: terrain = ocean | steppe | winter | desert | arctic | plains |
## jungle | mountains;  light = day | dusk | overcast | storm | night | arctic;
## weather = none | snow | rain | dust.

const CHAPTERS := [
	"Cold War, Cold Feet",
	"Subcontinental Drift",
	"Greatest Hits",
	"Not Technically Dogfights",
]

const LIST := [
	# ------------------------------------------------------------------ 1
	{
		"id": "foxbrat_express", "chapter": 0, "name": "Foxbrat Express", "year": 1976,
		"country": "Bearovia (allegedly)", "jet_id": "foxbrat", "enemy_jet": "fishbowl",
		"terrain": "ocean", "light": "day", "weather": "none",
		"quote": "So there I am, Bearovia, '76. Fastest jet on Earth, fuel tank of a lawnmower. And I just... keep flying east.",
		"goal_text": "Shake off the interceptors, then land on the Sunrise Isles airstrip before the tank runs dry.",
		"new": "Fuel, cannons, lock-on missiles, flares",
		"real_story": "In 1976 a pilot defected in his country's secret new interceptor, flying it low across the sea to a neighbouring island nation and landing with almost no fuel left. Engineers took the jet apart to study it, then shipped it back home in crates.",
		"bartender": "Sure, Ace. And I'm the King of Brollytain.",
		"fail": {"flameout": "Out of fuel. The Foxbrat makes a lovely glider for about four seconds.",
			"overrun": "The interceptors flew right past you. Awkward.", "shot_down": "Ace hits the silk. The bartender perks up."},
		"goal": "land", "seed": 1976, "fuel": 100.0, "fuel_rate": 0.6, "lives": 3, "max_bombs": 28,
		"clouds": [Vector2(96, 548), Vector2(240, 548), Vector2(384, 548)],
		"waves": [
			[
				{"shape": "vic3", "kind": "C", "x": 110, "y": 130, "move": "weave", "amp": 40, "freq": 1.0},
				{"shape": "vic3", "kind": "C", "x": 370, "y": 130, "move": "weave", "amp": 40, "freq": 1.0, "phase": PI, "delay": 0.4},
				{"shape": "pair", "kind": "B", "x": 240, "y": 210, "move": "weave", "amp": 120, "freq": 0.6, "delay": 1.2},
			],
			[
				{"shape": "vic5", "kind": "B", "x": 240, "y": 120, "move": "figure8", "amp": 110, "freq": 0.55},
				{"shape": "line4", "kind": "C", "x": 240, "y": 230, "move": "weave", "amp": 90, "freq": 0.45, "delay": 1.0, "phase": 1.5},
			],
			[
				{"shape": "echelon4", "kind": "A", "x": 140, "y": 140, "move": "weave", "amp": 70, "freq": 0.5},
				{"shape": "echelon4l", "kind": "A", "x": 340, "y": 140, "move": "weave", "amp": 70, "freq": 0.5, "phase": PI, "delay": 0.3},
				{"shape": "box4", "kind": "B", "x": 240, "y": 250, "move": "figure8", "amp": 100, "freq": 0.7, "delay": 1.4},
			],
		],
	},
	# ------------------------------------------------------------------ 2
	{
		"id": "spy_in_the_sky", "chapter": 0, "name": "Spy-in-the-Sky", "year": 1960,
		"country": "Amerigo (officially: a weather agency)", "jet_id": "dragon_laddie", "enemy_jet": "fishbowl",
		"terrain": "steppe", "light": "day", "weather": "none",
		"quote": "No guns, no missiles, one camera. They told me nothing down there could reach that high. They told me a lot of things.",
		"goal_text": "Fly over at least 4 of the 6 sites to photograph them. Missile sites on the ground will try to change your plans. Survive 70 seconds.",
		"new": "Unarmed spy jet, ground missile sites, photo targets",
		"real_story": "In 1960 a spy plane flying higher than anyone thought could be reached was brought down by ground-launched missiles deep inside the country it was photographing. The pilot survived, and a summit between two superpowers collapsed weeks later.",
		"bartender": "So the 'weather plane' took 400 photos of a missile factory.",
		"fail": {"photos": "Lovely flight. Lovely clouds. Not one useful photo.", "shot_down": "Ace parachutes into a very awkward conversation."},
		"goal": "survive", "duration": 70.0, "seed": 1960, "lives": 3,
		"sams": {"every": 3.0, "range": 430.0, "shots": 1},
		"photos": {"count": 6, "need": 4, "every": 10.0, "start": 4.0},
		"waves": [],
	},
	# ------------------------------------------------------------------ 3
	{
		"id": "butterknife_alley", "chapter": 0, "name": "Butterknife Alley", "year": 1951,
		"country": "Amerigo", "jet_id": "butterknife", "enemy_jet": "fishcake",
		"terrain": "winter", "light": "overcast", "weather": "snow",
		"quote": "Rule one: never cross the river. Rule two: they know rule one.",
		"goal_text": "Clear three waves of Fishcakes. They hide across the river on the left, where you're not allowed to shoot. Catch them when they come out.",
		"new": "Sanctuary river: no shooting across it",
		"real_story": "In a war in the early 1950s, one side's jets flew from bases across a border river that the other side's pilots were ordered never to cross. The corner of sky where they met got a nickname of its own.",
		"bartender": "So they just sat on the other side and waved?",
		"fail": {"overrun": "They came out of the sanctuary and kept going.", "shot_down": "Ace hits the silk. In January. Over a river."},
		"goal": "clear", "seed": 1951, "lives": 3, "sanctuary_x": 110.0,
		"waves": [
			[
				{"shape": "vic3", "kind": "C", "x": 170, "y": 140, "move": "weave", "amp": 90, "freq": 0.6},
				{"shape": "pair", "kind": "C", "x": 330, "y": 200, "move": "weave", "amp": 70, "freq": 0.8, "delay": 0.8},
			],
			[
				{"shape": "finger4", "kind": "B", "x": 190, "y": 130, "move": "figure8", "amp": 110, "freq": 0.5},
				{"shape": "vic3", "kind": "C", "x": 320, "y": 230, "move": "weave", "amp": 80, "freq": 0.7, "phase": 2.0, "delay": 1.0},
			],
			[
				{"shape": "echelon4", "kind": "A", "x": 200, "y": 150, "move": "weave", "amp": 110, "freq": 0.45},
				{"shape": "box4", "kind": "B", "x": 320, "y": 250, "move": "figure8", "amp": 80, "freq": 0.6, "delay": 1.2},
			],
			[
				{"shape": "vic5", "kind": "A", "x": 180, "y": 130, "move": "figure8", "amp": 100, "freq": 0.45},
				{"shape": "finger4", "kind": "A", "x": 300, "y": 240, "move": "weave", "amp": 100, "freq": 0.55, "phase": 1.0, "delay": 1.5},
			],
		],
	},
	# ------------------------------------------------------------------ 4
	{
		"id": "speed_check", "chapter": 0, "name": "Speed Check", "year": 1979,
		"country": "Amerigo", "jet_id": "blackbirb", "enemy_jet": "fishbowl",
		"terrain": "desert", "light": "dusk", "weather": "dust",
		"quote": "Some hotshot on the radio asks for a ground-speed check. So I ask for one too. Then I ask them to wait while I go faster.",
		"goal_text": "No weapons. Push forward (W / Up) to light the afterburners and outrun missiles, but watch the engine heat. Survive 60 seconds over the canyons.",
		"new": "Afterburner boost and engine heat",
		"real_story": "One real spy jet of that era flew so fast and so high that its crews' answer to a missile launch was simply to speed up, and none was ever shot down. Pilots still tell of a crew asking air traffic control for a ground-speed check, just to top another pilot who'd asked first.",
		"bartender": "Ground speed? You were sitting on that stool for an hour.",
		"fail": {"shot_down": "Turns out you can be somewhere else too slowly."},
		"goal": "survive", "duration": 60.0, "seed": 1979, "lives": 3,
		"sams": {"every": 3.4, "range": 430.0, "shots": 1},
		"waves": [
			[
				{"shape": "pair", "kind": "C", "x": 150, "y": 130, "move": "weave", "amp": 80, "freq": 0.6, "fire": 3.4, "missile_every": 99.0},
				{"shape": "pair", "kind": "C", "x": 330, "y": 160, "move": "weave", "amp": 80, "freq": 0.6, "phase": PI, "fire": 3.4, "missile_every": 99.0, "delay": 6.0},
			],
		],
	},
	# ------------------------------------------------------------------ 5
	{
		"id": "bear_necessities", "chapter": 0, "name": "Grin and Bear It", "year": 1985,
		"country": "Amerigo", "jet_id": "pigeon", "enemy_jet": "fishbowl",
		"terrain": "arctic", "light": "arctic", "weather": "snow",
		"quote": "The Tuba Grizzly comes by every Tuesday. Usually you wave. This Tuesday it brought friends with guns.",
		"goal_text": "Ice on the wings: your jet slides. Clear the escorts, then bring down the Tuba Grizzly. Missiles only dent it.",
		"new": "Icing (sliding controls) and a boss",
		"real_story": "For decades, big long-range propeller bombers have flown close to other countries' airspace, and fighters are sent up to escort them away. The meetings are usually polite. Pilots on both sides have been photographed waving.",
		"bartender": "You shot down the Tuesday Grizzly? Who's going to wave at us now?",
		"fail": {"overrun": "The Grizzly just kept going. It does that.", "shot_down": "Ace ejects into the Arctic. Brisk."},
		"goal": "clear", "seed": 1985, "lives": 3, "icing": true, "max_bombs": 36,
		"waves": [
			[
				{"shape": "vic3", "kind": "C", "x": 140, "y": 140, "move": "weave", "amp": 60, "freq": 0.7},
				{"shape": "vic3", "kind": "C", "x": 340, "y": 140, "move": "weave", "amp": 60, "freq": 0.7, "phase": PI, "delay": 0.5},
			],
			[
				{"shape": "finger4", "kind": "B", "x": 200, "y": 140, "move": "figure8", "amp": 100, "freq": 0.5},
				{"shape": "pair", "kind": "B", "x": 330, "y": 240, "move": "weave", "amp": 80, "freq": 0.8, "delay": 1.0},
			],
			[
				{"boss": true, "jet": "tuba", "kind": "A", "x": 240, "y": 170, "move": "weave", "amp": 70, "freq": 0.3, "descent": 1.0, "fire": 0.8},
				{"shape": "pair", "kind": "B", "x": 120, "y": 290, "move": "weave", "amp": 60, "freq": 0.9, "delay": 2.0},
				{"shape": "pair", "kind": "B", "x": 360, "y": 290, "move": "weave", "amp": 60, "freq": 0.9, "phase": PI, "delay": 2.5},
			],
		],
	},
	# ------------------------------------------------------------------ 6
	{
		"id": "five_in_a_minute", "chapter": 1, "name": "Five in a Minute", "year": 1965,
		"country": "Borderia", "enemy_country": "Bordaria", "jet_id": "butterknife", "enemy_jet": "hawkward",
		"terrain": "plains", "light": "day", "weather": "dust",
		"quote": "Monday I fly for Borderia. Tuesday for Bordaria. I don't take sides, I take cheques. This was a Monday.",
		"goal_text": "Flak from the airbase below bursts where the rings show: keep moving. Down 5 jets fast for a bonus. The Ministry of Claims will count them for you.",
		"new": "Ground flak, combo bonus, Kills vs Claimed",
		"real_story": "In a 1965 border war, one air force credited its pilot with downing five enemy jets in under a minute. The other side's records list fewer losses that day. Both still tell the story differently.",
		"bartender": "Five in a minute. I've heard it's two. I've heard it's nine.",
		"fail": {"overrun": "They overflew the airbase. The airbase has filed a complaint.", "shot_down": "Ace hits the silk. Both ministries claim him."},
		"goal": "clear", "seed": 1965, "lives": 3, "claims": true,
		"flak": {"every": 1.9, "radius": 30.0, "warn": 1.0, "dmg": 2, "spread": 70.0},
		"combo": {"window": 12.0, "need": 5, "bonus": 1500},
		"waves": [
			[
				{"shape": "line4", "kind": "C", "x": 240, "y": 140, "move": "weave", "amp": 80, "freq": 0.6},
				{"shape": "pair", "kind": "C", "x": 130, "y": 230, "move": "weave", "amp": 50, "freq": 1.0, "delay": 0.8},
				{"shape": "pair", "kind": "C", "x": 350, "y": 230, "move": "weave", "amp": 50, "freq": 1.0, "phase": PI, "delay": 1.0},
			],
			[
				{"shape": "vic5", "kind": "B", "x": 240, "y": 130, "move": "weave", "amp": 100, "freq": 0.5},
				{"shape": "line3", "kind": "C", "x": 240, "y": 240, "move": "figure8", "amp": 100, "freq": 0.55, "delay": 1.0},
			],
			[
				{"shape": "finger4", "kind": "A", "x": 160, "y": 140, "move": "figure8", "amp": 80, "freq": 0.5},
				{"shape": "finger4", "kind": "B", "x": 320, "y": 220, "move": "weave", "amp": 80, "freq": 0.6, "phase": PI, "delay": 1.0},
			],
		],
	},
	# ------------------------------------------------------------------ 7
	{
		"id": "midge_attack", "chapter": 1, "name": "Midge Attack", "year": 1971,
		"country": "Bordaria", "enemy_country": "Borderia", "jet_id": "midge", "enemy_jet": "butterknife",
		"terrain": "jungle", "light": "storm", "weather": "rain",
		"quote": "Tuesday. Bordaria hands me a jet the size of a coffee table and points at the monsoon.",
		"goal_text": "Monsoon gusts shove you sideways. Your Midge is tiny and nimble: hard to hit, quick to fire, not very tough.",
		"new": "Monsoon wind and turbulence, a tiny jet",
		"real_story": "In the 1965 and 1971 wars, a tiny, cheap fighter earned a giant-killer reputation against bigger, heavier jets, including a famous fight over a river delta in late 1971. The other side disputes some of the claims.",
		"bartender": "A jet the size of a coffee table. In a monsoon. Sure.",
		"fail": {"overrun": "Lost in the rain. They found you, though.", "shot_down": "The Midge goes down like, well, a midge."},
		"goal": "clear", "seed": 1971, "lives": 3, "claims": true,
		"wind": {"base": 0.0, "gust": 75.0, "period": 5.0, "turb": 30.0},
		"waves": [
			[
				{"shape": "vic3", "kind": "C", "x": 150, "y": 150, "move": "weave", "amp": 70, "freq": 0.7},
				{"shape": "vic3", "kind": "C", "x": 330, "y": 150, "move": "weave", "amp": 70, "freq": 0.7, "phase": PI, "delay": 0.6},
			],
			[
				{"shape": "finger4", "kind": "B", "x": 200, "y": 140, "move": "figure8", "amp": 100, "freq": 0.5},
				{"shape": "pair", "kind": "B", "x": 340, "y": 240, "move": "weave", "amp": 70, "freq": 0.9, "delay": 1.0},
			],
			[
				{"shape": "box4", "kind": "A", "x": 160, "y": 150, "move": "weave", "amp": 80, "freq": 0.55},
				{"shape": "box4", "kind": "B", "x": 320, "y": 230, "move": "weave", "amp": 80, "freq": 0.55, "phase": PI, "delay": 1.2},
			],
			[
				{"shape": "vic5", "kind": "A", "x": 240, "y": 130, "move": "figure8", "amp": 110, "freq": 0.5},
				{"shape": "finger4", "kind": "A", "x": 240, "y": 240, "move": "weave", "amp": 100, "freq": 0.6, "phase": 1.0, "delay": 1.4},
			],
		],
	},
	# ------------------------------------------------------------------ 8
	{
		"id": "starfrighter", "chapter": 1, "name": "Starfrighter", "year": 1971,
		"country": "Bordaria", "enemy_country": "Borderia", "jet_id": "fishbowl", "enemy_jet": "starfrighter",
		"terrain": "desert", "light": "night", "weather": "none",
		"quote": "A night over the sand sea. Their Starfrighters carry more heat-seekers than sense. Bring flares.",
		"goal_text": "Night over the desert. Starfrighters lock on often: watch for MISSILE LOCK and keep your flares ready.",
		"new": "Night fighting, frequent heat-seekers",
		"real_story": "In 1971 the two neighbours' jets met over the desert front in some of the region's first supersonic dogfights. Both air forces claim to have come out ahead.",
		"bartender": "In the dark? How do you know you won?",
		"fail": {"overrun": "They slipped past in the dark.", "shot_down": "Ace parachutes into the desert. At night. With no coffee."},
		"goal": "clear", "seed": 1972, "lives": 3, "claims": true, "enemy_missiles": 2, "missile_every": 4.5,
		"waves": [
			[
				{"shape": "pair", "kind": "C", "x": 140, "y": 150, "move": "weave", "amp": 70, "freq": 0.7},
				{"shape": "pair", "kind": "C", "x": 340, "y": 150, "move": "weave", "amp": 70, "freq": 0.7, "phase": PI, "delay": 0.5},
				{"shape": "pair", "kind": "C", "x": 240, "y": 240, "move": "figure8", "amp": 100, "freq": 0.5, "delay": 1.0},
			],
			[
				{"shape": "vic5", "kind": "B", "x": 240, "y": 140, "move": "weave", "amp": 100, "freq": 0.5},
				{"shape": "pair", "kind": "B", "x": 240, "y": 250, "move": "weave", "amp": 140, "freq": 0.6, "delay": 1.0},
			],
			[
				{"shape": "echelon4", "kind": "A", "x": 150, "y": 150, "move": "weave", "amp": 70, "freq": 0.5},
				{"shape": "echelon4l", "kind": "A", "x": 330, "y": 150, "move": "weave", "amp": 70, "freq": 0.5, "phase": PI, "delay": 0.4},
			],
			[
				{"shape": "box4", "kind": "A", "x": 160, "y": 140, "move": "figure8", "amp": 80, "freq": 0.5},
				{"shape": "box4", "kind": "A", "x": 320, "y": 230, "move": "weave", "amp": 80, "freq": 0.55, "phase": PI, "delay": 1.2},
			],
		],
	},
	# ------------------------------------------------------------------ 9
	{
		"id": "coffee_two_sugars", "chapter": 1, "name": "Coffee, Two Sugars", "year": 2019,
		"country": "Bordaria", "enemy_country": "Borderia", "jet_id": "fishbowl", "enemy_jet": "pigeon",
		"terrain": "mountains", "light": "day", "weather": "snow",
		"quote": "I'm flying wing for Squadron Leader Biscuit. Old jet, older jokes. The mountains are doing something to the air.",
		"goal_text": "Mountain winds bump you around. If you're shot down, steer your parachute (left/right) home to the left half. Land on the right half and you're staying for coffee.",
		"new": "Mountain turbulence, steer your parachute",
		"real_story": "In 2019 a pilot was shot down on the far side of a disputed line after a dogfight. He was held, filmed politely complimenting his hosts' hospitality, and handed back two days later. Each side still disputes what else was shot down that day.",
		"bartender": "And the coffee? ... Two sugars, I bet.",
		"fail": {"overrun": "They flew straight over the peaks and home for dinner.", "shot_down": "Out of jets. Out of biscuits."},
		"goal": "clear", "seed": 2019, "lives": 3, "claims": true, "tea": true, "home": "left",
		"wind": {"base": 10.0, "gust": 45.0, "period": 7.0, "turb": 70.0},
		"waves": [
			[
				{"shape": "pair", "kind": "C", "x": 150, "y": 150, "move": "weave", "amp": 70, "freq": 0.7},
				{"shape": "pair", "kind": "C", "x": 330, "y": 170, "move": "weave", "amp": 70, "freq": 0.7, "phase": PI, "delay": 0.6},
			],
			[
				{"shape": "finger4", "kind": "B", "x": 220, "y": 150, "move": "figure8", "amp": 100, "freq": 0.5},
			],
			[
				{"shape": "vic3", "kind": "A", "x": 150, "y": 150, "move": "weave", "amp": 80, "freq": 0.6},
				{"shape": "vic3", "kind": "A", "x": 330, "y": 210, "move": "weave", "amp": 80, "freq": 0.6, "phase": PI, "delay": 1.0},
			],
			[
				{"shape": "finger4", "kind": "A", "x": 180, "y": 140, "move": "figure8", "amp": 100, "freq": 0.5},
				{"shape": "finger4", "kind": "A", "x": 300, "y": 240, "move": "weave", "amp": 90, "freq": 0.6, "phase": 2.0, "delay": 1.4},
			],
		],
	},
	# ------------------------------------------------------------------ 10
	{
		"id": "beyond_visual_reason", "chapter": 1, "name": "Beyond Visual Reason", "year": 2025,
		"country": "Bordaria", "enemy_country": "Borderia", "jet_id": "raffle", "enemy_jet": "vigdragon",
		"terrain": "plains", "light": "night", "weather": "none",
		"quote": "The biggest air battle in decades and nobody crossed the line. Everybody fired across it. I flew for both sides. It was a long night.",
		"goal_text": "Nobody crosses the Line: it's missiles only. Lock and fire (hold Shift), flare their missiles, and halfway through... you'll see.",
		"new": "A missile-only duel across the Line, and a change of sides",
		"real_story": "In 2025 two neighbouring air forces fought one of the largest air battles in decades, by many accounts involving over 100 jets, nearly all firing long-range missiles from their own side of the border. Both sides claimed victory, and the losses are still disputed.",
		"bartender": "So who won? ... Both. Obviously.",
		"fail": {"shot_down": "Ace hits the silk. Both ministries issue a statement."},
		"goal": "clear", "seed": 2025, "lives": 4, "claims": true,
		"bvr_line": 300.0, "enemy_guns": false, "player_guns": false, "rearm_each_wave": true,
		"enemy_missiles": 2, "missile_every": 3.2,
		"switch": {"wave": 2, "jet_id": "vigdragon", "enemy_jet": "raffle",
			"banner": "Contract renegotiated. Ace now flies for Borderia."},
		"waves": [
			[
				{"shape": "line4", "kind": "C", "x": 240, "y": 120, "move": "weave", "amp": 80, "freq": 0.5},
				{"shape": "pair", "kind": "C", "x": 240, "y": 210, "move": "weave", "amp": 140, "freq": 0.4, "delay": 1.0},
			],
			[
				{"shape": "vic5", "kind": "B", "x": 240, "y": 130, "move": "figure8", "amp": 90, "freq": 0.45},
				{"shape": "pair", "kind": "B", "x": 240, "y": 220, "move": "weave", "amp": 150, "freq": 0.5, "delay": 1.0},
			],
			[
				{"shape": "line4", "kind": "B", "x": 240, "y": 120, "move": "weave", "amp": 80, "freq": 0.5},
				{"shape": "pair", "kind": "B", "x": 240, "y": 210, "move": "weave", "amp": 140, "freq": 0.4, "delay": 1.0},
			],
			[
				{"shape": "finger4", "kind": "A", "x": 200, "y": 130, "move": "figure8", "amp": 90, "freq": 0.45},
				{"shape": "finger4", "kind": "A", "x": 280, "y": 230, "move": "weave", "amp": 100, "freq": 0.5, "phase": PI, "delay": 1.2},
			],
		],
	},	# ------------------------------------------------------------------ 11
	{
		"id": "operation_bowlo", "chapter": 2, "name": "Operation Bowl-o", "year": 1967,
		"country": "Amerigo", "jet_id": "fantom", "enemy_jet": "fishbowl",
		"terrain": "jungle", "light": "day", "weather": "none",
		"quote": "We copied the bombers' route, their radio chatter, their bad jokes. Then we waited for someone to fall for it.",
		"goal_text": "You look like a slow bomber. They'll close in without firing: hold fire until they're close, then open up for double points. Shoot too early and the trick is wasted.",
		"new": "Disguise: lure them in, then ambush",
		"real_story": "In 1967 a fighter wing flew a mission copying the routes, speeds and radio calls of slower bombers, so enemy fighters would climb up expecting easy prey. They met fighters instead.",
		"bartender": "So you dressed up as a bomber. On purpose.",
		"fail": {"overrun": "They got so close they could read your fake call sign.", "shot_down": "The disguise worked a bit too well."},
		"goal": "clear", "seed": 1967, "lives": 3, "disguise": true,
		"waves": [
			[
				{"shape": "vic3", "kind": "C", "x": 150, "y": 110, "move": "weave", "amp": 50, "freq": 0.7},
				{"shape": "vic3", "kind": "C", "x": 330, "y": 110, "move": "weave", "amp": 50, "freq": 0.7, "phase": PI, "delay": 0.4},
			],
			[
				{"shape": "finger4", "kind": "B", "x": 200, "y": 110, "move": "figure8", "amp": 90, "freq": 0.5},
				{"shape": "pair", "kind": "B", "x": 330, "y": 170, "move": "weave", "amp": 70, "freq": 0.8, "delay": 0.8},
			],
			[
				{"shape": "vic5", "kind": "A", "x": 240, "y": 100, "move": "weave", "amp": 110, "freq": 0.45},
				{"shape": "pair", "kind": "A", "x": 240, "y": 190, "move": "weave", "amp": 150, "freq": 0.6, "delay": 1.0},
			],
		],
	},
	# ------------------------------------------------------------------ 12
	{
		"id": "ace_who_wasnt", "chapter": 2, "name": "The Ace Who Wasn't", "year": 1972,
		"country": "Amerigo", "jet_id": "fantom", "enemy_jet": "fishbowl",
		"terrain": "karst", "light": "overcast", "weather": "none",
		"quote": "Everyone had a story about Colonel Nobody. Thirteen kills. No photo. No name. Flies out of the mist and vanishes back into it.",
		"goal_text": "Colonel Nobody blinks in and out of existence. He can only be hit while he's solid. Clear his wingmen, then pin him down.",
		"new": "A phantom ace who fades in and out",
		"real_story": "During one long war, pilots told stories of a legendary enemy ace with a dozen kills. Historians later concluded he was probably a composite of several pilots, or never existed at all.",
		"bartender": "You shot down a pilot who didn't exist?",
		"fail": {"overrun": "They vanished into the mist. Very on brand.", "shot_down": "Shot down by a rumour. Embarrassing."},
		"goal": "clear", "seed": 1972, "lives": 3,
		"waves": [
			[
				{"shape": "vic3", "kind": "C", "x": 160, "y": 140, "move": "weave", "amp": 60, "freq": 0.7},
				{"shape": "vic3", "kind": "C", "x": 320, "y": 200, "move": "weave", "amp": 60, "freq": 0.7, "phase": PI, "delay": 0.5},
			],
			[
				{"shape": "finger4", "kind": "B", "x": 220, "y": 130, "move": "figure8", "amp": 100, "freq": 0.5},
				{"shape": "solo", "kind": "A", "x": 240, "y": 230, "move": "weave", "amp": 120, "freq": 0.6, "phantom": true, "fire": 1.4, "delay": 1.0},
			],
			[
				{"shape": "solo", "kind": "A", "x": 240, "y": 170, "move": "figure8", "amp": 140, "freq": 0.5, "phantom": true, "fire": 1.1},
				{"shape": "pair", "kind": "B", "x": 150, "y": 260, "move": "weave", "amp": 60, "freq": 0.9, "delay": 1.5},
				{"shape": "pair", "kind": "B", "x": 330, "y": 260, "move": "weave", "amp": 60, "freq": 0.9, "phase": PI, "delay": 2.0},
			],
		],
	},
	# ------------------------------------------------------------------ 13
	{
		"id": "a_line_allegedly", "chapter": 2, "name": "A Line, Allegedly", "year": 1981,
		"country": "Amerigo", "jet_id": "tomkitten", "enemy_jet": "fitterbug",
		"terrain": "ocean", "light": "dusk", "weather": "none",
		"quote": "Somebody drew a line across the sea and called it a border. Our orders: fly right up to it, and don't shoot first.",
		"goal_text": "Rules of engagement: WEAPONS HOLD until they fire first. Then it's fair game. Shoot early three times and you're court-martialled.",
		"new": "Rules of engagement: they must fire first",
		"real_story": "In 1981 a coastal state claimed a line far out at sea as its border. When two of its jets fired on patrolling carrier fighters, the fighters shot both down within about a minute.",
		"bartender": "They shot first? At you? Bold.",
		"fail": {"roe": "Court-martialled. You fired first. Three times.", "overrun": "They crossed the line. Then crossed you.", "shot_down": "Shot down while politely waiting your turn."},
		"goal": "clear", "seed": 1981, "lives": 3, "roe": true,
		"waves": [
			[
				{"shape": "pair", "kind": "C", "x": 180, "y": 150, "move": "weave", "amp": 60, "freq": 0.6},
				{"shape": "pair", "kind": "C", "x": 320, "y": 190, "move": "weave", "amp": 60, "freq": 0.6, "phase": PI, "delay": 0.4},
			],
			[
				{"shape": "vic3", "kind": "B", "x": 160, "y": 140, "move": "weave", "amp": 70, "freq": 0.6},
				{"shape": "vic3", "kind": "B", "x": 320, "y": 200, "move": "weave", "amp": 70, "freq": 0.6, "phase": PI, "delay": 0.6},
			],
			[
				{"shape": "finger4", "kind": "A", "x": 200, "y": 140, "move": "figure8", "amp": 100, "freq": 0.5},
				{"shape": "pair", "kind": "A", "x": 300, "y": 230, "move": "weave", "amp": 90, "freq": 0.7, "delay": 1.0},
			],
		],
	},
	# ------------------------------------------------------------------ 14
	{
		"id": "sea_harrumph", "chapter": 2, "name": "Sea Harrumph", "year": 1982,
		"country": "Great Brollytain", "jet_id": "harrumph", "enemy_jet": "mirth",
		"terrain": "ocean", "light": "storm", "weather": "rain",
		"quote": "Eight thousand miles from home, in a jet that can stop in mid-air. Their jets were faster. They also came from behind.",
		"goal_text": "Some squadrons climb up from BEHIND and shoot forward. Pull back (S / Down) to air-brake: they overshoot into your guns.",
		"new": "Attacks from behind; air-brake to make them overshoot",
		"real_story": "In 1982 small jump-jet fighters flying from carriers fought faster jets a very long way from home, and won almost every encounter. The famous trick of braking in mid-air to make a chaser overshoot was mostly a legend: their missiles did the work.",
		"bartender": "You stopped. In the air. And they just flew past?",
		"fail": {"overrun": "They flew past. Then kept flying past.", "shot_down": "Ace parachutes into the South Atlantic. In winter."},
		"goal": "clear", "seed": 1982, "lives": 3,
		"wind": {"base": 0.0, "gust": 40.0, "period": 6.0, "turb": 20.0},
		"waves": [
			[
				{"shape": "vic3", "kind": "C", "x": 240, "y": 140, "move": "weave", "amp": 80, "freq": 0.6},
				{"shape": "pair", "kind": "C", "x": 160, "y": 0, "move": "weave", "amp": 50, "freq": 0.8, "from": "behind", "delay": 2.0},
			],
			[
				{"shape": "pair", "kind": "B", "x": 320, "y": 0, "move": "weave", "amp": 60, "freq": 0.8, "from": "behind"},
				{"shape": "pair", "kind": "B", "x": 150, "y": 0, "move": "weave", "amp": 60, "freq": 0.8, "from": "behind", "delay": 2.5},
				{"shape": "vic3", "kind": "B", "x": 240, "y": 150, "move": "figure8", "amp": 90, "freq": 0.5, "delay": 1.0},
			],
			[
				{"shape": "vic3", "kind": "A", "x": 240, "y": 0, "move": "weave", "amp": 70, "freq": 0.6, "from": "behind"},
				{"shape": "finger4", "kind": "A", "x": 220, "y": 140, "move": "weave", "amp": 90, "freq": 0.5, "delay": 1.5},
			],
		],
	},
	# ------------------------------------------------------------------ 15
	{
		"id": "kill_chain", "chapter": 2, "name": "The Kill Chain", "year": 2026,
		"country": "Amerigo", "jet_id": "eventually", "enemy_jet": "vigdragon",
		"terrain": "cloudsea", "light": "day", "weather": "none",
		"quote": "A: the radar plane sees you. B: its fighters hide in plain sight. C: you find out the hard way. Unless you break the chain at A.",
		"goal_text": "Big Ear radar planes keep their fighters cloaked: shimmering, untouchable, and still shooting. Bring down every Big Ear to unveil them.",
		"new": "The kill chain: shoot the AWACS to unveil stealth fighters",
		"real_story": "Modern air forces fight as networks. A radar plane far behind the front spots targets and passes them to fighters that keep their own radars silent, so they stay hidden until they fire. Break the first link of the chain and the rest go blind.",
		"bartender": "You shot the guy with the binoculars? That's... actually smart.",
		"fail": {"overrun": "Unseen, unstopped, and now, unbothered.", "shot_down": "Shot down by someone you never saw. Classic."},
		"goal": "clear", "seed": 2026, "lives": 4, "max_bombs": 32,
		"waves": [
			[
				{"shape": "solo", "kind": "A", "x": 240, "y": 90, "move": "weave", "amp": 90, "freq": 0.35, "jet": "bigear", "awacs": true, "descent": 0.5},
				{"shape": "pair", "kind": "C", "x": 160, "y": 200, "move": "weave", "amp": 70, "freq": 0.7, "cloaked": true, "delay": 0.6},
				{"shape": "pair", "kind": "C", "x": 320, "y": 230, "move": "weave", "amp": 70, "freq": 0.7, "phase": PI, "cloaked": true, "delay": 1.0},
			],
			[
				{"shape": "solo", "kind": "A", "x": 130, "y": 90, "move": "weave", "amp": 60, "freq": 0.4, "jet": "bigear", "awacs": true, "descent": 0.5},
				{"shape": "solo", "kind": "A", "x": 350, "y": 110, "move": "weave", "amp": 60, "freq": 0.4, "phase": PI, "jet": "bigear", "awacs": true, "descent": 0.5, "delay": 0.5},
				{"shape": "vic3", "kind": "B", "x": 240, "y": 210, "move": "figure8", "amp": 100, "freq": 0.5, "cloaked": true, "delay": 1.0},
				{"shape": "pair", "kind": "B", "x": 240, "y": 280, "move": "weave", "amp": 140, "freq": 0.6, "delay": 1.5},
			],
			[
				{"shape": "solo", "kind": "A", "x": 240, "y": 80, "move": "weave", "amp": 110, "freq": 0.3, "jet": "bigear", "awacs": true, "descent": 0.4},
				{"shape": "finger4", "kind": "A", "x": 200, "y": 190, "move": "figure8", "amp": 100, "freq": 0.5, "cloaked": true, "delay": 0.8},
				{"shape": "finger4", "kind": "A", "x": 290, "y": 260, "move": "weave", "amp": 90, "freq": 0.55, "phase": 2.0, "cloaked": true, "delay": 1.4},
			],
		],
	},
]
