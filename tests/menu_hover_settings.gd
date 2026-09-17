extends SceneTree

const Bindings = preload("res://scripts/control_bindings.gd")
var failures: Array[String] = []
var checks := 0
var flow: Node
var had_settings := false
var saved_settings := ""

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
	print("PASS " if condition else "FAIL ", message)

func frames(count := 4) -> void:
	for i in count: await process_frame

func move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await frames()

func click(button: Control) -> void:
	await move(button.get_global_rect().get_center())
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)

func key(code: int, down := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await frames(2)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art-review/hover-settings/previews/" + name + ".png")

func run() -> void:
	had_settings = FileAccess.file_exists("user://settings.cfg")
	if had_settings: saved_settings = FileAccess.get_file_as_string("user://settings.cfg")
	root.size = Vector2i(1280, 800)
	flow = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(flow)
	flow.suppress_quit = true
	flow.suspend_on_focus_loss = false
	await frames(10)
	Bindings.reset()
	var actions: Node = flow.screen.get_node("Margin/Scroll/Layout/Menu/Actions")
	for name in ["Play", "Settings", "Quit"]:
		var button: Button = actions.get_node(name)
		await move(button.get_global_rect().get_center())
		check(button.get_draw_mode() == BaseButton.DRAW_HOVER and button.has_focus(), name + " receives hover highlight")
		for other in actions.get_children():
			if other != button: check(not other.has_focus() and other.get_draw_mode() == BaseButton.DRAW_NORMAL, other.name + " is not highlighted")
		await capture("hover-" + name.to_lower())
	await move(Vector2(20, 20))
	check(root.gui_get_focus_owner() == null, "Moving away clears the hover outline")
	await key(KEY_DOWN)
	await key(KEY_DOWN, false)
	check(root.gui_get_focus_owner() != null, "Keyboard navigation resumes after pointer use")
	await click(actions.get_node("Settings"))
	check(flow.state == "settings", "Settings opens by pointer")
	var settings: Control = flow.screen
	check(not settings.stack.has_node("TouchControls"), "Settings has no touch toggle")
	check(settings.binding_buttons.size() == 8, "All eight gameplay actions can be rebound")
	settings.stack.get_node("Volume").value = 0
	check(AudioServer.is_bus_mute(0), "Zero volume mutes audio")
	settings.stack.get_node("Volume").value = 40
	check(not AudioServer.is_bus_mute(0) and is_equal_approx(flow.master_volume, 40) and absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.4) < 0.001, "Volume updates the actual audio bus")
	var mine: Button = settings.binding_buttons.mine
	settings.stack.get_node("Bindings").ensure_control_visible(mine)
	await frames()
	await click(mine)
	check(settings.pending == "mine", "Clicking a binding waits for a key")
	await key(KEY_W)
	await key(KEY_W, false)
	check(settings.pending == "mine" and settings.stack.get_node("Status").text.begins_with("Already used"), "Duplicate movement key is rejected")
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE, false)
	check(settings.pending.is_empty() and flow.state == "settings", "Escape cancels capture without closing settings")
	await click(mine)
	await key(KEY_F)
	await key(KEY_F, false)
	check(settings.pending.is_empty() and Bindings.label("mine") == "F", "New key updates the control")
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	check(config.get_value("bindings", "mine")[0].key == KEY_F, "Changed key is saved")
	Bindings.initialize(config)
	check(Bindings.label("mine") == "F", "Saved key reloads correctly")
	for pair in [["camera", KEY_C], ["pause_game", KEY_P]]:
		settings._listen(pair[0])
		await key(pair[1])
		await key(pair[1], false)
	settings.stack.get_node("Bindings").scroll_vertical = 0
	await frames()
	await capture("settings-desktop")
	for dimensions in [Vector2i(390, 844), Vector2i(320, 568), Vector2i(844, 390)]:
		root.size = dimensions
		await frames(10)
		for button in settings.binding_buttons.values():
			var rect: Rect2 = button.get_global_rect()
			check(rect.position.x >= 0 and rect.end.x <= root.size.x, "Key binding fits width " + str(dimensions))
		await capture("settings-%dx%d" % [dimensions.x, dimensions.y])
		check(settings.stack.get_node("Done").get_global_rect().end.y <= root.size.y, "Done stays visible at " + str(dimensions))
	root.size = Vector2i(1280, 800)
	await frames()
	await click(settings.stack.get_node("Done"))
	flow._action("play")
	flow._action("ready")
	for i in 500:
		if flow.state == "battle": break
		await physics_frame
	check(flow.state == "battle", "Starts battle after editing controls")
	flow.game.battle_mode = false
	await key(KEY_F)
	await physics_frame
	check(flow.game.player.mine_cooldown > 0, "Rebound key drops a mine in actual gameplay")
	await key(KEY_F, false)
	var overview_before: bool = flow.game.overview_mode
	await key(KEY_C)
	await key(KEY_C, false)
	check(flow.game.overview_mode != overview_before, "Rebound camera key changes the game camera")
	await key(KEY_P)
	await key(KEY_P, false)
	check(flow.state == "pause", "Rebound pause key opens pause menu")
	flow._action("settings")
	flow.screen.stack.get_node("Heading/Reset").pressed.emit()
	check(Bindings.label("mine") == "Space", "Reset restores default keys")
	flow._action("back")
	flow._action("resume")
	overview_before = flow.game.overview_mode
	await key(KEY_TAB)
	await key(KEY_TAB, false)
	check(flow.game.overview_mode != overview_before, "Default camera key still works after reset")
	flow._show_home()
	flow.queue_free()
	await frames()
	if had_settings:
		var file := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
		file.store_string(saved_settings)
		file.close()
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	var report := FileAccess.open("res://art-review/hover-settings/validation.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	print("HOVER_SETTINGS_COMPLETE ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
