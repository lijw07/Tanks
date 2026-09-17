extends Node3D

@onready var audio: Node = get_node("/root/GameAudio")

var arena: Node3D
var timer := 0.0
var detonated := false
var armed := false
var lamp: MeshInstance3D

func _ready() -> void:
	var model: StaticBody3D = load("res://scenes/props/mine_disc.tscn").instantiate()
	model.collision_layer = 0
	add_child(model)
	lamp = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 6
	mesh.rings = 3
	lamp.mesh = mesh
	lamp.material_override = arena.fx.fire_material
	lamp.position.y = 0.24
	add_child(lamp)
	audio.play_world("mine_place", global_position, arena, -2.0)

func _physics_process(delta: float) -> void:
	if arena.view_mode != 0 or arena.round_over:
		return
	timer += delta
	lamp.visible = fmod(timer, 0.4) < 0.2
	if timer < 1.1 or detonated:
		return
	if not armed:
		armed = true
		audio.play_world("mine_arm", global_position, arena, -6.0)
	for tank in get_tree().get_nodes_in_group("tanks"):
		if tank.alive and tank.global_position.distance_to(global_position) < 1.0:
			detonate()
			return
	if timer > 12.0:
		detonate()

func detonate() -> void:
	if detonated:
		return
	detonated = true
	audio.play_world("mine_burst", global_position, arena)
	arena.fx.burst(global_position + Vector3.UP * 0.25)
	for tank in get_tree().get_nodes_in_group("tanks"):
		if tank.alive and tank.global_position.distance_to(global_position) < 2.0:
			tank.take_hit()
	queue_free()
