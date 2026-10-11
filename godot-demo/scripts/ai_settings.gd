extends Control
const UI = preload("res://scripts/room_studio.gd")
const VIEW = preload("res://scripts/food_view.gd")
var flow: Node
var status: Label
var secret: LineEdit
var vision: LineEdit
var image_model: LineEdit
var save_button: Button

func _ready() -> void:
	size = Vector2(393, 852)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("faf8ee")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.position = Vector2(24, 40)
	margin.size = Vector2(345, 760)
	add_child(margin)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 18)
	margin.add_child(list)
	list.add_child(VIEW.label("本机 AI 设置", 25))
	list.add_child(VIEW.label("服务：OpenAI\n密钥仅在这台 Windows 电脑上加密保存，不会写入 App 安装包。", 14))
	status = VIEW.label("正在连接本机服务…", 14)
	list.add_child(status)
	list.add_child(VIEW.label("API 密钥", 14))
	secret = LineEdit.new()
	secret.secret = true
	secret.placeholder_text = "未配置时填写；留空保留已有密钥"
	VIEW.input_style(secret)
	list.add_child(secret)
	var create_key := UI.make_button("打开 OpenAI 密钥管理页面 ↗", func(): OS.shell_open("https://platform.openai.com/api-keys"))
	create_key.custom_minimum_size.y = 36
	list.add_child(create_key)
	list.add_child(VIEW.label("食物识别模型", 13))
	vision = LineEdit.new()
	vision.text = "gpt-4.1-mini"
	VIEW.input_style(vision)
	list.add_child(vision)
	list.add_child(VIEW.label("食物贴纸模型（需支持透明背景）", 13))
	image_model = LineEdit.new()
	image_model.text = "gpt-image-2"
	VIEW.input_style(image_model)
	list.add_child(image_model)
	list.add_child(VIEW.label("原 Figma 食物插画作为固定风格参考 · 透明 PNG", 12))
	list.add_child(VIEW.label("没有密钥也可以导入照片并保存日记。配置后，点击识别或生成贴纸才会上传照片并产生 API 用量。", 13))
	save_button = UI.make_button("保存本机配置", save, true)
	save_button.custom_minimum_size.y = 44
	list.add_child(save_button)
	list.add_child(UI.make_button("返回这顿饭", func(): flow.app.close_overlay()))
	flow.request_api(self, "/health", {}, func(ok: bool, data: Dictionary):
		if not ok:
			status.text = data.get("error", "连接失败。")
			return
		vision.text = data.get("vision_model", vision.text)
		image_model.text = data.get("image_model", image_model.text)
		status.text = "已保存密钥；调用时将验证账户权限。" if data.get("configured", false) else "本机服务已连接 · 尚未配置密钥")

func save() -> void:
	save_button.disabled = true
	status.text = "正在保存…"
	flow.request_api(self, "/config", {"api_key": secret.text, "vision_model": vision.text, "image_model": image_model.text}, func(ok: bool, data: Dictionary):
		save_button.disabled = false
		if not ok:
			status.text = data.get("error", "保存失败。")
			return
		secret.clear()
		status.text = "配置已加密保存，返回后即可尝试识别。" if data.get("configured", false) else "模型设置已保存；仍需填写 API 密钥才能启用 AI。")
