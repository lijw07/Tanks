extends SceneTree

var issues: Array[String] = []
var records: Array[Dictionary] = []
const SIZES := [Vector2i(1280, 800), Vector2i(820, 1180), Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568)]

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for i in 5:
		await process_frame

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var review: Control = load("res://scenes/ui_review.tscn").instantiate()
	viewport.add_child(review)
	for dimensions in SIZES:
		viewport.size = dimensions
		review.set_deferred("size", Vector2(dimensions))
		await settle()
		for name in review.SCREENS:
			review.show_screen(name)
			await settle()
			var screen: Control = review.current
			if review.has_node("ReviewBar"): issues.append("Review navigation must not be visible")
			var record := {"screen":name,"width":dimensions.x,"height":dimensions.y,"buttons":0,"issues":[]}
			for node in screen.find_children("*", "BaseButton", true, false):
				if not node.is_visible_in_tree(): continue
				record.buttons += 1
				if node.size.x < 47.5 or node.size.y < 47.5:
					record.issues.append("Small touch target: " + str(node.name))
				var rect: Rect2 = node.get_global_rect()
				if rect.position.x < -0.5 or rect.end.x > dimensions.x + 0.5:
					record.issues.append("Horizontal overflow: " + str(node.name))
			if name == "HUD":
				var controls := [screen.get_node("HealthPanel"), screen.get_node("ScorePanel"), screen.get_node("Pause"), screen.get_node("Movement"), screen.get_node("Fire"), screen.get_node("Mine")]
				for i in controls.size():
					if not controls[i].visible: continue
					for j in range(i + 1, controls.size()):
						if controls[j].visible and controls[i].get_rect().intersects(controls[j].get_rect()):
							record.issues.append("HUD overlap: " + str(controls[i].name) + "/" + str(controls[j].name) + " " + str(controls[i].get_rect()) + " " + str(controls[j].get_rect()))
			for issue in record.issues:
				issues.append("%s %s: %s" % [dimensions, name, issue])
			records.append(record)
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png("res://previews/%s-%dx%d.png" % [str(name).to_lower(), dimensions.x, dimensions.y])
	review.show_screen("Start")
	await settle()
	review.current.get_node("SafeArea/Scroll/Center/Card/Stack/Play").pressed.emit()
	if review.current_name != "Tanks": issues.append("Play must open tank selection")
	await settle()
	for i in 8:
		review.current.buttons[i].pressed.emit()
		if review.selected_tank != i: issues.append("Tank selection did not propagate")
		var actual: Dictionary = review.current.catalog()[i]
		var shown: String = review.current.stack.get_node("Hero/Details/Stats").text
		if shown != review.current.stats_text(actual): issues.append("Displayed tank statistics differ from gameplay export")
	review.current.get_node("SafeArea/Scroll/Center/Card/Stack/Actions/Ready").pressed.emit()
	await settle()
	if review.current_name != "HUD": issues.append("Ready must open HUD")
	if not "SLATE" in review.current.get_node("HealthPanel/Stack/Name").text: issues.append("HUD did not retain tank")
	review.current.get_node("Fire").pressed.emit()
	if review.shots_fired != 1: issues.append("Fire feedback did not use the selected tank volley")
	if review.current.get_node("Ammo").text != "COOLDOWN": issues.append("Fire cooldown missing")
	review.current.get_node("Pause").pressed.emit()
	await settle()
	if review.current_name != "Pause": issues.append("Pause action failed")
	review.current.get_node("SafeArea/Scroll/Center/Card/Stack/Settings").pressed.emit()
	await settle()
	review.current.get_node("SafeArea/Scroll/Center/Card/Stack/Music").button_pressed = false
	review.current.get_node("SafeArea/Scroll/Center/Card/Stack/Done").pressed.emit()
	await settle()
	if review.current_name != "Pause": issues.append("Settings must return to pause")
	if review.settings_values.Music: issues.append("Settings state did not persist")
	var output := {"engine":Engine.get_version_info().string,"rendered":DisplayServer.get_name() != "headless","layouts":records,"flow_checks":"start → tanks (all 8) → HUD → fire → pause → settings → pause","issues":issues,"passed":issues.is_empty()}
	var file := FileAccess.open("res://validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("UI_VALIDATION: %d layouts, %d issues" % [records.size(), issues.size()])
	for issue in issues: print(issue)
	viewport.queue_free()
	await process_frame
	quit(0 if issues.is_empty() else 1)
