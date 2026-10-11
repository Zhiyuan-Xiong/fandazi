extends Node
## Small local demo state: source artwork + claimed items + normalized placements.
const CANVAS = preload("res://scripts/room_canvas.gd")
const EDITOR = preload("res://scripts/room_editor.gd")
const SAVE_PATH := "user://room-layout.json"
var app: Control
var catalog: Dictionary = {}
var days := 2
var owned: Array = ["sage-armchair", "coffee-table"]
var rooms: Dictionary = {}
var editor: Control
var test_mode := false
var room_views: Array[Control] = []
var refreshing := false

func _ready() -> void:
	app = get_parent()
	for item in JSON.parse_string(FileAccess.get_file_as_string("res://design/furniture.json")):
		catalog[item.id] = item
	rooms = {"My": initial_room(), "Partner": initial_room()}
	var args := OS.get_cmdline_user_args()
	test_mode = args.has("--interaction-test") or args.has("--smoke") or args.has("--capture-all") or args.has("--capture")
	if not test_mode: load_saved()
	app.values["VariableID:196:843"] = days
	app.values["VariableID:202:860"] = str(days)
	if days > 3: app.values["VariableID:224:2"] = "累计打卡 · 已陪伴 %d 天 ›" % days
	sync_room_values()

func initial_room() -> Array:
	return [{"id": "sage-armchair", "x": 0.235, "y": 0.77, "w": 0.39}]

func load_saved(path := SAVE_PATH) -> void:
	if not FileAccess.file_exists(path): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	days = clampi(int(data.get("days", 2)), 0, 365)
	for id in data.get("owned", []):
		if catalog.has(id) and not owned.has(id): owned.append(id)
	for key in ["My", "Partner"]:
		var clean: Array = []
		var seen: Array = []
		for item in data.get("rooms", {}).get(key, initial_room()):
			if not item is Dictionary or not owned.has(item.get("id", "")) or seen.has(item.id): continue
			clean.append({"id": item.id, "x": clampf(float(item.get("x", 0.5)), 0.03, 0.97), "y": clampf(float(item.get("y", 0.75)), 0.05, 0.97), "w": clampf(float(item.get("w", 0.4)), 0.08, 1.2)})
			seen.append(item.id)
		rooms[key] = clean

func persist(path := SAVE_PATH) -> bool:
	if test_mode and path == SAVE_PATH: return true
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Room save failed: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify({"version": 1, "days": days, "owned": owned, "rooms": rooms}, "\t"))
	return true

func set_days(value: int) -> void:
	days = clampi(value, 0, 365)
	app.values["VariableID:196:843"] = days
	app.values["VariableID:202:860"] = str(days)
	app.values["VariableID:224:2"] = "模拟打卡 · 已累计 %d 天 ›" % days
	persist()
	app.refresh_bindings()

func available() -> Array:
	return catalog.values().filter(func(item): return int(item.day) <= days and not owned.has(item.id))

func claim_available() -> int:
	var items := available()
	for item in items: owned.append(item.id)
	persist()
	app.refresh_bindings()
	return items.size()

func attach_page(page: Control, id: String) -> void:
	for node in app.descendants(page):
		var label: String = node.get_meta("figma_name", "")
		if not label.begins_with("Decor room / "): continue
		var key := "Partner" if label.ends_with("Partner") else "My"
		# Replace the three hard-coded preview sprites, keeping the original room slot.
		for child in node.get_children():
			if child.get_meta("figma_name", "") == "Status bubble": continue
			node.remove_child(child)
			child.queue_free()
		var canvas := Control.new()
		canvas.set_script(CANVAS)
		canvas.set_meta("room_key", key)
		canvas.configure(catalog, rooms[key], false)
		node.add_child(canvas)
		node.move_child(canvas, 0)
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		room_views.append(canvas)
		var entry := make_button("自由布置", func(): open_editor(key))
		entry.name = "OpenRoomEditor"
		entry.position = Vector2(node.size.x - 99, 10)
		entry.size = Vector2(91, 32)
		node.add_child(entry)
	if id == "165:1083":
		for node in app.descendants(page):
			if node is Label and node.text == "打卡收家具 · 布置你的角落":
				node.text = "点家具换姿势，点地板换位置"

func open_editor(key := "My", item := "") -> void:
	if is_instance_valid(editor): return
	app.clear_overlays()
	editor = Control.new()
	editor.set_script(EDITOR)
	editor.studio = self
	editor.room_key = key
	editor.pending_item = item
	editor.set_meta("figma_id", "room-editor")
	var blocker := Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	app.get_node("PopupLayer").add_child(blocker)
	blocker.add_child(editor)
	app.overlays.append(editor)
	app.set_buttons_enabled(app.pages[app.current_id], false)
	editor.tree_exited.connect(func(): editor = null)

