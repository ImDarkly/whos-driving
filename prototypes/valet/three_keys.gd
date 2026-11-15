extends Node3D

const Lot = preload("res://prototypes/valet/three_keys_lot.gd")
const DRIVE_KEYS := [KEY_W, KEY_S, KEY_UP, KEY_DOWN]
const CAR_KEYS := [KEY_1, KEY_2, KEY_3]
const BLUE := 1
const RED := 2
const LOOK_SENSITIVITY := 0.0025

enum Phase { BLUE_ARRIVAL, RED_ARRIVAL, PICKUP, FINISHED }

var tuning: DriveTuning = preload("res://tuning.tres").duplicate()
var parking := ParkingRules.new()
var controls := SharedControls.new()
var lot := Lot.new()
var cars: Array[ParkingCar] = []
var car_labels: Array[Label3D] = []
var phase := Phase.BLUE_ARRIVAL
var requested := 0
var selected := BLUE
var focus_active := true
var blocked_keys := 0
var switch_requested := -1
var red_arrival := PhysicsShapeQueryParameters3D.new()
var camera: Camera3D
var look_yaw := 0.0
var look_pitch := 0.0

var schedule: Label
var objective: Label
var status: Label
var progress: ProgressBar
var replay: HBoxContainer
var look_hint: Label


func _ready() -> void:
	get_window().title = "Who's Driving? · Three Keys"
	add_child(lot)
	lot.build_lot()
	for id in Lot.NAMES.size():
		var car := ParkingCar.new()
		car.name = Lot.NAMES[id]
		car.tuning = tuning
		car.freeze = true
		add_child(car)
		car.show_passengers(0, -1)
		lot.paint_car(car.visual, id)
		cars.append(car)
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.pixel_size = 0.011
		label.position.y = 1.42
		label.modulate = Lot.COLORS[id]
		car.add_child(label)
		car_labels.append(label)
	var arrival_box := BoxShape3D.new()
	arrival_box.size = tuning.body_size
	red_arrival.shape = arrival_box
	red_arrival.transform = _start_pose(RED)

	camera = Camera3D.new()
	camera.fov = 85.0
	camera.near = 0.04
	add_child(camera)
	camera.make_current()
	_build_hud()
	_restart(0)


func _start_pose(id: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, Lot.YAWS[id]), Lot.STARTS[id])


func _restart(pickup: int) -> void:
	requested = pickup
	phase = Phase.BLUE_ARRIVAL
	for id in cars.size():
		var car := cars[id]
		car.freeze = true
		car.reset_car()
		car.global_transform = _start_pose(id)
		car.reset_physics_interpolation()
	_set_red_present(false)
	_select(BLUE)


func _set_red_present(present: bool) -> void:
	cars[RED].visible = present
	cars[RED].collision_layer = int(present)
	cars[RED].collision_mask = int(present)


func _select(id: int) -> void:
	# A parked car keeps the same rigid body, collision footprint and pose.
	var previous := cars[selected]
	previous.set_commands(0)
	previous.freeze = true
	previous.linear_velocity = Vector3.ZERO
	previous.angular_velocity = Vector3.ZERO
	selected = id
	switch_requested = -1
	cars[id].freeze = phase == Phase.FINISHED
	look_yaw = 0.0
	look_pitch = 0.0
	_update_view()
	parking.reset()
	blocked_keys |= _raw_keys()
	_update_stage()


func _physics_process(delta: float) -> void:
	if phase == Phase.FINISHED:
		return
	var car := cars[selected]
	if switch_requested >= 0:
		var next := switch_requested
		switch_requested = -1
		if _stopped(car):
			_select(next)
			return
	if phase == Phase.RED_ARRIVAL and not cars[RED].visible:
		if get_world_3d().direct_space_state.intersect_shape(red_arrival, 1).is_empty():
			_set_red_present(true)
			if _stopped(car):
				_select(RED)
				return
			_update_stage()
	var keys := _raw_keys()
	blocked_keys &= keys
	car.set_commands(controls.keyboard_mask(1, keys & ~blocked_keys if focus_active else 0))
	var bay := _target(car)
	if bay < 0:
		parking.reset()
		return
	_set_target(bay)
	if parking.tick(car, tuning, delta):
		_advance()


func _target(car: ParkingCar) -> int:
	match phase:
		Phase.BLUE_ARRIVAL:
			if selected == BLUE:
				for bay in [Lot.Bay.NEAR, Lot.Bay.FAR]:
					_set_target(bay)
					if ParkingRules.contains_footprint(car.global_transform, tuning):
						return bay
		Phase.RED_ARRIVAL:
			if selected == RED:
				return Lot.Bay.RED
		Phase.PICKUP:
			if selected == requested:
				return Lot.Bay.CURB
	return -1


func _set_target(bay: int) -> void:
	var bounds := Lot.BAYS[bay]
	var center := bounds.get_center()
	tuning.bay_position = Vector3(center.x, 0, center.y)
	tuning.bay_size = bounds.size
	tuning.bay_yaw = 0.0


