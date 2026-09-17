extends Node

signal cue_played(cue: String, spatial: bool)

const WORLD_VOICES := 16
const UI_VOICES := 6
const MUSIC_BANK := {
	"menu": preload("res://assets/audio/music/menu_theme.wav"),
	"battle": preload("res://assets/audio/music/battle_theme.wav"),
}
const SOUND_BANK := {
	"cannon_00": preload("res://assets/audio/cannon_00.wav"),
	"cannon_01": preload("res://assets/audio/cannon_01.wav"),
	"cannon_02": preload("res://assets/audio/cannon_02.wav"),
	"cannon_03": preload("res://assets/audio/cannon_03.wav"),
	"cannon_04": preload("res://assets/audio/cannon_04.wav"),
	"cannon_05": preload("res://assets/audio/cannon_05.wav"),
	"cannon_06": preload("res://assets/audio/cannon_06.wav"),
	"cannon_07": preload("res://assets/audio/cannon_07.wav"),
	"ricochet_00": preload("res://assets/audio/ricochet_00.wav"),
	"ricochet_01": preload("res://assets/audio/ricochet_01.wav"),
	"ricochet_02": preload("res://assets/audio/ricochet_02.wav"),
	"explosion_00": preload("res://assets/audio/explosion_00.wav"),
	"explosion_01": preload("res://assets/audio/explosion_01.wav"),
	"explosion_02": preload("res://assets/audio/explosion_02.wav"),
	"mine_place": preload("res://assets/audio/mine_place.wav"),
	"mine_arm": preload("res://assets/audio/mine_arm.wav"),
	"mine_burst": preload("res://assets/audio/mine_burst.wav"),
	"reload_ready": preload("res://assets/audio/reload_ready.wav"),
	"ui_hover": preload("res://assets/audio/ui_hover.wav"),
	"ui_confirm": preload("res://assets/audio/ui_confirm.wav"),
	"ui_back": preload("res://assets/audio/ui_back.wav"),
	"tank_select": preload("res://assets/audio/tank_select.wav"),
	"pause": preload("res://assets/audio/pause.wav"),
	"resume": preload("res://assets/audio/resume.wav"),
	"match_start": preload("res://assets/audio/match_start.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"),
	"player_down": preload("res://assets/audio/player_down.wav"),
	"treads_loop": preload("res://assets/audio/treads_loop.wav"),
}

var streams: Dictionary = SOUND_BANK.duplicate()
var ui_players: Array[AudioStreamPlayer] = []
var world_players: Array[AudioStreamPlayer3D] = []
var last_cue: Dictionary = {}
var variants: Dictionary = {}
var world_paused := false
var arena: Node3D
var engine: AudioStreamPlayer3D
var engine_level := 0.0
var engine_subject: Node3D
var last_yaw := 0.0
var music_players: Dictionary = {}
var music_levels := {"menu": 0.0, "battle": 0.0}
var music_context := ""
var music_subdued := false
var stinger_until := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in UI_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = "UI"
		add_child(voice)
		ui_players.append(voice)
	for id in MUSIC_BANK:
		var voice := AudioStreamPlayer.new()
		voice.bus = "Music"
		var loop := MUSIC_BANK[id].duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
		voice.stream = loop
		voice.volume_db = -60.0
		add_child(voice)
		music_players[id] = voice

func set_music(context: String, subdued := false) -> void:
	if not context.is_empty() and not music_players.has(context): return
	music_context = context
	music_subdued = subdued
	if music_players.has(context) and not music_players[context].playing:
		music_players[context].play()

func stop_music() -> void:
	music_context = ""
	for id in music_players:
		music_players[id].stop()
		music_players[id].volume_db = -60.0
		music_levels[id] = 0.0

func _update_music(delta: float) -> void:
	var level := 0.3 if music_subdued else 1.0
	if Time.get_ticks_msec() / 1000.0 < stinger_until: level *= 0.4
	for id in music_players:
		var target := level if id == music_context else 0.0
		music_levels[id] = move_toward(float(music_levels[id]), target, delta / 1.2)
		music_players[id].volume_db = linear_to_db(maxf(float(music_levels[id]), 0.001))
		if target == 0.0 and float(music_levels[id]) <= 0.001:
			music_players[id].stop()

func _allow(cue: String, gap: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_cue.get(cue, -10.0)) < gap: return false
	last_cue[cue] = now
	return true

