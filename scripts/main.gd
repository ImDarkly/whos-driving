extends Node3D

const TUNING: DriveTuning = preload("res://tuning.tres")

var controls := SharedControls.new()
var parking := ParkingRules.new()
var car: ParkingCar
var lot: TestLot
var session: ParkingSession
var hud: ParkingHUD
var camera: Camera3D
var local_slot: int = 0
## Tests can inject channel samples while using the real physics loop.
var manual_inputs: bool = false
var active_mask: int = 0
var success_events: int = 0
var _success_epoch: int = -1
var _sequence: int = 0
var _snapshot_sequence: int = 0
var _last_snapshot: int = -1
var _blocked_keys: int = SharedControls.ALL
var _input_clock: float = 0.0
var _snapshot_clock: float = 0.0
var _host_last_seen: float = 0.0
var _received_config: bool = false
var _remote_target := Transform3D.IDENTITY
var _remote_velocity := Vector3.ZERO
var _remote_yaw_speed: float = 0.0
var _remote_steering: float = 0.0
var _rtt_ms: float = -1.0
var _focus_active: bool = true
var _reset_requested_epoch: int = -1


func _ready() -> void:
	lot = TestLot.new()
	add_child(lot)
	lot.build(TUNING)
	car = ParkingCar.new()
	car.name = "Car"
	car.tuning = TUNING
	add_child(car)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25.0
	camera.far = 120.0
	add_child(camera)
	camera.current = true
	session = ParkingSession.new()
	session.name = "Session"
	add_child(session)
	session.room_started.connect(_room_started)
	session.room_ended.connect(_room_ended)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	hud = ParkingHUD.new()
	add_child(hud)
	hud.reset_requested.connect(request_reset)
	hud.host_requested.connect(func(): session.host_room())
	hud.join_requested.connect(func(code: String): session.join_room(code))
	hud.leave_requested.connect(func(): session.leave_room())
	hud.local_count_changed.connect(set_local_count)
	hud.local_slot_changed.connect(func(slot: int):
		local_slot = slot
		_blocked_keys = SharedControls.ALL
	)
	_reset_attempt()
	camera.position = car.position + Vector3(0, 18, 14)
	camera.look_at(car.position + Vector3(0, 0, -3), Vector3.UP)


func _physics_process(delta: float) -> void:
	_input_clock += delta
	if not manual_inputs and _input_clock >= 1.0 / TUNING.input_hz:
		_input_clock = 0.0
		_sample_input()
	if _authority():
		active_mask = controls.merged(_now(), TUNING.stale_input_seconds)
		car.step(active_mask, delta)
		if parking.tick(car, TUNING, delta):
			success_events += 1
			_success_epoch = controls.epoch
			if session.online:
				_parking_success.rpc(controls.epoch)
		_snapshot_clock += delta
		if session.online and _snapshot_clock >= 1.0 / TUNING.snapshot_hz:
			_snapshot_clock = 0.0
			_snapshot_sequence += 1
			_receive_snapshot.rpc(_snapshot())
	elif session.online:
		if _now() - _host_last_seen > TUNING.host_timeout_seconds:
			session.leave_room("Host stopped responding. Room ended.")
			return
		if not _received_config:
			return
		car.velocity = _remote_velocity
		car.yaw_speed = _remote_yaw_speed
		car.steering = _remote_steering
		car.speed = _remote_velocity.dot(-_remote_target.basis.z)
		car.update_wheels()


