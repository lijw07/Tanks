extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	print("QUIT_BUTTON_INVOKED")
	menu.screen.get_node("Margin/Scroll/Layout/Menu/Actions/Quit").pressed.emit()
	await create_timer(0.5).timeout
	push_error("Quit button did not close the game")
	quit(1)
