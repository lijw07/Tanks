extends Control

signal action_requested(action: String)
signal setting_changed(setting: String, value: Variant)

@export var screen_kind: String = "start_menu"
@export var safe_area_insets: Vector4 = Vector4.ZERO:
	set(value):
		safe_area_insets = value
		if is_node_ready():
			_reflow()

@onready var card: PanelContainer = $SafeArea/Scroll/Center/Card
@onready var stack: VBoxContainer = $SafeArea/Scroll/Center/Card/Stack

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var display_font := FontVariation.new()
	display_font.base_font = ThemeDB.fallback_font
	display_font.variation_embolden = 0.9
	stack.get_node("Title").add_theme_font_override("font", display_font)
	resized.connect(_reflow)
	for child in stack.get_children():
		if child is Button and child.has_meta("action"):
			child.pressed.connect(func(): action_requested.emit(str(child.get_meta("action"))))
		if child is CheckButton:
			child.toggled.connect(func(value: bool): setting_changed.emit(child.name, value))
		if child is HSlider:
			child.value_changed.connect(func(value: float): setting_changed.emit(child.name, value))
	_reflow.call_deferred()
	for child in stack.get_children():
		if child is Button:
			child.grab_focus.call_deferred()
			break

func _reflow() -> void:
	var compact := size.y < 520
	var narrow := size.x < 600
	var margin := 12 if compact or narrow else 24
	$SafeArea.add_theme_constant_override("margin_left", margin + int(safe_area_insets.x))
	$SafeArea.add_theme_constant_override("margin_top", margin + int(safe_area_insets.y))
	$SafeArea.add_theme_constant_override("margin_right", margin + int(safe_area_insets.z))
	$SafeArea.add_theme_constant_override("margin_bottom", margin + int(safe_area_insets.w))
	var available := size.x - margin * 2 - safe_area_insets.x - safe_area_insets.z - 12
	card.custom_minimum_size.x = clampf(available, 240.0, 440.0)
	stack.add_theme_constant_override("separation", 8 if compact else 14)
	stack.get_node("Title").add_theme_font_size_override("font_size", 30 if compact else (38 if narrow else 48))
	var title: Label = stack.get_node("Title")
	var desired: int = title.get_theme_font_size("font_size")
	var font := title.get_theme_font("font")
	var widest := 0.0
	for line in title.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, desired).x)
	if widest > card.custom_minimum_size.x - 48:
		title.add_theme_font_size_override("font_size", maxi(22, int(desired * (card.custom_minimum_size.x - 48) / widest)))
	stack.get_node("Emblem").visible = not compact
	stack.get_node("Description").visible = not compact
	for child in stack.get_children():
		if child is Button:
			child.custom_minimum_size.y = 48 if compact else 56

func set_results(tanks_tagged: int, hull_hp: int, max_hp: int = 3) -> void:
	var stats := get_node_or_null("SafeArea/Scroll/Center/Card/Stack/Stats")
	if stats:
		stats.get_node("Score").text = "%02d\nTARGETS CLEARED" % maxi(tanks_tagged, 0)
		stats.get_node("Armor").text = "%d / %d\nHULL HP" % [clampi(hull_hp, 0, max_hp), max_hp]
