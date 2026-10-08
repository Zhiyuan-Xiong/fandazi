extends "res://tools/catalog_regression.gd"
## The local fixture service is explicit and isolated; no paid AI is used here.

func finish_request(view: Control) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while view.busy and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	return check(not view.busy, "request completes within test deadline")

func run() -> void:
	root.size = Vector2i(393, 852)
	root.content_scale_size = Vector2i(393, 852)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var flow: Node = app.food_flow
	flow.bridge_override = JSON.parse_string(FileAccess.get_file_as_string("res://qa/food-test-bridge.json"))
	var view: Control = flow.open_capture()
	await settle()
	if not check(view.save_button.disabled and view.analyze_button.disabled, "empty photo cannot be saved or analyzed"): return
	view.import_file(ProjectSettings.globalize_path("res://assets/figma/31d5f64980827f8b93ac.png"))
	if not await finish_request(view): return
	if not check(view.photo != null and view.preview.texture != null and view.meal.is_empty(), "photo loads without fabricated nutrition"): return
	await screenshot("food-photo-imported")
	view.title_input.text = "测试：仅照片记录"
	view.save()
	await settle()
	app.overlays[-1].confirm_record()
	await settle()
	app.close_overlay()
	await settle()
	if not check(app.current_id == "165:1308" and flow.records.size() == 1, "photo-only record appears in real diary"): return
	if not check(flow.records[0].source == "photo_only" and flow.records[0].meal.is_empty(), "missing AI is labelled unestimated rather than zero calories"): return
	await screenshot("food-photo-diary")
	view = flow.open_capture(flow.records[0])
	await settle()
	if not check(view.photo != null and view.title_input.text == "测试：仅照片记录", "saved photo can be reopened"): return
	view.notes.text = "TEST_FAIL"
	view.analyze()
	if not await finish_request(view): return
	if not check(view.meal.is_empty() and view.photo != null and view.status.text.contains("失败"), "AI failure keeps photo and supports retry"): return
	view.notes.text = "TEST_NONFOOD"
	view.analyze()
	if not await finish_request(view): return
	if not check(view.meal.is_empty() and view.status.text.contains("不是食物"), "non-food produces no nutrition or recipe"): return
	view.notes.text = "TEST_SUCCESS"
	view.analyze()
	if not await finish_request(view): return
	if not check(view.meal.items.size() == 1 and view.status.text.contains("测试数据"), "explicit fixture result renders through the real HTTP client"): return
	var initial: Dictionary = flow.totals(view.meal)
	for node in app.descendants(view.result_box):
		if node is SpinBox: node.value = 150
	if not check(is_equal_approx(flow.totals(view.meal).high, initial.high / 2), "portion editing rescales calories and nutrients"): return
	await screenshot("food-recognized-test-fixture")
	for node in view.get_children():
		if node is ScrollContainer: node.scroll_vertical = 10000
	await settle()
	await screenshot("food-recipe-test-fixture")
	view.generate_sticker()
	if not await finish_request(view): return
	if not check(view.sticker != null and view.preview.texture.get_width() == view.sticker.get_width(), "generated PNG is decoded and displayed"): return
	if not check(flow.save_view(view, true), "recipe and sticker save successfully"): return
	await settle()
	if not check(app.current_id == "165:1510" and flow.records.size() == 1 and flow.records[0].planned, "updating the record adds recipe to plan without duplicates"): return
	var record: Dictionary = flow.records[0].duplicate(true)
	flow.records.clear()
	flow.load_records()
	if not check(flow.records.size() == 1 and FileAccess.file_exists(record.photo) and FileAccess.file_exists(record.sticker), "record, original and sticker survive reload"): return
	if not check(Image.load_from_file(record.sticker).detect_alpha() != Image.ALPHA_NONE, "saved PNG retains actual transparency"): return
	if not await click_id("165:1526", "food-photo"): return
	view = app.overlays[-1]
	if not check(view.meal.recipe.steps.size() == 2 and view.meal.items[0].selected_g == 150, "plan opens saved recipe and corrected portion"): return
	flow.open_settings()
	await settle()
	if not check(app.overlays[-1].secret.secret, "API input is masked"): return
	app.close_overlay()
	await settle()
	if not check(not view.busy and not view.analyze_button.disabled, "return from settings keeps current meal usable"): return
	# A failed import must not destroy the current result.
	view.import_file(ProjectSettings.globalize_path("res://project.godot"))
	if not check(view.photo != null and not view.meal.is_empty(), "invalid file preserves existing record"): return
	view.import_file(ProjectSettings.globalize_path("res://assets/figma/6a0daa7d40fc9a0cb079.png"))
	if not await finish_request(view): return
	if not check(view.meal.is_empty() and view.sticker == null and view.record.is_empty(), "different photo clears stale recognition and generated artwork"): return
	app.close_overlay()
	app.show_page("165:1308")
	await settle()
	if not check(app.pages["165:1308"].find_children("PhotoRecords", "", true, false).size() == 1, "repeated diary visits never duplicate the record list"): return
	FileAccess.open("res://qa/food-flow-test.json", FileAccess.WRITE).store_string(JSON.stringify({"passed": passed.size(), "checks": passed, "live_ai": false}, "\t"))
	print("FOOD_FLOW_OK checks=", passed.size(), " live_ai=false")
	quit()
