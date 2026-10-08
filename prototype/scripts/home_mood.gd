extends "res://scripts/otter_motion.gd"
## The existing home bubble slot mirrors the exact artwork chosen in the mood sheet.
## Variable IDs and PNGs are from Figma frame 165:2525, including all hidden states.
const MOODS := [
	["VariableID:147:4", "Happy", preload("res://assets/figma/5b0428c7ffb8adf023e7.png")],
	["VariableID:147:5", "Flutter", preload("res://assets/figma/e6eaf49d8fa79e730b99.png")],
	["VariableID:147:6", "Pleasure", preload("res://assets/figma/bdccb3b3927f0682bcea.png")],
	["VariableID:147:7", "Peaceful", preload("res://assets/figma/ce50a52faa467d07e026.png")],
	["VariableID:147:8", "Normal", preload("res://assets/figma/43e813f1f43d837465eb.png")],
	["VariableID:147:9", "Tired", preload("res://assets/figma/5c0ad3b62c7cdd82b8df.png")],
	["VariableID:147:10", "Sad", preload("res://assets/figma/1c0b659b9b90dda77b69.png")],
	["VariableID:147:11", "Anxiety", preload("res://assets/figma/7c58acdd1bce7f4186fd.png")],
	["VariableID:147:12", "Angry", preload("res://assets/figma/86b258f97cdea9cf81d7.png")],
	["VariableID:147:13", "Disappointed", preload("res://assets/figma/1bae4afb53de1cf37e45.png")],
	["VariableID:147:14", "Stress", preload("res://assets/figma/d682fc802b0b76e8b314.png")],
	["VariableID:147:15", "Sleepy", preload("res://assets/figma/5883a903c162b5380782.png")],
]

func _ready() -> void:
	# The source's lone Normal slot used to disappear for every other mood.
	var bindings: Dictionary = get_parent().get_meta("bindings", {}).duplicate(true)
	bindings.erase("visible")
	get_parent().set_meta("bindings", bindings)
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	super._ready()

func sync_mood(values: Dictionary) -> void:
	var selected: Array = MOODS[4]
	for mood in MOODS:
		if values.get(mood[0], false):
			selected = mood
			break
	get_parent().show()
	if pose_name == selected[1] and texture == selected[2]: return
	pose_name = selected[1]
	texture = selected[2]
	configure_motion()
	elapsed = 0.0
	reaction_time = -1.0
	reset_pose()