func _process(delta: float) -> void:
	if not is_instance_valid(car):
		return
	if session.online and not session.is_host and _received_config:
		car.global_transform = car.global_transform.interpolate_with(_remote_target, 1.0 - exp(-TUNING.interpolation_speed * delta))
	var desired := car.position + Vector3(0, 18, 14)
	camera.position = camera.position.lerp(desired, 1.0 - exp(-4.0 * delta))
	camera.look_at(car.position + Vector3(0, 0, -3), Vector3.UP)
	lot.show_parking(parking.success, parking.contained)
	var authority := "HOST" if session.online and session.is_host else ("CLIENT · host simulates" if session.online else "LOCAL")
	var latency := "RTT %.0f ms" % _rtt_ms if _rtt_ms >= 0 else "RTT —"
	var input_text := "Input %s" % SharedControls.describe(active_mask)
	hud.update_view(session, controls, _local_id(), parking, TUNING, car.speed, "%s · %s\n%s" % [authority, latency, input_text])


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			request_reset()
		elif event.physical_keycode == KEY_F3:
			hud.debug_panel.visible = not hud.debug_panel.visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_active = false
		_blocked_keys = SharedControls.ALL
		if is_instance_valid(hud):
			hud.clear_injections()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focus_active = true


func _authority() -> bool:
	return session.lobby == null or (session.online and session.is_host)


func _local_id() -> int:
	if session.online:
		return multiplayer.get_unique_id()
	return local_slot + 1


func _raw_keys() -> int:
	var mask: int = 0
	for item in [[KEY_W, SharedControls.W], [KEY_A, SharedControls.A], [KEY_S, SharedControls.S], [KEY_D, SharedControls.D]]:
		if Input.is_physical_key_pressed(item[0]):
			mask |= int(item[1])
	return mask


func _sample_input() -> void:
	var raw := _raw_keys()
	# A control held through reset/remapping/focus loss stays blocked until released.
	_blocked_keys &= raw
	var focus := get_viewport().gui_get_focus_owner()
	var mask := raw & ~_blocked_keys if _focus_active and not focus is LineEdit else 0
	_sequence += 1
	if session.online:
		if not _received_config and not session.is_host:
			return
		mask &= controls.owned_mask(_local_id())
		if session.is_host:
			controls.submit(1, mask, _sequence, controls.epoch, _now())
		else:
			_submit_input.rpc_id(1, mask, _sequence, controls.epoch, Time.get_ticks_msec())
	elif session.lobby == null:
		var injected := hud.injected_mask() if _focus_active else 0
		for id in controls.players:
			controls.submit(id, (mask if id == _local_id() else 0) | injected, _sequence, controls.epoch, _now())


func set_local_count(count: int) -> void:
	if session.lobby != null or session.busy:
		return
	var ids: Array[int] = []
	for id in range(1, clampi(count, 1, 4) + 1):
		ids.append(id)
	controls.remap(ids)
	local_slot = 0
	hud.set_local_count(ids.size())
	_reset_attempt()


func request_reset() -> void:
	if _authority():
		_reset_attempt()
	elif session.online and _received_config and _reset_requested_epoch != controls.epoch:
		_reset_requested_epoch = controls.epoch
		_request_reset.rpc_id(1, controls.epoch)


func _reset_attempt() -> void:
	controls.clear()
	parking.reset()
	active_mask = 0
	car.reset_car()
	_flush_local_input()
	if session.online and session.is_host:
		_configure.rpc(controls.players, _snapshot())


func _flush_local_input() -> void:
	_blocked_keys = SharedControls.ALL
	_reset_requested_epoch = -1
	if hud:
		hud.clear_injections()


func _room_started() -> void:
	# Attempt numbers belong to a room, so another room may reuse this value.
	_success_epoch = -1
	parking.reset()
	_rtt_ms = -1.0
	_last_snapshot = -1
	_host_last_seen = _now()
	_received_config = session.is_host
	hud.set_local_count(1)
	local_slot = 0
	if session.is_host:
		controls.remap([1])
		_reset_attempt()
	else:
		_flush_local_input()
		_request_config.rpc_id(1)


func _room_ended(_reason: String) -> void:
	_success_epoch = -1
	_received_config = false
	_rtt_ms = -1.0
	controls.remap([1])
	local_slot = 0
	hud.set_local_count(1)
	_reset_attempt()


func _peer_connected(id: int) -> void:
	if not session.online or not session.is_host:
		return
	if controls.players.has(id):
		return
	if controls.players.size() >= 4:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var ids := controls.players.duplicate()
	ids.append(id)
	controls.remap(ids)
	_reset_attempt()