func play_ui(cue: String) -> void:
	if not streams.has(cue): return
	if not _allow(cue, 0.055 if cue == "ui_hover" else 0.03): return
	if cue in ["match_start", "victory", "defeat", "player_down"]:
		stinger_until = Time.get_ticks_msec() / 1000.0 + streams[cue].get_length()
	var voice := ui_players[0]
	for candidate in ui_players:
		if not candidate.playing:
			voice = candidate
			break
	voice.stop()
	voice.stream = streams[cue]
	voice.pitch_scale = randf_range(0.97, 1.03) if cue == "ui_hover" else 1.0
	voice.volume_db = -3.0 if cue == "ui_hover" else 0.0
	voice.play()
	cue_played.emit(cue, false)

func stop_ui() -> void:
	for voice in ui_players:
		voice.stop()
		voice.stream = null

func _variation(family: String) -> String:
	var previous := int(variants.get(family, -1))
	var next := randi_range(0, 2) if previous < 0 else (previous + randi_range(1, 2)) % 3
	variants[family] = next
	return "%s_%02d" % [family, next]

func play_world(cue: String, point: Vector3, owner_node: Node3D, gain_db := 0.0) -> void:
	if world_paused or not is_instance_valid(owner_node): return
	var family := cue
	if not _allow(family, 0.04 if family in ["explosion", "mine_burst"] else 0.018): return
	if cue in ["ricochet", "explosion"]: cue = _variation(cue)
	if not streams.has(cue): return
	world_players = world_players.filter(func(p): return is_instance_valid(p))
	var voice: AudioStreamPlayer3D
	for candidate in world_players:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null and world_players.size() < WORLD_VOICES:
		voice = AudioStreamPlayer3D.new()
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		voice.bus = "SFX"
		voice.unit_size = 12.0
		voice.max_distance = 65.0
		voice.attenuation_filter_cutoff_hz = 14000.0
		owner_node.add_child(voice)
		world_players.append(voice)
	if voice == null:
		voice = world_players[0]
		for candidate in world_players:
			if candidate.volume_db < voice.volume_db: voice = candidate
		if gain_db < voice.volume_db: return
	voice.stop()
	if voice.get_parent() != owner_node: voice.reparent(owner_node)
	voice.global_position = point
	voice.stream = streams[cue]
	voice.volume_db = gain_db
	voice.pitch_scale = randf_range(0.96, 1.04)
	voice.play()
	cue_played.emit(cue, true)

func set_world_paused(value: bool) -> void:
	world_paused = value
	for voice in world_players:
		if is_instance_valid(voice): voice.stream_paused = value
	if is_instance_valid(engine): engine.stream_paused = value

func follow_arena(value: Node3D) -> void:
	arena = value
	engine_subject = null
	engine_level = 0.0
	if is_instance_valid(engine): engine.queue_free()
	engine = AudioStreamPlayer3D.new()
	engine.process_mode = Node.PROCESS_MODE_ALWAYS
	engine.bus = "Engine"
	engine.unit_size = 14.0
	engine.max_distance = 65.0
	var loop := streams["treads_loop"].duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	engine.stream = loop
	engine.volume_db = -60.0
	arena.add_child(engine)

func clear_world() -> void:
	for voice in world_players:
		if is_instance_valid(voice):
			voice.stop()
			voice.queue_free()
	world_players.clear()
	if is_instance_valid(engine):
		engine.stop()
		engine.queue_free()
	engine = null
	arena = null
	engine_subject = null
	engine_level = 0.0
	world_paused = false

func _exit_tree() -> void:
	stop_ui()
	stop_music()
	clear_world()

func _process(delta: float) -> void:
	_update_music(delta)
	if not is_instance_valid(arena) or not is_instance_valid(engine) or world_paused: return
	var subject: ToyTank = arena.spectate_target if arena.spectating else arena.player
	var target := 0.0
	if is_instance_valid(subject) and subject.alive and not arena.round_over and arena.view_mode == 0:
		engine.global_position = subject.global_position
		if engine_subject != subject:
			engine_subject = subject
			last_yaw = subject.rotation.y
		var turning := absf(angle_difference(last_yaw, subject.rotation.y)) / maxf(delta, 0.001)
		last_yaw = subject.rotation.y
		target = clampf(subject.velocity.length() / ToyTank.SPEEDS[subject.variant] + turning * 0.12, 0.0, 1.0)
		engine.pitch_scale = lerpf(engine.pitch_scale, 0.77 + target * 0.35 + (3.0 - subject.variant) * 0.015, 1.0 - exp(-delta * 5))
	engine_level = lerpf(engine_level, target, 1.0 - exp(-delta * 9))
	engine.volume_db = linear_to_db(maxf(engine_level, 0.001))
	if engine_level > 0.015 and not engine.playing: engine.play()
	elif engine_level <= 0.015 and engine.playing: engine.stop()
