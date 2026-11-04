extends SceneTree
## Scripted feasibility check, NOT a driving aid or human playtest.
## Only submits owned commands; never teleports or changes motion/parking/tuning.

var game: Node3D
var sequence := 0
var failures := 0
const C = preload("res://scripts/shared_controls.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.manual_inputs = true
	await process_frame
	for count in range(1, 5):
		game.set_local_count(count)
		await _send(0)
		var aligned := true
		var arrived := false
		for leg in 4:
			var offset: Vector3 = game.TUNING.bay_position - game.car.position
			offset.y = 0
			if offset.length() < 0.25:
				arrived = true
				break
			aligned = await _turn(atan2(-offset.x, -offset.z)) and aligned
			for tick in 30:
				await _send(0)
			for tick in 1600:
				var remaining: float = (game.TUNING.bay_position - game.car.position).dot(-game.car.global_basis.z)
				if absf(remaining) < 0.10 and absf(game.car.speed) < 0.10:
					break
				var desired_speed := clampf(remaining * 1.2, -2.0, 2.0)
				var error: float = desired_speed - game.car.speed
				await _send(C.drive(C.WHEELS, int(signf(error)) if absf(error) > 0.06 else 0))
			for tick in 30:
				await _send(0)
		aligned = await _turn(0) and aligned
		for tick in 240:
			await _send(0)
		var ok: bool = aligned and arrived and game.parking.success
		print("COMMAND-ONLY PARKING ", count, "P ", "PASS" if ok else "FAIL", " position=", game.car.position, " yaw=", game.car.rotation.y)
		if not ok:
			failures += 1
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _turn(target: float) -> bool:
	for tick in 1200:
		var error := wrapf(target - game.car.rotation.y, -PI, PI)
		if absf(error) < 0.02 and absf(game.car.yaw_speed) < 0.07:
			return true
		var effort: float = 3.0 * error - 2.0 * game.car.yaw_speed
		var direction := int(signf(effort)) if absf(effort) > 0.015 else 0
		# Trio's rear wheels are one group; leave them neutral during a turn.
		var left := C.FL if game.controls.players.size() == 3 else C.LEFT
		var right := C.FR if game.controls.players.size() == 3 else C.RIGHT
		await _send(C.drive(left, -direction) | C.drive(right, direction))
	return false


func _send(mask: int) -> void:
	await physics_frame
	sequence += 1
	for id in game.controls.players:
		game.controls.submit(id, mask, sequence, game.controls.epoch, Time.get_ticks_msec() / 1000.0)
	await process_frame
