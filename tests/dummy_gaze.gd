extends Node
## Demo-only head presentation. Sender identity comes from the RPC connection.
const SEND_INTERVAL := 1.0 / 15.0
const STALE_SECONDS := 0.75
var game: Node3D
var targets: Dictionary = {}
var _received: Dictionary = {}
var _last_sequence: Dictionary = {}
var _rigs: Array[Skeleton3D] = []
var _heads: Array[int] = []
var _base: Array[Quaternion] = []
var _epoch := -1
var _players: Array[int] = []
var _clock := 0.0
var _sequence := 0
var _snapshot_sequence := 0
var _last_snapshot := -1

func _ready() -> void:
	game = get_parent()
	for passenger in game.car.passengers:
		var dummy: Node3D = passenger.get_node("SeatedDummy")
		var player := dummy.find_child("AnimationPlayer", true, false) as AnimationPlayer
		player.stop(true)
		var rig := dummy.find_child("Skeleton3D", true, false) as Skeleton3D
		var head := rig.find_bone("Head")
		_rigs.append(rig)
		_heads.append(head)
		_base.append(rig.get_bone_pose_rotation(head))

func _sync_context() -> void:
	if _epoch == game.controls.epoch and _players == game.controls.players:
		return
	_epoch = game.controls.epoch
	_players.assign(game.controls.players)
	targets.clear()
	_received.clear()
	_last_sequence.clear()
	_last_snapshot = -1
	for index in _rigs.size():
		_rigs[index].set_bone_pose_rotation(_heads[index], _base[index])

func _physics_process(delta: float) -> void:
	_sync_context()
	if not game.session.online or (not game.session.is_host and not game._received_config):
		return
	_clock += delta
	if _clock < SEND_INTERVAL:
		return
	_clock = 0.0
	_sequence += 1
	if game.session.is_host:
		_accept(1, game.look_yaw, game.look_pitch, _sequence, _epoch)
		var samples := {}
		for id in targets:
			if _now() - float(_received.get(id, -10.0)) < STALE_SECONDS:
				samples[id] = targets[id]
		_snapshot_sequence += 1
		_snapshot.rpc(_epoch, _snapshot_sequence, samples)
	else:
		_submit.rpc_id(1, game.look_yaw, game.look_pitch, _sequence, _epoch)

func _process(delta: float) -> void:
	_sync_context()
	for index in _rigs.size():
		var angles := Vector2.ZERO
		if index < _players.size():
			var id: int = _players[index]
			if _now() - float(_received.get(id, -10.0)) < STALE_SECONDS:
				angles = targets.get(id, Vector2.ZERO)
		var rig := _rigs[index]
		# Convert car-local camera axes into the head bone's rest axes.
		var car_axes: Basis = rig.global_basis.orthonormalized().inverse() * game.car.global_basis.orthonormalized()
		var rest := rig.get_bone_global_rest(_heads[index]).basis.orthonormalized()
		var correction: Basis = rest.inverse() * car_axes * Basis.from_euler(Vector3(angles.y, angles.x, 0)) * car_axes.inverse() * rest
		var desired: Quaternion = _base[index] * correction.get_rotation_quaternion()
		var current := rig.get_bone_pose_rotation(_heads[index])
		rig.set_bone_pose_rotation(_heads[index], current.slerp(desired, 1.0-exp(-12.0*delta)))

func _accept(id: int, yaw: float, pitch: float, sequence: int, epoch: int) -> void:
	if epoch != _epoch or not _players.has(id) or not is_finite(yaw) or not is_finite(pitch):
		return
	if sequence <= int(_last_sequence.get(id, -1)):
		return
	_last_sequence[id] = sequence
	targets[id] = Vector2(clampf(wrapf(yaw, -PI, PI), -PI/2, PI/2), clampf(pitch, -.65, .65))
	_received[id] = _now()

@rpc("any_peer", "call_remote", "unreliable", 1)
func _submit(yaw: float, pitch: float, sequence: int, epoch: int) -> void:
	_sync_context()
	if game.session.online and game.session.is_host:
		_accept(multiplayer.get_remote_sender_id(), yaw, pitch, sequence, epoch)

@rpc("authority", "call_remote", "unreliable", 2)
func _snapshot(epoch: int, sequence: int, samples: Dictionary) -> void:
	_sync_context()
	if not game.session.online or game.session.is_host or epoch != _epoch or sequence <= _last_snapshot:
		return
	_last_snapshot = sequence
	for id in targets.keys():
		if not samples.has(id):
			_received.erase(id)
	for id in samples:
		if not _players.has(id) or not samples[id] is Vector2:
			continue
		var value: Vector2 = samples[id]
		if is_finite(value.x) and is_finite(value.y):
			targets[id] = Vector2(clampf(value.x, -PI/2, PI/2), clampf(value.y, -.65, .65))
			_received[id] = _now()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
