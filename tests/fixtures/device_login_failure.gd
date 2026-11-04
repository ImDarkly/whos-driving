extends "res://scripts/eos_session.gd"
## Simulate SDK first-user creation followed by a failed confirmation login.
## Only the external SDK/helper calls are replaced; _login() runs unchanged.

var device_calls: int = 0
var connect_calls: int = 0


func _create_device_id_async() -> Dictionary:
	device_calls += 1
	return {"result_code": EOS.Result.Success if device_calls == 1 else EOS.Result.DuplicateNotAllowed}


func _connect_device_login_async(_options: EOS.Connect.LoginOptions) -> bool:
	connect_calls += 1
	if connect_calls == 1:
		# HAuth creates a PUID before the runtime/native login listeners see it.
		HAuth.product_user_id = "first-user-test-identity"
		return true
	if connect_calls in [2, 3]:
		return false
	EOSGRuntime.local_product_user_id = HAuth.product_user_id
	return true
