class_name TestLot
extends Node3D

var bay_fill: MeshInstance3D
const PARKED_VISUAL = preload("res://assets/retro_car/retro_car_visual.tscn")
@export var barrier_gap: float = 0.3
@export var approach_left: float = -25.0
@export var approach_right: float = 25.0
@export var approach_back: float = 25.0
@export var approach_end: float = -25.0
@export var opening_width: float = 4.5
@export var first_opening := Vector2(-0.5, 3.0)
@export var second_opening := Vector2(5.0, -4.0)
var parked_cars: Array[StaticBody3D] = []


func build(tuning: DriveTuning) -> void:
	_box(Vector3(50, 0.4, 50), Vector3(0, -0.2, 0), Color("35444d"), true)
	# Rows reach the existing perimeter, closing broad shortcuts.
	for x in [-25.0, 25.0]:
		_box(Vector3(0.4, 0.7, 50), Vector3(x, 0.35, 0), Color("75868c"), true)
	for z in [-25.0, 25.0]:
		_box(Vector3(50, 0.7, 0.4), Vector3(0, 0.35, z), Color("75868c"), true)
	_build_parked_lot(tuning)
	var bay := Node3D.new()
	bay.position = tuning.bay_position
	bay.rotation.y = tuning.bay_yaw
	add_child(bay)
	# Neighbouring parked cars frame the target without changing its rules.
	var side_x := tuning.bay_size.x / 2 + barrier_gap + tuning.body_size.x / 2
	for side in [-1.0, 1.0]:
		_park_car(tuning.bay_position + Vector3(side * side_x, 0, 0), tuning.bay_yaw, tuning)
	_park_car(tuning.bay_position + Vector3(0, 0, -tuning.bay_size.y / 2 - barrier_gap - tuning.body_size.z / 2), tuning.bay_yaw, tuning)
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


func _build_parked_lot(tuning: DriveTuning) -> void:
	# Side-on cars form each offset row; gaps between bumpers stay real.
	for opening in [first_opening, second_opening]:
		for direction in [-1.0, 1.0]:
			var edge: float = opening.x + direction * opening_width / 2
			var end: float = approach_left + 0.2 if direction < 0 else approach_right - 0.2
			var length := absf(end - edge)
			var count := int(floorf(length / tuning.body_size.z))
			var gap := (length - count * tuning.body_size.z) / maxf(count - 1, 1)
			for index in count:
				var x: float = edge + direction * (tuning.body_size.z / 2 + index * (tuning.body_size.z + gap))
				_park_car(Vector3(x, 0, opening.y), direction * PI / 2, tuning)
	# Surrounding rows give the lot scale, leaving the short playable approach clear.
	for z in [-22.0, -16.0, 13.0, 19.0]:
		for index in 16:
			var x := -22.5 + index * 3.0
			_parking_space(Vector3(x, 0, z), 0, Vector2(2.8, 5.2))
			if (index + int(z)) % 7 != 0:
				_park_car(Vector3(x, 0, z), 0 if int(z) % 2 == 0 else PI, tuning, false)


func _park_car(at: Vector3, yaw: float, tuning: DriveTuning, marked: bool = true) -> void:
	var body := StaticBody3D.new()
	body.name = "ParkedCar%d" % parked_cars.size()
	body.position = at + Vector3(0, tuning.body_size.y / 2, 0)
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tuning.body_size
	shape.shape = box
	body.add_child(shape)
	body.add_child(PARKED_VISUAL.instantiate())
	add_child(body)
	parked_cars.append(body)
	if marked:
		_parking_space(at, yaw, Vector2(tuning.body_size.x + 0.3, tuning.body_size.z + 0.15))


func _parking_space(at: Vector3, yaw: float, size: Vector2) -> void:
	var space := Node3D.new()
	space.position = at
	space.rotation.y = yaw
	add_child(space)
	for x in [-size.x / 2, size.x / 2]:
		_box(Vector3(0.07, 0.012, size.y), Vector3(x, 0.018, 0), Color("ccd0c3"), false, space)
	_box(Vector3(size.x, 0.012, 0.07), Vector3(0, 0.018, size.y / 2), Color("ccd0c3"), false, space)


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
