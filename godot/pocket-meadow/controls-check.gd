extends SceneTree
var game
func _initialize() -> void:
	call_deferred("_run")
func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func check(ok: bool, label: String) -> bool:
	print("MEADOW_CONTROL %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok:
		quit(1)
	return ok
func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	game = current_scene
	game.location = Vector2.ZERO
	var start: Vector2 = game.location
	key(KEY_RIGHT,true)
	await create_timer(0.7).timeout
	key(KEY_RIGHT,false)
	if not check(game.location.x > start.x+1.0,"right movement"): return
	key(KEY_UP,true)
	await create_timer(0.7).timeout
	key(KEY_UP,false)
	if not check(game.location.y < start.y-1.0,"up movement"): return
	key(KEY_ENTER,true)
	await create_timer(0.1).timeout
	key(KEY_ENTER,false)
	if not check(game.hop_time > 0.0,"A hop"): return
	key(KEY_P,true)
	await create_timer(0.1).timeout
	key(KEY_P,false)
	if not check(game.paused,"Start pause"): return
	start = game.location
	key(KEY_RIGHT,true)
	await create_timer(0.4).timeout
	key(KEY_RIGHT,false)
	if not check(game.location.is_equal_approx(start),"paused movement blocked"): return
	key(KEY_P,true)
	await create_timer(0.1).timeout
	key(KEY_P,false)
	if not check(not game.paused,"Start resume"): return
	for point in game.STAR_POINTS:
		if not check(game._resolve_position(point).distance_to(point)<1.2,"collectible reachable"): return
	game.found.clear()
	game.location = game.STAR_POINTS[0]
	game._collect_nearby()
	if not check(game.found == [0],"pickup"): return
	game._load_progress()
	if not check(game.found == [0],"saved pickup reload"): return
	print("MEADOW_CONTROLS_COMPLETE")
	key(KEY_ESCAPE,true)
	await create_timer(1.0).timeout
	check(false,"Select failed to quit")
