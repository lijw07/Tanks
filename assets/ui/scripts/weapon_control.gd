extends Button

@export var weapon_name := "Fire"
@export var weapon_icon: Texture2D
@export var binding_action := "fire"
var recharge := 1.0
var navigation_mode := false
var navigation_direction := 1.0
var icon_view: TextureRect
var fill_material: ShaderMaterial

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	icon_view = TextureRect.new()
	icon_view.texture = weapon_icon
	icon_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_view.offset_left = 4
	icon_view.offset_right = -4
	icon_view.offset_top = 4
	icon_view.offset_bottom = -4
	icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_material = ShaderMaterial.new()
	fill_material.shader = preload("res://assets/ui/shaders/icon_recharge.gdshader")
	icon_view.material = fill_material
	add_child(icon_view)
	mouse_entered.connect(func(): fill_material.set_shader_parameter("hovered", not disabled); queue_redraw())
	mouse_exited.connect(func(): fill_material.set_shader_parameter("hovered", false); queue_redraw())
	tooltip_text = "%s (%s)" % [weapon_name, preload("res://scripts/control_bindings.gd").label(binding_action)]

func set_cooldown(remaining: float, duration: float) -> void:
	if navigation_mode: return
	disabled = remaining > 0.0
	recharge = clampf(1.0 - maxf(remaining, 0) / maxf(duration, 0.001), 0, 1)
	fill_material.set_shader_parameter("recharge", recharge)
	fill_material.set_shader_parameter("hovered", is_hovered() and not disabled)

func set_navigation(label: String) -> void:
	navigation_mode = true
	disabled = false
	icon_view.hide()
	navigation_direction = -1.0 if label == "Previous" else 1.0
	tooltip_text = label + " tank"
	queue_redraw()

func _draw() -> void:
	if not navigation_mode: return
	var center := size * 0.5
	var points := PackedVector2Array([center + Vector2(-10 * navigation_direction, -16), center + Vector2(10 * navigation_direction, 0), center + Vector2(-10 * navigation_direction, 16)])
	draw_polyline(points, Color("10212d"), 10, true)
	draw_polyline(points, Color("fff0b8") if is_hovered() else Color("f4cb6c"), 5, true)
