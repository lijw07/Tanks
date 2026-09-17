extends Node3D

const TankScript = preload("res://scripts/tank.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const MineScript = preload("res://scripts/mine.gd")
const EffectScript = preload("res://scripts/effects.gd")
const MapCatalog = preload("res://scripts/map_catalog.gd")

signal match_ready
signal match_finished(won: bool)
signal player_destroyed

@export var game_menu_mode := false
@export var starting_map := 0
var touch_move := Vector2.ZERO
var touch_aim_active := false
var touch_aim_point := Vector3.ZERO

var player: ToyTank
var actors: Node3D
var shots: Node3D
var fx: Node3D
var aim_point := Vector3.ZERO
var view_mode: int = 0
var battle_mode := false
var battle_age := 0.0
var round_over := false
var selected_tank := 0
var kills := 0
var shots_fired := 0
var camera: Camera3D
var crosshair: Control
var cursor_position := Vector2.ZERO
var gallery: Node3D
var stats: Label
var mode_label: Label
var status_label: Label
var battle_button: Button
var tank_choice: OptionButton
var collision_toggle: CheckButton
var nav_buttons: Array[Button] = []
var show_collisions := false
var qa_mode := false
var test_input := Vector2.ZERO
var active_map: Node3D
var selected_map := 0
var tank_count := 8
var map_choice: OptionButton
var count_choice: OptionButton
var follow_toggle: CheckButton
var overview_mode := true
var loading_map := false
var spectating := false
var spectate_target: ToyTank

func _ready() -> void:
	qa_mode = "--integration-qa" in OS.get_cmdline_user_args()
	for child in $Arena.get_children():
		$Arena.remove_child(child)
		child.queue_free()
	actors = Node3D.new()
	actors.name = "LiveTanks"
	$Arena.add_child(actors)
	shots = Node3D.new()
	shots.name = "ProjectilesAndMines"
	$Arena.add_child(shots)
	fx = Node3D.new()
	fx.set_script(EffectScript)
	fx.name = "CartoonEffects"
	$Arena.add_child(fx)
	camera = $Camera3D
	_build_ui()
	_build_crosshair()
	cursor_position = get_viewport().get_mouse_position()
	await select_map(starting_map)
	match_ready.emit()
	if qa_mode:
		call_deferred("_integration_qa")

func _physics_process(delta: float) -> void:
	if battle_mode and not round_over and not loading_map and view_mode == 0:
		battle_age += delta

func _process(delta: float) -> void:
	if view_mode == 0:
		if not loading_map:
			_update_map_camera(1.0 - exp(-delta * 8.0))
		var mouse := cursor_position
		var point = Plane(Vector3.UP, 1.02).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
		if touch_aim_active:
			aim_point = touch_aim_point
		elif point != null:
			aim_point = point
		crosshair.follow_mouse = not touch_aim_active
		crosshair.pointer_position = mouse
		crosshair.touch_position = camera.unproject_position(aim_point)
		crosshair.enabled = not pointer_over_ui() and not round_over and not spectating
		if spectating:
			_keep_spectate_target_alive()
			stats.text = "SPECTATING  %s     TARGETS  %d / %d" % [spectate_name(), kills, tank_count - 1]
		else:
			var hp := player.health if is_instance_valid(player) else 0
			stats.text = "HULL  %s     TARGETS  %d / %d" % ["●".repeat(maxi(hp, 0)) + "○".repeat(ToyTank.PLAYER_HP - maxi(hp, 0)), kills, tank_count - 1]
	else:
		crosshair.enabled = false
	if not game_menu_mode and Input.is_action_just_pressed("reset"):
		reset_arena()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		cursor_position = event.position

func pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null

func reset_arena() -> void:
	if loading_map or not is_instance_valid(active_map):
		return
	for container in [actors,shots,fx]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	kills = 0
	battle_age = 0.0
	shots_fired = 0
	round_over = false
	spectating = false
	spectate_target = null
	var spawns: Array[Node] = active_map.spawn_points()
	for i in range(tank_count):
		var variant := selected_tank if i == 0 else (selected_tank + i) % 8
		var tank: ToyTank = load("res://scenes/tanks/%s.tscn" % ToyTank.IDS[variant]).instantiate()
		tank.player_controlled = i == 0
		tank.arena = self
		tank.transform = spawns[i].transform
		actors.add_child(tank)
		tank.destroyed.connect(_on_tank_destroyed)
		if i == 0:
			player = tank
	_update_mode_text()
	if show_collisions:
		_refresh_collision_overlay()
	if view_mode == 0:
		_update_map_camera(1.0)

func select_map(index: int) -> void:
	if loading_map:
		return
	loading_map = true
	round_over = true
	selected_map = index
	map_choice.disabled = true
	if is_instance_valid(active_map):
		$Arena.remove_child(active_map)
		active_map.queue_free()
	active_map = load(MapCatalog.scene_path(index)).instantiate()
	active_map.name = "Battlefield"
	active_map.prepare_for_game()
	$Arena.add_child(active_map)
	await get_tree().physics_frame
	await get_tree().physics_frame
	active_map.build_navigation()
	loading_map = false
	map_choice.disabled = view_mode != 0
	reset_arena()

func navigation_direction(from: Vector3, target: Vector3) -> Vector2:
	return active_map.steering(from, target) if is_instance_valid(active_map) else Vector2.ZERO

func _update_map_camera(weight: float) -> void:
	var focus := Vector3.ZERO
	var subject: ToyTank = spectate_target if spectating else player
	if not overview_mode and is_instance_valid(subject):
		var limits: Vector2 = active_map.play_size * .5 - Vector2(10, 8)
		focus = Vector3(clampf(subject.position.x, -limits.x, limits.x), 0, clampf(subject.position.z, -limits.y, limits.y))
	var overview_size: float = maxf(active_map.play_size.x * 1.04, active_map.play_size.y * 1.38)
	var offset := Vector3(0, overview_size, overview_size * .75) if overview_mode else Vector3(0, 25, 19)
	camera.position = camera.position.lerp(focus + offset, weight)
	camera.size = lerpf(camera.size, overview_size if overview_mode else 21.0, weight)
	camera.rotation.x = -atan2(offset.y, offset.z)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and ((game_menu_mode and event.is_action_pressed("camera")) or (not game_menu_mode and event is InputEventKey and event.keycode == KEY_TAB)) and view_mode == 0:
		overview_mode = not overview_mode
		follow_toggle.set_pressed_no_signal(not overview_mode)
		get_viewport().set_input_as_handled()

func spawn_shell(point: Vector3, direction: Vector3, shooter: CharacterBody3D) -> void:
	var shell := Node3D.new()
	shell.set_script(ProjectileScript)
	shell.position = point
	shell.direction = direction
	shell.shooter = shooter
	shell.arena = self
	shots.add_child(shell)
	shots_fired += 1

func spawn_mine(point: Vector3, _shooter: ToyTank) -> void:
	var mine := Node3D.new()
	mine.set_script(MineScript)
	var half: Vector2 = active_map.play_size * .5 - Vector2.ONE
	mine.position = Vector3(clampf(point.x, -half.x, half.x), 0, clampf(point.z, -half.y, half.y))
	mine.arena = self
	shots.add_child(mine)

func _on_tank_destroyed(tank: ToyTank) -> void:
	if tank.player_controlled:
		spectating = true
		cycle_spectate(0)
		player_destroyed.emit()
		_finish_if_last_tank_standing()
		return
	if spectating:
		_finish_if_last_tank_standing()
		return
	kills += 1
	if kills == tank_count - 1:
		round_over = true
		status_label.text = "ARENA CLEAR  ·  All %d targets destroyed  ·  R to restart" % (tank_count - 1)
		match_finished.emit(true)

func _finish_if_last_tank_standing() -> void:
	if living_tanks().size() > 1:
		return
	round_over = true
	spectating = false
	status_label.text = "TANK DOWN  ·  Press R or Reset to try again"
	match_finished.emit(false)

func living_tanks() -> Array[ToyTank]:
	var result: Array[ToyTank] = []
	for node in actors.get_children():
		var tank := node as ToyTank
		if tank != null and tank.alive:
			result.append(tank)
	return result

func cycle_spectate(step: int) -> void:
	var candidates := living_tanks()
	if candidates.is_empty():
		spectate_target = null
		return
	var index := candidates.find(spectate_target)
	spectate_target = candidates[posmod(index + step, candidates.size()) if index >= 0 else 0]

func spectate_name() -> String:
	return ToyTank.NAMES[spectate_target.variant].to_upper() if is_instance_valid(spectate_target) else "ARENA"

func _keep_spectate_target_alive() -> void:
	if not is_instance_valid(spectate_target) or not spectate_target.alive:
		cycle_spectate(1)

func _update_mode_text() -> void:
	mode_label.text = "BATTLE / ENEMIES ACTIVE" if battle_mode else "PRACTICE / TARGETS HOLD FIRE"
	status_label.text = MapCatalog.MAPS[selected_map].description
	battle_button.text = "Practice mode" if battle_mode else "Start battle"

func _set_view(mode: int) -> void:
	view_mode = mode
	$Arena.visible = mode == 0
	$Arena.process_mode = Node.PROCESS_MODE_INHERIT if mode == 0 else Node.PROCESS_MODE_DISABLED
	if is_instance_valid(gallery):
		remove_child(gallery)
		gallery.queue_free()
	if mode == 0:
		_update_map_camera(1.0)
		_update_mode_text()
	else:
		_build_gallery(mode)
		mode_label.text = "TANK SCENES / 8 VARIANTS" if mode == 1 else "MODULAR SCENES / 25 PIECES"
		status_label.text = "Each displayed piece is its own .tscn scene with model-matched collision."
		stats.text = "COLLISION OVERLAY AVAILABLE"
	for i in range(nav_buttons.size()):
		nav_buttons[i].button_pressed = i == mode
	battle_button.disabled = mode != 0
	tank_choice.disabled = mode != 0
	map_choice.disabled = mode != 0 or loading_map
	count_choice.disabled = mode != 0
	follow_toggle.disabled = mode != 0
	if show_collisions:
		_refresh_collision_overlay()

func _build_gallery(mode: int) -> void:
	gallery = Node3D.new()
	gallery.name = "AssetGallery"
	add_child(gallery)
	var paths: Array[String] = []
	if mode == 1:
		for id in ToyTank.IDS:
			paths.append("res://scenes/tanks/%s.tscn" % id)
	else:
		for folder in ["arena", "props"]:
			for file in DirAccess.get_files_at("res://scenes/" + folder):
				if file.ends_with(".tscn"):
					paths.append("res://scenes/%s/%s" % [folder,file])
		paths.sort()
	var columns := 4 if mode == 1 else 5
	var rows := ceili(float(paths.size()) / columns)
	for i in range(paths.size()):
		var stage := Node3D.new()
		gallery.add_child(stage)
		stage.position = Vector3((i % columns - (columns - 1) * .5) * 5.0, 0, (i / columns - (rows - 1) * .5) * 4.1)
		var asset: Node3D = load(paths[i]).instantiate()
		stage.add_child(asset)
		asset.process_mode = Node.PROCESS_MODE_DISABLED
		if mode == 1:
			asset.rotation.y = PI - .25
		var plinth := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4.5,.18,3.7)
		plinth.mesh = box
		plinth.position.y = -.18 if not "pit_" in paths[i] else -.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("243b4b")
		mat.roughness = 1.0
		plinth.material_override = mat
		stage.add_child(plinth)
		var label := Label3D.new()
		label.text = ToyTank.NAMES[i] if mode == 1 else paths[i].get_file().get_basename().replace("_", " ")
		label.font_size = 40
		label.pixel_size = .008
		label.position = Vector3(0,.02,1.55)
		label.rotation_degrees.x = -90
		label.modulate = Color("e9e2c9")
		label.no_depth_test = true
		stage.add_child(label)
	camera.position = Vector3(0,30,18)
	camera.look_at(Vector3.ZERO)
	camera.size = 19.0 if mode == 1 else 29.5

