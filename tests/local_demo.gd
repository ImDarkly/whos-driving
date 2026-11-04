extends SceneTree
## Interactive, same-PC demo. ENet is a test transport only; the normal
## playable still uses EOS. Launch four instances with -- --slot=1 through 4.

var game: Node3D
var peer: ENetMultiplayerPeer
var slot: int = 1
var status_clock: float = 0.0
var deadline: float = 0.0
var parking_rehearsal: bool = false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--park":
			parking_rehearsal = true
		if argument.begins_with("--slot="):
			slot = clampi(int(argument.trim_prefix("--slot=")), 1, 4)
	_start.call_deferred()


func _start() -> void:
	Engine.max_fps = 30
	if DisplayServer.get_name() != "headless":
		var screen := DisplayServer.screen_get_usable_rect()
		var size := Vector2i(screen.size.x / 2 - 12, screen.size.y / 2 - 38)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(screen.position + Vector2i(((slot - 1) % 2) * (screen.size.x / 2), ((slot - 1) / 2) * (screen.size.y / 2)) + Vector2i(6, 28))
		DisplayServer.window_set_title("Who's Driving? — LOCAL TEST — P%d%s" % [slot, " HOST" if slot == 1 else ""])
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.session.lobby = load("res://addons/epic-online-services-godot/heos/hlobby.gd").new()
	game.session.is_host = slot == 1
	game.session.status = "LOCAL TEST · connecting…"
	game.session.room_ended.connect(func(_reason: String):
		peer.close()
	)
	peer = ENetMultiplayerPeer.new()
	var error: Error
	if slot == 1:
		error = peer.create_server(19462, 3)
		if error == OK:
			root.multiplayer.multiplayer_peer = peer
			game.session.online = true
			game.session.status = "LOCAL TEST · host · localhost"
			game._room_started()
	else:
		error = peer.create_client("127.0.0.1", 19462)
		if error == OK:
			root.multiplayer.connected_to_server.connect(func():
				game.session.online = true
				game.session.status = "LOCAL TEST · joined localhost"
				game._room_started()
			)
			root.multiplayer.multiplayer_peer = peer
			deadline = Time.get_ticks_msec() / 1000.0 + 15.0
	if error != OK:
		game.session.status = "LOCAL TEST · connection failed: %s" % error_string(error)
	if parking_rehearsal:
		var rehearsal := Node.new()
		rehearsal.set_script(load("res://build/parking_rehearsal.gd"))
		rehearsal.name = "ParkingRehearsal"
		rehearsal.game = game
		game.add_child(rehearsal)
	_write_status()


func _process(delta: float) -> bool:
	if not is_instance_valid(game):
		return false
	# Prevent this test launcher from starting a real EOS session accidentally.
	game.hud.host_button.disabled = true
	game.hud.join_button.disabled = true
	game.hud.code_edit.editable = false
	game.hud.leave_button.text = "Disconnect"
	game.hud.count_select.disabled = true
	game.hud.slot_select.disabled = true
	for button in game.hud.inject_buttons:
		button.disabled = true
	if deadline > 0.0 and not game.session.online and Time.get_ticks_msec() / 1000.0 > deadline:
		game.session.status = "LOCAL TEST · could not reach localhost host"
		deadline = 0.0
	status_clock += delta
	if status_clock >= 0.5:
		status_clock = 0.0
		_write_status()
	return false


func _write_status() -> void:
	var mapping: Array[int] = []
	for id in game.controls.players:
		mapping.append(game.controls.owned_mask(id))
	var file := FileAccess.open("res://build/local-demo-%d.json" % slot, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"slot": slot, "online": game.session.online,
			"players": game.controls.players.size(), "mapping": mapping,
			"configured": slot == 1 or game._received_config, "status": game.session.status,
			"parked": game.parking.success, "speed": game.car.speed,
			"position": [game.car.position.x, game.car.position.y, game.car.position.z]}))
