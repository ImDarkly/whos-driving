extends SceneTree
## Actual scene/physics and physical-key sampler. No EOS authentication.

var game: Node3D
var checks: int = 0
var failures: int = 0
const C = preload("res://scripts/shared_controls.gd")
const FORWARD: int = 85
const REVERSE: int = 170


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
	await _drive(0, 15)
	_check(absf(game.car.position.y - 0.55) < 0.04, "rigid body rests on real 3D floor")
	var start: Vector3 = game.car.position
	await _drive(FORWARD, 60)
	_check(game.car.position.z < start.z - 1 and game.car.speed > 3, "equal wheel forces drive forward")
	_check(absf(game.car.rotation.y) < 0.01 and absf(game.car.position.x) < 0.01, "equal wheel forces travel straight")
	var before: float = game.car.speed
	await _drive(REVERSE, 1)
	_check(game.car.speed > 0 and game.car.speed <= before + 0.1, "counter-drive does not instantly reverse velocity")
	await _drive(REVERSE, 25)
	_check(game.car.speed < before - 1 and game.car.speed > 0, "reverse force opposes forward motion")
	await _drive(REVERSE, 90)
	_check(game.car.speed < -1, "continued counter-drive reverses")
	await _drive(REVERSE, 90)
	_check(game.car.speed >= -game.TUNING.reverse_speed - 0.15, "reverse speed limit")
	game.request_reset()
	# Long speed/coast fixture uses the unobstructed outer lot, outside the course.
	await _drive(0, 2)
	game.car.global_transform = Transform3D(Basis.IDENTITY, Vector3(-15, 0.56, 10))
	await _drive(FORWARD, 160)
	_check(game.car.speed <= game.TUNING.forward_speed + 0.15 and game.car.speed > 7.5, "forward speed limit")
	var coasting: float = game.car.speed
	await _drive(0, 30)
	_check(game.car.speed < coasting - 0.1 and game.car.speed > coasting - 0.7, "release coasts with passive resistance")
	game.request_reset()
	await _drive(C.drive(C.RIGHT, 1), 60)
	_check(game.car.rotation.y > 0.2 and game.car.position.x < -0.05, "right side alone turns left from wheel forces")
	game.request_reset()
	await _drive(C.drive(C.LEFT, 1), 60)
	_check(game.car.rotation.y < -0.2 and game.car.position.x > 0.05, "left side alone turns right from wheel forces")
	game.request_reset()
	await _drive(C.drive(C.LEFT, -1) | C.drive(C.RIGHT, 1), 90)
	_check(absf(game.car.rotation.y) > 0.6 and game.car.position.distance_to(game.TUNING.start_position) < 0.2, "opposing sides turn tightly with little translation")
	_check(absf(game.car.yaw_speed) <= game.TUNING.max_yaw_speed + 0.15, "angular speed limit")
	var spinning: float = absf(game.car.yaw_speed)
	await _drive(0, 60)
	_check(absf(game.car.yaw_speed) < spinning * 0.5, "neutral wheel slip and rolling resistance dissipate yaw")
	game.request_reset()
	await _drive(C.ALL_INPUT, 30)
	_check(absf(game.car.speed) < 0.01 and absf(game.car.yaw_speed) < 0.01, "both directions held neutralize each group")
	# Each of the four corners can drive on its own in the four-owner layout.
	game.set_local_count(4)
	for index in 4:
		game.request_reset()
		await _drive(C.drive(1 << index, 1), 40)
		var expected_sign := -1.0 if index % 2 == 0 else 1.0
		_check(game.car.speed > 0.2 and game.car.yaw_speed * expected_sign > 0.1, "%s independently produces translation and torque" % C.NAMES[index])
		_check(is_zero_approx(game.car.wheels[index].rotation.y), "wheel remains fixed without steering")
	game.set_local_count(1)
	game.car.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.56, -22))
	await _drive(FORWARD, 120)
	_check(game.car.position.z > -23.1 and absf(game.car.speed) < 0.12, "perimeter collision resolves without stored speed")
	game.request_reset()
	_check(game.car.linear_velocity == Vector3.ZERO and game.car.angular_velocity == Vector3.ZERO, "reset clears linear and angular motion immediately")
	await _drive(0, 3)
	_check(game.car.position.distance_to(game.TUNING.start_position) < 0.04, "reset does not retain old wheel forces")
	_check(game.controls.samples.values().all(func(s): return s.mask == 0) and not game.parking.success and game.parking.held == 0, "reset clears command and parking state")
	_test_containment()
	game.car.global_transform = Transform3D(Basis.IDENTITY, game.TUNING.bay_position + Vector3(0, 0.56, 0))
	await _drive(0, 90)
	_check(game.parking.success and game.success_events == 1, "parking hold produces shared success")
	await _drive(0, 20)
	_check(game.success_events == 1, "success once per attempt")
	game.request_reset()
	_check(not game.parking.success and game.parking.held == 0, "retry clears success")
	await _test_keyboard()
	for count in range(1, 5):
		game.set_local_count(count)
		_check(game.controls.players.size() == count and game.car.speed == 0 and game.car.angular_velocity == Vector3.ZERO and game.controls.samples.is_empty(), "player count changes reset motion and input")
		game.hud.update_view(game.session, game.controls, 1, game.parking, game.TUNING, 0, "test", 0)
		_check(game.hud.wheel_labels.size() == 4 and "YOU" in game.hud.wheel_labels[0].text, "wheel diagram explains ownership at every count")
	game.set_local_count(4)
	game.controls.submit(2, FORWARD, 10000, game.controls.epoch, _now())
	_check(game.controls.merged(_now(), 0.35) == C.drive(C.FR, 1), "independent P2 channel only owns front-right")
	# Explicit fixtures: never read real credentials or initiate login.
	_check(game.session._load_credentials("res://build/absent-eos-config.cfg") == null and "config" in game.session.status, "missing online config fails gracefully")
	_check(game.session._load_credentials("res://eos.example.cfg") == null and "missing" in game.session.status, "blank online config fails clearly")
	await game.session.join_room("X")
	_check(not game.session.online and not game.session.busy and "six-character" in game.session.status, "invalid room rejected before login")
	_check(not game.session._platform_ready, "offline checks never initialize EOS")
	print("PLAYABLE CHECKS ", "PASSED" if failures == 0 else "FAILED", ": ", checks, " checks, ", failures, " failures")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _test_ownership() -> void:
	var controls := SharedControls.new()
	var expected := [[15], [5, 10], [1, 2, 12], [1, 2, 4, 8]]
	for count in range(1, 5):
		var ids: Array[int] = []
		for index in count:
			ids.append(10 + index)
		controls.remap(ids)
		var seen := 0
		for index in count:
			var wheels := controls.owned_wheels(ids[index])
			_check(wheels == expected[count - 1][index] and (seen & wheels) == 0, "approved exclusive wheel assignment")
			seen |= wheels
			controls.submit(ids[index], FORWARD, 1, controls.epoch, 1)
			_check(controls.samples[ids[index]].mask == C.drive(wheels, 1), "host removes unowned wheel commands")
			_check(controls.keyboard_mask(ids[index], 3) == 0, "opposite physical keys neutralize primary group")
			if count > 1:
				_check(controls.keyboard_mask(ids[index], 1) == C.drive(wheels, 1), "multiplayer W drives entire owned group")
				_check(controls.keyboard_mask(ids[index], 4) == 0, "solo second pair cannot affect multiplayer wheels")
		_check(seen == C.WHEELS and controls.merged(1, 0.35) == FORWARD, "all four wheels covered once")
		_check(controls.merged(1.4, 0.35) == 0, "stale channels neutralize")
		if count in [1, 2, 3]:
			var owner: int = ids.back()
			var group := C.LEFT if count == 1 else int(expected[count - 1][-1])
			var first := 0
			for wheel in 4:
				if group & (1 << wheel):
					first = 1 << wheel
					break
			_check(controls.normalize(owner, C.drive(first, 1)) == C.drive(group, 1), "partial group input is applied to whole group")
			_check(controls.normalize(owner, C.drive(first, 1) | C.drive(group & ~first, -1)) == 0, "split group directions neutralize whole group")
	_check(not controls.submit(999, FORWARD, 2, controls.epoch, 2), "unknown sender rejected")
	_check(not controls.submit(10, FORWARD, 1, controls.epoch, 2), "duplicate sequence rejected")
	_check(not controls.submit(10, FORWARD, 0, controls.epoch, 2), "out-of-order sequence rejected")
	var old_epoch := controls.epoch
	controls.clear()
	_check(not controls.submit(10, FORWARD, 999, old_epoch, 2), "old attempt rejected")
	_check(controls.merged(2, 0.35) == 0, "reset neutralizes all channels")
	controls.remap([1])
	_check(controls.keyboard_mask(1, 1 | 8) == C.drive(C.LEFT, 1) | C.drive(C.RIGHT, -1), "solo independent opposite side commands")
	_check(controls.keyboard_mask(1, 15) == 0, "both solo direction pairs cancel")


