extends "res://tools/catalog_regression.gd"
## Check every exported character, then exercise taps, scrolling and modal isolation.

func labels_in(scope: Node) -> Dictionary:
	var result := {}
	for node in app.descendants(scope):
		if node is Label:
			result[node.get_path()] = [node.position, node.size, node.scale, node.rotation]
	return result

func run() -> void:
	root.size = Vector2i(393, 852)
	root.content_scale_size = Vector2i(393, 852)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	var count := 0
	var poses := {}
	for id in app.routes:
		var page: Control = app.instantiate_route(id)
		app.get_node("PageHost").add_child(page)
		var page_labels := labels_in(page)
		for node in app.descendants(page):
			if not node is TextureRect or not node.get_meta("figma_name", "").begins_with("OTTER_"):
				continue
			if not check(node.has_method("react") and node.motion_enabled, "animation attached " + str(node.get_meta("figma_id"))): return
			var initial_size: Vector2 = node.size
			var initial_parent_position: Vector2 = node.get_parent().position
			# Exercise hidden mood variants too without changing application variables.
			node.elapsed = 0.9
			node.apply_pose()
			var first: Transform2D = node.get_transform()
			node.elapsed = 1.7
			node.apply_pose()
			if not check(not first.is_equal_approx(node.get_transform()), "idle motion varies " + node.pose_name): return
			if not check(node.size.is_equal_approx(initial_size) and node.get_parent().position.is_equal_approx(initial_parent_position), "motion preserves layout " + str(node.get_meta("figma_id"))): return
			for t in [0.0, 0.2, 0.4, 0.6, 0.8]:
				node.reaction_time = t
				node.apply_pose()
				if not check(node.position.distance_to(node.base_position) < 11.0 and absf(node.rotation - node.base_rotation) < 0.075 and absf(node.scale.y - node.base_scale.y) < 0.05, "bounded tap response " + node.pose_name + " / " + str(t)): return
			node.reset_pose()
			poses[node.pose_name] = true
			count += 1
		if not check(labels_in(page) == page_labels, "all labels stay fixed " + id): return
		page.queue_free()
		await settle()
	if not check(count == 64 and poses.size() == 17, "all 64 otters and 17 poses have motion"): return
	var home: Control = app.pages[app.HOME]
	var character := find_layer("I165:976;167:855;98:1910")
	var labels_before := labels_in(home)
	var pose_before: Transform2D = character.get_transform()
	await create_timer(0.25).timeout
	if not check(not character.get_transform().is_equal_approx(pose_before), "visible home otter animates during real frames"): return
	var point := character.get_global_rect().get_center()
	await drag_pointer(point, point)
	if not check(character.reaction_time >= 0.0 and app.current_id == app.HOME and app.overlays.is_empty(), "tap reacts without changing the home route"): return
	await create_timer(0.9).timeout
	if not check(character.reaction_time == -1.0, "tap response completes and returns to idle"): return
	if not check(labels_before == labels_in(home), "tap does not move any home text"): return
	app.show_page("165:1510")
	await settle()
	if not check(not character.is_processing() and character.position == character.base_position and character.scale == character.base_scale, "hidden page pauses and resets its otter"): return
	app.show_page(app.HOME)
	await settle()
	if not check(character.is_processing(), "returning home resumes idle motion"): return
	character.reaction_time = -1.0
	point = character.get_global_rect().get_center()
	await drag_pointer(point, point + Vector2(0, -90))
	if not check(character.reaction_time == -1.0, "drag gesture does not trigger an otter tap"): return
	app.show_page(app.HOME, false, true)
	await settle()
	if not await click_id("I165:976;165:2241", "165:2525"): return
	if not check(app.otter_at(character.get_global_rect().get_center()) != character, "modal blocks taps to the home otter underneath"): return
	var mood_actors: Array = app.descendants(app.overlays[-1]).filter(func(n): return n.is_in_group("otter_characters"))
	if not check(mood_actors.size() == 12 and mood_actors.all(func(n): return n.is_processing()), "all twelve mood choices animate"): return
	if not await click_id("165:2530", "165:958"): return
	if not check(app.values.get("VariableID:147:4", false), "animated mood choice keeps its Figma action"): return
	app.show_page("165:1833")
	await settle()
	var shared: Array = app.descendants(app.pages[app.current_id]).filter(func(n): return n.is_in_group("otter_characters") and n.is_visible_in_tree())
	if not check(shared.size() >= 2 and shared[0].phase != shared[1].phase, "shared-room characters have individual timing"): return
	FileAccess.open("res://qa/otter-motion.json", FileAccess.WRITE).store_string(JSON.stringify({"passed":passed.size(),"characters":count,"poses":poses.keys(),"checks":passed}, "  "))
	print("OTTER_MOTION_OK checks=", passed.size(), " characters=", count, " poses=", poses.size())
	quit()
