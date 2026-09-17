extends SceneTree

var audio: Node
var flow: Node
var viewport: SubViewport
var capture: AudioEffectCapture
var recording: AudioEffectRecord
var checks := 0
var failures: Array[String] = []
var original_volume := 75.0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
	print("PASS " if condition else "FAIL ", message)

func wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout

func peak() -> float:
	var frames := capture.get_buffer(capture.get_frames_available())
	var value := 0.0
	for frame in frames: value = maxf(value, maxf(absf(frame.x), absf(frame.y)))
	return value

func run() -> void:
	audio = root.get_node("GameAudio")
	var music_bus := AudioServer.get_bus_index("Music")
	check(music_bus > 0 and AudioServer.get_bus_send(music_bus) == &"Master", "Music uses the existing master volume control")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) == 0.0, "Effects are 5 dB louder")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI")) == -3.0, "Menu effects are 4 dB louder")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Engine")) == -19.0, "Treads are 5 dB louder")
	for id in audio.music_players:
		var stream: AudioStreamWAV = audio.music_players[id].stream
		check(stream.stereo and stream.mix_rate == 32000, id + " is stereo music")
		check(stream.get_length() >= 60 and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, id + " loops its complete composition")
		check(stream.loop_end == roundi(stream.get_length() * stream.mix_rate), id + " loop covers exact sample frames")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 5
	AudioServer.add_bus_effect(0, capture)
	recording = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, recording)
	recording.set_recording_active(true)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.audio_listener_enable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	flow = load("res://scenes/main_menu.tscn").instantiate()
	viewport.add_child(flow)
	flow.suspend_on_focus_loss = false
	flow.suppress_quit = true
	original_volume = flow.master_volume
	flow.master_volume = 75
	flow._apply_volume()
	await wait(1.5)
	var menu: AudioStreamPlayer = audio.music_players.menu
	var battle: AudioStreamPlayer = audio.music_players.battle
	check(audio.music_context == "menu" and menu.playing and not battle.playing, "Main menu starts its own theme")
	check(audio.music_levels.menu > .99, "Menu music fades in to normal level")
	check(peak() > .01, "Menu music reaches the native audio mixer")
	var position := menu.get_playback_position()
	flow._action("play")
	await wait(.5)
	check(menu.get_playback_position() > position and audio.music_context == "menu", "Tank selection continues the menu music without restarting")
	flow._show_home()
	flow._show_settings()
	await wait(.15)
	check(audio.music_context == "menu" and not audio.music_subdued, "Main-menu settings retain menu theme")
	flow._action("back")
	flow.start_match()
	var saw_crossfade := false
	for i in 1200:
		if is_instance_valid(flow.game):
			flow.game.qa_mode = true
			flow.game.battle_mode = false
		if menu.playing and battle.playing: saw_crossfade = true
		if flow.state == "battle" and not flow.fade.visible: break
		await process_frame
	check(flow.state == "battle", "Actual match loads")
	if flow.state != "battle": quit(1); return
	flow.game.qa_mode = true
	flow.game.battle_mode = false
	await wait(audio.streams["match_start"].get_length() + .85)
	check(saw_crossfade, "Menu and battle tracks overlap during the transition")
	check(audio.music_context == "battle" and battle.playing and not menu.playing, "Gameplay has its own music with old theme stopped")
	check(audio.music_levels.battle > .95, "Battle music recovers after launch stinger")
	capture.clear_buffer()
	flow.game.player.fire()
	await wait(.6)
	check(peak() < .999, "Louder cannon and music mix below clipping")
	for shot in flow.game.shots.get_children(): shot.queue_free()
	position = battle.get_playback_position()
	flow.pause_match()
	await wait(.95)
	check(audio.world_paused and audio.music_subdued, "Pause suspends world effects and softens music")
	check(absf(audio.music_levels.battle - .3) < .01, "Paused music reaches its softer level")
	check(battle.get_playback_position() > position, "Music continues smoothly while gameplay is paused")
	flow._show_settings()
	check(audio.music_context == "battle" and audio.music_subdued, "Pause settings retain the softer battle music")
	flow.master_volume = 0
	flow._apply_volume()
	check(AudioServer.is_bus_mute(0), "Zero volume also mutes music")
	flow.master_volume = 75
	flow._apply_volume()
	flow._action("back")
	flow._show_hud()
	await wait(1)
	check(not audio.music_subdued and audio.music_levels.battle > .99, "Resuming restores music level")
	for id in audio.music_players:
		audio.set_music(id)
		await wait(1.3)
		var player: AudioStreamPlayer = audio.music_players[id]
		player.seek(player.stream.get_length() - .15)
		capture.clear_buffer()
		await wait(.45)
		check(player.playing and player.get_playback_position() < 1, id + " wraps and continues playing at the loop boundary")
		check(peak() > .01, id + " produces audio across its loop boundary")
	audio.set_music("battle")
	await wait(.15)
	flow._show_home()
	await wait(1.3)
	check(menu.playing and not battle.playing and audio.music_context == "menu", "Returning home during a crossfade leaves only menu music")
	recording.set_recording_active(false)
	var wav := recording.get_recording()
	check(wav != null and wav.get_length() > 8, "Recorded native music and effects mix")
	if wav != null: wav.save_to_wav("res://art-review/music-v1/runtime-mix.wav")
	flow.master_volume = original_volume
	flow._apply_volume()
	flow.queue_free()
	await wait(.15)
	check(not menu.playing and not battle.playing, "Scene teardown stops both music players")
	var report := {"checks": checks, "failures": failures, "audio_driver": AudioServer.get_driver_name()}
	var file := FileAccess.open("res://art-review/music-v1/runtime-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
