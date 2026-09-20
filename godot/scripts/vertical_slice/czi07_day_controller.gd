extends Node

# Milestone 0.7: seis blocos discretos; só ações explícitas avançam GameState.
# Reutiliza mapa, atores, joystick e decisão. Sem IA geral ou troca de cena.
const IDS: Array[String] = ["maya", "iris", "dante", "noah"]
const ROUTINES: Dictionary = {
	"maya": ["generator", "communication", "entrance", "generator", "supplies", "rest"],
	"iris": ["supplies", "supplies", "entrance", "communication", "generator", "rest"],
	"dante": ["entrance", "generator", "communication", "supplies", "entrance", "rest"],
	"noah": ["communication", "entrance", "generator", "entrance", "communication", "rest"],
}
const STATIONS: Dictionary = {
	"generator": Vector3(-1.65, 0.90, -7.25),
	"supplies": Vector3(5.45, 0.90, -4.85),
	"entrance": Vector3(-1.0, 0.90, 5.50),
	"communication": Vector3(-1.50, 0.90, -0.40),
	"rest": Vector3(0.0, 0.90, -4.8),
}
const OBJECT_POSITIONS: Dictionary = {
	"generator": Vector3(0.0, 0.65, -8.25),
	"supplies": Vector3(6.35, 0.45, -4.85),
	"entrance": Vector3(-2.15, 0.65, 5.5),
	"communication": Vector3(-2.15, 0.65, -0.4),
}
const LINES: Dictionary = {
	"maya": "O gerador está segurando a carga.",
	"iris": "Separei o que ainda podemos usar.",
	"dante": "Deixei uma marca junto da entrada.",
	"noah": "O contato estava solto. Agora acende.",
}
const SHORT_LINES: Dictionary = {"maya": "Está ligado.", "iris": "Pronto.", "dante": "Tudo quieto.", "noah": "Funciona."}
const ARRIVAL_SECONDS: float = 5.0
const FLOOR_DELAY: float = 1.25

var bunker: Node3D
var dormitory: Node
var player: CharacterBody3D
var actors: Dictionary = {}
var motions: Array[Tween] = []
var remaining_arrivals: int = 0
var active: bool = false
var iris_greeting: bool = false
var normal_speed: float = 4.5
var observe_button: Button
var object_button: Button
var nearby_id: String = ""
var nearby_object: String = ""
var wing: Node3D
var survival_button: Button
var nearby_survival: String = ""
var game_over_panel: Control
var trace_root: Node3D
var supply_lid: MeshInstance3D
var communication_indicator: MeshInstance3D
var cough_target: Node3D
var cough_was_near: bool = false
var response_text: String = ""
var response_origin: Vector3
var response_visible: bool = false

func start(decision: Node) -> void:
	if active or GameState.get_sleep_assignment().is_empty():
		return
	dormitory = decision
	bunker = get_parent() as Node3D
	player = bunker.get("player") as CharacterBody3D
	actors = dormitory.get("group_markers") as Dictionary
	if actors.size() != 4:
		push_error("CZI07DayController: grupo incompleto")
		return
	wing = bunker.get_node("ServiceWing") as Node3D
	normal_speed = float(player.get("move_speed"))
	active = true
	_build_stations()
	_build_ui()
	for id: String in IDS:
		var actor: Node3D = actors[id] as Node3D
		actor.visible = true
		var label := Label3D.new()
		label.text = id.capitalize()
		label.position.y = 1.35
		label.font_size = 32
		label.pixel_size = 0.007
		label.modulate = Color("e9e2d2")
		label.outline_modulate = Color("28382f")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(label)
	GameState.day_phase_changed.connect(_on_phase_changed)
	if not GameState.start_day():
		_on_phase_changed(GameState.day_phase)

func routine_for(id: String, phase: int) -> String:
	if GameState.survival.active:
		if not GameState.survival.alive(id):
			return "dead"
		if GameState.survival.jobs.has(id):
			return String(GameState.survival.jobs[id])
		if GameState.survival.condition(id) == "critical":
			return "recover"
		return {"maya": "generator", "iris": "supplies", "dante": "entrance", "noah": "communication"}[id]
	return String(ROUTINES[id][phase])

