class_name TestLot
extends Node3D

var bay_fill: MeshInstance3D
const PARKED_VISUAL = preload("res://assets/retro_car/retro_car_visual.tscn")
@export var barrier_gap: float = 0.3
@export var approach_left: float = -6.0
@export var approach_right: float = 16.0
@export var approach_back: float = 4.5
@export var approach_end: float = -10.2
@export var entrance_width: float = 5.5
@export var aisle_z: float = -2.9
@export var near_row_z: float = 1.1
var parked_cars: Array[StaticBody3D] = []
var paint_textures: Array[Texture2D] = []


func build(tuning: DriveTuning) -> void:
	var width := approach_right - approach_left
	var depth := approach_back - approach_end
	# One continuous collider avoids catching a settled body on a coplanar seam.
	var floor_mesh := _box(Vector3(width + 0.4, 0.4, depth + 5.9), Vector3((approach_left + approach_right) / 2, -0.2, (approach_back + 5.5 + approach_end) / 2), Color("35444d"), true)
	floor_mesh.visible = false
	_box(Vector3(width + 0.4, 0.4, depth + 0.4), Vector3((approach_left + approach_right) / 2, -0.2, (approach_back + approach_end) / 2), Color("35444d"))
	# A short driveway keeps the real spawn outside the single entrance.
	_box(Vector3(entrance_width, 0.4, 5.5), Vector3(0, -0.2, approach_back + 2.75), Color("35444d"))
	for x in [approach_left, approach_right]:
		_box(Vector3(0.3, 0.35, depth), Vector3(x, 0.175, (approach_back + approach_end) / 2), Color("b6b7a8"), true)
	_box(Vector3(width, 0.35, 0.3), Vector3((approach_left + approach_right) / 2, 0.175, approach_end), Color("b6b7a8"), true)
	for span in [Vector2(approach_left, -entrance_width / 2), Vector2(entrance_width / 2, approach_right)]:
		_box(Vector3(span.y - span.x, 0.35, 0.3), Vector3((span.x + span.y) / 2, 0.175, approach_back), Color("b6b7a8"), true)
	for x in [-entrance_width / 2, entrance_width / 2]:
		_box(Vector3(0.15, 0.015, 5.5), Vector3(x, 0.015, approach_back + 2.75), Color("ccd0c3"))
		_box(Vector3(0.15, 0.35, 5.5), Vector3(x, 0.175, approach_back + 2.75), Color("b6b7a8"), true)
	_box(Vector3(entrance_width, 0.35, 0.15), Vector3(0, 0.175, approach_back + 5.5), Color("b6b7a8"), true)
	_build_paints()
	_build_parked_lot(tuning)
	_arrow(Vector3(0, 0, 2.5), 0)
	_arrow(Vector3(2.0, 0, aisle_z), -PI / 2)
	_box(Vector3(0.06, 0.8, 0.06), Vector3(-3.35, 0.4, approach_back), Color("75868c"))
	_box(Vector3(0.6, 0.6, 0.06), Vector3(-3.35, 0.95, approach_back), Color("42665d"))
	var entrance := Label3D.new()
	entrance.text = "P"
	entrance.font_size = 48
	entrance.pixel_size = 0.008
	entrance.position = Vector3(-3.35, 0.95, approach_back + 0.035)
	add_child(entrance)
	var bay := Node3D.new()
	bay.position = tuning.bay_position
	bay.rotation.y = tuning.bay_yaw
	add_child(bay)
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
	var pitch := tuning.bay_size.x / 2 + barrier_gap + tuning.body_size.x / 2
	# Seven far spaces (including the target), five near spaces around the entrance.
	for index in 7:
		var x := tuning.bay_position.x + (index - 3) * pitch
		if index != 3:
			_parking_space(Vector3(x, 0, tuning.bay_position.z), 0, Vector2(2.8, tuning.bay_size.y))
			if index != 1:
				_park_car(Vector3(x, 0, tuning.bay_position.z), 0, tuning)
		if index not in [1, 2]:
			_parking_space(Vector3(x, 0, near_row_z), PI, Vector2(2.8, tuning.bay_size.y))
			if index != 5:
				_park_car(Vector3(x, 0, near_row_z), PI, tuning)


func _build_paints() -> void:
	var source := load("res://assets/retro_car/retro_car_Blue Car Texture.png") as Texture2D
	for color in [Color("a94b3f"), Color("c9c2ad"), Color("478575"), Color("d09a47"), Color("72787d"), Color("426ca4")]:
		var pixels := source.get_image().duplicate() as Image
		if pixels.is_compressed():
			pixels.decompress()
		pixels.convert(Image.FORMAT_RGBA8)
		for y in pixels.get_height():
			for x in pixels.get_width():
				var pixel := pixels.get_pixel(x, y)
				# Repaint blue body texels only; retain the atlas's non-body details.
				if pixel.b > pixel.r * 1.25 and pixel.b > pixel.g * 1.05 and pixel.b > 0.08:
					var paint: Color = color * clampf(pixel.get_luminance() / 0.24, 0.2, 1.4)
					paint.a = pixel.a
					pixels.set_pixel(x, y, paint)
		# Rebuild distant-detail levels too; imported mipmaps still contain blue.
		pixels.generate_mipmaps()
		paint_textures.append(ImageTexture.create_from_image(pixels))


func _arrow(at: Vector3, yaw: float) -> void:
	var arrow := Node3D.new()
	arrow.position = at
	arrow.rotation.y = yaw
	add_child(arrow)
	_box(Vector3(0.12, 0.015, 1.2), Vector3(0, 0.02, 0.2), Color("ccd0c3"), false, arrow)
	for direction in [-1, 1]:
		var tip := _box(Vector3(0.12, 0.015, 0.65), Vector3(direction * 0.2, 0.02, -0.3), Color("ccd0c3"), false, arrow)
		tip.rotation.y = direction * PI / 4


func _park_car(at: Vector3, yaw: float, tuning: DriveTuning) -> void:
	var body := StaticBody3D.new()
	body.name = "ParkedCar%d" % parked_cars.size()
	body.position = at + Vector3(0, tuning.body_size.y / 2, 0)
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tuning.body_size
	shape.shape = box
	body.add_child(shape)
	var visual := PARKED_VISUAL.instantiate()
	body.add_child(visual)
	for part in visual.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var material := part.get_active_material(surface) as StandardMaterial3D
			if material and material.albedo_texture and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				material = material.duplicate()
				material.albedo_texture = paint_textures[parked_cars.size() % paint_textures.size()]
				if part.material_override:
					part.material_override = material
				else:
					part.set_surface_override_material(surface, material)
	add_child(body)
	parked_cars.append(body)


func _parking_space(at: Vector3, yaw: float, size: Vector2) -> void:
	var space := Node3D.new()
	space.position = at
	space.rotation.y = yaw
	add_child(space)
	for x in [-size.x / 2, size.x / 2]:
		_box(Vector3(0.07, 0.012, size.y), Vector3(x, 0.018, 0), Color("ccd0c3"), false, space)
	_box(Vector3(size.x, 0.012, 0.07), Vector3(0, 0.018, -size.y / 2), Color("ccd0c3"), false, space)


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
