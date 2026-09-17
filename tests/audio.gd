extends SceneTree

var flow: Node
var audio: Node
var viewport: SubViewport
var failures: Array[String] = []
var checks := 0
var events: Array[String] = []
var capture: AudioEffectCapture
var recording: AudioEffectRecord
var original_volume := 75.0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
	print("PASS " if condition else "FAIL ", message)

func wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout

func count_prefix(prefix: String) -> int:
	var count := 0
	for event in events:
		if event.begins_with(prefix): count += 1
	return count

func mixed_peak() -> float:
	var buffer := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for frame in buffer: peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak

func start_battle() -> void:
	flow.start_match()
	for i in 1200:
		if is_instance_valid(flow.game):
			flow.game.qa_mode = true
			flow.game.battle_mode = false
		if flow.state == "battle" and not flow.fade.visible: break
		await process_frame
	flow.game.qa_mode = true
	flow.game.battle_mode = false
	check(flow.state == "battle", "Actual arena loads with audio")

func run() -> void:
	audio = root.get_node("GameAudio")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	audio.cue_played.connect(func(cue: String, _spatial: bool): events.append(cue))
	check(audio.streams.size() == 29, "All 29 sound files import")
	for id in audio.streams:
		var stream: AudioStreamWAV = audio.streams[id]
		check(stream != null and stream.get_length() > 0.05 and stream.mix_rate == 44100, id + " has playable audio")
	for bus in ["SFX", "UI", "Engine"]:
		var index := AudioServer.get_bus_index(bus)
		check(index > 0 and AudioServer.get_bus_send(index) == &"Master", bus + " obeys master volume")
	check(AudioServer.get_bus_effect(0, 0) is AudioEffectLimiter, "Master mix has peak protection")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 5.0
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
	await wait(.25)
	capture.clear_buffer()
	flow._action("play")
	await wait(.4)
	check(events.has("ui_confirm"), "Play selection sounds")
	check(mixed_peak() > .001, "UI produces actual mixed audio")
	flow.screen.select_tank(5)
	await wait(.35)
	check(events.has("tank_select"), "Tank selection sounds")
	var button: Button = flow.screen.buttons[3]
	button.grab_focus()
	await wait(.1)
	check(events.has("ui_hover"), "Menu focus sounds")
	var hovers := count_prefix("ui_hover")
	await wait(.2)
	check(count_prefix("ui_hover") == hovers, "Stationary focus does not repeat sound")
	await start_battle()
	check(events.has("match_start"), "Round starts with its own cue")
	await wait(.9)
	var player: ToyTank = flow.game.player
	var before := count_prefix("cannon_")
	capture.clear_buffer()
	check(player.fire(), "Player fires")
	check(not player.fire(), "Cooldown rejects a second trigger")
	await wait(.21)
	check(count_prefix("cannon_") == before + 2, "Duelist sounds once for each of its two real barrels")
	check(events.has("cannon_05"), "Duelist uses its own cannon recording")
	check(mixed_peak() > .001, "Spatial cannons reach the actual audio mix")
	for shot in flow.game.shots.get_children(): shot.queue_free()
	await wait(.65)
	check(events.has("reload_ready"), "Reload completion sounds once")
	var reloads := count_prefix("reload_ready")
	await wait(.2)
	check(count_prefix("reload_ready") == reloads, "Ready cannon does not repeat reload sound")
	player.drop_mine()
	player.drop_mine()
	check(count_prefix("mine_place") == 1, "Mine placement only sounds when a mine is created")
	await wait(1.2)
	check(count_prefix("mine_arm") == 1, "Mine arms with one cue")
	for mine in flow.game.shots.get_children():
		if mine.has_method("detonate"):
			mine.global_position += Vector3(15, 0, 15)
			mine.detonate()
	check(events.has("mine_burst"), "Detonation triggers the mine's deeper burst")
	await wait(.1)
	flow.pause_match()
	check(audio.world_paused and events.has("pause"), "Pause freezes world audio and plays menu cue")
	var paused_voices := 0
	for voice in audio.world_players:
		if voice.stream_paused: paused_voices += 1
	check(paused_voices > 0, "Existing spatial voices are paused")
	await wait(.25)
	flow._show_settings()
	check(audio.world_paused, "Settings opened from pause keeps arena audio paused")
	flow.master_volume = 0
	flow._apply_volume()
	check(AudioServer.is_bus_mute(0), "Zero volume mutes every sound")
	flow.master_volume = 40
	flow._apply_volume()
	check(not AudioServer.is_bus_mute(0) and absf(AudioServer.get_bus_volume_db(0) - linear_to_db(.4)) < .01, "Volume restores smoothly through Master")
	flow._action("back")
	flow._show_hud()
	check(not audio.world_paused and events.has("resume"), "Resume restores arena sound")
	flow.master_volume = 75
	flow._apply_volume()
	flow.game.test_input = Vector2(0, 1)
	await wait(.55)
	check(audio.engine.playing and audio.engine_level > .05, "Tread loop follows actual tank movement")
	var loop: AudioStreamWAV = audio.engine.stream
	check(loop.loop_end == roundi(loop.get_length() * loop.mix_rate), "Motor loop uses sample frames, including compressed imports")
	flow.game.test_input = Vector2.ZERO
	await wait(.85)
	check(not audio.engine.playing, "Stopped tank settles to silence")
	var previous := ""
	for i in 5:
		flow.game.fx.impact(player.global_position + Vector3.UP, Vector3.UP)
		var current: String = events[-1]
		check(current.begins_with("ricochet_") and current != previous, "Ricochet varies without immediate repetition")
		previous = current
		await wait(.07)
	for id in audio.streams:
		audio.play_world(id, player.global_position, flow.game)
	check(audio.world_players.size() <= 16, "Busy battles keep a bounded spatial voice count")
	await wait(.4)
	check(mixed_peak() < 1.0, "Stress mix stays below digital clipping")
	player.take_hit()
	check(flow.state == "spectate" and events.has("player_down"), "Player loss enters spectator with a short cue")
	check(count_prefix("explosion_") > 0, "Destroyed tanks trigger debris explosions")
	await wait(.1)
	for tank in flow.game.living_tanks(): tank.take_hit()
	check(events.has("defeat"), "Completed lost round sounds")
	await wait(1.4)
	flow._show_home()
	check(audio.world_players.is_empty() and not is_instance_valid(audio.engine), "Returning home clears all arena audio")
	flow.selected_tank = 0
	await start_battle()
	await wait(.2)
	for tank in flow.game.living_tanks():
		if tank != flow.game.player: tank.take_hit()
	check(flow.state == "win" and events.has("victory"), "Actual arena victory plays the win fanfare")
	check(not audio.world_paused, "Round-end explosion tails can finish beneath results")
	await wait(2.2)
	recording.set_recording_active(false)
	var wav := recording.get_recording()
	check(wav != null and wav.data.size() > 44100, "Runtime audio recording contains mixed samples")
	if wav != null: wav.save_to_wav("res://art-review/audio-v1/runtime-mix.wav")
	flow.master_volume = original_volume
	flow._apply_volume()
	flow.queue_free()
	await process_frame
	var result := {"checks": checks, "failures": failures, "cue_count": events.size(), "audio_driver": AudioServer.get_driver_name(), "display": DisplayServer.get_name()}
	var file := FileAccess.open("res://art-review/audio-v1/runtime-validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
