# Air Superiority Complex: notes for Claude

A satirical Space-Invaders-style shooter in Godot 4.7 (GDScript), and the third game made with the user's game-launch recipe. Copy the GitHub, release, browser and video tooling from the Cardboard Espionage Action repo (`../godot-sandbox`). The full design (20 missions, countries, jets, tone rules) is in README.md.

**Another game (Sparkfrost, `../sparkfrost`) is developed in parallel.** Don't touch its folder, and don't drive the Godot editor through computer use while it might be in use. Use headless runs and `--screenshot`.

## Legal and tone rules (important)
- **No real country, jet or person names anywhere players can see**: briefing, HUD, end cards and the "real story" text. Describe events indirectly ("a pilot defected in his country's secret interceptor").
  - Parody names must not contain a real jet's actual word (several were renamed for this).
  - Keep jokes indirect: coffee, not tea, for the 2019 story. The user asked for this on 2026-10-14.
  - The whole repo is public: no real-to-parody mapping anywhere in it (code comments included). `blend` fields describe jet *types* only. The AI-art prompt pack, which needs real names to work, lives in the git-ignored `docs/private/`.
- Never use real jet designations or names; some are trademarked.
- Use flipped-number parody designations and parody makers.
- Real names appear only in the factual "real story" end card.
- Silhouettes are stylized, not exact copies.
- The countries are satirical. Bordaria and Borderia are satirized equally: every joke gets a matched pair. No civilian tragedies.

## Run and check
- Play: `godot --path .`
- Every change: `bash checks/verify.sh` must end with `air-superiority-complex: all good` (about 25 s). It runs:
  - the smoke test;
  - `tests/sim_test.gd`: rules, determinism, and the autopilot beating every mission solo and co-op;
  - `checks/autoplay.sh`: the real game beats every mission on autopilot.
- Dev flags after `--`: `--level=N` (1-based), `--players=2`, `--autopilot`, `--exit-on-end` (prints `RESULT ...`), `--linger=S`, `--timeout=S`, `--screenshot=path.png --wait=S`, `--portrait`.
- Put `--fixed-fps 60` before `--` to run faster than real time. Timers count game time, so `--wait` is in game seconds.
- Visual check: `godot --path . -- --autopilot --players=2 --screenshot=<scratchpad>/x.png --wait=9`, then Read the PNG.

## Difficulty curve
- Every mission has a `difficulty` (its position, 1..N). sim.gd turns it into a 0..1 `ramp` that scales:
  - enemy fire interval (x1.45 down to x0.7);
  - missile frequency;
  - bullet speed and aim cone;
  - armor (+0..2) and burst length.
- A per-mission `tune` dict (`fire`, `missiles`, `hp`) trims outliers.
- `godot --headless --path . --script res://tests/difficulty.gd` flies every mission with a **rookie** autopilot (reacts every 9 frames, sloppy aim, late dodges, forgets flares) and prints armor lost per minute. Keep it rising mission to mission; chapter finales may spike. After this tuning (2026-10-15) it runs 4, 9, 9, 10, 13, 14, 18, 19, 19, 25, 21, 24, 24, 28, 32.
- Modern missions have `enemy_flares` (chance per missile), and the BVR duel has `missile_regen`.

## Sound
- `python3 tools/make_audio.py` regenerates `audio/` in about 8 s. It uses the stdlib synth in `tools/synth.py`, shared with Sparkfrost and Cardboard. The output is:
  - sfx;
  - loops (engine, rain, wind);
  - music: `lounge` for the briefing bar, `cold_war` for chapter 1, `subcontinent` for chapter 2.
- `scripts/sound.gd` has:
  - an SFX pool, plus dedicated cannon players (rapid fire stays quiet);
  - faded loops (the engine follows throttle and afterburner; rain, wind and the MISSILE LOCK warning);
  - music crossfades on Music, SFX and Ambience buses.
- M toggles music; `--no-music` turns it off. Autopilot runs are silent unless you pass `--music`.
- Comedy stings, as the user likes: ka-ching (combo, side switch), a teacup, and a sad trombone on failure. Keep repeated sounds quiet and dark.

