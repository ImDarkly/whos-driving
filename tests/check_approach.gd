extends SceneTree
## Collision fixtures are separate from the command-only spawn-to-success proof.
var game: Node3D
var sequence := 0
var failures := 0
const C = preload("res://scripts/shared_controls.gd")

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.manual_inputs = true
	await process_frame
	# Nose-first forces against both blocked shortcut spans and every enclosure side.
	var contacts := [
		[Vector3(4, 0.56, 5.5), 0.0, Vector3(0, 0, -1), 1.6],
		[Vector3(0, 0.56, -0.75), 0.0, Vector3(0, 0, -1), 0.8],
		[Vector3(-1, 0.56, 6), PI / 2, Vector3(-1, 0, 0), 1.6],
		[Vector3(5.5, 0.56, 6), -PI / 2, Vector3(1, 0, 0), 1.6],
		[Vector3(0, 0.56, 6), PI, Vector3(0, 0, 1), 1.6],
		[Vector3(0, 0.56, -8), 0.0, Vector3(0, 0, -1), 1.6],
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
		check(advance > 0.1 and advance < fixture[3] and game.car.linear_velocity.length() < 0.1, "solid contact %d stops driven shortcut/enclosure crossing" % index)
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
	print("APPROACH: 24 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _drive(mask: int, ticks: int) -> void:
	for tick in ticks:
		await physics_frame
		sequence += 1
		game.controls.submit(1, mask, sequence, game.controls.epoch, Time.get_ticks_msec() / 1000.0)
		await process_frame
