extends Control

signal action_requested(action: String)
signal tank_selected(tank_id: String)

const CATALOG = preload("../tank_stats.json")

static func catalog() -> Array:
	return CATALOG.data.tanks

@export var selected_index: int = 0
@export var safe_area_insets: Vector4 = Vector4.ZERO
@onready var stack: VBoxContainer = $SafeArea/Scroll/Center/Card/Stack
@onready var card: PanelContainer = $SafeArea/Scroll/Center/Card
var buttons: Array[Button] = []

func _ready() -> void:
	var display_font := FontVariation.new()
	display_font.base_font = ThemeDB.fallback_font
	display_font.variation_embolden = 0.7
	stack.get_node("Title").add_theme_font_override("font", display_font)
	for i in catalog().size():
		var data: Dictionary = catalog()[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(76, 106)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.tooltip_text = str(data.name)
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.offset_left = 6
		column.offset_right = -6
		column.offset_top = 6
		column.offset_bottom = -6
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := TextureRect.new()
		picture.texture = load(get_script().resource_path.get_base_dir().path_join("../badges/tank-%s.svg" % data.badge))
		picture.custom_minimum_size.y = 63
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(picture)
		var label := Label.new()
		label.text = str(data.name).split(" ")[1]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
		button.add_child(column)
		button.pressed.connect(select_tank.bind(i))
		stack.get_node("Roster").add_child(button)
		buttons.append(button)
	stack.get_node("Actions/Back").pressed.connect(func(): action_requested.emit("main_menu"))
	stack.get_node("Actions/Ready").pressed.connect(func(): action_requested.emit("ready"))
	resized.connect(_reflow)
	select_tank(clampi(selected_index, 0, catalog().size() - 1))
	_reflow.call_deferred()
	buttons[selected_index].grab_focus.call_deferred()

func select_tank(index: int) -> void:
	selected_index = clampi(index, 0, catalog().size() - 1)
	var data: Dictionary = catalog()[selected_index]
	stack.get_node("Hero/Portrait").texture = load(get_script().resource_path.get_base_dir().path_join("../badges/tank-%s.svg" % data.badge))
	stack.get_node("Hero/Details/Name").text = str(data.name).to_upper()
	stack.get_node("Hero/Details/Class").text = "TWIN BARRELS" if int(data.shots_per_trigger) == 2 else "SINGLE BARREL"
	stack.get_node("Hero/Details/Description").text = "Two shells per trigger, fired in sequence." if int(data.shots_per_trigger) == 2 else "One shell per trigger. One hit point per shell."
	stack.get_node("Hero/Details/Stats").text = stats_text(data)
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == selected_index)
		buttons[i].theme_type_variation = &"PrimaryButton" if i == selected_index else &"Button"
		var label: Label = buttons[i].get_child(0).get_child(1)
		label.add_theme_color_override("font_color", Color("152027") if i == selected_index else Color("e5edf0"))
		label.text = ("✓ " if i == selected_index else "") + str(catalog()[i].name).split(" ")[1]
	tank_selected.emit(str(data.id))

func _reflow() -> void:
	var available := size.x - 52 - safe_area_insets.x - safe_area_insets.z
	card.custom_minimum_size.x = clampf(available, 250, 1000)
	var narrow := size.x < 650
	stack.get_node("Hero").vertical = narrow
	stack.get_node("Hero/Portrait").custom_minimum_size = Vector2(100, 130 if narrow else 190)
	stack.get_node("Title").add_theme_font_size_override("font_size", 22 if narrow else 36)
	stack.get_node("Roster").columns = 2 if size.x < 420 else (4 if size.x < 1100 else 8)
	$SafeArea.add_theme_constant_override("margin_left", 20 + int(safe_area_insets.x))
	$SafeArea.add_theme_constant_override("margin_top", 20 + int(safe_area_insets.y))
	$SafeArea.add_theme_constant_override("margin_right", 20 + int(safe_area_insets.z))
	$SafeArea.add_theme_constant_override("margin_bottom", 20 + int(safe_area_insets.w))

static func stats_text(data: Dictionary) -> String:
	return "Top speed       %.1f m/s\nHull strength   %d HP\nShell damage    %d HP\nFire interval   %.2f s\nShells / volley %d" % [data.speed_mps, data.player_hp, data.damage_per_shell, data.fire_interval_s, data.shots_per_trigger]
