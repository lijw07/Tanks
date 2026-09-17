extends Control

signal action_requested(action: String)
@onready var menu: VBoxContainer = $Margin/Scroll/Layout/Menu

func _ready() -> void:
	menu.get_node("Actions/Play").pressed.connect(func(): action_requested.emit("play"))
	menu.get_node("Actions/Settings").pressed.connect(func(): action_requested.emit("settings"))
	menu.get_node("Actions/Quit").pressed.connect(func(): action_requested.emit("quit"))
	if OS.has_feature("web"): menu.get_node("Actions/Quit").text = "End session"
	var font := FontVariation.new()
	font.base_font = load("res://assets/ui/fonts/Fredoka.ttf")
	font.variation_opentype = {2003265652: 700.0, 2003072104: 110.0}
	menu.get_node("Title").add_theme_font_override("font", font)
	resized.connect(_reflow)
	preload("res://assets/ui/scripts/menu_button_feedback.gd").install(self)
	_reflow.call_deferred()
	_safe_focus.call_deferred(menu.get_node("Actions/Play"))

func _reflow() -> void:
	var compact := size.y < 520
	var phone := size.x < 680
	menu.custom_minimum_size.x = minf(360, size.x - 48)
	menu.add_theme_constant_override("separation", 8 if compact else 18)
	menu.get_node("Title").add_theme_font_size_override("font_size", 40 if compact else (58 if phone else 78))
	menu.get_node("Title").add_theme_constant_override("line_spacing", -10 if compact else -20)
	menu.get_node("Tagline").visible = not compact
	menu.get_node("Space").custom_minimum_size.y = 2 if compact else 12
	menu.get_node("Actions").custom_minimum_size.x = minf(300, size.x - 60)
	menu.get_node("Actions").add_theme_constant_override("separation", 9 if compact else 14)
	for button in menu.get_node("Actions").get_children():
		button.custom_minimum_size.y = 50 if compact else 62
		button.add_theme_font_size_override("font_size", 22 if compact else 25)

func _safe_focus(button: Control) -> void:
	if is_inside_tree() and is_instance_valid(button) and button.is_visible_in_tree(): button.grab_focus()
