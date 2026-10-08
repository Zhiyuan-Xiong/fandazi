extends "res://tools/walkthrough.gd"
## Regression for dragging over tabs and hidden Figma wrap layouts.

func drag_pointer(from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = from
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down)
	for step in range(1, 9):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, step / 8.0)
		motion.relative = (to - from) / 8.0
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion)
		await process_frame
	var up := InputEventMouseButton.new()
	up.position = to
	up.button_index = MOUSE_BUTTON_LEFT
	root.push_input(up)
	await settle()

func screenshot(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/screenshots/" + label + ".png")

func run() -> void:
	root.size = Vector2i(393, 852)
	root.content_scale_size = Vector2i(393, 852)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.show_page("199:2313")
	await settle()
	var tabs: ScrollContainer = find_layer("202:2390")
	await drag_pointer(Vector2(330, 212), Vector2(160, 212))
	if not check(tabs.scroll_horizontal >= 103, "drag on a category button reveals the last tab"): return
	if not check(app.values.get("VariableID:201:2"), "drag does not accidentally select another category"): return
	if not check(tabs.get_global_rect().encloses(find_layer("202:2427").get_global_rect()), "wall category is fully reachable after dragging"): return
	if not await click_id("202:2428", "199:2313"): return
	await drag_pointer(Vector2(70, 212), Vector2(250, 212))
	if not check(tabs.scroll_horizontal == 0, "reverse drag returns to the first category"): return
	var total := 0
	for group in [["202:2393", "202:2434", 6], ["202:2400", "202:2435", 8], ["202:2407", "202:2436", 8], ["202:2414", "202:2437", 2], ["202:2421", "202:2438", 2], ["202:2428", "202:2439", 6]]:
		var normal: Control = find_layer(group[0])
		var normal_label: Label
		for child in normal.get_children():
			if child is Label: normal_label = child
		if not await click_id(group[0], "199:2313"): return
		var active_label: Label
		for sibling in normal.get_parent().get_children():
			if sibling.get_meta("figma_name", "").begins_with("Active / "):
				for child in sibling.get_children():
					if child is Label: active_label = child
		if not check(active_label != null and active_label.is_visible_in_tree() and active_label.get_global_rect().is_equal_approx(normal_label.get_global_rect()), "category label does not move when clicked " + group[0]): return
		var grid: Control = find_layer(group[1])
		if not check(grid is GridContainer and grid.is_visible_in_tree() and grid.position.y == 0, "category starts in the existing card slot " + group[1]): return
		var cards := grid.get_children()
		if not check(cards.size() == group[2], "expected card count " + group[1]): return
		for i in cards.size():
			var card: Control = cards[i]
			if not check(card.is_visible_in_tree() and grid.get_global_rect().encloses(card.get_global_rect()), "card in category bounds " + str(card.get_meta("figma_id"))): return
			if not check(app.descendants(card).any(func(n): return n is TextureRect and n.is_visible_in_tree() and n.texture != null), "card artwork present " + str(card.get_meta("figma_id"))): return
			for j in range(i):
				if not check(not card.get_global_rect().intersects(cards[j].get_global_rect()), "cards do not overlap " + str(i) + "/" + str(j)): return
			total += 1
		await screenshot("catalog-" + group[1].replace(":", "_"))
	if not check(total == 32, "all 32 furniture cards are displayed across six categories"): return
	# Card taps still work after a drag; keep the original frozen-detail route.
	if not await click_id("202:2585", "199:2314"): return
	app.go_back()
	await settle()
	if not check(app.current_id == "199:2313", "furniture details return to catalog"): return
	# These two pages share the same initially hidden Active button components.
	for page in ["165:1138", "199:2315"]:
		app.show_page(page)
		await settle()
		for node in app.descendants(app.pages[app.current_id]):
			if node is Control and node.get_meta("figma_name", "").begins_with("Category / "):
				var normal: Control = node.get_child(0)
				var active: Control = node.get_child(1)
				if not await click_id(normal.get_meta("figma_id"), page): return
				var first: Label
				var second: Label
				for child in normal.get_children():
					if child is Label: first = child
				for child in active.get_children():
					if child is Label: second = child
				if not check(first != null and second != null and second.is_visible_in_tree() and first.get_global_rect().is_equal_approx(second.get_global_rect()), "decor label does not move when clicked " + str(normal.get_meta("figma_id"))): return
	app.show_page("165:1669")
	await settle()
	var content: ScrollContainer
	for node in app.descendants(app.pages[app.current_id]):
		if node is ScrollContainer and node.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			content = node
			break
	await drag_pointer(Vector2(140, 560), Vector2(140, 280))
	if not check(content != null and content.scroll_vertical > 0, "vertical drag over content scrolls the health page"): return
	if not check(app.overlays.is_empty() and app.current_id == "165:1669", "vertical drag does not activate the card beneath it"): return
	var report := {"passed": passed.size(), "furniture_cards": total, "checks": passed}
	FileAccess.open("res://qa/catalog-regression.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("CATALOG_REGRESSION_OK checks=", passed.size(), " furniture=", total)
	quit()
