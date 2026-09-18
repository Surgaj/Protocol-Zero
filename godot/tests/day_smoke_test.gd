extends SceneTree

# Integração 0.7: usa a decisão real, cartela, mesmo mapa, UI e tweens de produção.
# Não aprova leitura visual nem sensação no celular.
var failures: int = 0
var state: Node

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("DAY SMOKE FAIL: " + message)

func finish_motion(controller: Node) -> void:
	var motions: Array = controller.get("motions") as Array
	for motion: Tween in motions:
		if motion.is_valid():
			motion.custom_step(12.0)

func _run() -> void:
	state = root.get_node("GameState")
	state.call("reset_new_game")
	check(not bool(state.call("start_day")), "dia não pode começar antes da decisão")
	check(not bool(state.call("advance_time", "observe:maya")), "ação antes do dia")
	for sleeper: String in ["maya", "iris", "dante", "noah", "elias"]:
		await _variant(sleeper)
	state.call("reset_new_game")
	check(int(state.get("day")) == 0 and not bool(state.get("cough_resolved")), "novo jogo limpa o dia")
	check((state.get("day_traces") as Dictionary).is_empty(), "novo jogo limpa rastros")
	if failures == 0:
		print("DAY SMOKE PASS: seis fases + cinco variantes + rotinas físicas + rastros persistentes + agir/ignorar + mapa contínuo")
	quit(0 if failures == 0 else 1)

