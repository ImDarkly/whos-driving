extends SceneTree
## Scripted feasibility check, NOT a driving aid or human playtest.
## Only submits owned commands; never teleports or changes motion/parking/tuning.

var game: Node3D
var sequence := 0
var failures := 0
var entered := false
var route_valid := true
var previous_position := Vector3.ZERO
var turned_right := false
var turned_left := false
const C = preload("res://scripts/shared_controls.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.manual_inputs = true
	await process_frame
	var counts := [2] if "--capture" in OS.get_cmdline_user_args() else [1, 2, 3, 4]
	for count in counts:
		game.set_local_count(count)
		await _send(0)
		entered = false
		route_valid = true
		turned_right = false
		turned_left = false
		previous_position = game.car.position
		await _capture("spawn")
		var aligned := true
		# Enter the lot, follow the aisle, then align into the target.
		# No car-state writes.
		var route := [Vector3(0, 0, game.lot.aisle_z), Vector3(5, 0, game.lot.aisle_z), game.TUNING.bay_position]
		for target in route:
			for leg in 4:
				var offset: Vector3 = target - game.car.position
				offset.y = 0
				if offset.length() < 0.16:
					break
				aligned = await _turn(atan2(-offset.x, -offset.z)) and aligned
				for tick in 30:
					await _send(0)
				for tick in 1600:
					var remaining: float = (target - game.car.position).dot(-game.car.global_basis.z)
					if absf(remaining) < 0.08 and absf(game.car.speed) < 0.08:
						break
					var desired_speed := clampf(remaining * 1.2, -1.4, 1.4)
					var error: float = desired_speed - game.car.speed
					await _send(C.drive(C.WHEELS, int(signf(error)) if absf(error) > 0.06 else 0))
				for tick in 30:
					await _send(0)
			aligned = aligned and Vector2(target.x - game.car.position.x, target.z - game.car.position.z).length() < 0.2
			await _capture("leg-%d" % route.find(target))
			print("ROUTE ", count, "P target=", target, " actual=", game.car.position)
		var arrived: bool = game.car.position.distance_to(game.TUNING.bay_position + Vector3(0, game.car.position.y, 0)) < 0.2
		aligned = await _turn(0) and aligned
		for tick in 240:
			await _send(0)
		await _capture("parked")
		var ok: bool = aligned and arrived and game.parking.success and route_valid and entered and turned_right and turned_left
		if not ok:
			print("DETAIL aligned=", aligned, " arrived=", arrived, " parked=", game.parking.success, " valid=", route_valid, " entered=", entered, " turns=", turned_right, "/", turned_left)
		print("COMMAND-ONLY PARKING ", count, "P ", "PASS" if ok else "FAIL", " position=", game.car.position, " yaw=", game.car.rotation.y)
		if not ok:
			failures += 1
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _turn(target: float) -> bool:
	for tick in 1200:
		var error := wrapf(target - game.car.rotation.y, -PI, PI)
		if absf(error) < 0.01 and absf(game.car.yaw_speed) < 0.015:
			return true
		var effort: float = 3.0 * error - 2.0 * game.car.yaw_speed
		var direction := int(signf(effort)) if absf(effort) > 0.015 else 0
		# Trio's rear wheels are one group; leave them neutral during a turn.
		var left := C.FL if game.controls.players.size() == 3 else C.LEFT
		var right := C.FR if game.controls.players.size() == 3 else C.RIGHT
		await _send(C.drive(left, -direction) | C.drive(right, direction))
	print("TURN TIMEOUT target=", target, " yaw=", game.car.rotation.y, " rate=", game.car.yaw_speed, " position=", game.car.position)
	return false


func _send(mask: int) -> void:
	await physics_frame
	sequence += 1
	for id in game.controls.players:
		game.controls.submit(id, game.controls.normalize(id, mask), sequence, game.controls.epoch, Time.get_ticks_msec() / 1000.0)
	await process_frame

	# Observe the physical trajectory, including every driven physics step.
	var at: Vector3 = game.car.position
	if previous_position.z >= game.lot.approach_back and at.z < game.lot.approach_back:
		entered = true
		if absf(at.x) > game.lot.entrance_width / 2:
			route_valid = false
	var on_driveway: bool = absf(at.x) < game.lot.entrance_width / 2 and at.z >= game.lot.approach_back and at.z < game.lot.approach_back + 5.5
	var in_lot: bool = at.x > game.lot.approach_left and at.x < game.lot.approach_right and at.z > game.lot.approach_end and at.z < game.lot.approach_back
	if not on_driveway and not in_lot:
		route_valid = false
	turned_right = turned_right or game.car.yaw_speed < -0.2
	turned_left = turned_left or (turned_right and game.car.yaw_speed > 0.2)
	previous_position = at


func _capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	var directory_error := DirAccess.make_dir_recursive_absolute("res://build")
	if directory_error != OK:
		failures += 1
		push_error("Could not create capture directory: %s" % error_string(directory_error))
		return
	for view in ["forward", "right"]:
		game.look_yaw = 0.0 if view == "forward" else -PI / 2
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://build/approach-%s-%s.png" % [label, view]
		var save_error := root.get_texture().get_image().save_png(path)
		if save_error != OK:
			failures += 1
			push_error("Could not save %s: %s" % [path, error_string(save_error)])
	game.look_yaw = 0.0
