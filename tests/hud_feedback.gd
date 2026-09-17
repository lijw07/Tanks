extends SceneTree

var flow: Node
var test_viewport: SubViewport
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
	print("PASS " if condition else "FAIL ", message)

func frames(count := 4) -> void:
	for i in count: await process_frame

func move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	test_viewport.push_input(event, true)
	await frames()

func click(button: Control) -> void:
	await move(button.get_global_rect().get_center())
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		test_viewport.push_input(event, true)
		await process_frame
	await frames()

func capture(name: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	test_viewport.get_texture().get_image().save_png("res://art-review/hud-icons-v2/previews/" + name + ".png")

func run() -> void:
	test_viewport = SubViewport.new()
	test_viewport.own_world_3d = true
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	test_viewport.size = Vector2i(1280, 800)
	root.add_child(test_viewport)
	flow = load("res://scenes/main_menu.tscn").instantiate()
	test_viewport.add_child(flow)
	flow.suppress_quit = true
	flow.suspend_on_focus_loss = false
	flow.selected_tank = 6
	flow.start_match()
	for i in 800:
		if is_instance_valid(flow.game):
			flow.game.battle_mode = false
			flow.game.qa_mode = true
		if flow.state == "battle" and not flow.fade.visible: break
		await process_frame
	check(flow.state == "battle", "Actual battle loads")
	if flow.state != "battle": quit(1); return
	flow.game.qa_mode = true
	flow.game.battle_mode = false
	var hud: Control = flow.screen
	check(not hud.has_node("ScorePanel") and not hud.has_node("Ammo") and not hud.has_node("HealthPanel"), "No health panel, tank count, or ammo amount in HUD")
	check(hud.get_node("Fire").recharge == 1 and hud.get_node("Mine").recharge == 1, "Both meters start ready")
	await move(Vector2(720, 360))
	await capture("01-ready")
	await click(hud.get_node("Fire"))
	check(flow.game.player.cooldown > 0 and hud.get_node("Fire").recharge < 1, "Clicking fire starts its actual reload meter")
	check(hud.get_node("Fire").disabled, "Fire is disabled during reload")
	await click(hud.get_node("Mine"))
	check(flow.game.player.mine_cooldown > 0 and hud.get_node("Mine").recharge < 1, "Clicking mine starts its actual cooldown meter")
	check(hud.get_node("Mine").disabled, "Mine is disabled during cooldown")
	for shot in flow.game.shots.get_children(): shot.queue_free()
	await move(Vector2(720, 360))
	await capture("02-reloading")
	check(hud.get_node("Fire").find_children("*", "Label", true, false).is_empty() and hud.get_node("Mine").find_children("*", "ProgressBar", true, false).is_empty(), "Weapon controls contain icons only")
	var fire_value: float = hud.get_node("Fire").recharge
	await create_timer(0.25).timeout
	await capture("02b-filling")
	check(hud.get_node("Fire").recharge > fire_value, "Reload progress advances over time")
	check(absf(hud.get_node("Fire").recharge - (1 - flow.game.player.cooldown / ToyTank.player_stats(6).fire_interval_s)) < 0.06, "Mortar meter uses its slower actual reload duration")
	var saved_fire: float = flow.game.player.cooldown
	var saved_mine: float = flow.game.player.mine_cooldown
	flow.pause_match()
	await create_timer(0.2, true).timeout
	check(flow.game.player.cooldown == saved_fire and flow.game.player.mine_cooldown == saved_mine, "Pausing freezes both weapon cooldowns")
	check(not flow.game.crosshair.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause hides crosshair and restores menu cursor")
	flow._show_hud()
	await frames()
	hud = flow.screen
	check(hud.get_node("Mine").recharge < 1, "Resume retains mine cooldown progress")
	await create_timer(ToyTank.MINE_COOLDOWN + 0.1).timeout
	check(not hud.get_node("Fire").disabled and not hud.get_node("Mine").disabled, "Both controls re-enable when ready")
	for dimensions in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(820, 1180), Vector2i(844, 390), Vector2i(320, 568)]:
		test_viewport.size = dimensions
		hud.touch_controls = dimensions.x != 1280
		hud._reflow()
		await frames(8)
		for name in ["Fire", "Mine", "Pause"]:
			var rect: Rect2 = hud.get_node(name).get_global_rect()
			check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(rect), name + " fits " + str(dimensions))
		if hud.get_node("Movement").visible:
			check(not hud.get_node("Movement").get_global_rect().intersects(hud.get_node("Fire").get_global_rect()), "Movement and fire do not overlap")
		for overview in [false, true]:
			flow.game.overview_mode = overview
			for point in [Vector2(dimensions) * Vector2(0.4, 0.4), Vector2(dimensions) * Vector2(0.6, 0.48)]:
				await move(point)
				if flow.game.crosshair.global_position.distance_to(point) >= 0.1:
					print("CURSOR expected=", point, " actual=", flow.game.crosshair.global_position, " viewport=", test_viewport.get_mouse_position())
				check(flow.game.crosshair.global_position.distance_to(point) < 0.1, "Crosshair matches cursor in " + str(dimensions) + (" overview" if overview else " follow"))
				check(flow.game.crosshair.visible, "Crosshair is visible over the arena")
				check(flow.game.camera.unproject_position(flow.game.aim_point).distance_to(point) < 1, "Aim ray matches cursor")
		flow.game.overview_mode = false
		await move(Vector2(dimensions) * Vector2(0.45, 0.4))
		await capture("hud-%dx%d" % [dimensions.x, dimensions.y])
		await move(hud.get_node("Pause").get_global_rect().get_center())
		check(not flow.game.crosshair.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pointer over UI uses normal cursor")
	test_viewport.size = Vector2i(1280, 800)
	hud.touch_controls = false
	hud._reflow()
	await frames()
	flow.game.player.take_hit()
	await frames()
	check(flow.state == "spectate", "Player death preserves spectator flow")
	check(hud.get_node("Fire").navigation_mode and not hud.get_node("Fire").icon_view.visible, "Spectator controls replace weapon icons with arrows")

	check(not flow.game.crosshair.visible, "Spectating hides crosshair")
	await capture("03-spectator")
	flow._show_home()
	await frames()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Returning to menu restores cursor")
	var report := FileAccess.open("res://art-review/hud-icons-v2/validation.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	print("HUD_FEEDBACK_COMPLETE ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
