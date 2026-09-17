extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(640, 480)
	var portrait := SubViewportContainer.new()
	portrait.set_script(load("res://assets/ui/scripts/tank_portrait.gd"))
	portrait.animate = false
	portrait.size = Vector2(640, 480)
	root.add_child(portrait)
	for i in 8:
		portrait.show_tank(i)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		var result: int = portrait.get_child(0).get_texture().get_image().save_png("res://assets/ui/portraits/%s.png" % ToyTank.IDS[i])
		if result != OK:
			push_error("Failed to render tank portrait %d" % i)
			quit(1)
			return
	print("TANK_PORTRAITS_COMPLETE")
	quit()
