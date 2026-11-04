extends SceneTree
## Offline guard/selection checks. Never contacts the tool or EOS.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("DEV AUTH CHECK: " + description)


func _run() -> void:
	var session = load("res://scripts/eos_session.gd").new()
	root.add_child(session)
	for editor in [false, true]:
		var defaults: Dictionary = session.dev_auth_options([], editor)
		check(not defaults.enabled and defaults.error.is_empty(), "normal launch preserves Device-ID login")
	var host: Dictionary = session.dev_auth_options(["--dev-auth=host_user"], true)
	var client: Dictionary = session.dev_auth_options(["--dev-auth=client_user", "--dev-auth-server=127.0.0.1:8081"], true)
	check(host.enabled and host.account == "host_user" and host.server == "localhost:8081", "host named credential")
	check(client.enabled and client.account == "client_user" and client.server == "127.0.0.1:8081", "client named credential and server")
	var rejected: Array = [
		["--dev-auth"], ["--dev-auth="], ["--dev-auth-server=localhost:8081"],
		["--dev-auth=host_user", "--dev-auth=client_user"],
		["--dev-auth=host_user", "--dev-auth-server=localhost:1", "--dev-auth-server=localhost:2"],
		["--dev-auth=host_user", "--dev-auth-server=example.com:8081"],
		["--dev-auth=host_user", "--dev-auth-server=http://localhost:8081"],
		["--dev-auth=host_user", "--dev-auth-server=localhost:0"],
		["--dev-auth=host_user", "--dev-auth-server=localhost:65536"],
		["--dev-auth=host_user", "--dev-auth-server"], ["--dev-auth=bad name"],
	]
	for arguments in rejected:
		var result: Dictionary = session.dev_auth_options(PackedStringArray(arguments), true)
		check(not result.enabled and not result.error.is_empty(), "invalid options fail closed")
	for arguments in [["--dev-auth=host_user"], ["--dev-auth=client_user", "--dev-auth-server=localhost:8081"]]:
		var exported: Dictionary = session.dev_auth_options(PackedStringArray(arguments), false)
		check(not exported.enabled and "exported" in exported.error, "exports reject Dev Auth")
	session.dev_auth = session.dev_auth_options(["--dev-auth=host_user"], false)
	check(not await session._login() and not session._platform_ready, "rejected Dev Auth cannot fall back to Device-ID or initialize EOS")
	print("DEV AUTH CHECKS: ", checks, " checks, ", failures, " failures")
	session.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
