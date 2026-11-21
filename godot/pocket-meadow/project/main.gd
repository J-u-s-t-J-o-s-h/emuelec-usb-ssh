extends Node3D
# Frame-rate-independent movement; no rigid-body simulation or imported assets.
const SAVE := "user://meadow.cfg"
const LIMIT := 29.0
const WALK_SPEED := 6.0
const STAR_POINTS := [
	Vector2(0,-4), Vector2(-4,-7), Vector2(-9,-7), Vector2(-15,-5),
	Vector2(-22,-3), Vector2(-24,-10), Vector2(-20,-17), Vector2(-13,-22),
	Vector2(-5,-24), Vector2(3,-22), Vector2(11,-20), Vector2(20,-18),
	Vector2(23,-10), Vector2(22,-3), Vector2(16,4), Vector2(22,12),
	Vector2(18,21), Vector2(10,24), Vector2(3,21), Vector2(-5,23),
	Vector2(-13,20), Vector2(-22,17), Vector2(-23,9), Vector2(-12,7),
]
var location := Vector2.ZERO
var motion := Vector2.ZERO
var found: Array[int] = []
var obstacles: Array[Vector3] = []
var clock := 0.0
var paused := false
var hop_time := 0.0
var feedback := 0.0
var avatar: Node3D
var body: Node3D
var camera: Camera3D
var stars: MultiMesh
var counter: Label
var message: Label
var sound: AudioStreamPlayer
var world_surface: SurfaceTool
var cube: BoxMesh
var trunk_mesh: CylinderMesh
var cone_mesh: CylinderMesh
var rock_mesh: SphereMesh
var benchmark := false
var test_start := 0
var test_frames := 0
var frame_samples: Array[float] = []

func _ready() -> void:
	get_tree().auto_accept_quit = false
	benchmark = "--benchmark" in OS.get_cmdline_user_args()
	if not benchmark:
		_load_progress()
	_build_world()
	_build_avatar()
	_build_stars()
	_build_hud()
	_build_sound()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23.0
	camera.near = 0.1
	camera.far = 80.0
	add_child(camera)
	_position_camera(1.0, true)
	_update_hud()
	print("MEADOW_READY ticks_ms=%d stars=%d" % [Time.get_ticks_msec(), STAR_POINTS.size()])
	if "--self-test" in OS.get_cmdline_user_args():
		call_deferred("_self_test")

func _process(delta: float) -> void:
	clock += delta
	feedback = maxf(0.0, feedback-delta)
	if not paused:
		var input := Vector2(
			float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
		if benchmark:
			input = Vector2(sin(clock*0.6), cos(clock*0.6))
		input = input.limit_length()
		motion = motion.move_toward(input*WALK_SPEED, 28.0*minf(delta,0.1))
		location = _resolve_position(location + motion*minf(delta,0.1))
		_collect_nearby()
		hop_time = maxf(0.0, hop_time-delta)
	avatar.position = Vector3(location.x,0.0,location.y)
	if motion.length() > 0.15 and not paused:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-motion.x,-motion.y), 1.0-exp(-delta*14.0))
	var walking := minf(motion.length()/WALK_SPEED,1.0) if not paused else 0.0
	body.position.y = absf(sin(clock*11.0))*0.085*walking
	if hop_time > 0:
		body.position.y += sin((1.0-hop_time/0.55)*PI)*0.9
	body.rotation.z = sin(clock*11.0)*0.045*walking
	_position_camera(delta)
	for i in STAR_POINTS.size():
		var point: Vector2 = STAR_POINTS[i]
		var scale := Vector3.ZERO if i in found else Vector3.ONE*0.48
		var basis := Basis(Vector3.UP,clock*1.3+i).scaled(scale)
		stars.set_instance_transform(i,Transform3D(basis,Vector3(point.x,0.95+sin(clock*2.2+i)*0.13,point.y)))
	if feedback <= 0 and not paused and found.size() < STAR_POINTS.size():
		message.text = "Explore the meadow and find the golden stars"
	if benchmark:
		if clock > 3.0:
			if test_start == 0:
				test_start = Time.get_ticks_usec()
				test_frames = Engine.get_process_frames()
			frame_samples.append(delta*1000.0)
		if clock > 23.0:
			frame_samples.sort()
			var elapsed := (Time.get_ticks_usec()-test_start)/1000000.0
			print("MEADOW_BENCH fps=%.2f median_ms=%.2f p95_ms=%.2f worst_ms=%.2f collected=%d" % [
				(Engine.get_process_frames()-test_frames)/elapsed,
				frame_samples[int(frame_samples.size()*0.5)],frame_samples[int(frame_samples.size()*0.95)],frame_samples[-1],found.size()])
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("user://meadow-benchmark.png")
			get_tree().quit(0)

