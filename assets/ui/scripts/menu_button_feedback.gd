extends Node

@onready var audio: Node = get_node("/root/GameAudio")

var buttons: Array[BaseButton] = []
var last_button: BaseButton
var installed_at := 0

static func install(screen: Control) -> void:
	var feedback := Node.new()
	feedback.set_script(load("res://assets/ui/scripts/menu_button_feedback.gd"))
	screen.add_child(feedback)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	installed_at = Time.get_ticks_msec()
	for node in get_parent().find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		buttons.append(button)
		button.mouse_entered.connect(_hover.bind(button))
		button.mouse_exited.connect(_leave.bind(button))
		button.focus_entered.connect(func():
			last_button = button
			if Time.get_ticks_msec() - installed_at > 180 and not button.disabled:
				audio.play_ui("ui_hover"))

func _hover(button: BaseButton) -> void:
	if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
		button.grab_focus()

func _leave(button: BaseButton) -> void:
	if button.has_focus(): button.release_focus()

func _input(event: InputEvent) -> void:
	if get_parent().get_meta("capturing_binding", false): return
	if event is InputEventMouseMotion:
		var focused := get_viewport().gui_get_focus_owner()
		if focused in buttons and not focused.get_global_rect().has_point(event.position):
			focused.release_focus()
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if get_viewport().gui_get_focus_owner() != null: return
		for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev", "ui_accept"]:
			if event.is_action_pressed(action):
				if is_instance_valid(last_button) and last_button.is_visible_in_tree() and not last_button.disabled:
					last_button.grab_focus()
				else:
					for button in buttons:
						if button.is_visible_in_tree() and not button.disabled:
							button.grab_focus()
							break
				get_viewport().set_input_as_handled()
				return
