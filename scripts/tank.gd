class_name ToyTank
extends CharacterBody3D

@onready var audio: Node = get_node("/root/GameAudio")

signal destroyed(tank: ToyTank)
signal health_changed(value: int)

const IDS = ["tank_01_azure_scout", "tank_02_mint_cruiser", "tank_03_vermilion_heavy", "tank_04_saffron_sprinter", "tank_05_violet_marksman", "tank_06_ivory_duelist", "tank_07_tangerine_siege", "tank_08_charcoal_command"]
const NAMES = ["Azure Scout", "Mint Cruiser", "Red Bulldog", "Gold Sprinter", "Violet Needle", "Ivory Duelist", "Orange Mortar", "Slate Command"]
const WIDTHS = [1.12, 1.40, 1.78, 1.02, 1.22, 1.48, 1.70, 1.56]
const LENGTHS = [1.50, 1.75, 2.03, 1.28, 1.84, 1.66, 2.12, 1.88]
const PLAYER_HP = 1
const ENEMY_HP = 1
const SHELL_DAMAGE = 1
const PLAYER_FIRE_INTERVAL = 0.7
const ENEMY_SPAWN_GRACE = 4.0
const SIGHT_RANGE = 22.0
const TARGET_MEMORY = 5.0
const AIM_TIME = 0.8
const HEAVY_FIRE_MULTIPLIER = 1.4
const MINE_COOLDOWN = 2.5

const SPEEDS = [3.5, 3.1, 2.5, 4.2, 3.0, 3.1, 2.4, 2.9]

@export_range(0, 7) var variant: int = 0
@export var player_controlled: bool = false
var arena: Node3D
var health: int = 1
var alive: bool = true
var cooldown: float = 0.0
var mine_cooldown: float = 0.0
var turret: Node3D
var suspension: Node3D
var wheels: Array[Node3D] = []
var wheel_bases: Array[Basis] = []
var tracks: Array[Node3D] = []
var guns: Array[Node3D] = []
var muzzles: Array[Node3D] = []
var gun_origins: Array[Vector3] = []
var travel_left: float = 0.0
var travel_right: float = 0.0
var age: float = 0.0
var dust_clock: float = 0.0
var ai_clock: float = 0.0
var ai_move: Vector2 = Vector2.ZERO
var last_seen := Vector3.ZERO
var memory_left := 0.0
var aim_time := 0.0
var patrol_index := 0
var patrol_goal := Vector3.ZERO
var hitboxes: Array[Area3D] = []

func _ready() -> void:
	health = PLAYER_HP if player_controlled else ENEMY_HP
	if not player_controlled:
		cooldown = ENEMY_SPAWN_GRACE + randf() * 0.9
	add_to_group("tanks")
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var model: Node3D = $Model
	_collect_parts(model)
	for child in get_children():
		if child is Area3D:
			hitboxes.append(child)
	for gun in guns:
		gun_origins.append(gun.position)
	patrol_index = variant
	if is_instance_valid(arena):
		patrol_goal = arena.active_map.patrol_point(patrol_index)
	ai_clock = 0.7 + variant * 0.13
	_update_tracks()

func _collect_parts(node: Node) -> void:
	if node is Node3D:
		var label := String(node.name).to_lower().replace(" ", "_")
		if "turretpivot" in label:
			turret = node
			turret.rotation.y = 0.0
		elif "suspension" in label:
			suspension = node
		elif "road_wheel" in label:
			wheels.append(node)
			wheel_bases.append(node.basis)
		elif "tread_" in label or "tread-" in label:
			tracks.append(node)
		elif "barrelrecoil" in label:
			guns.append(node)
		elif "muzzle" in label and not node is MeshInstance3D:
			muzzles.append(node)
	for child in node.get_children():
		_collect_parts(child)

