extends SceneTree
## Record actual rendered frames with --fixed-fps 12 for a compact preview GIF.
var app: Control

func _initialize() -> void:
	call_deferred("record")

func record() -> void:
	root.size = Vector2i(393, 852)
	root.content_scale_size = Vector2i(393, 852)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for shot in ["home", "moods"]:
		app.show_page(app.HOME, false, true)
		if shot == "moods":
			app.open_overlay("165:2525")
		await process_frame
		await process_frame
		DirAccess.make_dir_recursive_absolute("res://qa/motion-frames/" + shot)
		for frame in range(60):
			if frame == 18 and shot == "home":
				for character in get_nodes_in_group("otter_characters"):
					if character.is_visible_in_tree() and character.size.x > 180:
						character.react()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/motion-frames/%s/%03d.png" % [shot, frame])
			await process_frame
	print("OTTER_PREVIEW_OK")
	quit()
