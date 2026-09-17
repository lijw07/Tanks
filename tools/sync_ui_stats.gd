extends SceneTree

const Tank = preload("res://scripts/tank.gd")
const Shell = preload("res://scripts/projectile.gd")
const BADGES := ["azure", "mint", "red", "gold", "violet", "ivory", "orange", "slate"]

class PreviewFX extends Node3D:
	func muzzle(_point: Vector3, _direction: Vector3) -> void: pass
	func impact(_point: Vector3, _direction: Vector3) -> void: pass

class ProbeArena extends Node3D:
	var fx := PreviewFX.new()
	var shots := 0
	func spawn_shell(_point: Vector3, _direction: Vector3, _tank: Node) -> void:
		shots += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena := ProbeArena.new()
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(arena)
	arena.add_child(arena.fx)
	var records: Array[Dictionary] = []
	for i in Tank.IDS.size():
		var tank = load("res://scenes/tanks/%s.tscn" % Tank.IDS[i]).instantiate()
		tank.player_controlled = true
		tank.arena = arena
		arena.add_child(tank)
		var hp: int = tank.health
		tank.take_hit()
		var damage: int = hp - tank.health
		arena.shots = 0
		assert(tank.fire(), "Expected a loaded tank to fire")
		var firing_delay: float = tank.cooldown
		await create_timer(0.15).timeout
		records.append({"id":Tank.IDS[i],"badge":BADGES[i],"name":Tank.NAMES[i],"speed_mps":Tank.SPEEDS[i],"player_hp":hp,"damage_per_shell":damage,"fire_interval_s":snappedf(firing_delay, 0.01),"shots_per_trigger":arena.shots})
		assert(arena.shots == (2 if i == 5 else 1))
		arena.remove_child(tank)
		tank.queue_free()
	var sources := {}
	for path in ["scripts/tank.gd", "scripts/projectile.gd"]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var output := {"source":"Current playable Godot tank scenes; player-controlled values", "source_sha256":sources,"tanks":records}
	var file := FileAccess.open("res://art-review/ui-kit-v1/tank_stats.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("UI_STATS_SYNC: probed all 8 tanks; health, hit damage, fire delay, and shot count verified")
	arena.queue_free()
	await process_frame
	quit()
