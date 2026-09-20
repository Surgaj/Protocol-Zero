extends Node

# PROTOCOL ZERO — estado persistente mínimo do vertical slice.
# Guarda relações/memórias entre cenas, formação do grupo e decisões espaciais no CZI-07.

signal day_phase_changed(phase: int)
const SurvivalState = preload("res://scripts/survival/survival_state.gd")
var survival: SurvivalState = SurvivalState.new()
const BaseCoreState = preload("res://scripts/base/base_state.gd")
var base_mode: bool = false
var base_core: BaseCoreState = null

const DAY_PHASES: Array[String] = ["MANHÃ", "MEIO DA MANHÃ", "MEIO-DIA", "TARDE", "FIM DE TARDE", "NOITE"]
const DAY_OBJECTS: Array[String] = ["generator", "supplies", "entrance", "communication"]
var day: int = 0
var day_phase: int = 0
var last_time_source: String = ""
var day_traces: Dictionary = {}
var cough_pending: bool = false
var cough_resolved: bool = false
var checked_cough: bool = false
# Alias: a decisão aprovada continua tendo uma única fonte de verdade.
var sleep_assignment: String:
	get:
		return bunker_sleep_assignment

var run_active: bool = false
var turn_index: int = 0
var citizens: Dictionary = {}
var bunker_sleep_assignment: String = ""
var party_members: Array[String] = []

func ensure_new_run() -> void:
	if not run_active:
		reset_new_game()

func reset_new_game() -> void:
	base_mode = false
	base_core = null
	survival = SurvivalState.new()
	day = 0
	day_phase = 0
	last_time_source = ""
	day_traces.clear()
	cough_pending = false
	cough_resolved = false
	checked_cough = false
	run_active = true
	turn_index = 0
	bunker_sleep_assignment = ""
	party_members = ["elias"]
	citizens = {
		"elias": _citizen_record(),
		"maya": _citizen_record(),
		"iris": _citizen_record(),
		"dante": _citizen_record(),
		"noah": _citizen_record(),
	}
	_ensure_relation("maya", "elias")

func _citizen_record() -> Dictionary:
	return {
		"relations": {},
		"memories": [],
	}

func _ensure_citizen(citizen_id: String) -> Dictionary:
	if not citizens.has(citizen_id):
		citizens[citizen_id] = _citizen_record()
	return citizens[citizen_id] as Dictionary

func _ensure_relation(from_id: String, to_id: String) -> Dictionary:
	var citizen: Dictionary = _ensure_citizen(from_id)
	var relations: Dictionary = citizen["relations"] as Dictionary
	if not relations.has(to_id):
		relations[to_id] = {
			"warmth": 0.0,
			"trust": 0.0,
			"tension": 0.0,
		}
	return relations[to_id] as Dictionary

func get_relation(from_id: String, to_id: String) -> Dictionary:
	return _ensure_relation(from_id, to_id)

func get_memories(citizen_id: String) -> Array:
	var citizen: Dictionary = _ensure_citizen(citizen_id)
	return citizen["memories"] as Array

func add_party_member(citizen_id: String) -> void:
	ensure_new_run()
	if not citizens.has(citizen_id):
		push_warning("GameState: cidadão desconhecido no grupo: %s" % citizen_id)
		return
	if not party_members.has(citizen_id):
		party_members.append(citizen_id)

func is_party_member(citizen_id: String) -> bool:
	return party_members.has(citizen_id)

func get_party_members() -> Array[String]:
	return party_members.duplicate()

func record_maya_substation_choice(choice: String) -> void:
	ensure_new_run()
	var relation: Dictionary = _ensure_relation("maya", "elias")
	var memory: Dictionary = {
		"event": "substation_priority",
		"theme": "trust",
		"intensity": 0.0,
		"context": "",
		"perceived_responsibility": "elias",
		"turn": turn_index,
		"choice": choice,
	}

	match choice:
		"generator":
			relation["trust"] = float(relation["trust"]) + 0.30
			relation["warmth"] = float(relation["warmth"]) + 0.15
			relation["tension"] = maxf(0.0, float(relation["tension"]) - 0.10)
			memory["intensity"] = 0.45
			memory["context"] = "Elias priorizou estabilizar o gerador antes de capturar o sinal."
		"signal":
			relation["trust"] = float(relation["trust"]) - 0.25
			relation["warmth"] = float(relation["warmth"]) - 0.05
			relation["tension"] = float(relation["tension"]) + 0.30
			memory["intensity"] = 0.55
			memory["context"] = "Elias priorizou o sinal enquanto o gerador estava instável."
		"ignored":
			relation["trust"] = float(relation["trust"]) - 0.10
			relation["tension"] = float(relation["tension"]) + 0.12
			memory["intensity"] = 0.30
			memory["context"] = "Elias não respondeu ao conflito e Maya resolveu o problema sozinha."
		_:
			push_warning("GameState: escolha de subestação desconhecida: %s" % choice)
			return

	var memories: Array = get_memories("maya")
	memories.append(memory)
	add_party_member("maya")
	turn_index += 1

