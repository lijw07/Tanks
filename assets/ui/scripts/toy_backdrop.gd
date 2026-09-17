extends Control

@export var show_tanks := false
var left: TextureRect
var right: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if show_tanks:
		left = _tank(0)
		right = _tank(2)
	resized.connect(_arrange)
	_arrange()

func _tank(index: int) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = load("res://assets/ui/portraits/%s.png" % ToyTank.IDS[index])
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	return picture

func _arrange() -> void:
	queue_redraw()
	if not is_instance_valid(left): return
	var wide := size.x > 850 and size.y > 500
	left.visible = wide
	right.visible = wide
	var width := minf(size.x * 0.35, 540)
	left.size = Vector2(width, width * 0.8)
	right.size = left.size
	left.position = Vector2(size.x * 0.16 - width * 0.5, size.y * 0.58 - width * 0.4)
	right.position = Vector2(size.x * 0.84 - width * 0.5, size.y * 0.58 - width * 0.4)
	right.flip_h = true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("182c3a"))
	_poly([Vector2(0, 0), Vector2(0.55, 0), Vector2(0.20, 0.62), Vector2(0, 0.72)], "1d3443")
	_poly([Vector2(1, 0.10), Vector2(1, 1), Vector2(0.56, 1), Vector2(0.70, 0.62)], "142633")
	_poly([Vector2(0, 0.78), Vector2(0.35, 0.88), Vector2(0.51, 1), Vector2(0, 1)], "263d47")
	_poly([Vector2(0.75, 0.83), Vector2(1, 0.64), Vector2(1, 1), Vector2(0.59, 1)], "203844")
	for i in 11:
		var y := size.y * 0.20 + i * 36
		var x := size.x * 0.06 + i * 9
		draw_set_transform(Vector2(x, y), -0.25)
		draw_rect(Rect2(0, 0, 17, 8), Color("28404b"))
		draw_rect(Rect2(32, 0, 17, 8), Color("28404b"))
	draw_set_transform(Vector2.ZERO)
	for point in [Vector2(0.18, 0.24), Vector2(0.84, 0.23), Vector2(0.90, 0.78), Vector2(0.12, 0.82)]:
		_star(point * size, 7, Color("496065"))
	if show_tanks and size.x > 850 and size.y > 500:
		for x in [0.16, 0.84]:
			var center := Vector2(size.x * x, size.y * 0.67)
			draw_set_transform(center, 0, Vector2(1, 0.32))
			draw_circle(Vector2.ZERO, minf(size.x * 0.13, 185), Color("10222d"))
		draw_set_transform(Vector2.ZERO)

func _poly(points: Array, color: String) -> void:
	var positions := PackedVector2Array()
	for point in points: positions.append(point * size)
	draw_colored_polygon(positions, Color(color))

func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var angle := i * PI / 4.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (radius if i % 2 == 0 else radius * 0.30))
	draw_colored_polygon(points, color)
