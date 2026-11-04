extends SceneTree
## Run with --headless --path . --script tests/check_playable.gd --fixed-fps 60
## Uses the actual scene, physics, input sampler and parking code. No EOS login.

var game: Node3D
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	checks += 1


func _run() -> void:
	_test_ownership()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.manual_inputs = true
	await process_frame
	await _drive(0, 3)
	_check(game.car.is_on_floor(), "real 3D floor collision")
	var start: Vector3 = game.car.position
	await _drive(SharedControls.W, 60)
	_check(game.car.position.z < start.z - 1.0 and game.car.speed > 3.0, "W moves forward")
	var saw_zero := false
	for tick in 55:
		var before: float = game.car.speed
		await _drive(SharedControls.S, 1)
		if is_zero_approx(game.car.speed):
			saw_zero = true
		_check(not (before > 0 and game.car.speed < 0), "brake cannot jump directly into reverse")
	_check(saw_zero and game.car.speed < -0.5, "S stops then reverses")
	game.request_reset()
	await _drive(SharedControls.W | SharedControls.A, 35)
	_check(game.car.rotation.y > 0.1 and game.car.position.x < 0, "A steers left while driving forward")
	game.request_reset()
	await _drive(SharedControls.W | SharedControls.D, 35)
	_check(game.car.rotation.y < -0.1 and game.car.position.x > 0, "D steers right while driving forward")
	game.request_reset()
	await _drive(SharedControls.ALL, 30)
	_check(absf(game.car.speed) < 0.01 and absf(game.car.steering) < 0.01, "opposing actions cancel")
	await _drive(SharedControls.W, 180)
	_check(game.car.speed <= game.TUNING.forward_speed + 0.01, "forward speed is capped")
	var coasting: float = game.car.speed
	await _drive(0, 20)
	_check(game.car.speed < coasting and game.car.speed > 0, "releasing drive coasts")
	# The physical perimeter stops the car; speed is not accumulated against it.
	game.car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.56, -22))
	await _drive(SharedControls.W, 100)
	_check(game.car.position.z > -23.1 and absf(game.car.speed) < 0.1, "wall collision resolves without stored drive speed")
	game.request_reset()
	_check(game.car.velocity == Vector3.ZERO and game.car.speed == 0.0, "reset clears motion immediately")
	_check(game.controls.samples.is_empty() and not game.parking.success and game.parking.held == 0.0, "reset clears all channel and parking state")
	_test_containment()
	game.car.global_transform = Transform3D(Basis.IDENTITY, game.TUNING.bay_position + Vector3(0, 0.56, 0))
	await _drive(0, 85)
	_check(game.parking.success and game.success_events == 1, "parking hold produces shared success")
	await _drive(0, 20)
	_check(game.success_events == 1, "success event happens only once per attempt")
	game.request_reset()
	_check(not game.parking.success and game.parking.held == 0, "retry clears success")
	await _test_keyboard_reset()
	for count in range(1, 5):
		game.set_local_count(count)
		_check(game.controls.players.size() == count and game.car.speed == 0, "local remapping safely resets")
	game.set_local_count(4)
	game.controls.submit(2, SharedControls.ALL, 1000, game.controls.epoch, _now())
	_check(game.controls.merged(_now(), 0.35) == SharedControls.A, "independent P2 channel only owns A with four players")
	await _drive(0, 2)
	# Explicit fixture paths: never use real local credentials or initiate login.
	_check(game.session._load_credentials("res://build/absent-eos-config.cfg") == null and "config" in game.session.status, "missing online config fails gracefully")
	_check(game.session._load_credentials("res://eos.example.cfg") == null and "missing" in game.session.status, "blank online config fails clearly")
	await game.session.join_room("X")
	_check(not game.session.online and not game.session.busy and "six-character" in game.session.status, "invalid room code rejected before login")
	_check(not game.session._platform_ready, "offline checks never initialize or log in to EOS")
	print("PLAYABLE CHECKS ", "PASSED" if failures == 0 else "FAILED", ": ", checks, " checks, ", failures, " failures")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _test_ownership() -> void:
	var controls := SharedControls.new()
	var expected := [[15], [5, 10], [1, 4, 10], [1, 2, 4, 8]]
	for count in range(1, 5):
		var ids: Array[int] = []
		for index in count:
			ids.append(10 + index)
		controls.remap(ids)
		var seen: int = 0
		for index in count:
			var mask := controls.owned_mask(ids[index])
			_check(mask == expected[count - 1][index] and (seen & mask) == 0, "approved exclusive action assignment")
			seen |= mask
			controls.submit(ids[index], SharedControls.ALL, 1, controls.epoch, 1.0)
		_check(seen == SharedControls.ALL and controls.merged(1.0, 0.35) == SharedControls.ALL, "all four actions covered once")
		_check(controls.merged(1.4, 0.35) == 0, "stale channels become neutral")
	_check(not controls.submit(999, 15, 2, controls.epoch, 2.0), "unknown sender rejected")
	_check(not controls.submit(10, 15, 1, controls.epoch, 2.0), "duplicate sequence rejected")
	var old_epoch := controls.epoch
	controls.clear()
	_check(not controls.submit(10, 15, 999, old_epoch, 2.0), "old attempt inputs rejected")
	_check(controls.merged(2.0, 0.35) == 0, "reset neutralizes every channel")


