extends SceneTree
## Offline, interactive character preview using the real playable and F3 controls.
## --capture-only verifies all seat views then exits; default leaves a window open.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_title("Who's Driving? — LOCAL DUMMY DEMO")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	var palette := ["yellow", "red", "blue", "green"]
	for index in 4:
		var passenger: Node3D = game.car.passengers[index]
		for child in passenger.get_children():
			if child is MeshInstance3D:
				child.queue_free()
		var dummy := load("res://assets/player/crash_dummy.glb").instantiate() as Node3D
		dummy.name = "SeatedDummy"
		dummy.scale = Vector3.ONE * 1.2
		dummy.position.y = (-0.24 if index < 2 else -0.227) - passenger.position.y
		passenger.add_child(dummy)
		var material := load("res://assets/player/body_%s.tres" % palette[index]) as StandardMaterial3D
		for mesh in dummy.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				if mesh.mesh.surface_get_material(surface).resource_name == "Body_Repaint":
					mesh.set_surface_override_material(surface, material)
		var animation := dummy.find_child("AnimationPlayer", true, false) as AnimationPlayer
		animation.play("Sit")
		animation.advance(0.0)
	game.set_local_count(4)
	for frame in 6:
		await process_frame
	var capture_only := "--capture-only" in OS.get_cmdline_user_args()
	if capture_only:
		for slot in 4:
			game.hud.local_slot_changed.emit(slot)
			game.look_yaw = -PI / 2 if slot % 2 == 0 else PI / 2
			for frame in 4:
				await process_frame
			for index in 4:
				assert(game.car.passengers[index].visible == (index != slot))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/dummy-game-seat-%d.png" % (slot+1))
		print("DUMMY DEMO: all four native seat captures; local avatar hidden and three friends visible")
		quit(0)
	else:
		print("LOCAL DUMMY DEMO READY: four practice seats; F3 changes seat/count; no EOS login")