func _resolve_position(next: Vector2) -> Vector2:
	next.x = clampf(next.x,-LIMIT,LIMIT)
	next.y = clampf(next.y,-LIMIT,LIMIT)
	# Soft circular obstacles let the player slide around trunks and rocks.
	for obstacle in obstacles:
		var offset := next-Vector2(obstacle.x,obstacle.y)
		if offset.length() < obstacle.z+0.35:
			if offset.length_squared() < 0.0001:
				offset = Vector2.RIGHT
			next = Vector2(obstacle.x,obstacle.y)+offset.normalized()*(obstacle.z+0.35)
	# Walk around the pond; there is no drowning or falling.
	var pond_offset := next-Vector2(12,-10)
	var ellipse := pond_offset/Vector2(6.5,4.5)
	if ellipse.length() < 1.0:
		if ellipse.length_squared() < 0.0001:
			ellipse = Vector2.RIGHT
		next = Vector2(12,-10)+ellipse.normalized()*Vector2(6.5,4.5)
	return next

func _collect_nearby() -> void:
	for i in STAR_POINTS.size():
		if i not in found and location.distance_to(STAR_POINTS[i]) < 1.2:
			found.append(i)
			sound.pitch_scale = 0.9+float(found.size()%5)*0.1
			sound.play()
			feedback = 2.0
			message.text = "A golden star!  %d / %d" % [found.size(),STAR_POINTS.size()]
			_update_hud()
			if not benchmark:
				_save_progress()
			print("MEADOW_PICKUP id=%d total=%d" % [i,found.size()])

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			if not benchmark:
				_save_progress()
			print("MEADOW_QUIT stars=%d" % found.size())
			get_tree().quit(0)
		KEY_P:
			paused = not paused
			motion = Vector2.ZERO
			_update_hud()
		KEY_ENTER, KEY_SPACE:
			if not paused:
				if found.size() == STAR_POINTS.size():
					found.clear()
					_save_progress()
					_update_hud()
				hop_time = 0.55

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not benchmark:
			_save_progress()
		get_tree().quit(0)

func _position_camera(delta: float, snap := false) -> void:
	var target := Vector3(location.x,0.0,location.y)
	var desired := target+Vector3(0,17,13)
	camera.position = desired if snap else camera.position.lerp(desired,1.0-exp(-delta*9.0))
	camera.rotation_degrees = Vector3(-52.6,0,0)

