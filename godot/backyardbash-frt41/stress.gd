extends SceneTree
var game
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	game = current_scene
	game._confirm_selected_mode(-1, true)
	game._join_or_ready(-1, true)
	await create_timer(7.0).timeout
	for mode in [0, 2]:
		game.selected_mode = mode
		game._restart_game()
		game._start_round()
		await create_timer(1.0).timeout
		var start := Time.get_ticks_msec()
		var frames := Engine.get_process_frames()
		if mode == 0:
			for index in 8:
				game.toy_cars[index].force_crush(game.truck)
		else:
			for index in 24:
				game._smash_castle_piece(index, game.truck)
		await create_timer(8.0).timeout
		print("FRT_STRESS mode=%d fps=%.2f score=%s" % [mode, (Engine.get_process_frames()-frames) * 1000.0 / (Time.get_ticks_msec()-start), game.player_scores])
	game._quit_to_batocera("stress_complete")
