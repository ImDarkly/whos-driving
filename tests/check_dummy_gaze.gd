extends "res://tests/dummy_local_demo.gd"

func _start() -> void:
	super._start()
	create_timer(18).timeout.connect(func():
		push_error("GAZE TEST timed out on peer %d" % slot)
		quit(1)
	)
	_check.call_deferred()

func _marker(name: String) -> String:
	return "res://build/gaze-check-" + name

func _mark(name: String) -> void:
	var file := FileAccess.open(_marker(name), FileAccess.WRITE)
	file.store_string("ok")

func _wait(name: String) -> void:
	while not FileAccess.file_exists(_marker(name)):
		await process_frame

func _check() -> void:
	while game.controls.players.size() != 2 or (slot == 2 and not game._received_config):
		await process_frame
	await create_timer(.8).timeout
	var gaze: Node = game.get_node("DummyGaze")
	var local_yaw: float = -1.2 if slot == 1 else 1.3
	game.look_yaw = local_yaw
	game.look_pitch = .25 if slot == 1 else -.2
	var epoch: int = game.controls.epoch
	var origin: Vector3 = game.car.position
	var other: int = game.controls.players[1 if slot == 1 else 0]
	var index := 1 if slot == 1 else 0
	var rig: Skeleton3D = gaze._rigs[index]
	var head: int = gaze._heads[index]
	var initial: Array[Quaternion] = []
	for bone in rig.get_bone_count():
		initial.append(rig.get_bone_pose_rotation(bone))
	await create_timer(1.5).timeout
	assert(gaze.targets.has(other), "Remote gaze missing")
	var expected: float = 1.3 if slot == 1 else -1.2
	assert(absf(gaze.targets[other].x - expected) < .01, "Remote camera yaw was not replicated")
	assert(absf(game.look_yaw-local_yaw) < .001, "Remote gaze changed local camera")
	assert(game.car.position.distance_to(origin) < .01, "Head look moved car")
	assert(rig.get_bone_pose_rotation(head).angle_to(gaze._base[index]) > .6, "Remote head bone did not turn")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/gaze-peer-%d-turned.png" % slot)
	for bone in rig.get_bone_count():
		if bone != head:
			assert(rig.get_bone_pose_rotation(bone).angle_to(initial[bone]) < .001, "Head look moved seated body")
	_mark("pose-%d" % slot)
	await _wait("pose-%d" % (2 if slot == 1 else 1))
	if slot == 1:
		gaze._accept(other, 99.0, 99.0, 100000, epoch)
		assert(absf(gaze.targets[other].x) <= PI/2 and absf(gaze.targets[other].y) <= .65)
		var prior: Vector2 = gaze.targets[other]
		gaze._accept(other, NAN, 0.0, 100001, epoch)
		gaze._accept(other, 0.0, 0.0, 99999, epoch)
		gaze._accept(other, 0.0, 0.0, 100002, epoch-1)
		assert(gaze.targets[other] == prior, "Invalid/stale gaze accepted")
		game.request_reset()
	while game.controls.epoch == epoch:
		await process_frame
	await create_timer(.9).timeout
	assert(absf(game.look_yaw) < .001 and absf(game.look_pitch) < .001)
	assert(gaze.targets.get(other, Vector2.ONE).length() < .01, "Reset did not clear remote gaze")
	if slot == 2:
		game.look_yaw = -.9
		await create_timer(.4).timeout
		gaze.set_physics_process(false)
		_mark("stale")
		await _wait("done")
	else:
		await _wait("stale")
		await create_timer(1.2).timeout
		assert(rig.get_bone_pose_rotation(head).angle_to(gaze._base[index]) < .08, "Stale head did not return forward")
		_mark("done")
	print("GAZE PASS peer %d: remote head motion, independent camera, reset; host also bounds/order/epoch/stale" % slot)
	peer.close()
	quit(0)
