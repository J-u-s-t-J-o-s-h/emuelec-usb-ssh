extends Node3D
# FRT smoke test: 12 rigid bodies + FPS readout; logs FPS and inputs to stderr; quits after 45 s.

const RUN_SECONDS := 45.0
var label: Label
var elapsed := 0.0
var since_print := 0.0
var bodies: Array = []

func _ready() -> void:
	printerr("SMOKE start, renderer=", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_video_adapter_vendor())
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 10)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var ground := StaticBody3D.new()
	var gshape := CollisionShape3D.new()
	gshape.shape = BoxShape3D.new()
	(gshape.shape as BoxShape3D).size = Vector3(20, 1, 20)
	ground.add_child(gshape)
	var gmesh := MeshInstance3D.new()
	gmesh.mesh = BoxMesh.new()
	(gmesh.mesh as BoxMesh).size = Vector3(20, 1, 20)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.3, 0.7, 0.3)
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	ground.position = Vector3(0, -0.5, 0)
	add_child(ground)
	for i in 12:
		var rb := RigidBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.from_hsv(i / 12.0, 0.8, 0.9)
		mi.material_override = m
		rb.add_child(mi)
		add_child(rb)
		bodies.append(rb)
		_respawn(rb, i)
	label = Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 36)
	add_child(label)

func _respawn(rb: RigidBody3D, i: int) -> void:
	rb.linear_velocity = Vector3.ZERO
	rb.angular_velocity = Vector3(randf(), randf(), randf())
	rb.position = Vector3((i % 4) * 1.5 - 2.25, 4.0 + i * 0.8, (i / 4) * 1.5 - 1.5)

func _process(delta: float) -> void:
	elapsed += delta
	since_print += delta
	var fps := Engine.get_frames_per_second()
	label.text = "FPS %d   t=%ds" % [fps, int(elapsed)]
	if since_print >= 1.0:
		since_print = 0.0
		printerr("SMOKE t=", int(elapsed), " fps=", fps)
	for i in bodies.size():
		if bodies[i].position.y < -5.0 or randf() < 0.002:
			_respawn(bodies[i], i)
	if elapsed >= RUN_SECONDS:
		printerr("SMOKE done")
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		printerr("SMOKE input joy button ", event.button_index)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
		printerr("SMOKE input joy axis ", event.axis, " ", snappedf(event.axis_value, 0.1))
	elif event is InputEventKey and event.pressed:
		printerr("SMOKE input key ", OS.get_keycode_string(event.keycode))
