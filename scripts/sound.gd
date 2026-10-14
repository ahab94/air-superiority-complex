extends Node
## Music, ambience and sound effects. Every file in audio/ is synthesized by
## tools/make_audio.py: original sounds built from oscillators and noise.
##
## An AudioStreamPlayer plays one sound at a time, so a pool of them lets
## effects overlap. Cannon fire (~12 rounds a second) gets its own players so
## it never crowds out explosions. Loops (engine, rain, wind, the missile
## warning) each have a dedicated player whose volume is faded each frame.
## Everything runs through three buses (Music, SFX, Ambience), so each group's
## volume is set in one place.

const SFX_NAMES := ["gun", "egun", "hit", "hurt", "boom", "bigboom", "missile", "sam", "lock_tone",
	"lock_ok", "warning", "flare", "pop", "flak", "splash", "shutter", "missed", "overheat", "kaching",
	"stamp", "tea", "clear", "approach", "win", "lose", "rescue", "join", "ui"]
const MUSIC := {
	"lounge": "res://audio/music/lounge.wav",
	"cold_war": "res://audio/music/cold_war.wav",
	"subcontinent": "res://audio/music/subcontinent.wav",
}

var music_on := true
var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _guns: Array[AudioStreamPlayer] = []
var _gun_i := 0
var _music: Array[AudioStreamPlayer] = []   # two players, for crossfades
var _music_now := ""
var _wanted := ""                           # the track the game asked for (kept while muted)
var _active := 0
var _loops := {}                            # name -> AudioStreamPlayer
var _loop_target := {}                      # name -> target volume (dB), or -80 for off


func _ready() -> void:
	_bus("Music", -11.0)
	_bus("SFX", -3.0)
	_bus("Ambience", -8.0)
	for n in SFX_NAMES:
		_sfx[n] = load("res://audio/sfx/%s.wav" % n)
	for i in 18:
		_pool.append(_player("SFX"))
	for i in 4:
		_guns.append(_player("SFX"))
	for i in 2:
		_music.append(_player("Music"))
	for n in ["engine", "rain", "wind"]:
		_loops[n] = _player("Ambience")
		_loops[n].stream = _looped(load("res://audio/loops/%s.wav" % n))
		_loop_target[n] = -80.0
	_loops["warning"] = _player("SFX")
	_loops["warning"].stream = _looped(load("res://audio/sfx/warning.wav"))
	_loop_target["warning"] = -80.0


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


## WAV files don't loop by default; set the loop points to the whole file.
static func _looped(w: AudioStreamWAV) -> AudioStreamWAV:
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(round(w.get_length() * w.mix_rate))
	return w


# --- effects ------------------------------------------------------------------

func play(sound: String, volume_db := 0.0, pitch_jitter := 0.0, pitch := 1.0) -> void:
	var p := _pool[0]
	for c in _pool:
		if not c.playing:
			p = c
			break
	p.stream = _sfx[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	p.play()


## Cannon fire cycles through its own few players: rapid, quiet, never
## starving the pool.
func gun(enemy: bool) -> void:
	var p := _guns[_gun_i]
	_gun_i = (_gun_i + 1) % _guns.size()
	p.stream = _sfx["egun" if enemy else "gun"]
	p.volume_db = -19.0 if enemy else -13.0
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()


# --- loops --------------------------------------------------------------------

## Set how loud a loop should be (-80 = off); it fades there smoothly.
func loop(name: String, db: float, pitch := 1.0) -> void:
	_loop_target[name] = db
	var p: AudioStreamPlayer = _loops[name]
	p.pitch_scale = lerpf(p.pitch_scale, pitch, 0.1)


func _process(delta: float) -> void:
	for n in _loops:
		var p: AudioStreamPlayer = _loops[n]
		var target: float = _loop_target[n]
		if target <= -79.0 and not p.playing:
			continue
		if not p.playing:
			p.volume_db = -60.0
			p.play()
		p.volume_db = move_toward(p.volume_db, target, delta * 60.0)
		if target <= -79.0 and p.volume_db <= -59.0:
			p.stop()
	# Music crossfade.
	for i in 2:
		var m := _music[i]
		var want := 0.0 if i == _active and music_on else -60.0
		m.volume_db = move_toward(m.volume_db, want, delta * 30.0)
		if i != _active and m.playing and m.volume_db <= -59.0:
			m.stop()


func silence_loops() -> void:
	for n in _loop_target:
		_loop_target[n] = -80.0


# --- music --------------------------------------------------------------------

## Crossfade to a music track ("" = fade out).
func music(track: String) -> void:
	_wanted = track
	if not music_on:
		track = ""
	if track == _music_now:
		return
	_music_now = track
	_active = 1 - _active
	var m := _music[_active]
	if track == "":
		m.stop()
		return
	m.stream = _looped(load(MUSIC[track]).duplicate())
	m.volume_db = -40.0
	m.play()


func toggle_music() -> bool:
	music_on = not music_on
	music(_wanted)
	return music_on


static func _bus(bus_name: String, db: float) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(i, db)
