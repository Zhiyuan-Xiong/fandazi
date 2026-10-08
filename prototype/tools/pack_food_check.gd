extends SceneTree
## Uses the production loopback bridge, never sends a paid request when configured.
var app: Control

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in 5: await process_frame

func ensure(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func wait_request(view: Control) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while view.busy and Time.get_ticks_msec() < deadline: await process_frame
	return ensure(not view.busy, "Local request timed out")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	var flow: Node = app.food_flow
	var health: Array = []
	flow.request_api(app, "/health", {}, func(ok: bool, data: Dictionary): health.append([ok, data]))
	var deadline := Time.get_ticks_msec() + 15000
	while health.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if not ensure(not health.is_empty() and health[0][0], "Production local bridge unavailable"): return
	var view: Control = flow.open_capture()
	var photo_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photo="): photo_path = arg.trim_prefix("--photo=")
	view.import_file(photo_path)
	if not await wait_request(view): return
	if not ensure(view.photo != null and view.meal.is_empty(), "Real import failed"): return
	if not health[0][1].get("configured", false):
		view.analyze()
		if not await wait_request(view): return
		if not ensure(view.status.text.contains("密钥") and view.meal.is_empty() and view.photo != null, "No-key failure must preserve photo and not invent data"): return
	flow.open_settings()
	await settle()
	if not ensure(app.overlays[-1].secret.secret, "Key field must be masked"): return
	app.close_overlay()
	await settle()
	view.save()
	await settle()
	app.overlays[-1].confirm_record()
	await settle()
	if not ensure(app.current_id == "165:1308" and flow.records.size() == 1, "Pack photo diary save failed"): return
	print("PACK_FOOD_OK production_bridge=true live_ai=false configured=", health[0][1].get("configured", false))
	quit()
