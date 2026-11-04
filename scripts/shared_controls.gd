class_name SharedControls
extends RefCounted
## The host merges masks, never client-selected roles. Each action has one owner.

const W: int = 1
const A: int = 2
const S: int = 4
const D: int = 8
const ALL: int = W | A | S | D
const LAYOUTS: Array = [[ALL], [W | S, A | D], [W, S, A | D], [W, A, S, D]]

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


func owned_mask(id: int) -> int:
	var slot := players.find(id)
	return int(LAYOUTS[players.size() - 1][slot]) if slot >= 0 else 0


func submit(id: int, mask: int, sequence: int, attempt: int, now: float) -> bool:
	if attempt != epoch or not players.has(id) or sequence < 0:
		return false
	var previous: Dictionary = samples.get(id, {})
	if sequence <= int(previous.get("sequence", -1)):
		return false
	samples[id] = {"mask": mask & owned_mask(id), "sequence": sequence, "received": now}
	return true


func merged(now: float, timeout: float) -> int:
	var result: int = 0
	for id in players:
		var sample: Dictionary = samples.get(id, {})
		if not sample.is_empty() and now - float(sample.received) <= timeout:
			result |= int(sample.mask) & owned_mask(id)
	return result


static func describe(mask: int) -> String:
	var keys: PackedStringArray = []
	for item in [[W, "W"], [A, "A"], [S, "S"], [D, "D"]]:
		if mask & int(item[0]):
			keys.append(item[1])
	return "/".join(keys) if not keys.is_empty() else "—"
