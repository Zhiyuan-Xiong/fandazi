extends Control
const UI = preload("res://scripts/room_studio.gd")
var flow: Node
var record: Dictionary = {}
var photo: Image
var sticker: Image
var meal: Dictionary = {}
var preview: TextureRect
var title_input: LineEdit
var notes: TextEdit
var status: Label
var nutrition: Label
var result_box: VBoxContainer
var busy := false
var buttons: Array[Button] = []
var analyze_button: Button
var sticker_button: Button
var save_button: Button
var chooser: FileDialog
var meal_type: OptionButton
var is_demo := false
var browser_callback: JavaScriptObject

static func label(text: String, font_size := 14) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", UI.make_font(600 if font_size >= 18 else 500))
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("2b4035"))
	return node

static func input_style(node: Control) -> void:
	node.add_theme_font_override("font", UI.make_font(500))
	node.add_theme_font_size_override("font_size", 14)
	node.add_theme_color_override("font_color", Color("2b4035"))
	node.add_theme_color_override("font_placeholder_color", Color("718477"))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("ffffff")
	box.border_color = Color("ceddce")
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	node.add_theme_stylebox_override("normal", box)
	node.add_theme_stylebox_override("focus", box)

func _ready() -> void:
	size = Vector2(393, 852)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color("faf8ee")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := UI.make_button("‹ 返回", func(): flow.app.close_overlay())
	back.position = Vector2(20, 32)
	back.size = Vector2(68, 40)
	add_child(back)
	var heading := label("记下这一餐", 22)
	heading.position = Vector2(105, 37)
	heading.size = Vector2(175, 34)
	add_child(heading)
	var settings := UI.make_button("AI 设置", func(): flow.open_settings())
	settings.position = Vector2(297, 32)
	settings.size = Vector2(76, 40)
	add_child(settings)
	buttons.append(settings)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 90)
	scroll.size = Vector2(353, 674)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	list.add_child(label("① 上传照片 → ② 核对营养 → ③ 存入个人记录", 13))
	add_button(list, "免费体验示例流程", func(): flow.open_demo())
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(0, 210)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(preview)
	var photos := HBoxContainer.new()
	photos.add_theme_constant_override("separation", 8)
	list.add_child(photos)
	add_button(photos, "导入 / 换照片", choose_photo)
	add_button(photos, "原图", func(): show_image(photo))
	add_button(photos, "AI 贴纸", func():
		if sticker != null: show_image(sticker)
		else: status.text = "还没有生成贴纸；完成识别后可点击下方生成。")
	list.add_child(label("餐食名称", 13))
	title_input = LineEdit.new()
	title_input.text = record.get("title", "我的一餐")
	title_input.max_length = 80
	input_style(title_input)
	list.add_child(title_input)
	var meal_row := HBoxContainer.new()
	list.add_child(meal_row)
	meal_row.add_child(label("用餐类型", 13))
	meal_type = OptionButton.new()
	for text in ["早餐", "午餐", "晚餐", "加餐"]: meal_type.add_item(text)
	meal_type.selected = 1
	for i in meal_type.item_count:
		if meal_type.get_item_text(i) == record.get("meal_type", ""): meal_type.selected = i
	meal_type.custom_minimum_size = Vector2(140, 36)
	input_style(meal_type)
	meal_row.add_child(meal_type)
	notes = TextEdit.new()
	notes.custom_minimum_size.y = 64
	notes.placeholder_text = "补充份量或做法，例如：小碗米饭、少油、只吃了一半。"
	notes.text = record.get("notes", "")
	notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input_style(notes)
	list.add_child(notes)
	status = label("尚未识别。可以先导入照片并保存；AI 功能需要本机配置。", 13)
	list.add_child(status)
	analyze_button = add_button(list, "识别食物、热量与参考食谱", analyze, true)
	list.add_child(label("开始识别或生成贴纸时，照片才会发送至 OpenAI，调用由该服务计费。热量仅为照片预估，可调整份量。", 11))
	if OS.has_feature("web"):
		list.get_child(list.get_child_count() - 1).text = "浏览器演示不调用 AI。照片仅保存在此浏览器；示例数值不来自识别，不计入真实记录。"
	result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 10)
	list.add_child(result_box)
	sticker_button = add_button(list, "生成同风格透明贴纸", generate_sticker)
	list.add_child(label("沿用饭搭子食物插画风格 · 透明 PNG", 12))
	add_button(list, "将参考食谱加入计划", func():
		if meal.is_empty() or meal.get("recipe", {}).get("steps", []).is_empty():
			status.text = "请先完成识别，获得参考食谱。"
		else: flow.open_review(self, true))
	save_button = UI.make_button("保存照片日记", save, true)
	save_button.position = Vector2(20, 785)
	save_button.size = Vector2(353, 46)
	add_child(save_button)
	buttons.append(save_button)
	chooser = FileDialog.new()
	chooser.access = FileDialog.ACCESS_FILESYSTEM
	chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	chooser.use_native_dialog = true
	chooser.filters = PackedStringArray(["*.jpg,*.jpeg,*.png,*.webp;食物照片"])
	chooser.file_selected.connect(import_file)
	add_child(chooser)
	if not record.is_empty():
		photo = load(record.photo).get_image() if is_demo else Image.load_from_file(record.photo)
		if not str(record.get("sticker", "")).is_empty(): sticker = Image.load_from_file(record.sticker)
		meal = record.get("meal", {}).duplicate(true)
		show_image(sticker if sticker != null else photo)
		render_meal()
		status.text = "演示记录 · 不计入真实个人数据" if is_demo else "已保存的本机记录；修改后请重新核对并保存。"
	update_buttons()

