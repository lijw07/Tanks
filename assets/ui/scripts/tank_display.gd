extends SubViewportContainer

var model: Node3D
var angle := 0.0

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 600)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0, 0, 0, 0)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("cce4de")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.8
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(3.2, 3.7, 4.5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.4
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.45, 0))
	var platform := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.6
	cylinder.bottom_radius = 1.65
	cylinder.height = 0.18
	platform.mesh = cylinder
	platform.position.y = -0.12
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("31464b")
	platform.material_override = material
	stage.add_child(platform)
	model = load("res://assets/models/tanks/tank_01_azure_scout.glb").instantiate()
	stage.add_child(model)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if model:
		angle += delta * 0.18
		model.rotation.y = angle
