extends Node

@onready var audio: Node = get_node("/root/GameAudio")

signal state_changed(state_name: String)
signal quit_requested

const HOME = preload("res://assets/ui/scenes/home_screen.tscn")
const TANKS = preload("res://assets/ui/scenes/tank_selection.tscn")
const HUD = preload("res://assets/ui/scenes/battle_hud.tscn")
const PAUSE = preload("res://assets/ui/scenes/pause_menu.tscn")
const WIN = preload("res://assets/ui/scenes/win_screen.tscn")
const LOSS = preload("res://assets/ui/scenes/loss_screen.tscn")
const SETTINGS = preload("res://assets/ui/scenes/settings_menu.tscn")
const GAME = preload("res://scenes/main.tscn")
const Bindings = preload("res://scripts/control_bindings.gd")
const Maps = preload("res://scripts/map_catalog.gd")

const FADE_OUT_SECONDS := 0.28
const FADE_IN_SECONDS := 0.42
const CARD_SECONDS := 1.1

var state := "home"
var game: Node3D
var screen: Control
var selected_tank := 0
var last_map := -1
var settings_from := "home"
var touch_enabled := DisplayServer.is_touchscreen_available()
var master_volume := 75.0
var suppress_quit := false
var suspend_on_focus_loss := true
var rng := RandomNumberGenerator.new()
var changing_match := false
var transition: CanvasLayer
var fade: ColorRect
var card: VBoxContainer
var card_kicker: Label
var card_title: Label
var card_subtitle: Label

func _ready() -> void:
	rng.randomize()
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		master_volume = float(config.get_value("audio", "volume", 75.0))
	Bindings.initialize(config)
	_apply_volume()
	_build_transition()
	_show_home()

func _build_transition() -> void:
	transition = CanvasLayer.new()
	transition.name = "Transition"
	transition.layer = 20
	add_child(transition)
	fade = ColorRect.new()
	fade.name = "Fade"
	fade.color = Color("0d1a22")
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.process_mode = Node.PROCESS_MODE_ALWAYS
	fade.modulate.a = 0.0
	fade.visible = false
	transition.add_child(fade)
	card = VBoxContainer.new()
	card.name = "Card"
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation", 12)
	card.visible = false
	fade.add_child(card)
	card_kicker = _transition_label(14, Color("92afaf"))
	card_title = _transition_label(46, Color("f4cb6c"))
	card_subtitle = _transition_label(16, Color("cfe0e6"))
	var display_font := FontVariation.new()
	display_font.base_font = load("res://assets/ui/fonts/Fredoka.ttf")
	display_font.variation_opentype = {2003265652: 650.0}
	card_title.add_theme_font_override("font", display_font)

func _transition_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)
	return label

func _fade_to_black() -> void:
	fade.visible = true
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, FADE_OUT_SECONDS)
	await tween.finished

func _fade_from_black() -> void:
	card.visible = false
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, FADE_IN_SECONDS)
	await tween.finished
	fade.visible = false

func _clear_screen() -> void:
	if is_instance_valid(screen):
		$UI/ScreenHost.remove_child(screen)
		screen.queue_free()
	screen = null

func _set_screen(scene: PackedScene, next_state: String) -> void:
	_clear_screen()
	state = next_state
	_sync_music()
	screen = scene.instantiate()
	if next_state == "tanks": screen.selected_index = selected_tank
	if next_state in ["battle", "spectate"]: screen.touch_controls = touch_enabled
	$UI/ScreenHost.add_child(screen)
	screen.action_requested.connect(_action)
	if next_state == "tanks":
		screen.tank_selected.connect(func(_id: String):
			selected_tank = screen.selected_index
			audio.play_ui("tank_select"))
	state_changed.emit(state)

func _sync_music() -> void:
	if state == "ended":
		audio.set_music("")
	elif state in ["home", "tanks"] or (state == "settings" and settings_from != "pause"):
		audio.set_music("menu")
	else:
		audio.set_music("battle", state in ["pause", "settings", "win", "loss"])

func _show_home() -> void:
	get_tree().paused = false
	_remove_game()
	_set_screen(HOME, "home")

func _remove_game() -> void:
	audio.clear_world()
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	game = null

func pick_random_map() -> int:
	if Maps.MAPS.size() < 2: return 0
	var choices: Array[int] = []
	for i in Maps.MAPS.size():
		if i != last_map: choices.append(i)
	return choices[rng.randi_range(0, choices.size() - 1)]

func start_match(restart := false) -> void:
	if changing_match: return
	changing_match = true
	await _fade_to_black()
	get_tree().paused = false
	_remove_game()
	if not restart or last_map < 0: last_map = pick_random_map()
	_clear_screen()
	state = "loading"
	_sync_music()
	state_changed.emit(state)
	card_kicker.text = "ARENA SELECTED"
	card_title.text = str(Maps.MAPS[last_map].name).to_upper()
	card_subtitle.text = str(Maps.MAPS[last_map].description)
	card.visible = true
	var card_shown := Time.get_ticks_msec()
	await get_tree().process_frame
	game = GAME.instantiate()
	game.game_menu_mode = true
	game.starting_map = last_map
	game.selected_tank = selected_tank
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.match_finished.connect(_match_finished)
	game.player_destroyed.connect(_enter_spectate)
	add_child(game)
	await game.match_ready
	game.overview_mode = false
	game._update_map_camera(1.0)
	var remaining := CARD_SECONDS - float(Time.get_ticks_msec() - card_shown) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining, true).timeout
	await _fade_from_black()
	game.battle_mode = true
	audio.follow_arena(game)
	audio.play_ui("match_start")
	changing_match = false
	_show_hud()

