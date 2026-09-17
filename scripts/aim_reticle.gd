extends Control

var enabled := false
var follow_mouse := true
var touch_position := Vector2.ZERO
var pointer_position := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	hide()

func _process(_delta: float) -> void:
	position = pointer_position if follow_mouse else touch_position
	visible = enabled and not get_tree().paused and get_viewport_rect().has_point(position)
	var mode := Input.MOUSE_MODE_HIDDEN if visible and follow_mouse and get_window().has_focus() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode: Input.mouse_mode = mode

func _draw() -> void:
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(direction * 6, direction * 13, Color("10212d"), 6, true)
		draw_line(direction * 6, direction * 13, Color("ffdf89"), 3, true)
	draw_circle(Vector2.ZERO, 2.5, Color("10212d"))
	draw_circle(Vector2.ZERO, 1.0, Color("fff2c9"))

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
