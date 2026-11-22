extends SceneTree
var game
func _initialize() -> void: call_deferred("_run")
func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func check(ok: bool, label: String) -> bool:
	print("JAM_CONTROL %s %s" % ["PASS" if ok else "FAIL",label])
	if not ok: quit(1)
	return ok
func _run() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	game = current_scene
	for i in 12:
		var before: int = game.hits
		key(game.BUTTONS[i],true)
		await create_timer(0.04).timeout
		if not check(game.hits==before+1 and game.glow[i]>0.5,"button %d sound/visual" % i): return
		key(game.BUTTONS[i],false)
		await process_frame
	var before: int = game.hits
	key(KEY_ENTER,true)
	await create_timer(0.2).timeout
	if not check(game.hits==before+1,"held button plays once"): return
	key(KEY_ENTER,false)
	for i in 4: key(game.BUTTONS[i],true)
	await create_timer(0.05).timeout
	var playing := 0
	for voice in game.voices:
		if voice.playing: playing += 1
	if not check(playing>=4,"overlapping audio voices"): return
	for i in 4: key(game.BUTTONS[i],false)
	key(KEY_P,true)
	await process_frame
	key(KEY_P,false)
	if not check(game.palette==1,"Start changes key"): return
	print("JAM_CONTROLS_COMPLETE")
	key(KEY_ESCAPE,true)
	await create_timer(1).timeout
	check(false,"Select failed to quit")
