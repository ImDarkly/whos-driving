extends TestLot

enum Bay { YELLOW, NEAR, FAR, RED, CURB }

const BAYS: Array[Rect2] = [
	Rect2(-6, -2.8, 6, 5.6),
	Rect2(0.15, -6.05, 3.2, 4.7),
	Rect2(-9.55, -11.15, 5.5, 3.4),
	Rect2(-11.9, -4.05, 3.4, 5.1),
	Rect2(6.8, -2.0, 5.3, 4.0),
]
const NAMES := ["Yellow", "Blue", "Red"]
const COLORS := [Color("ffe086"), Color("9bd2ff"), Color("ffa69b")]
const STARTS := [
	Vector3(-2.65, 0.56, 0), Vector3(1.6, 0.56, -9.65), Vector3(-10.2, 0.56, 3.55),
]
const YAWS := [-0.86, PI, 0.0]
const PALETTE := [3, 5, 0]

var surfaces: Array[MeshInstance3D] = []


func build_lot() -> void:
	_box(Vector3(27, 0.4, 19), Vector3(0, -0.2, -3.5), Color("35434c"), true)
	for x in [-13.4, 13.4]:
		_box(Vector3(0.3, 0.36, 19), Vector3(x, 0.18, -3.5), Color("b8b9a9"), true)
	for z in [-12.9, 5.9]:
		_box(Vector3(27, 0.36, 0.3), Vector3(0, 0.18, z), Color("b8b9a9"), true)
	_box(Vector3(7.4, 1.25, 1.75), Vector3(9.1, 0.625, 6.6), Color("776559"))
	_box(Vector3(7.8, 0.22, 2.0), Vector3(9.1, 1.32, 6.6), Color("ba9163"))
	_box(Vector3(5.6, 0.1, 1.4), Vector3(9.45, 0.05, 3.85), Color("998776"))
	_sign("HOTEL", Vector3(9.1, 1.85, 6.6), Color("ffe2ab"))

	_add_bay(Bay.YELLOW)
	_add_bay(Bay.NEAR, "NEAR", Vector3(1.75, 0.85, -1.35))
	_add_bay(Bay.FAR, "FAR", Vector3(-6.8, 0.85, -11.15))
	_add_bay(Bay.RED, "RED BAY", Vector3(-10.2, 0.85, -4.05))
	_add_bay(Bay.CURB, "PICKUP CURB", Vector3(9.45, 0.85, 2.85))
	for index in 5:
		var stripe := _box(Vector3(0.07, 0.012, 1.3),
			Vector3(0.18, 0.027, -2.05 - index * 0.48), Color("d3ae6d"))
		stripe.rotation.y = -PI / 4
	_sign("TURNING SPACE", Vector3(-1.0, 0.65, -2.9), Color("edd09a"))
	_build_paints()

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("293c49")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c2d7e5")
	world.environment.ambient_light_energy = 0.65
	add_child(world)


func paint_car(visual: Node3D, id: int) -> void:
	for part: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var material := part.get_active_material(surface) as StandardMaterial3D
			if material and material.albedo_texture and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				material = material.duplicate()
				material.albedo_texture = paint_textures[PALETTE[id]]
				if part.material_override:
					part.material_override = material
				else:
					part.set_surface_override_material(surface, material)


func highlight(bays: Array[int]) -> void:
	for index in surfaces.size():
		var material := surfaces[index].material_override as StandardMaterial3D
		material.albedo_color = Color("42765f") if index in bays else Color("52616a")


func _add_bay(id: Bay, title := "", label_at := Vector3.ZERO) -> void:
	var bounds := BAYS[id]
	var center := bounds.get_center()
	var at := Vector3(center.x, 0, center.y)
	_parking_space(at, 0.0, bounds.size)
	surfaces.append(_box(Vector3(bounds.size.x, 0.01, bounds.size.y),
		at + Vector3.UP * 0.007, Color("52616a")))
	_box(Vector3(bounds.size.x, 0.012, 0.07),
		Vector3(center.x, 0.018, bounds.end.y), Color("ccd0c3"))
	if not title.is_empty():
		_sign(title, label_at)


func _sign(value: String, at: Vector3, tint := Color("eff5ed")) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = 56
	label.outline_size = 10
	label.pixel_size = 0.011
	label.modulate = tint
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	add_child(label)
