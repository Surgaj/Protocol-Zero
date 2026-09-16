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
	if float(tense_rel["tension"]) <= 0.20 or tense_memories.size() != 1 or not bool(game_state.call("is_party_member", "maya")):
		_fail("escolha de priorizar sinal não persistiu relação/memória/Maya no grupo")
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

	# Caminho cooperativo + JORNADA: Maya entra no grupo e Iris/Dante/Noah são recrutados em uma cena única.
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

	var journey: Node = _instantiate_scene("res://scenes/vertical_slice/scene_02b_journey.tscn")
	if journey == null:
		_fail("não foi possível carregar scene_02b_journey.tscn")
		return
	await process_frame
	await process_frame
	if journey.get_node_or_null("IrisEncounterTrigger") == null or journey.get_node_or_null("DanteEncounterTrigger") == null or journey.get_node_or_null("NoahEncounterTrigger") == null or journey.get_node_or_null("JourneyExit") == null:
		_fail("Jornada não possui as três batidas e saída")
		return
	if journey.get_node_or_null("ClinicTable") == null or journey.get_node_or_null("CollapsedBarrierA") == null or journey.get_node_or_null("NoahConsole") == null:
		_fail("Jornada perdeu os três marcos físicos no mesmo mapa")
		return
	var journey_panel: Control = journey.get_node_or_null("GreyboxUI/JourneyEncounter") as Control
	if journey_panel == null or journey_panel.find_child("FollowButton", true, false) == null:
		_fail("Jornada não construiu painel modal/SEGUIR")
		return

	journey.call("apply_encounter_for_test", "iris")
	journey.call("apply_encounter_for_test", "dante")
	journey.call("apply_encounter_for_test", "noah")
	await process_frame
	var party: Array = game_state.call("get_party_members") as Array
	if party.size() != 5 or not party.has("iris") or not party.has("dante") or not party.has("noah") or int(journey.call("get_joined_count")) != 4:
		_fail("Jornada não formou grupo de cinco")
		return
	journey.queue_free()
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
	if scene3_coop.get_node_or_null("Iris_GroupMarker") == null or scene3_coop.get_node_or_null("Dante_GroupMarker") == null or scene3_coop.get_node_or_null("Noah_GroupMarker") == null:
		_fail("grupo formado na Jornada não chegou ao portão do CZI-07")
		return
	if scene3_coop.get_node_or_null("CZIEntryTrigger") == null:
		_fail("Cena 3 não possui limiar de entrada para o CZI-07")
		return
	scene3_coop.queue_free()
	await process_frame

	# CZI-07 persistente — entrada, corredor, gerador e dormitório coexistem no MESMO mapa.
	# O smoke prova estrutura/estado; sensação, leitura espacial e backtracking continuam sendo validados em device real.
	var czi: Node = _instantiate_scene("res://scenes/vertical_slice/czi07_base.tscn")
	if czi == null:
		_fail("não foi possível carregar czi07_base.tscn")
		return
	await process_frame
	await process_frame

	var bunker_player: CharacterBody3D = czi.get_node_or_null("Elias_GreyCapsule") as CharacterBody3D
	var generator: StaticBody3D = czi.get_node_or_null("Geometry/GeneratorRoom/AuxGenerator") as StaticBody3D
	var bunker_interact: Button = czi.get_node_or_null("GreyboxUI/GeneratorInteract") as Button
	var generator_light: OmniLight3D = czi.get_node_or_null("GeneratorRoomLight") as OmniLight3D
	var entry_light: OmniLight3D = czi.get_node_or_null("EntryCeilingLight") as OmniLight3D
	var corridor_light: OmniLight3D = czi.get_node_or_null("CorridorLight") as OmniLight3D
	var dormitory_light: OmniLight3D = czi.get_node_or_null("DormitoryLight") as OmniLight3D
	var drone: AudioStreamPlayer = czi.get_node_or_null("BunkerDrone") as AudioStreamPlayer
	var dormitory_trigger: Area3D = czi.get_node_or_null("DormitoryTrigger") as Area3D
	if bunker_player == null or generator == null or bunker_interact == null or generator_light == null or entry_light == null or corridor_light == null or dormitory_light == null or drone == null or dormitory_trigger == null:
		_fail("CZI-07 incompleto: player/gerador/luzes/áudio/UI/trigger")
		return

	if czi.get_node_or_null("Geometry/EntranceHall") == null or czi.get_node_or_null("Geometry/MainCorridor") == null or czi.get_node_or_null("Geometry/GeneratorRoom") == null or czi.get_node_or_null("Geometry/DormitoryRoom") == null:
		_fail("CZI-07 não instancia as quatro áreas no mesmo mapa")
		return
	if czi.get_node_or_null("Geometry/DormitoryRoom/DormitoryFloor") == null or czi.get_node_or_null("Geometry/MainCorridor/DormDoorLintel") == null:
		_fail("CZI-07 perdeu passagem física/dormitório contínuo")
		return
	if drone.stream == null:
		_fail("CZI-07 não configurou AudioStreamGenerator do bunker")
		return

	bunker_player.global_position = Vector3(generator.global_position.x + 0.8, 0.90, generator.global_position.z)
	await process_frame
	await process_frame
	if not bunker_interact.visible:
		_fail("INTERAGIR do gerador auxiliar não aparece por proximidade")
		return

	czi.call("apply_power_stage_for_test", 3)
	await process_frame
	if not bool(czi.get("power_complete")):
		_fail("CZI-07 não conclui estado de energia no estágio final")
		return
	if generator_light.light_energy <= 0.0 or entry_light.light_energy <= 0.0 or corridor_light.light_energy <= 0.0 or dormitory_light.light_energy <= 0.0:
		_fail("CZI-07 não traduz energia em iluminação sequencial entre salas")
		return

	# Prova arquitetural: entrar/sair do dormitório muda apenas a zona; player e mapa continuam os mesmos.
	var original_parent: Node = bunker_player.get_parent()
	czi.call("_on_dormitory_entered", bunker_player)
	if String(czi.get("current_zone")) != "dormitory" or bunker_player.get_parent() != original_parent:
		_fail("entrada no dormitório não preserva o mesmo mapa/player")
		return
	czi.call("_on_dormitory_exited", bunker_player)
	if String(czi.get("current_zone")) != "interior" or bunker_player.get_parent() != original_parent:
		_fail("retorno do dormitório não preserva o mesmo mapa/player")
		return

	print("SMOKE PASS: rádio + Maya + Jornada + grupo de cinco + CZI persistente")
	quit(0)
