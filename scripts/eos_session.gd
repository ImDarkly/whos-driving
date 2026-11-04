class_name ParkingSession
extends Node
## EOS lobby discovery + the installed EOSGMultiplayerPeer transport.
## Game RPCs live in main.gd. No automatic login when the scene opens.

signal room_started
signal room_ended(reason: String)

const BUCKET := "whosdriving-v1"
const SOCKET := "WhosDrivingV1"
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

# The 2.3.1 native binding reads this field, but its GDScript options omit it.
# Keep the upstream addon intact; an empty list means no platform restriction.
class LobbyOptions extends EOS.Lobby.CreateLobbyOptions:
	var allowed_platform_ids: Array = []

var lobby: HLobby
var peer: EOSGMultiplayerPeer
var room_code: String = ""
var status: String = "Local practice"
var busy: bool = false
var online: bool = false
var is_host: bool = true
var _platform_ready: bool = false
var _connecting_since: float = 0.0
var _leaving: bool = false
var dev_auth: Dictionary = {"enabled": false, "account": "", "server": "localhost:8081", "error": ""}
var _dev_auth_result: int = -1


func _ready() -> void:
	dev_auth = dev_auth_options(OS.get_cmdline_user_args(), OS.has_feature("editor"))
	IEOS.auth_interface_login_callback.connect(func(data: Dictionary):
		if dev_auth.enabled:
			_dev_auth_result = int(data.get("result_code", -1))
	)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): leave_room("Could not connect to host."))
	multiplayer.server_disconnected.connect(func(): leave_room("Host left. Room ended."))


func _process(_delta: float) -> void:
	if peer and lobby and is_host:
		# Accept only EOS identities actually in this room. Lobby updates can arrive
		# after the request, so leave unknown requests pending rather than accepting.
		for user_id in peer.get_all_connection_requests():
			if lobby.get_member_by_product_user_id(user_id):
				peer.accept_connection_request(user_id)
	if peer and not is_host and not online and _connecting_since > 0.0:
		if Time.get_ticks_msec() / 1000.0 - _connecting_since > 15.0:
			leave_room("Host connection timed out. Try joining again.")


func host_room() -> void:
	if busy or lobby:
		return
	busy = true
	if not await _login():
		busy = false
		return
	status = "Creating room…"
	var options := LobbyOptions.new()
	options.bucket_id = BUCKET
	options.max_lobby_members = 4
	options.disable_host_migration = true
	options.presence_enabled = false
	options.enable_join_by_id = false
	options.allow_invites = false
	options.enable_rtc_room = false
	lobby = await HLobbies.create_lobby_async(options)
	if not lobby:
		status = "Could not create EOS room. Check the client policy and logs."
		busy = false
		return
	room_code = ""
	var random := Crypto.new().generate_random_bytes(6)
	for byte in random:
		room_code += CODE_ALPHABET[int(byte) % CODE_ALPHABET.length()]
	lobby.add_attribute("room_code", room_code)
	if not await lobby.update_async():
		await lobby.destroy_async()
		lobby = null
		status = "Could not publish room code. Check EOS lobby permissions."
		busy = false
		return
	is_host = true
	peer = EOSGMultiplayerPeer.new()
	peer.set_auto_accept_connection_requests(false)
	var error := peer.create_server(SOCKET)
	if error != OK:
		await lobby.destroy_async()
		lobby = null
		peer = null
		status = "EOS host transport failed: %s" % error_string(error)
		busy = false
		return
	multiplayer.multiplayer_peer = peer
	online = true
	_watch_lobby()
	status = "Hosting · %s" % room_code
	busy = false
	room_started.emit()