func _build_world() -> void:
	world_surface = SurfaceTool.new()
	world_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	cube = BoxMesh.new()
	trunk_mesh = CylinderMesh.new()
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1
	cone_mesh = CylinderMesh.new()
	cone_mesh.top_radius = 0
	cone_mesh.bottom_radius = 1
	cone_mesh.height = 2
	cone_mesh.radial_segments = 8
	cone_mesh.rings = 1
	rock_mesh = SphereMesh.new()
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 3
	_stamp(cube,Vector3(0,-0.3,0),Vector3(64,0.5,64),Color("#80bc63"))
	_stamp(cube,Vector3(0,-0.025,0),Vector3(3.2,0.04,59),Color("#e9cf94"))
	_stamp(cube,Vector3(0,-0.02,0),Vector3(59,0.04,3.2),Color("#e9cf94"))
	_stamp(trunk_mesh,Vector3(12,0.01,-10),Vector3(12,0.03,8),Color("#52b9cf"))
	_stamp(trunk_mesh,Vector3(12,0.03,-10),Vector3(10,0.03,6),Color("#70d2dd"))
	for i in 40:
		var angle := float(i)/40.0*TAU
		var point := Vector2(cos(angle),sin(angle))*(26.0 if i%3==0 else 30.5)
		_tree(point,1.0+float(i%4)*0.17)
	for point in [Vector2(-10,-14),Vector2(-17,-13),Vector2(-20,3),Vector2(9,10),Vector2(15,15),Vector2(-10,13)]:
		_tree(point,1.2)
	for point in [Vector2(-6,16),Vector2(-3,17),Vector2(20,-24),Vector2(23,-23)]:
		_stamp(rock_mesh,Vector3(point.x,0.55,point.y),Vector3(2.8,1.5,2),Color("#a0a6ab"))
		obstacles.append(Vector3(point.x,point.y,1.1))
	# A tiny cottage and a flower garden make recognizable destinations.
	_stamp(cube,Vector3(-18,1.25,-23),Vector3(5,2.5,4),Color("#eec69c"))
	_stamp(cone_mesh,Vector3(-18,3.1,-23),Vector3(4,1.2,3.2),Color("#ce6c69"))
	_stamp(cube,Vector3(-18,0.85,-20.95),Vector3(1.1,1.7,0.1),Color("#80634e"))
	obstacles.append(Vector3(-18,-23,2.7))
	for i in 18:
		var x := -24.0+float(i%6)*1.1
		var z := 20.0+float(i/6)*1.0
		_stamp(cone_mesh,Vector3(x,0.25,z),Vector3(0.25,0.3,0.25),Color("#e6a0b6") if i%2==0 else Color("#f6d56d"))
	var mesh := MeshInstance3D.new()
	mesh.mesh = world_surface.commit()
	mesh.material_override = _vertex_material()
	add_child(mesh)
	world_surface = null

func _tree(point: Vector2, size: float) -> void:
	_stamp(trunk_mesh,Vector3(point.x,0.65*size,point.y),Vector3(0.65,1.3,0.65)*size,Color("#9a7953"))
	_stamp(cone_mesh,Vector3(point.x,2.0*size,point.y),Vector3(1.65,1.4,1.65)*size,Color("#3e8962"))
	_stamp(cone_mesh,Vector3(point.x,3.1*size,point.y),Vector3(1.2,1.15,1.2)*size,Color("#61a56b"))
	obstacles.append(Vector3(point.x,point.y,0.48*size))

