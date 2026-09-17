@tool
extends Node3D

@export var map_title: String = ""
@export_multiline var description: String = ""
@export var play_size := Vector2(96, 72)
@export_range(4, 8) var max_tanks: int = 8

const BARRIER_HEIGHT := 3.0
const BARRIER_THICKNESS := 1.0
const BARRIER_INSET := 0.025

var navigation: AStarGrid2D

func prepare_for_game() -> void:
	var preview := get_node_or_null("Preview")
	if preview:
		remove_child(preview)
		preview.queue_free()
	_build_perimeter_barrier()

func _build_perimeter_barrier() -> void:
	var existing := get_node_or_null("PerimeterBarrier")
	if existing:
		remove_child(existing)
		existing.queue_free()
	var barrier := StaticBody3D.new()
	barrier.name = "PerimeterBarrier"
	barrier.collision_layer = 1
	barrier.collision_mask = 0
	add_child(barrier)
	var half := play_size * 0.5 + Vector2.ONE * BARRIER_INSET
	var span := play_size + Vector2.ONE * (BARRIER_THICKNESS + BARRIER_INSET) * 2.0
	for side in [-1.0, 1.0]:
		_add_barrier_panel(barrier, Vector3(side * (half.x + BARRIER_THICKNESS * 0.5), BARRIER_HEIGHT * 0.5, 0.0), Vector3(BARRIER_THICKNESS, BARRIER_HEIGHT, span.y))
		_add_barrier_panel(barrier, Vector3(0.0, BARRIER_HEIGHT * 0.5, side * (half.y + BARRIER_THICKNESS * 0.5)), Vector3(span.x, BARRIER_HEIGHT, BARRIER_THICKNESS))

func _add_barrier_panel(barrier: StaticBody3D, offset: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = offset
	barrier.add_child(collider)

func spawn_points() -> Array[Node]:
	return $Spawns.get_children()

func build_navigation() -> void:
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(Vector2i.ZERO, Vector2i(play_size / 2))
	navigation.cell_size = Vector2(2, 2)
	navigation.offset = -play_size * .5 + Vector2.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	var shape := CylinderShape3D.new()
	shape.radius = 1.15
	shape.height = 1.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 4
	var space := get_world_3d().direct_space_state
	for x in range(navigation.region.size.x):
		for z in range(navigation.region.size.y):
			var point := navigation.get_point_position(Vector2i(x, z))
			query.transform.origin = global_position + Vector3(point.x, 0.85, point.y)
			navigation.set_point_solid(Vector2i(x, z), not space.intersect_shape(query, 1).is_empty())

func nearest_cell(point: Vector3) -> Vector2i:
	var local := to_local(point)
	var desired := Vector2i(((Vector2(local.x, local.z) - navigation.offset) / navigation.cell_size).round())
	desired = desired.clamp(Vector2i.ZERO, navigation.region.size - Vector2i.ONE)
	if not navigation.is_point_solid(desired):
		return desired
	var best := desired
	var distance := INF
	for x in range(navigation.region.size.x):
		for z in range(navigation.region.size.y):
			var cell := Vector2i(x, z)
			if not navigation.is_point_solid(cell) and cell.distance_squared_to(desired) < distance:
				distance = cell.distance_squared_to(desired)
				best = cell
	return best

func steering(from: Vector3, target: Vector3) -> Vector2:
	if navigation == null:
		return Vector2.ZERO
	var path := navigation.get_point_path(nearest_cell(from), nearest_cell(target))
	if path.is_empty():
		return Vector2.ZERO
	var point: Vector2 = path[mini(1, path.size() - 1)]
	return (point - Vector2(from.x - global_position.x, from.z - global_position.z)).normalized()

func patrol_point(index: int) -> Vector3:
	var stops := [Vector2(-.30, .23), Vector2(-.30, -.23), Vector2(0, -.23), Vector2(.30, -.23), Vector2(.30, .23), Vector2(0, .23)]
	var p: Vector2 = stops[posmod(index, stops.size())] * play_size
	var cell := nearest_cell(global_position + Vector3(p.x, 0, p.y))
	var free := navigation.get_point_position(cell)
	return global_position + Vector3(free.x, 0, free.y)
