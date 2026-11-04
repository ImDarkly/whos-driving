extends SceneTree
## Short native graphical run that captures the actual viewport for visual QA.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute("res://build")
	var ignore := FileAccess.open("res://build/.gdignore", FileAccess.WRITE)
	ignore.close()
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/local-playable.png")
	game.set_local_count(4)
	game.hud.debug_panel.visible = true
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/channel-debug.png")
	game.manual_inputs = true
	for frame in 25:
		for id in game.controls.players:
			game._sequence += 1
			game.controls.submit(id, SharedControls.drive(SharedControls.FL, 1) | SharedControls.drive(SharedControls.FR, -1), game._sequence, game.controls.epoch, Time.get_ticks_msec() / 1000.0)
		await physics_frame
	game.hud.debug_panel.visible = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/wheel-commands.png")
	game.set_local_count(1)
	game.hud.debug_panel.visible = false
	await physics_frame
	await process_frame
	game.car.global_position = game.TUNING.bay_position + Vector3(0, 0.56, 0)
	for frame in 100:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/parking-success.png")
	print("PREVIEW CAPTURED: build/local-playable.png, channel-debug.png, wheel-commands.png, parking-success.png")
	quit(0 if game.parking.success else 1)