func _stamp(mesh: PrimitiveMesh, position: Vector3, scale: Vector3, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	var light := Vector3(-0.4,0.85,0.3).normalized()
	for i in vertices.size():
		var brightness := 0.73+0.27*maxf(0.0,normals[i].dot(light))
		colors[i] = Color(color.r*brightness,color.g*brightness,color.b*brightness)
	arrays[Mesh.ARRAY_COLOR] = colors
	var colored := ArrayMesh.new()
	colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	world_surface.append_from(colored,0,Transform3D(Basis.IDENTITY.scaled(scale),position))

func _vertex_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	return material

func _part(mesh: PrimitiveMesh, position: Vector3, scale: Vector3, color: Color, parent: Node3D) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	instance.material_override = material
	parent.add_child(instance)

func _build_avatar() -> void:
	avatar = Node3D.new()
	add_child(avatar)
	body = Node3D.new()
	avatar.add_child(body)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	_part(sphere,Vector3(0,0.65,0),Vector3(1,1.25,0.85),Color("#eaa66e"),body)
	_part(sphere,Vector3(0,1.4,-0.05),Vector3(0.85,0.85,0.8),Color("#f6cf9b"),body)
	_part(sphere,Vector3(-0.28,1.95,0),Vector3(0.24,0.7,0.24),Color("#f6cf9b"),body)
	_part(sphere,Vector3(0.28,1.95,0),Vector3(0.24,0.7,0.24),Color("#f6cf9b"),body)
	_part(sphere,Vector3(-0.17,1.47,-0.4),Vector3(0.09,0.11,0.07),Color("#3b3747"),body)
	_part(sphere,Vector3(0.17,1.47,-0.4),Vector3(0.09,0.11,0.07),Color("#3b3747"),body)
	_part(cube,Vector3(0,0.85,0.3),Vector3(0.65,0.7,0.35),Color("#6b83b4"),body)

func _build_stars() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var angle := TAU*float(i)/10.0
		var next_angle := TAU*float(i+1)/10.0
		var radius := 1.0 if i%2==0 else 0.46
		var next_radius := 1.0 if (i+1)%2==0 else 0.46
		var edge := Vector3(sin(angle)*radius,cos(angle)*radius,0)
		var next_edge := Vector3(sin(next_angle)*next_radius,cos(next_angle)*next_radius,0)
		for face in [1.0,-1.0]:
			surface.set_color(Color("#ffe08a") if i%2==0 else Color("#efb64f"))
			surface.add_vertex(Vector3(0,0,0.22*face))
			surface.add_vertex(edge if face>0 else next_edge)
			surface.add_vertex(next_edge if face>0 else edge)
	var star_mesh := surface.commit()
	stars = MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	stars.mesh = star_mesh
	stars.instance_count = STAR_POINTS.size()
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = stars
	var material := _vertex_material()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	add_child(instance)

func _label(text: String, y: float, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(12,y)
	label.size = Vector2(696,42)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("#fff6db"))
	label.add_theme_color_override("font_shadow_color",Color("#35434e"))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	hud.add_child(_label("POCKET MEADOW",16,30))
	counter = _label("",55,24)
	hud.add_child(counter)
	message = _label("",619,20)
	hud.add_child(message)
	hud.add_child(_label("A: hop   Start: pause   Select: save & quit",670,17))

func _update_hud() -> void:
	counter.text = "Golden stars: %d / %d" % [found.size(),STAR_POINTS.size()]
	message.text = "PAUSED — Start to continue" if paused else "Explore the meadow and find the golden stars"
	if not paused and found.size()==STAR_POINTS.size():
		message.text = "You found them all!  A starts a new adventure"

func _build_sound() -> void:
	var bytes := PackedByteArray()
	bytes.resize(4410)
	for i in 2205:
		var t := float(i)/22050.0
		bytes.encode_s16(i*2,int(sin(TAU*880*t)*sin(PI*t/0.1)*3500))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	sound = AudioStreamPlayer.new()
	sound.stream = stream
	add_child(sound)

func _save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("meadow","found",found)
	save.set_value("meadow","position",location)
	var error := save.save(SAVE)
	if error != OK:
		push_error("MEADOW_SAVE_FAILED error=%d" % error)

func _load_progress() -> void:
	var save := ConfigFile.new()
	if save.load(SAVE) != OK:
		return
	var loaded = save.get_value("meadow","found",[])
	if loaded is Array:
		for value in loaded:
			if value is int and value>=0 and value<STAR_POINTS.size() and value not in found:
				found.append(value)
	var point = save.get_value("meadow","position",Vector2.ZERO)
	if point is Vector2 and is_finite(point.x) and is_finite(point.y):
		location = Vector2(clampf(point.x,-LIMIT,LIMIT),clampf(point.y,-LIMIT,LIMIT))

func _self_test() -> void:
	await get_tree().process_frame
	var previous := found.duplicate()
	found.clear()
	location = STAR_POINTS[0]
	_collect_nearby()
	assert(found == [0], "pickup")
	_collect_nearby()
	assert(found == [0], "duplicate pickup")
	assert(_resolve_position(Vector2(50,50)).x <= LIMIT, "boundary")
	assert((_resolve_position(Vector2(12,-10))-Vector2(12,-10)).length() >= 4.5, "pond")
	var event := InputEventKey.new()
	event.keycode = KEY_P
	event.pressed = true
	_unhandled_input(event)
	assert(paused, "pause")
	_unhandled_input(event)
	assert(not paused, "resume")
	_save_progress()
	found.clear()
	_load_progress()
	assert(found == [0], "save reload")
	found.assign(previous)
	print("MEADOW_SELF_TEST_PASS")
	get_tree().quit(0)
