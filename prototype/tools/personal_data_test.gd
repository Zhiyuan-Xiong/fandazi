extends "res://tools/catalog_regression.gd"
## Isolated UI test: synthetic nutrition never enters the user's diary or calls AI.

func tap_control(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.position = at
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down)
	var up := InputEventMouseButton.new()
	up.position = at
	up.button_index = MOUSE_BUTTON_LEFT
	root.push_input(up)
	await settle()

func run() -> void:
	root.size = Vector2i(393, 852)
	root.content_scale_size = Vector2i(393, 852)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var flow: Node = app.food_flow
	app.show_page("165:1669")
	await settle()
	var entry: Array = app.pages["165:1669"].find_children("PersonalDataEntry", "", true, false)
	if not check(entry.size() == 1, "health page exposes personal dietary data"): return
	await tap_control(entry[0])
	await settle()
	if not check(app.overlays[-1].mode == "personal" and flow.personal_summary().count == 0, "personal data opens with honest empty state"): return
	await screenshot("personal-empty")
	flow.open_demo()
	await settle()
	var demo_view: Control = app.overlays[-1]
	if not check(demo_view.is_demo and demo_view.analyze_button.disabled and demo_view.sticker_button.disabled, "free demo cannot call paid AI"): return
	var example: Dictionary = demo_view.meal.duplicate(true)
	await tap_control(demo_view.save_button)
	await settle()
	if not check(flow.demo_records.is_empty() and flow.records.is_empty(), "review never persists before confirmation"): return
	await tap_control(app.overlays[-1].get_node("PrimaryAction"))
	await settle()
	if not check(flow.demo_records.size() == 1 and flow.records.is_empty(), "demo records stay separate from personal records"): return
	if not check(flow.personal_summary(1, true).estimated == 1 and flow.personal_summary().estimated == 0, "demo totals never affect real totals"): return
	var view: Control = flow.open_capture()
	view.import_file(ProjectSettings.globalize_path("res://assets/figma/31d5f64980827f8b93ac.png"))
	var deadline := Time.get_ticks_msec() + 15000
	while view.busy and Time.get_ticks_msec() < deadline: await process_frame
	if not check(not view.busy and view.photo != null, "photo import completes locally"): return
	view.meal = example
	view.title_input.text = "隔离测试 · 早餐面条"
	view.status.text = "测试数据 · 未调用 AI"
	view.meal_type.selected = 0
	view.meal.items[0].selected_g = 150
	view.render_meal()
	view.update_buttons()
	await tap_control(view.save_button)
	await settle()
	if not check(flow.records.is_empty(), "recognized nutrients wait for explicit confirmation"): return
	await screenshot("personal-review")
	app.close_overlay()
	await settle()
	if not check(view.meal.items[0].selected_g == 150 and not view.save_button.disabled, "back to edit preserves portion and controls"): return
	await tap_control(view.save_button)
	await settle()
	await tap_control(app.overlays[-1].get_node("PrimaryAction"))
	await settle()
	if not check(flow.records.size() == 1 and app.overlays[-1].mode == "receipt", "confirmation persists one record and shows receipt"): return
	await screenshot("personal-saved")
	var summary: Dictionary = flow.personal_summary()
	if not check(summary.count == 1 and summary.estimated == 1 and summary.totals.high == 250, "personal nutrition uses corrected portions"): return
	if not check(flow.records[0].meal_type == "早餐", "meal type persists with record"): return
	flow.open_personal()
	await settle()
	await screenshot("personal-data-today")
	view = flow.open_capture(flow.records[0])
	view.meal.items[0].selected_g = 300
	if not check(flow.save_view(view), "edited record saves"): return
	if not check(flow.records.size() == 1 and flow.personal_summary().totals.high == 500, "editing replaces rather than double counts nutrients"): return
	view = flow.open_capture()
	view.photo = load("res://assets/figma/31d5f64980827f8b93ac.png").get_image()
	view.title_input.text = "隔离测试 · 未识别照片"
	if not check(flow.save_view(view), "photo-only personal record saves"): return
	summary = flow.personal_summary()
	if not check(summary.count == 2 and summary.unestimated == 1 and summary.totals.high == 500, "unknown nutrition is counted separately from totals"): return
	var old: Dictionary = flow.records[1].duplicate(true)
	old.id = "older_test_record"
	var midnight := Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system() + "T00:00:00")
	old.created = Time.get_datetime_string_from_unix_time(midnight - 86400 + 43200)
	flow.records.append(old)
	if not check(flow.personal_summary().count == 2 and flow.personal_summary(7).count == 3, "today and seven-day summaries filter calendar dates"): return
	flow.write_records(flow.records)
	flow.records.clear()
	flow.load_records()
	if not check(flow.personal_summary(7).totals.high == 1000 and flow.records.size() == 3, "personal totals rebuild correctly after reload"): return
	flow.open_personal()
	app.overlays[-1].days = 7
	app.overlays[-1].render_personal()
	await settle()
	await screenshot("personal-data-week")
	app.show_page("165:2391")
	await settle()
	if not check(app.pages["165:2391"].find_children("PersonalDataEntry", "", true, false).size() == 1, "profile exposes personal data"): return
	app.show_page("165:1669")
	app.show_page("165:1669")
	await settle()
	if not check(app.pages["165:1669"].find_children("PersonalDataEntry", "", true, false).size() == 1, "revisiting health never stacks extra entries"): return
	await screenshot("personal-health-entry")
	FileAccess.open("res://qa/personal-data-test.json", FileAccess.WRITE).store_string(JSON.stringify({"passed": passed.size(), "checks": passed, "live_ai": false}, "\t"))
	print("PERSONAL_DATA_OK checks=", passed.size(), " live_ai=false")
	quit()