func save_editor(key: String, arrangement: Array) -> bool:
	var previous: Array = rooms[key]
	rooms[key] = arrangement.duplicate(true)
	if not persist():
		rooms[key] = previous
		return false
	sync_room_values()
	for canvas in room_views:
		if is_instance_valid(canvas): canvas.configure(catalog, rooms[canvas.get_meta("room_key")], false)
	app.close_overlay()
	app.show_page("199:2315" if key == "Partner" else "165:1083")
	return true

func sync_room_values() -> void:
	for key in ["My", "Partner"]:
		for i in 3:
			var slug: String = ["sage-armchair", "coffee-table", "paw-rug"][i]
			var placed: bool = rooms[key].any(func(item): return item.id == slug)
			app.values["VariableID:201:" + str(2285 + i + (3 if key == "Partner" else 0))] = placed
			app.values["VariableID:205:" + str(2 + i + (3 if key == "Partner" else 0))] = placed

func intercept(button: Button) -> bool:
	var id: String = button.get_meta("source_id", "")
	if id in ["202:2645", "202:2656"]:
		open_editor("Partner" if id == "202:2656" else "My", str(app.values.get("VariableID:201:10", "")))
		return true
	# Claimed furniture remains selectable in the original Figma catalog and rows.
	for action in button.get_meta("click_actions", []):
		if action.get("type") == "SET_VARIABLE" and action.get("variableId") == "VariableID:201:10":
			var slug: String = str(app.resolve_value(action.variableValue))
			if not owned.has(slug): return false
			var actions: Array = button.get_meta("click_actions").filter(func(a): return a.get("type") != "NODE")
			app.apply_actions(actions, button.get_parent())
			return true
	return false

func refresh() -> void:
	if refreshing: return
	refreshing = true
	days = maxi(days, int(app.values.get("VariableID:196:843", days)))
	app.values["VariableID:196:843"] = days
	app.values["VariableID:202:860"] = str(days)
	if app.values.get("VariableID:196:844", false) and not owned.has("paw-rug"):
		owned.append("paw-rug")
		persist()
	var slug: String = str(app.values.get("VariableID:201:10", ""))
	if catalog.has(slug):
		app.values["VariableID:201:11"] = "已拥有 · 可自由放置" if owned.has(slug) else ("已解锁 · 进入自由布置领取" if days >= int(catalog[slug].day) else "冻结 · %d 天解锁" % int(catalog[slug].day))
	# Keep the source's card layout; update only ownership paint and status.
	for page in app.pages.values():
		for node in app.descendants(page):
			var title: String = node.get_meta("figma_name", "")
			if not title.begins_with("Furniture / "): continue
			var furniture := title.trim_prefix("Furniture / ")
			if not catalog.has(furniture): continue
			var claimed := owned.has(furniture)
			for child in app.descendants(node):
				var child_name: String = child.get_meta("figma_name", "")
				if child is Label and child_name == "StatusLabel":
					child.text = "✓ 已拥有" if claimed else ("可领取 · %d天" % int(catalog[furniture].day) if days >= int(catalog[furniture].day) else "❄ 冻结 · %d天" % int(catalog[furniture].day))
				if child is TextureRect and child_name.begins_with("Artwork / "): child.modulate.a = 1.0 if claimed else 0.55
			if node.get_script() != null and node.get_script().resource_path.ends_with("surface.gd"):
				if not node.has_meta("room_claimed") or node.get_meta("room_claimed", false) != claimed:
					node.set_meta("room_claimed", claimed)
					var color := Color("fffef9") if claimed else Color("d8e9ee")
					node.surface_data["fills"] = [{"type": "SOLID", "color": {"r": color.r, "g": color.g, "b": color.b}, "opacity": 1}]
					node.apply_surface()
	refreshing = false

static func make_button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", make_font(550))
	button.add_theme_font_size_override("font_size", 13)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (Color("3c7764") if primary else Color("eef3ea")) if state != "pressed" else Color("c6dbc0")
		if state == "disabled": style.bg_color = Color("dfe7d9")
		style.set_corner_radius_all(15)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("fffef8") if primary else Color("2b4035"))
	button.add_theme_color_override("font_hover_color", Color("fffef8") if primary else Color("2b4035"))
	button.add_theme_color_override("font_pressed_color", Color("2b4035"))
	button.add_theme_color_override("font_disabled_color", Color("809084"))
	button.pressed.connect(action)
	return button

static func make_font(weight := 500) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/NotoSansSC-VF.ttf")
	font.variation_opentype = {2003265652: float(weight)}
	return font
