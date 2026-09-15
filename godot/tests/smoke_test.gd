extends SceneTree

# Headless integration smoke test do vertical slice.
# Valida lógica/integração, NÃO sensação de movimento, áudio audível, legibilidade,
# responsividade touch, timing dramático ou se diferenças de comportamento são perceptíveis em device real.
# godot --headless --path godot --script res://tests/smoke_test.gd

var _proximity_true_seen: bool = false
var _signal_locked_seen: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("SMOKE FAIL: %s" % message)
	quit(1)

func _on_test_proximity(is_near: bool) -> void:
	if is_near:
		_proximity_true_seen = true

func _on_test_signal_locked(_frequency: float) -> void:
	_signal_locked_seen = true

func _instantiate_scene(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	return scene

func _run() -> void:
	var game_state: Node = root.get_node_or_null("GameState")
	if game_state == null:
		_fail("autoload GameState ausente")
		return
	game_state.call("reset_new_game")

	# CENA 1 — rádio: comportamento, não só existência de nós.
	var scene1: Node = _instantiate_scene("res://scenes/vertical_slice/scene_01_greybox.tscn")
	if scene1 == null:
		_fail("não foi possível carregar scene_01_greybox.tscn")
		return
	await process_frame
	await process_frame

	var player: CharacterBody3D = scene1.get_node_or_null("Elias_GreyCapsule") as CharacterBody3D
	var radio: Node3D = scene1.get_node_or_null("FieldRadio") as Node3D
	var audio: AudioStreamPlayer3D = scene1.get_node_or_null("FieldRadio/StaticAudio") as AudioStreamPlayer3D
	var interact: Button = scene1.get_node_or_null("GreyboxUI/RadioInteract") as Button
	var dial: Control = scene1.get_node_or_null("GreyboxUI/RadioDial") as Control
	var decoded: Control = scene1.get_node_or_null("GreyboxUI/DecodedSignal") as Control
	if player == null or radio == null or audio == null or interact == null or dial == null or decoded == null:
		_fail("Cena 1 incompleta")
		return
	if radio.get_script() == null or not radio.has_method("begin_tuning"):
		_fail("radio.gd não anexou/parseou corretamente")
		return
	if dial.get_script() == null or not dial.has_signal("frequency_changed"):
		_fail("dial.gd não anexou/parseou corretamente")
		return

	radio.connect("proximity_changed", Callable(self, "_on_test_proximity"))
	radio.connect("signal_locked", Callable(self, "_on_test_signal_locked"))
	player.global_position = Vector3(radio.global_position.x + 0.8, 0.90, radio.global_position.z)
	await process_frame
	await process_frame
	if not bool(radio.get("player_near")) or not _proximity_true_seen or not interact.visible:
		_fail("proximidade/INTERAGIR do rádio falhou")
		return

	var tuning_started: bool = bool(radio.call("begin_tuning"))
	if not tuning_started or audio.stream == null:
		_fail("sintonia/AudioStreamGenerator do rádio falhou")
		return
	var target: float = float(radio.get("target_frequency"))
	radio.call("set_frequency", target)
	radio.call("_update_lock", 1.0)
	await process_frame
	if not bool(radio.get("locked")) or not _signal_locked_seen or not bool(scene1.get("scene_signal_locked")) or not decoded.visible:
		_fail("lock/transição narrativa do rádio falhou")
		return

	scene1.queue_free()
	await process_frame

	# CENA 2 -> CENA 3, caminho tenso: escolha vira relação + memória e comportamento.
	game_state.call("reset_new_game")
	var scene2_signal: Node = _instantiate_scene("res://scenes/vertical_slice/scene_02_maya.tscn")
	if scene2_signal == null:
		_fail("não foi possível carregar scene_02_maya.tscn")
		return
	await process_frame
	await process_frame
	if scene2_signal.get_node_or_null("Maya_GreyCapsule") == null or scene2_signal.get_node_or_null("GreyboxUI/MayaChoice") == null:
		_fail("Cena 2 não construiu Maya/UI de escolha")
		return
	scene2_signal.call("apply_choice_for_test", "signal")
	var tense_rel: Dictionary = game_state.call("get_relation", "maya", "elias") as Dictionary
	var tense_memories: Array = game_state.call("get_memories", "maya") as Array
	if float(tense_rel["tension"]) <= 0.20 or tense_memories.size() != 1:
		_fail("escolha de priorizar sinal não persistiu relação/memória")
		return
	scene2_signal.queue_free()
	await process_frame

	var scene3_tense: Node = _instantiate_scene("res://scenes/vertical_slice/scene_03_czi_approach.tscn")
	if scene3_tense == null:
		_fail("não foi possível carregar scene_03_czi_approach.tscn")
		return
	await process_frame
	await process_frame
	var maya_tense: CharacterBody3D = scene3_tense.get_node_or_null("Maya_GreyCapsule") as CharacterBody3D
	if maya_tense == null or maya_tense.get_script() == null:
		_fail("Maya da Cena 3 não carregou comportamento")
		return
	if absf(float(maya_tense.get("follow_distance")) - 2.0) > 0.01 or bool(maya_tense.get("waits_at_doors")) or not bool(maya_tense.get("takes_initiative")):
		_fail("Cena 3 não traduziu tensão em distância/iniciativa")
		return
	scene3_tense.queue_free()
	await process_frame

	# Caminho cooperativo: mesmos sistemas, parâmetros espaciais diferentes.
	game_state.call("reset_new_game")
	var scene2_coop: Node = _instantiate_scene("res://scenes/vertical_slice/scene_02_maya.tscn")
	if scene2_coop == null:
		_fail("Cena 2 cooperativa não carregou")
		return
	await process_frame
	await process_frame
	scene2_coop.call("apply_choice_for_test", "generator")
	var coop_rel: Dictionary = game_state.call("get_relation", "maya", "elias") as Dictionary
	if float(coop_rel["trust"]) <= 0.15:
		_fail("escolha de proteger gerador não aumentou confiança")
		return
	scene2_coop.queue_free()
	await process_frame

	var scene3_coop: Node = _instantiate_scene("res://scenes/vertical_slice/scene_03_czi_approach.tscn")
	if scene3_coop == null:
		_fail("Cena 3 cooperativa não carregou")
		return
	await process_frame
	await process_frame
	var maya_coop: CharacterBody3D = scene3_coop.get_node_or_null("Maya_GreyCapsule") as CharacterBody3D
	if maya_coop == null:
		_fail("Maya cooperativa ausente")
		return
	if absf(float(maya_coop.get("follow_distance")) - 1.2) > 0.01 or not bool(maya_coop.get("waits_at_doors")) or bool(maya_coop.get("takes_initiative")):
		_fail("Cena 3 não traduziu confiança em proximidade/espera")
		return
	if scene3_coop.get_node_or_null("CZIEntryTrigger") == null:
		_fail("Cena 3 não possui limiar de entrada para o CZI-07")
		return
	scene3_coop.queue_free()
	await process_frame

	# CENA 4 — bunker morto -> desperto. O smoke prova estrutura/estado; sensação/timing ficam para device real.
	var scene4: Node = _instantiate_scene("res://scenes/vertical_slice/scene_04_bunker_wakes.tscn")
	if scene4 == null:
		_fail("não foi possível carregar scene_04_bunker_wakes.tscn")
		return
	await process_frame
	await process_frame
	var bunker_player: CharacterBody3D = scene4.get_node_or_null("Elias_GreyCapsule") as CharacterBody3D
	var generator: StaticBody3D = scene4.get_node_or_null("AuxGenerator") as StaticBody3D
	var bunker_interact: Button = scene4.get_node_or_null("GreyboxUI/GeneratorInteract") as Button
	var entry_light: OmniLight3D = scene4.get_node_or_null("EntryCeilingLight") as OmniLight3D
	var corridor_light: OmniLight3D = scene4.get_node_or_null("CorridorLight") as OmniLight3D
	var distant_light: OmniLight3D = scene4.get_node_or_null("DistantRoomLight") as OmniLight3D
	var drone: AudioStreamPlayer = scene4.get_node_or_null("BunkerDrone") as AudioStreamPlayer
	if bunker_player == null or generator == null or bunker_interact == null or entry_light == null or corridor_light == null or distant_light == null or drone == null:
		_fail("Cena 4 incompleta: player/gerador/luzes/áudio/UI")
		return
	if scene4.get_node_or_null("SealedHabitationDoor") == null or scene4.get_node_or_null("DistantRoomFloor") == null:
		_fail("Cena 4 perdeu a segunda sala/porta narrativa deliberada")
		return
	if drone.stream == null:
		_fail("Cena 4 não configurou AudioStreamGenerator do bunker")
		return

	bunker_player.global_position = Vector3(generator.global_position.x + 0.8, 0.90, generator.global_position.z)
	await process_frame
	await process_frame
	if not bunker_interact.visible:
		_fail("INTERAGIR do gerador auxiliar não aparece por proximidade")
		return

	scene4.call("apply_power_stage_for_test", 3)
	await process_frame
	if not bool(scene4.get("power_complete")):
		_fail("Cena 4 não conclui estado de energia no estágio final")
		return
	if entry_light.light_energy <= 0.0 or corridor_light.light_energy <= 0.0 or distant_light.light_energy <= 0.0:
		_fail("Cena 4 não traduz energia em iluminação sequencial")
		return

	print("SMOKE PASS: rádio + GameState + Maya + entrada CZI + bunker desperto")
	quit(0)
