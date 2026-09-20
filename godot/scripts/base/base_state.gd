extends RefCounted

const Grid = preload("res://scripts/base/power_grid.gd")
const Life = preload("res://scripts/survival/survival_state.gd")
const IDS: Array[String] = ["maya", "iris", "dante", "noah"]
var power: Grid = Grid.new()
var resources: Life
var jobs: Dictionary = {"maya": "", "iris": "", "dante": "", "noah": ""}
var salvage: Dictionary = {}
var produced: Dictionary = {"water": 0, "kitchen": 0, "workshop": 0}
var saved_positions: Dictionary = {}
var elapsed: float = 0.0

func _init(ledger: Life = null) -> void:
	resources = ledger if ledger != null else Life.new()

func initialize_resources() -> void:
	resources.active = true
	resources.powered = false
	resources.water = 4
	resources.food = 12
	resources.meals = 3
	resources.parts = 8

func unlocked(sector: String) -> bool:
	if sector == "dormitory":
		return true
	return bool(resources.areas["pantry" if sector == "workshop" else "services"])

func repair(area: String) -> bool:
	if area not in ["services", "pantry"] or resources.areas[area] or not power.running:
		return false
	var cost: int = 2 if area == "services" else 4
	if resources.parts < cost or (area == "pantry" and not resources.areas["services"]):
		return false
	resources.parts -= cost
	resources.areas[area] = true
	return true

func upgrade_cost() -> int:
	return 6 if power.level == 1 else 12

func upgrade() -> bool:
	if not power.running or power.level >= 3 or resources.parts < upgrade_cost():
		return false
	resources.parts -= upgrade_cost()
	power.level += 1
	return true

func assign(id: String, sector: String) -> bool:
	if not jobs.has(id) or sector not in ["water", "kitchen", "workshop", ""]:
		return false
	if not sector.is_empty() and not unlocked(sector):
		return false
	for other: String in jobs:
		if other != id and jobs[other] == sector and not sector.is_empty():
			jobs[other] = ""
	jobs[id] = sector
	return true

func produce(id: String, sector: String) -> bool:
	if jobs.get(id, "") != sector or not unlocked(sector) or not power.supplied(sector):
		return false
	match sector:
		"water":
			if resources.water >= Life.WATER_CAPACITY:
				return false
			resources.water = mini(Life.WATER_CAPACITY, resources.water + 2)
		"kitchen":
			if resources.food < 1 or resources.water < 1 or resources.meals >= 20:
				return false
			resources.food -= 1
			resources.water -= 1
			resources.meals = mini(20, resources.meals + 2)
		"workshop":
			if resources.parts >= 50:
				return false
			resources.parts += 1
		_:
			return false
	produced[sector] += 1
	return true

func collect_salvage(id: String) -> bool:
	if id not in ["entry", "corridor"] or salvage.has(id):
		return false
	salvage[id] = true
	resources.parts += 4
	resources.food += 8
	return true

func snapshot() -> Dictionary:
	return {"version": 1, "level": power.level, "running": power.running, "enabled": power.enabled.duplicate(), "resources": {"water": resources.water, "food": resources.food, "meals": resources.meals, "parts": resources.parts}, "areas": resources.areas.duplicate(), "jobs": jobs.duplicate(), "salvage": salvage.duplicate(), "produced": produced.duplicate(), "positions": saved_positions.duplicate(true), "elapsed": elapsed}

func restore(data: Dictionary) -> bool:
	# Validate before mutating the live ledger; reject damaged/foreign saves.
	if data.get("version") != 1 or not data.get("resources") is Dictionary or not data.get("enabled") is Dictionary or not data.get("jobs") is Dictionary or not data.get("areas") is Dictionary:
		return false
	var rank: int = int(data.get("level", 0))
	if rank < 1 or rank > 3:
		return false
	for key: String in ["water", "food", "meals", "parts"]:
		var value = data.resources.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0 or float(value) > 10000:
			return false
	for sector: String in Grid.DEMAND:
		if not data.enabled.get(sector) is bool:
			return false
	for area: String in ["services", "pantry"]:
		if not data.areas.get(area) is bool:
			return false
	var seen: Array[String] = []
	for id: String in IDS:
		var task = data.jobs.get(id)
		if not task is String or task not in ["water", "kitchen", "workshop", ""]:
			return false
		if not String(task).is_empty():
			if seen.has(task):
				return false
			seen.append(task)
	var test_grid := Grid.new()
	test_grid.level = rank
	test_grid.running = true
	test_grid.enabled = data.enabled.duplicate()
	if test_grid.load_requested() > test_grid.capacity():
		return false
	if data.areas.pantry and not data.areas.services:
		return false
	for sector: String in ["water", "kitchen", "workshop"]:
		var open: bool = bool(data.areas["pantry" if sector == "workshop" else "services"])
		if not open and (data.enabled[sector] or seen.has(sector)):
			return false
	power.level = rank
	power.running = bool(data.get("running", false))
	power.enabled = data.enabled.duplicate()
	for key: String in ["water", "food", "meals", "parts"]:
		resources.set(key, int(data.resources[key]))
	resources.water = mini(resources.water, Life.WATER_CAPACITY)
	resources.meals = mini(resources.meals, 20)
	resources.parts = mini(resources.parts, 50)
	resources.active = true
	resources.powered = power.running
	resources.areas = data.areas.duplicate()
	jobs = data.jobs.duplicate()
	salvage.clear()
	if data.get("salvage") is Dictionary:
		for key: String in ["entry", "corridor"]:
			if data.salvage.get(key, false) == true:
				salvage[key] = true
	if data.get("produced") is Dictionary:
		for key: String in produced:
			produced[key] = maxi(0, int(data.produced.get(key, 0)))
	saved_positions = data.get("positions", {}).duplicate(true) if data.get("positions", {}) is Dictionary else {}
	elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	return true
