extends TextureRect
## Animate only the original PNG. Its parent, labels and hit areas never move.
@export var pose_name := "Default"
var motion_enabled := true
var base_position := Vector2.ZERO
var base_scale := Vector2.ONE
var base_rotation := 0.0
var elapsed := 0.0
var phase := 0.0
var reaction_time := -1.0
var period := 3.6
var breath := 0.013
var bob := 0.005
var sway_degrees := 0.65
var lively := false
var sleepy := false
var initialized := false

func _ready() -> void:
	add_to_group("otter_characters")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_position = position
	base_scale = scale
	base_rotation = rotation
	pivot_offset = size * Vector2(0.5, 0.88)
	phase = fmod(float(str(get_meta("figma_id", name)).hash()), 997.0) / 997.0 * TAU
	configure_motion()
	var args := OS.get_cmdline_user_args()
	motion_enabled = not args.has("--no-motion") and (args.has("--motion-test") or not (args.has("--smoke") or args.has("--capture-all") or args.has("--capture") or args.has("--interaction-test")))
	initialized = true
	visibility_changed.connect(sync_visibility)
	sync_visibility()

func configure_motion() -> void:
	period = 3.6
	breath = 0.013
	bob = 0.005
	sway_degrees = 0.65
	lively = false
	sleepy = false
	match pose_name:
		"Happy", "Flutter", "Pleasure", "FaceHappy":
			period = 2.8
			bob = 0.010
			sway_degrees = 1.1
			lively = true
		"Eat":
			period = 2.3
			bob = 0.004
			breath = 0.018
			sway_degrees = 1.25
		"Wave":
			period = 3.0
			bob = 0.007
			sway_degrees = 1.8
			lively = true
		"Sleepy", "LieDown":
			period = 5.2
			breath = 0.020
			bob = 0.001
			sway_degrees = 0.3
			sleepy = true
		"Tired", "Sad", "Disappointed":
			period = 4.6
			bob = 0.002
			sway_degrees = 0.45
		"Anxiety", "Stress", "Angry":
			period = 3.1
			bob = 0.002
			sway_degrees = 0.85
		"Peaceful":
			period = 4.4
			sway_degrees = 0.4

func sync_visibility() -> void:
	if not initialized:
		return
	set_process(motion_enabled and is_visible_in_tree())
	if not is_processing():
		reaction_time = -1.0
		reset_pose()

func reset_pose() -> void:
	position = base_position
	scale = base_scale
	rotation = base_rotation

func react() -> void:
	if motion_enabled and is_visible_in_tree():
		# Replace the previous response instead of stacking tweens on repeated taps.
		reaction_time = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	if reaction_time >= 0.0:
		reaction_time += delta
		if reaction_time >= 0.8:
			reaction_time = -1.0
	apply_pose()

func apply_pose() -> void:
	var angle := elapsed * TAU / period + phase
	# Fade into the loop on first appearance so the authored pose never snaps.
	var fade := smoothstep(0.0, 0.45, elapsed)
	var breathing := sin(angle) * breath * fade
	var offset := Vector2(0, -(0.5 - 0.5 * cos(angle)) * size.y * bob * fade)
	var stretch := Vector2(1.0 - breathing * 0.35, 1.0 + breathing)
	var tilt := deg_to_rad(sway_degrees) * sin(angle * 0.5 + phase) * fade
	if lively:
		offset.y -= pow(maxf(0.0, sin(angle)), 4.0) * minf(1.4, size.y * 0.008) * fade
	if reaction_time >= 0.0:
		var progress := reaction_time / 0.8
		var envelope := sin(PI * progress)
		var energy := 0.35 if sleepy else 1.0
		offset.y -= envelope * minf(6.0, size.y * 0.024) * energy
		stretch += Vector2(-0.018, 0.025) * sin(TAU * progress) * envelope * energy
		tilt += deg_to_rad(2.0) * sin(TAU * progress) * envelope * energy
	position = base_position + offset
	scale = base_scale * stretch
	rotation = base_rotation + tilt
