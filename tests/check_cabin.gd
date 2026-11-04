extends SceneTree
## Presentation checks plus real solid-barrier contact. No authentication.
var game: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CABIN FAIL: " + detail)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.manual_inputs = true
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "room UI starts accessible")
	check(game.car.get_child(0).shape.size == game.TUNING.body_size, "original collision size retained")
	for index in 4:
		check(game.car.wheels[index].position.distance_to(game.TUNING.wheel_positions[index]) < 0.001, "visual wheel centered on unchanged force position")
		check(game.car.wheel_materials[index].albedo_texture != null and game.car.wheel_materials[index].emission_texture != null, "supplied diffuse and emissive textures imported")
	var bounds := AABB()
	for part in game.car.visual.get_node("Model").get_children():
		if part is MeshInstance3D:
			var part_bounds: AABB = part.transform * part.get_aabb()
			bounds = bounds.merge(part_bounds)
	check(bounds.position.x >= -game.TUNING.body_size.x / 2 - 0.001 and bounds.end.x <= game.TUNING.body_size.x / 2 + 0.001, "visual width within collision footprint")
	check(bounds.position.z >= -game.TUNING.body_size.z / 2 - 0.001 and bounds.end.z <= game.TUNING.body_size.z / 2 + 0.001, "visual length within collision footprint")

	if DisplayServer.get_name() != "headless":
		for frame in 3:
			await process_frame
		var click := InputEventMouseButton.new()
		click.position = game.hud.code_edit.get_global_rect().get_center()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		Input.parse_input_event(click.duplicate())
		await process_frame
		check(game.hud.code_edit.has_focus() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "room code UI takes click without capture")
		click.pressed = false
		Input.parse_input_event(click.duplicate())
		click.position = Vector2(640, 350)
		click.pressed = true
		Input.parse_input_event(click.duplicate())
		for frame in 3:
			await process_frame
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not game.hud.room_panel.visible, "viewport click captures and clears room overlay")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/captured-cabin.png")
		click.pressed = false
		Input.parse_input_event(click.duplicate())
		var release := InputEventKey.new()
		release.physical_keycode = KEY_ESCAPE
		release.pressed = true
		Input.parse_input_event(release.duplicate())
		for frame in 3:
			await process_frame
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and game.hud.room_panel.visible, "Escape through input pipeline restores room UI")
		release.pressed = false
		Input.parse_input_event(release.duplicate())
	for count in range(1, 5):
		game.set_local_count(count)
		for slot in count:
			game.hud.local_slot_changed.emit(slot)
			await process_frame
			game._update_seated_view()
			check(game.camera.position.distance_to(game.car.to_global(game.car.seat_position(slot))) < 0.001, "camera at assigned seat")
			for index in 4:
				check(game.car.passengers[index].visible == (index < count and index != slot), "occupied friends only; local head hidden")
	# Local view cannot affect body pose; yaw wraps and pitch clamps.
	var before: Transform3D = game.car.global_transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(2500, -2500)
	game._input(motion)
	check(absf(game.look_pitch) <= 1.15 and absf(game.look_yaw) <= PI, "bounded free look")
	check(game.car.global_transform == before, "look leaves car pose unchanged")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases mouse")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and game._blocked_keys == 15, "focus loss releases and gates keys")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.request_reset()
	check(game.look_pitch == 0 and game.look_yaw == 0, "reset restores forward view")
	game.set_local_count(1)
	await physics_frame
	await process_frame
	# Start before each barrier, then use real wheel forces into the solid body.
	for side in [false, true]:
		var bay: Vector3 = game.TUNING.bay_position
		game.car.global_transform = Transform3D(Basis(Vector3.UP, -PI / 2 if side else 0.0), bay + Vector3(0, 0.56, 0))
		game.car.linear_velocity = Vector3.ZERO
		game.car.angular_velocity = Vector3.ZERO
		for tick in 180:
			await physics_frame
			game._sequence += 1
			game.controls.submit(1, SharedControls.drive(SharedControls.WHEELS, 1), game._sequence, game.controls.epoch, Time.get_ticks_msec() / 1000.0)
			await process_frame
		var offset: Vector3 = game.car.position - bay
		print("BARRIER CONTACT side=", side, " offset=", offset, " speed=", game.car.speed)
		check(offset.x > 0.1 and offset.x < 0.5 if side else offset.z < -0.7 and offset.z > -1.5, "actual barrier stops driven car before penetration")
		check(absf(game.car.speed) < 0.1, "car rests against barrier under drive")
		game.look_yaw = 1.0
		game.request_reset()
		await physics_frame
		await process_frame
		check(game.car.position.distance_to(game.TUNING.start_position) < 0.05 and game.look_yaw == 0, "reset clears contact and look")
	print("CABIN CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
