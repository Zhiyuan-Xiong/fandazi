@tool
extends "res://scripts/surface.gd"
## One reusable scene, with the four layouts exported from the Figma tab states.
@export_enum("食宠", "日记", "计划", "健康指数") var active_tab: int = 0

func _ready() -> void:
	super._ready()
	for i in range(4):
		get_node("State%d" % i).visible = i == active_tab
