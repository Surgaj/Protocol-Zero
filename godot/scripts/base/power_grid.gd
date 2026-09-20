extends RefCounted

const DEMAND: Dictionary = {"water": 3, "kitchen": 4, "dormitory": 1, "workshop": 4}
const CAPACITY: Array[int] = [4, 8, 12]
var level: int = 1
var running: bool = false
var enabled: Dictionary = {"water": false, "kitchen": false, "dormitory": true, "workshop": false}

func capacity() -> int:
	return CAPACITY[level - 1] if running else 0

func load_requested() -> int:
	var total: int = 0
	for sector: String in DEMAND:
		if enabled[sector]:
			total += int(DEMAND[sector])
	return total

func consumption() -> int:
	return load_requested() if running else 0

func supplied(sector: String) -> bool:
	return running and bool(enabled.get(sector, false)) and load_requested() <= capacity()

func switch_sector(sector: String) -> bool:
	if not DEMAND.has(sector):
		return false
	if enabled[sector]:
		enabled[sector] = false
		return true
	if not running or load_requested() + int(DEMAND[sector]) > capacity():
		return false
	enabled[sector] = true
	return true
