class_name DriveTuning
extends Resource
## Planar rigid body: local -Z is forward. Distances in metres, time in seconds.

@export_group("Car")
## Collision/parking footprint includes protruding wheels and lights.
@export var body_size := Vector3(2.24, 1.1, 3.6)
@export var start_position := Vector3(0.0, 0.56, 6.0)
@export var mass_kg: float = 800.0
## FL, FR, RL, RR. Fixed wheels; offsets from the body's centre in local space.
@export var wheel_positions := PackedVector3Array([
	Vector3(-1.0, -0.2, -1.2), Vector3(1.0, -0.2, -1.2),
	Vector3(-1.0, -0.2, 1.2), Vector3(1.0, -0.2, 1.2)])
## Newtons per wheel, same force in either direction (no active brake).
@export var wheel_force: float = 900.0
## Sideways force per wheel per m/s of local slip. Lower permits tighter turns.
@export var lateral_grip: float = 260.0
@export var forward_speed: float = 8.0
@export var reverse_speed: float = 4.0
@export var max_yaw_speed: float = 2.5
## Passive rolling deceleration in m/s², also present while driving.
@export var coast_drag: float = 0.7

@export_group("Parking")
@export var bay_position := Vector3(5.0, 0.0, -7.0)
@export var bay_size := Vector2(3.4, 5.5)
@export var bay_yaw: float = 0.0
## All four footprint corners must be inside the bay's inner rectangle.
@export var parking_margin: float = 0.04
@export var parking_speed: float = 0.18
@export var parking_yaw_speed: float = 0.08
@export var parking_hold: float = 1.2

@export_group("Networking")
@export var input_hz: float = 30.0
@export var snapshot_hz: float = 20.0
@export var stale_input_seconds: float = 0.35
@export var host_timeout_seconds: float = 8.0
@export var interpolation_speed: float = 14.0
