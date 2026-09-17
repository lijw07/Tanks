extends Node

var checks: Array = []
var game: Node3D
var capture_enabled := false

func check(label: String, passed: bool, detail: String = "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print("PASS " if passed else "FAIL ", label, " ", detail)

func frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame

func capture(name_value: String) -> void:
	if not capture_enabled:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art-review/godot-integration/previews/" + name_value + ".png")

func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh:
		result.append(node)
	for child in node.get_children():
		result.append_array(meshes(child))
	return result

func relative_transform(node: Node3D, stop: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != stop and cursor is Node3D:
		result = cursor.transform * result
		cursor = cursor.get_parent()
	return result

func ray(origin: Vector3, end: Vector3, mask: int = 1) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,mask))

func run(root: Node3D) -> void:
	game = root
	capture_enabled = DisplayServer.get_name() != "headless"
	await frames(4)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/scene_manifest.json"))
	check("49 independent TSCN assets", manifest.assets.size() == 49)
	var total_meshes := 0
	var matched := 0
	var failed_shapes: Array = []
	for entry in manifest.assets:
		var packed := load(entry.scene) as PackedScene
		if not packed:
			failed_shapes.append(entry.id)
			continue
		var asset: Node3D = packed.instantiate()
		var shapes := asset.find_children("*","CollisionShape3D",true,false)
		check(entry.id + " saved collision", shapes.size() == int(entry.collision_shapes) and shapes.size() > 0)
		for shape in shapes:
			if shape.shape is BoxShape3D:
				continue
			var found := false
			for mesh in meshes(asset.get_node("Model")):
				if String(shape.name) != "Collision_" + String(mesh.name).validate_node_name():
					continue
				var expected := mesh.mesh.get_faces()
				var transform_value := relative_transform(mesh,asset)
				var shape_transform := relative_transform(shape,asset)
				var actual: PackedVector3Array = shape.shape.points if shape.shape is ConvexPolygonShape3D else shape.shape.get_faces()
				var same := actual.size() == expected.size()
				if same:
					for i in range(actual.size()):
						if (shape_transform * actual[i]).distance_to(transform_value * expected[i]) > 0.0001:
							same = false
							break
				matched += int(same)
				total_meshes += 1
				found = true
				if not same:
					failed_shapes.append(entry.id + ":" + String(shape.name))
				break
			if not found:
				failed_shapes.append(entry.id + ":missing mesh")
		asset.free()
	check("Collision points match source meshes", failed_shapes.is_empty(), "%d / %d matched; %s" % [matched,total_meshes,str(failed_shapes)])
	for tank in game.actors.get_children():
		check(ToyTank.IDS[tank.variant] + " animated parts", tank.wheels.size() == 6 and tank.tracks.size() == 28 and tank.turret != null and tank.muzzles.size() >= 1)
	await capture("01_arena")
	game._set_view(1)
	await frames(3)
	await capture("02_tanks")
	game.show_collisions = true
	game.collision_toggle.button_pressed = true
	game._refresh_collision_overlay()
	await frames(2)
	await capture("03_tank_collision")
	game._set_view(2)
	game.show_collisions = false
	game.collision_toggle.button_pressed = false
	game._refresh_collision_overlay()
	await frames(2)
	await capture("04_modular_pieces")
	game._set_view(0)
	await frames(3)
	var isolated := Node3D.new()
	game.add_child(isolated)
	isolated.position = Vector3(100,0,100)
	var corner: Node3D = load("res://scenes/arena/wall_corner_L.tscn").instantiate()
	isolated.add_child(corner)
	var wedge: Node3D = load("res://scenes/arena/wall_diagonal.tscn").instantiate()
	isolated.add_child(wedge)
	wedge.position.x = 5
	var pit: Node3D = load("res://scenes/arena/pit_2m.tscn").instantiate()
	isolated.add_child(pit)
	pit.position.x = 10
	await frames(3)
	check("L wall opening stays open", ray(Vector3(100.5,2,99.5),Vector3(100.5,.1,99.5)).is_empty())
	check("L wall solid arm stops rays", not ray(Vector3(99.5,2,99.5),Vector3(99.5,.1,99.5)).is_empty())
	check("Diagonal wedge empty half stays open", ray(Vector3(105.6,2,99.4),Vector3(105.6,.1,99.4)).is_empty())
	check("Diagonal wedge solid half stops rays", not ray(Vector3(104.5,2,100.5),Vector3(104.5,.1,100.5)).is_empty())
	check("Pit passes shells above opening", ray(Vector3(108,1,100),Vector3(112,1,100),1).is_empty())
	check("Pit blocks tank movement", not ray(Vector3(108,.4,100),Vector3(112,.4,100),4).is_empty())
	var half: Vector2 = game.active_map.play_size * 0.5
	for outward in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var edge := Vector3(outward.x * half.x, 1.02, outward.z * half.y)
		var hit := ray(edge - outward * 0.6, edge + outward * 1.4, 1)
		check("Outer border stops shells heading %s" % outward, not hit.is_empty() and hit.position.distance_to(edge) < 0.2, str(hit.get("position", "no hit")))
	game.set_process(false)
	var player: ToyTank = game.player
	player.position = Vector3(100,0,104)
	player.rotation.y = PI
	player.velocity = Vector3.ZERO
	var wheel_axis: Vector3 = player.wheels[0].basis * Vector3.UP
	var start_z := player.position.z
	game.test_input = Vector2.UP
	await frames(100)
	game.test_input = Vector2.ZERO
	await frames(15)
	check("Tank moves with input", player.position.z < start_z - 1.0)
	check("Tank stops against mesh wall", player.position.z > 101.2 and player.position.z < 102.2, str(player.position))
	check("Wheel axle direction preserved", wheel_axis.normalized().dot((player.wheels[0].basis * Vector3.UP).normalized()) > .999)
	check("Treads travel with movement", absf(player.travel_left) > 1.0 and absf(player.travel_left-player.travel_right) < .001)
	game.reset_arena()
	player = game.player
	var enemy: ToyTank = game.actors.get_child(1)
	player.position = Vector3(100,0,105)
	player.rotation.y = PI
	enemy.position = Vector3(100,0,101.5)
	game.aim_point = enemy.position + Vector3.UP
	await frames(35)
	var original_gun: Vector3 = player.guns[0].position
	check("Fire starts shell and muzzle effects", player.fire() and game.shots.get_child_count() > 0 and game.fx.get_child_count() > 0)
	check("Barrel recoils", player.guns[0].position.distance_to(original_gun) > .1)
	await frames(35)
	check("Shell kills target and creates wreck", not enemy.alive and game.kills == 1 and game.fx.bursts == 1)
	check("Recoil returns to rest", player.guns[0].position.distance_to(original_gun) < .001)
	game.spawn_shell(Vector3(99.5,1.02,103),Vector3(0,0,-1),player)
	var shell: Node3D = game.shots.get_child(game.shots.get_child_count()-1)
	await frames(12)
	check("Wall ricochet reverses shell direction", is_instance_valid(shell) and shell.bounces == 0 and shell.direction.z > .9)
	game.spawn_mine(Vector3.ZERO,player)
	var mine: Node3D = game.shots.get_child(game.shots.get_child_count()-1)
	mine.position = player.position
	await frames(30)
	check("Mine has arming delay", player.health == ToyTank.PLAYER_HP)
	await frames(45)
	check("Armed mine damages nearby tank", not player.alive)
	check("Player destruction starts spectating", game.spectating and is_instance_valid(game.spectate_target) and game.spectate_target.alive)
	isolated.queue_free()
	game.reset_arena()
	game.set_process(true)
	await frames(3)
	check("Reset restores eight tanks and clears effects", game.actors.get_child_count() == 8 and game.player.health == ToyTank.PLAYER_HP and game.shots.get_child_count() == 0 and game.fx.get_child_count() == 0 and not game.spectating)
	game.camera.position = Vector3(-8,7,12)
	game.camera.look_at(game.player.position + Vector3.UP*.4)
	game.camera.size = 5
	await frames(2)
	await capture("05_tank_closeup")
	game.set_process(false)
	game.player.die()
	await frames(5)
	await capture("06_explosion")
	await frames(50)
	await capture("07_wreck")
	var failures := checks.filter(func(item): return not item.passed)
	var report := {"passed": failures.is_empty(), "checks": checks.size(), "failures": failures, "results": checks, "rendered": capture_enabled, "engine": Engine.get_version_info().string}
	var file := FileAccess.open("res://art-review/godot-integration/validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("INTEGRATION_QA_COMPLETE ", checks.size(), " checks, ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