func join_room(code: String) -> void:
	if busy or lobby:
		return
	code = code.strip_edges().to_upper()
	if code.length() != 6:
		status = "Enter the six-character room code."
		return
	busy = true
	if not await _login():
		busy = false
		return
	status = "Finding room…"
	var found = await HLobbies.search_by_attribute_async([
		{"key": EOS.Lobby.SEARCH_BUCKET_ID, "value": BUCKET},
		{"key": "room_code", "value": code},
	])
	if found == null or found.size() != 1:
		status = "Room not found or code ambiguous. Ask the host for a new code."
		busy = false
		return
	HLobbies.presence_enabled = false
	lobby = await HLobbies.join_async(found[0])
	if not lobby:
		status = "Could not join. The room may be full or closed."
		busy = false
		return
	room_code = code
	is_host = false
	peer = EOSGMultiplayerPeer.new()
	peer.set_auto_accept_connection_requests(false)
	var error := peer.create_client(SOCKET, lobby.owner_product_user_id)
	if error != OK:
		await lobby.leave_async()
		lobby = null
		peer = null
		status = "EOS client transport failed: %s" % error_string(error)
		busy = false
		return
	_connecting_since = Time.get_ticks_msec() / 1000.0
	multiplayer.multiplayer_peer = peer
	_watch_lobby()
	status = "Connecting to host…"
	# Busy remains true until connected or timed out.


func leave_room(reason: String = "Left room. Local practice.") -> void:
	if _leaving:
		return
	_leaving = true
	var old_lobby := lobby
	var was_host := is_host
	lobby = null
	online = false
	busy = true
	_connecting_since = 0.0
	if peer:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	room_code = ""
	status = reason
	room_ended.emit(reason)
	if old_lobby and old_lobby.is_valid():
		if was_host:
			await old_lobby.destroy_async()
		else:
			await old_lobby.leave_async()
	is_host = true
	busy = false
	_leaving = false


func _connected() -> void:
	if not peer or is_host:
		return
	online = true
	busy = false
	_connecting_since = 0.0
	status = "Joined · %s" % room_code
	room_started.emit()


func _watch_lobby() -> void:
	var watched: WeakRef = weakref(lobby)
	lobby.kicked_from_lobby.connect(func():
		if lobby != null and lobby == watched.get_ref():
			leave_room("Room closed or connection lost. Local practice.")
	)
	lobby.lobby_owner_changed.connect(func():
		if lobby != null and lobby == watched.get_ref():
			leave_room("Host changed. Room ended; host migration is disabled.")
	)


func _login() -> bool:
	if not str(dev_auth.error).is_empty():
		status = dev_auth.error
		return false
	if not _platform_ready:
		var path := "res://eos.local.cfg"
		if OS.has_feature("standalone"):
			path = OS.get_executable_path().get_base_dir().path_join("eos.local.cfg")
		var credentials := _load_credentials(path)
		if credentials == null:
			return false
		status = "Initializing EOS…"
		HPlatform.flags = EOS.Platform.PlatformFlags.DisableOverlay
		if not await HPlatform.setup_eos_async(credentials):
			status = "EOS initialization failed. Check the local config and logs."
			return false
		_platform_ready = true
	if HAuth.product_user_id.is_empty():
		if dev_auth.enabled:
			return await _login_developer()
		status = "Connecting to EOS…"
		# Preserve any existing device identity. The addon's anonymous helper deletes
		# it before login, which is unnecessary here and disrupts parallel instances.
		var create := EOS.Connect.CreateDeviceIdOptions.new()
		create.device_model = OS.get_name()
		EOS.Connect.ConnectInterface.create_device_id(create)
		var result: Dictionary = await IEOS.connect_interface_create_device_id_callback
		if not EOS.is_success(result) and result.result_code != EOS.Result.DuplicateNotAllowed:
			status = "EOS device login failed: %s" % EOS.result_str(result)
			return false
		var login := EOS.Connect.LoginOptions.new()
		login.credentials = EOS.Connect.Credentials.new()
		login.credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken
		login.user_login_info = EOS.Connect.UserLoginInfo.new()
		login.user_login_info.display_name = "Driver"
		HAuth.auto_fetch_external_account = false
		if not await HAuth.login_game_services_async(login):
			status = "EOS login failed. Check Connect permissions and logs."
			return false
		# On a first-ever device login, HAuth may create the Product User after the
		# login callback. Log in once more so the native peer mediator and runtime
		# both observe the new identity through their login callback listeners.
		if EOSGRuntime.local_product_user_id != HAuth.product_user_id:
			if not await HAuth.login_game_services_async(login):
				status = "EOS new-user login failed. Retry Host/Join."
				return false
	return true


