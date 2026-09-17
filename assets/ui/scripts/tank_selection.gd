extends Control

signal action_requested(action: String)
signal tank_selected(tank_id: String)

const BADGES := ["azure", "mint", "red", "gold", "violet", "ivory", "orange", "slate"]
const COLORS := ["75c8e3", "9bd0b5", "e49a89", "f0ce70", "bba1df", "ece0c4", "e8b17a", "a8bdc9"]
const SHORT_NAMES := ["Scout", "Cruiser", "Bulldog", "Sprinter", "Needle", "Duelist", "Mortar", "Command"]

static func catalog() -> Array:
	var values: Array = []
	for i in ToyTank.IDS.size():
		var data := ToyTank.player_stats(i)
		data["badge"] = BADGES[i]
		values.append(data)
	return values

@export var selected_index: int = 0
@export var safe_area_insets: Vector4 = Vector4.ZERO
@onready var stack: VBoxContainer = $SafeArea/Scroll/Center/Card/Stack
@onready var card: PanelContainer = $SafeArea/Scroll/Center/Card
var buttons: Array[Button] = []
var stat_values: Array[Label] = []

func _ready() -> void:
	var display_font := FontVariation.new()
	display_font.base_font = load("res://assets/ui/fonts/Fredoka.ttf")
	display_font.variation_opentype = {2003265652: 650.0}
	stack.get_node("Title").add_theme_font_override("font", display_font)
	for i in ToyTank.IDS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(64, 102)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.tooltip_text = ToyTank.NAMES[i]
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 5
		column.offset_right = -5
		column.offset_top = 4
		column.offset_bottom = -8
		column.add_theme_constant_override("separation", 0)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := TextureRect.new()
		picture.texture = load("res://assets/ui/portraits/%s.png" % ToyTank.IDS[i])
		picture.custom_minimum_size.y = 66
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(picture)
		var label := Label.new()
		label.text = SHORT_NAMES[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
		button.add_child(column)
		button.pressed.connect(select_tank.bind(i))
		stack.get_node("Roster").add_child(button)
		buttons.append(button)
		for state in ["normal", "hover", "pressed"]:
			var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			style.content_margin_left = 3
			style.content_margin_right = 3
			style.content_margin_top = 3
			style.content_margin_bottom = 3
			style.bg_color = Color("314e61") if state != "pressed" else Color("496477")
			if state == "hover":
				style.bg_color = Color("527d92")
				style.border_color = Color("fff2c9")
			if state == "pressed": style.border_color = Color("f4cb6c")
			button.add_theme_stylebox_override(state, style)
	for title in ["Speed", "Reload", "Hull", "Shell damage"]:
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"DarkPanel"
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := theme.get_stylebox("panel", "DarkPanel").duplicate() as StyleBoxFlat
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", style)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		var label := Label.new()
		label.text = title
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("a6bec9"))
		column.add_child(label)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 23)
		column.add_child(value)
		stat_values.append(value)
		panel.add_child(column)
		stack.get_node("Hero/Details/Stats").add_child(panel)
	stack.get_node("Actions/Back").pressed.connect(func(): action_requested.emit("main_menu"))
	stack.get_node("Actions/Ready").pressed.connect(func(): action_requested.emit("ready"))
	resized.connect(_reflow)
	select_tank(clampi(selected_index, 0, catalog().size() - 1))
	preload("res://assets/ui/scripts/menu_button_feedback.gd").install(self)
	_reflow.call_deferred()
	_safe_focus.call_deferred(buttons[selected_index])

func select_tank(index: int) -> void:
	selected_index = clampi(index, 0, catalog().size() - 1)
	var data: Dictionary = catalog()[selected_index]
	stack.get_node("Hero/Portrait").show_tank(selected_index)
	stack.get_node("Hero/Details/Name").text = str(data.name)
	stack.get_node("Hero/Details/Name").add_theme_color_override("font_color", Color(COLORS[selected_index]))
	stack.get_node("Hero/Details/Class").text = "Two barrels. Double trouble." if int(data.shots_per_trigger) == 2 else "One barrel. Make it count."
	stack.get_node("Hero/Details/Description").text = "%d shells per volley" % data.shots_per_trigger if int(data.shots_per_trigger) == 2 else "1 shell per volley"
	var values := ["%.1f m/s" % data.speed_mps, "%.2f s" % data.fire_interval_s, "%d HP" % data.player_hp, "%d HP" % data.damage_per_shell]
	for i in stat_values.size(): stat_values[i].text = values[i]
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == selected_index)
		var label: Label = buttons[i].get_child(0).get_child(1)
		label.add_theme_color_override("font_color", Color("ffdf89") if i == selected_index else Color("e5edf0"))
	tank_selected.emit(str(data.id))