func _peer_disconnected(id: int) -> void:
	if not session.online or not session.is_host or not controls.players.has(id):
		return
	var ids := controls.players.duplicate()
	ids.erase(id)
	controls.remap(ids)
	_reset_attempt()


# EOSG has no unreliable-ordered mode. Explicit sequence/attempt checks provide
# ordering while keeping late input from queuing behind reliable packets.
@rpc("any_peer", "call_remote", "unreliable", 1)
func _submit_input(mask: int, sequence: int, attempt: int, client_msec: int) -> void:
	if not session.online or not session.is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if client_msec < 0 or not controls.players.has(id):
		return
	var sample: Dictionary = controls.samples.get(id, {})
	if not sample.is_empty() and _now() - float(sample.received) < 1.0 / 60.0:
		return
	if controls.submit(id, mask & SharedControls.ALL, sequence, attempt, _now()):
		# Echo the sender's own clock; no synchronized wall clocks are assumed.
		_input_ack.rpc_id(id, client_msec)


@rpc("authority", "call_remote", "unreliable", 1)
func _input_ack(client_msec: int) -> void:
	var measured := float(Time.get_ticks_msec() - client_msec)
	if measured >= 0:
		_rtt_ms = measured if _rtt_ms < 0 else lerpf(_rtt_ms, measured, 0.15)


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_reset(attempt: int) -> void:
	if session.online and session.is_host and controls.players.has(multiplayer.get_remote_sender_id()) and attempt == controls.epoch:
		_reset_attempt()


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_config() -> void:
	var id := multiplayer.get_remote_sender_id()
	if session.online and session.is_host and controls.players.has(id):
		_configure.rpc_id(id, controls.players, _snapshot())


@rpc("authority", "call_remote", "reliable", 0)
func _configure(ids: Array[int], snapshot: Dictionary) -> void:
	if not session.online or session.is_host or ids.is_empty() or ids.size() > 4:
		return
	controls.remap(ids)
	controls.epoch = int(snapshot.epoch)
	parking.reset()
	_received_config = true
	_flush_local_input()
	_apply_snapshot(snapshot, true)


func _snapshot() -> Dictionary:
	return {"sequence": _snapshot_sequence, "epoch": controls.epoch,
		"transform": car.global_transform, "velocity": car.velocity,
		"yaw_speed": car.yaw_speed, "steering": car.steering,
		"held": parking.held, "success": parking.success,
		"contained": parking.contained, "input": active_mask}


@rpc("authority", "call_remote", "unreliable", 2)
func _receive_snapshot(snapshot: Dictionary) -> void:
	if not session.online or session.is_host or not _received_config:
		return
	if int(snapshot.epoch) != controls.epoch or int(snapshot.sequence) <= _last_snapshot:
		return
	_apply_snapshot(snapshot, false)


func _apply_snapshot(snapshot: Dictionary, snap: bool) -> void:
	_last_snapshot = int(snapshot.sequence)
	_host_last_seen = _now()
	_remote_target = snapshot.transform
	_remote_velocity = snapshot.velocity
	_remote_yaw_speed = float(snapshot.yaw_speed)
	_remote_steering = float(snapshot.steering)
	parking.held = float(snapshot.held)
	if bool(snapshot.success):
		_parking_success(controls.epoch)
	parking.contained = bool(snapshot.contained)
	active_mask = int(snapshot.input)
	if snap:
		car.global_transform = _remote_target
		car.velocity = _remote_velocity
		car.speed = _remote_velocity.dot(-_remote_target.basis.z)
		car.steering = _remote_steering
		car.yaw_speed = _remote_yaw_speed
		car.update_wheels()
		car.reset_physics_interpolation()


@rpc("authority", "call_remote", "reliable", 0)
func _parking_success(attempt: int) -> void:
	if attempt != controls.epoch:
		return
	# Configuration can rebuild parking state for an already-observed attempt.
	# Always restore the state; deduplicate only the announcement/counter.
	parking.success = true
	if _success_epoch != attempt:
		_success_epoch = attempt
		success_events += 1


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
