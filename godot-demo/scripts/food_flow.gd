extends Node
## Real photo records are separate from the retained, clearly labelled Figma examples.
const VIEW = preload("res://scripts/food_view.gd")
const SETTINGS_VIEW = preload("res://scripts/ai_settings.gd")
const SUMMARY_VIEW = preload("res://scripts/food_summary.gd")
const UI = preload("res://scripts/room_studio.gd")
var app: Control
var records: Array = []
var demo_records: Array = []
var last_saved: Dictionary = {}
var store_dir := "user://food_diary"
var bridge_override: Dictionary = {}

func _ready() -> void:
	app = get_parent()
	if OS.get_cmdline_user_args().has("--interaction-test"):
		store_dir = "user://food_test_" + str(OS.get_process_id())
	load_records()

func load_records() -> void:
	var path := store_dir.path_join("records.json")
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Array: records = data

func bridge() -> Dictionary:
	# The public browser demo never connects to a visitor's local AI service.
	if OS.has_feature("web"): return {}
	if not bridge_override.is_empty(): return bridge_override
	var path := OS.get_environment("LOCALAPPDATA").path_join("FanDaziAI/bridge.json")
	if not FileAccess.file_exists(path): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.has("port") and data.has("token"): return data
	return {}

func request_api(owner: Node, path: String, payload: Dictionary, callback: Callable) -> void:
	if OS.has_feature("web"):
		callback.call(false, {"error": "网页版仅演示本地交互；AI 服务请在桌面工程中自行配置。"})
		return
	var connection := bridge()
	if connection.is_empty():
		callback.call(false, {"error": "本机 AI 服务未启动。请使用「启动饭搭子.cmd」重新打开；照片仍可本地保存。"})
		return
	var request := HTTPRequest.new()
	request.timeout = 330.0 if path == "/sticker" else 190.0 if path == "/analyze" else 15.0
	request.body_size_limit = 32 * 1024 * 1024
	owner.add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		request.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			callback.call(false, {"error": "连接中断或等待超时。照片和已完成的结果仍然保留，可以重试。"})
			return
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not data is Dictionary:
			callback.call(false, {"error": "服务返回了无法读取的结果。"})
			return
		callback.call(code == 200, data))
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + str(connection.token)])
	var method := HTTPClient.METHOD_GET if path == "/health" else HTTPClient.METHOD_POST
	var error := request.request("http://127.0.0.1:%d%s" % [int(connection.port), path], headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload))
	if error != OK:
		request.queue_free()
		callback.call(false, {"error": "无法连接本机 AI 服务，请重新启动饭搭子。"})

func show_custom(panel: Control) -> void:
	var blocker := Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	app.get_node("PopupLayer").add_child(blocker)
	blocker.add_child(panel)
	if app.overlays.is_empty(): app.set_buttons_enabled(app.pages[app.current_id], false)
	else: app.set_buttons_enabled(app.overlays[-1], false)
	app.overlays.append(panel)

func open_capture(record: Dictionary = {}) -> Control:
	app.clear_overlays()
	var panel := Control.new()
	panel.set_script(VIEW)
	panel.flow = self
	panel.record = record.duplicate(true)
	panel.is_demo = record.get("source", "") == "demo"
	panel.set_meta("figma_id", "food-photo")
	show_custom(panel)
	return panel

func summary_panel(mode: String) -> Control:
	var panel := Control.new()
	panel.set_script(SUMMARY_VIEW)
	panel.flow = self
	panel.mode = mode
	panel.set_meta("figma_id", "food-" + mode)
	return panel

func open_review(editor: Control, planned := false) -> void:
	var panel := summary_panel("review")
	panel.editor = editor
	panel.planned = planned
	show_custom(panel)

func open_receipt(record: Dictionary, planned := false) -> void:
	app.clear_overlays()
	var panel := summary_panel("receipt")
	panel.saved = record.duplicate(true)
	panel.planned = planned
	show_custom(panel)

func open_personal(demo := false) -> void:
	app.clear_overlays()
	var panel := summary_panel("personal")
	panel.demo = demo
	show_custom(panel)

func open_demo() -> void:
	var view := open_capture()
	view.is_demo = true
	view.photo = load("res://assets/figma/31d5f64980827f8b93ac.png").get_image()
	view.title_input.text = "示例 · 番茄鸡蛋面"
	view.meal = {"is_food": true, "items": [{"name": "番茄鸡蛋面（示例）", "portion_g": 300.0, "kcal_low": 350.0, "kcal_high": 500.0, "protein_g": 20.0, "carbs_g": 60.0, "fat_g": 12.0, "confidence": "low"}], "assumptions": ["这组数值仅用于演示交互，不来自照片识别。"], "recipe": {"title": "", "minutes": 0, "ingredients": [], "steps": []}}
	view.show_image(view.photo)
	view.status.text = "免费示例 · 可调整份量并体验存入流程，不会上传或计入真实记录。"
	view.render_meal()
	view.update_buttons()

