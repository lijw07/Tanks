extends SubViewportContainer

var camera: Camera3D
var clock := 0.0
var arena: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	arena = load("res://scenes/maps/01_crossfire_court.tscn").instantiate()
	viewport.add_child(arena)
	camera = arena.get_node("Preview/OverviewCamera")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48.0
	camera.near = 0.1
	camera.far = 110.0
	var environment: Environment = arena.get_node("Preview/WorldEnvironment").environment.duplicate()
	environment.ambient_light_color = Color("9fb8c4")
	environment.ambient_light_energy = 0.34
	environment.background_color = Color("1b292e")
	arena.get_node("Preview/WorldEnvironment").environment = environment
	var sun: DirectionalLight3D = arena.get_node("Preview/DirectionalLight3D")
	sun.light_color = Color("ffdaa7")
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-28, -38, 0)
	_update_camera()

func _process(delta: float) -> void:
	clock += delta
	_update_camera()

func _update_camera() -> void:
	if not is_instance_valid(camera): return
	var narrow := size.x < size.y
	var drift := sin(clock * 0.065)
	camera.position = Vector3(-26.0 + drift * 0.6, 6.0, 20.0 + cos(clock * 0.065) * 0.35)
	camera.look_at(Vector3(-18.0 if not narrow else -20.0, 0.0, 7.0 if not narrow else 10.5))
	camera.fov = 48.0 if not narrow else 56.0
