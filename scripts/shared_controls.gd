class_name SharedControls
extends RefCounted
## Ownership uses four wheel bits; input uses TWO bits per wheel (+, -).
## The host enforces ownership and common commands within each group.

const FL: int = 1
const FR: int = 2
const RL: int = 4
const RR: int = 8
const LEFT: int = FL | RL
const RIGHT: int = FR | RR
const REAR: int = RL | RR
const WHEELS: int = 15
const ALL_INPUT: int = 255
const NAMES: Array[String] = ["FL", "FR", "RL", "RR"]
const LAYOUTS: Array = [[WHEELS], [LEFT, RIGHT], [FL, FR, REAR], [FL, FR, RL, RR]]

var players: Array[int] = [1]
var samples: Dictionary = {}
var epoch: int = 0


func remap(ids: Array[int]) -> void:
	assert(ids.size() >= 1 and ids.size() <= 4)
	players = ids.duplicate()
	clear()


func clear() -> void:
	epoch += 1
	samples.clear()


func owned_wheels(id: int) -> int:
	var slot := players.find(id)
	return int(LAYOUTS[players.size() - 1][slot]) if slot >= 0 else 0


func normalize(id: int, mask: int) -> int:
	var groups: Array = [LEFT, RIGHT] if players.size() == 1 else [owned_wheels(id)]
	var result := 0
	if not players.has(id):
		return 0
	for group: int in groups:
		var forward := (mask & drive(group, 1)) != 0
		var reverse := (mask & drive(group, -1)) != 0
		# Conflicting directions neutralize the whole group. A malformed sender
		# cannot split a group into independently controlled wheels.
		result |= drive(group, int(forward) - int(reverse))
	return result


func keyboard_mask(id: int, keys: int) -> int:
	# Raw physical pairs: W/S bits 0/1, Up/Down bits 2/3.
	var primary := int(bool(keys & 1)) - int(bool(keys & 2))
	if players.size() == 1:
		var secondary := int(bool(keys & 4)) - int(bool(keys & 8))
		return drive(LEFT, primary) | drive(RIGHT, secondary)
	return drive(owned_wheels(id), primary)


func submit(id: int, mask: int, sequence: int, attempt: int, now: float) -> bool:
	if attempt != epoch or not players.has(id) or sequence < 0:
		return false
	var previous: Dictionary = samples.get(id, {})
	if sequence <= int(previous.get("sequence", -1)):
		return false
	samples[id] = {"mask": normalize(id, mask), "sequence": sequence, "received": now}
	return true


func merged(now: float, timeout: float) -> int:
	var result := 0
	for id in players:
		var sample: Dictionary = samples.get(id, {})
		if not sample.is_empty() and now - float(sample.received) <= timeout:
			result |= int(sample.mask)
	return result


static func drive(wheel_bits: int, direction: int) -> int:
	var result := 0
	for index in 4:
		if wheel_bits & (1 << index) and direction != 0:
			result |= (1 if direction > 0 else 2) << (index * 2)
	return result


static func command(mask: int, index: int) -> int:
	return int(bool(mask & (1 << (index * 2)))) - int(bool(mask & (2 << (index * 2))))


static func describe_wheels(mask: int) -> String:
	var names: PackedStringArray = []
	for index in 4:
		if mask & (1 << index):
			names.append(NAMES[index])
	return "/".join(names) if not names.is_empty() else "—"


static func describe(mask: int) -> String:
	var parts: PackedStringArray = []
	for index in 4:
		parts.append("%s %s" % [NAMES[index], command_text(command(mask, index))])
	return " · ".join(parts)


static func command_text(value: int) -> String:
	return "FWD ↑" if value > 0 else ("REV ↓" if value < 0 else "NEUTRAL ·")