func _test_containment() -> void:
	var tuning: DriveTuning = game.TUNING
	var at := tuning.bay_position + Vector3(0, 0.56, 0)
	_check(ParkingRules.contains_footprint(Transform3D(Basis.IDENTITY, at), tuning), "aligned footprint fits bay")
	_check(not ParkingRules.contains_footprint(Transform3D(Basis(Vector3.UP, PI / 2), at), tuning), "rotated protruding corners reject parking")
	_check(not ParkingRules.contains_footprint(Transform3D(Basis.IDENTITY, at + Vector3(1, 0, 0)), tuning), "center-in-bay alone is insufficient")
	var rotated := tuning.duplicate() as DriveTuning
	rotated.bay_yaw = 0.7
	_check(ParkingRules.contains_footprint(Transform3D(Basis(Vector3.UP, 0.7), at), rotated), "oriented bay containment")
	game.parking.reset()
	game.car.global_transform = Transform3D(Basis.IDENTITY, at)
	game.car.velocity = Vector3(1, 0, 0)
	game.parking.tick(game.car, tuning, 2.0)
	_check(not game.parking.success and game.parking.held == 0, "moving through bay cannot win")
	game.car.velocity = Vector3.ZERO
	game.car.yaw_speed = 1.0
	game.parking.tick(game.car, tuning, 2.0)
	_check(not game.parking.success, "spinning in bay cannot win")
	game.car.yaw_speed = 0.0
	game.parking.tick(game.car, tuning, 0.5)
	game.car.global_position.x += 4.0
	game.parking.tick(game.car, tuning, 0.1)
	_check(game.parking.held == 0, "leaving bay breaks hold")
	game.request_reset()


func _test_keyboard_reset() -> void:
	game._sample_input() # Clear release gate with no keys held.
	_key(KEY_W, true)
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == SharedControls.W, "physical W reaches sampler")
	game.request_reset()
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == 0, "held W blocked after reset")
	_key(KEY_W, false)
	game._sample_input()
	_key(KEY_W, true)
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == SharedControls.W, "release then press enables W again")
	_key(KEY_W, false)
	game.request_reset()
	await process_frame


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _drive(mask: int, ticks: int) -> void:
	for tick in ticks:
		await physics_frame
		for id in game.controls.players:
			game.controls.submit(id, mask, game._sequence + 1, game.controls.epoch, _now())
		game._sequence += 1
		await process_frame


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