func _test_containment() -> void:
	var tuning: DriveTuning = game.TUNING
	var at := tuning.bay_position + Vector3(0, 0.56, 0)
	_check(ParkingRules.contains_footprint(Transform3D(Basis.IDENTITY, at), tuning), "aligned footprint fits bay")
	_check(not ParkingRules.contains_footprint(Transform3D(Basis(Vector3.UP, PI / 2), at), tuning), "rotated corners reject parking")
	_check(not ParkingRules.contains_footprint(Transform3D(Basis.IDENTITY, at + Vector3(1, 0, 0)), tuning), "center-in-bay is insufficient")
	var rotated := tuning.duplicate() as DriveTuning
	rotated.bay_yaw = 0.7
	_check(ParkingRules.contains_footprint(Transform3D(Basis(Vector3.UP, 0.7), at), rotated), "oriented bay containment")
	game.parking.reset()
	game.car.global_transform = Transform3D(Basis.IDENTITY, at)
	game.car.linear_velocity = Vector3(1, 0, 0)
	game.parking.tick(game.car, tuning, 2)
	_check(not game.parking.success and game.parking.held == 0, "moving through bay cannot win")
	game.car.linear_velocity = Vector3.ZERO
	game.car.angular_velocity = Vector3(0, 1, 0)
	game.parking.tick(game.car, tuning, 2)
	_check(not game.parking.success, "spinning in bay cannot win")
	game.car.angular_velocity = Vector3.ZERO
	game.parking.tick(game.car, tuning, 0.5)
	game.car.global_position.x += 4
	game.parking.tick(game.car, tuning, 0.1)
	_check(game.parking.held == 0, "leaving bay breaks hold")
	game.request_reset()


