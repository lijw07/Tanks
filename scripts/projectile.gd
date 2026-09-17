extends Node3D

var direction := Vector3.FORWARD
var shooter: CharacterBody3D
var arena: Node3D
var speed := 14.0
var life := 4.0
var bounces := 1

func _ready() -> void:
	var visual: Node3D = load("res://scenes/props/shell_standard.tscn").instantiate()
	visual.collision_layer = 0
	visual.position.y = -0.09
	add_child(visual)
	rotation.y = atan2(direction.x, direction.z)

func _physics_process(delta: float) -> void:
	if arena.view_mode != 0 or arena.round_over:
		queue_free()
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var target := global_position + direction * speed * delta
	var excluded: Array[RID] = []
	if is_instance_valid(shooter):
		excluded = shooter.excluded_rids()
	var query := PhysicsRayQueryParameters3D.create(global_position, target, 1 | 2 | 8, excluded)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = target
		return
	global_position = hit.position
	if hit.collider is ToyTank:
		hit.collider.take_hit()
		queue_free()
	elif hit.collider is Area3D and hit.collider.get_parent() is ToyTank:
		hit.collider.get_parent().take_hit()
		queue_free()
	elif bounces > 0:
		bounces -= 1
		direction = direction.bounce(hit.normal).normalized()
		direction.y = 0.0
		global_position += direction * 0.09
		rotation.y = atan2(direction.x, direction.z)
		arena.fx.impact(hit.position, hit.normal)
	else:
		arena.fx.impact(hit.position, hit.normal)
		queue_free()
