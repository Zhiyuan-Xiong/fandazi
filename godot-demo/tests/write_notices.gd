extends SceneTree

func _initialize() -> void:
	var path := ProjectSettings.globalize_path("res://../demo/web/THIRD_PARTY_NOTICES.txt")
	var text := "Godot Engine and bundled third-party components\n\n"
	text += Engine.get_license_text() + "\n\n"
	text += "Copyright information\n" + JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\n"
	var licenses := Engine.get_license_info()
	for name in licenses:
		text += str(name) + "\n" + str(licenses[name]) + "\n\n"
	text += "Noto Sans SC\n" + FileAccess.get_file_as_string("res://assets/fonts/OFL.txt")
	FileAccess.open(path, FileAccess.WRITE).store_string(text)
	print("THIRD_PARTY_NOTICES_WRITTEN")
	quit()
