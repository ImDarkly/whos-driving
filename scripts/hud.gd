class_name ParkingHUD
extends CanvasLayer

signal reset_requested
signal host_requested
signal join_requested(code: String)
signal leave_requested
signal local_count_changed(count: int)
signal local_slot_changed(slot: int)

var status_label: Label
var instruction: Label
var mapping_label: Label
var debug_label: Label
var debug_panel: PanelContainer
var progress: ProgressBar
var host_button: Button
var join_button: Button
var leave_button: Button
var code_edit: LineEdit
var count_select: OptionButton
var slot_select: OptionButton
var inject_buttons: Array[Button] = []


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := _panel(root, Vector2(22, 18), Vector2(340, 100))
	var title := _label(top, "WHO'S DRIVING?", 26)
	title.add_theme_color_override("font_color", Color("f6b94c"))
	_label(top, "Shared controls · first playable", 15)
	_label(top, "Park the whole car. Hold still. Retry.", 15)
	var room := _panel(root, Vector2(-342, 18), Vector2(320, 170), true)
	status_label = _label(room, "Local practice", 16)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := HBoxContainer.new()
	room.add_child(buttons)
	host_button = _button(buttons, "Host room", func(): host_requested.emit())
	leave_button = _button(buttons, "Leave room", func(): leave_requested.emit())
	var join_row := HBoxContainer.new()
	room.add_child(join_row)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "ROOM CODE"
	code_edit.max_length = 6
	code_edit.custom_minimum_size.x = 160
	join_row.add_child(code_edit)
	join_button = _button(join_row, "Join", func():
		join_requested.emit(code_edit.text)
		code_edit.release_focus()
	)
	code_edit.text_submitted.connect(func(code: String):
		join_requested.emit(code)
		code_edit.release_focus()
	)
	_label(room, "F3 · connection / local channel tests", 14)
	var bottom := _panel(root, Vector2(22, -154), Vector2(620, 132), false, true)
	instruction = _label(bottom, "W forward · S stop / reverse · A/D steer", 19)
	mapping_label = _label(bottom, "P1: W/A/S/D", 17)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(580, 12)
	progress.show_percentage = false
	progress.max_value = 1.0
	bottom.add_child(progress)
	var retry_row := HBoxContainer.new()
	bottom.add_child(retry_row)
	_button(retry_row, "Retry [R]", func(): reset_requested.emit())
	_label(retry_row, "  No Space · release keys after reset", 14)
	debug_panel = PanelContainer.new()
	debug_panel.position = Vector2(22, 140)
	debug_panel.custom_minimum_size = Vector2(340, 250)
	debug_panel.add_theme_stylebox_override("panel", _style())
	root.add_child(debug_panel)
	var debug := VBoxContainer.new()
	debug.add_theme_constant_override("separation", 8)
	debug_panel.add_child(debug)
	_label(debug, "LOCAL CHANNEL TEST / DEBUG", 16)
	count_select = OptionButton.new()
	for count in range(1, 5):
		count_select.add_item("%d local player%s" % [count, "s" if count > 1 else ""])
	count_select.item_selected.connect(func(index: int): local_count_changed.emit(index + 1))
	debug.add_child(count_select)
	slot_select = OptionButton.new()
	slot_select.add_item("Keyboard → P1")
	slot_select.item_selected.connect(func(index: int): local_slot_changed.emit(index))
	debug.add_child(slot_select)
	_label(debug, "Toggle actions into their owning channels:", 14)
	var injections := HBoxContainer.new()
	debug.add_child(injections)
	for key in ["W", "A", "S", "D"]:
		var button := Button.new()
		button.text = key
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.x = 65
		injections.add_child(button)
		inject_buttons.append(button)
	debug_label = _label(debug, "", 14)
	debug_panel.visible = false


func update_view(session: ParkingSession, controls: SharedControls, local_id: int, parking: ParkingRules, tuning: DriveTuning, speed: float, debug_text: String) -> void:
	status_label.text = session.status
	host_button.disabled = session.busy or session.lobby != null
	join_button.disabled = host_button.disabled
	code_edit.editable = not host_button.disabled
	leave_button.disabled = session.lobby == null or session.busy
	count_select.disabled = session.lobby != null or session.busy
	slot_select.disabled = count_select.disabled
	for button in inject_buttons:
		button.disabled = count_select.disabled
	var parts: PackedStringArray = []
	for index in controls.players.size():
		var id := controls.players[index]
		parts.append("P%d%s: %s" % [index + 1, " (you)" if id == local_id else "", SharedControls.describe(controls.owned_mask(id))])
	mapping_label.text = "    ".join(parts)
	instruction.text = "PARKED!  Retry together [R]" if parking.success else "W forward · S stop / reverse · A/D steer"
	progress.value = parking.held / tuning.parking_hold
	debug_label.text = "%s\nSpeed %.2f m/s · attempt %d\n%s" % [debug_text, speed, controls.epoch, "Fully inside bay" if parking.contained else "Outside bay"]


func set_local_count(count: int) -> void:
	count_select.select(count - 1)
	slot_select.clear()
	for index in count:
		slot_select.add_item("Keyboard → P%d" % (index + 1))
	slot_select.select(0)
	clear_injections()


func injected_mask() -> int:
	var result: int = 0
	for index in inject_buttons.size():
		if inject_buttons[index].button_pressed:
			result |= 1 << index
	return result


func clear_injections() -> void:
	for button in inject_buttons:
		button.set_pressed_no_signal(false)


func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _panel(parent: Control, at: Vector2, size: Vector2, right: bool = false, bottom: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	if right:
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
	if bottom:
		panel.anchor_top = 1.0
		panel.anchor_bottom = 1.0
	panel.position = at
	panel.custom_minimum_size = size
	panel.add_theme_stylebox_override("panel", _style())
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	return column


func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.085, 0.11, 0.93)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style
