extends Control

@onready var audio: Node = get_node("/root/GameAudio")

signal action_requested(action: String)
signal setting_changed(setting: String, value: Variant)
const Bindings = preload("res://scripts/control_bindings.gd")
@onready var stack: VBoxContainer = $SafeArea/Scroll/Center/Card/Stack
var binding_buttons: Dictionary = {}
var pending := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in Bindings.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = Bindings.ACTIONS[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 17)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 48)
		button.add_theme_font_size_override("font_size", 16)
		button.clip_text = true
		button.text = Bindings.label(action)
		button.pressed.connect(_listen.bind(action))
		row.add_child(button)
		stack.get_node("Bindings/Rows").add_child(row)
		binding_buttons[action] = button
	stack.get_node("Volume").value_changed.connect(func(value: float):
		stack.get_node("VolumeLabel").text = "Volume   %d%%" % value
		setting_changed.emit("Volume", value))
	stack.get_node("Done").pressed.connect(func(): action_requested.emit("back"))
	stack.get_node("Heading/Reset").pressed.connect(func():
		audio.play_ui("ui_confirm")
		Bindings.reset()
		_refresh()
		setting_changed.emit("Bindings", null))
	preload("res://assets/ui/scripts/menu_button_feedback.gd").install(self)
	resized.connect(_reflow)
	_reflow.call_deferred()

func set_volume(value: float) -> void:
	stack.get_node("Volume").set_value_no_signal(value)
	stack.get_node("VolumeLabel").text = "Volume   %d%%" % value

func _listen(action: String) -> void:
	audio.play_ui("ui_confirm")
	pending = action
	set_meta("capturing_binding", true)
	binding_buttons[action].text = "Press a key…"
	stack.get_node("Status").text = "Press a key or mouse button. Esc cancels."

func _refresh() -> void:
	pending = ""
	set_meta("capturing_binding", false)
	for action in binding_buttons: binding_buttons[action].text = Bindings.label(action)
	stack.get_node("Status").text = "Select a control to change its binding."

func _input(event: InputEvent) -> void:
	if pending.is_empty(): return
	if event is InputEventKey:
		if not event.pressed or event.echo: return
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			_refresh()
			return
		if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]: return
	elif event is InputEventMouseButton:
		if not event.pressed: return
		get_viewport().set_input_as_handled()
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return
	else: return
	var candidate: InputEvent = event.duplicate()
	if candidate is InputEventKey:
		candidate.physical_keycode = candidate.physical_keycode if candidate.physical_keycode else candidate.keycode
		candidate.keycode = 0
		candidate.unicode = 0
	var used := Bindings.conflict(pending, candidate)
	if not used.is_empty():
		stack.get_node("Status").text = "Already used for %s. Choose another key." % used.to_lower()
		return
	Bindings.set_events(pending, [candidate])
	audio.play_ui("ui_confirm")
	_refresh()
	setting_changed.emit("Bindings", null)

func _reflow() -> void:
	var narrow := size.x < 600
	var compact := size.y < 500
	var margin := 12 if narrow or compact else 24
	for edge in ["left", "top", "right", "bottom"]:
		$SafeArea.add_theme_constant_override("margin_" + edge, margin)
	$SafeArea/Scroll/Center/Card.custom_minimum_size.x = clampf(size.x - margin * 2 - 12, 270, 600)
	stack.add_theme_constant_override("separation", 6 if compact else 10)
	stack.get_node("Title").add_theme_font_size_override("font_size", 28 if compact else (30 if narrow else 40))
	stack.get_node("VolumeLabel").add_theme_font_size_override("font_size", 16 if compact else 18)
	stack.get_node("Volume").custom_minimum_size.y = 24 if compact else 32
	stack.get_node("Done").add_theme_font_size_override("font_size", 20 if compact else 22)
	stack.get_node("Bindings").custom_minimum_size.y = clampf(size.y - 405, 96, 280)
	for button in binding_buttons.values():
		button.custom_minimum_size.x = 122 if narrow else 190
		button.get_parent().get_child(0).add_theme_font_size_override("font_size", 15 if narrow else 17)