func _test_keyboard() -> void:
	game._focus_active = true # Headless windows have no OS keyboard focus.
	game._sample_input()
	_key(KEY_W, true)
	_key(KEY_DOWN, true)
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == C.drive(C.LEFT, 1) | C.drive(C.RIGHT, -1), "physical W and Down reach independent sides")
	game.request_reset()
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == 0, "both held pairs blocked after reset")
	_key(KEY_W, false)
	_key(KEY_DOWN, false)
	game._sample_input()
	_key(KEY_W, true)
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == C.drive(C.LEFT, 1), "release then press enables drive")
	game.set_local_count(3)
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == 0, "held controls blocked after remapping")
	_key(KEY_W, false)
	game.local_slot = 2
	game._sample_input()
	_key(KEY_S, true)
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == C.drive(C.REAR, -1), "trio rear owner drives both rear wheels with S")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == 0, "focus loss neutralizes input")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == 0, "held controls stay blocked after focus return")
	_key(KEY_S, false)
	game.set_local_count(1)
	game._sample_input()
	_key(KEY_A, true)
	_key(KEY_D, true)
	game._sample_input()
	_check(game.controls.merged(_now(), 0.35) == 0, "old A/D steering keys have no drive command")
	_key(KEY_A, false)
	_key(KEY_D, false)
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
