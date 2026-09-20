extends Node

func _ready() -> void:
	GameState.ensure_new_run()
	GameState.base_mode = true
	if GameState.base_core == null:
		GameState.base_core = load("res://scripts/base/base_state.gd").new(GameState.survival)
		var saved: Dictionary = load("res://scripts/base/base_save.gd").read_data()
		if saved.is_empty() or not GameState.base_core.restore(saved):
			GameState.base_core.initialize_resources()
		elif saved.get("story") is Dictionary:
			var story: Dictionary = saved.story
			var sleeper: String = str(story.get("sleep_assignment", ""))
			if sleeper in ["elias", "maya", "iris", "dante", "noah", ""]:
				GameState.bunker_sleep_assignment = sleeper
			if story.get("citizens") is Dictionary:
				for id: String in ["elias", "maya", "iris", "dante", "noah"]:
					var record = story.citizens.get(id)
					if record is Dictionary and record.get("relations") is Dictionary and record.get("memories") is Array:
						GameState.citizens[id] = record.duplicate(true)
	for id: String in ["maya", "iris", "dante", "noah"]:
		GameState.add_party_member(id)
	var map: Node = load("res://scenes/vertical_slice/czi07_base.tscn").instantiate()
	add_child(map)
