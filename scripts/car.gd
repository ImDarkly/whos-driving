class_name ParkingCar
extends RigidBody3D
## Only the authority simulates. Clients freeze this body and interpolate visuals.
## Wheel forces act at fixed offsets; no steering angle or input-derived yaw.

var tuning: DriveTuning
var command_mask: int = 0
var wheels: Array[Node3D] = []
var wheel_materials: Array[StandardMaterial3D] = []
var command_markers: Array[Label3D] = []
const VISUAL = preload("res://assets/retro_car/retro_car_visual.tscn")
var visual: Node3D
var seat_anchors: Array[Node] = []
var passengers: Array[Node3D] = []
var speed: float:
	get: return linear_velocity.dot(-global_basis.z)
var yaw_speed: float:
	get: return angular_velocity.y


func _ready() -> void:
	mass = tuning.mass_kg
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	can_sleep = false
	continuous_cd = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	# Floor friction would act as a hidden brake and prevent differential turns.
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.0
	physics_material_override.bounce = 0.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tuning.body_size
	shape.shape = box
	add_child(shape)
	visual = VISUAL.instantiate()
	add_child(visual)
	seat_anchors = visual.get_node("Seats").get_children()
	var colors := [Color("70d39b"), Color("ec8981"), Color("79b9ef"), Color("d9a1e8")]
	for index in 4:
		var seat := seat_position(index)
		var head := Node3D.new()
		head.position = seat
		add_child(head)
		var face := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.14
		sphere.height = 0.28
		face.mesh = sphere
		face.material_override = _material(colors[index])
		head.add_child(face)
		var label := Label3D.new()
		label.text = "P%d" % (index + 1)
		label.position.y = 0.16
		label.font_size = 48
		label.pixel_size = 0.002
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		head.add_child(label)
		passengers.append(head)
	for index in 4:
		var wheel_name: String = ["WheelFL", "WheelFR", "WheelRL", "WheelRR"][index]
		var pivot := visual.find_child(wheel_name, true, false) as MeshInstance3D
		var material := pivot.get_active_material(0).duplicate() as StandardMaterial3D
		pivot.set_surface_override_material(0, material)
		wheels.append(pivot)
		wheel_materials.append(material)
		var marker := Label3D.new()
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.position = Vector3(0, 0.65, 0)
		marker.font_size = 40
		marker.pixel_size = 0.009
		pivot.add_child(marker)
		command_markers.append(marker)
		# Commands are readable in the HUD; floating wheel labels obscure cabin views.
		marker.visible = false


func show_passengers(count: int, local_seat: int) -> void:
	for index in passengers.size():
		passengers[index].visible = index < count and index != local_seat


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var forward := -state.transform.basis.z
	var right := state.transform.basis.x
	# Safety limits only; forces below create ALL player-driven translation/yaw.
	var longitudinal := state.linear_velocity.dot(forward)
	state.linear_velocity += forward * (clampf(longitudinal, -tuning.reverse_speed, tuning.forward_speed) - longitudinal)
	state.angular_velocity.y = clampf(state.angular_velocity.y, -tuning.max_yaw_speed, tuning.max_yaw_speed)
	for index in 4:
		var offset := state.transform.basis * tuning.wheel_positions[index]
		var point_velocity := state.linear_velocity + state.angular_velocity.cross(offset)
		var along := point_velocity.dot(forward)
		var sideways := point_velocity.dot(right)
		# Passive rolling resistance cannot overshoot zero in a fixed step.
		var rolling := signf(along) * minf(tuning.mass_kg * tuning.coast_drag / 4.0, absf(along) * mass / (4.0 * state.step))
		var lateral := sideways * minf(tuning.lateral_grip, mass / (4.0 * state.step))
		var force := forward * (SharedControls.command(command_mask, index) * tuning.wheel_force - rolling) - right * lateral
		state.apply_force(force, offset)


func set_commands(mask: int) -> void:
	command_mask = mask
	update_wheels()


func reset_car() -> void:
	global_transform = Transform3D(Basis.IDENTITY, tuning.start_position)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	constant_force = Vector3.ZERO
	constant_torque = Vector3.ZERO
	set_commands(0)
	reset_physics_interpolation()


func update_wheels() -> void:
	for index in wheels.size():
		var command := SharedControls.command(command_mask, index)
		wheel_materials[index].albedo_color = Color("70d39b") if command > 0 else (Color("ec8981") if command < 0 else Color.WHITE)
		command_markers[index].text = "↑" if command > 0 else ("↓" if command < 0 else "·")


func seat_position(index: int) -> Vector3:
	return (seat_anchors[index] as Node3D).position


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
