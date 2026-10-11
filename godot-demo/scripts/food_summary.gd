extends Control
const UI = preload("res://scripts/room_studio.gd")
const VIEW = preload("res://scripts/food_view.gd")
var flow: Node
var mode := "personal"
var editor: Control
var planned := false
var demo := false
var saved: Dictionary = {}
var list: VBoxContainer
var message: Label
var saving := false
var days := 1

func _ready() -> void:
	size = Vector2(393, 852)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("faf8ee")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := UI.make_button("‹ 返回", func(): flow.app.close_overlay())
	back.position = Vector2(20, 32)
	back.size = Vector2(68, 40)
	add_child(back)
	var title := VIEW.label("存入前核对" if mode == "review" else "记录完成" if mode == "receipt" else "我的饮食数据", 22)
	title.position = Vector2(106, 37)
	title.size = Vector2(267, 34)
	add_child(title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 96)
	scroll.size = Vector2(353, 656)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	if mode == "review": render_review()
	elif mode == "receipt": render_receipt()
	else: render_personal()

func button(text: String, action: Callable, primary := false) -> Button:
	var b := UI.make_button(text, action, primary)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size.y = 44
	list.add_child(b)
	return b

func footer(text: String, action: Callable) -> void:
	var b := UI.make_button(text, action, true)
	b.name = "PrimaryAction"
	b.position = Vector2(20, 785)
	b.size = Vector2(353, 46)
	add_child(b)

func card(title: String, text: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e7eedf")
	style.set_corner_radius_all(22)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	list.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)
	content.add_child(VIEW.label(title, 20))
	content.add_child(VIEW.label(text, 15))

func nutrition_text(meal: Dictionary) -> String:
	if meal.is_empty(): return "尚未识别营养信息\n只保存照片，不会记为 0 kcal。"
	var t: Dictionary = flow.totals(meal)
	return "预估 %d–%d kcal\n蛋白质 %.1f g\n碳水化合物 %.1f g\n脂肪 %.1f g" % [roundi(t.low), roundi(t.high), t.protein, t.carbs, t.fat]

func render_review() -> void:
	demo = editor.is_demo
	list.add_child(VIEW.label("演示数据 · 不会写入真实个人记录" if demo else "③ 核对这顿饭，再存入个人记录", 14))
	var photo := TextureRect.new()
	photo.texture = ImageTexture.create_from_image(editor.photo)
	photo.custom_minimum_size.y = 132
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	list.add_child(photo)
	card(editor.title_input.text, "%s · %s\n%s" % [editor.meal_type.get_item_text(editor.meal_type.selected), editor.record.get("created", Time.get_datetime_string_from_system()).left(10), nutrition_text(editor.meal)])
	for item in editor.meal.get("items", []):
		list.add_child(VIEW.label("%s · %.0f g" % [item.name, item.get("selected_g", item.portion_g)], 14))
	list.add_child(VIEW.label("保存内容：餐食照片、用餐类型、你核对的份量与营养预估、备注。保存在这台电脑，可在个人饮食数据和日记中查看。", 13))
	list.add_child(VIEW.label("照片不能推断血糖、血脂或身体健康评分；油量、配料和重量也可能有误差。", 12))
	message = VIEW.label("", 13)
	list.add_child(message)
	button("返回修改份量", func(): flow.app.close_overlay())
	footer("确认存入演示记录" if demo else "确认存入个人记录", confirm_record)

func confirm_record() -> void:
	if saving or not is_instance_valid(editor): return
	saving = true
	if not flow.save_view(editor, planned):
		saving = false
		message.text = "保存失败，内容仍然保留，请检查本机存储空间。"
		return
	flow.open_receipt(flow.last_saved, planned)

func render_receipt() -> void:
	demo = saved.get("source", "") == "demo"
	card("已存入演示记录" if demo else "这一餐，记下了", "演示记录不会混入真实个人数据。" if demo else "照片和确认后的信息已保存在本机。\n日记和个人饮食数据已更新。")
	card(saved.get("title", "我的一餐"), nutrition_text(saved.get("meal", {})))
	button("查看演示汇总" if demo else "查看我的饮食数据", func(): flow.open_personal(demo), true)
	button("查看参考食谱计划" if planned else "返回饮食日记", func(): flow.app.show_page("165:1510" if planned else "165:1308"))
	footer("回到食宠", func(): flow.app.show_page("165:958"))

func render_personal() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	list.add_child(VIEW.label("演示汇总 · 不计入真实记录" if demo else "只汇总你确认保存的餐食 · 本机保存", 13))
	var period := HBoxContainer.new()
	period.add_theme_constant_override("separation", 10)
	list.add_child(period)
	for entry in [[1, "今天"], [7, "近 7 天"]]:
		var b := UI.make_button(entry[1], func(): days = entry[0]; render_personal(), days == entry[0])
		b.custom_minimum_size.y = 40
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		period.add_child(b)
	var summary: Dictionary = flow.personal_summary(days, demo)
	card("今天的餐食记录" if days == 1 else "近 7 天的餐食记录", "%d 餐已记录 · %d 餐有营养预估\n%d 餐尚未估算" % [summary.count, summary.estimated, summary.unestimated])
	if summary.estimated > 0:
		var t: Dictionary = summary.totals
		card("已记录餐食的营养合计", "预估 %d–%d kcal\n蛋白质 %.1f g · 碳水 %.1f g\n脂肪 %.1f g" % [roundi(t.low), roundi(t.high), t.protein, t.carbs, t.fat])
		list.add_child(VIEW.label("仅代表已记录且有估算的餐食，不能作为全天实际摄入或健康评分。", 12))
	else:
		card("营养数据等待补充", "导入照片并完成识别，核对后保存。只有照片的记录不会被当作零热量。")
	for row in summary.records:
		var details := "%s · %s\n%s" % [row.get("meal_type", "未分类"), str(row.created).replace("T", " ").left(16), row.title]
		button(details, func(): flow.open_capture(row))
	if summary.count == 0: list.add_child(VIEW.label("还没有这个时间段的记录。从第一张餐食照片开始。", 14))
	button("＋ 上传食物照片", func():
		var view: Control = flow.open_capture()
		view.call_deferred("choose_photo"), true)
	if not demo: button("免费体验示例流程", func(): flow.open_demo())