func _reflow() -> void:
	var narrow := size.x < 650
	var compact := size.y < 500
	var short_phone := narrow and size.y < 720
	var tight := compact or short_phone
	var margin := 10 if narrow or compact else 24
	var available := size.x - margin * 2 - safe_area_insets.x - safe_area_insets.z - 12
	card.custom_minimum_size.x = clampf(available, 260, 1040)
	var panel := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel.content_margin_left = 12 if narrow else 24
	panel.content_margin_right = 12 if narrow else 24
	panel.content_margin_top = 12 if narrow or compact else 22
	panel.content_margin_bottom = 12 if compact else (16 if narrow else 24)
	card.add_theme_stylebox_override("panel", panel)
	stack.add_theme_constant_override("separation", 6 if compact else (8 if narrow else 16))
	stack.get_node("Hero").vertical = narrow
	stack.get_node("Hero").add_theme_constant_override("separation", 4 if narrow else 24)
	stack.get_node("Hero/Portrait").visible = not short_phone
	stack.get_node("Hero/Portrait").custom_minimum_size = Vector2(100, 138 if narrow else (130 if compact else 252))
	stack.get_node("Hero/Details/Class").visible = not tight
	stack.get_node("Title").add_theme_font_size_override("font_size", 28 if narrow else (30 if compact else 42))
	stack.get_node("Hero/Details/Name").add_theme_font_size_override("font_size", 24 if narrow or compact else 33)
	stack.get_node("Hero/Details/Name").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narrow else HORIZONTAL_ALIGNMENT_LEFT
	stack.get_node("Hero/Details/Class").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narrow else HORIZONTAL_ALIGNMENT_LEFT
	stack.get_node("Hero/Details/Description").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narrow else HORIZONTAL_ALIGNMENT_LEFT
	stack.get_node("Roster").columns = 4 if narrow or (size.x < 1000 and not compact) else 8
	stack.get_node("Roster").add_theme_constant_override("h_separation", 6 if narrow else 10)
	stack.get_node("Roster").add_theme_constant_override("v_separation", 8)
	for button in buttons:
		button.custom_minimum_size = Vector2(54, 72 if tight else (78 if narrow else 102))
		button.get_child(0).get_child(0).custom_minimum_size.y = 40 if tight else (44 if narrow else 66)
		button.get_child(0).get_child(1).add_theme_font_size_override("font_size", 11 if size.x < 360 else (12 if narrow or compact else 15))
	for value in stat_values:
		value.add_theme_font_size_override("font_size", 18 if tight else 23)
		value.get_parent().get_child(0).add_theme_font_size_override("font_size", 12 if tight else 14)
		var stat_panel: PanelContainer = value.get_parent().get_parent()
		var stat_style := stat_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		stat_style.content_margin_top = 4 if tight else 8
		stat_style.content_margin_bottom = 4 if tight else 8
		stat_panel.add_theme_stylebox_override("panel", stat_style)
	for button in stack.get_node("Actions").get_children():
		button.custom_minimum_size.y = 48 if tight else 56
	for edge in ["left", "top", "right", "bottom"]:
		var inset: float = safe_area_insets[["left", "top", "right", "bottom"].find(edge)]
		$SafeArea.add_theme_constant_override("margin_" + edge, margin + int(inset))

static func stats_text(data: Dictionary) -> String:
	return "Top speed       %.1f m/s\nHull strength   %d HP\nShell damage    %d HP\nFire interval   %.2f s\nShells / volley %d" % [data.speed_mps, data.player_hp, data.damage_per_shell, data.fire_interval_s, data.shots_per_trigger]

func _safe_focus(button: Control) -> void:
	if is_inside_tree() and is_instance_valid(button) and button.is_visible_in_tree(): button.grab_focus()
