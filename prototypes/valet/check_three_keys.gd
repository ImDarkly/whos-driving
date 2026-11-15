extends SceneTree
## Drives the standalone shift through its normal physical-key input.

const Game = preload("res://prototypes/valet/three_keys.gd")
const Lot = preload("res://prototypes/valet/three_keys_lot.gd")
const EAST := -PI / 2.0

var game: Game
var failures := 0
var checks := 0
var keys := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = load("res://prototypes/valet/three_keys.tscn").instantiate()
	root.add_child(game)
	if "--capture" in OS.get_cmdline_user_args():
		_check(DirAccess.make_dir_recursive_absolute("res://build") == OK, "Capture folder is available")
	var initial := _poses()
	game.cars[0].contact_monitor = true
	game.cars[0].max_contacts_reported = 8
	_check_start(0, initial)
	await _drive(0, 0, 4)
	await _capture("yellow-start")
	if "--capture" in OS.get_cmdline_user_args():
		await _check_mouse_look()

	await _park_arrivals(false)
	var blue_pose := game.cars[1].global_transform
	var red_pose := game.cars[2].global_transform
	_check(await _swing(), "Yellow's turn contacts Blue in the near bay")
	await _drive(0, 0, 100)
	_check(game.phase == Game.Phase.PICKUP, "Contact leaves the pickup in progress")
	await _capture("blocked")
	var before_switch := game.cars[0].global_transform
	_press(KEY_2)
	await _drive(0, 0, 2)
	var yellow_pose := game.cars[0].global_transform
	_check(game.selected == 1 and game.cars[0].freeze
		and _same_parked_pose(game.cars[1].global_transform, blue_pose)
		and _same_parked_pose(yellow_pose, before_switch),
		"Stopped switch takes control of Blue at its parked position and heading")
	_check_driver_view()
	await _straight(Vector3(1.6, 0, -8.7))
	await _drive(0, 0, 30)
	_check(game.cars[0].global_transform == yellow_pose, "Yellow stays frozen while Blue is driven")
	_press(KEY_1)
	await _drive(0, 0, 2)
	var moved_blue := game.cars[1].global_transform
	_check(game.selected == 0 and moved_blue.origin.z < -8.0
		and _same_parked_pose(game.cars[0].global_transform, yellow_pose),
		"Switching back takes control of Yellow in the same place and heading")
	await _capture("recovered")
	await _return_to_curb()
	_check(game.phase == Game.Phase.FINISHED and game.cars[1].global_transform == moved_blue
		and game.cars[2].global_transform == red_pose, "Yellow returns after the recovery")
	await _capture("yellow-returned")

	_press(KEY_1)
	_check_start(0, initial)
	await _drive(0, 0, 4)
	await _park_arrivals(true)
	_check(not await _swing() and game.cars[0].position.x > 0.0,
		"The same turn clears Blue in the far bay")
	await _drive(0, 0, 80)
	await _return_to_curb()
	_check(game.phase == Game.Phase.FINISHED, "Yellow returns directly with Blue parked far away")
	await _capture("yellow-direct")

	var blue_replay := game.replay.get_child(1) as Button
	blue_replay.pressed.emit()
	_check_start(1, initial)
	await _drive(0, 0, 4)
	await _capture("blue-start")
	await _park_arrivals(false)
	_check(game.selected == 1 and game.cars[1].global_transform.is_equal_approx(blue_pose),
		"Blue-first uses the same near parking pose and selects Blue for pickup")
	await _straight(Vector3(1.6, 0, 0.45))
	await _turn(EAST)
	await _return_to_curb()
	_check(game.phase == Game.Phase.FINISHED and game.cars[0].global_transform == initial[0],
		"Blue returns from the near bay without moving Yellow")
	await _capture("blue-returned")
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _same_parked_pose(actual: Transform3D, parked: Transform3D) -> bool:
	# Compare the planar pose across a thaw, when the suspensionless body settles on the floor.
	var drift := actual.origin - parked.origin
	return Vector2(drift.x, drift.z).length() < 0.004 and actual.basis.is_equal_approx(parked.basis)


func _poses() -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for car in game.cars:
		poses.append(car.global_transform)
	return poses


func _check_start(pickup: int, initial: Array[Transform3D]) -> void:
	_check(game.phase == Game.Phase.BLUE_ARRIVAL and game.selected == 1
		and game.requested == pickup and Lot.NAMES[pickup].to_upper() in game.schedule.text
		and game.cars[0].freeze and game.cars[0].collision_layer == 1
		and not game.cars[2].visible and game.cars[2].collision_layer == 0
		and _poses() == initial, "Same staged start with %s announced first" % Lot.NAMES[pickup])
	_check_driver_view()