func _login_developer() -> bool:
	status = "Dev Auth · %s…" % dev_auth.account
	# Only the explicit editor-only branch changes Auth settings. Players continue
	# to use Connect Device-ID directly, without Epic Account Services.
	HAuth.auto_fetch_external_account = false
	HAuth.auto_connect_account = false
	HAuth.auto_link_account = false
	HAuth.auth_login_scope_flags = EOS.Auth.ScopeFlags.BasicProfile
	if not await HAuth.login_devtool_async(dev_auth.server, dev_auth.account):
		var reason := EOS.result_str(_dev_auth_result) if _dev_auth_result >= 0 else "No callback result"
		status = "Dev Auth failed: %s (%d). Check the tool/account and local logs." % [reason, _dev_auth_result]
		return false
	# Auth authenticates the named Epic account; Connect establishes the PUID used
	# by lobbies/P2P. Keep tokens entirely inside the SDK/helper objects.
	var copied := EOS.Auth.AuthInterface.copy_user_auth_token(EOS.Auth.CopyUserAuthTokenOptions.new(), HAuth.epic_account_id)
	if not EOS.is_success(copied):
		status = "Dev Auth token lookup failed: %s" % EOS.result_str(copied)
		return false
	var login := EOS.Connect.LoginOptions.new()
	login.credentials = EOS.Connect.Credentials.new()
	login.credentials.type = EOS.ExternalCredentialType.Epic
	login.credentials.token = copied.token.access_token
	if not await HAuth.login_game_services_async(login):
		status = "Dev Auth Connect login failed. See the Connect result in local logs."
		return false
	# First-time Connect user creation does not invoke the native login listeners.
	if EOSGRuntime.local_product_user_id != HAuth.product_user_id or EOSGMultiplayerPeer.get_local_user_id() != HAuth.product_user_id:
		if not await HAuth.login_game_services_async(login):
			status = "Dev Auth new-user Connect login failed."
			return false
	if HAuth.product_user_id.is_empty() or EOSGMultiplayerPeer.get_local_user_id() != HAuth.product_user_id:
		status = "Dev Auth identity is not ready for EOS transport."
		return false
	return true


## No config setting can enable Dev Auth for players. Only explicit source/editor
## launches can select it; even debug exports reject these development options.
static func dev_auth_options(arguments: PackedStringArray, editor_build: bool) -> Dictionary:
	var options := {"enabled": false, "account": "", "server": "localhost:8081", "error": ""}
	var has_account := false
	var has_server := false
	for argument in arguments:
		if argument == "--dev-auth" or argument.begins_with("--dev-auth="):
			if has_account:
				options.error = "Dev Auth: specify one named account per instance."
				return options
			has_account = true
			options.account = argument.trim_prefix("--dev-auth=") if argument.begins_with("--dev-auth=") else ""
		elif argument == "--dev-auth-server" or argument.begins_with("--dev-auth-server="):
			if has_server:
				options.error = "Dev Auth: specify one localhost server."
				return options
			has_server = true
			options.server = argument.trim_prefix("--dev-auth-server=") if argument.begins_with("--dev-auth-server=") else ""
	if not has_account and not has_server:
		return options
	if not editor_build:
		options.error = "Dev Auth is development-only and unavailable in exported builds."
		return options
	var account_pattern := RegEx.create_from_string("^[A-Za-z0-9_-]{1,64}$")
	if not has_account or account_pattern.search(options.account) == null:
		options.error = "Dev Auth: provide a named account, for example --dev-auth=host_user."
		return options
	var server_pattern := RegEx.create_from_string("^(localhost|127\\.0\\.0\\.1):([0-9]{1,5})$")
	var server_match := server_pattern.search(options.server)
	if server_match == null or int(server_match.get_string(2)) < 1 or int(server_match.get_string(2)) > 65535:
		options.error = "Dev Auth: server must be localhost:PORT or 127.0.0.1:PORT."
		return options
	options.enabled = true
	return options


func _load_credentials(path: String) -> HCredentials:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		status = "Online needs local config: eos.local.cfg. Local practice is ready."
		return null
	var credentials := HCredentials.new()
	credentials.product_name = "Whos Driving"
	credentials.product_version = "0.1"
	for key in ["product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]:
		var value := str(config.get_value("eos", key, "")).strip_edges()
		if value.is_empty():
			status = "Online config is missing %s. Local practice is ready." % key
			return null
		credentials.set(key, value)
	credentials.encryption_key = str(config.get_value("eos", "encryption_key", ""))
	return credentials
