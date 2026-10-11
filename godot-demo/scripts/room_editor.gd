extends Control
## Dedicated, otter-free placement page. Cancel discards only the arrangement draft.
const CANVAS = preload("res://scripts/room_canvas.gd")
var studio: Node
var room_key := "My"
var pending_item := ""
var canvas: Control
var selection_label: Label
var scale_slider: HSlider
var day_input: SpinBox
var day_label: Label
var claim_button: Button
var inventory: HBoxContainer
var category := "客厅"
var categories: HBoxContainer
var help: Label
var updating := false

func _ready() -> void:
	size = Vector2(393, 852)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("faf8ee")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_at("9:41", Rect2(22, 10, 100, 22), 14)
	label_at("● ▰", Rect2(331, 10, 48, 22), 14)
	button_at("取消", Rect2(20, 44, 62, 38), func(): studio.app.close_overlay())
	var title := label_at("自由布置", Rect2(101, 45, 190, 36), 21)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_at("清空", Rect2(311, 44, 62, 38), func(): canvas.clear_room())
	help = label_at("拖动家具摆放 · 拉右下角或滑杆缩放", Rect2(20, 88, 353, 22), 12)
	canvas = Control.new()
	canvas.set_script(CANVAS)
	canvas.position = Vector2(20, 116)
	canvas.size = Vector2(353, 336)
	canvas.configure(studio.catalog, studio.rooms[room_key], true)
	add_child(canvas)
	canvas.selection_changed.connect(update_selection)
	selection_label = label_at("选择下方家具，开始布置空房间", Rect2(20, 460, 353, 24), 14)
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(20, 491)
	toolbar.size = Vector2(353, 32)
	toolbar.add_theme_constant_override("separation", 6)
	add_child(toolbar)
	scale_slider = HSlider.new()
	scale_slider.min_value = 20
	scale_slider.max_value = 300
	scale_slider.step = 1
	scale_slider.custom_minimum_size.x = 146
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(scale_slider)
	scale_slider.value_changed.connect(func(value: float):
		if not updating: canvas.set_width(value / 250.0))
	for action in [["后移", func(): canvas.change_layer(false)], ["前移", func(): canvas.change_layer(true)], ["收起", func(): canvas.remove_selected()]]:
		var button: Button = studio.make_button(action[0], action[1])
		button.custom_minimum_size.x = 57
		toolbar.add_child(button)
	var card := Panel.new()
	card.position = Vector2(20, 533)
	card.size = Vector2(353, 71)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e7eedf")
	style.set_corner_radius_all(16)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	day_label = label_at("", Rect2(31, 537, 330, 21), 12)
	day_input = SpinBox.new()
	day_input.position = Vector2(30, 564)
	day_input.size = Vector2(84, 30)
	day_input.min_value = 0
	day_input.max_value = 365
	day_input.step = 1
	day_input.suffix = "天"
	var day_edit := day_input.get_line_edit()
	day_edit.add_theme_font_size_override("font_size", 13)
	day_edit.add_theme_font_override("font", studio.make_font(550))
	day_edit.add_theme_color_override("font_color", Color("2b4035"))
	var day_style := StyleBoxFlat.new()
	day_style.bg_color = Color("fffef9")
	day_style.set_corner_radius_all(10)
	day_style.content_margin_left = 7
	day_style.content_margin_top = 3
	day_style.content_margin_bottom = 3
	day_edit.add_theme_stylebox_override("normal", day_style)
	day_edit.add_theme_stylebox_override("focus", day_style)
	add_child(day_input)
	day_input.value = studio.days
	day_input.value_changed.connect(func(value: float): studio.set_days(int(value)); refresh_inventory())
	button_at("+7 天", Rect2(122, 564, 61, 30), func(): day_input.value += 7)
	button_at("32 天", Rect2(189, 564, 61, 30), func(): day_input.value = 32)
	claim_button = button_at("领取", Rect2(256, 564, 106, 30), func():
		var count: int = studio.claim_available()
		help.text = "已领取 %d 件家具，可在下方选择摆放" % count
		refresh_inventory(), true)
	var tabs := make_scroll(Rect2(20, 616, 353, 31))
	categories = HBoxContainer.new()
	categories.add_theme_constant_override("separation", 7)
	tabs.add_child(categories)
	for item in ["客厅", "休息", "餐厨", "植物", "灯饰", "墙饰"]:
		var tab: Button = studio.make_button(item, func(): category = item; refresh_inventory())
		tab.custom_minimum_size = Vector2(62, 30)
		categories.add_child(tab)
	var scroll := make_scroll(Rect2(20, 655, 353, 117))
	inventory = HBoxContainer.new()
	inventory.add_theme_constant_override("separation", 9)
	scroll.add_child(inventory)
	button_at("保存并回到小窝", Rect2(20, 787, 353, 44), func():
		if not studio.save_editor(room_key, canvas.placements): help.text = "保存失败，请重试", true)
	var home_indicator := Panel.new()
	home_indicator.position = Vector2(132, 840)
	home_indicator.size = Vector2(129, 4)
	var line := StyleBoxFlat.new()
	line.bg_color = Color("2b4035")
	line.set_corner_radius_all(2)
	home_indicator.add_theme_stylebox_override("panel", line)
	add_child(home_indicator)
	if studio.catalog.has(pending_item):
		category = studio.catalog[pending_item].category
		if studio.owned.has(pending_item): canvas.add_item(pending_item)
	refresh_inventory()
	update_selection()

