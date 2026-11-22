extends Node3D
# Frame-rate-independent movement; no rigid-body simulation or imported assets.
const SAVE := "user://maze.cfg"
const CELL := 3.0
const WIDTH := 15
const WALK_SPEED := 6.0
var STAR_POINTS: Array[Vector2] = []
var grid: Array[String] = []
var key_points: Array[Vector2] = []
var keys: Array[int] = []
var key_models: Array[Node3D] = []
var stage := 0
var won := false
var exit_point := Vector2.ZERO
var route: Array[Vector2] = []
var route_index := 0
var route_direction := 1
var exit_model: Node3D
var title: Label
var hud_state := Vector4i(-1,-1,-1,-1)
var location := Vector2.ZERO
var motion := Vector2.ZERO
var found: Array[int] = []
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
var benchmark := false
var test_start := 0
var test_frames := 0
var previous_frame_tick := 0
var frame_samples: Array[float] = []

func _ready() -> void:
	get_tree().auto_accept_quit = false
	if "--benchmark" not in OS.get_cmdline_user_args():
		var config := ConfigFile.new()
		if config.load(SAVE) == OK:
			stage = clampi(int(config.get_value("maze","stage",0)),0,2)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-stage="):
			stage = clampi(int(arg.get_slice("=",1)),0,2)
	_generate_maze()
	location = _point(Vector2i(1,1))
	benchmark = "--benchmark" in OS.get_cmdline_user_args()
	if not benchmark:
		_load_progress()
	_build_world()
	_build_avatar()
	_build_stars()
	_build_keys_exit()
	_build_hud()
	_build_sound()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25.0
	camera.near = 0.1
	camera.far = 80.0
	add_child(camera)
	_position_camera(1.0, true)
	_update_hud()
	print("MAZE_READY ticks_ms=%d stars=%d startup_viewport=%s stage=%d" % [Time.get_ticks_msec(), STAR_POINTS.size(),get_viewport().size,stage])
	if "--self-test" in OS.get_cmdline_user_args():
		call_deferred("_self_test")

func _process(delta: float) -> void:
	var frame_tick := Time.get_ticks_usec()
	var wall_frame_ms := (frame_tick-previous_frame_tick)/1000.0 if previous_frame_tick else 0.0
	previous_frame_tick = frame_tick
	clock += delta
	feedback = maxf(0.0, feedback-delta)
	if not paused and not won:
		var input := Vector2(
			float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
		if benchmark:
			var target := route[route_index]
			if location.distance_to(target) < 0.15:
				route_index += route_direction
				if route_index >= route.size() or route_index < 0:
					route_direction *= -1
					route_index = clampi(route_index,0,route.size()-1)
				target = route[route_index]
			input = (target-location).normalized()
		input = input.limit_length()
		motion = motion.move_toward(input*WALK_SPEED, 28.0*minf(delta,0.1))
		var step := motion*minf(delta,0.05)
		# Axis-separated player-box-vs-grid collision; small steps prevent tunnelling.
		var candidate := location+Vector2(step.x,0)
		if _walkable(candidate): location.x = candidate.x
		candidate = location+Vector2(0,step.y)
		if _walkable(candidate): location.y = candidate.y
		_collect_nearby()
		_collect_keys_exit()
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
	if feedback <= 0:
		_update_hud()
	for i in key_models.size():
		key_models[i].visible = i not in keys
		key_models[i].rotation.y = clock*1.5
	exit_model.scale = Vector3.ONE*(1.0+0.04*sin(clock*3.0)) if keys.size()==3 else Vector3.ONE
	if benchmark:
		if clock > 3.0:
			if test_start == 0:
				test_start = Time.get_ticks_usec()
				test_frames = Engine.get_process_frames()
			frame_samples.append(wall_frame_ms)
		if clock > 23.0:
			frame_samples.sort()
			var elapsed := (Time.get_ticks_usec()-test_start)/1000000.0
			print("MAZE_BENCH fps=%.2f median_ms=%.2f p95_ms=%.2f worst_ms=%.2f collected=%d" % [
				(Engine.get_process_frames()-test_frames)/elapsed,
				frame_samples[int(frame_samples.size()*0.5)],frame_samples[int(frame_samples.size()*0.95)],frame_samples[-1],found.size()])
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png("user://maze-benchmark.png")
			get_tree().quit(0)

func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell-Vector2i(7,7))*CELL

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x/CELL)+7,roundi(point.y/CELL)+7)

