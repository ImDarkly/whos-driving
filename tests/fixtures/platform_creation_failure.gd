extends "res://addons/epic-online-services-godot/heos/hplatform.gd"
## Keep real SDK Initialize/AlreadyConfigured behavior; only platform creation
## is scripted, so no product configuration or network access is needed.

var create_calls: int = 0


func create_platform_async(_options: EOS.Platform.CreateOptions) -> bool:
	create_calls += 1
	return create_calls > 1