func delay_for(id: String) -> float:
	return FLOOR_DELAY if GameState.day == 1 and GameState.get_sleep_assignment() == id else 0.0

func target_for(id: String, phase: int) -> Vector3:
	var task: String = routine_for(id, phase)
	if GameState.survival.active:
		match task:
			"dead": return (actors[id] as Node3D).position
			"pump": return Vector3(3.5, 0.90, 0.65)
			"cook", "empty_pot": return Vector3(6.35, 0.90, 0.85)
			"power_wait": return Vector3(-1.65, 0.90, -7.25)
			"eat", "drink", "empty_table":
				if GameState.survival.areas["services"]:
					return Vector3(5.2 + IDS.find(id) * 0.52, 0.90, 1.4)
				return Vector3(-1.6 + IDS.find(id) * 0.85, 0.90, 4.0)
			"recover": return Vector3(-1.6 + IDS.find(id) * 0.85, 0.90, -5.3)
	var target: Vector3 = STATIONS[task] as Vector3
	if task == "rest":
		# Grupo no corredor, longe das camas e da passagem estreita.
		target = Vector3(-1.6 + IDS.find(id) * 0.95, 0.90, -5.25)
	elif id == "iris" and phase == 1:
		target += Vector3(0, 0, 0.55)
	if GameState.day == 1 and GameState.get_sleep_assignment() == id:
		# Mesmo ambiente, afastado do posto de trabalho e do grupo.
		if task == "rest":
			target = Vector3(-1.65, 0.90, 1.75)
		elif task == "supplies":
			target += Vector3(-1.25, 0, 0.5)
		else:
			target += Vector3(2.8, 0, 0.5)
	return target

func route_between(origin: Vector3, target: Vector3) -> Array[Vector3]:
	if GameState.survival.active:
		return _survival_route(origin, target)
	var route: Array[Vector3] = []
	# Única porta: x=2.8,z=-3.7. O corredor central evita o gerador.
	if origin.x > 2.9:
		route.append(Vector3(4.65, 0.90, origin.z))
		route.append(Vector3(4.65, 0.90, -3.7))
		route.append(Vector3(1.65, 0.90, -3.7))
	else:
		route.append(Vector3(1.65, 0.90, origin.z))
	if target.x > 2.9:
		route.append(Vector3(1.65, 0.90, -3.7))
		route.append(Vector3(4.65, 0.90, -3.7))
		route.append(Vector3(4.65, 0.90, target.z))
	else:
		route.append(Vector3(1.65, 0.90, target.z))
	route.append(target)
	return route

func _on_phase_changed(phase: int) -> void:
	for motion: Tween in motions:
		if motion.is_valid():
			motion.kill()
	motions.clear()
	remaining_arrivals = IDS.size()
	if wing != null:
		# Open collision immediately; stocks update on arrival after the task animation.
		for area: String in ["services", "pantry"]:
			var gate: StaticBody3D = wing.get("gates")[area] as StaticBody3D
			gate.visible = not GameState.survival.areas[area]
			gate.collision_layer = 0 if GameState.survival.areas[area] else 1

	iris_greeting = GameState.day == 1 and phase == 0 and GameState.get_sleep_assignment() == "elias"
	player.set("move_speed", normal_speed * (0.92 if iris_greeting else 1.0))
	for id: String in IDS:
		var actor: Node3D = actors[id] as Node3D
		var visual: Node = actor.get_node_or_null("CitizenVisual")
		if visual != null:
			visual.set("activity", "")
			visual.set("weakened", GameState.survival.active and GameState.survival.condition(id) in ["weak", "critical"])
		if GameState.survival.active and not GameState.survival.alive(id):
			if visual != null:
				visual.set("activity", "dead")
			remaining_arrivals -= 1
			continue
		var target: Vector3 = target_for(id, phase)
		if id == "iris" and iris_greeting:
			# Aproximação antes do trabalho; aguarda uma ação, nunca um cronômetro.
			target = player.position + Vector3(-1.1, 0, 0)
			target.y = 0.90
			if target.x > 2.9:
				target = Vector3(4.65, 0.90, -4.4)
		var route: Array[Vector3] = route_between(actor.position, target)
		var length: float = 0.0
		var previous: Vector3 = actor.position
		for point: Vector3 in route:
			length += previous.distance_to(point)
			previous = point
		var motion := create_tween()
		motions.append(motion)
		if delay_for(id) > 0:
			motion.tween_interval(delay_for(id))
		previous = actor.position
		for point: Vector3 in route:
			var duration: float = ARRIVAL_SECONDS * previous.distance_to(point) / maxf(length, 0.001)
			motion.tween_property(actor, "position", point, maxf(duration, 0.001))
			previous = point
		motion.tween_callback(_arrived.bind(id, phase))
	if remaining_arrivals == 0:
		_settled()
	_refresh_labels()

