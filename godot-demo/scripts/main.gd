extends Control
## Local UX demo. Routes and mock values are copied from the Figma prototype.
const HOME := "165:958"
var routes: Dictionary = {}
var values: Dictionary = {}
var pages: Dictionary = {}
var current_id := ""
var history: Array[String] = []
var overlays: Array[Control] = []
var busy := false
var smoke_mode := false
var otter_press_position := Vector2.ZERO
var pressed_otter: Control
var room_studio: Node
var food_flow: Node

func _input(event: InputEvent) -> void:
	# Observe taps without consuming them: all existing Figma button routes remain active.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			otter_press_position = event.position
			pressed_otter = otter_at(event.position)
		else:
			if is_instance_valid(pressed_otter) and event.position.distance_to(otter_press_position) < 8.0 and pressed_otter == otter_at(event.position):
				pressed_otter.react()
			pressed_otter = null
	elif event is InputEventMouseMotion and event.position.distance_to(otter_press_position) >= 8.0:
		pressed_otter = null

func otter_at(point: Vector2) -> Control:
	if current_id.is_empty():
		return null
	var scope: Control = pages[current_id] if overlays.is_empty() else overlays[-1]
	var characters := get_tree().get_nodes_in_group("otter_characters")
	characters.reverse()
	for character in characters:
		if scope.is_ancestor_of(character) and $DragScroll.visible_at(character, point):
			return character
	return null

func _ready() -> void:
	routes = JSON.parse_string(FileAccess.get_file_as_string("res://design/routes.json"))
	for item in JSON.parse_string(FileAccess.get_file_as_string("res://design/variables.json")):
		if not item.values.is_empty():
			values[item.id] = item.values.values()[0]
	var start := HOME
	if OS.has_feature("web"):
		var requested: String = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('page') || ''"))
		if routes.has(requested): start = requested
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--page="):
			start = arg.trim_prefix("--page=")
	smoke_mode = args.has("--smoke") or args.has("--capture-all") or args.has("--interaction-test")
	room_studio = Node.new()
	room_studio.name = "RoomStudio"
	room_studio.set_script(preload("res://scripts/room_studio.gd"))
	add_child(room_studio)
	food_flow = Node.new()
	food_flow.name = "FoodFlow"
	food_flow.set_script(preload("res://scripts/food_flow.gd"))
	add_child(food_flow)
	show_page(start, false)
	if OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).get('demo') === 'food'"):
		food_flow.call_deferred("open_demo")
	if args.has("--smoke"):
		call_deferred("run_smoke")
	elif args.has("--capture-all"):
		call_deferred("capture_all")
	elif args.has("--capture"):
		call_deferred("capture_current")
	elif args.has("--ai-settings"):
		food_flow.open_capture()
		food_flow.open_settings()
	elif args.has("--food-demo"):
		food_flow.open_demo()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

func instantiate_route(id: String) -> Control:
	if not routes.has(id):
		push_error("Unknown Figma destination: " + id)
		return null
	var scene: PackedScene = load(routes[id].path)
	if scene == null:
		push_error("Missing scene: " + routes[id].path)
		return null
	return scene.instantiate()

func show_page(id: String, remember := true, reset_scroll := false) -> void:
	if not routes.has(id):
		push_error("Unknown page: " + id)
		return
	clear_overlays()
	if remember and not current_id.is_empty() and id != current_id:
		history.append(current_id)
	for page in pages.values():
		page.hide()
	if not pages.has(id):
		var page := instantiate_route(id)
		if page == null:
			return
		$PageHost.add_child(page)
		pages[id] = page
		bind_nodes(page)
		room_studio.attach_page(page, id)
	current_id = id
	pages[id].show()
	if reset_scroll:
		for node in descendants(pages[id]):
			if node is ScrollContainer:
				node.scroll_vertical = 0
	refresh_bindings()
	food_flow.update_page(pages[id], id)
	start_timers(pages[id])
	print("PAGE ", id, " ", routes[id].name)

