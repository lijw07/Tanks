extends RefCounted

const ACTIONS := {
	"move_up": "Move forward", "move_down": "Move backward",
	"move_left": "Move left", "move_right": "Move right",
	"fire": "Fire", "mine": "Drop mine", "camera": "Camera", "pause_game": "Pause"
}

static func defaults(action: String) -> Array:
	if action in ["camera", "pause_game"]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_TAB if action == "camera" else KEY_ESCAPE
		return [key]
	return ProjectSettings.get_setting("input/" + action, {"events": []}).events

static func initialize(config: ConfigFile) -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var events: Array = []
		for data in config.get_value("bindings", action, []):
			if not data is Dictionary: continue
			if data.get("key", 0) > 0:
				var key := InputEventKey.new()
				key.physical_keycode = int(data.key)
				key.shift_pressed = bool(data.get("shift", false))
				key.ctrl_pressed = bool(data.get("ctrl", false))
				key.alt_pressed = bool(data.get("alt", false))
				key.meta_pressed = bool(data.get("meta", false))
				events.append(key)
			elif data.get("mouse", 0) > 0:
				var mouse := InputEventMouseButton.new()
				mouse.button_index = int(data.mouse)
				events.append(mouse)
		set_events(action, defaults(action) if events.is_empty() else events)

static func set_events(action: String, events: Array) -> void:
	Input.action_release(action)
	InputMap.action_erase_events(action)
	for event in events: InputMap.action_add_event(action, event)

static func save(config: ConfigFile) -> void:
	for action in ACTIONS:
		var events: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				events.append({"key": event.physical_keycode if event.physical_keycode else event.keycode,
					"shift": event.shift_pressed, "ctrl": event.ctrl_pressed, "alt": event.alt_pressed, "meta": event.meta_pressed})
			elif event is InputEventMouseButton:
				events.append({"mouse": event.button_index})
		config.set_value("bindings", action, events)

static func label(action: String) -> String:
	var names := PackedStringArray()
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT: names.append("Left mouse")
				MOUSE_BUTTON_RIGHT: names.append("Right mouse")
				MOUSE_BUTTON_MIDDLE: names.append("Middle mouse")
				_: names.append("Mouse %d" % event.button_index)
		else: names.append(event.as_text().replace(" (Physical)", "").replace(" - Physical", ""))
	return " / ".join(names)

static func conflict(action: String, event: InputEvent) -> String:
	for other in ACTIONS:
		if other != action and InputMap.event_is_action(event, other, true): return ACTIONS[other]
	return ""

static func movement_label() -> String:
	var keys := PackedStringArray()
	for action in ["move_up", "move_left", "move_down", "move_right"]:
		keys.append(label(action).split(" / ")[0])
	return "/".join(keys)

static func reset() -> void:
	for action in ACTIONS: set_events(action, defaults(action))
