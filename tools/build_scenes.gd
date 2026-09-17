extends SceneTree

var assets: Array = []
var receipts: Array = []

func _initialize() -> void:
	call_deferred("build")

func relative_transform(node: Node3D, stop: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != stop and cursor is Node3D:
		result = cursor.transform * result
		cursor = cursor.get_parent()
	return result

func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node.get_meta("visual_outline", false):
		return result
	if node is MeshInstance3D and node.mesh:
		result.append(node)
	for child in node.get_children():
		result.append_array(meshes(child))
	return result

func find_part(node: Node, text_value: String) -> Node3D:
	if text_value in String(node.name).to_lower():
		return node
	for child in node.get_children():
		var result := find_part(child,text_value)
		if result:
			return result
	return null

func add_collider(mesh_node: MeshInstance3D, body: Node3D, origin: Node3D, owner_node: Node, convex: bool) -> void:
	var points := mesh_node.mesh.get_faces()
	var xform := relative_transform(mesh_node,origin)
	for i in range(points.size()):
		points[i] = xform * points[i]
	if points.size() < 3:
		return
	var collision := CollisionShape3D.new()
	collision.name = "Collision_" + String(mesh_node.name).validate_node_name()
	if convex:
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		collision.shape = shape
	else:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(points)
		shape.backface_collision = true
		collision.shape = shape
	body.add_child(collision)
	collision.owner = owner_node

func save_scene(node: Node, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	assert(ResourceSaver.save(scene,path) == OK)

func build_asset(record: Dictionary) -> void:
	var id: String = record.id
	var is_tank: bool = "models/tanks/" in record.path
	var is_wreck: bool = "models/wrecks/" in record.path
	var is_prop: bool = id in ["crate_1m","barrels_pair","barricade_2m","rubble_cluster","mine_disc","shell_standard","shell_rocket","spawn_marker_2m"]
	var folder := "tanks" if is_tank else "wrecks" if is_wreck else "props" if is_prop else "arena"
	var body: Node3D = CharacterBody3D.new() if is_tank else StaticBody3D.new()
	body.name = id
	body.set_meta("asset_id",id)
	body.set_meta("source_model",record.path)
	body.set_meta("collision_method","Mesh-derived convex hulls for the tank; triangle surfaces for static assets.")
	body.collision_layer = 2 if is_tank else 1
	body.collision_mask = 7 if is_tank else 0
	var model: Node3D = load("res://" + record.path).instantiate()
	model.name = "Model"
	body.add_child(model)
	model.owner = body
	var count := 0
	if is_tank:
		var turret := find_part(model,"turretpivot")
		var groups: Array[Node3D] = [turret]
		for node in turret.find_children("*","Node3D",true,false):
			if "barrelrecoil" in String(node.name).to_lower():
				groups.append(node)
		for mesh in meshes(model):
			var name_value := String(mesh.name).to_lower().replace("_"," ")
			if "lower hull" in name_value or "upper deck" in name_value or "track belt" in name_value or "track guard" in name_value:
				add_collider(mesh,body,body,body,true)
				count += 1
		for i in range(groups.size()):
			var part: Node3D = groups[i]
			var hitbox := Area3D.new()
			hitbox.name = "TurretHitbox" if i == 0 else "BarrelHitbox%d" % i
			hitbox.collision_layer = 8
			hitbox.collision_mask = 0
			hitbox.monitoring = false
			hitbox.set_meta("follow_part", body.get_path_to(part))
			body.add_child(hitbox)
			hitbox.owner = body
			hitbox.transform = relative_transform(part,body)
			for mesh in meshes(part):
				var belongs_to_barrel := false
				if i == 0:
					for j in range(1,groups.size()):
						if groups[j].is_ancestor_of(mesh):
							belongs_to_barrel = true
				if not belongs_to_barrel:
					add_collider(mesh,hitbox,part,body,true)
					count += 1
		body.set_script(load("res://scripts/tank.gd"))
		body.variant = int(id.substr(5,2)) - 1
	else:
		for mesh in meshes(model):
			add_collider(mesh,body,body,body,false)
			count += 1
		if id == "pit_2m":
			var blocker := StaticBody3D.new()
			blocker.name = "PitTankBlocker"
			blocker.collision_layer = 4
			blocker.collision_mask = 0
			body.add_child(blocker)
			blocker.owner = body
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.8,1.3,1.8)
			collision.shape = shape
			collision.position.y = .35
			blocker.add_child(collision)
			collision.owner = body
			count += 1
	var path := "res://scenes/%s/%s.tscn" % [folder,id]
	save_scene(body,path)
	receipts.append({"id":id,"scene":path,"collision_shapes":count,"model_meshes":meshes(model).size(),"mode":"convex compound + articulated hitboxes" if is_tank else "mesh triangle surfaces"})
	body.free()

func place(parent: Node3D, owner_node: Node, id: String, at: Vector3, degrees: float = 0) -> Node3D:
	var folder := "props" if id in ["crate_1m","barrels_pair","barricade_2m","rubble_cluster","mine_disc","shell_standard","shell_rocket","spawn_marker_2m"] else "arena"
	var instance: Node3D = load("res://scenes/%s/%s.tscn" % [folder,id]).instantiate()
	instance.name = id
	instance.position = at
	instance.rotation_degrees.y = degrees
	parent.add_child(instance,true)
	instance.owner = owner_node
	return instance

func simple_box(parent: Node3D, owner_node: Node, name_value: String, at: Vector3, size_value: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name_value
	var box := BoxMesh.new()
	box.size = size_value
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	mesh.owner = owner_node

func build_arena() -> void:
	var root_node := Node3D.new()
	root_node.name = "PocketArmor"
	var arena := Node3D.new()
	arena.name = "Arena"
	root_node.add_child(arena)
	arena.owner = root_node
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 100.0
	camera.position = Vector3(0,96,72)
	camera.rotation.x = -atan2(48.0,36.0)
	camera.current = true
	root_node.add_child(camera)
	camera.owner = root_node
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("172c38")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d2e5f4")
	environment.environment.ambient_light_energy = .4
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	root_node.add_child(environment)
	environment.owner = root_node
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-55,-30,0)
	light.light_energy = .9
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 120
	root_node.add_child(light)
	light.owner = root_node
	root_node.set_script(load("res://scripts/main.gd"))
	save_scene(root_node,"res://scenes/main.tscn")
	root_node.free()

func build() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/approved_asset_manifest.json"))
	assets = manifest.assets
	for record in assets:
		build_asset(record)
	build_arena()
	configure_project()
	var file := FileAccess.open("res://assets/scene_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"assets":receipts,"scene_count":receipts.size(),"all_assets_have_tscn":true},"\t"))
	print("ASSET_SCENES_BUILT ",receipts.size())
	quit()

func configure_project() -> void:
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 2)
	ProjectSettings.set_setting("application/run/main_scene", "res://scenes/main_menu.tscn" if FileAccess.file_exists("res://scenes/main_menu.tscn") else "res://scenes/main.tscn")
	ProjectSettings.set_setting("display/window/size/viewport_width", 1280)
	ProjectSettings.set_setting("display/window/size/viewport_height", 800)
	ProjectSettings.set_setting("display/window/size/window_width_override", 1280)
	ProjectSettings.set_setting("display/window/size/window_height_override", 800)
	var keys := {"move_up": [KEY_W,KEY_UP], "move_down": [KEY_S,KEY_DOWN], "move_left": [KEY_A,KEY_LEFT], "move_right": [KEY_D,KEY_RIGHT], "mine": [KEY_SPACE], "reset": [KEY_R]}
	for action in keys:
		var events: Array[InputEvent] = []
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			events.append(event)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	ProjectSettings.set_setting("input/fire", {"deadzone": 0.2, "events": [click]})
	ProjectSettings.set_setting("layer_names/3d_physics/layer_1", "Solid scenery")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_2", "Tank bodies")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_3", "Pit movement blocker")
	ProjectSettings.set_setting("layer_names/3d_physics/layer_4", "Articulated tank hitboxes")
	ProjectSettings.save()
