extends Node

var game: Node3D
var peer: ENetMultiplayerPeer
var reports: Dictionary = {}
var failures: int = 0
var is_host: bool
var port: int = 19461
var _deadline: float = 0.0
var _pair_drive: bool = false
var _pair_input_clock: float = 0.0


func _ready() -> void:
	_start.call_deferred()


func _process(delta: float) -> void:
	_pair_input_clock += delta
	if _pair_drive and _pair_input_clock >= 1.0 / game.TUNING.input_hz:
		_pair_input_clock = 0.0
		game._sequence += 1
		# Deliberately send commands for every wheel; production ownership filters.
		game._submit_input.rpc_id(1, SharedControls.drive(SharedControls.WHEELS, 1), game._sequence, game.controls.epoch, Time.get_ticks_msec())
	if _deadline > 0.0 and _now() > _deadline:
		push_error("NETWORK CLIENT TIMEOUT")
		get_tree().quit(1)


func check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error("NETWORK FAIL: " + detail)
	else:
		print("NETWORK OK: ", detail)


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	is_host = args.has("host")
	if args.has("eos"):
		await _start_eos(args)
		return
	var delay := 0.0
	for arg in args:
		if arg.begins_with("delay="):
			delay = float(arg.trim_prefix("delay="))
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	# A dummy lobby keeps normal offline practice disabled. No EOS calls occur.
	game.session.lobby = HLobby.new()
	game.session.is_host = is_host
	peer = ENetMultiplayerPeer.new()
	if is_host:
		check(peer.create_server(port, 3) == OK, "localhost test server starts")
		multiplayer.multiplayer_peer = peer
		game.session.online = true
		game._room_started()
		await _host_test()
	else:
		check(peer.create_client("127.0.0.1", port) == OK, "localhost test client starts")
		multiplayer.connected_to_server.connect(func():
			game.session.online = true
			game._room_started()
		)
		multiplayer.multiplayer_peer = peer
		_deadline = _now() + 18.0