func _physics_process(delta: float) -> void:
	if not alive or not is_instance_valid(arena) or arena.view_mode != 0:
		return
	if arena.round_over:
		velocity = Vector3.ZERO
		return
	age += delta
	var was_reloading := cooldown > 0.0
	cooldown = maxf(0.0, cooldown - delta)
	if was_reloading and cooldown == 0.0 and player_controlled:
		audio.play_world("reload_ready", global_position, arena, -7.0)
	mine_cooldown = maxf(0.0, mine_cooldown - delta)
	var input := Vector2.ZERO
	var aim := global_position + global_basis.z * 3.0
	if player_controlled:
		input = arena.test_input if arena.qa_mode else (Input.get_vector("move_left", "move_right", "move_up", "move_down") + arena.touch_move).limit_length(1.0)
		aim = arena.aim_point
		if not arena.qa_mode and Input.is_action_pressed("fire") and not arena.pointer_over_ui():
			fire()
		if not arena.qa_mode and Input.is_action_just_pressed("mine"):
			drop_mine()
	elif arena.battle_mode:
		var opponent := _acquire_target()
		var visible_target := is_instance_valid(opponent) and global_position.distance_to(opponent.global_position) <= SIGHT_RANGE and _clear_shot(opponent)
		memory_left = maxf(0.0, memory_left - delta)
		if visible_target:
			last_seen = opponent.global_position
			memory_left = TARGET_MEMORY
			aim_time += delta
		else:
			aim_time = 0.0
		if memory_left > 0.0:
			aim = last_seen
		else:
			if global_position.distance_to(patrol_goal) < 3.0:
				patrol_index += 1
				patrol_goal = arena.active_map.patrol_point(patrol_index)
			aim = patrol_goal
		ai_clock -= delta
		if ai_clock <= 0.0:
			ai_clock = 0.3 + randf() * 0.15
			ai_move = arena.navigation_direction(global_position, aim) if not visible_target or global_position.distance_to(aim) > 8.0 else Vector2.ZERO
		input = ai_move * 0.55
		if visible_target and aim_time >= AIM_TIME and cooldown <= 0.0 and global_position.distance_to(opponent.global_position) < 15.0:
			var facing := turret.global_basis.z.normalized().dot((opponent.global_position - global_position).normalized()) if turret else 0.0
			if facing > .98:
				fire()
	var old_position := global_position
	var old_yaw := rotation.y
	var desired_speed := 0.0
	if input.length() > 0.05:
		var desired_yaw := atan2(input.x, input.y)
		rotation.y = rotate_toward(rotation.y, desired_yaw, delta * 3.6)
		var alignment := cos(angle_difference(rotation.y, desired_yaw))
		desired_speed = SPEEDS[variant] * input.length() * maxf(0.0, alignment)
	velocity = global_basis.z * move_toward(velocity.length(), desired_speed, delta * 10.0)
	move_and_slide()
	position.y = 0.0
	var yaw_delta := angle_difference(old_yaw, rotation.y)
	var middle_forward := Vector3(sin(old_yaw + yaw_delta * 0.5), 0.0, cos(old_yaw + yaw_delta * 0.5))
	var distance := (global_position - old_position).dot(middle_forward)
	var track_width := 0.30 if WIDTHS[variant] < 1.4 else 0.36
	var offset: float = (WIDTHS[variant] - track_width) * 0.5
	travel_left += distance + yaw_delta * offset
	travel_right += distance - yaw_delta * offset
	_update_tracks()
	var aim_offset := aim - global_position
	if turret and aim_offset.length_squared() > 0.1:
		var local_yaw := atan2(aim_offset.x, aim_offset.z) - rotation.y
		turret.rotation.y = rotate_toward(turret.rotation.y, local_yaw, delta * 7.0)
	for hitbox in hitboxes:
		var target_part := get_node(hitbox.get_meta("follow_part")) as Node3D
		hitbox.global_transform = target_part.global_transform
	if suspension:
		suspension.position.y = sin(age * 20.0) * 0.012 * minf(1.0, velocity.length())
	dust_clock += delta
	if velocity.length() > 0.4 and dust_clock > 0.17:
		dust_clock = 0.0
		arena.fx.dust(global_position - global_basis.z * LENGTHS[variant] * 0.4, global_basis.x * 0.35)

func _update_tracks() -> void:
	for i in range(wheels.size()):
		var wheel := wheels[i]
		var travel := travel_left if wheel.position.x < 0.0 else travel_right
		wheel.basis = Basis(Quaternion(Vector3.RIGHT, fposmod(travel / 0.17, TAU))) * wheel_bases[i]
	var a: float = LENGTHS[variant] * 0.5 - 0.22
	var perimeter := 4.0 * a + TAU * 0.22
	var groups: Array = [[], []]
	for link in tracks:
		groups[0 if link.position.x < 0.0 else 1].append(link)
	for side in range(2):
		var links: Array = groups[side]
		links.sort_custom(func(x, y): return String(x.name).naturalnocasecmp_to(String(y.name)) < 0)
		for i in range(links.size()):
			var link: Node3D = links[i]
			var travel := travel_left if side == 0 else travel_right
			var result := track_path(fposmod(float(i) * perimeter / links.size() + travel, perimeter), a)
			link.position.y = result.y
			link.position.z = -result.x
			link.rotation = Vector3(result.z, 0.0, 0.0)

