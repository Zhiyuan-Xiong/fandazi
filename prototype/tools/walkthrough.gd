extends SceneTree
## Exercises real Godot GUI input, including clipping and modal hit testing.
var app: Control
var passed: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	await process_frame
	await process_frame

func top_id() -> String:
	return app.current_id if app.overlays.is_empty() else app.overlays[-1].get_meta("figma_id")

func check(condition: bool, label: String) -> bool:
	if not condition:
		push_error("WALKTHROUGH_FAIL " + label + " at " + top_id())
		quit(1)
		return false
	passed.append(label)
	return true

func click_id(id: String, expected: String) -> bool:
	var scope: Node = app.pages[app.current_id] if app.overlays.is_empty() else app.overlays[-1]
	var found: Button = null
	for n in app.descendants(scope):
		if n is Button and n.get_meta("source_id", "") == id and n.is_visible_in_tree() and not n.disabled:
			found = n
			break
	if not check(found != null, "button available " + id):
		return false
	var parent: Node = found.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(found)
		parent = parent.get_parent()
	await settle()
	var at := found.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	var down := InputEventMouseButton.new()
	down.position = at
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down)
	var up := InputEventMouseButton.new()
	up.position = at
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	root.push_input(up)
	await settle()
	return check(top_id() == expected, id + " -> " + expected)

func tab(label: String, expected: String) -> bool:
	for n in app.descendants(app.pages[app.current_id]):
		if n is Button and n.is_visible_in_tree() and n.get_parent().get_meta("figma_name", "") == label:
			return await click_id(n.get_meta("source_id"), expected)
	return check(false, "tab missing " + label)

func find_layer(id: String) -> Control:
	for node in app.descendants(app.pages[app.current_id]):
		if node.get_meta("figma_id", "") == id:
			return node
	return null

func run() -> void:
	root.size = Vector2i(393, 852)
	root.content_scale_size = Vector2i(393, 852)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	for _cycle in range(2):
		if not await tab("Tab / 日记", "165:1308"): return
		if not await tab("Tab / 计划", "165:1510"): return
		if not await tab("Tab / 健康指数", "165:1669"): return
		if not await tab("Tab / 食宠", "165:958"): return
		if not check(app.get_node("PageHost").get_children().filter(func(p): return p.visible).size() == 1, "one visible page"): return
	for step in [
		["165:1003", "165:1223"], ["165:1237", "165:958"],
		["165:1003", "165:1223"], ["165:1234", "165:1242"],
		["165:1254", "165:1257"], ["165:1279", "165:1285"],
		["165:1304", "165:1257"], ["165:1280", "165:2456"],
		["165:2461", "165:1257"], ["165:1280", "165:2456"], ["165:2464", "165:1257"],
		["165:1282", "165:2484"], ["165:2503", "165:2504"],
		["165:2523", "165:958"]
	]:
		if not await click_id(step[0], step[1]): return
	if not check(app.overlays.is_empty(), "recording closes all overlays"): return
	if not await tab("Tab / 日记", "165:1308"): return
	var saved_card: Control = null
	for n in app.descendants(app.pages[app.current_id]):
		if n.get_meta("figma_id", "") == "165:1338": saved_card = n
	if not check(saved_card != null and saved_card.is_visible_in_tree() and saved_card.get_child_count() >= 3, "saved lunch content is present"): return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/screenshots/diary-recorded.png")
	if not await tab("Tab / 食宠", "165:958"): return
	# A second record uses the existing mock result, then cancellation restores home.
	if not await click_id("165:1003", "165:1223"): return
	# Real album imports have their own integration suite; this branch is the labelled example camera.
	if not await click_id("165:1234", "165:1242"): return
	if not await click_id("165:1254", "165:1257"): return
	if not await click_id("I165:1261;28:79", "165:958"): return
	# Enter the room via its source prototype route; exercise daily reward and save.
	var room_button := ""
	for n in app.descendants(app.pages[app.current_id]):
		if n is Button and n.is_visible_in_tree():
			for action in n.get_meta("click_actions", []):
				if action.get("destinationId") == "165:1083": room_button = n.get_meta("source_id")
	if not await click_id(room_button, "165:1083"): return
	if not await click_id("204:947", "199:2311"): return
	if not await click_id("200:2271", "199:2312"): return
	app.go_back()
	await settle()
	app.go_back()
	await settle()
	if not await click_id("165:1135", "165:1138"): return
	if not await click_id("202:2666", "165:1138"): return
	var rest_panel := find_layer("202:2769")
	if not check(rest_panel != null and rest_panel.is_visible_in_tree() and app.descendants(rest_panel).filter(func(n): return n is TextureRect).size() >= 6, "rest furniture category contains its exported images"): return
	if not await click_id("202:2673", "165:1138"): return
	var kitchen_panel := find_layer("202:2802")
	if not check(kitchen_panel is ScrollContainer and kitchen_panel.is_visible_in_tree() and kitchen_panel.get_node("ScrollContent").get_combined_minimum_size().x > kitchen_panel.size.x and kitchen_panel.position.y == 0, "kitchen furniture row is in view and can scroll horizontally"): return
	kitchen_panel.scroll_horizontal = 260
	await settle()
	if not check(kitchen_panel.scroll_horizontal > 0, "kitchen furniture horizontal scroll moves to later cards"): return
	for n in app.descendants(app.pages[app.current_id]):
		if n is Button and n.is_visible_in_tree() and n.get_parent().get_meta("figma_name", "") == "客厅":
			if not await click_id(n.get_meta("source_id"), "165:1138"): return
			break
	# Save action is sourced directly from the design, with its existing variable updates.
	var save_id := ""
	for n in app.descendants(app.pages[app.current_id]):
		if n is Button and n.is_visible_in_tree():
			for action in n.get_meta("click_actions", []):
				if action.get("destinationId") == "199:2316": save_id = n.get_meta("source_id")
	if not await click_id(save_id, "199:2316"): return
	if not await click_id("200:2361", "165:1083"): return
	if not await click_id("I165:1087;28:82", "165:958"): return
	if not await click_id("I165:976;165:2241", "165:2525"): return
	if not await click_id("165:2530", "165:958"): return
	if not check(app.values.get("VariableID:147:4", false), "happy mood retained after closing sheet"): return
	if not await click_id("I165:964;165:2173", "165:1833"): return
	if not await click_id("165:1899", "165:2571"): return
	if not await click_id("165:2578", "165:1833"): return
	if not check(app.values.get("VariableID:147:18", false), "mock meal sharing retained locally"): return
	var report := {"passed": passed.size(), "checks": passed, "final_page": top_id(), "overlay_count": app.overlays.size()}
	var out := FileAccess.open("res://qa/walkthrough.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "  "))
	print("WALKTHROUGH_OK checks=", passed.size())
	quit()