func _build_crosshair() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AimOverlay"
	layer.layer = 2
	add_child(layer)
	crosshair = Control.new()
	crosshair.set_script(preload("res://scripts/aim_reticle.gd"))
	crosshair.name = "AimMarker"
	layer.add_child(crosshair)

func _style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_color = border
	style.set_border_width_all(1)
	return style

func _button(text_value: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style(Color("233746")))
	button.add_theme_stylebox_override("hover", _style(Color("34536a")))
	button.add_theme_stylebox_override("pressed", _style(Color("3b615f"),Color("9ce0c3")))
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	canvas.visible = not game_menu_mode
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(screen)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_top = 20
	top.offset_right = -24
	top.add_theme_stylebox_override("panel", _style(Color("132430")))
	screen.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var top_rows := VBoxContainer.new()
	top_rows.add_theme_constant_override("separation", 10)
	top.add_child(top_rows)
	top_rows.add_child(row)
	var title_group := VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_group)
	var title := Label.new()
	title.text = "POCKET ARMOR"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f4d592"))
	title_group.add_child(title)
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 12)
	mode_label.add_theme_color_override("font_color", Color("92afaF"))
	title_group.add_child(mode_label)
	for i in range(3):
		var button := _button(["Arena", "Tanks", "Pieces"][i], row, _set_view.bind(i))
		button.toggle_mode = true
		button.button_pressed = i == 0
		nav_buttons.append(button)
	tank_choice = OptionButton.new()
	tank_choice.focus_mode = Control.FOCUS_NONE
	for name_value in ToyTank.NAMES:
		tank_choice.add_item(name_value)
	tank_choice.item_selected.connect(func(index: int): selected_tank = index; reset_arena())
	row.add_child(tank_choice)
	battle_button = _button("Start battle", row, func(): battle_mode = not battle_mode; follow_toggle.button_pressed = battle_mode; reset_arena())
	_button("Reset", row, reset_arena)
	var maps_row := HBoxContainer.new()
	maps_row.add_theme_constant_override("separation", 14)
	top_rows.add_child(maps_row)
	var map_label := Label.new()
	map_label.text = "MAP"
	maps_row.add_child(map_label)
	map_choice = OptionButton.new()
	map_choice.custom_minimum_size.x = 220
	map_choice.focus_mode = Control.FOCUS_NONE
	for item in MapCatalog.MAPS:
		map_choice.add_item(item.name)
	map_choice.item_selected.connect(select_map)
	maps_row.add_child(map_choice)
	count_choice = OptionButton.new()
	count_choice.focus_mode = Control.FOCUS_NONE
	for count in [4, 6, 8]:
		count_choice.add_item("%d tanks" % count, count)
	count_choice.select(2)
	count_choice.item_selected.connect(func(index: int): tank_count = count_choice.get_item_id(index); reset_arena())
	maps_row.add_child(count_choice)
	var size_label := Label.new()
	size_label.text = "96 × 72 m"
	size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_label.add_theme_color_override("font_color", Color("92afaf"))
	maps_row.add_child(size_label)
	follow_toggle = CheckButton.new()
	follow_toggle.text = "Follow tank"
	follow_toggle.focus_mode = Control.FOCUS_NONE
	follow_toggle.toggled.connect(func(enabled: bool): overview_mode = not enabled)
	maps_row.add_child(follow_toggle)
	var info := HBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	info.offset_left = 34
	info.offset_right = -34
	info.offset_top = 154
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(info)
	stats = Label.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color("f4e4c5"))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(stats)
	collision_toggle = CheckButton.new()
	collision_toggle.text = "Show collision"
	collision_toggle.focus_mode = Control.FOCUS_NONE
	collision_toggle.toggled.connect(func(enabled: bool): show_collisions = enabled; _refresh_collision_overlay())
	info.add_child(collision_toggle)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -83
	bottom.offset_bottom = -18
	bottom.add_theme_stylebox_override("panel", _style(Color("132430")))
	screen.add_child(bottom)
	var hints := VBoxContainer.new()
	bottom.add_child(hints)
	var controls := Label.new()
	controls.text = "WASD / ARROWS  move   ·   MOUSE  aim   ·   CLICK  fire   ·   SPACE  mine   ·   TAB  camera   ·   R  reset"
	controls.add_theme_font_size_override("font_size", 15)
	hints.add_child(controls)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("9cb4bf"))
	hints.add_child(status_label)

func _refresh_collision_overlay() -> void:
	for node in get_tree().get_nodes_in_group("collision_overlay"):
		node.queue_free()
	if not show_collisions:
		return
	var target: Node = $Arena if view_mode == 0 else gallery
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.15,1.0,0.6,0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	_overlay_recursive(target, material)

func _overlay_recursive(node: Node, material: Material) -> void:
	if node is CollisionShape3D and node.shape:
		var mesh := MeshInstance3D.new()
		mesh.mesh = node.shape.get_debug_mesh()
		mesh.material_override = material
		mesh.add_to_group("collision_overlay")
		node.add_child(mesh)
	for child in node.get_children():
		if not child.is_in_group("collision_overlay"):
			_overlay_recursive(child, material)

func _integration_qa() -> void:
	var test = load("res://tests/integration.gd").new()
	add_child(test)
	test.run(self)