static func track_path(s: float, a: float) -> Vector3:
	var straight := 2.0 * a
	var radius := 0.22
	if s < straight:
		return Vector3(a - s, 0.48, PI)
	s -= straight
	if s < PI * radius:
		var t := s / radius
		return Vector3(-a - radius * sin(t), 0.26 + radius * cos(t), PI + t)
	s -= PI * radius
	if s < straight:
		return Vector3(-a + s, 0.04, 0.0)
	var t := (s - straight) / radius
	return Vector3(a + radius * sin(t), 0.26 - radius * cos(t), t)

func _acquire_target() -> ToyTank:
	if is_instance_valid(arena.player) and arena.player.alive:
		return arena.player
	var nearest: ToyTank = null
	var closest := INF
	for node in get_tree().get_nodes_in_group("tanks"):
		var other := node as ToyTank
		if other == null or other == self or not other.alive:
			continue
		var distance := global_position.distance_squared_to(other.global_position)
		if distance < closest:
			closest = distance
			nearest = other
	return nearest

func _clear_shot(target: ToyTank) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, target.global_position + Vector3.UP, 1 | 2 | 8, excluded_rids())
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and (result.collider == target or (result.collider is Area3D and result.collider.get_parent() == target))

func excluded_rids() -> Array[RID]:
	var result: Array[RID] = [get_rid()]
	for area in hitboxes:
		result.append(area.get_rid())
	return result

func fire() -> bool:
	if not alive or cooldown > 0.0 or muzzles.is_empty():
		return false
	if not player_controlled and arena.battle_age < ENEMY_SPAWN_GRACE:
		return false
	cooldown = PLAYER_FIRE_INTERVAL if player_controlled else 2.6 + randf() * 1.2
	if variant == 6:
		cooldown *= HEAVY_FIRE_MULTIPLIER
	_shoot_barrel(0)
	if muzzles.size() > 1:
		get_tree().create_timer(0.12, false).timeout.connect(func():
			if is_instance_valid(self) and alive:
				_shoot_barrel(1))
	return true

func _shoot_barrel(index: int) -> void:
	var muzzle := muzzles[index]
	var direction := turret.global_basis.z.normalized()
	direction.y = 0.0
	var point := muzzle.global_position
	point.y = 1.02
	arena.spawn_shell(point, direction, self)
	audio.play_world("cannon_%02d" % variant, point, arena, 0.0 if player_controlled else -4.0)
	arena.fx.muzzle(point, direction)
	if index < guns.size():
		var gun := guns[index]
		gun.position = gun_origins[index] - Vector3(0, 0, 0.18)
		create_tween().tween_property(gun, "position", gun_origins[index], 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func drop_mine() -> void:
	if mine_cooldown > 0.0 or not alive:
		return
	mine_cooldown = MINE_COOLDOWN
	arena.spawn_mine(global_position - global_basis.z * (LENGTHS[variant] * 0.5 + 0.45), self)

func take_hit() -> void:
	if not alive:
		return
	health -= SHELL_DAMAGE
	health_changed.emit(health)
	if health <= 0:
		die()
	else:
		arena.fx.impact(global_position + Vector3.UP * 0.7, Vector3.UP)

func die() -> void:
	if not alive:
		return
	alive = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	for hitbox in hitboxes:
		hitbox.collision_layer = 0
	$Model.hide()
	arena.fx.explosion(global_position, variant, rotation.y)
	destroyed.emit(self)

static func player_stats(index: int) -> Dictionary:
	var i := clampi(index, 0, IDS.size() - 1)
	return {"id": IDS[i], "name": NAMES[i], "speed_mps": SPEEDS[i], "player_hp": PLAYER_HP, "damage_per_shell": SHELL_DAMAGE, "fire_interval_s": PLAYER_FIRE_INTERVAL * (HEAVY_FIRE_MULTIPLIER if i == 6 else 1.0), "shots_per_trigger": 2 if i == 5 else 1}
