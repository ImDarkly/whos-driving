extends SceneTree
## Source/editor-only, real EOS host/join launcher. See DEV_AUTH.md.
## No test transport, identity deletion, tokens or config values in reports.

var game: Node3D
var role: String = ""
var room_code: String = ""
var elapsed: float = 0.0
var exit_requested: bool = false
var events: Array[Dictionary] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
		elif argument.begins_with("--room-code="):
			room_code = argument.trim_prefix("--room-code=")
	_start.call_deferred()


func _start() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	if role not in ["host", "client"] or not game.session.dev_auth.enabled or not game.session.dev_auth.error.is_empty():
		push_error("Use editor/source Godot, --role=host/client and --dev-auth=NAME. See tests/DEV_AUTH.md.")
		exit_requested = true
		quit(1)
		return
	if role == "client" and room_code.length() != 6:
		push_error("Client needs --room-code=CODE from the host.")
		exit_requested = true
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Who's Driving? — DEV AUTH — %s" % game.session.dev_auth.account)
	DirAccess.make_dir_recursive_absolute("res://build")
	var eos = load("res://addons/epic-online-services-godot/eos.gd").get_instance()
	eos.lobby_interface_join_lobby_callback.connect(func(data: Dictionary):
		events.append({"event": "join_result", "result_code": data.get("result_code")})
	)
	eos.lobby_interface_lobby_member_status_received_callback.connect(func(data: Dictionary):
		events.append({"event": "member_status", "status": data.get("current_status"),
			"self": data.get("target_user_id") == root.get_node("HAuth").product_user_id})
	)
	eos.lobby_interface_leave_lobby_callback.connect(func(data: Dictionary):
		events.append({"event": "leave_result", "result_code": data.get("result_code")})
	)
	game.session.room_ended.connect(func(reason: String): events.append({"event": "room_ended", "reason": reason}))
	if role == "host":
		await game.session.host_room()
	else:
		await game.session.join_room(room_code)
	_save_status()


func _process(delta: float) -> bool:
	if exit_requested:
		return true
	elapsed += delta
	if is_instance_valid(game) and role in ["host", "client"] and elapsed >= 0.5:
		elapsed = 0.0
		_save_status()
	return false


func _save_status() -> void:
	var auth = root.get_node("HAuth")
	var file := FileAccess.open("res://build/dev-auth-%s.json" % role, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"pid": OS.get_process_id(), "role": role,
			"account": game.session.dev_auth.account, "status": game.session.status,
			"online": game.session.online, "room_code": game.session.room_code,
			"product_user_id": auth.product_user_id, "players": game.controls.players.size(),
			"configured": role == "host" or game._received_config, "events": events}))
