extends SubViewportContainer

@export var tank_index := 0
@export var animate := true
var model: Node3D
var stage: Node3D
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	stage = Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6e8ec")
	environment.ambient_light_energy = 0.8
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_color = Color("fff0d4")
	light.light_energy = 1.1
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(3.3, 2.9, 4.5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.45, 0))
	show_tank(tank_index)

func show_tank(index: int) -> void:
	tank_index = clampi(index, 0, ToyTank.IDS.size() - 1)
	if not is_instance_valid(stage): return
	if is_instance_valid(model):
		stage.remove_child(model)
		model.queue_free()
	model = load("res://assets/models/tanks/%s.glb" % ToyTank.IDS[tank_index]).instantiate()
	stage.add_child(model)
	elapsed = 0.0

func _process(delta: float) -> void:
	if animate and is_instance_valid(model):
		elapsed += delta
		model.rotation.y = sin(elapsed * 0.45) * 0.18
