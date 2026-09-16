extends SceneTree

# Milestone 0.5 smoke: estrutura física + decisão + persistência.
# Assume o grupo já formado pela Jornada; não prova clareza visual, peso emocional ou UX touch.

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("DORMITORY SMOKE FAIL: %s" % message)
	quit(1)

func _run() -> void:
	var game_state: Node = root.get_node_or_null("GameState")
	if game_state == null:
		_fail("autoload GameState ausente")
		return
	game_state.call("reset_new_game")
	for citizen_id: String in ["maya", "iris", "dante", "noah"]:
		game_state.call("add_party_member", citizen_id)

	var packed: PackedScene = load("res://scenes/vertical_slice/czi07_base.tscn") as PackedScene
	if packed == null:
		_fail("czi07_base.tscn não carregou")
		return
	var czi: Node = packed.instantiate()
	root.add_child(czi)
	await process_frame
	await process_frame
	await process_frame

	var helper: Node = czi.get_node_or_null("DormitoryDecision")
	var player: CharacterBody3D = czi.get_node_or_null("Elias_GreyCapsule") as CharacterBody3D
	if helper == null or player == null or not helper.has_method("apply_sleep_choice_for_test"):
		_fail("helper/player do dormitório ausente")
		return

	for i: int in range(1, 5):
		var bed_path: String = "Geometry/DormitoryRoom/Bed%02d" % i
		if czi.get_node_or_null(bed_path) == null:
			_fail("cama física ausente: %s" % bed_path)
			return

	var panel: Control = czi.get_node_or_null("GreyboxUI/FourBedsChoice") as Control
	var chapter_end: Control = czi.get_node_or_null("GreyboxUI/ChapterEnd") as Control
	if panel == null or panel.find_child("Choice_Maya", true, false) == null or panel.find_child("Choice_Elias", true, false) == null:
		_fail("UI de escolha das quatro camas incompleta")
		return
	if chapter_end == null or chapter_end.find_child("ChapterEndTitle", true, false) == null or chapter_end.find_child("ChapterEndSubtitle", true, false) == null:
		_fail("marcador de fim de capítulo ausente")
		return

	czi.call("apply_power_stage_for_test", 3)
	czi.call("_on_dormitory_entered", player)
	await process_frame
	helper.call("apply_sleep_choice_for_test", "maya")
	await process_frame

	if String(game_state.call("get_sleep_assignment")) != "maya":
		_fail("alocação de camas não persistiu no GameState")
		return
	if czi.get_node_or_null("Geometry/DormitoryRoom/SleepAssignmentVisuals/Floor_maya") == null:
		_fail("escolha não virou condição física visível no dormitório")
		return

	var maya_relation: Dictionary = game_state.call("get_relation", "maya", "elias") as Dictionary
	var maya_memories: Array = game_state.call("get_memories", "maya") as Array
	if float(maya_relation["tension"]) <= 0.0 or maya_memories.size() != 1:
		_fail("escolha de cama não criou relação/memória social")
		return

	print("DORMITORY SMOKE PASS: grupo formado + 4 camas + 5 pessoas + memória + consequência espacial + fim de capítulo")
	quit(0)