func _arrived(id: String, phase: int) -> void:
	if phase != GameState.day_phase:
		return
	var task: String = routine_for(id, phase)
	var visual: Node = (actors[id] as Node3D).get_node_or_null("CitizenVisual")
	if visual != null:
		visual.set("activity", "" if iris_greeting and id == "iris" else task)
		var facing: Vector3 = _task_focus(id, task) - (actors[id] as Node3D).position
		if facing.length_squared() > 0.01:
			(visual as Node3D).rotation.y = atan2(facing.x, facing.z)
	if not (id == "iris" and iris_greeting):
		if (id == "maya" and task == "generator") or (id == "iris" and task == "supplies") or (id == "dante" and task == "entrance") or (id == "noah" and task == "communication"):
			_leave_trace(id)
	remaining_arrivals -= 1
	if remaining_arrivals == 0:
		_settled()

func _process(_delta: float) -> void:
	if not active:
		return
	if GameState.survival.game_over:
		_show_game_over()
		return
	nearby_survival = String(wing.call("closest_action", player.position))
	survival_button.visible = not nearby_survival.is_empty()
	survival_button.disabled = remaining_arrivals > 0
	survival_button.text = String(wing.call("action_text", nearby_survival))
	nearby_id = ""
	nearby_object = ""
	var closest: float = 2.15
	for id: String in IDS:
		if GameState.survival.active and not GameState.survival.alive(id):
			continue
		var actor: Node3D = actors[id] as Node3D
		var distance: float = _flat_distance(player.position, actor.position)
		if distance < closest:
			closest = distance
			nearby_id = id
	closest = 2.15
	for id: String in OBJECT_POSITIONS:
		var distance: float = _flat_distance(player.position, OBJECT_POSITIONS[id] as Vector3)
		if distance < closest:
			closest = distance
			nearby_object = id
	observe_button.visible = not nearby_id.is_empty()
	observe_button.disabled = remaining_arrivals > 0
	observe_button.text = "OBSERVAR\n%s" % nearby_id.capitalize()
	object_button.visible = not nearby_object.is_empty() and nearby_survival.is_empty()
	object_button.disabled = remaining_arrivals > 0
	if not nearby_object.is_empty():
		object_button.text = {"generator": "VERIFICAR\nGERADOR", "supplies": "EXAMINAR\nSUPRIMENTOS", "entrance": "CONFERIR\nENTRADA", "communication": "TESTAR\nCONTATO"}[nearby_object]
	if response_visible and _flat_distance(player.position, response_origin) > 2.5:
		response_visible = false
	_check_cough_proximity()
	_refresh_labels()

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func observation_line(id: String) -> String:
	if GameState.survival.active:
		if GameState.survival.condition(id) == "critical":
			return "Não consigo continuar assim."
		if GameState.survival.condition(id) == "weak":
			return "Preciso beber e comer alguma coisa."
		var task: String = routine_for(id, GameState.day_phase)
		return {"pump": "Estou enchendo o reservatório.", "cook": "Já vai sair comida.", "empty_pot": "Falta água, alimento ou energia.", "power_wait": "A bomba ficou sem energia.", "eat": "Ainda bem que tem uma porção.", "drink": "Pelo menos temos água.", "empty_table": "Não sobrou nada."}.get(task, "Vou cuidar desta parte.")
	if id == "iris" and iris_greeting:
		return "Dormiu alguma coisa?"
	if id == GameState.get_sleep_assignment():
		return String(SHORT_LINES[id])
	return String(LINES[id])

