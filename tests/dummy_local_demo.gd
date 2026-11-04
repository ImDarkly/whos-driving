extends "res://tests/local_demo.gd"
## Same-PC networked dummy demo; production networking remains EOS.

func _start() -> void:
	super._start()
	load("res://tests/dummy_demo.gd").install_dummies(game)
	if DisplayServer.get_name() != "headless":
		var screen := DisplayServer.screen_get_usable_rect()
		var size := Vector2i(screen.size.x / 2 - 12, mini(screen.size.y - 80, 720))
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(screen.position + Vector2i((slot - 1) * (screen.size.x / 2) + 6, 30))
		DisplayServer.window_set_title("Who's Driving? — LOCAL DUMMIES — P%d%s" % [slot, " HOST" if slot == 1 else ""])
	print("LOCAL DUMMIES: seated avatars installed for peer ", slot)