func add_button(parent: Node, text: String, action: Callable, primary := false) -> Button:
	var button := UI.make_button(text, action, primary)
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	buttons.append(button)
	return button

func choose_photo() -> void:
	if OS.has_feature("web"):
		if busy: return
		browser_callback = JavaScriptBridge.create_callback(on_browser_file)
		JavaScriptBridge.eval("""window.fandaziPickPhoto = function(done) {
			const input = document.createElement('input');
			input.type = 'file'; input.accept = 'image/png,image/jpeg,image/webp';
			input.onchange = function() {
				const file = input.files[0]; if (!file) return;
				if (file.size > 12 * 1024 * 1024) { done('error', '照片超过 12 MB。'); return; }
				const ext = file.name.split('.').pop().toLowerCase();
				if (!['png','jpg','jpeg','webp'].includes(ext)) { done('error','请选择 JPG、PNG 或 WebP。'); return; }
				const reader = new FileReader();
				reader.onload = function() { done(ext, reader.result.split(',')[1]); };
				reader.onerror = function() { done('error','照片无法读取。'); };
				reader.readAsDataURL(file);
			}; input.click();
		};""", true)
		JavaScriptBridge.get_interface("window").fandaziPickPhoto(browser_callback)
		return
	if not busy: chooser.popup_centered_ratio(0.8)

func on_browser_file(arguments: Array) -> void:
	if arguments.size() != 2: return
	var extension := str(arguments[0])
	if extension == "error":
		status.text = str(arguments[1])
		return
	if extension not in ["png", "jpg", "jpeg", "webp"]: return
	var data := Marshalls.base64_to_raw(str(arguments[1]))
	if data.size() > 12 * 1024 * 1024: return
	var path := "user://browser-import." + extension
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		status.text = "浏览器暂时无法保存文件。"
		return
	file.store_buffer(data)
	file.close()
	import_file(path)
	DirAccess.remove_absolute(path)

func show_image(image: Image) -> void:
	if image != null: preview.texture = ImageTexture.create_from_image(image)

func import_file(path: String) -> void:
	if busy: return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 12 * 1024 * 1024:
		status.text = "无法打开照片，或文件超过 12 MB。"
		return
	var raw := file.get_buffer(file.get_length())
	file.close()
	var candidate := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"png": error = candidate.load_png_from_buffer(raw)
		"jpg", "jpeg": error = candidate.load_jpg_from_buffer(raw)
		"webp": error = candidate.load_webp_from_buffer(raw)
	if error != OK or candidate.get_width() * candidate.get_height() > 24000000:
		status.text = "照片无法读取，请选择 2400 万像素以内的 JPG、PNG 或 WebP。"
		return
	if candidate.get_width() > 1600 or candidate.get_height() > 1600:
		var ratio := 1600.0 / maxf(candidate.get_width(), candidate.get_height())
		candidate.resize(roundi(candidate.get_width() * ratio), roundi(candidate.get_height() * ratio), Image.INTERPOLATE_LANCZOS)
	photo = candidate
	is_demo = false
	sticker = null
	meal = {}
	record = {}
	title_input.text = "我的一餐"
	notes.text = ""
	show_image(photo)
	render_meal()
	status.text = "照片已导入，还没有发送给 AI。"
	update_buttons()
	if not flow.bridge().is_empty():
		set_busy(true, "正在本机整理照片方向…")
		flow.request_api(self, "/normalize", {"image_base64": Marshalls.raw_to_base64(raw)}, func(ok: bool, data: Dictionary):
			set_busy(false)
			if ok:
				var normalized := Image.new()
				if normalized.load_jpg_from_buffer(Marshalls.base64_to_raw(data.get("image_base64", ""))) == OK:
					photo = normalized
					show_image(photo)
				status.text = "照片已导入并整理方向，还没有发送给 AI。"
			else: status.text = "照片已导入；本机整理不可用，请检查照片方向。")

