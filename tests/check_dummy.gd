extends SceneTree

func _initialize() -> void:
	call_deferred("check_asset")

func check_asset() -> void:
	create_timer(8).timeout.connect(func(): quit(1))
	var scene := load("res://assets/player/crash_dummy.glb") as PackedScene
	assert(scene != null)
	var instance := scene.instantiate()
	root.add_child(instance)
	var skeleton := instance.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(skeleton != null and player != null)
	assert(skeleton.get_bone_count() == 14)
	for clip in ["Stand", "Sit", "Steer", "LookSide"]:
		assert(player.has_animation(clip), "Missing pose " + clip)
		player.play(clip)
		player.advance(0.0)
		await process_frame
	var head := skeleton.find_bone("Head")
	player.play("Stand")
	player.advance(0.0)
	var forward := skeleton.get_bone_pose_rotation(head)
	player.play("LookSide")
	player.advance(0.0)
	assert(forward.angle_to(skeleton.get_bone_pose_rotation(head)) > 1.0)
	player.play("Sit")
	player.advance(0.0)
	var thigh := skeleton.find_bone("Thigh.L")
	assert(skeleton.get_bone_pose_rotation(thigh).angle_to(Quaternion.IDENTITY) > 1.4)
	var colors := {}
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		assert(node.skin != null, "Unskinned part " + node.name)
		for surface in node.mesh.get_surface_count():
			var mat: Material = node.mesh.surface_get_material(surface)
			colors[mat.resource_name] = true
	assert(colors.size() == 4)
	for color in ["yellow", "red", "blue", "green"]:
		assert(load("res://assets/player/body_%s.tres" % color) is StandardMaterial3D)
	print("DUMMY PASS: 14 bones, four pose clips, head/thigh pose changes, skinned meshes, four materials")
	instance.queue_free()
	quit(0)
