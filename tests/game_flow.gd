extends SceneTree

var output_dir := "res://art-review/main-menu-v1/"
var failures: Array[String] = []
var checks := 0
var flow: Node

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
	print("PASS " if condition else "FAIL ", message)

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output_dir = argument.trim_prefix("--capture-dir=").trim_suffix("/") + "/"
	run.call_deferred()

func frames(count := 4) -> void:
	for i in count: await process_frame

func click_button(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func press_key(physical_keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = physical_keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func wait_for_battle() -> void:
	for i in 500:
		if flow.state == "battle": return
		await physics_frame
	check(false, "Match loaded within timeout")

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(5)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output_dir + "previews/" + name + ".png") == OK, "Captured " + name)

func run() -> void:
	root.size = Vector2i(1280, 800)
	flow = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(flow)
	await frames(10)
	flow.suppress_quit = true
	flow.suspend_on_focus_loss = false
	check(flow.state == "home" and not is_instance_valid(flow.game), "Launch into main menu without a running match")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_menu.tscn", "Main menu is the game entry scene")
	check(not flow.has_node("ReviewBar"), "No review navigation bar")
	await capture("01-main-menu")
	await click_button(flow.screen.get_node("Margin/Scroll/Layout/Menu/Actions/Play"))
	await frames()
	check(flow.state == "tanks", "Play opens tank selection")
	for i in 8:
		await click_button(flow.screen.buttons[i])
		check(flow.selected_tank == i, "Select tank %d" % i)
		check(flow.screen.catalog()[i].speed_mps == ToyTank.SPEEDS[i], "Tank %d uses gameplay speed" % i)
		check(flow.screen.stack.get_node("Hero/Portrait").tank_index == i, "Tank %d preview matches selection" % i)
		check(flow.screen.stat_values[1].text == "%.2f s" % ToyTank.player_stats(i).fire_interval_s, "Tank %d shows actual reload interval" % i)
	await click_button(flow.screen.buttons[5])
	await capture("02-tank-selection")
	await click_button(flow.screen.get_node("SafeArea/Scroll/Center/Card/Stack/Actions/Ready"))
	await wait_for_battle()
	check(flow.game.player.variant == 5, "Duelist selection enters actual arena")
	check(flow.game.battle_mode and flow.game.actors.get_child_count() == 8, "Match has seven active enemies")
	check(not flow.game.get_node("Interface").visible, "Diagnostic UI is hidden in gameplay")
	check(flow.game.selected_map == flow.last_map, "Random arena is the actual map scene")
	flow.game.qa_mode = true
	flow.game.battle_mode = false
	flow.game.player.health = ToyTank.PLAYER_HP
	await frames()
	check(ToyTank.PLAYER_HP == 1, "Player tank is a one-hit kill")
	check(not flow.screen.has_node("HealthPanel"), "HUD omits the health panel")
	flow.screen.get_node("Fire").pressed.emit()
	flow.pause_match()
	var frozen: Vector3 = flow.game.player.position
	var reload_before: float = flow.game.player.cooldown
	var shots_before: int = flow.game.shots_fired
	await create_timer(0.22, true).timeout
	check(paused and flow.state == "pause", "Pause freezes the scene tree")
	check(flow.game.player.position == frozen and flow.game.player.cooldown == reload_before, "Movement and cooldown stay frozen")
	check(flow.game.shots_fired == shots_before, "Delayed Duelist barrel respects pause")
	await capture("04-pause")
	flow.screen.get_node("SafeArea/Scroll/Center/Card/Stack/Settings").pressed.emit()
	await frames()
	check(flow.state == "settings" and paused, "Settings preserve pause")
	await capture("07-settings")
	flow.screen.get_node("SafeArea/Scroll/Center/Card/Stack/Done").pressed.emit()
	check(flow.state == "pause" and paused, "Settings return to pause")
	flow.screen.get_node("SafeArea/Scroll/Center/Card/Stack/Resume").pressed.emit()
	await create_timer(0.18, true).timeout
	check(flow.state == "battle" and not paused, "Resume unpauses gameplay")
	check(flow.game.shots_fired == shots_before + 1, "Duelist second barrel resumes")
	flow.game.battle_mode = false
	await capture("03-live-match")
	flow.pause_match()
	var map_before: int = flow.last_map
	flow.screen.get_node("SafeArea/Scroll/Center/Card/Stack/Restart").pressed.emit()
	await wait_for_battle()
	flow.game.qa_mode = true
	flow.game.battle_mode = false
	check(flow.last_map == map_before and flow.game.player.health == ToyTank.PLAYER_HP, "Restart keeps map and restores tank")
	for i in range(1, 8): flow.game.actors.get_child(i).die()
	check(flow.state == "win" and paused, "Actual enemy defeats open victory")
	check(flow.screen.get_node("SafeArea/Scroll/Center/Card/Stack/Stats/Score").text.begins_with("07"), "Victory uses actual cleared targets")
	await capture("05-victory")
	flow.screen.get_node("SafeArea/Scroll/Center/Card/Stack/Again").pressed.emit()
	await wait_for_battle()
	flow.game.qa_mode = true
	flow.game.battle_mode = false
	check(flow.last_map != map_before, "Next round chooses a different random arena")
	for i in ToyTank.PLAYER_HP: flow.game.player.take_hit()
	await frames()
	check(flow.state == "spectate" and not paused, "Player destruction starts spectating instead of ending the round")
	check(flow.game.spectating and is_instance_valid(flow.game.spectate_target) and flow.game.spectate_target.alive, "Spectator camera holds a surviving tank")
	check(flow.screen.get_node("SpectatorName").visible, "HUD shows the spectator subject")
	var watched: ToyTank = flow.game.spectate_target
	flow.game.cycle_spectate(1)
	check(flow.game.spectate_target != watched and flow.game.spectate_target.alive, "Spectator can switch between surviving tanks")
	for key in [KEY_D, KEY_A, KEY_RIGHT, KEY_LEFT]:
		var before: ToyTank = flow.game.spectate_target
		await press_key(key)
		check(flow.game.spectate_target != before and flow.game.spectate_target.alive, "Spectator switches with %s" % OS.get_keycode_string(key))
	flow.pause_match()
	check(flow.state == "pause" and paused, "Escape menu opens while spectating")
	flow.screen.get_node("SafeArea/Scroll/Center/Card/Stack/Resume").pressed.emit()
	await frames()
	check(flow.state == "spectate" and not paused, "Resume returns to spectating")
	for i in range(1, 7): flow.game.actors.get_child(i).die()
	await frames()
	check(flow.state == "loss" and paused, "Defeat opens once one tank is left standing")
	await capture("06-defeat")
	flow.screen.get_node("SafeArea/Scroll/Center/Card/Stack/MainMenu").pressed.emit()
	await frames()
	check(flow.state == "home" and not paused and not is_instance_valid(flow.game), "Return to main menu unloads match")
	var quit_events := [0]
	flow.quit_requested.connect(func(): quit_events[0] += 1)
	flow.screen.get_node("Margin/Scroll/Layout/Menu/Actions/Quit").pressed.emit()
	check(quit_events[0] == 1, "Quit button invokes game quit handler")
	for width_height in [Vector2i(390, 844), Vector2i(820, 1180), Vector2i(844, 390), Vector2i(320, 568)]:
		root.size = width_height
		flow._show_home()
		await frames(10)
		var controls: Array[Node] = flow.screen.find_children("*", "BaseButton", true, false)
		for button in controls:
			var rect: Rect2 = button.get_global_rect()
			check(rect.position.x >= 0 and rect.end.x <= root.size.x + 1, "Home %s button %s fits" % [width_height, button.name])
			check(absf(rect.get_center().x - root.size.x * 0.5) < 1, "Home %s button %s is centered" % [width_height, button.name])
			check(rect.position.y >= 0 and rect.end.y <= root.size.y and rect.size.y >= 48, "Home %s button %s is visible and touch-sized" % [width_height, button.name])
		await capture("home-%dx%d" % [width_height.x, width_height.y])
		flow._action("play")
		await frames(10)
		for button in flow.screen.buttons:
			var rect: Rect2 = button.get_global_rect()
			check(rect.position.x >= 0 and rect.end.x <= root.size.x + 1, "Tank grid %s fits" % width_height)
		await capture("tanks-%dx%d" % [width_height.x, width_height.y])
		var ready_rect: Rect2 = flow.screen.stack.get_node("Actions/Ready").get_global_rect()
		check(ready_rect.position.y >= 0 and ready_rect.end.y <= root.size.y, "Roll out remains visible at %s" % width_height)
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"rendered":DisplayServer.get_name() != "headless"}
	var file := FileAccess.open(output_dir + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("GAME_FLOW_QA_COMPLETE ", checks, " checks, ", failures.size(), " failures")
	flow.queue_free()
	await frames()
	await create_timer(0.12, true).timeout
	quit(0 if failures.is_empty() else 1)