func update_buttons() -> void:
	for button in buttons: button.disabled = busy
	title_input.editable = not busy
	notes.editable = not busy
	meal_type.disabled = busy
	analyze_button.disabled = busy or photo == null or is_demo or OS.has_feature("web")
	sticker_button.disabled = busy or meal.is_empty() or photo == null or is_demo or OS.has_feature("web")
	save_button.disabled = busy or photo == null
	save_button.text = "下一步 · 核对并存入" if not meal.is_empty() else "下一步 · 保存照片记录"

func set_busy(value: bool, message := "") -> void:
	busy = value
	if not message.is_empty(): status.text = message
	update_buttons()

func analyze() -> void:
	if busy or photo == null or is_demo: return
	set_busy(true, "正在识别食物与预估份量，请稍候…")
	flow.request_api(self, "/analyze", {"image_base64": Marshalls.raw_to_base64(photo.save_jpg_to_buffer(0.9)), "notes": notes.text.left(600)}, func(ok: bool, data: Dictionary):
		set_busy(false)
		if not ok:
			status.text = data.get("error", "识别失败，可以重试。")
			return
		var detected: Dictionary = data.get("meal", {})
		if not detected.get("is_food", false):
			meal = {}
			sticker = null
			render_meal()
			update_buttons()
			status.text = detected.get("message", "没有识别到清晰的食物，请换一张照片。")
			return
		meal = detected
		title_input.text = meal.get("title", "我的一餐")
		status.text = "已得到 AI 预估，请核对份量。参考食谱是建议做法，并非对原配方的确认。"
		if data.get("test_fixture", false): status.text = "本地测试数据 · 未调用真实 AI"
		render_meal()
		update_buttons())

func generate_sticker() -> void:
	if busy or photo == null or meal.is_empty() or is_demo: return
	set_busy(true, "正在把这餐画成食物贴纸，可能需要几分钟…")
	flow.request_api(self, "/sticker", {"image_base64": Marshalls.raw_to_base64(photo.save_jpg_to_buffer(0.9))}, func(ok: bool, data: Dictionary):
		set_busy(false)
		if not ok:
			status.text = data.get("error", "贴纸生成失败。") + " 仍可保存原图和识别结果。"
			return
		var image := Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(data.get("image_base64", ""))) != OK:
			status.text = "贴纸图片不完整，请重试。"
			return
		sticker = image
		show_image(sticker)
		status.text = "透明贴纸已生成。可切换原图对照，确认后保存。")

func render_meal() -> void:
	for child in result_box.get_children():
		result_box.remove_child(child)
		child.queue_free()
	if meal.is_empty(): return
	result_box.add_child(label("示例营养数据" if is_demo else "② 这一餐的营养预估", 20))
	nutrition = label("", 15)
	result_box.add_child(nutrition)
	for item in meal.get("items", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		result_box.add_child(row)
		row.add_child(label(item.name + (" · 待核对" if item.confidence == "low" else ""), 14))
		var portion := SpinBox.new()
		portion.custom_minimum_size.x = 112
		portion.min_value = 1
		portion.max_value = 5000
		portion.step = 1
		portion.suffix = "g"
		input_style(portion.get_line_edit())
		portion.value = item.get("selected_g", item.portion_g)
		row.add_child(portion)
		portion.value_changed.connect(func(value: float): item.selected_g = value; refresh_totals())
	refresh_totals()
	result_box.add_child(label("照片无法确定油量、隐藏配料与实际重量。修改份量后，营养数值按比例调整。", 12))
	for assumption in meal.get("assumptions", []): result_box.add_child(label("· " + assumption, 12))
	var recipe: Dictionary = meal.get("recipe", {})
	if not recipe.get("steps", []).is_empty():
		result_box.add_child(label("参考食谱 · " + str(recipe.get("title", "")), 20))
		result_box.add_child(label("约 %d 分钟 · 根据照片推测的建议做法" % int(recipe.get("minutes", 0)), 12))
		result_box.add_child(label("食材：" + "、".join(recipe.get("ingredients", [])), 14))
		for index in recipe.steps.size(): result_box.add_child(label("%d. %s" % [index + 1, recipe.steps[index]], 14))

func refresh_totals() -> void:
	var total: Dictionary = flow.totals(meal)
	nutrition.text = "预估 %d–%d kcal\n蛋白质 %.1f g · 碳水 %.1f g · 脂肪 %.1f g" % [roundi(total.low), roundi(total.high), total.protein, total.carbs, total.fat]

func save() -> void:
	if not busy and photo != null: flow.open_review(self)