func _start_eos(args: PackedStringArray) -> void:
	# Explicit opt-in; uses only existing named Dev Auth accounts, never Device-ID.
	if not game.session.dev_auth.enabled or not game.session.dev_auth.error.is_empty():
		push_error("EOS wheel check requires valid source/editor Dev Auth options.")
		get_tree().quit(1)
		return
	_deadline = _now() + 75.0
	if not is_host:
		var code := ""
		for arg in args:
			if arg.begins_with("room="):
				code = arg.trim_prefix("room=")
		await game.session.join_room(code)
		return
	await game.session.host_room()
	if not game.session.online:
		push_error("EOS wheel host could not open a room; inspect local logs.")
		get_tree().quit(1)
		return
	var report := FileAccess.open("res://build/eos-wheel-room.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"room_code": game.session.room_code}))
	report.close()
	while game.controls.players.size() < 2 and _now() < _deadline:
		await get_tree().process_frame
	check(game.controls.players.size() == 2, "real EOS pair connected")
	if game.controls.players.size() != 2:
		return
	await _barrier("pair_mapping")
	await _barrier("pair_drive")
	var end := _now() + 1.0
	while _now() < end:
		game._sequence += 1
		game.controls.submit(1, SharedControls.drive(SharedControls.LEFT, -1), game._sequence, game.controls.epoch, _now())
		await get_tree().physics_frame
	check(game.car.rotation.y > 0.3, "real EOS opposing wheel inputs turn host car")
	check(game.controls.samples.size() == 2, "real EOS owned input reaches host")
	await _barrier("pair_motion")
	await _barrier("pair_stop")
	await get_tree().create_timer(0.45).timeout
	check(game.controls.merged(_now(), 0.35) == 0, "real EOS stale input neutralizes")
	for retry in 2:
		var attempt: int = game.controls.epoch
		await _barrier("reset")
		await get_tree().create_timer(0.25).timeout
		check(game.controls.epoch == attempt + 1, "real EOS reset request creates next attempt")
		await _barrier("reset_state")
	game.car.global_transform = Transform3D(Basis.IDENTITY, game.TUNING.bay_position + Vector3(0, 0.56, 0))
	await get_tree().create_timer(1.7).timeout
	check(game.parking.success, "real EOS host verifies parking fixture")
	await _barrier("parking")
	await _barrier("request_reconfiguration")
	await get_tree().create_timer(0.2).timeout
	await _barrier("parking_restored")
	await _barrier("exit")
	await game.session.leave_room("Test host left. Room ended.")
	await get_tree().create_timer(0.5).timeout
	check(await game.session.shutdown(), "real EOS host releases SDK before exit")
	print("EOS WHEEL HOST ", "PASS" if failures == 0 else "FAIL", ": real EOSGMultiplayerPeer, same PC")
	get_tree().quit(0 if failures == 0 else 1)


func _host_test() -> void:
	var deadline := _now() + 8.0
	var saw_duo := false
	var saw_trio := false
	while game.controls.players.size() < 4 and _now() < deadline:
		if game.controls.players.size() == 2 and not saw_duo:
			saw_duo = true
			await _barrier("current_mapping")
			game._sequence += 1
			game.controls.submit(1, SharedControls.drive(SharedControls.LEFT, 1), game._sequence, game.controls.epoch, _now())
		if game.controls.players.size() == 3 and not saw_trio:
			saw_trio = true
			await _barrier("current_mapping")
		await get_tree().physics_frame
	check(game.controls.players.size() == 4, "four separate processes joined")
	check(saw_duo and saw_trio, "duo and trio configured before join in progress to four")
	game.request_reset()
	await _barrier("mapping")
	await _barrier("input")
	await get_tree().create_timer(0.1).timeout
	check(game.controls.samples.size() == 3, "all remote channels reached host")
	var owned := SharedControls.drive(SharedControls.FR | SharedControls.RL | SharedControls.RR, 1)
	check(game.controls.merged(_now(), 0.35) == owned, "host strips unowned wheels from every remote sender")
	await get_tree().create_timer(0.45).timeout
	check(game.controls.merged(_now(), 0.35) == 0, "stale remote input becomes neutral")
	await _barrier("motion")
	var attempt: int = game.controls.epoch
	await _barrier("reset")
	await get_tree().create_timer(0.2).timeout
	check(game.controls.epoch == attempt + 1, "simultaneous reset requests create one new attempt")
	check(game.car.speed == 0.0 and game.controls.samples.is_empty(), "network retry clears motion and commands")
	await _barrier("reset_state")
	game.car.global_transform = Transform3D(Basis.IDENTITY, game.TUNING.bay_position + Vector3(0, 0.56, 0))
	await get_tree().create_timer(1.6).timeout
	check(game.parking.success, "host verifies parking")
	await _barrier("parking")
	await _barrier("request_reconfiguration")
	await get_tree().create_timer(0.15).timeout
	await _barrier("parking_restored")
	game._parking_success.rpc(game.controls.epoch)
	await get_tree().create_timer(0.1).timeout
	await _barrier("parking_restored")
	await _barrier("new_room_context")
	await get_tree().create_timer(0.15).timeout
	await _barrier("new_room_parked")
	await _barrier("request_reconfiguration")
	await get_tree().create_timer(0.15).timeout
	await _barrier("new_room_parked")
	var before_disconnect: int = game.controls.epoch
	_stage.rpc_id(game.controls.players.back(), "disconnect")
	var disconnect_deadline := _now() + 3.0
	while game.controls.players.size() == 4 and _now() < disconnect_deadline:
		await get_tree().process_frame
	check(game.controls.players.size() == 3 and game.controls.epoch > before_disconnect, "departing client safely remaps and resets remaining players")
	check(not game.parking.success and game.car.speed == 0.0 and game.controls.samples.is_empty(), "disconnect clears success, velocity and stale inputs")
	await _barrier("remapped")
	await _barrier("exit")
	peer.close()
	game.session.leave_room("Test host left.")
	await get_tree().create_timer(0.5).timeout
	print("NETWORK HOST ", "PASS" if failures == 0 else "FAIL", ": production RPCs over test-only localhost ENet")
	get_tree().quit(0 if failures == 0 else 1)


func _barrier(stage: String) -> void:
	reports.clear()
	_stage.rpc(stage)
	var expected: int = game.controls.players.size() - 1
	var deadline := _now() + 3.0
	while reports.size() < expected and _now() < deadline:
		await get_tree().process_frame
	check(reports.size() == expected, "%d client reports: %s" % [expected, stage])


@rpc("authority", "call_remote", "reliable")
func _stage(stage: String) -> void:
	var ok := true
	match stage:
		"pair_mapping":
			ok = game._received_config and game.controls.players.size() == 2 and game.controls.owned_wheels(multiplayer.get_unique_id()) == SharedControls.RIGHT and game.session.peer is EOSGMultiplayerPeer
		"pair_drive":
			_pair_drive = true
		"pair_motion":
			ok = game.car.rotation.y > 0.2 and game.car.angular_velocity.y > 0.1 and game._rtt_ms >= 0 and game.car.freeze and SharedControls.command(game.active_mask, 0) == -1 and SharedControls.command(game.active_mask, 1) == 1
		"pair_stop":
			_pair_drive = false
		"current_mapping":
			var slot: int = game.controls.players.find(multiplayer.get_unique_id())
			ok = game._received_config and slot > 0 and game.controls.owned_wheels(multiplayer.get_unique_id()) == int(SharedControls.LAYOUTS[game.controls.players.size() - 1][slot])
		"mapping":
			ok = game._received_config and game.controls.players.size() == 4
			var slot: int = game.controls.players.find(multiplayer.get_unique_id())
			ok = ok and slot > 0 and game.controls.owned_wheels(multiplayer.get_unique_id()) == (1 << slot)
		"input":
			game._submit_input.rpc_id(1, SharedControls.drive(SharedControls.WHEELS, 1), 1000, game.controls.epoch, Time.get_ticks_msec())
		"motion":
			ok = game.car.position.z < game.TUNING.start_position.z - 0.01 and game.car.command_mask == game.active_mask and game.car.freeze and game._rtt_ms >= 0.0
		"reset":
			game.request_reset()
		"reset_state":
			# A resting rigid body has tiny solver velocity at floor contact.
			ok = game.car.linear_velocity.length() < 0.001 and game.car.angular_velocity.length() < 0.001 and game.active_mask == 0 and game.car.global_position.distance_to(game.TUNING.start_position) < 0.1 and not game.parking.success
		"parking":
			ok = game.parking.success and game.success_events == 1 and game.car.position.distance_to(game.TUNING.bay_position + Vector3(0, 0.56, 0)) < 0.2
		"request_reconfiguration":
			game._request_config.rpc_id(1)
		"parking_restored":
			ok = game.parking.success and game.success_events == 1
		"new_room_context":
			# Exercise the real room lifecycle subscriptions. Reuse the same host
			# attempt number, as an unrelated room is allowed to do.
			game.session.room_ended.emit("Test room handoff")
			game.session.room_started.emit()
		"new_room_parked":
			ok = game.parking.success and game.success_events == 2 and game.hud.instruction.text.begins_with("PARKED")
		"disconnect":
			peer.close()
			game.session.leave_room("Test client left.")
			print("NETWORK CLIENT ", "PASS" if failures == 0 else "FAIL", " (left room)")
			get_tree().quit(0 if failures == 0 else 1)
			return
		"remapped":
			var slot: int = game.controls.players.find(multiplayer.get_unique_id())
			ok = game.controls.players.size() == 3 and game.controls.owned_wheels(multiplayer.get_unique_id()) == int(SharedControls.LAYOUTS[2][slot]) and not game.parking.success
		"exit":
			_report.rpc_id(1, true, stage)
			var deadline := _now() + 3.0
			while game.session.online and _now() < deadline:
				await get_tree().process_frame
			check(not game.session.online and ("Host" in game.session.status or "Room closed" in game.session.status), "host departure ends client session clearly")
			if OS.get_cmdline_user_args().has("eos"):
				check(await game.session.shutdown(), "real EOS client releases SDK before exit")
			print("NETWORK CLIENT ", "PASS" if failures == 0 else "FAIL")
			get_tree().quit(0 if failures == 0 else 1)
			return
	if not ok:
		failures += 1
	_report.rpc_id(1, ok, stage)


@rpc("any_peer", "call_remote", "reliable")
func _report(ok: bool, stage: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	reports[id] = stage
	check(ok, "client %d / %s" % [id, stage])


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
