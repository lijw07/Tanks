extends Control

signal action_requested(action: String)
@onready var layout: BoxContainer = $Margin/Scroll/Layout

func _ready() -> void:
	$Margin/Scroll/Layout/Menu/Actions/Play.pressed.connect(func(): action_requested.emit("play"))
	$Margin/Scroll/Layout/Menu/Actions/Settings.pressed.connect(func(): action_requested.emit("settings"))
	$Margin/Scroll/Layout/Menu/Actions/Quit.pressed.connect(func(): action_requested.emit("quit"))
	if OS.has_feature("web"):
		$Margin/Scroll/Layout/Menu/Actions/Quit.text = "End session"
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 1.6
	$Margin/Scroll/Layout/Menu/Title.add_theme_font_override("font", font)
	resized.connect(_reflow)
	_reflow.call_deferred()
	_safe_focus.call_deferred($Margin/Scroll/Layout/Menu/Actions/Play)

func _reflow() -> void:
	var phone := size.x < 680
	layout.vertical = phone
	$Margin.add_theme_constant_override("margin_left", 24 if phone else 70)
	$Margin.add_theme_constant_override("margin_right", 24 if phone else 70)
	$Margin.add_theme_constant_override("margin_top", 24 if size.y < 600 else 60)
	$Margin.add_theme_constant_override("margin_bottom", 24 if size.y < 600 else 60)
	$Margin/Scroll/Layout/Menu/Title.add_theme_font_size_override("font_size", 60 if phone else (64 if size.x < 1000 else 88))
	$Margin/Scroll/Layout/Display.visible = not (size.y < 500)
	$Margin/Scroll/Layout/Display.custom_minimum_size = Vector2(0, 280 if phone else 420)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101c24"))
	var spacing := 46.0
	for i in range(0, int(size.x / spacing) + 1):
		draw_line(Vector2(i * spacing, 0), Vector2(i * spacing, size.y), Color(0.25, 0.45, 0.48, 0.09))
	for i in range(0, int(size.y / spacing) + 1):
		draw_line(Vector2(0, i * spacing), Vector2(size.x, i * spacing), Color(0.25, 0.45, 0.48, 0.09))
	draw_line(Vector2(0, 0), Vector2(size.x, 0), Color("f6a34a"), 8)
	if size.x >= 680:
		var center := Vector2(size.x * 0.74, size.y * 0.48)
		draw_arc(center, minf(size.x * 0.2, 270), 0, TAU, 80, Color("2a434c"), 2, true)
		draw_arc(center, minf(size.x * 0.18, 245), 0.25, 2.1, 40, Color("80b9ae"), 3, true)

func _safe_focus(button: Control) -> void:
	if is_inside_tree() and is_instance_valid(button) and button.is_visible_in_tree():
		button.grab_focus()
