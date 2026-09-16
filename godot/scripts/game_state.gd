extends Node

# PROTOCOL ZERO — estado persistente mínimo do vertical slice.
# Guarda relações/memórias entre cenas e decisões espaciais dentro do CZI-07.

var run_active: bool = false
var turn_index: int = 0
var citizens: Dictionary = {}
var bunker_sleep_assignment: String = ""

func ensure_new_run() -> void:
	if not run_active:
		reset_new_game()

func reset_new_game() -> void:
	run_active = true
	turn_index = 0
	bunker_sleep_assignment = ""
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
