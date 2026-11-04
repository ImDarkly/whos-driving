extends SceneTree
## Credential-free recovery regressions. Run with --headless --path . --script
## tests/check_recovery.gd. The device SDK calls use scripted failure outcomes.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("RECOVERY FAIL: " + description)


func _run() -> void:
	await _device_login_retry()
	await _platform_creation_retry()
	print("RECOVERY CHECKS: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _device_login_retry() -> void:
	var auth = root.get_node("HAuth")
	var runtime = root.get_node("EOSGRuntime")
	var original_id: String = auth.product_user_id
	var original_runtime_id: String = runtime.local_product_user_id
	var session = load("res://tests/fixtures/device_login_failure.gd").new()
	root.add_child(session)
	session._platform_ready = true # Platform creation is outside this SDK fault.
	check(not await session._login() and session.connect_calls == 2, "first-user confirmation failure reports not ready")
	check(not auth.product_user_id.is_empty() and runtime.local_product_user_id.is_empty(), "fault leaves the real helper's partially created PUID")
	check(not await session._login() and session.connect_calls == 3, "retry must call Connect and report its failure despite the partial PUID")
	check(await session._login() and session.connect_calls == 4, "a later successful Connect retry can finish login")
	check(await session._login() and session.connect_calls == 4, "only completed login may be reused")
	auth.product_user_id = original_id
	runtime.local_product_user_id = original_runtime_id
	session.queue_free()
	await process_frame


func _platform_creation_retry() -> void:
	var platform = load("res://tests/fixtures/platform_creation_failure.gd").new()
	root.add_child(platform)
	var api = load("res://addons/epic-online-services-godot/eos.gd")
	var credentials = load("res://addons/epic-online-services-godot/heos/hcredentials.gd").new()
	credentials.product_name = "Recovery regression"
	credentials.product_version = "0.1"
	var initialized_events: Array[int] = [0]
	platform.platform_initialized.connect(func(): initialized_events[0] += 1)
	check(not await platform.setup_eos_async(credentials), "first platform creation failure is reported")
	check(platform.create_calls == 1, "SDK initialization reached the initial platform creation")
	check(await platform.setup_eos_async(credentials), "retry accepts real SDK AlreadyConfigured after creation failed")
	check(platform.create_calls == 2, "platform creation is retried after SDK was already initialized")
	check(initialized_events[0] == 1, "already-initialized SDK does not announce a second initialization")
	check(api.is_success(api.Platform.PlatformInterface.shutdown()), "test releases the initialized SDK")
	platform.queue_free()
	await process_frame
