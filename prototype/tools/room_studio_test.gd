extends "res://tools/catalog_regression.gd"
## Sends real pointer events through Godot GUI; uses isolated demo state.

func tap(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		root.push_input(event)
	await settle()

func click_text(text: String) -> bool:
	var scope: Node = app.pages[app.current_id] if app.overlays.is_empty() else app.overlays[-1]
	for node in app.descendants(scope):
		if node is Button and node.text == text and node.is_visible_in_tree() and not node.disabled:
			await tap(node.get_global_rect().get_center())
			return true
	return check(false, "missing button " + text)

func run() -> void:
	root.size = Vector2i(393, 852)
	root.content_scale_size = Vector2i(393, 852)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.show_page("165:1138")
	await settle()
	await screenshot("room-entry")
	if not await click_text("自由布置"): return
	var studio: Node = app.room_studio
	var editor: Control = studio.editor
	var canvas: Control = editor.canvas
	if not check(canvas.editable and canvas.otter == null, "placement mode has no otter"): return
	await screenshot("room-editor-initial")
	if not await click_text("清空"): return
	if not check(canvas.placements.is_empty(), "clear produces an empty room"): return
	if not check(studio.rooms.My.size() == 1, "draft does not alter saved room"): return
	if not await click_text("32 天"): return
	if not check(studio.days == 32 and studio.available().size() == 30, "day 32 unlocks all remaining furniture"): return
	if not await click_text("领取 30 件"): return
	if not check(studio.owned.size() == 32, "all 32 complete furniture images can be claimed"): return
	if not check(studio.available().is_empty(), "claims cannot be duplicated"): return
	await drag_pointer(Vector2(325, 630), Vector2(130, 630))
	if not check(editor.categories.get_parent().scroll_horizontal > 40, "category bar drags to the last category"): return
	if not check(editor.category == "客厅", "category drag does not click a tab"): return
	if not await click_text("墙饰"): return
	if not check(editor.inventory.get_child_count() == 6, "all wall decorations are available"): return
	await drag_pointer(Vector2(70, 630), Vector2(270, 630))
	if not await click_text("客厅"): return
	await drag_pointer(Vector2(315, 708), Vector2(90, 708))
	if not check(editor.inventory.get_parent().scroll_horizontal > 100, "furniture cards drag to reveal later items"): return
	if not check(canvas.placements.is_empty(), "inventory drag never accidentally places furniture"): return
	await drag_pointer(Vector2(70, 708), Vector2(355, 708))
	for card in editor.inventory.get_children():
		var art: TextureRect = card.get_child(0)
		if not check(card.get_global_rect().encloses(art.get_global_rect()), "inventory artwork fits its card " + str(card.get_meta("furniture_id"))): return
	# Every source model renders independently with full opacity and aspect ratio.
	for item in studio.catalog.values():
		canvas.add_item(item.id)
		var sprite: TextureRect = canvas.sprites[item.id]
		if not check(sprite.texture != null and sprite.modulate.a == 1, "complete art available " + str(item.id)): return
		if not check(is_equal_approx(sprite.size.x / sprite.size.y, float(sprite.texture.get_width()) / sprite.texture.get_height()), "undistorted furniture " + str(item.id)): return
	canvas.clear_room()
	# Select rug from inventory, drag it, then resize using the actual corner handle.
	for card in editor.inventory.get_children():
		if card.get_meta("furniture_id") == "paw-rug":
			await tap(card.get_global_rect().get_center())
	if not check(canvas.selected == "paw-rug", "inventory card places a rug"): return
	var start: Vector2 = canvas.sprites["paw-rug"].get_global_rect().get_center()
	await drag_pointer(start, start + Vector2(-50, 29))
	var rug: Dictionary = canvas.item_data("paw-rug")
	if not check(absf(rug.x - (0.5 - 50.0 / 353)) < 0.01 and rug.y > 0.8, "furniture follows pointer drag"): return
	var before_width: float = rug.w
	var handle: Vector2 = canvas.global_position + canvas.handle_rect().get_center()
	await drag_pointer(handle, handle + Vector2(22, 14))
	if not check(float(rug.w) > before_width, "corner handle scales furniture"): return
	await tap(editor.scale_slider.global_position + Vector2(63, 16))
	if not check(canvas.item_data("paw-rug").w != before_width, "scale slider changes selected furniture"): return
	canvas.set_width(20)
	if not check(canvas.item_data("paw-rug").w == 1.2 and Rect2(Vector2.ZERO, canvas.size).encloses(canvas.handle_rect()), "maximum scale keeps resize handle reachable"): return
	canvas.set_width(0.001)
	if not check(canvas.item_data("paw-rug").w == 0.08, "minimum scale keeps furniture selectable"): return
	canvas.set_width(0.52)
	canvas.add_item("sage-sofa")
	var sofa: Dictionary = canvas.item_data("sage-sofa")
	sofa.x = 0.73
	sofa.y = 0.67
	canvas.set_width(0.46)
	await click_text("后移")
	if not check(canvas.placements[0].id == "sage-sofa", "furniture can move behind other furniture"): return
	await click_text("前移")
	if not check(canvas.placements[-1].id == "sage-sofa", "furniture can move in front"): return
	canvas.add_item("coffee-table")
	await click_text("收起")
	if not check(canvas.item_data("coffee-table").is_empty(), "selected furniture can be stored"): return
	await screenshot("room-editor-arranged")
	await click_text("保存并回到小窝")
	if not check(app.current_id == "165:1083" and app.overlays.is_empty(), "save returns to one normal room page"): return
	var view: Control
	for room in studio.room_views:
		if room.is_visible_in_tree(): view = room
	if not check(view.placements.size() == 2 and view.otter != null, "saved room restores otter and arrangement"): return
	await tap(view.sprites["sage-sofa"].get_global_rect().get_center())
	await create_timer(0.35).timeout
	if not check(view.otter_pose == "Default" and view.attached_to == "sage-sofa", "sofa click seats otter"): return
	await screenshot("room-otter-sofa")
	await tap(view.sprites["paw-rug"].get_global_rect().get_center())
	await create_timer(0.35).timeout
	if not check(view.otter_pose == "LieDown" and view.attached_to == "paw-rug", "rug click changes otter to lying"): return
	await screenshot("room-otter-rug")
	await tap(view.sprites["paw-rug"].get_global_rect().get_center())
	await create_timer(0.35).timeout
	if not check(view.otter_pose == "Default", "repeated furniture tap alternates pose"): return
	var previous: Vector2 = view.otter_anchor
	await tap(view.global_position + view.size * Vector2(0.85, 0.92))
	await create_timer(0.35).timeout
	if not check(view.attached_to.is_empty() and view.otter_anchor.distance_to(previous) > 0.1, "floor click moves otter to a new location"): return
	# Cancel and reopen must preserve the saved layout; decreasing days keeps claims.
	await click_text("自由布置")
	editor = studio.editor
	editor.day_input.value = 1
	if not check(studio.owned.size() == 32 and studio.days == 1, "day simulation never revokes claimed furniture"): return
	await click_text("清空")
	await click_text("取消")
	if not check(studio.rooms.My.size() == 2, "cancel discards only the arrangement draft"): return
	await click_text("自由布置")
	if not check(studio.editor.canvas.placements.size() == 2, "reopening restores saved arrangement"): return
	await click_text("取消")
	if not check(studio.persist("res://qa/room-test-save.json"), "local save writes successfully"): return
	studio.rooms.My = []
	studio.owned = ["sage-armchair", "coffee-table"]
	studio.days = 2
	studio.load_saved("res://qa/room-test-save.json")
	if not check(studio.rooms.My.size() == 2 and studio.owned.size() == 32 and studio.days == 1, "local save round trip preserves positions and ownership"): return
	var report := {"passed": passed.size(), "checks": passed}
	FileAccess.open("res://qa/room-studio-test.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("ROOM_STUDIO_OK checks=", passed.size())
	quit()
