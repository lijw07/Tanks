@tool
extends EditorScenePostImport

const OUTLINE_MATERIAL = preload("res://assets/materials/charcoal_outline.tres")
const EXCLUDED_ASSETS = ["floor_maple_2m", "floor_sand_2m", "spawn_marker_2m"]
const FLAT_DETAILS = ["inlay", "stripe", "insignia", "label", "bore shadow", "pit floor"]

func _post_import(scene: Node) -> Object:
	var asset_id := get_source_file().get_file().get_basename()
	if asset_id in EXCLUDED_ASSETS:
		return scene
	var width := 0.04 if asset_id.begins_with("tank_") else 0.035
	_add_outlines(scene, scene, width)
	scene.set_meta("outline_style", "charcoal_hull")
	return scene

func _add_outlines(node: Node, scene: Node, width: float) -> void:
	for child in node.get_children():
		_add_outlines(child, scene, width)
	if not node is MeshInstance3D or node.mesh == null:
		return
	var label := String(node.name).to_lower().replace("_", " ")
	for detail in FLAT_DETAILS:
		if detail in label:
			return
	var mesh_node := node as MeshInstance3D
	var size := mesh_node.mesh.get_aabb().size
	var smallest := minf(size.x, minf(size.y, size.z))
	if smallest < 0.008:
		return
	var outline_mesh := mesh_node.mesh.create_outline(minf(width, smallest * 0.18))
	if outline_mesh == null:
		push_error("Could not create outline for " + String(node.name))
		return
	var outline := MeshInstance3D.new()
	outline.name = "CharcoalOutline"
	outline.mesh = outline_mesh
	outline.material_override = OUTLINE_MATERIAL
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	outline.layers = mesh_node.layers
	outline.set_meta("visual_outline", true)
	mesh_node.add_child(outline)
	outline.owner = scene
