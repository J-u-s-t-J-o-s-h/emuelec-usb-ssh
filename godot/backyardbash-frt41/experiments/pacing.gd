extends SceneTree
var game
var measuring := false
var samples: Array[float] = []
var previous := 0
func _initialize() -> void:
	process_frame.connect(_frame)
	call_deferred("_run")
func _frame() -> void:
	var now := Time.get_ticks_usec()
	if measuring and previous > 0:
		samples.append((now - previous) / 1000.0)
	previous = now
func _run() -> void:
	Engine.max_fps = 60
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	game = current_scene
	game.selected_mode = 0
	game._confirm_selected_mode(-1, true)
	game._join_or_ready(-1, true)
	await create_timer(7.0).timeout
	for shrink in [3, 2]:
		for show_hud in [true, false]:
			game._restart_game()
			game._start_round()
			game.camera_entries[0].container.stretch_shrink = shrink
			game.hud.visible = show_hud
			game.hud.set_process(show_hud)
			await create_timer(2.0).timeout
			samples.clear()
			measuring = true
			var start := Time.get_ticks_usec()
			var frames := Engine.get_process_frames()
			await create_timer(5.0).timeout
			measuring = false
			var fps := (Engine.get_process_frames() - frames) * 1000000.0 / (Time.get_ticks_usec()-start)
			samples.sort()
			print("PACING shrink=%d hud=%s fps=%.2f median_ms=%.2f p95_ms=%.2f max_ms=%.2f" % [shrink, show_hud, fps, samples[int(samples.size()*0.5)], samples[int(samples.size()*0.95)], samples[-1]])
	game._quit_to_batocera("pacing_complete")
