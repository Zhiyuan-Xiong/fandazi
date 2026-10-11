@tool
extends Panel
## Native panel fills, corners and shadows copied from Figma.
@export var surface_data: Dictionary = {}
const MASK = preload("res://scripts/rounded_gradient.gdshader")

func _ready() -> void:
	apply_surface()

func color_of(value: Dictionary, opacity: float = 1.0) -> Color:
	return Color(value.get("r", 0.0), value.get("g", 0.0), value.get("b", 0.0), value.get("a", 1.0) * opacity)

func apply_surface() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.anti_aliasing = true
	box.anti_aliasing_size = 1.0
	var radii := Vector4(surface_data.get("topLeftRadius", 0), surface_data.get("topRightRadius", 0), surface_data.get("bottomRightRadius", 0), surface_data.get("bottomLeftRadius", 0))
	box.corner_radius_top_left = int(radii.x)
	box.corner_radius_top_right = int(radii.y)
	box.corner_radius_bottom_right = int(radii.z)
	box.corner_radius_bottom_left = int(radii.w)
	for paint in surface_data.get("fills", []):
		if paint.type == "SOLID":
			box.bg_color = box.bg_color.blend(color_of(paint.color, paint.get("opacity", 1.0)))
	var strokes: Array = surface_data.get("strokes", [])
	if not strokes.is_empty() and strokes[0].type == "SOLID":
		box.border_color = color_of(strokes[0].color, strokes[0].get("opacity", 1.0))
		box.set_border_width_all(int(surface_data.get("strokeWeight", 1)))
	for effect in surface_data.get("effects", []):
		if effect.type == "DROP_SHADOW":
			box.shadow_color = color_of(effect.color)
			box.shadow_size = int(effect.get("radius", 0) / 2)
			box.shadow_offset = Vector2(effect.offset.x, effect.offset.y)
			break
	add_theme_stylebox_override("panel", box)
	for child in get_children():
		if child.name.begins_with("GradientFill"):
			remove_child(child)
			child.queue_free()
	var layer_index := 0
	for paint in surface_data.get("fills", []):
		if paint.type != "GRADIENT_LINEAR":
			continue
		var gradient := Gradient.new()
		var colors := PackedColorArray()
		var offsets := PackedFloat32Array()
		for stop in paint.gradientStops:
			colors.append(color_of(stop.color, paint.get("opacity", 1.0)))
			offsets.append(stop.position)
		gradient.colors = colors
		gradient.offsets = offsets
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 128
		texture.height = 256
		var transform: Array = paint.get("gradientTransform", [[0, 1, 0], [-1, 0, 1]])
		var axis := Vector2(transform[0][0], transform[0][1])
		texture.fill_from = Vector2(0.5, 0.5) - axis * 0.5
		texture.fill_to = Vector2(0.5, 0.5) + axis * 0.5
		var rect := TextureRect.new()
		rect.name = "GradientFill%d" % layer_index
		rect.texture = texture
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var material_instance := ShaderMaterial.new()
		material_instance.shader = MASK
		material_instance.set_shader_parameter("rect_size", size)
		material_instance.set_shader_parameter("radii", radii)
		rect.material = material_instance
		add_child(rect)
		move_child(rect, layer_index)
		resized.connect(func(): material_instance.set_shader_parameter("rect_size", size))
		layer_index += 1
