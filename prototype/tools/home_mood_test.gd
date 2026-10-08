extends "res://tools/catalog_regression.gd"
## Click each real Figma choice and compare the home PNG with the chosen sheet PNG.
func run() -> void:
	root.size = Vector2i(393, 852)
	root.content_scale_size = Vector2i(393, 852)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	var badge: TextureRect = find_layer("I165:976;165:2229;98:1958")
	var caption: Label = find_layer("I165:976;165:2242")
	var caption_rect := caption.get_global_rect()
	var slot_rect: Rect2 = badge.get_parent().get_global_rect()
	for id in ["165:2530", "165:2533", "165:2536", "165:2540", "165:2543", "165:2546", "165:2550", "165:2553", "165:2556", "165:2560", "165:2563", "165:2566"]:
		# The image's own existing hit area must still open the sheet.
		if not await click_id("I165:976;165:2229", "165:2525"): return
		var choice: Control
		for node in app.descendants(app.overlays[-1]):
			if node.get_meta("figma_id", "") == id: choice = node
		var expected: TextureRect
		for node in app.descendants(choice):
			if node is TextureRect and node.is_in_group("otter_characters"): expected = node
		var chosen_texture := expected.texture
		var chosen_pose: String = expected.pose_name
		if not await click_id(id, app.HOME): return
		if not check(badge.is_visible_in_tree() and badge.texture == chosen_texture and badge.pose_name == chosen_pose, "home shows exact selected emoji " + chosen_pose): return
		if not check(caption.text == app.values["VariableID:147:16"] and not caption.text.is_empty(), "matching caption " + chosen_pose): return
		if not check(caption.get_global_rect() == caption_rect and badge.get_parent().get_global_rect() == slot_rect, "selection preserves bubble layout " + chosen_pose): return
		if not check(not caption.get_global_rect().intersects(badge.get_parent().get_global_rect()), "emoji and caption do not overlap " + chosen_pose): return
		app.show_page("165:1308")
		app.show_page(app.HOME)
		await settle()
		if not check(badge.is_visible_in_tree() and badge.texture == chosen_texture, "returning home retains emoji " + chosen_pose): return
		if chosen_pose in ["Happy", "Pleasure", "Sleepy"]: await screenshot("home-mood-" + chosen_pose.to_lower())
	if not await click_id("I165:976;165:2241", "165:2525"): return
	app.go_back()
	await settle()
	if not check(badge.pose_name == "Sleepy" and badge.is_visible_in_tree(), "closing sheet without choosing keeps current emoji"): return
	FileAccess.open("res://qa/home-mood-test.json", FileAccess.WRITE).store_string(JSON.stringify({"passed": passed.size(), "checks": passed}, "\t"))
	print("HOME_MOOD_OK checks=", passed.size(), " moods=12")
	quit()
