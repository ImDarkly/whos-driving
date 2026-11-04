extends SceneTree
## Default: separate processes use TEST-ONLY localhost ENet without credentials.
## Explicit `eos` opt-in runs the two-account EOS check; see run_eos_wheels.ps1.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.manual_inputs = true
	var probe := Node.new()
	probe.set_script(load("res://tests/network_probe.gd"))
	probe.name = "Probe"
	probe.game = game
	root.add_child(probe)
