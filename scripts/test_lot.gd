class_name TestLot
extends Node3D

var bay_fill: MeshInstance3D
@export var barrier_gap: float = 0.3
@export var barrier_height: float = 1.15


func build(tuning: DriveTuning) -> void:
	_box(Vector3(50, 0.4, 50), Vector3(0, -0.2, 0), Color("35444d"), true)
	# Perimeter contains the test area; no obstacle course in this checkpoint.
	for x in [-25.0, 25.0]:
		_box(Vector3(0.4, 0.7, 50), Vector3(x, 0.35, 0), Color("75868c"), true)
	for z in [-25.0, 25.0]:
		_box(Vector3(50, 0.7, 0.4), Vector3(0, 0.35, z), Color("75868c"), true)
	for x in range(-20, 25, 5):
		_box(Vector3(0.025, 0.008, 48), Vector3(x, 0.005, 0), Color("42535b"))
	for z in range(-20, 25, 5):
		_box(Vector3(48, 0.008, 0.025), Vector3(0, 0.005, z), Color("42535b"))
	var bay := Node3D.new()
	bay.position = tuning.bay_position
	bay.rotation.y = tuning.bay_yaw
	add_child(bay)
	# Outside containment, with the near end and left side open for an approach.
	var side_x := tuning.bay_size.x / 2.0 + barrier_gap + 0.15
	var end_z := -tuning.bay_size.y / 2.0 - barrier_gap - 0.15
	_box(Vector3(0.3, barrier_height, tuning.bay_size.y), Vector3(side_x, barrier_height / 2, 0), Color("cf8157"), true, bay)
	_box(Vector3(tuning.bay_size.x + 0.6, barrier_height, 0.3), Vector3(0, barrier_height / 2, end_z), Color("cf8157"), true, bay)
	for z in range(-2, 3):
		_box(Vector3(0.32, 0.12, 0.3), Vector3(side_x, barrier_height - 0.15, z), Color("fff3c5"), false, bay)
	for x in [-1.0, 0.0, 1.0]:
		_box(Vector3(0.3, 0.12, 0.32), Vector3(x, barrier_height - 0.15, end_z), Color("fff3c5"), false, bay)
	bay_fill = _box(Vector3(tuning.bay_size.x, 0.012, tuning.bay_size.y), Vector3(0, 0.015, 0), Color("42665d"), false, bay)
	for x in [-tuning.bay_size.x / 2.0, tuning.bay_size.x / 2.0]:
		_box(Vector3(0.1, 0.025, tuning.bay_size.y + 0.1), Vector3(x, 0.035, 0), Color("bde8be"), false, bay)
	for z in [-tuning.bay_size.y / 2.0, tuning.bay_size.y / 2.0]:
		_box(Vector3(tuning.bay_size.x + 0.1, 0.025, 0.1), Vector3(0, 0.035, z), Color("bde8be"), false, bay)
	var marker := Label3D.new()
	marker.text = "PARK HERE"
	marker.font_size = 72
	marker.pixel_size = 0.012
	marker.rotation_degrees.x = -90
	marker.position = Vector3(0, 0.06, -tuning.bay_size.y / 2.0 - 0.7)
	marker.modulate = Color("bde8be")
	bay.add_child(marker)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("263641")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c2d7e5")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)


func show_parking(success: bool, contained: bool) -> void:
	var material := bay_fill.material_override as StandardMaterial3D
	material.albedo_color = Color("68a877") if success else (Color("527b67") if contained else Color("42665d"))


func _box(size: Vector3, at: Vector3, color: Color, collision: bool = false, parent: Node3D = self) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material_override = material
	parent.add_child(mesh)
	if collision:
		var body := StaticBody3D.new()
		body.position = at
		var shape := CollisionShape3D.new()
		var rectangle := BoxShape3D.new()
		rectangle.size = size
		shape.shape = rectangle
		body.add_child(shape)
		parent.add_child(body)
	return mesh
