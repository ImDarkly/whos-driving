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
	check(game.lot.parked_cars.size() == 9, "small lot has nine parked cars and empty spaces")
	var separate := true
	var within_lot := true
	for index in game.lot.parked_cars.size():
		var car: StaticBody3D = game.lot.parked_cars[index]
		var bounds: AABB = car.global_transform * AABB(-game.TUNING.body_size / 2, game.TUNING.body_size)
		within_lot = within_lot and bounds.position.x >= game.lot.approach_left + 0.15 and bounds.end.x <= game.lot.approach_right - 0.15 and bounds.position.z >= game.lot.approach_end + 0.15 and bounds.end.z <= game.lot.approach_back - 0.15
		for other_index in range(index + 1, game.lot.parked_cars.size()):
			var other: StaticBody3D = game.lot.parked_cars[other_index]
			var other_bounds: AABB = other.global_transform * AABB(-game.TUNING.body_size / 2, game.TUNING.body_size)
			separate = separate and not bounds.grow(-0.01).intersects(other_bounds.grow(-0.01))
	check(separate, "parked cars have separate non-overlapping footprints")
	check(within_lot, "parked cars fit inside the existing perimeter")
	print("PARKED CARS: ", game.lot.parked_cars.size())
	var query := PhysicsRayQueryParameters3D.create(Vector3(-1.24, 0.55, -4), Vector3(-1.24, 0.55, -9))
	check(game.car.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "empty ordinary space has no invisible wall")
	query = PhysicsRayQueryParameters3D.create(Vector3(0, 0.15, 7), Vector3(0, 0.15, 3))
	query.exclude = [game.car.get_rid()]
	check(game.car.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "entrance is open from the unchanged spawn")
	var source: Image = load("res://assets/retro_car/retro_car_Blue Car Texture.png").get_image()
	if source.is_compressed():
		source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var detail_preserved := true
	var body_changed := false
	for texture in game.lot.paint_textures:
		var painted: Image = texture.get_image()
		for y in source.get_height():
			for x in source.get_width():
				var pixel := source.get_pixel(x, y)
				var is_body := pixel.b > pixel.r * 1.25 and pixel.b > pixel.g * 1.05 and pixel.b > 0.08
				if not is_body:
					detail_preserved = detail_preserved and pixel == painted.get_pixel(x, y)
				else:
					body_changed = body_changed or pixel != painted.get_pixel(x, y)
	check(detail_preserved and body_changed and game.lot.paint_textures.size() == 6, "six body palettes preserve non-blue atlas details")
	if not detail_preserved or not body_changed:
		print("PALETTE DETAIL preserved=", detail_preserved, " changed=", body_changed, " count=", game.lot.paint_textures.size())
	# Target neighbours, back curb, side boundaries, and the near row.
	var contacts := [
		[Vector3(5, 0.56, -7), -PI / 2, Vector3(1, 0, 0), 0.5],
		[Vector3(5, 0.56, -7), PI / 2, Vector3(-1, 0, 0), 0.5],
		[Vector3(5, 0.56, -7), 0.0, Vector3(0, 0, -1), 1.6],
		[Vector3(-2.7, 0.56, -2.9), PI / 2, Vector3(-1, 0, 0), 1.6],
		[Vector3(13, 0.56, -2.9), -PI / 2, Vector3(1, 0, 0), 1.4],
		[Vector3(5, 0.56, -2.9), PI, Vector3(0, 0, 1), 0.6],
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
