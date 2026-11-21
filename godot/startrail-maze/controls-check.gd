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
	print("MAZE_CONTROL %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: quit(1)
	return ok
func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	game = current_scene
	game.location = game._point(Vector2i(1,1))
	game.won = false
	var start: Vector2 = game.location
	var direction: Vector2 = game.route[1]-start
	var code := KEY_RIGHT if direction.x>0 else KEY_DOWN
	key(code,true)
	await create_timer(0.4).timeout
	print("MAZE_INPUT start=%s end=%s direction=%s key=%d pressed=%s" % [start,game.location,direction,code,Input.is_key_pressed(code)])
	key(code,false)
	if not check(game.location.distance_to(start)>0.8,"keyboard walking"): return
	key(KEY_ENTER,true)
	await create_timer(0.1).timeout
	key(KEY_ENTER,false)
	if not check(game.hop_time>0,"A hop"): return
	key(KEY_P,true)
	await create_timer(0.1).timeout
	key(KEY_P,false)
	if not check(game.paused,"Start pause"): return
	start = game.location
	key(code,true)
	await create_timer(0.4).timeout
	key(code,false)
	if not check(game.location.is_equal_approx(start),"paused movement blocked"): return
	key(KEY_P,true)
	await create_timer(0.1).timeout
	key(KEY_P,false)
	key(KEY_BACKSPACE,true)
	await create_timer(0.6).timeout
	if not check(game.camera.size>50,"B overview"): return
	key(KEY_BACKSPACE,false)
	game.location = game._point(Vector2i(1,1))
	game.motion = Vector2.ZERO
	key(KEY_LEFT,true)
	await create_timer(0.6).timeout
	key(KEY_LEFT,false)
	if not check(game.location.x>game._point(Vector2i(1,1)).x-1.2,"wall collision"): return
	game.keys.clear()
	game.location = game.exit_point
	game._collect_keys_exit()
	if not check(not game.won,"exit needs keys"): return
	game.keys.assign([0,1,2])
	game._collect_keys_exit()
	if not check(game.won,"unlocked exit wins"): return
	var next_stage: int = (game.stage+1)%3
	key(KEY_ENTER,true)
	await create_timer(0.5).timeout
	key(KEY_ENTER,false)
	game = current_scene
	if not check(game.stage==next_stage and game.keys.is_empty(),"A next maze"): return
	if not check(game.location.is_equal_approx(game._point(Vector2i(1,1))),"next maze starts at entrance"): return
	print("MAZE_CONTROLS_COMPLETE")
	key(KEY_ESCAPE,true)
	await create_timer(1).timeout
	check(false,"Select failed to quit")