func observe(id: String) -> bool:
	if not actors.has(id) or remaining_arrivals > 0:
		return false
	var actor: Node3D = actors[id] as Node3D
	if _flat_distance(player.position, actor.position) > 2.15:
		return false
	var line: String = observation_line(id)
	var accepted: bool = perform_action("observe:" + id)
	if accepted:
		response_text = line
		response_origin = player.position
		response_visible = true
	return accepted

func interact_object(id: String) -> bool:
	if not OBJECT_POSITIONS.has(id) or _flat_distance(player.position, OBJECT_POSITIONS[id] as Vector3) > 2.15:
		return false
	return perform_action("object:" + id)

func perform_action(source_id: String) -> bool:
	if not active or remaining_arrivals > 0 or source_id == GameState.last_time_source or not GameState.is_significant_source(source_id):
		return false
	# A aproximação vence se o jogador já entrou no raio neste frame.
	_check_cough_proximity()
	var pending: bool = GameState.cough_pending
	response_visible = false
	var advanced: bool = GameState.advance_time(source_id)
	return advanced or (pending and GameState.cough_resolved)

func _build_ui() -> void:
	var layer: CanvasLayer = bunker.get_node("GreyboxUI") as CanvasLayer
	survival_button = _action_button(layer, "SurvivalAction", -330, -250)
	survival_button.pressed.connect(_survival_pressed)
	observe_button = _action_button(layer, "ObserveCitizen", -230, -150)
	observe_button.pressed.connect(func() -> void: observe(nearby_id))
	object_button = _action_button(layer, "InspectDayObject", -330, -250)
	object_button.pressed.connect(func() -> void: interact_object(nearby_object))

func _action_button(layer: CanvasLayer, name_: String, top: float, bottom: float) -> Button:
	var button := Button.new()
	button.name = name_
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -245
	button.offset_right = -25
	button.offset_top = top
	button.offset_bottom = bottom
	button.add_theme_font_size_override("font_size", 20)
	button.visible = false
	layer.add_child(button)
	return button

func _refresh_labels() -> void:
	var objective: Label = bunker.get("objective_label") as Label
	var status: Label = bunker.get("status_label") as Label
	objective.text = "CZI-07 — DIA %d // %s" % [GameState.day, GameState.DAY_PHASES[GameState.day_phase]]
	if response_visible:
		status.text = response_text
	elif GameState.survival.active:
		status.text = "Volte ao dormitório para descansar." if GameState.day_phase == 5 else GameState.survival.status_text()
	elif GameState.cough_pending:
		status.text = "Elias leva a mão à boca. Iris ergue os olhos." if GameState.get_sleep_assignment() == "elias" else "%s leva a mão à boca." % GameState.get_sleep_assignment().capitalize()
	elif GameState.cough_resolved:
		status.text = "Volte ao dormitório. DESCANSAR inicia o próximo dia."
	else:
		status.text = "Observe alguém ou examine um posto de trabalho."