func _check_driver_view() -> void:
	var car := game.cars[game.selected]
	var seat := car.global_transform * Transform3D(Basis.IDENTITY, car.seat_position(0))
	_check(game.camera.is_current() and game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE
		and game.camera.global_transform.is_equal_approx(seat), "View faces forward from the active driver's seat")


func _check_mouse_look() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_visible_rect().get_center()
	Input.parse_input_event(click)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Clicking the cabin captures the pointer")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(565, 0)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	_check(game.look_yaw < -1.0 and game.cars[1].global_basis.is_equal_approx(Basis(Vector3.UP, PI)),
		"Mouse turns the view without steering Blue")
	await _capture("look-right")
	_press(KEY_ESCAPE)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases the pointer")


func _park_arrivals(far: bool) -> void:
	var yellow_pose := game.cars[0].global_transform
	if far:
		await _turn(EAST)
		await _straight(Vector3(-6.8, 0, -9.65))
	else:
		await _straight(Vector3(1.6, 0, -3.7))
	await _drive(0, 0, 100)
	_check(game.phase == Game.Phase.RED_ARRIVAL and game.selected == 2 and game.cars[2].visible,
		"Blue parks %s and Red arrives" % ("far" if far else "near"))
	if game.phase != Game.Phase.RED_ARRIVAL or game.selected != 2:
		return
	_check_driver_view()
	var parked_blue := game.cars[1].global_transform
	await _capture("red-far" if far else "red-near")
	await _straight(Vector3(-10.2, 0, -1.48))
	await _drive(0, 0, 100)
	_check(game.phase == Game.Phase.PICKUP and game.selected == game.requested
		and _same_parked_pose(game.cars[0].global_transform, yellow_pose)
		and _same_parked_pose(game.cars[1].global_transform, parked_blue)
		and game.cars[2].freeze, "Red parks in its own bay and pickup starts with saved poses")


func _swing() -> bool:
	var hit := false
	for frame in 90:
		if frame == 30:
			_press(KEY_2)
		await _drive(1, 1 if frame < 43 else 0)
		hit = hit or game.cars[1] in game.cars[0].get_colliding_bodies()
	await _drive(0, 0)
	_check(game.selected == 0, "A switch request while rolling leaves Yellow active")
	return hit


func _return_to_curb() -> void:
	var curb := Lot.BAYS[Lot.Bay.CURB].get_center()
	var target := Vector3(curb.x, 0, curb.y)
	var car := game.cars[game.selected]
	for leg in 3:
		var offset := target - car.position
		if game.phase != Game.Phase.PICKUP or Vector2(offset.x, offset.z).length() < 0.20:
			break
		await _turn(atan2(-offset.x, -offset.z))
		await _drive(0, 0, 30)
		await _straight(target)
		await _drive(0, 0, 40)
	if game.phase == Game.Phase.PICKUP:
		await _turn(EAST)
		await _drive(0, 0, 100)


func _turn(target: float) -> void:
	var car := game.cars[game.selected]
	for frame in 440:
		var error := wrapf(target - car.rotation.y, -PI, PI)
		if absf(error) < 0.012 and absf(car.yaw_speed) < 0.02:
			return
		var effort := 3.0 * error - 2.0 * car.yaw_speed
		var direction := int(signf(effort)) if absf(effort) > 0.02 else 0
		await _drive(-direction, direction)
	_check(false, "Turn to %.2f timed out at %s yaw %.2f" % [target, car.position, car.rotation.y])


func _straight(target: Vector3) -> void:
	var car := game.cars[game.selected]
	var initial_phase := game.phase
	for frame in 700:
		if game.phase != initial_phase:
			return
		var remaining := (target - car.position).dot(-car.global_basis.z)
		if absf(remaining) < 0.08 and absf(car.speed) < 0.08:
			return
		var effort := clampf(remaining * 1.3, -2.4, 2.4) - car.speed
		var direction := int(signf(effort)) if absf(effort) > 0.06 else 0
		await _drive(direction, direction)
	_check(false, "Straight leg to %s timed out at %s" % [target, car.position])


func _drive(left: int, right: int, frames := 1) -> void:
	var mask := int(left == 1) | (int(left == -1) << 1) | (int(right == 1) << 2) | (int(right == -1) << 3)
	for index in Game.DRIVE_KEYS.size():
		var bit := 1 << index
		if bool(keys & bit) != bool(mask & bit):
			_key(Game.DRIVE_KEYS[index], bool(mask & bit))
	keys = mask
	Input.flush_buffered_events()
	for frame in frames:
		await physics_frame


func _press(code: Key) -> void:
	_key(code, true)
	_key(code, false)
	Input.flush_buffered_events()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _capture(label: String) -> void:
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://build/three-keys-%s.png" % label) == OK,
			"Captured %s from native Godot" % label)


func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	checks += 1
	if not ok:
		failures += 1