func open_overlay(id: String, replace := false) -> void:
	if replace and not overlays.is_empty():
		close_overlay()
	var panel := instantiate_route(id)
	if panel == null:
		return
	# All overlays in the source file use CENTER and no extra overlay background.
	panel.position = Vector2((393 - panel.size.x) / 2, maxf(0, (852 - panel.size.y) / 2))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var blocker := Control.new()
	blocker.name = "ModalInputBlocker"
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	$PopupLayer.add_child(blocker)
	blocker.add_child(panel)
	overlays.append(panel)
	# Prevent hidden pages and covered sheets from receiving keyboard focus.
	set_buttons_enabled(pages[current_id], false)
	if overlays.size() > 1:
		set_buttons_enabled(overlays[-2], false)
	bind_nodes(panel)
	food_flow.decorate_overlay(panel, id)
	refresh_bindings()
	start_timers(panel)
	print("OVERLAY ", id, " ", routes[id].name)

func close_overlay() -> void:
	if overlays.is_empty():
		return
	var panel: Control = overlays.pop_back()
	var blocker: Node = panel.get_parent()
	$PopupLayer.remove_child(blocker)
	blocker.queue_free()
	if not overlays.is_empty():
		set_buttons_enabled(overlays[-1], true)
		if overlays[-1].has_method("update_buttons"): overlays[-1].update_buttons()
	elif pages.has(current_id):
		set_buttons_enabled(pages[current_id], true)

func clear_overlays() -> void:
	while not overlays.is_empty():
		close_overlay()

func go_back() -> void:
	if not overlays.is_empty():
		close_overlay()
	elif not history.is_empty():
		show_page(history.pop_back(), false)
	elif current_id != HOME:
		show_page(HOME, false)

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children():
		result.append_array(descendants(child))
	return result

func set_buttons_enabled(root: Node, enabled: bool) -> void:
	for node in descendants(root):
		if node is Button:
			node.disabled = not enabled

func bind_nodes(root: Node) -> void:
	for node in descendants(root):
		if node is Button and node.has_meta("click_actions"):
			node.pressed.connect(func(): on_pressed(node))

func on_pressed(button: Button) -> void:
	if busy:
		return
	if food_flow.intercept(button):
		return
	if room_studio.intercept(button):
		return
	var actions: Array = button.get_meta("click_actions", [])
	# The camera is a mock. Its existing frame remains visible during the short wait.
	var mock_capture := false
	for action in actions:
		if action.get("destinationId", "") == "165:1257":
			mock_capture = true
	if mock_capture and not smoke_mode:
		busy = true
		button.mouse_default_cursor_shape = Control.CURSOR_WAIT
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(button) or not button.is_inside_tree():
			busy = false
			return
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		busy = false
	apply_actions(actions, button.get_parent())

func resolve_value(data: Variant) -> Variant:
	if not data is Dictionary:
		return data
	if data.get("type") == "VARIABLE_ALIAS":
		var alias: Variant = data.get("value", data)
		return values.get(alias.get("id", ""), null)
	if data.get("type") == "EXPRESSION":
		return evaluate_expression(data.value)
	if data.has("expressionFunction"):
		return evaluate_expression(data)
	return data.get("value", data)

func evaluate_expression(expression: Dictionary) -> Variant:
	var args: Array = []
	for value in expression.get("expressionArguments", []):
		args.append(resolve_value(value))
	match expression.get("expressionFunction", ""):
		"EQUALS": return args[0] == args[1]
		"NOT_EQUAL": return args[0] != args[1]
		"ADDITION": return args[0] + args[1]
		"SUBTRACTION": return args[0] - args[1]
		"MULTIPLICATION": return args[0] * args[1]
		"DIVISION": return args[0] / args[1] if args[1] != 0 else 0
		"LESS_THAN": return args[0] < args[1]
		"LESS_THAN_OR_EQUAL": return args[0] <= args[1]
		"GREATER_THAN": return args[0] > args[1]
		"GREATER_THAN_OR_EQUAL": return args[0] >= args[1]
		"AND": return args[0] and args[1]
		"OR": return args[0] or args[1]
		"NOT": return not args[0]
		"NEGATE": return -args[0]
	push_error("Unsupported Figma expression: " + str(expression))
	return null

