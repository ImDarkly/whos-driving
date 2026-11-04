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
	if "--record-motion" in OS.get_cmdline_user_args():
		await _record_motion(game)
		return
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

func _record_motion(game: Node3D) -> void:
	var rigs: Array[Skeleton3D] = []
	var seated: Array = []
	var reaching: Array = []
	for passenger in game.car.passengers:
		var dummy: Node3D = passenger.get_node("SeatedDummy")
		var rig := dummy.find_child("Skeleton3D", true, false) as Skeleton3D
		var player := dummy.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var sit: Array[Quaternion] = []
		var steer: Array[Quaternion] = []
		player.play("Sit")
		player.advance(0.0)
		for bone in rig.get_bone_count():
			sit.append(rig.get_bone_pose_rotation(bone))
		player.play("Steer")
		player.advance(0.0)
		for bone in rig.get_bone_count():
			steer.append(rig.get_bone_pose_rotation(bone))
		player.stop(true)
		rigs.append(rig)
		seated.append(sit)
		reaching.append(steer)
	var caption := Label.new()
	caption.text = "SCRIPTED MOTION PREVIEW · local demo"
	caption.position = Vector2(390, 18)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	game.hud.add_child(caption)
	# Four fixed-seat shots, four seconds each at movie mode's fixed 30 fps.
	for frame in 480:
		var slot := frame / 120
		var t := float(frame) / 30.0
		if frame % 120 == 0:
			game.hud.local_slot_changed.emit(slot)
		game.look_yaw = (-PI / 2 if slot % 2 == 0 else PI / 2) + .18 * sin(t * .8)
		game.look_pitch = -.08
		for index in 4:
			var rig := rigs[index]
			var reach := .5 + .5 * sin(t * 1.8 + index * 1.3)
			for bone in rig.get_bone_count():
				rig.set_bone_pose_rotation(bone, seated[index][bone].slerp(reaching[index][bone], reach))
			var head := rig.find_bone("Head")
			rig.set_bone_pose_rotation(head, seated[index][head] * Quaternion(Vector3.UP, .72 * sin(t * 1.4 + index * 1.2)))
		await process_frame
		if frame % 120 == 60:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://build/dummy-motion-seat-%d.png" % (slot+1))
	print("DUMMY MOTION RECORDED: 480 scripted motion frames, four seats; no gameplay animation or gaze replication")
	quit(0)