func label_at(text: String, rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", studio.make_font(650 if font_size > 18 else 500))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("2b4035"))
	add_child(label)
	return label

func button_at(text: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var button: Button = studio.make_button(text, action, primary)
	button.position = rect.position
	button.size = rect.size
	add_child(button)
	return button

func make_scroll(rect: Rect2) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(scroll)
	return scroll

func update_selection() -> void:
	updating = true
	var item: Dictionary = canvas.item_data(canvas.selected)
	scale_slider.editable = not item.is_empty()
	if item.is_empty(): selection_label.text = "选择下方家具开始布置 · 房间内暂不显示水獭"
	else:
		scale_slider.value = float(item.w) * 250
		selection_label.text = "%s · %d%%" % [studio.catalog[item.id].name, roundi(float(item.w) * 250)]
	updating = false

func refresh_inventory() -> void:
	day_label.text = "模拟打卡天数 · 已领取 %d / 32 件家具" % studio.owned.size()
	claim_button.text = "领取 %d 件" % studio.available().size()
	if studio.owned.size() == 32: claim_button.text = "全部已领取"
	claim_button.disabled = studio.available().is_empty()
	for tab in categories.get_children():
		var style: StyleBoxFlat = tab.get_theme_stylebox("normal").duplicate()
		style.bg_color = Color("c7dbc1") if tab.text == category else Color("eef3ea")
		tab.add_theme_stylebox_override("normal", style)
	for child in inventory.get_children():
		inventory.remove_child(child)
		child.queue_free()
	for item in studio.catalog.values():
		if item.category != category: continue
		var claimed: bool = studio.owned.has(item.id)
		var card: Button = studio.make_button("", func():
			if studio.owned.has(item.id):
				canvas.add_item(item.id)
				help.text = "拖动家具摆放 · 拉右下角或滑杆缩放"
			else: help.text = "%s · %d 天解锁，请先在上方领取" % [item.name, int(item.day)])
		card.set_meta("furniture_id", item.id)
		card.custom_minimum_size = Vector2(100, 113)
		inventory.add_child(card)
		var art := TextureRect.new()
		art.texture = load(item.asset)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.position = Vector2(8, 4)
		art.size = Vector2(84, 65)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.modulate.a = 1.0 if claimed else 0.45
		card.add_child(art)
		for row in 2:
			var text := Label.new()
			text.text = item.name if row == 0 else ("点击摆放" if claimed else ("可领取" if studio.days >= int(item.day) else "%d 天解锁" % int(item.day)))
			text.position = Vector2(2, 70 + 20 * row)
			text.size = Vector2(96, 18)
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			text.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text.add_theme_font_override("font", studio.make_font(500))
			text.add_theme_font_size_override("font_size", 11)
			text.add_theme_color_override("font_color", Color("2b4035") if row == 0 else Color("6d8375"))
			card.add_child(text)
	inventory.get_parent().set_deferred("scroll_horizontal", 0)
