extends Node

func _ready() -> void:
	GameState.ensure_new_run()
	GameState.base_mode = true
	if GameState.base_core == null:
		GameState.base_core = load("res://scripts/base/base_state.gd").new(GameState.survival)
		var saved: Dictionary = load("res://scripts/base/base_save.gd").read_data()
		if saved.is_empty() or not GameState.base_core.restore(saved):
			GameState.base_core.initialize_resources()
	for id: String in ["maya", "iris", "dante", "noah"]:
		GameState.add_party_member(id)
	var map: Node = load("res://scenes/vertical_slice/czi07_base.tscn").instantiate()
	add_child(map)
