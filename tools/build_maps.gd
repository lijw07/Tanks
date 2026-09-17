extends SceneTree

const Catalog = preload("res://scripts/map_catalog.gd")
const Battlefield = preload("res://scripts/battlefield.gd")
const OUTLINE = preload("res://assets/materials/charcoal_outline.tres")
const SPAWNS = [Vector2(-40, 27), Vector2(40, -27), Vector2(-40, -27), Vector2(40, 27), Vector2(-14, 28), Vector2(14, -28), Vector2(-40, 0), Vector2(40, 0)]
const TANKS = ["tank_01_azure_scout", "tank_02_mint_cruiser", "tank_03_vermilion_heavy", "tank_04_saffron_sprinter", "tank_05_violet_marksman", "tank_06_ivory_duelist", "tank_07_tangerine_siege", "tank_08_charcoal_command"]

var map: Node3D
var geometry: Node3D
var materials: Dictionary = {}

func _initialize() -> void:
	call_deferred("build")

func add(node: Node, parent: Node) -> Node:
	parent.add_child(node, true)
	node.owner = map
	return node

func material(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = Color(color)
		result.roughness = 1
		materials[color] = result
	return materials[color]

func box(label: String, at: Vector3, size: Vector3, color: String, solid: bool = false, outlined: bool = true, parent: Node = null) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material(color)
	visual.position = at
	add(visual, geometry if parent == null else parent)
	if outlined:
		var contour := MeshInstance3D.new()
		contour.name = "CharcoalOutline"
		contour.mesh = mesh.create_outline(0.035)
		contour.material_override = OUTLINE
		contour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		contour.set_meta("visual_outline", true)
		add(contour, visual)
	if solid:
		var body := StaticBody3D.new()
		body.name = "Solid"
		body.collision_layer = 1
		body.collision_mask = 0
		add(body, visual)
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		add(shape, body)
	return visual

func piece(id: String, x: float, z: float, angle: float = 0) -> Node3D:
	var folder := "props" if id in ["crate_1m", "barrels_pair", "barricade_2m", "rubble_cluster", "mine_disc", "spawn_marker_2m"] else "arena"
	var node: Node3D = load("res://scenes/%s/%s.tscn" % [folder, id]).instantiate()
	node.name = id
	node.position = Vector3(x, 0, z)
	node.rotation_degrees.y = angle
	add(node, geometry)
	return node

func wall(x: float, z: float, length: int = 4, vertical: bool = false, kind: String = "beech") -> void:
	var unit := 4 if kind == "beech" and length % 4 == 0 else 2
	for i in range(length / unit):
		var offset := -length * 0.5 + unit * 0.5 + i * unit
		piece("wall_%s_%dm" % [kind, unit], x if vertical else x + offset, z + offset if vertical else z, 90 if vertical else 0)

func blocker(label: String, at: Vector3, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 4
	body.collision_mask = 0
	add(body, geometry)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add(collision, body)

func floor_area(x: float, z: float, width: float, depth: float, color: String) -> void:
	box("Floor", Vector3(x, -0.10, z), Vector3(width, 0.2, depth), color, false, false)

func begin(index: int, floor_style: String = "wood") -> void:
	map = Node3D.new()
	map.name = Catalog.MAPS[index].id
	map.set_script(Battlefield)
	map.map_title = Catalog.MAPS[index].name
	map.description = Catalog.MAPS[index].description
	geometry = Node3D.new()
	geometry.name = "Geometry"
	add(geometry, map)
	box("BoardBase", Vector3(0, -0.48, 0), Vector3(97, 0.5, 73), "a77643")
	if floor_style == "wood":
		for row in range(36):
			floor_area(0, -35 + row * 2, 96, 1.985, "bca580" if row % 2 == 0 else "b8a07b")
	elif floor_style == "canal":
		for row in range(36):
			for x in [-26, 26]:
				floor_area(x, -35 + row * 2, 44, 1.985, "bca580" if row % 2 == 0 else "b8a07b")
	elif floor_style != "crater":
		floor_area(0, 0, 96, 72, "81907a" if floor_style == "green" else "7f8c89")
		for x in range(-44, 48, 4):
			box("Paving joint", Vector3(x, 0.002, 0), Vector3(.018, .005, 72), "67756b", false, false)
		for z in range(-32, 36, 4):
			box("Paving joint", Vector3(0, 0.002, z), Vector3(96, .005, .018), "67756b", false, false)
	for x in range(-47, 48, 2):
		for z in [-36.2, 36.2]: piece("border_2m", x, z)
	for z in range(-35, 36, 2):
		for x in [-48.2, 48.2]: piece("border_2m", x, z, 90)
	for x in [-48.2, 48.2]:
		for z in [-36.2, 36.2]: piece("border_corner", x, z)
	var spawns := Node3D.new()
	spawns.name = "Spawns"
	add(spawns, map)
	for i in range(SPAWNS.size()):
		var marker := Marker3D.new()
		marker.name = "Spawn%02d" % (i + 1)
		marker.position = Vector3(SPAWNS[i].x, 0, SPAWNS[i].y)
		marker.rotation.y = atan2(-marker.position.x, -marker.position.z)
		add(marker, spawns)
		var pad := box("SpawnPad%02d" % (i + 1), marker.position + Vector3(0, .008, 0), Vector3(2.8, .015, 2.8), "5c8e99" if i == 0 else "aa8b73", false, false)
		pad.set_meta("spawn_index", i)
		piece("spawn_marker_2m", marker.position.x, marker.position.z)

func spawn_cover() -> void:
	for i in range(SPAWNS.size()):
		var at: Vector2 = SPAWNS[i]
		var forward := (-at).normalized()
		var right := Vector2(forward.y, -forward.x)
		var shelter := Node3D.new()
		shelter.name = "SpawnShelter%02d" % (i + 1)
		shelter.position = Vector3(at.x, 0, at.y)
		shelter.rotation.y = atan2(forward.x, forward.y)
		add(shelter, geometry)
		box("Front shield", Vector3(0, .9, 6), Vector3(10, 1.8, 1), "bba078", true, true, shelter)
		box("Side baffle", Vector3(8, .9, 0), Vector3(1, 1.8, 7), "ae7054", true, true, shelter)
		for side in [-1, 1]:
			var exit: Vector2 = at + right * side * 5.5
			box("Exit marking", Vector3(exit.x, .01, exit.y), Vector3(.8, .015, .8), "d8bf83", false, false)

func outer_routes(index: int) -> void:
	# Midfield islands break up long firing lanes without sealing the perimeter route.
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var x: float = sx * 27.0
			var z: float = sz * 16.0
			if index == 4:
				container_at(x, z, 90, "ae7054")
			else:
				wall(x, z, 8, index == 0 or index == 3, "terracotta" if index == 5 else "beech")
			piece("crate_1m", x + sx * 3, z + sz * 4, 15)
			piece("barrels_pair", x - sx * 3, z - sz * 3, 90)
	for sx in [-1, 1]:
		wall(sx * 25, 0, 6, true, "steel" if index == 4 else "beech")
	for sz in [-1, 1]:
		if index != 2:
			wall(0, sz * 23, 8, false, "terracotta")
		for sx in [-1, 1]:
			wall(sx * 16, sz * 18, 6, false, "steel" if index == 4 else "beech")

func finish(index: int) -> void:
	outer_routes(index)
	spawn_cover()
	var preview := Node3D.new()
	preview.name = "Preview"
	add(preview, map)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("172c38")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d2e5f4")
	environment.environment.ambient_light_energy = .4
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	add(environment, preview)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = .9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	add(sun, preview)
	var camera := Camera3D.new()
	camera.name = "OverviewCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 94
	camera.position = Vector3(0, 96, 72)
	camera.rotation.x = -atan2(48.0, 36.0)
	camera.current = true
	add(camera, preview)
	for i in range(SPAWNS.size()):
		var tank: Node3D = load("res://scenes/tanks/%s.tscn" % TANKS[i]).instantiate()
		tank.name = "PreviewTank%02d" % (i + 1)
		tank.transform = map.get_node("Spawns").get_child(i).transform
		tank.process_mode = Node.PROCESS_MODE_DISABLED
		add(tank, preview)
	var packed := PackedScene.new()
	assert(packed.pack(map) == OK)
	assert(ResourceSaver.save(packed, Catalog.scene_path(index)) == OK)
	print("LARGE_MAP_BUILT ", Catalog.MAPS[index].name)
	map.free()

func crossfire() -> void:
	begin(0)
	for x in [-12, 12]:
		for z in [-8, 8]: wall(x, z, 10, true)
	for x in [-17, 17]:
		for z in [-6, 6]: wall(x, z, 4)
	wall(-3, -4, 4)
	wall(3, 4, 4)
	for x in [-5, 5]:
		for z in [-10, 10]: piece("wall_round_pillar", x, z)
	for x in [-15, 15]:
		for z in [-13, 13]: piece("crate_1m", x, z, 12)
	finish(0)

func keep() -> void:
	begin(1, "green")
	box("Courtyard", Vector3(0, .005, 0), Vector3(24, .012, 22), "92968b", false, false)
	for z in [-11, 11]:
		for x in [-8, 8]: wall(x, z, 8)
	for x in [-12, 12]:
		for z in [-7, 7]: wall(x, z, 6, true)
	for x in [-12, 12]:
		for z in [-11, 11]: piece("pillar_beech", x, z).scale = Vector3(1.25, 1.5, 1.25)
	for x in [-20, 20]:
		for z in [-7, 7]: wall(x, z, 4, false, "terracotta")
	for z in [-16, 16]: wall(0, z, 4, false, "terracotta")
	box("Center emblem", Vector3(0, .015, 0), Vector3(3.4, .025, 3.4), "b6a16e", false, false)
	piece("spawn_marker_2m", 0, 0)
	for x in [-17, 17]: piece("barrels_pair", x, 0, 90)
	finish(1)

func canal() -> void:
	begin(2, "canal")
	box("Canal water", Vector3(0, -.13, 0), Vector3(8, .08, 72), "3c8f9b", false, false)
	for z in [-22, 0, 22]:
		box("Bridge", Vector3(0, -.1, z), Vector3(8.8, .2, 5), "b99c6c", false, false)
		for x in range(-4, 5):
			box("Deck seam", Vector3(x, .006, z), Vector3(.022, .01, 4.8), "7d694c", false, false)
		for side in [-1, 1]:
			box("Bridge curb", Vector3(0, .12, z + side * 2.48), Vector3(8.8, .24, .14), "b29a70", true)
	for segment in [Vector2(-36, -24.5), Vector2(-19.5, -2.5), Vector2(2.5, 19.5), Vector2(24.5, 36)]:
		var shape := BoxShape3D.new()
		shape.size = Vector3(8, 1.5, segment.y - segment.x)
		blocker("WaterBlocker", Vector3(0, .35, (segment.x + segment.y) * .5), shape)
		for x in [-4.1, 4.1]:
			box("Bank edging", Vector3(x, .08, (segment.x + segment.y) * .5), Vector3(.18, .16, segment.y - segment.x), "b69b70", false)
	for x in [-10, 10]:
		for z in [-5.5, 5.5]: wall(x, z, 4, true, "terracotta")
	for x in [-16, 16]:
		for z in [-8, 8]: wall(x, z, 4)
	for x in [-14, 14]: piece("crate_1m", x, 0)
	finish(2)

func switchback() -> void:
	begin(3)
	for pair in [Vector2(-14, -5), Vector2(0, 5), Vector2(14, -5)]:
		wall(pair.x, pair.y, 24, true)
	for x in [-7, 7]:
		for z in [-11, 11]: wall(x, z, 4)
	for x in [-17, 17]:
		for z in [-7, 7]: piece("wall_round_pillar", x, z)
	for p in [Vector2(-6, 0), Vector2(6, 0), Vector2(-16, 13), Vector2(16, -13)]:
		piece("crate_1m", p.x, p.y, 10)
	finish(3)

func container_at(x: float, z: float, angle: float, color: String) -> void:
	var cargo := Node3D.new()
	cargo.name = "CargoContainer"
	cargo.position = Vector3(x, 0, z)
	cargo.rotation_degrees.y = angle
	add(cargo, geometry)
	box("Cargo shell", Vector3(0, .85, 0), Vector3(8, 1.7, 3), color, true, true, cargo)
	for xx in [-3.9, 3.9]: box("End frame", Vector3(xx, .86, 0), Vector3(.12, 1.76, 3.07), "465a5b", false, false, cargo)
	for xx in range(-3, 4):
		for zz in [-1.51, 1.51]: box("Side rib", Vector3(xx, .85, zz), Vector3(.06, 1.5, .06), color, false, false, cargo)

func freight() -> void:
	begin(4, "concrete")
	for x in [-14, 0, 14]:
		for z in [-10, 10]: container_at(x, z, 0, "4b8187" if int(x + z) % 3 == 0 else "ae7054")
	for x in [-7, 7]: container_at(x, 0, 90, "4b8187")
	for z in [-13, 13]:
		for x in range(-18, 19, 4): box("Lane dash", Vector3(x, .008, z), Vector3(1.4, .01, .09), "d5c8a3", false, false)
	for x in [-18, 18]: wall(x, 0, 2, true, "steel")
	for x in [-20, 20]:
		for z in [-8, 8]: piece("barrels_pair", x, z, 90)
	finish(4)

func crater() -> void:
	begin(5, "crater")
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(64):
		var a := i * TAU / 64
		var b := (i + 1) * TAU / 64
		var da := Vector3(cos(a), 0, sin(a))
		var db := Vector3(cos(b), 0, sin(b))
		var ra := minf(48 / maxf(absf(da.x), .001), 36 / maxf(absf(da.z), .001))
		var rb := minf(48 / maxf(absf(db.x), .001), 36 / maxf(absf(db.z), .001))
		for v in [da * 6, da * ra, db * 6, da * ra, db * rb, db * 6]:
			vertices.append(v)
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ground := MeshInstance3D.new()
	ground.name = "Sand around crater"
	ground.mesh = mesh
	ground.material_override = material("b69b70").duplicate()
	ground.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	add(ground, geometry)
	var pit := MeshInstance3D.new()
	pit.name = "Crater bottom"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 6.2
	cylinder.bottom_radius = 6.2
	cylinder.height = .05
	cylinder.radial_segments = 64
	pit.mesh = cylinder
	pit.position.y = -.19
	pit.material_override = material("4a3a30")
	add(pit, geometry)
	for i in range(32):
		var a := i * TAU / 32
		var edge := box("Crater rim", Vector3(cos(a) * 6.15, .12, sin(a) * 6.15), Vector3(1.24, .24, .24), "a88a58")
		edge.rotation.y = PI * .5 - a
	var shape := CylinderShape3D.new()
	shape.radius = 6.3
	shape.height = 1.5
	blocker("CraterBlocker", Vector3(0, .35, 0), shape)
	for x in [-13, 13]:
		for z in [-5, 5]: wall(x, z, 4, true, "terracotta")
	for z in [-11, 11]:
		for x in [-5, 5]: wall(x, z, 2, false, "terracotta")
	for p in [Vector2(-9, -8), Vector2(9, 8), Vector2(-9, 8), Vector2(9, -8)]:
		piece("wall_diagonal", p.x, p.y, 45)
	for x in [-8, 8]: piece("rubble_cluster", x, 0, 35)
	finish(5)

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/maps")
	crossfire()
	keep()
	canal()
	switchback()
	freight()
	crater()
	print("LARGE_MAPS_COMPLETE 6 scenes; 96 x 72 m; 8 spawns each")
	quit()
