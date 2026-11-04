extends SceneTree
## Collision fixtures are separate from the command-only spawn-to-success proof.
var game: Node3D
var sequence := 0
var failures := 0
var checks := 0
const C = preload("res://scripts/shared_controls.gd")

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.manual_inputs = true
	await process_frame
	await _drive(0, 15)
	check(game.lot.parked_cars.size() > 70, "surrounding marked rows populate the lot")
	var separate := true
	var within_lot := true
	for index in game.lot.parked_cars.size():
		var car: StaticBody3D = game.lot.parked_cars[index]
		var bounds: AABB = car.global_transform * AABB(-game.TUNING.body_size / 2, game.TUNING.body_size)
		within_lot = within_lot and bounds.position.x >= -24.81 and bounds.end.x <= 24.81 and bounds.position.z >= -24.81 and bounds.end.z <= 24.81
		for other_index in range(index + 1, game.lot.parked_cars.size()):
			var other: StaticBody3D = game.lot.parked_cars[other_index]
			var other_bounds: AABB = other.global_transform * AABB(-game.TUNING.body_size / 2, game.TUNING.body_size)
			separate = separate and not bounds.grow(-0.01).intersects(other_bounds.grow(-0.01))
	check(separate, "parked cars have separate non-overlapping footprints")
	check(within_lot, "parked cars fit inside the existing perimeter")
	print("PARKED CARS: ", game.lot.parked_cars.size())
	var query := PhysicsRayQueryParameters3D.create(Vector3(5.45, 0.55, 5), Vector3(5.45, 0.55, 1))
	check(game.car.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "visible bumper gap has no invisible wall")
	for opening in [game.lot.first_opening, game.lot.second_opening]:
		var spans: Array[Vector2] = []
		for car in game.lot.parked_cars:
			if is_equal_approx(car.position.z, opening.y):
				spans.append(Vector2(car.position.x - game.TUNING.body_size.z / 2, car.position.x + game.TUNING.body_size.z / 2))
		spans.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
		var previous := -24.8
		var wide_gaps := 0
		var correct_opening := true
		for span in spans:
			if span.x - previous >= game.TUNING.body_size.x:
				wide_gaps += 1
				correct_opening = correct_opening and absf((span.x + previous) / 2 - opening.x) < 0.01 and absf(span.x - previous - game.lot.opening_width) < 0.01
			previous = span.y
		check(wide_gaps == 1 and correct_opening and 24.8 - previous < game.TUNING.body_size.x, "parked row leaves only its intended vehicle-width opening")
	# Both blocking rows, a real bumper gap, and all three target neighbours.
	var contacts := [
		[Vector3(3.55, 0.56, 7), 0.0, Vector3(0, 0, -1), 1.4],
		[Vector3(0.95, 0.56, 0), 0.0, Vector3(0, 0, -1), 1.4],
		[Vector3(5.45, 0.56, 7), 0.0, Vector3(0, 0, -1), 1.4],
		[Vector3(5, 0.56, -7), -PI / 2, Vector3(1, 0, 0), 0.5],
		[Vector3(5, 0.56, -7), PI / 2, Vector3(-1, 0, 0), 0.5],
		[Vector3(5, 0.56, -7), 0.0, Vector3(0, 0, -1), 1.6],
	]
	for index in contacts.size():
		var fixture: Array = contacts[index]
		game.request_reset()
		await _drive(0, 2)
		game.car.global_transform = Transform3D(Basis(Vector3.UP, fixture[1]), fixture[0])
		game.car.linear_velocity = Vector3.ZERO
		game.car.angular_velocity = Vector3.ZERO
		await _drive(C.drive(C.WHEELS, 1), 240)
		var advance: float = (game.car.position - fixture[0]).dot(fixture[2])
		check(advance > 0.1 and advance < fixture[3] and game.car.linear_velocity.length() < 0.1, "solid contact %d stops driven parked-car crossing" % index)
		game.request_reset()
		check(game.car.linear_velocity == Vector3.ZERO and game.car.angular_velocity == Vector3.ZERO, "contact %d clears motion immediately" % index)
		await _drive(0, 15)
		check(game.car.position.distance_to(game.TUNING.start_position) < 0.05 and game.car.linear_velocity.length() < 0.05 and game.active_mask == 0 and not game.parking.success, "contact %d resets to unchanged spawn with cleared state" % index)
		# Reproduce contact to test driving away separately from contact-reset.
		game.car.global_transform = Transform3D(Basis(Vector3.UP, fixture[1]), fixture[0])
		game.car.linear_velocity = Vector3.ZERO
		game.car.angular_velocity = Vector3.ZERO
		await _drive(C.drive(C.WHEELS, 1), 240)
		var contact: Vector3 = game.car.position
		await _drive(C.drive(C.WHEELS, -1), 40)
		check((game.car.position - contact).dot(fixture[2]) < -0.2, "contact %d permits recovery" % index)
	print("APPROACH: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _drive(mask: int, ticks: int) -> void:
	for tick in ticks:
		await physics_frame
		sequence += 1
		game.controls.submit(1, mask, sequence, game.controls.epoch, Time.get_ticks_msec() / 1000.0)
		await process_frame