func personal_summary(days := 1, demo := false) -> Dictionary:
	var today := Time.get_date_string_from_system()
	var start := Time.get_unix_time_from_datetime_string(today + "T00:00:00") - (days - 1) * 86400
	var finish := Time.get_unix_time_from_datetime_string(today + "T00:00:00") + 86400
	var result := {"count": 0, "estimated": 0, "unestimated": 0, "totals": totals({}), "records": []}
	for record in (demo_records if demo else records):
		if not demo and record.get("source", "") == "demo": continue
		var date := str(record.get("created", "")).left(10)
		if date.length() != 10: continue
		var stamp := Time.get_unix_time_from_datetime_string(date + "T00:00:00")
		if stamp < start or stamp >= finish: continue
		result.records.append(record)
		result.count += 1
		if record.get("meal", {}).is_empty(): result.unestimated += 1
		else:
			result.estimated += 1
			var nutrients := totals(record.meal)
			for key in nutrients: result.totals[key] += nutrients[key]
	return result

func open_settings() -> void:
	if OS.has_feature("web"):
		var notice := Control.new()
		notice.size = Vector2(393, 852)
		var background := ColorRect.new()
		background.color = Color("faf8ee")
		background.size = notice.size
		notice.add_child(background)
		var message := VIEW.label("浏览器交互演示\n\n本版本不接入 AI 服务、不收集密钥。可以体验示例核对流程，或导入自己的照片并保存在此浏览器。\n\n清除网站数据会删除本地记录；请勿将它作为重要数据的唯一副本。", 18)
		message.position = Vector2(24, 100)
		message.size = Vector2(345, 450)
		notice.add_child(message)
		var close := UI.make_button("返回", func(): app.close_overlay())
		close.position = Vector2(24, 34)
		close.size = Vector2(100, 44)
		notice.add_child(close)
		show_custom(notice)
		return
	var panel := Control.new()
	panel.set_script(SETTINGS_VIEW)
	panel.flow = self
	panel.set_meta("figma_id", "ai-settings")
	show_custom(panel)

func intercept(button: Button) -> bool:
	var id: String = button.get_meta("source_id", "")
	if id in ["165:1235", "165:1252"]:
		var panel := open_capture()
		panel.call_deferred("choose_photo")
		return true
	if id == "165:1526":
		for item in records:
			if item.get("planned", false):
				open_capture(item)
				return true
	return false

func write_records(data: Array) -> bool:
	if DirAccess.make_dir_recursive_absolute(store_dir) != OK: return false
	var temporary := store_dir.path_join("records.tmp")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(temporary, store_dir.path_join("records.json")) == OK

func save_view(view: Control, planned := false) -> bool:
	if view.photo == null: return false
	if view.is_demo:
		last_saved = {"id": view.record.get("id", "demo_" + str(randi())), "title": view.title_input.text, "created": view.record.get("created", Time.get_datetime_string_from_system()), "meal_type": view.meal_type.get_item_text(view.meal_type.selected), "meal": view.meal.duplicate(true), "photo": "res://assets/figma/31d5f64980827f8b93ac.png", "sticker": "", "notes": view.notes.text, "source": "demo", "planned": false}
		demo_records = demo_records.filter(func(item): return item.id != last_saved.id)
		demo_records.push_front(last_saved.duplicate(true))
		app.clear_overlays()
		return true
	var id: String = view.record.get("id", "%d_%d" % [Time.get_unix_time_from_system(), randi()])
	var folder := store_dir.path_join(id)
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return false
	var photo_path := folder.path_join("photo.jpg")
	if view.photo.save_jpg(photo_path, 0.92) != OK: return false
	var sticker_path := ""
	if view.sticker != null:
		sticker_path = folder.path_join("sticker.png")
		if view.sticker.save_png(sticker_path) != OK: return false
	var saved := {"id": id, "title": view.title_input.text.strip_edges(),
		"meal_type": view.meal_type.get_item_text(view.meal_type.selected),
		"created": view.record.get("created", Time.get_datetime_string_from_system()),
		"photo": photo_path, "sticker": sticker_path, "notes": view.notes.text,
		"meal": view.meal.duplicate(true), "planned": planned or view.record.get("planned", false),
		"source": "ai_photo_estimate" if not view.meal.is_empty() else "photo_only"}
	if saved.title.is_empty(): saved.title = "我的一餐"
	var updated := records.filter(func(item): return item.id != id)
	updated.push_front(saved)
	if not write_records(updated): return false
	records = updated
	last_saved = saved.duplicate(true)
	view.record = saved
	app.show_page("165:1510" if planned else "165:1308")
	return true

