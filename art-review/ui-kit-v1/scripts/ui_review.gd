extends Control

const SCREENS := {
	"Tanks": preload("../scenes/tank_selection.tscn"),
	"Start": preload("../scenes/start_menu.tscn"),
	"Pause": preload("../scenes/pause_menu.tscn"),
	"Win": preload("../scenes/win_screen.tscn"),
	"Loss": preload("../scenes/loss_screen.tscn"),
	"Settings": preload("../scenes/settings_menu.tscn"),
	"HUD": preload("../scenes/battle_hud.tscn")
}
var current: Control
var current_name := "Start"
var previous_name := "Start"
var shots_fired := 0
var next_shot_at := 0
var selected_tank := 0
var settings_values := {"Music": true, "Sound": true, "ReducedMotion": false, "Volume": 65.0}

func _ready() -> void:
	var initial := "Start"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screen="):
			initial = argument.trim_prefix("--screen=")
	show_screen(initial if initial in SCREENS else "Start")

func show_screen(screen_name: String) -> void:
	if current:
		$ScreenHost.remove_child(current)
		current.queue_free()
	current_name = screen_name
	current = SCREENS[screen_name].instantiate()
	if screen_name == "Tanks":
		current.selected_index = selected_tank
	$ScreenHost.add_child(current)
	current.action_requested.connect(_action)
	if screen_name == "HUD":
		current.set_health(float(tank_data().player_hp), float(tank_data().player_hp))
		current.set_targets(0, 7)
		current.set_fire_ready(Time.get_ticks_msec() >= next_shot_at)
		current.get_node("HealthPanel/Stack/Name").text = str(tank_data().name).to_upper()
	if screen_name == "Tanks":
		current.tank_selected.connect(func(_id: String): selected_tank = current.selected_index)
	if screen_name == "Settings":
		var stack := current.get_node("SafeArea/Scroll/Center/Card/Stack")
		for key in settings_values:
			var field := stack.get_node(str(key))
			if field is CheckButton:
				field.set_pressed_no_signal(settings_values[key])
			elif field is HSlider:
				field.set_value_no_signal(settings_values[key])
		current.setting_changed.connect(func(key: String, value: Variant): settings_values[key] = value)

func _action(action: String) -> void:
	match action:
		"play": show_screen("Tanks")
		"ready", "restart":
			shots_fired = 0
			next_shot_at = 0
			show_screen("HUD")
		"resume": show_screen("HUD")
		"pause": show_screen("Pause")
		"settings":
			previous_name = current_name
			show_screen("Settings")
		"back": show_screen(previous_name)
		"main_menu": show_screen("Start")
		"how_to":
			current.get_node("SafeArea/Scroll/Center/Card/Stack/Description").text = "WASD to move. Mouse to aim and fire. Space to place a mine.\nTouch: move pad and fire button.\nThis review demonstrates UI only."
		"fire":
			if Time.get_ticks_msec() < next_shot_at: return
			shots_fired += int(tank_data().shots_per_trigger)
			next_shot_at = Time.get_ticks_msec() + int(float(tank_data().fire_interval_s) * 1000)
			current.set_fire_ready(false)
		"mine":
			current.get_node("Mine").text = "SET!"

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if current_name == "HUD": show_screen("Pause")
		elif current_name == "Pause": show_screen("HUD")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and current_name == "HUD":
		_action("mine")

func tank_data() -> Dictionary:
	return preload("tank_selection.gd").catalog()[selected_tank]

func _process(_delta: float) -> void:
	if is_instance_valid(current) and current_name == "HUD":
		current.set_fire_ready(Time.get_ticks_msec() >= next_shot_at)
