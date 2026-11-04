class_name ParkingCar
extends CharacterBody3D

var tuning: DriveTuning
var speed: float = 0.0
var steering: float = 0.0
var yaw_speed: float = 0.0
var wheels: Array[Node3D] = []


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tuning.body_size
	shape.shape = box
	add_child(shape)
	_box(Vector3(1.85, 0.65, 3.5), Vector3(0, -0.05, 0), Color("f6b94c"))
	_box(Vector3(1.5, 0.65, 1.65), Vector3(0, 0.57, 0.15), Color("273a4c"))
	# White headlights make the forward (-Z) end readable from above.
	for x in [-0.59, 0.59]:
		_box(Vector3(0.4, 0.18, 0.08), Vector3(x, 0.0, -1.77), Color("fff3c5"))
		_box(Vector3(0.35, 0.15, 0.08), Vector3(x, 0.0, 1.77), Color("c54d52"))
	for z in [-1.2, 1.2]:
		for x in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, -0.2, z)
			add_child(pivot)
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.34
			cylinder.bottom_radius = 0.34
			cylinder.height = 0.22
			wheel.mesh = cylinder
			wheel.rotation.z = PI / 2.0
			wheel.material_override = _material(Color("19232d"))
			pivot.add_child(wheel)
			wheels.append(pivot)


func step(mask: int, delta: float) -> void:
	var drive := int(bool(mask & SharedControls.W)) - int(bool(mask & SharedControls.S))
	var turn := int(bool(mask & SharedControls.A)) - int(bool(mask & SharedControls.D))
	var target := float(drive) * (tuning.forward_speed if drive > 0 else tuning.reverse_speed)
	var rate := tuning.acceleration
	if drive == 0:
		rate = tuning.coast_drag
	elif speed * drive < 0:
		# Stop this tick before accelerating in the other direction on later ticks.
		target = 0.0
		rate = tuning.braking
	speed = move_toward(speed, target, rate * delta)
	steering = move_toward(steering, turn * deg_to_rad(tuning.steering_degrees), tuning.steering_rate * delta)
	yaw_speed = speed / tuning.wheelbase * tan(steering)
	rotate_y(yaw_speed * delta)
	var forward := -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y -= tuning.gravity * delta
	move_and_slide()
	# Project actual velocity after collision so driving into a wall cannot store speed.
	speed = velocity.dot(forward)
	update_wheels()


func reset_car() -> void:
	global_transform = Transform3D(Basis.IDENTITY, tuning.start_position)
	velocity = Vector3.ZERO
	speed = 0.0
	steering = 0.0
	yaw_speed = 0.0
	reset_physics_interpolation()
	update_wheels()


func update_wheels() -> void:
	for index in wheels.size():
		wheels[index].rotation.y = steering if index < 2 else 0.0


func _box(size: Vector3, offset: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = offset
	mesh.material_override = _material(color)
	add_child(mesh)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