func _visual(name_: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = name_
	item.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh.material = material
	item.mesh = mesh
	trace_root.add_child(item)
	return item

func _build_stations() -> void:
	trace_root = Node3D.new()
	trace_root.name = "DayActivityTraces"
	bunker.add_child(trace_root)
	# A caixa fechada existe antes de Iris trabalhar; a tampa continua aberta depois.
	_visual("SupplyBox", Vector3(0.7, 0.55, 0.65), Vector3(6.35, 0.28, -4.85), Color("677266"))
	supply_lid = _visual("SupplyLid", Vector3(0.74, 0.08, 0.69), Vector3(6.35, 0.59, -4.85), Color("afb6a0"))
	_visual("CommunicationUnit", Vector3(0.5, 0.8, 0.6), Vector3(-2.15, 0.40, -0.4), Color("747c80"))
	communication_indicator = _visual("CommunicationIndicator", Vector3(0.07, 0.12, 0.34), Vector3(-1.88, 0.66, -0.4), Color("292d29"))
	_visual("EntrancePanel", Vector3(0.3, 0.85, 0.65), Vector3(-2.15, 0.44, 5.5), Color("767a72"))
	for id: String in GameState.day_traces.keys():
		_render_trace(id)

func _leave_trace(id: String) -> void:
	if GameState.day_traces.has(id):
		return
	GameState.day_traces[id] = true
	_render_trace(id)

func _render_trace(id: String) -> void:
	match id:
		"maya":
			_visual("MayaTool", Vector3(0.75, 0.08, 0.12), Vector3(0.45, 1.55, -8.10), Color("edb54d"))
			_visual("MayaToolHead", Vector3(0.16, 0.08, 0.3), Vector3(0.1, 1.55, -8.10), Color("d8d7c6"))
			var light: OmniLight3D = bunker.get("generator_light") as OmniLight3D
			light.light_color = Color("e5dfc7")
			light.light_energy = 5.3
		"iris":
			supply_lid.rotation_degrees.z = -65
			supply_lid.position = Vector3(6.62, 0.85, -4.85)
			_visual("IrisBandages", Vector3(0.42, 0.18, 0.38), Vector3(6.25, 0.65, -4.85), Color("f0e8cd"))
		"dante":
			_visual("DanteEntryMarker", Vector3(0.8, 0.06, 0.18), Vector3(-1.8, 0.06, 6.65), Color("e3b565"))
			_visual("DanteEntryMarkerCross", Vector3(0.18, 0.06, 0.65), Vector3(-1.8, 0.065, 6.65), Color("e3b565"))
		"noah":
			_visual("NoahCable", Vector3(0.08, 0.06, 1.35), Vector3(-1.9, 0.055, -0.3), Color("da9a3d"))
			var material: StandardMaterial3D = communication_indicator.mesh.material as StandardMaterial3D
			material.albedo_color = Color("80d8ac")
			material.emission_enabled = true
			material.emission = Color("80d8ac")
			material.emission_energy_multiplier = 2.0

func _begin_night_event() -> void:
	GameState.begin_cough()
	if not GameState.cough_pending:
		return
	var sleeper: String = GameState.get_sleep_assignment()
	var coughing: Node3D = player if sleeper == "elias" else actors[sleeper] as Node3D
	cough_target = actors["iris"] as Node3D if sleeper == "elias" else coughing
	cough_was_near = _flat_distance(player.position, cough_target.position) <= 1.7
	# Um gesto breve de desconforto. Sem penalidade, diagnóstico ou relógio de decisão.
	var gesture := create_tween()
	gesture.tween_property(coughing, "rotation:x", 0.16, 0.18)
	gesture.tween_property(coughing, "rotation:x", 0.0, 0.25)
	gesture.tween_property(coughing, "rotation:x", 0.12, 0.16)
	gesture.tween_property(coughing, "rotation:x", 0.0, 0.30)

func _check_cough_proximity() -> void:
	if not GameState.cough_pending or cough_target == null:
		return
	var near: bool = _flat_distance(player.position, cough_target.position) <= 1.7
	if near and not cough_was_near:
		GameState.resolve_cough(true)
	cough_was_near = near

func _survival_route(origin: Vector3, target: Vector3) -> Array[Vector3]:
	var route: Array[Vector3] = []
	# Dormitory door z=-3.7, service door z=1.2; both join x=1.65 corridor.
	if origin.x > 2.9 and origin.z < -1.3:
		route.append(Vector3(4.65, 0.9, origin.z))
		route.append(Vector3(4.65, 0.9, -3.7))
		route.append(Vector3(1.65, 0.9, -3.7))
	elif origin.x > 2.9:
		route.append(Vector3(origin.x, 0.9, 1.2))
		route.append(Vector3(1.65, 0.9, 1.2))
	else:
		route.append(Vector3(1.65, 0.9, origin.z))
	if target.x > 2.9 and target.z < -1.3:
		route.append(Vector3(1.65, 0.9, -3.7))
		route.append(Vector3(4.65, 0.9, -3.7))
		route.append(Vector3(4.65, 0.9, target.z))
	elif target.x > 2.9:
		route.append(Vector3(1.65, 0.9, 1.2))
		route.append(Vector3(target.x, 0.9, 1.2))
	else:
		route.append(Vector3(1.65, 0.9, target.z))
	route.append(target)
	return route

func _task_focus(id: String, task: String) -> Vector3:
	match task:
		"pump": return Vector3(3.35, 0.9, -0.25)
		"cook", "empty_pot": return Vector3(6.35, 0.9, -0.25)
		"eat", "drink", "empty_table": return Vector3(6, 0.9, 2.3)
		"generator", "power_wait": return OBJECT_POSITIONS["generator"] as Vector3
		"supplies": return OBJECT_POSITIONS["supplies"] as Vector3
		"communication": return OBJECT_POSITIONS["communication"] as Vector3
		"entrance": return OBJECT_POSITIONS["entrance"] as Vector3
	return (actors[id] as Node3D).position + Vector3(0, 0, 1)

func _settled() -> void:
	if GameState.day == 1 and GameState.day_phase == 5:
		_begin_night_event()
	if not GameState.survival.active:
		return
	wing.call("sync_state")
	var cooking: bool = GameState.survival.jobs.values().has("cook")
	(wing.get("steam") as Node3D).visible = cooking
	var elias_visual: Node = player.get_node_or_null("CitizenVisual")
	if elias_visual != null:
		elias_visual.set("activity", String(GameState.survival.jobs.get("elias", "")))
		elias_visual.set("weakened", GameState.survival.condition("elias") in ["weak", "critical"])
	if GameState.survival.game_over:
		_show_game_over()

func _survival_pressed() -> void:
	var enter_base: bool = nearby_survival == "rest" and GameState.day == 1 and GameState.cough_resolved
	if not use_survival_action(nearby_survival) or not enter_base:
		return
	# After the preserved first day, continue in this same physical bunker.
	for motion: Tween in motions:
		if motion.is_valid():
			motion.kill()
	active = false
	set_process(false)
	GameState.base_mode = true
	GameState.base_core = GameState.BaseCoreState.new(GameState.survival)
	GameState.base_core.initialize_resources()
	GameState.base_core.power.running = true
	var core := Node3D.new()
	core.name = "BaseCore"
	core.set_script(load("res://scripts/base/base_controller.gd"))
	bunker.add_child(core)

func use_survival_action(source: String) -> bool:
	if remaining_arrivals > 0 or source.is_empty() or GameState.survival.game_over:
		return false
	if String(wing.call("closest_action", player.position)) != source:
		return false
	if source == "rest":
		response_visible = false
		return GameState.sleep_to_next_day()
	if GameState.day_phase == 5:
		response_text = "Por hoje, descanse. Amanhã continuamos."
		response_origin = player.position
		response_visible = true
		return false
	if source.begins_with("area:"):
		var reason: String = GameState.survival.unlock_reason(source.trim_prefix("area:"))
		if not reason.is_empty():
			response_text = reason
			response_origin = player.position
			response_visible = true
			return false
	var accepted: bool = perform_action(source)
	if accepted and source == "object:power":
		var energy: bool = GameState.survival.powered
		(bunker.get("generator_light") as OmniLight3D).light_energy = 5.3 if energy else 0.2
		(bunker.get("corridor_light") as OmniLight3D).light_energy = 4.0 if energy else 1.1
		(bunker.get("entry_light") as OmniLight3D).light_energy = 3.6 if energy else 0.7
		bunker.set("_drone_target_gain", 0.14 if energy else 0.0)
	return accepted

func _show_game_over() -> void:
	player.call("set_input_enabled", false)
	(bunker.get("virtual_stick") as Control).visible = false
	observe_button.visible = false
	object_button.visible = false
	survival_button.visible = false
	if game_over_panel != null:
		return
	game_over_panel = ColorRect.new()
	(game_over_panel as ColorRect).color = Color(0.04, 0.06, 0.05, 0.96)
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(bunker.get_node("GreyboxUI") as CanvasLayer).add_child(game_over_panel)
	var column := VBoxContainer.new()
	column.position = Vector2(55, 420)
	column.size = Vector2(610, 280)
	column.add_theme_constant_override("separation", 24)
	game_over_panel.add_child(column)
	var title := Label.new()
	title.text = "O BUNKER FICOU EM SILÊNCIO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var detail := Label.new()
	detail.text = "Elias não resistiu à falta de %s." % GameState.survival.people["elias"]["cause"]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	var restart := Button.new()
	restart.text = "RECOMEÇAR"
	restart.custom_minimum_size.y = 72
	restart.pressed.connect(func() -> void:
		GameState.reset_new_game()
		get_tree().change_scene_to_file("res://scenes/vertical_slice/scene_01_greybox.tscn")
	)
	column.add_child(restart)