static func totals(meal: Dictionary) -> Dictionary:
	var total := {"low": 0.0, "high": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0}
	for item in meal.get("items", []):
		var ratio := float(item.get("selected_g", item.portion_g)) / maxf(1.0, float(item.portion_g))
		total.low += float(item.kcal_low) * ratio
		total.high += float(item.kcal_high) * ratio
		total.protein += float(item.protein_g) * ratio
		total.carbs += float(item.carbs_g) * ratio
		total.fat += float(item.fat_g) * ratio
	return total

func update_page(page: Control, id: String) -> void:
	if id == "165:2391":
		for node in app.descendants(page):
			if node.get_meta("figma_id", "") == "165:2409": node.text = "记录保存在本机 · 仅使用 AI 时发送照片"
	if id in ["165:1669", "165:2391"]:
		var content_id := "165:1674" if id == "165:1669" else "165:2396"
		for node in app.descendants(page):
			if node.get_meta("figma_id", "") != content_id: continue
			var content: Control = node.get_node("ScrollContent")
			if content.has_node("PersonalDataEntry"): break
			for child in content.get_children(): child.position.y += 64
			content.custom_minimum_size.y += 64
			var entry := UI.make_button("我的饮食数据 · 查看已保存的餐食 ›", func(): open_personal(), true)
			entry.name = "PersonalDataEntry"
			entry.position = Vector2(24, 8)
			entry.size = Vector2(345, 44)
			content.add_child(entry)
			break
	# Real records use the existing diary header, scroll area and bottom navigation.
	if id == "165:1308" and not records.is_empty():
		var content: Control
		for node in app.descendants(page):
			if node.get_meta("figma_id", "") == "165:1313": content = node.get_node("ScrollContent")
		if content == null: return
		if not content.has_node("ExampleDiary"):
			var original := Control.new()
			original.name = "ExampleDiary"
			for child in content.get_children():
				content.remove_child(child)
				original.add_child(child)
			content.add_child(original)
			original.hide()
		var previous := content.get_node_or_null("PhotoRecords")
		if previous != null:
			content.remove_child(previous)
			previous.queue_free()
		var list := VBoxContainer.new()
		list.name = "PhotoRecords"
		list.position = Vector2(24, 8)
		list.size.x = 345
		list.add_theme_constant_override("separation", 12)
		content.add_child(list)
		list.add_child(VIEW.label("我的照片日记", 23))
		list.add_child(VIEW.label("%d 餐真实记录 · 照片与贴纸保存在本机" % records.size(), 12))
		list.add_child(UI.make_button("我的饮食数据 ›", func(): open_personal(), true))
		for item in records:
			var button := UI.make_button("", func(): open_capture(item))
			button.custom_minimum_size = Vector2(345, 116)
			list.add_child(button)
			var texture := TextureRect.new()
			texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture.position = Vector2(10, 12)
			texture.size = Vector2(86, 90)
			texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var image := Image.load_from_file(item.sticker if not str(item.sticker).is_empty() else item.photo)
			if image != null: texture.texture = ImageTexture.create_from_image(image)
			button.add_child(texture)
			var text := VBoxContainer.new()
			text.position = Vector2(108, 14)
			text.size = Vector2(221, 88)
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(text)
			var name_label := VIEW.label(item.title, 16)
			name_label.max_lines_visible = 2
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			text.add_child(name_label)
			text.add_child(VIEW.label(str(item.created).replace("T", " ").left(16), 11))
			var nutrition := "照片记录 · 尚未估算热量"
			if not item.meal.is_empty():
				var total := totals(item.meal)
				nutrition = "预估 %d–%d kcal" % [roundi(total.low), roundi(total.high)]
			text.add_child(VIEW.label(nutrition, 12))
		list.add_child(UI.make_button("＋ 再记录一餐", func(): open_capture()))
		list.resized.connect(func(): content.custom_minimum_size.y = maxf(578, list.size.y + 28))
	if id == "165:1510":
		for item in records:
			if not item.get("planned", false): continue
			for node in app.descendants(page):
				match node.get_meta("figma_id", ""):
					"165:1527": node.text = "我的食谱 · %d MIN" % int(item.meal.recipe.minutes)
					"165:1528": node.text = item.meal.recipe.title
					"165:1529": node.text = "来自照片日记\n查看参考做法"
					"I165:1530;98:2027":
						var image := Image.load_from_file(item.sticker if not str(item.sticker).is_empty() else item.photo)
						if image != null: node.texture = ImageTexture.create_from_image(image)
			break

func decorate_overlay(panel: Control, id: String) -> void:
	if id not in ["165:1223", "165:1242"]: return
	for node in app.descendants(panel):
		match node.get_meta("figma_id", ""):
			"I165:1233;28:87": node.text = "上传真实照片 · 识别与制作食物贴纸"
			"I165:1234;165:1979": node.text = "体验示例拍摄"
			"I165:1252;165:1984": node.text = "从相册选择真实照片"