func _show_hud() -> void:
	if state == "pause": audio.play_ui("resume")
	audio.set_world_paused(false)
	get_tree().paused = false
	var watching: bool = is_instance_valid(game) and game.spectating
	_set_screen(HUD, "spectate" if watching else "battle")
	screen.movement_changed.connect(func(direction: Vector2):
		if is_instance_valid(game): game.touch_move = direction)
	screen.aim_changed.connect(_touch_aim)
	if watching: screen.enter_spectator()
	_update_hud()

func _enter_spectate() -> void:
	if state != "battle": return
	audio.play_ui("player_down")
	state = "spectate"
	screen.enter_spectator()
	state_changed.emit(state)

func pause_match() -> void:
	if not state in ["battle", "spectate"] or not is_instance_valid(game): return
	game.touch_move = Vector2.ZERO
	get_tree().paused = true
	audio.set_world_paused(true)
	audio.play_ui("pause")
	_set_screen(PAUSE, "pause")

func _match_finished(won: bool) -> void:
	if not state in ["battle", "spectate"]: return
	game.touch_move = Vector2.ZERO
	get_tree().paused = true
	_set_screen(WIN if won else LOSS, "win" if won else "loss")
	audio.play_ui("victory" if won else "defeat")
	screen.set_results(game.kills, maxi(game.player.health, 0), ToyTank.PLAYER_HP)

func _show_settings() -> void:
	settings_from = state
	_set_screen(SETTINGS, "settings")
	screen.set_volume(master_volume)
	screen.setting_changed.connect(func(key: String, value: Variant):
		if key == "Volume":
			master_volume = float(value)
			_apply_volume()
			if audio._allow("volume_preview", 0.13): audio.play_ui("ui_hover")
		_save_settings())

func _apply_volume() -> void:
	AudioServer.set_bus_mute(0, master_volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume / 100.0, 0.0001)))

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", master_volume)
	Bindings.save(config)
	config.save("user://settings.cfg")

func _action(action: String) -> void:
	if action in ["back", "main_menu"]: audio.play_ui("ui_back")
	elif action in ["play", "ready", "restart", "settings"]: audio.play_ui("ui_confirm")
	match action:
		"play": _set_screen(TANKS, "tanks")
		"ready": start_match()
		"restart": start_match(state != "win")
		"resume": _show_hud()
		"pause": pause_match()
		"settings": _show_settings()
		"back":
			if settings_from == "pause": _set_screen(PAUSE, "pause")
			else: _show_home()
		"main_menu": _show_home()
		"quit": request_quit()
		"fire":
			if state == "spectate":
				game.cycle_spectate(1)
				audio.play_ui("ui_hover")
			elif state == "battle" and is_instance_valid(game.player): game.player.fire()
		"mine":
			if state == "spectate":
				game.cycle_spectate(-1)
				audio.play_ui("ui_hover")
			elif state == "battle" and is_instance_valid(game.player): game.player.drop_mine()

func request_quit() -> void:
	quit_requested.emit()
	if suppress_quit: return
	if OS.has_feature("web"):
		get_tree().paused = false
		_remove_game()
		_set_screen(PAUSE, "ended")
		var stack := screen.get_node("SafeArea/Scroll/Center/Card/Stack")
		stack.get_node("Title").text = "SESSION ENDED"
		stack.get_node("Description").text = "You can close this browser tab."
		for child in stack.get_children():
			if child is BaseButton: child.visible = child.name == "MainMenu"
	else: get_tree().quit()

func _process(_delta: float) -> void:
	if state in ["battle", "spectate"]: _update_hud()

func _update_hud() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	if state == "spectate":
		screen.set_spectator_subject(game.spectate_name())
		return
	var stats := ToyTank.player_stats(game.player.variant)
	screen.set_cooldowns(game.player.cooldown, stats.fire_interval_s, game.player.mine_cooldown, ToyTank.MINE_COOLDOWN)

func _touch_aim(point: Vector2) -> void:
	if state != "battle" or not is_instance_valid(game): return
	var intersection = Plane(Vector3.UP, 1.02).intersects_ray(game.camera.project_ray_origin(point), game.camera.project_ray_normal(point))
	if intersection != null:
		game.touch_aim_active = true
		game.touch_aim_point = intersection

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_instance_valid(game) and event.device != InputEvent.DEVICE_ID_EMULATION:
		game.touch_aim_active = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if state == "spectate" and is_instance_valid(game):
		var step := _spectate_step(event)
		if step != 0:
			game.cycle_spectate(step)
			audio.play_ui("ui_hover")
			get_viewport().set_input_as_handled()
			return
	if (state in ["battle", "spectate", "pause"] and event.is_action_pressed("pause_game")) or (not state in ["battle", "spectate"] and event.is_action_pressed("ui_cancel")):
		if state in ["battle", "spectate"]: pause_match()
		elif state == "pause": _show_hud()
		elif state == "settings": _action("back")
		elif state == "tanks":
			audio.play_ui("ui_back")
			_show_home()
		get_viewport().set_input_as_handled()

func _spectate_step(event: InputEvent) -> int:
	if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		return 1
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		return -1
	return 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state in ["battle", "spectate"] and suspend_on_focus_loss: pause_match()

func _exit_tree() -> void:
	audio.stop_ui()
	audio.stop_music()
	audio.clear_world()
	if get_tree(): get_tree().paused = false