func _advance() -> void:
	match phase:
		Phase.BLUE_ARRIVAL:
			phase = Phase.RED_ARRIVAL
			_update_stage()
		Phase.RED_ARRIVAL:
			phase = Phase.PICKUP
			_select(requested)
		Phase.PICKUP:
			phase = Phase.FINISHED
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_select(requested)


func _raw_keys() -> int:
	var keys := 0
	for index in DRIVE_KEYS.size():
		if Input.is_physical_key_pressed(DRIVE_KEYS[index]):
			keys |= 1 << index
	return keys


func _stopped(car: ParkingCar) -> bool:
	return car.linear_velocity.length() <= tuning.parking_speed and absf(car.yaw_speed) <= tuning.parking_yaw_speed


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focus_active = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		blocked_keys = 15
		switch_requested = -1
		for car in cars:
			car.set_commands(0)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		focus_active = true


func _input(event: InputEvent) -> void:
	if not focus_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_yaw = wrapf(look_yaw - event.relative.x * LOOK_SENSITIVITY, -PI, PI)
		look_pitch = clampf(look_pitch - event.relative.y * LOOK_SENSITIVITY, -1.15, 1.15)
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	var id := CAR_KEYS.find(event.physical_keycode)
	if phase == Phase.FINISHED:
		if id in [0, BLUE]:
			_restart(id)
	elif id >= 0 and id != selected and cars[id].visible:
		switch_requested = id


func _unhandled_input(event: InputEvent) -> void:
	if focus_active and phase != Phase.FINISHED and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_view() -> void:
	var car := cars[selected]
	var look := Basis.from_euler(Vector3(look_pitch, look_yaw, 0))
	camera.global_transform = car.global_transform * Transform3D(look, car.seat_position(0))


func _process(_delta: float) -> void:
	_update_view()
	progress.value = parking.held / tuning.parking_hold
	progress.visible = parking.contained and phase != Phase.FINISHED
	if phase != Phase.FINISHED:
		look_hint.text = ("Mouse to look · Esc releases cursor" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else "Click to look around")
		status.text = "Driving %s   ·   %s" % [
			Lot.NAMES[selected],
			"1 Yellow   2 Blue   3 Red" if _stopped(cars[selected]) else "Stop to switch cars",
		]


func _update_stage() -> void:
	var bays: Array[int] = []
	var name_of_pickup: String = Lot.NAMES[requested]
	schedule.text = "FIRST PICKUP   ·   %s" % name_of_pickup.to_upper()
	schedule.add_theme_color_override("font_color", Lot.COLORS[requested])
	replay.visible = phase == Phase.FINISHED
	status.visible = not replay.visible
	look_hint.visible = not replay.visible
	match phase:
		Phase.BLUE_ARRIVAL:
			bays = [Lot.Bay.NEAR, Lot.Bay.FAR]
			objective.text = "Park Blue in either green bay. Stop fully inside."
		Phase.RED_ARRIVAL:
			bays = [Lot.Bay.RED]
			objective.text = ("Park Red in its green bay. Stop fully inside." if cars[RED].visible
				else "Red is waiting for the left entrance to clear.")
		Phase.PICKUP:
			bays = [Lot.Bay.CURB]
			objective.text = "Bring %s to the hotel curb. Stop fully inside." % name_of_pickup
		Phase.FINISHED:
			bays = [Lot.Bay.CURB]
			objective.text = "%s returned. Choose the first pickup for your next shift." % name_of_pickup
	lot.highlight(bays)
	for id in car_labels.size():
		car_labels[id].visible = id != selected
		car_labels[id].text = "%d  %s%s" % [
			id + 1,
			Lot.NAMES[id].to_upper(),
			"  ·  PICKUP" if phase == Phase.PICKUP and id == requested else "",
		]


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var header := VBoxContainer.new()
	canvas.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 12
	schedule = _label(header, 18)
	objective = _label(header, 26)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(162, 7)
	progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	progress.max_value = 1.0
	progress.step = 0.0
	progress.show_percentage = false
	header.add_child(progress)

	var footer := VBoxContainer.new()
	canvas.add_child(footer)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_bottom = -12
	status = _label(footer, 19)
	look_hint = _label(footer, 16)

	replay = HBoxContainer.new()
	replay.alignment = BoxContainer.ALIGNMENT_CENTER
	replay.add_theme_constant_override("separation", 12)
	footer.add_child(replay)
	for id in [0, BLUE]:
		var button := Button.new()
		button.text = "%d  ·  %s first" % [id + 1, Lot.NAMES[id]]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_restart.bind(id))
		replay.add_child(button)
	var bindings := _label(footer, 17)
	bindings.text = "W / S  Left wheels     ·     ↑ / ↓  Right wheels"


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color("17242b"))
	parent.add_child(label)
	return label