func _open(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<WIDTH and cell.y<WIDTH and grid[cell.y][cell.x]=="."

func _walkable(point: Vector2) -> bool:
	for offset in [Vector2(-0.4,-0.4),Vector2(0.4,-0.4),Vector2(-0.4,0.4),Vector2(0.4,0.4)]:
		if not _open(_cell(point+offset)): return false
	return true

func _generate_maze() -> void:
	grid.clear()
	STAR_POINTS.clear()
	key_points.clear()
	route.clear()
	for y in WIDTH: grid.append("#".repeat(WIDTH))
	var rng := RandomNumberGenerator.new()
	rng.seed = 437+stage*7919
	var stack: Array[Vector2i] = [Vector2i(1,1)]
	grid[1][1] = "."
	while not stack.is_empty():
		var current := stack[-1]
		var options: Array[Vector2i] = []
		for dir in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
			var cell: Vector2i = current+dir
			if cell.x>0 and cell.y>0 and cell.x<WIDTH-1 and cell.y<WIDTH-1 and not _open(cell):
				options.append(cell)
		if options.is_empty():
			stack.pop_back()
		else:
			var next := options[rng.randi_range(0,options.size()-1)]
			var between := (current+next)/2
			grid[between.y][between.x] = "."
			grid[next.y][next.x] = "."
			stack.append(next)
	# Breadth-first traversal proves reachability and chooses a distant exit.
	var queue: Array[Vector2i] = [Vector2i(1,1)]
	var parents := {Vector2i(1,1):Vector2i(1,1)}
	var head := 0
	while head<queue.size():
		var current := queue[head]
		head += 1
		for dir in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current+dir
			if _open(next) and not parents.has(next):
				parents[next] = current
				queue.append(next)
	exit_point = _point(queue[-1])
	for fraction in [0.3,0.55,0.8]:
		key_points.append(_point(queue[int(queue.size()*fraction)]))
	for i in 12:
		STAR_POINTS.append(_point(queue[2+i*7]))
	var cursor := queue[-1]
	while cursor != Vector2i(1,1):
		route.push_front(_point(cursor))
		cursor = parents[cursor]
	route.push_front(_point(Vector2i(1,1)))
	route_index = 0
	route_direction = 1

func _collect_keys_exit() -> void:
	for i in key_points.size():
		if i not in keys and location.distance_to(key_points[i])<0.85:
			keys.append(i)
			sound.pitch_scale = 1.5
			sound.play()
			if not benchmark: _save_progress()
			print("MAZE_KEY id=%d total=%d" % [i,keys.size()])
	if keys.size()==3 and location.distance_to(exit_point)<0.9 and not benchmark:
		won = true
		motion = Vector2.ZERO
		_save_progress()
		print("MAZE_WIN stage=%d" % stage)
	_update_hud()

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
			print("MAZE_PICKUP id=%d total=%d" % [i,found.size()])

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			if not benchmark:
				_save_progress()
			print("MAZE_QUIT stars=%d" % found.size())
			get_tree().quit(0)
		KEY_P:
			paused = not paused
			motion = Vector2.ZERO
			_update_hud()
		KEY_ENTER, KEY_SPACE:
			if not paused:
				if won:
					stage = (stage+1)%3
					found.clear()
					keys.clear()
					location = _point(Vector2i(1,1))
					_save_progress()
					get_tree().reload_current_scene()
					return
				hop_time = 0.55

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not benchmark:
			_save_progress()
		get_tree().quit(0)

func _position_camera(delta: float, snap := false) -> void:
	var overview := Input.is_key_pressed(KEY_BACKSPACE) or (benchmark and "--benchmark-map" in OS.get_cmdline_user_args())
	var target := Vector3.ZERO if overview else Vector3(location.x,0.0,location.y)
	var desired := target+Vector3(0,30,16)
	camera.size = lerpf(camera.size,54.0 if overview else 25.0,1.0-exp(-delta*8.0))
	camera.position = desired if snap else camera.position.lerp(desired,1.0-exp(-delta*12.0))
	camera.rotation_degrees = Vector3(-62.0,0,0)

func _build_world() -> void:
	world_surface = SurfaceTool.new()
	world_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	cube = BoxMesh.new()
	trunk_mesh = CylinderMesh.new()
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1
	cone_mesh = CylinderMesh.new()
	cone_mesh.top_radius = 0
	cone_mesh.radial_segments = 6
	cone_mesh.rings = 1
	var wall_color: Color = [Color("#54ad83"),Color("#a18cdb"),Color("#e99568")][stage]
	for y in WIDTH:
		for x in WIDTH:
			var p := _point(Vector2i(x,y))
			if not _open(Vector2i(x,y)):
				_stamp(cube,Vector3(p.x,0.52,p.y),Vector3(3,1.05,3),wall_color)
			else:
				_stamp(cube,Vector3(p.x,-0.15,p.y),Vector3(3,0.3,3),Color("#f2e4c7") if (x+y)%2==0 else Color("#e8d7aa"))
	var mesh := MeshInstance3D.new()
	mesh.mesh = world_surface.commit()
	mesh.material_override = _vertex_material()
	add_child(mesh)
	world_surface = null

func _begin_batch() -> void:
	world_surface = SurfaceTool.new()
	world_surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func _finish_batch(parent: Node3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = world_surface.commit()
	mesh.material_override = _vertex_material()
	parent.add_child(mesh)
	world_surface = null

func _build_keys_exit() -> void:
	for point in key_points:
		var model := Node3D.new()
		model.position = Vector3(point.x,0.9,point.y)
		add_child(model)
		_begin_batch()
		_stamp(cube,Vector3.ZERO,Vector3(0.6,0.6,0.6),Color("#64e7ed"))
		_stamp(cube,Vector3(0,-0.55,0),Vector3(0.18,0.7,0.18),Color("#64e7ed"))
		_stamp(cube,Vector3(0.18,-0.75,0),Vector3(0.4,0.16,0.18),Color("#64e7ed"))
		_finish_batch(model)
		key_models.append(model)
	exit_model = Node3D.new()
	exit_model.position = Vector3(exit_point.x,0,exit_point.y)
	add_child(exit_model)
	_begin_batch()
	for x in [-0.9,0.9]:
		_stamp(cube,Vector3(x,1,0),Vector3(0.25,2,0.25),Color("#d56c91"))
	_stamp(cube,Vector3(0,2,0),Vector3(2.1,0.3,0.3),Color("#f9cd6f"))
	_stamp(cube,Vector3(0,0.02,0),Vector3(1.8,0.04,1.8),Color("#f9cd6f"))
	_finish_batch(exit_model)

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

func _build_avatar() -> void:
	avatar = Node3D.new()
	add_child(avatar)
	body = Node3D.new()
	avatar.add_child(body)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	_begin_batch()
	_stamp(sphere,Vector3(0,0.65,0),Vector3(1,1.25,0.85),Color("#eaa66e"))
	_stamp(sphere,Vector3(0,1.4,-0.05),Vector3(0.85,0.85,0.8),Color("#f6cf9b"))
	_stamp(sphere,Vector3(-0.28,1.95,0),Vector3(0.24,0.7,0.24),Color("#f6cf9b"))
	_stamp(sphere,Vector3(0.28,1.95,0),Vector3(0.24,0.7,0.24),Color("#f6cf9b"))
	_stamp(sphere,Vector3(-0.17,1.47,-0.4),Vector3(0.09,0.11,0.07),Color("#3b3747"))
	_stamp(sphere,Vector3(0.17,1.47,-0.4),Vector3(0.09,0.11,0.07),Color("#3b3747"))
	_stamp(cube,Vector3(0,0.85,0.3),Vector3(0.65,0.7,0.35),Color("#6b83b4"))
	_finish_batch(body)

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
	hud.scale = Vector2.ONE*(float(ProjectSettings.get_setting("display/window/size/viewport_width"))/720.0)
	add_child(hud)
	title = _label("STARTRAIL MAZE",16,30)
	hud.add_child(title)
	counter = _label("",55,24)
	hud.add_child(counter)
	message = _label("",619,20)
	hud.add_child(message)
	hud.add_child(_label("A: hop   Hold B: map   Start: pause   Select: quit",670,17))

func _update_hud() -> void:
	var state := Vector4i(stage,keys.size(),found.size(),int(paused)+2*int(won))
	if state == hud_state: return
	hud_state = state
	title.text = ["CLOVER COURT","LAVENDER LANES","SUNSET GARDEN"][stage]
	counter.text = "Keys %d / 3     Stars %d / %d" % [keys.size(),found.size(),STAR_POINTS.size()]
	message.text = "PAUSED — Start to continue" if paused else "Find three blue keys to unlock the rainbow gate"
	if keys.size()==3 and not paused: message.text = "The gate is open! Find the rainbow arch"
	if won and not paused: message.text = "Maze complete! A begins the next garden"

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
	save.set_value("maze","stage",stage)
	save.set_value("maze","found",found)
	save.set_value("maze","keys",keys)
	save.set_value("maze","position",location)
	var error := save.save(SAVE)
	if error != OK: push_error("MAZE_SAVE_FAILED error=%d" % error)

func _load_progress() -> void:
	var save := ConfigFile.new()
	if save.load(SAVE) != OK: return
	found.clear()
	keys.clear()
	var loaded = save.get_value("maze","found",[])
	if loaded is Array:
		for value in loaded:
			if value is int and value>=0 and value<STAR_POINTS.size() and value not in found:
				found.append(value)
	loaded = save.get_value("maze","keys",[])
	if loaded is Array:
		for value in loaded:
			if value is int and value>=0 and value<3 and value not in keys:
				keys.append(value)
	var point = save.get_value("maze","position",location)
	if point is Vector2 and is_finite(point.x) and is_finite(point.y) and _walkable(point):
		location = point

func _check(ok: bool, label: String) -> bool:
	print("MAZE_CHECK %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: get_tree().quit(1)
	return ok

func _self_test() -> void:
	await get_tree().process_frame
	for level in 3:
		stage = level
		_generate_maze()
		if not _check(route.size()>10,"exit route"): return
		for p in route:
			if not _check(_walkable(p),"route walkable"): return
		for p in key_points+STAR_POINTS:
			if not _check(_walkable(p),"collectible walkable"): return
		if not _check(not _walkable(_point(Vector2i(0,0))),"wall blocks"): return
	stage = 0
	_generate_maze()
	found.clear()
	keys.clear()
	location = STAR_POINTS[0]
	_collect_nearby()
	if not _check(found==[0],"pickup"): return
	_collect_nearby()
	if not _check(found==[0],"no duplicate pickup"): return
	location = exit_point
	_collect_keys_exit()
	if not _check(not won,"locked exit"): return
	for point in key_points:
		location = point
		_collect_keys_exit()
	if not _check(keys.size()==3,"three keys"): return
	_save_progress()
	keys.clear()
	found.clear()
	_load_progress()
	if not _check(keys.size()==3 and found==[0],"save reload"): return
	location = exit_point
	_collect_keys_exit()
	if not _check(won,"exit unlocked"): return
	var event := InputEventKey.new()
	event.keycode = KEY_P
	event.pressed = true
	_unhandled_input(event)
	if not _check(paused,"pause"): return
	_unhandled_input(event)
	if not _check(not paused,"resume"): return
	print("MAZE_SELF_TEST_PASS")
	get_tree().quit(0)
