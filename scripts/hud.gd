class_name ParkingHUD
extends CanvasLayer

signal reset_requested
signal host_requested
signal join_requested(code: String)
signal leave_requested
signal local_count_changed(count: int)
signal local_slot_changed(slot: int)

var room_panel: Control
var look_hint: Label
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
var wheel_labels: Array[Label] = []


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := _panel(root, Vector2(16, 12), Vector2(360, 40))
	look_hint = _label(top, "Click the view to look · Esc releases pointer", 14)
	var room := _panel(root, Vector2(-326, 12), Vector2(310, 150), true)
	room_panel = room.get_parent()
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
	var bottom := _panel(root, Vector2(16, -176), Vector2(600, 160), false, true)
	instruction = _label(bottom, "LEFT W/S · RIGHT ↑/↓", 19)
	mapping_label = _label(bottom, "You own all four wheels", 17)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(580, 12)
	progress.show_percentage = false
	progress.max_value = 1.0
	bottom.add_child(progress)
	var retry_row := HBoxContainer.new()
	bottom.add_child(retry_row)
	_button(retry_row, "Retry [R]", func(): reset_requested.emit())
	_label(retry_row, "  Release held keys after reset / remapping", 14)
	var diagram := _panel(root, Vector2(-326, -194), Vector2(310, 178), true, true)
	_label(diagram, "FRONT ↑   ·   WHEEL OWNERS", 16)
	var wheel_grid := GridContainer.new()
	wheel_grid.columns = 2
	wheel_grid.add_theme_constant_override("h_separation", 12)
	wheel_grid.add_theme_constant_override("v_separation", 5)
	diagram.add_child(wheel_grid)
	for index in 4:
		var cell := _label(wheel_grid, SharedControls.NAMES[index], 16)
		cell.custom_minimum_size = Vector2(130, 40)
		wheel_labels.append(cell)
	_label(diagram, "FL / FR front · RL / RR rear", 13)
	debug_panel = PanelContainer.new()
	debug_panel.position = Vector2(16, 64)
	debug_panel.custom_minimum_size = Vector2(430, 290)
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
	_label(debug, "Inject wheel directions (groups stay linked):", 14)
	var injections := GridContainer.new()
	injections.columns = 4
	debug.add_child(injections)
	for key in ["FL ↑", "FL ↓", "FR ↑", "FR ↓", "RL ↑", "RL ↓", "RR ↑", "RR ↓"]:
		var button := Button.new()
		button.text = key
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.x = 65
		injections.add_child(button)
		inject_buttons.append(button)
	debug_label = _label(debug, "", 14)
	debug_panel.visible = false


func update_view(session: ParkingSession, controls: SharedControls, local_id: int, parking: ParkingRules, tuning: DriveTuning, speed: float, debug_text: String, commands: int) -> void:
	status_label.text = session.status
	host_button.disabled = session.busy or session.lobby != null
	join_button.disabled = host_button.disabled
	code_edit.editable = not host_button.disabled
	leave_button.disabled = session.lobby == null or session.busy
	count_select.disabled = session.lobby != null or session.busy
	slot_select.disabled = count_select.disabled
	for button in inject_buttons:
		button.disabled = count_select.disabled
	for index in 4:
		var owner := -1
		for slot in controls.players.size():
			if controls.owned_wheels(controls.players[slot]) & (1 << index):
				owner = slot
		var yours := owner >= 0 and controls.players[owner] == local_id
		var command := SharedControls.command(commands, index)
		wheel_labels[index].text = "%s · P%d%s\n%s" % [SharedControls.NAMES[index], owner + 1, " YOU" if yours else "", SharedControls.command_text(command)]
		wheel_labels[index].modulate = Color("70d39b") if command > 0 else (Color("ec8981") if command < 0 else Color("e1e9ed"))
	mapping_label.text = "P%d · %d player%s · You own %s" % [controls.players.find(local_id) + 1, controls.players.size(), "s" if controls.players.size() > 1 else "", SharedControls.describe_wheels(controls.owned_wheels(local_id))]
	var keys := "LEFT W/S · RIGHT ↑/↓" if controls.players.size() == 1 else "W/S · your wheels forward / reverse"
	instruction.text = "PARKED!  Retry together [R]" if parking.success else keys + "\nRelease to coast · opposite drive slows then reverses"
	progress.value = parking.held / tuning.parking_hold
	progress.tooltip_text = "Hold still inside the bay"
	if parking.contained and not parking.success:
		instruction.text = keys + "\nInside bay · hold still to park"
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
