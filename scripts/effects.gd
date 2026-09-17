extends Node3D

@onready var audio: Node = get_node("/root/GameAudio")

var fire_material: StandardMaterial3D
var orange_material: StandardMaterial3D
var smoke_material: StandardMaterial3D
var dust_material: StandardMaterial3D
var debris_material: StandardMaterial3D
var ico: ArrayMesh
var random := RandomNumberGenerator.new()
var bursts := 0

func _ready() -> void:
	random.randomize()
	fire_material = _material(Color("ffe45c"), true)
	orange_material = _material(Color("ff7b22"), true)
	smoke_material = _material(Color("707b89"))
	dust_material = _material(Color("c6a879"))
	debris_material = _material(Color("344253"))
	ico = _icosahedron()

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _icosahedron() -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var vertices: Array[Vector3] = [Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)]
	var faces: Array = [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var a: Vector3 = vertices[face[0]].normalized()
		var b: Vector3 = vertices[face[1]].normalized()
		var c: Vector3 = vertices[face[2]].normalized()
		var normal := (c-a).cross(b-a).normalized()
		for point in [a,c,b]:
			surface.set_normal(normal)
			surface.add_vertex(point)
	return surface.commit()

func _particle(point: Vector3, radius: float, material: Material, drift: Vector3, duration: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = ico
	mesh.material_override = material
	add_child(mesh)
	mesh.global_position = point
	mesh.scale = Vector3.ONE * radius
	var tween := create_tween().set_parallel(true)
	tween.tween_property(mesh, "position", point + drift, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "scale", Vector3.ONE * 0.001, duration).set_delay(duration * 0.12)
	tween.chain().tween_callback(mesh.queue_free)
	return mesh

func muzzle(point: Vector3, direction: Vector3) -> void:
	_particle(point + direction * 0.14, 0.19, fire_material, direction * 0.22, 0.10)
	_particle(point + direction * 0.35, 0.15, orange_material, direction * 0.25, 0.14)
	for i in range(3):
		_particle(point, 0.10, smoke_material, direction * 0.2 + Vector3(randf_range(-.15,.15),.45,0), .40)

func dust(point: Vector3, side: Vector3) -> void:
	for sign_value in [-1.0,1.0]:
		_particle(point + side * sign_value + Vector3.UP * 0.11, 0.11, dust_material, side * sign_value * 0.5 + Vector3.UP * 0.15, 0.4)

func impact(point: Vector3, normal: Vector3) -> void:
	audio.play_world("ricochet", point, get_parent(), -4.0)
	_particle(point, 0.14, fire_material, normal * 0.12, .10)
	for i in range(5):
		var drift := normal * 0.3 + Vector3(random.randf_range(-.4,.4),random.randf_range(.2,.65),random.randf_range(-.4,.4))
		_particle(point, .035, orange_material, drift, .28)
	_particle(point, .18, smoke_material, Vector3.UP * .5, .45)

func burst(point: Vector3) -> void:
	bursts += 1
	for i in range(7):
		var offset := Vector3(random.randf_range(-.45,.45),random.randf_range(0,.5),random.randf_range(-.45,.45))
		_particle(point + offset, random.randf_range(.3,.55), fire_material if i < 3 else orange_material, offset * 1.4 + Vector3.UP * .4, .38 + i * .02)
	for i in range(8):
		var offset := Vector3(random.randf_range(-.5,.5),random.randf_range(.2,.6),random.randf_range(-.5,.5))
		_particle(point + offset, random.randf_range(.22,.4), smoke_material, Vector3.UP * random.randf_range(1,2) + offset, 1.2 + i * .08)
	for i in range(9):
		var direction := Vector3(random.randf_range(-1.4,1.4),random.randf_range(.5,1.7),random.randf_range(-1.4,1.4))
		_particle(point, .07, debris_material, direction, .65)

func explosion(point: Vector3, variant: int, yaw: float) -> void:
	audio.play_world("explosion", point, get_parent())
	burst(point + Vector3.UP * .45)
	var id: String = ToyTank.IDS[variant]
	var hull: Node3D = load("res://scenes/wrecks/%s_hull.tscn" % id).instantiate()
	add_child(hull)
	hull.position = point
	hull.rotation.y = yaw
	var turret: Node3D = load("res://scenes/wrecks/%s_turret.tscn" % id).instantiate()
	add_child(turret)
	turret.position = point + Vector3.UP * .8
	turret.rotation.y = yaw
	turret.collision_layer = 0
	var destination := point + Vector3(1.0, .22, -.65).rotated(Vector3.UP, yaw)
	var tween := create_tween()
	tween.tween_property(turret, "position", (point + destination) * .5 + Vector3.UP * 1.8, .35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(turret, "position", destination, .38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	create_tween().tween_property(turret, "rotation", Vector3(1.7,yaw+.4,.3), .73)
	get_tree().create_timer(5.0, false).timeout.connect(func():
		if is_instance_valid(hull):
			create_tween().tween_property(hull, "scale", Vector3.ONE * .001, .3).finished.connect(hull.queue_free)
		if is_instance_valid(turret):
			create_tween().tween_property(turret, "scale", Vector3.ONE * .001, .3).finished.connect(turret.queue_free))
