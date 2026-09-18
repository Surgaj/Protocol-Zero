extends RefCounted

# Small deterministic economy. GameState is the only production caller of step().
# Numbers are balancing units for fiction, not real-world medical thresholds.
const IDS: Array[String] = ["elias", "maya", "iris", "dante", "noah"]
const WATER_CAPACITY: int = 20
const UNLOCK_COST: int = 2
var active: bool = false
var powered: bool = true
var water: int = 10
var food: int = 12
var meals: int = 5
var parts: int = 4
var areas: Dictionary = {"services": false, "pantry": false}
var people: Dictionary = {}
var jobs: Dictionary = {}
var events: Array[String] = []
var last_tick: String = ""
var game_over: bool = false

func _init() -> void:
	for id: String in IDS:
		people[id] = {"thirst": 0, "hunger": 0, "alive": true, "cause": ""}

func start() -> void:
	active = true

func alive(id: String) -> bool:
	return people.has(id) and bool(people[id]["alive"])

func unlock_reason(area: String) -> String:
	if not active:
		return "Amanhã, vamos abrir esta ala."
	if not areas.has(area):
		return "Área indisponível."
	if bool(areas[area]):
		return "Acesso já liberado."
	if area == "pantry" and not bool(areas["services"]):
		return "Abra a ala de serviços primeiro."
	if not powered:
		return "O mecanismo precisa de energia."
	if parts < UNLOCK_COST:
		return "Faltam peças para reparar a porta."
	return ""

func unlock(area: String) -> bool:
	if not unlock_reason(area).is_empty():
		return false
	parts -= UNLOCK_COST
	areas[area] = true
	if area == "pantry":
		food += 18
	return true

func _worker(preferred: Array[String]) -> String:
	for id: String in preferred:
		if alive(id) and condition(id) != "critical":
			return id
	return ""

func condition(id: String) -> String:
	if not alive(id):
		return "dead"
	var person: Dictionary = people[id]
	if int(person["thirst"]) >= 12 or int(person["hunger"]) >= 18:
		return "critical"
	if int(person["thirst"]) >= 6 or int(person["hunger"]) >= 9:
		return "weak"
	return "well"

func step(day: int, phase: int) -> bool:
	var tick: String = "%d:%d" % [day, phase]
	if not active or game_over or tick == last_tick:
		return false
	last_tick = tick
	jobs.clear()
	events.clear()
	for id: String in IDS:
		if alive(id):
			people[id]["thirst"] = int(people[id]["thirst"]) + 1
			people[id]["hunger"] = int(people[id]["hunger"]) + 1
	var service_open: bool = bool(areas["services"])
	if phase in [0, 3] and service_open:
		var operator: String = _worker(["maya", "noah", "dante", "iris"])
		if not operator.is_empty():
			jobs[operator] = "pump" if powered else "power_wait"
			if powered:
				water = mini(WATER_CAPACITY, water + 12)
				events.append("A bomba abasteceu o reservatório.")
	if phase in [1, 4] and service_open:
		var cook: String = _worker(["iris", "dante", "noah", "maya"])
		if not cook.is_empty():
			jobs[cook] = "cook"
			if powered and food > 0 and water >= 2:
				var batch: int = mini(food, 5)
				food -= batch
				water -= 2
				meals += batch
				events.append("A cozinha preparou uma refeição.")
			else:
				jobs[cook] = "empty_pot"
				events.append("A cozinha parou: falta energia, água ou mantimentos.")
	if phase in [2, 5]:
		# Rotate serving order by day, no permanently privileged NPC.
		for offset: int in range(IDS.size()):
			var id: String = IDS[(offset + day) % IDS.size()]
			if not alive(id):
				continue
			var drank: bool = water > 0
			var ate: bool = meals > 0
			if drank:
				water -= 1
				people[id]["thirst"] = 0
			if ate:
				meals -= 1
				people[id]["hunger"] = 0
			jobs[id] = "eat" if ate else ("drink" if drank else "empty_table")
			if not drank:
				events.append("%s encontrou o reservatório vazio." % id.capitalize())
			if not ate:
				events.append("Não há porção para %s." % id.capitalize())
	for id: String in IDS:
		if not alive(id):
			continue
		var person: Dictionary = people[id]
		if int(person["thirst"]) >= 18 or int(person["hunger"]) >= 30:
			person["alive"] = false
			person["cause"] = "água" if int(person["thirst"]) >= 18 else "comida"
			jobs.erase(id)
			events.append("%s não resistiu à falta de %s." % [id.capitalize(), person["cause"]])
		elif condition(id) == "critical":
			events.append("%s mal consegue ficar de pé. O abastecimento é urgente." % id.capitalize())
		elif condition(id) == "weak":
			events.append("%s está fraco e procura algo para beber ou comer." % id.capitalize())
	game_over = not alive("elias")
	return true

func status_text() -> String:
	for id: String in IDS:
		if not alive(id):
			return "%s não resistiu à falta de %s." % [id.capitalize(), people[id]["cause"]]
	for id: String in IDS:
		if condition(id) == "critical":
			return "%s mal fica de pé. Reabasteça água e comida." % id.capitalize()
	if water < 5:
		return "Pouca água. A bomba precisa de energia e de um operador."
	if meals < 5 and food == 0:
		return "Os mantimentos acabaram. Não haverá refeição para todos."
	if not bool(areas["services"]):
		return "Abra SERVIÇOS: precisamos de água e de uma cozinha."
	if not bool(areas["pantry"]) and food <= 7:
		return "Poucos mantimentos. O DEPÓSITO ainda está fechado."
	return events[0] if not events.is_empty() else "O bunker segue trabalhando."
