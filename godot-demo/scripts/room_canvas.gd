extends Control
## Normalized room coordinates keep the arrangement identical in both room sizes.
signal selection_changed
signal arrangement_changed
signal otter_changed(pose: String)
const MOTION = preload("res://scripts/otter_motion.gd")
const SITTING = preload("res://assets/figma/c2a6d044023896c489b8.png")
const LYING = preload("res://assets/figma/e807a4caf52d4e69828a.png")
var catalog: Dictionary = {}
var placements: Array = []
var editable := false
var selected := ""
var sprites: Dictionary = {}
static var alpha_masks: Dictionary = {}
var otter: TextureRect
var otter_pose := "Default"
var otter_anchor := Vector2(0.77, 0.91)
var otter_width := 0.27
var attached_to := ""
var dragging := false
var resizing_item := false
var start_pointer := Vector2.ZERO
var start_center := Vector2.ZERO
var start_width := 0.0
var start_distance := 0.0
var press_item := ""
var travel: Tween

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("room_canvases")
	var background := TextureRect.new()
	background.texture = preload("res://assets/figma/c840c375e553e15de7d8.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(layout_items)
	visibility_changed.connect(func(): dragging = false; resizing_item = false)
	rebuild()

func configure(items: Dictionary, arrangement: Array, editing: bool) -> void:
	catalog = items
	placements = arrangement.duplicate(true)
	editable = editing
	if is_node_ready(): rebuild()

func rebuild() -> void:
	for sprite in sprites.values():
		remove_child(sprite)
		sprite.queue_free()
	sprites.clear()
	for item in placements:
		var sprite := TextureRect.new()
		sprite.name = item.id.replace("-", "_")
		sprite.texture = load(catalog[item.id].asset)
		if not alpha_masks.has(item.id):
			var mask := BitMap.new()
			var pixels := sprite.texture.get_image()
			if pixels.is_compressed(): pixels.decompress()
			mask.create_from_image_alpha(pixels, 0.10)
			alpha_masks[item.id] = mask
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite)
		sprites[item.id] = sprite
	if not editable and otter == null: create_otter("Default")
	if editable and is_instance_valid(otter):
		remove_child(otter)
		otter.queue_free()
		otter = null
	layout_items()

func layout_items() -> void:
	for item in placements:
		if not sprites.has(item.id): continue
		var sprite: TextureRect = sprites[item.id]
		var aspect := float(sprite.texture.get_height()) / sprite.texture.get_width()
		sprite.size = Vector2(size.x * float(item.w), size.x * float(item.w) * aspect)
		sprite.position = Vector2(float(item.x), float(item.y)) * size - sprite.size / 2
	if is_instance_valid(otter): update_otter_transform()
	queue_redraw()

func item_data(id: String) -> Dictionary:
	for item in placements:
		if item.id == id: return item
	return {}

func add_item(id: String) -> void:
	if not catalog.has(id): return
	if item_data(id).is_empty():
		var width := 0.40 if id != "paw-rug" else 0.53
		placements.append({"id": id, "x": 0.5, "y": 0.74, "w": width})
	selected = id
	rebuild()
	selection_changed.emit()
	arrangement_changed.emit()

func remove_selected() -> void:
	for index in range(placements.size() - 1, -1, -1):
		if placements[index].id == selected: placements.remove_at(index)
	selected = ""
	rebuild()
	selection_changed.emit()
	arrangement_changed.emit()

func clear_room() -> void:
	placements.clear()
	selected = ""
	rebuild()
	selection_changed.emit()
	arrangement_changed.emit()

func change_layer(front: bool) -> void:
	var item := item_data(selected)
	if item.is_empty(): return
	placements.erase(item)
	if front: placements.append(item)
	else: placements.push_front(item)
	rebuild()
	arrangement_changed.emit()

func set_width(width: float) -> void:
	var item := item_data(selected)
	if item.is_empty(): return
	item.w = clampf(width, 0.08, 1.20)
	layout_items()
	selection_changed.emit()
	arrangement_changed.emit()

func pick(point: Vector2) -> String:
	# Test texture alpha so a transparent image corner does not cover another item.
	for index in range(placements.size() - 1, -1, -1):
		var id: String = placements[index].id
		var sprite: TextureRect = sprites[id]
		if not sprite.get_rect().has_point(point): continue
		var uv := (point - sprite.position) / sprite.size
		var pixel := Vector2i(uv * sprite.texture.get_size())
		if alpha_masks[id].get_bitv(pixel): return id
	return ""

