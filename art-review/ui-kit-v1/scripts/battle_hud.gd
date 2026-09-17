extends Control

signal action_requested(action: String)
signal movement_changed(direction: Vector2)

@export var touch_controls: bool = false
@export var safe_area_insets: Vector4 = Vector4.ZERO
var _touch_index: int = -1
var _mouse_drag := false

func _ready() -> void:
	var score_style := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
	score_style.content_margin_left = 8
	score_style.content_margin_right = 8
	$ScorePanel.add_theme_stylebox_override("panel", score_style)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("263431")
	track.set_corner_radius_all(7)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Color("a9cbbb")
	$HealthPanel/Stack/Health.add_theme_stylebox_override("background", track)
	$HealthPanel/Stack/Health.add_theme_stylebox_override("fill", fill)
	$Pause.pressed.connect(func(): action_requested.emit("pause"))
	$Fire.pressed.connect(func(): action_requested.emit("fire"))
	$Mine.pressed.connect(func(): action_requested.emit("mine"))
	$Movement.gui_input.connect(_movement_input)
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.10, 0.16, 0.19, 0.85)
	base.border_color = Color("49616b")
	base.set_border_width_all(3)
	base.set_corner_radius_all(80)
	$Movement/Base.add_theme_stylebox_override("panel", base)
	var knob := base.duplicate() as StyleBoxFlat
	knob.bg_color = Color("a9cbbb")
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
	$HealthPanel.position = Vector2(left, top)
	$HealthPanel.size = Vector2(166 if compact else 230, 0)
	$HealthPanel/Stack/Name.add_theme_font_size_override("font_size", 11 if compact else 14)
	$HealthPanel/Stack/Value.add_theme_font_size_override("font_size", 10 if compact else 12)
	$ScorePanel/Time.add_theme_font_size_override("font_size", 14 if compact else 22)
	$ScorePanel.position = Vector2(right - (164 if compact else size.x * 0.5), top)
	$ScorePanel.set_deferred("size", Vector2(92 if compact else 150, 0))
	if size.x < 380:
		$ScorePanel.position.y = top + 104
		$ScorePanel.position.x = left
	$Pause.position = Vector2(right - 56, top)
	$Pause.size = Vector2(56, 56)
	$Movement.visible = touch_controls or DisplayServer.is_touchscreen_available() or size.x < 1100
	$Movement.position = Vector2(left, bottom - 132)
	$Movement.size = Vector2(132, 132)
	$Fire.position = Vector2(right - 90, bottom - 90)
	$Fire.size = Vector2(90, 90)
	$Mine.position = Vector2(right - 90, bottom - 160)
	$Mine.size = Vector2(90, 56)
	$Ammo.position = Vector2(right - 134, bottom - 196)
	$Ammo.size = Vector2(134, 22)
	$Hint.visible = not $Movement.visible
	$Hint.position = Vector2(left, bottom - 38)
	$Hint.size = Vector2(maxf(0, size.x - 2 * margin - 180), 24)

func set_health(current: float, maximum: float = 3.0) -> void:
	$HealthPanel/Stack/Health.max_value = maxf(maximum, 1.0)
	$HealthPanel/Stack/Health.value = clampf(current, 0.0, maximum)
	$HealthPanel/Stack/Value.text = "%d / %d HP" % [current, maximum]

func set_ammo(current: int, maximum: int) -> void:
	$Ammo.text = "%d / %d SHELLS" % [current, maximum]

func set_round(seconds_remaining: int, round_number: int) -> void:
	var seconds := maxi(seconds_remaining, 0)
	$ScorePanel/Time.text = "%02d:%02d\nROUND %02d" % [seconds / 60, seconds % 60, round_number]

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

func set_targets(cleared: int, total: int) -> void:
	$ScorePanel/Time.text = "%d / %d\nTARGETS" % [cleared, total]

func set_fire_ready(ready: bool) -> void:
	$Ammo.text = "READY" if ready else "COOLDOWN"
	$Fire.disabled = not ready