func record_sleep_assignment(floor_id: String) -> void:
	ensure_new_run()
	var valid_ids: Array[String] = ["elias", "maya", "iris", "dante", "noah"]
	if not valid_ids.has(floor_id):
		push_warning("GameState: cidadão inválido na alocação de camas: %s" % floor_id)
		return
	bunker_sleep_assignment = floor_id

	if floor_id == "elias":
		for citizen_id: String in ["maya", "iris", "dante", "noah"]:
			var relation: Dictionary = _ensure_relation(citizen_id, "elias")
			relation["trust"] = float(relation["trust"]) + 0.08
			relation["warmth"] = float(relation["warmth"]) + 0.04
			var memories: Array = get_memories(citizen_id)
			memories.append({
				"event": "sleep_assignment",
				"theme": "sacrifice",
				"intensity": 0.25,
				"context": "Elias cedeu a própria cama para o grupo.",
				"perceived_responsibility": "elias",
				"turn": turn_index,
				"choice": floor_id,
			})
	else:
		var relation: Dictionary = _ensure_relation(floor_id, "elias")
		relation["trust"] = float(relation["trust"]) - 0.08
		relation["tension"] = float(relation["tension"]) + 0.18
		var memories: Array = get_memories(floor_id)
		memories.append({
			"event": "sleep_assignment",
			"theme": "fairness",
			"intensity": 0.35,
			"context": "Elias decidiu quem ficaria sem uma das quatro camas.",
			"perceived_responsibility": "elias",
			"turn": turn_index,
			"choice": floor_id,
		})
	turn_index += 1

func get_sleep_assignment() -> String:
	return bunker_sleep_assignment

func get_maya_behavior() -> Dictionary:
	var relation: Dictionary = _ensure_relation("maya", "elias")
	var trust: float = float(relation["trust"])
	var tension: float = float(relation["tension"])

	if tension > 0.20:
		return {
			"follow_distance": 2.0,
			"waits_at_doors": false,
			"takes_initiative": true,
		}
	if trust > 0.15 and tension <= 0.20:
		return {
			"follow_distance": 1.2,
			"waits_at_doors": true,
			"takes_initiative": false,
		}
	return {
		"follow_distance": 1.6,
		"waits_at_doors": false,
		"takes_initiative": false,
	}


func start_day() -> bool:
	if day != 0 or bunker_sleep_assignment.is_empty():
		return false
	day = 1
	day_phase = 0
	day_phase_changed.emit(day_phase)
	return true

func is_significant_source(source_id: String) -> bool:
	if survival.active and source_id in ["area:services", "area:pantry", "object:reservoir", "object:kitchen", "object:table", "object:power"]:
		return true
	if source_id.begins_with("observe:"):
		return ["maya", "iris", "dante", "noah"].has(source_id.trim_prefix("observe:"))
	return source_id.begins_with("object:") and DAY_OBJECTS.has(source_id.trim_prefix("object:"))

func advance_time(source_id: String) -> bool:
	if day < 1 or survival.game_over or not is_significant_source(source_id) or source_id == last_time_source:
		return false
	if day_phase >= DAY_PHASES.size() - 1:
		# À noite, outra ação resolve ignorar sem inventar uma sétima fase.
		if cough_pending:
			resolve_cough(false)
			last_time_source = source_id
		return false
	# Validate and apply unlocks atomically before time/consumption changes.
	if source_id.begins_with("area:") and not survival.unlock(source_id.trim_prefix("area:")):
		return false
	if source_id == "object:power":
		survival.powered = not survival.powered
	last_time_source = source_id
	day_phase += 1
	if survival.active:
		survival.step(day, day_phase)
	day_phase_changed.emit(day_phase)
	return true

func begin_cough() -> void:
	if day == 1 and day_phase == DAY_PHASES.size() - 1 and not cough_resolved:
		cough_pending = true

func resolve_cough(checked: bool) -> void:
	if not cough_pending:
		return
	checked_cough = checked
	cough_pending = false
	cough_resolved = true

func sleep_to_next_day() -> bool:
	if day < 1 or day_phase != 5 or survival.game_over:
		return false
	if day == 1 and not cough_resolved:
		return false
	if not survival.active:
		survival.start()
	day += 1
	day_phase = 0
	last_time_source = "rest"
	survival.step(day, day_phase)
	day_phase_changed.emit(day_phase)
	return true