func handle_rect() -> Rect2:
	if not sprites.has(selected): return Rect2()
	var corner: Vector2 = sprites[selected].get_rect().end.clamp(Vector2(12, 12), size - Vector2(12, 12))
	return Rect2(corner - Vector2(10, 10), Vector2(20, 20))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if editable and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var item := item_data(selected)
			if not item.is_empty(): set_width(item.w + (0.02 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.02))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_pointer = event.position
				press_item = pick(event.position)
				resizing_item = editable and not selected.is_empty() and handle_rect().has_point(event.position)
				if editable:
					if not resizing_item: selected = press_item
					var item := item_data(selected)
					if not item.is_empty():
						start_center = Vector2(item.x, item.y) * size
						start_width = item.w
						start_distance = maxf(1, event.position.distance_to(start_center))
						dragging = not resizing_item
					selection_changed.emit()
					queue_redraw()
			elif not editable and event.position.distance_to(start_pointer) < 8:
				visit(event.position, press_item)
			if not event.pressed:
				dragging = false
				resizing_item = false
			accept_event()
	elif event is InputEventMouseMotion and editable:
		var item := item_data(selected)
		if item.is_empty(): return
		if resizing_item:
			set_width(start_width * event.position.distance_to(start_center) / start_distance)
			accept_event()
		elif dragging:
			var center: Vector2 = (start_center + event.position - start_pointer) / size
			item.x = clampf(center.x, 0.03, 0.97)
			item.y = clampf(center.y, 0.05, 0.97)
			layout_items()
			arrangement_changed.emit()
			accept_event()

func _draw() -> void:
	if editable and sprites.has(selected):
		draw_rect(sprites[selected].get_rect(), Color("3c7764"), false, 1.5)
		draw_style_box(handle_style(), handle_rect())
		draw_line(handle_rect().position + Vector2(6, 14), handle_rect().position + Vector2(14, 6), Color.WHITE, 2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
		resizing_item = false

func handle_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3c7764")
	style.set_corner_radius_all(6)
	return style

func create_otter(pose: String) -> void:
	if is_instance_valid(otter):
		remove_child(otter)
		otter.queue_free()
	otter = TextureRect.new()
	otter.set_script(MOTION)
	otter.pose_name = pose
	otter.texture = LYING if pose == "LieDown" else SITTING
	otter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	otter.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	otter_pose = pose
	add_child(otter)
	update_otter_transform()

func update_otter_transform() -> void:
	otter.size = Vector2(size.x * otter_width, size.x * otter_width * float(otter.texture.get_height()) / otter.texture.get_width())
	otter.base_position = otter_anchor * size - Vector2(otter.size.x / 2, otter.size.y)
	otter.position = otter.base_position
	otter.pivot_offset = otter.size * Vector2(0.5, 0.88)
	move_child(otter, -1)

func visit(point: Vector2, id: String) -> void:
	if id.is_empty() and is_instance_valid(otter) and otter.get_rect().has_point(point):
		otter.react()
		return
	var target := point / size
	var pose := "Default"
	otter_width = 0.27
	if not id.is_empty() and not str(catalog[id].pose).is_empty():
		var rect: Rect2 = sprites[id].get_rect()
		pose = catalog[id].pose
		# Repeated taps on the same seat/rug alternate sitting and lying.
		if attached_to == id: pose = "Default" if otter_pose == "LieDown" else "LieDown"
		target = Vector2(rect.get_center().x, rect.position.y + rect.size.y * (0.79 if pose == "LieDown" else 0.72)) / size
		otter_width = clampf(float(item_data(id).w) * (0.76 if pose == "LieDown" else 0.47), 0.10, 0.37)
		attached_to = id
	else:
		target.x = clampf(target.x, 0.14, 0.86)
		target.y = clampf(target.y, 0.64, 0.96)
		attached_to = ""
	if travel != null: travel.kill()
	create_otter(pose)
	travel = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	travel.tween_method(func(value: Vector2): otter_anchor = value; update_otter_transform(), otter_anchor, target, 0.28)
	otter.react()
	otter_changed.emit(pose)