func _variant(sleeper: String) -> void:
	state.call("reset_new_game")
	for id: String in ["maya", "iris", "dante", "noah"]:
		state.call("add_party_member", id)
	var scene: Node = (load("res://scenes/vertical_slice/czi07_base.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	var player: CharacterBody3D = scene.get("player") as CharacterBody3D
	var original_id: int = scene.get_instance_id()
	var helper: Node = scene.get_node("DormitoryDecision")
	scene.call("apply_power_stage_for_test", 3)
	player.position = Vector3(4.65, 0.9, -3.8)
	helper.call("apply_sleep_choice_for_test", sleeper)
	await create_timer(1.9).timeout
	var end_panel: Control = scene.get_node("GreyboxUI/ChapterEnd") as Control
	check(end_panel.visible, "cartela exibida")
	check((end_panel.find_child("ChapterEndTitle", true, false) as Label).text == "FIM DO CAPÍTULO 1", "título exato")
	await create_timer(2.55).timeout
	var controller: Node = scene.get_node_or_null("CZI07DayController")
	check(controller != null, "decisão real inicia 0.7")
	if controller == null:
		scene.queue_free()
		await process_frame
		return
	check(not end_panel.visible and bool(player.get("input_enabled")), "controle devolvido ao jogador")
	check(int(state.get("day")) == 1 and int(state.get("day_phase")) == 0, "Dia 1 começa na manhã")
	check(load("res://scripts/game_state.gd").DAY_PHASES.size() == 6, "exatamente seis fases")
	check(String(state.get("sleep_assignment")) == sleeper, "escolha preservada")
	check(not bool(state.call("start_day")), "start_day idempotente")
	finish_motion(controller)
	await process_frame
	var actors: Dictionary = controller.get("actors") as Dictionary
	check(int(controller.get("remaining_arrivals")) == 0, "todos chegam ao posto")
	for id: String in actors:
		check(is_equal_approx(float(controller.call("delay_for", id)), 1.25 if id == sleeper else 0.0), "atraso só para floor sleeper NPC")
		var morning: Vector3 = controller.call("target_for", id, 0) as Vector3
		var later: Vector3 = controller.call("target_for", id, 2) as Vector3
		check(morning.distance_to(later) > 1.0, "rotina muda: " + id)
		var route: Array = controller.call("route_between", Vector3(5.4, 0.9, -4.85), Vector3(-1, 0.9, 5.5)) as Array
		check(route.has(Vector3(4.65, 0.90, -3.7)) and route.has(Vector3(1.65, 0.90, -3.7)), "trajeto usa porta")
	if sleeper == "elias":
		check(is_equal_approx(float(player.get("move_speed")), 4.5 * 0.92), "Elias 8% mais lento")
		check(bool(controller.get("iris_greeting")), "Iris se aproxima antes do trabalho")
		check(String(controller.call("observation_line", "iris")) == "Dormiu alguma coisa?", "fala exata de Iris")
		check(not (state.get("day_traces") as Dictionary).has("iris"), "Iris ainda não abriu a caixa")
	else:
		check(is_equal_approx(float(player.get("move_speed")), 4.5), "velocidade normal nas variantes NPC")
		check(String(controller.call("observation_line", sleeper)).length() < 20, "resposta curta do floor sleeper")
		check((state.get("day_traces") as Dictionary).size() == 4, "quatro cidadãos deixaram rastros")
		var night_target: Vector3 = controller.call("target_for", sleeper, 5) as Vector3
		check(night_target.z > 0, "floor sleeper separado do grupo")
	var traces: Node = scene.get_node("DayActivityTraces")
	var maya_trace_id: int = traces.get_node("MayaTool").get_instance_id()
	check(traces.has_node("DanteEntryMarker") and traces.has_node("NoahCable"), "rastros físicos presentes")
	check((scene.get("generator_light") as OmniLight3D).light_energy > 4.8, "luz alterada por Maya")
	var indicator: MeshInstance3D = traces.get_node("CommunicationIndicator") as MeshInstance3D
	check((indicator.mesh.material as StandardMaterial3D).emission_enabled, "indicador de Noah ativo")
	var phase_before: int = int(state.get("day_phase"))
	player.position = Vector3(0, 0.9, 5)
	scene.call("_on_dormitory_exited", player)
	await process_frame
	player.position = Vector3(4.65, 0.9, -4.4)
	scene.call("_on_dormitory_entered", player)
	await process_frame
	check(int(state.get("day_phase")) == phase_before and scene.get_instance_id() == original_id, "andar e trocar sala preserva tempo/mapa")
	check(not bool(state.call("advance_time", "walk")) and not bool(state.call("advance_time", "")), "fontes não significativas rejeitadas")
	# UI contextual: longe não observa; perto, um clique avança exatamente uma fase.
	player.position = Vector3(0, 0.9, 6.5)
	check(not bool(controller.call("observe", "iris")), "observar exige proximidade")
	player.position = (actors["iris"] as Node3D).position + Vector3(0, 0, 0.5)
	await process_frame
	var button: Button = scene.get_node("GreyboxUI/ObserveCitizen") as Button
	check(button.visible and not button.disabled, "OBSERVAR disponível por proximidade")
	button.pressed.emit()
	check(int(state.get("day_phase")) == 1, "OBSERVAR avança uma fase")
	if sleeper == "elias":
		check(String(controller.get("response_text")) == "Dormiu alguma coisa?", "UI apresenta resposta de Iris")
		check(is_equal_approx(float(player.get("move_speed")), 4.5), "velocidade restaurada após manhã")
	check(not bool(state.call("advance_time", "observe:iris")) and int(state.get("day_phase")) == 1, "fonte repetida não avança duas fases")
	# Tweens reais: atores normais chegam primeiro, floor sleeper 1.25s depois.
	var motions: Array = controller.get("motions") as Array
	for motion: Tween in motions:
		motion.custom_step(5.05)
	check(int(controller.get("remaining_arrivals")) == (0 if sleeper == "elias" else 1), "diferença temporal de chegada")
	finish_motion(controller)
	check((state.get("day_traces") as Dictionary).size() == 4, "Iris deixa rastro também na variante Elias")
	check(absf((traces.get_node("SupplyLid") as Node3D).rotation_degrees.z) > 60, "caixa ficou aberta")
	for phase: int in range(2, 6):
		var source: String = "object:generator" if phase % 2 == 0 else "object:communication"
		check(bool(controller.call("perform_action", source)), "ação válida avança")
		check(int(state.get("day_phase")) == phase, "avança exatamente uma fase")
		check(not bool(controller.call("perform_action", "object:entrance")), "não pula rotina em trânsito")
		finish_motion(controller)
		check(traces.get_node("MayaTool").get_instance_id() == maya_trace_id, "rastro persiste sem recriar")
	check(bool(state.get("cough_pending")) and not bool(state.get("cough_resolved")), "evento ao chegar à noite")
	player.position = Vector3(0, 0.9, 6.5)
	controller.call("_check_cough_proximity")
	await process_frame
	await process_frame
	check(bool(state.get("cough_pending")), "esperar não decide tosse")
	if sleeper in ["maya", "dante", "elias"]:
		var target: Node3D = controller.get("cough_target") as Node3D
		if sleeper == "elias":
			check(target == actors["iris"], "Elias pode se aproximar de Iris")
		player.position = target.position + Vector3(0.8, 0, 0)
		controller.call("_check_cough_proximity")
		check(bool(state.get("checked_cough")) and bool(state.get("cough_resolved")), "aproximar registra agir")
		state.call("advance_time", "object:supplies")
		check(bool(state.get("checked_cough")), "decisão agir não é sobrescrita")
	else:
		check(bool(controller.call("perform_action", "object:entrance")), "outra ação registra ignorar")
		check(not bool(state.get("checked_cough")) and bool(state.get("cough_resolved")), "ignorar registrado")
		player.position = (controller.get("cough_target") as Node3D).position
		controller.call("_check_cough_proximity")
		check(not bool(state.get("checked_cough")), "ignorar não é sobrescrito")
	check(int(state.get("day_phase")) == 5, "noite nunca cria sétima fase")
	check(scene.get_instance_id() == original_id and player.get_parent() == scene, "mapa e player persistem")
	for room: String in ["EntranceHall", "MainCorridor", "GeneratorRoom", "DormitoryRoom"]:
		check(scene.has_node("Geometry/" + room), "área preservada: " + room)
	scene.queue_free()
	await process_frame
