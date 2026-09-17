extends Control

signal action_requested(action: String)
signal movement_changed(direction: Vector2)
signal aim_changed(point: Vector2)


@export var touch_controls: bool = false
@export var safe_area_insets: Vector4 = Vector4.ZERO
var spectating := false
var spectate_actions: HBoxContainer
var _touch_index: int = -1
var _mouse_drag := false

func _ready() -> void:
	$Pause.pressed.connect(func(): action_requested.emit("pause"))
	$Fire.pressed.connect(func(): action_requested.emit("fire"))
	$Mine.pressed.connect(func(): action_requested.emit("mine"))
	$Movement.gui_input.connect(_movement_input)
	var base := StyleBoxFlat.new()
	base.bg_color = Color("243e50")
	base.border_color = Color("10212d")
	base.set_border_width_all(3)
	base.set_corner_radius_all(80)
	$Movement/Base.add_theme_stylebox_override("panel", base)
	var knob := base.duplicate() as StyleBoxFlat
	knob.bg_color = Color("f4cb6c")
	$Movement/Knob.add_theme_stylebox_override("panel", knob)
	resized.connect(_reflow)
	_reflow.call_deferred()

func _reflow() -> void:
	var compact := size.x < 600 or size.y < 500
	var margin := 14.0 if compact else 24.0
	var left := margin + safe_area_insets.x
	var top := margin + safe_area_insets.y
	var right := size.x - margin - safe_area_insets.z
	var bottom := size.y - margin - safe_area_insets.w
	$SpectatorName.position = Vector2(left, top + 12)
	$SpectatorName.size = Vector2(maxf(0, right - left - 72), 28)
	$SpectatorName.clip_text = true
	$Pause.position = Vector2(right - 56, top)
	$Pause.size = Vector2(56, 56)
	$Movement.visible = not spectating and (touch_controls or DisplayServer.is_touchscreen_available())
	$Movement.position = Vector2(left, bottom - 132)
	$Movement.size = Vector2(132, 132)
	var narrow := size.x < 600
	var weapon_size := Vector2(72, 72) if compact else Vector2(80, 80)
	$Fire.size = weapon_size
	$Mine.size = weapon_size
	$Fire.position = Vector2(right - weapon_size.x, bottom - weapon_size.y)
	$Mine.position = Vector2(right - weapon_size.x if narrow else right - weapon_size.x * 2 - 12, bottom - weapon_size.y * 2 - 10 if narrow else bottom - weapon_size.y)
	$Pause.tooltip_text = "Pause (%s)" % preload("res://scripts/control_bindings.gd").label("pause_game")
	$Hint.text = _spectator_hint() if spectating else "%s  Move    •    Mouse  Aim    •    %s  Fire    •    %s  Mine" % [preload("res://scripts/control_bindings.gd").movement_label(), preload("res://scripts/control_bindings.gd").label("fire"), preload("res://scripts/control_bindings.gd").label("mine")]
	$Hint.visible = spectating and size.x >= 700
	$Hint.position = Vector2(left, bottom - (96.0 if spectating else 38.0))
	$Hint.size = Vector2(maxf(0, size.x - 2 * margin - 390), 24)
	if is_instance_valid(spectate_actions):
		spectate_actions.visible = spectating
		spectate_actions.position = Vector2(left, bottom - 52)
		spectate_actions.size = Vector2(minf(320.0, maxf(0.0, right - left)), 52)

func _spectator_hint() -> String:
	var bindings := preload("res://scripts/control_bindings.gd")
	var left: String = bindings.label("move_left").split(" / ")[0]
	var right: String = bindings.label("move_right").split(" / ")[0]
	return "%s / %s  Switch tank    •    %s  Menu" % [left, right, bindings.label("pause_game")]

func enter_spectator() -> void:
	spectating = true
	$SpectatorName.show()
	$Fire.set_navigation("Next")
	$Mine.set_navigation("Previous")
	_build_spectate_actions()
	_reflow()

func _build_spectate_actions() -> void:
	if is_instance_valid(spectate_actions):
		return
	spectate_actions = HBoxContainer.new()
	spectate_actions.name = "SpectateActions"
	spectate_actions.add_theme_constant_override("separation", 10)
	add_child(spectate_actions)
	_add_spectate_action("Try again", "restart", &"PrimaryButton")
	_add_spectate_action("Main menu", "main_menu", &"Button")

func _add_spectate_action(label: String, action: String, variation: StringName) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(150, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.theme_type_variation = variation
	button.pressed.connect(func(): action_requested.emit(action))
	spectate_actions.add_child(button)

func set_spectator_subject(tank_name: String) -> void:
	$SpectatorName.text = "Spectating · " + tank_name

func set_cooldowns(fire_remaining: float, fire_duration: float, mine_remaining: float, mine_duration: float) -> void:
	$Fire.set_cooldown(fire_remaining, fire_duration)
	$Mine.set_cooldown(mine_remaining, mine_duration)

func _movement_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_move_knob(event.position)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_reset_knob()
	if event is InputEventScreenDrag and event.index == _touch_index:
		_move_knob(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_drag = event.pressed
		if _mouse_drag:
			_move_knob(event.position)
		else:
			_reset_knob()
	if event is InputEventMouseMotion and _mouse_drag:
		_move_knob(event.position)

func _move_knob(local_position: Vector2) -> void:
	var delta := (local_position - Vector2(66, 66)).limit_length(34)
	$Movement/Knob.position = Vector2(38, 38) + delta
	movement_changed.emit(delta / 34.0)

func _reset_knob() -> void:
	$Movement/Knob.position = Vector2(38, 38)
	movement_changed.emit(Vector2.ZERO)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and _mouse_drag:
		_mouse_drag = false
		_reset_knob()
	if event is InputEventScreenTouch and not event.pressed and event.index == _touch_index:
		_touch_index = -1
		_reset_knob()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		aim_changed.emit(event.position)
	elif event is InputEventScreenDrag:
		aim_changed.emit(event.position)
