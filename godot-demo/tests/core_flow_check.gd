extends SceneTree
## Publication-copy driver; adapted from the 2026-10-11 archive. No AI requests; save files are synthetic fixtures.
var app: Control
var checks: Array[String] = []
const REPORT_DIR = "user://publication-qa"

func _initialize() -> void:
	call_deferred("run")

func verify(ok: bool, label: String) -> bool:
	if not ok:
		push_error("ARCHIVE_CHECK_FAILED " + label)
		quit(1)
		return false
	checks.append(label)
	return true

func settle() -> void:
	for i in 5: await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	if not verify(app.current_id == "165:958", "copied pack starts in pet home"): return
	for id in ["165:1308", "165:1510", "165:1669", "165:1833", "199:2313"]:
		app.show_page(id)
		await settle()
		if not verify(app.current_id == id and app.pages[id] != null, "navigation " + id): return
	app.show_page("165:1138")
	var studio = app.room_studio
	studio.open_editor()
	await settle()
	if not verify(studio.editor.canvas.otter == null, "edit mode hides pet without replacing art"): return
	studio.set_days(32)
	if not verify(studio.claim_available() == 30 and studio.owned.size() == 32, "synthetic day 32 claims 30 remaining furniture"): return
	for item in studio.catalog.values():
		studio.editor.canvas.add_item(item.id)
		if not verify(studio.editor.canvas.sprites[item.id].texture != null, "furniture texture " + item.id): return
	if not verify(studio.save_editor("My", studio.editor.canvas.placements), "save room arrangement"): return
	if not verify(studio.persist(REPORT_DIR + "/room_fixture.json"), "write isolated room fixture"): return
	studio.rooms.My = []
	studio.load_saved(REPORT_DIR + "/room_fixture.json")
	if not verify(studio.rooms.My.size() == 32, "room arrangement reload"): return
	var flow = app.food_flow
	flow.store_dir = REPORT_DIR + "/synthetic_food_fixture"
	flow.records = []
	# Override with an unreachable loopback endpoint, never use production bridge/settings.
	flow.bridge_override = {"port": 1, "token": "archive-fixture-only"}
	var view = flow.open_capture()
	await settle()
	view.import_file(ProjectSettings.globalize_path("res://assets/figma/31d5f64980827f8b93ac.png"))
	var deadline := Time.get_ticks_msec() + 5000
	while view.busy and Time.get_ticks_msec() < deadline: await process_frame
	if not verify(view.photo != null and view.meal.is_empty(), "photo import has no fabricated nutrition"): return
	view.title_input.text = "归档验证用示例图片（非用户餐食）"
	if not verify(flow.save_view(view), "save isolated photo-only diary fixture"): return
	if not verify(flow.records.size() == 1 and flow.records[0].source == "photo_only", "photo-only is explicitly unestimated"): return
	view.record = flow.records[0]
	view.title_input.text = "归档验证同一条更新"
	if not verify(flow.save_view(view) and flow.records.size() == 1, "editing record does not duplicate totals"): return
	flow.records = []
	flow.load_records()
	if not verify(flow.records.size() == 1 and FileAccess.file_exists(flow.records[0].photo), "diary and photo reload from archive fixture"): return
	flow.open_receipt(flow.records[0])
	await settle()
	app.show_page("165:958")
	if not verify(app.current_id == "165:958" and app.overlays.is_empty(), "receipt can return to room home"): return
	FileAccess.open(REPORT_DIR + "/archive_pack_result.json", FileAccess.WRITE).store_string(JSON.stringify({"passed": checks.size(), "checks": checks, "live_ai": false, "mode": "headless-source-publication-copy", "real_user_data_accessed": false}, "\t"))
	print("ARCHIVE_PACK_OK checks=", checks.size(), " live_ai=false")
	quit()