func apply_actions(actions: Array, source: Node) -> void:
	for action in actions:
		match action.get("type", ""):
			"SET_VARIABLE":
				values[action.variableId] = resolve_value(action.get("variableValue", {}))
			"CONDITIONAL":
				for block in action.conditionalBlocks:
					if not block.has("condition") or resolve_value(block.condition):
						apply_actions(block.actions, source)
						break
			"CLOSE": close_overlay()
			"BACK": go_back()
			"NODE":
				var destination: String = action.get("destinationId", "")
				match action.get("navigation", "NAVIGATE"):
					"NAVIGATE": show_page(destination, true, action.get("resetScrollPosition", false))
					"OVERLAY": open_overlay(destination)
					"SWAP": open_overlay(destination, true)
					"CHANGE_TO": change_component(source, destination)
	refresh_bindings()

func change_component(source: Node, destination: String) -> void:
	if not is_instance_valid(source) or not source.is_inside_tree():
		return
	var target: Node = source
	while target != null and target.get_meta("figma_type", "") not in ["INSTANCE", "COMPONENT"]:
		target = target.get_parent()
	if target == null:
		return
	var replacement := instantiate_route(destination)
	if replacement == null:
		return
	var parent: Node = target.get_parent()
	var index: int = target.get_index()
	replacement.position = target.position
	parent.remove_child(target)
	target.queue_free()
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	bind_nodes(replacement)
	start_timers(replacement)

func refresh_bindings() -> void:
	if room_studio != null:
		room_studio.refresh()
	for node in descendants(self):
		var bindings: Dictionary = node.get_meta("bindings", {})
		if bindings.has("visible"):
			node.visible = bool(values.get(bindings.visible.id, node.visible))
		if node is Label and bindings.has("characters"):
			node.text = str(values.get(bindings.characters.id, node.text))
		if node.has_method("sync_mood"):
			node.sync_mood(values)
	# Category panels and recorded meal cards change visibility in the source prototype.
	# Update scroll extents so newly visible content stays reachable.
	for node in descendants(self):
		if node is ScrollContainer:
			var content: Control = node.get_node_or_null("ScrollContent")
			if content != null:
				var bottom: float = node.size.y
				var right: float = node.size.x
				for child in content.get_children():
					if child is Control and child.visible:
						bottom = maxf(bottom, child.position.y + child.size.y + 12)
						right = maxf(right, child.position.x + child.size.x + 12)
				if node.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
					content.custom_minimum_size.y = bottom
				if node.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
					content.custom_minimum_size.x = right
	for root in pages.values():
		if root.visible:
			start_timers(root)

func start_timers(root: Node) -> void:
	if smoke_mode:
		return
	for node in descendants(root):
		if not node is Control or not node.is_visible_in_tree() or node.has_meta("timer_started"):
			continue
		for reaction in node.get_meta("reactions", []):
			if reaction.trigger.type == "AFTER_TIMEOUT":
				node.set_meta("timer_started", true)
				get_tree().create_timer(reaction.trigger.timeout).timeout.connect(func():
					if is_instance_valid(node) and node.is_inside_tree() and node.is_visible_in_tree():
						apply_actions(reaction.actions, node))

func capture_current() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://qa/screenshots")
	get_viewport().get_texture().get_image().save_png("res://qa/screenshots/" + current_id.replace(":", "_") + ".png")
	get_tree().quit()

func capture_all() -> void:
	DirAccess.make_dir_recursive_absolute("res://qa/screenshots")
	for id in routes:
		if routes[id].component:
			continue
		show_page(id, false)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://qa/screenshots/" + id.replace(":", "_") + ".png")
	print("CAPTURE_ALL_OK")
	get_tree().quit()

func run_smoke() -> void:
	# Load every frame and resolve each authored prototype destination.
	var loaded := 0
	var links := 0
	for id in routes:
		var page := instantiate_route(id)
		assert(page != null, "Scene failed: " + id)
		$PageHost.add_child(page)
		bind_nodes(page)
		for node in descendants(page):
			for reaction in node.get_meta("reactions", []):
				links += validate_destinations(reaction.actions)
		$PageHost.remove_child(page)
		page.queue_free()
		loaded += 1
		await get_tree().process_frame
	show_page(HOME, false)
	print("SMOKE_OK scenes=", loaded, " links=", links)
	get_tree().quit()

func validate_destinations(actions: Array) -> int:
	var count := 0
	for action in actions:
		if action.type == "NODE":
			assert(routes.has(action.destinationId), "Missing destination: " + str(action.destinationId))
			count += 1
		elif action.type == "CONDITIONAL":
			for block in action.conditionalBlocks:
				count += validate_destinations(block.actions)
	return count
