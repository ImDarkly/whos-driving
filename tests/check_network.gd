extends SceneTree
## TEST TRANSPORT ONLY: separate processes use localhost ENet to exercise the
## production game RPCs without EOS credentials. Does not validate EOS services.


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
