extends SceneTree

const Catalog = preload("res://scripts/map_catalog.gd")
const OUT = "res://art-review/large-maps-v2/"

var failures: Array[String] = []
var checks := 0

func check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures.append(label)
	print("PASS " if passed else "FAIL ", label)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3) -> void:
	for i in range(count): await physics_frame

func capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(6)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "previews/" + filename) == OK, "Saved " + filename)

func probe_map(game: Node3D, index: int) -> void:
	var map: Node3D = game.active_map
	var label: String = Catalog.MAPS[index].name
	check(map.play_size == Vector2(96, 72), label + " is 96 x 72 m")
	var points: Array[Node] = map.spawn_points()
	check(points.size() == 8, label + " has 8 spawn points")
	var space := map.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 1.3
	shape.height = 1.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 4
	for i in range(points.size()):
		query.transform.origin = points[i].global_position + Vector3.UP * .85
		check(space.intersect_shape(query, 1).is_empty(), "%s spawn %d clears a heavy tank" % [label, i + 1])
		for j in range(i):
			check(points[i].position.distance_to(points[j].position) >= 24, "%s spawn spacing %d/%d" % [label, i, j])
		var route: PackedVector2Array = map.navigation.get_point_path(map.nearest_cell(points[0].global_position), map.nearest_cell(points[i].global_position))
		check(not route.is_empty(), "%s spawn %d is reachable" % [label, i + 1])
	for count in [4, 6, 8]:
		game.tank_count = count
		game.reset_arena()
		await frames()
		check(game.actors.get_child_count() == count, "%s supports %d tanks" % [label, count])
	var body: ToyTank = game.player
	for child in body.find_children("CharcoalOutline", "MeshInstance3D", true, false):
		check(child.get_parent() is MeshInstance3D and child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, label + " follows tank parts with unlit outlines")
	if index == 2:
		for z in [-22.0, 0.0, 22.0]:
			var bridge := PhysicsRayQueryParameters3D.create(Vector3(-4, .7, z), Vector3(4, .7, z), 1 | 4)
			check(space.intersect_ray(bridge).is_empty(), "Canal bridge %s allows tank crossing" % z)
		var water := PhysicsRayQueryParameters3D.create(Vector3(-3, .7, 5), Vector3(3, .7, 5), 4)
		water.hit_from_inside = true
		check(not space.intersect_ray(water).is_empty(), "Canal water blocks movement")
	if index == 5:
		var crater := PhysicsRayQueryParameters3D.create(Vector3(-8, .7, 0), Vector3(8, .7, 0), 4)
		check(not space.intersect_ray(crater).is_empty(), "Crater blocks movement")
	game.count_choice.select(2)
	await capture(Catalog.MAPS[index].id + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT + "previews")
	root.size = Vector2i(1600, 1000)
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(6)
	while game.loading_map: await frames()
	game.qa_mode = true
	game.set_process_input(false)
	for index in range(Catalog.MAPS.size()):
		if index > 0: await game.select_map(index)
		game.map_choice.select(index)
		await frames()
		await probe_map(game, index)
	await game.select_map(0)
	game.map_choice.select(0)
	game.follow_toggle.button_pressed = true
	await frames(40)
	check(game.camera.size < 23, "Follow camera zooms into the large map")
	await capture("07_follow_camera.png")
	game.spawn_mine(game.player.position, game.player)
	check(game.shots.get_child(0).position.distance_to(game.player.position) < .01, "Mines use the large map bounds")
	game.reset_arena()
	game.battle_mode = true
	var enemy: ToyTank = game.actors.get_child(1)
	var start := enemy.position
	await frames(180)
	check(enemy.position.distance_to(start) > .5, "AI follows routes on the large map")
	game.battle_mode = false
	game.tank_count = 4
	game.reset_arena()
	for i in range(1, 4): game.actors.get_child(i).die()
	check(game.round_over and game.kills == 3, "Four-tank victory counts three enemies")
	var file := FileAccess.open(OUT + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "maps": 6, "dimensions_m": [96, 72], "supported_tanks": [4, 6, 8], "rendered": DisplayServer.get_name() != "headless"}, "\t"))
	print("LARGE_MAP_QA_COMPLETE ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
