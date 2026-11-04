class_name ParkingRules
extends RefCounted

var held: float = 0.0
var success: bool = false
var contained: bool = false


func reset() -> void:
	held = 0.0
	success = false
	contained = false


func tick(car: ParkingCar, tuning: DriveTuning, delta: float) -> bool:
	contained = contains_footprint(car.global_transform, tuning)
	if success:
		return false
	var slow := car.linear_velocity.length() <= tuning.parking_speed and absf(car.yaw_speed) <= tuning.parking_yaw_speed
	held = held + delta if contained and slow else 0.0
	if held >= tuning.parking_hold:
		success = true
		return true
	return false


static func contains_footprint(car_transform: Transform3D, tuning: DriveTuning) -> bool:
	var bay := Transform3D(Basis(Vector3.UP, tuning.bay_yaw), tuning.bay_position)
	var half := tuning.bay_size * 0.5 - Vector2.ONE * tuning.parking_margin
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			var corner := bay.affine_inverse() * (car_transform * Vector3(x * tuning.body_size.x, 0.0, z * tuning.body_size.z))
			if absf(corner.x) > half.x or absf(corner.z) > half.y:
				return false
	return absf(car_transform.origin.y - tuning.start_position.y) < 0.5
