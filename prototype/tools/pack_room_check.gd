extends SceneTree
## External driver validates the exported pack; no test scripts are bundled.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.show_page("165:1138")
	var studio = app.room_studio
	studio.open_editor()
	await process_frame
	assert(studio.editor.canvas.otter == null)
	studio.set_days(32)
	assert(studio.claim_available() == 30)
	for item in studio.catalog.values():
		studio.editor.canvas.add_item(item.id)
		assert(studio.editor.canvas.sprites[item.id].texture != null)
	assert(studio.editor.canvas.placements.size() == 32)
	assert(studio.save_editor("My", studio.editor.canvas.placements))
	await process_frame
	assert(app.current_id == "165:1083" and app.overlays.is_empty())
	print("PACK_ROOM_OK furniture=32")
	quit()