## Release and videos
- **Release:** GitHub repo `ahab94/air-superiority-complex` (public).
  - Push a `v*` tag: `.github/workflows/release.yml` runs the checks, exports Windows, macOS, Linux and Web, attaches the zips to the Release, and deploys Web to Pages (https://ahab94.github.io/air-superiority-complex/).
  - Write `docs/releases/<tag>.md` before tagging.
  - Install one-liners: `install.sh`, `install.ps1`.
- **Browser build:** uses the Compatibility renderer. scene3d.gd brightens it, turns SSAO off, and on the web uses a 2048 shadow map and MSAA 2x.
- **Touch:** `scripts/touch.gd` shows a floating stick plus Fire, Missile, Flare and Pause buttons. It turns on with `DisplayServer.is_touchscreen_available()` or `--touch`, and presses the same input actions as the keys. Mouse-from-touch emulation is on, so the menus take taps.
- **Videos:**
  1. `bash tools/video/record_footage.sh [clips]` records Movie Maker footage into `build/footage/`: portrait 1080x1920 `p-NN`, landscape `l-NN`, and `p-reck-NN` with `--reckless` (no dodging or shooting, the parachute goes to the wrong side). Each clip gets a `.events` file from `--log-events` with exact moment times.
  2. `python3 tools/video/make_video_audio.py` builds the stingers and music beds.
  3. `/usr/bin/python3 tools/video/make_videos.py` writes `build/videos/` and `docs/marketing/youtube.md`.

## Layout
- `scripts/sim.gd`: deterministic rules with no graphics. 480x720 portrait field, `step(inputs)` per 1/60 s, and an `events` list that the game drains for effects. It covers:
  - **squadrons**: several small formations per wave (vic, line, echelon, box, finger-four, pair). Each flies in from the top, brakes into its slot, then weaves or flies a figure 8. Paths are formulas of the squadron's clock, so `enemy_pos_in(e, t)` gives exact forecasts;
  - **cannons** on both sides: rapid explosive rounds. Enemies fire aimed bursts, angled up to ±0.32 rad;
  - **armor** on every jet. Damage slows the player's jet and makes it drift (`damage(p)`);
  - **missiles**: limited. Hold the missile button to lock 1–N targets one by one, release to fire. Missiles home in, and one hit kills;
  - **enemy missiles and flares**: each squadron periodically starts a warned lock (`enemy_locks`, 1.1 s, shown as MISSILE LOCK), then launches a homing missile that turns slower than ours and costs 6 armor on a hit. Flares (F/Q, Deuce `/`, pad B/Y) are unlimited: 2 decoys per drop, then the dispenser recharges (`flare_cd` per jet, Foxbrat 3 s). Any missile within 280 px of its target chases one and won't fuse on a jet. Each enemy carries one missile;
  - clouds (cell grid) that both sides' bullets chew through;
  - shared spare lives, with eject-and-rescue in co-op;
  - fuel, the approach and the landing strip;
  - `formation_offset()` for forecasting.
- `scripts/jets.gd`: each jet type's capabilities: agility, armor, cannon rate, missiles, lock count and lock time, plus the AI's burst pattern. The rules, autopilot, briefing and 3D all read it.
- `scripts/autopilot.gd`: forecasts bullets (they fall straight down, so the forecast is exact), leads shots using `formation_offset`, catches the wingman's parachute, and lands.
- `scripts/levels.gd`: 10 missions. Gameplay, story (goal_text, real_story, bartender, fail) and look (terrain, light, weather) live together. The optional rules are listed at the top of sim.gd: goal land/clear/survive, wind, icing, flak, sams, photos, sanctuary_x, bvr_line, enemy_guns, player_guns, rearm_each_wave, claims, combo, tea, switch.
- `scripts/game.gd`:
  - InputMap actions built in code. Solo: Arrows also fly Ace. Enter makes Deuce join, and after that Arrows go to Deuce.
  - Drawing in field coordinates via `_field()`. Text is drawn in screen pixels via `_text`/`_para`.
  - The briefing and end cards, and the side panels in wide windows.
- `scripts/scene3d.gd`: the real-time 3D view. It only reads the sim and never changes it.
  - Mapping: 1 unit = 10 field px, field y becomes +Z, and the action happens on the plane Y=0.
  - A perspective camera hangs straight down, sized so that plane exactly fills the 2D field. That's why HUD labels line up with the jets.
  - Sea at SEA_Y=-22, with things at sea level scaled by K so they line up on screen (`to_sea`).
  - Ocean, land and runway shaders; clouds as MultiMesh puffs with shadows on the sea; drifting parallax clouds; tracers; GPUParticles explosions; banking jets; descent on landing.
- `scripts/jet_mesh.gd`: jets built in code with SurfaceTool from numbers in `MODELS`: fuselage loft, wings and fins as plates, intakes, canopy and nozzles.
  - **Each jet blends 2–3 jet types** (see the `blend` field in jets.gd).
  - Preview models with `godot --path . --resolution 1000x800 --script res://tools/jet_preview.gd -- --out=x.png`.
- **Chapter 3 mechanics (sim.gd):**
  - `disguise`: the players look like bombers. Enemies lure in and hold fire; the first trigger pull reveals (`ambush_t` gives double points), and lingering too long gets you `spotted`.
  - `roe`: `weapons_free` turns true on the enemy's first shot. Trigger pulls before that are violations, and three lose the mission.
  - Squadron flags: `from: behind` (climbs up from below and fires upward; the climb speeds up when the throttle is negative), `awacs` (`chain_up` while any is alive), `cloaked` (`hittable()` is false while `chain_up`), and `phantom` (alternates ghost and solid, jumps position).
  - `hittable(e)` gates every shot, missile and lock.
- **Stealth camo** (`shaders/stealth.gdshader`): screen-texture refraction. scene3d `_restealth` rebuilds the node when it toggles, because a live node ignores a runtime `cast_shadow` change. Stealth jets deliberately keep their shadow (the user wants it as the giveaway); the phantom's mist casts none.
- `scripts/look3d.gd`: light presets (day, dusk, overcast, storm, night, arctic), terrain table, and the SAM site and photo target models.
- `shaders/terrain.gdshader`: one shader for every land biome (steppe, winter, desert, arctic, plains, jungle, mountains). The mesh is raised for real relief. Town lights appear at night. The palette is sRGB, so it's converted to linear.
- `scripts/fx3d.gd`: explosions, cannon impacts, wrecks tumbling into the sea with a splash, muzzle flashes, damage smoke and fire, and ribbon trails (vapour, missile smoke).
- `scripts/ships.gd`: scenery ships with wakes.
- `shaders/`:
  - `jet_skin`: camo, panel lines, roundels. Normals are flipped to face the camera, because mesh winding isn't consistent.
  - `flame`: additive HDR, which triggers bloom.
  - `ocean` (swell, waves, foam, cloud shadows, glitter), `land`, `runway`, `cloud`, `wake`.
  - `post`: vignette, light grain and lens fringing, on a CanvasLayer under the HUD.
- **Visual rules the user asked for:**
  - Jets never fly backwards. Vertical movement reads as throttle: world speed, flame size and vapour change. The world always scrolls forward.
  - Damaged jets visibly struggle: wobble, jolt on each hit, smoke then fire, a coughing engine, and sagging out of formation.
  - Keep it sharp: no depth-of-field blur, low bloom, MSAA 4x.
- `scripts/menu.gd`: the title (over a silent autopilot demo, game state "menu"), mission select, options (music and effects volume, fullscreen; saved in the cfg), controls, and the pause menu. It emits `chosen(what, arg)`, and game.gd's `_on_menu` acts on it.
  - **Esc never quits.** It pauses during play and goes back one level in menus. The only exit is Quit on the title screen.
  - Keyboard, gamepad (Start = back) and mouse all work.
  - Dev flag `--menu=title|select|options|controls` opens a menu screen directly, for screenshots.
- `scripts/art.gd`: 2D colours and the small HUD jet icons.

## Conventions
- Multiplayer is always optional: every mission must be fun and winnable solo.
- Each mission introduces one new mechanic. Add its rules to sim.gd, teach the autopilot, and verify it wins solo and co-op.
- Scripts use `preload`, not `class_name`. Declare explicit types on values from untyped objects (`var p: Vector2 = obj.pos`).
- Comments explain why. The user is learning Godot, so briefly explain new engine concepts.
- Visual style: real-time 3D, cinematic, top-down (the user asked for photoreal; we chose 3D over AI sprites). AI art is only for promo and briefing portraits; prompts are in `docs/private/ai-art-prompts.md` (not in the repo).
- The ground scroll belongs to the sim (`ground_speed`, `ground_scroll`, driven by the pilots' throttle), so SAM sites and photo targets stay pinned to the terrain.
- Progress is saved to `user://air_superiority_complex.cfg` (missions unlocked). The dev flag `--all-missions` unlocks everything.
- Still to do from the recipe: GitHub, web export, videos.
