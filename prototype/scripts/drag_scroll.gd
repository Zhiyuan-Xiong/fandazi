extends Node
## Mouse dragging over buttons scrolls the nearest container on the gesture axis.
## Native ScrollContainer keeps handling the wheel and real touch input.
var candidates: Array[ScrollContainer] = []
var target: ScrollContainer
var origin := Vector2.ZERO
var scroll_origin := Vector2.ZERO
var dragging := false
var horizontal := false
var canceled_buttons: Array[Button] = []

func _input(event: InputEvent) -> void:
	if event.device == -1:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			origin = event.position
			candidates.clear()
			target = null
			var app := get_parent()
			if app.current_id.is_empty():
				return
			var scope: Node = app.pages[app.current_id] if app.overlays.is_empty() else app.overlays[-1]
			# A furniture drag belongs to the room canvas, not the page scroll.
			for canvas in get_tree().get_nodes_in_group("room_canvases"):
				if scope.is_ancestor_of(canvas) and visible_at(canvas, origin): return
			for node in app.descendants(scope):
				if node is ScrollContainer and visible_at(node, origin):
					candidates.push_front(node)
		elif dragging:
			get_viewport().set_input_as_handled()
			dragging = false
			candidates.clear()
			target = null
			call_deferred("restore_buttons")
		else:
			candidates.clear()
	elif event is InputEventMouseMotion and not candidates.is_empty():
		var delta: Vector2 = event.position - origin
		if not dragging and delta.length() >= 8:
			horizontal = absf(delta.x) > absf(delta.y)
			for candidate in candidates:
				var bar: ScrollBar = candidate.get_h_scroll_bar() if horizontal else candidate.get_v_scroll_bar()
				var mode: int = candidate.horizontal_scroll_mode if horizontal else candidate.vertical_scroll_mode
				if mode != ScrollContainer.SCROLL_MODE_DISABLED and bar.max_value > bar.page:
					target = candidate
					break
			if target != null:
				dragging = true
				scroll_origin = Vector2(target.scroll_horizontal, target.scroll_vertical)
				# A drag that starts on a card/tab must not activate it on release.
				for node in get_parent().descendants(target):
					if node is Button and not node.disabled:
						canceled_buttons.append(node)
						node.disabled = true
		if dragging and is_instance_valid(target):
			if horizontal:
				target.scroll_horizontal = roundi(scroll_origin.x - delta.x)
			else:
				target.scroll_vertical = roundi(scroll_origin.y - delta.y)
			get_viewport().set_input_as_handled()

func visible_at(control: Control, point: Vector2) -> bool:
	if not control.is_visible_in_tree() or not control.get_global_rect().has_point(point):
		return false
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().has_point(point):
			return false
		ancestor = ancestor.get_parent()
	return true

func restore_buttons() -> void:
	for button in canceled_buttons:
		if is_instance_valid(button):
			button.disabled = false
	canceled_buttons.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
		candidates.clear()
		target = null
		restore_buttons()
