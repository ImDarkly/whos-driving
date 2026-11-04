class_name DriveTuning
extends Resource
## Kinematic bicycle: local -Z is forward; +Y yaw is left while moving forward.
## Distances are metres, time seconds. No simulated wheel forces or center of mass.

@export_group("Car")
## Collision/parking footprint includes protruding wheels and lights.
@export var body_size := Vector3(2.24, 1.1, 3.6)
@export var start_position := Vector3(0.0, 0.56, 6.0)
@export var wheelbase: float = 2.4
@export var forward_speed: float = 8.0
@export var reverse_speed: float = 4.0
@export var acceleration: float = 4.2
@export var braking: float = 10.0
## Passive rolling resistance when neither or both drive actions are held.
@export var coast_drag: float = 0.9
@export var steering_degrees: float = 32.0
@export var steering_rate: float = 2.8
@export var gravity: float = 20.0

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
