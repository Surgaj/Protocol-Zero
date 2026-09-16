extends Node3D

# PROTOCOL ZERO — Milestone 0.6 / A Jornada.
# Uma única faixa externa, três batidas curtas, zero mecânica nova.
# Promessa: o jogador vê Iris, Dante e Noah entrarem no grupo antes do CZI-07.

const ENCOUNTER_ORDER: Array[String] = ["iris", "dante", "noah"]

var player: CharacterBody3D
var gameplay_camera: Camera3D
var virtual_stick: Control
var objective_label: Label
var status_label: Label
var encounter_panel: ColorRect
var encounter_title: Label
var encounter_text: Label
var follow_button: Button

var party_markers: Dictionary = {}
var joined_members: Dictionary = {"maya": true}
var current_beat: int = 0
var current_encounter_id: String = ""
var encounter_open: bool = false

func _ready() -> void:
	GameState.ensure_new_run()
	if not GameState.is_party_member("maya"):
		GameState.add_party_member("maya")
	_build_environment()
	_build_route()
	player = _build_player()
	_build_party_and_encounters()
	gameplay_camera = _build_camera(player)
	player.call("set_movement_camera", gameplay_camera)
	_build_ui()
	_build_encounter_triggers()
	_build_exit_trigger()

func _process(delta: float) -> void:
	_update_followers(delta)

func _make_material(color: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_static_box(name_: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.position = pos
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _make_material(color)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("171717")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8c5bd")
	environment.ambient_light_energy = 0.48
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)

func _build_route() -> void:
	# Uma única faixa física: posto de Iris -> bloqueio de Dante -> estação de Noah -> CZI-07.
	_add_static_box("Road", Vector3(8.0, 0.30, 34.0), Vector3(0, -0.15, 0), Color("676767"))
	_add_static_box("LeftBoundary", Vector3(0.30, 1.1, 34.0), Vector3(-3.85, 0.55, 0), Color("505050"))
	_add_static_box("RightBoundary", Vector3(0.30, 0.55, 34.0), Vector3(3.85, 0.275, 0), Color("484848"))

	# Batida 1: posto médico improvisado.
	_add_static_box("ClinicTable", Vector3(2.0, 0.75, 0.85), Vector3(-1.75, 0.375, 7.4), Color("6a6258"))
	_add_static_box("ClinicCrate", Vector3(0.75, 0.75, 0.75), Vector3(-2.65, 0.375, 8.3), Color("5b584f"))
	_add_static_box("ClinicTarpPost", Vector3(0.18, 2.2, 0.18), Vector3(-3.0, 1.1, 6.65), Color("595959"))

	# Batida 2: rota direta bloqueada, mas a faixa lateral continua transitável.
	_add_static_box("CollapsedBarrierA", Vector3(3.8, 0.75, 0.65), Vector3(-0.9, 0.375, 0.8), Color("555555"))
	_add_static_box("CollapsedBarrierB", Vector3(1.2, 1.15, 0.85), Vector3(-2.2, 0.575, -0.05), Color("5c5651"))
	_add_static_box("RouteMarker", Vector3(0.22, 1.7, 0.22), Vector3(2.65, 0.85, 0.2), Color("7b6345"))

	# Batida 3: estação de comunicação pequena.
	_add_static_box("NoahConsole", Vector3(1.5, 1.05, 0.75), Vector3(1.7, 0.525, -6.7), Color("565c60"))
	_add_static_box("NoahAntenna", Vector3(0.18, 2.8, 0.18), Vector3(2.45, 1.4, -7.2), Color("696969"))
	_add_static_box("NoahReceiver", Vector3(0.55, 0.45, 0.45), Vector3(1.7, 1.25, -6.7), Color("73766f"))

	# Silhueta/placa no fim da rota: o CZI-07 ainda é a Cena 3 externa.
	_add_static_box("CZIWayfinder", Vector3(2.5, 1.4, 0.32), Vector3(0, 0.70, -15.2), Color("55595b"))

func _build_player() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Elias_GreyCapsule"
	body.position = Vector3(0.55, 0.90, 14.2)
	body.set_script(load("res://scripts/vertical_slice/player_capsule.gd"))
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.80
	mesh.material = _make_material(Color("c7c7c7"))
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.80
	collision.shape = capsule
	body.add_child(collision)
	return body

func _build_party_and_encounters() -> void:
	var starts: Dictionary = {
		"maya": Vector3(-0.8, 0.90, 13.0),
		"iris": Vector3(-1.45, 0.90, 7.15),
		"dante": Vector3(1.65, 0.90, 0.35),
		"noah": Vector3(1.35, 0.90, -6.05),
	}
	for citizen_id: String in ["maya", "iris", "dante", "noah"]:
		var marker := Node3D.new()
		marker.name = "%s_JourneyMarker" % citizen_id.capitalize()
		marker.position = starts[citizen_id] as Vector3
		add_child(marker)
		var mesh_instance := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.29
		capsule.height = 1.70
		capsule.material = _make_material(_citizen_color(citizen_id), 0.88)
		mesh_instance.mesh = capsule
		marker.add_child(mesh_instance)
		party_markers[citizen_id] = marker

func _build_camera(target_player: CharacterBody3D) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "GreyboxCamera"
	camera.set_script(load("res://scripts/vertical_slice/camera_follow.gd"))
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 9.4
	var offset := Vector3(8.5, 6.0, 10.0)
	camera.set("camera_offset", offset)
	camera.set("follow_min", Vector2(-0.70, -13.5))
	camera.set("follow_max", Vector2(0.70, 12.8))
	camera.global_position = target_player.global_position + offset
	camera.look_at(target_player.global_position + Vector3(0, 0.78, 0), Vector3.UP)
	camera.current = true
	camera.call("set_target", target_player)
	return camera

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GreyboxUI"
	add_child(layer)

	var panel := ColorRect.new()
	panel.name = "StatusPanel"
	panel.position = Vector2(24, 22)
	panel.size = Vector2(620, 104)
	panel.color = Color(0.04, 0.04, 0.04, 0.86)
	layer.add_child(panel)

	objective_label = Label.new()
	objective_label.name = "Objective"
	objective_label.position = Vector2(20, 12)
	objective_label.text = "A JORNADA — ROTA PARA CZI-07"
	objective_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.position = Vector2(20, 44)
	status_label.text = "OBJETIVO: siga a rota com Maya."
	status_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(status_label)

	virtual_stick = Control.new()
	virtual_stick.name = "VirtualStick"
	virtual_stick.set_script(load("res://scripts/vertical_slice/virtual_stick.gd"))
	virtual_stick.anchor_top = 1.0
	virtual_stick.anchor_bottom = 1.0
	virtual_stick.offset_left = 30.0
	virtual_stick.offset_top = -218.0
	virtual_stick.offset_right = 218.0
	virtual_stick.offset_bottom = -30.0
	layer.add_child(virtual_stick)

	encounter_panel = ColorRect.new()
	encounter_panel.name = "JourneyEncounter"
	encounter_panel.anchor_left = 0.07
	encounter_panel.anchor_top = 0.18
	encounter_panel.anchor_right = 0.93
	encounter_panel.anchor_bottom = 0.75
	encounter_panel.color = Color(0.025, 0.025, 0.025, 0.97)
	encounter_panel.visible = false
	layer.add_child(encounter_panel)

	var column := VBoxContainer.new()
	column.anchor_right = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = 26.0
	column.offset_top = 24.0
	column.offset_right = -26.0
	column.offset_bottom = -24.0
	column.add_theme_constant_override("separation", 14)
	encounter_panel.add_child(column)

	encounter_title = Label.new()
	encounter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	encounter_title.add_theme_font_size_override("font_size", 22)
	column.add_child(encounter_title)

	encounter_text = Label.new()
	encounter_text.custom_minimum_size = Vector2(0, 230)
	encounter_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encounter_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	encounter_text.add_theme_font_size_override("font_size", 17)
	column.add_child(encounter_text)

	follow_button = Button.new()
	follow_button.name = "FollowButton"
	follow_button.text = "SEGUIR"
	follow_button.custom_minimum_size = Vector2(0, 66)
	follow_button.add_theme_font_size_override("font_size", 20)
	follow_button.pressed.connect(_on_follow_pressed)
	column.add_child(follow_button)

func _build_encounter_triggers() -> void:
	var trigger_positions: Dictionary = {
		"iris": Vector3(0, 1.0, 8.0),
		"dante": Vector3(0, 1.0, 1.1),
		"noah": Vector3(0, 1.0, -6.2),
	}
	for citizen_id: String in ENCOUNTER_ORDER:
		var area := Area3D.new()
		area.name = "%sEncounterTrigger" % citizen_id.capitalize()
		area.position = trigger_positions[citizen_id] as Vector3
		add_child(area)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.8, 2.2, 2.8)
		collision.shape = shape
		area.add_child(collision)
		area.body_entered.connect(_on_encounter_entered.bind(citizen_id))

func _build_exit_trigger() -> void:
	var area := Area3D.new()
	area.name = "JourneyExit"
	area.position = Vector3(0, 1.0, -14.2)
	add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.8, 2.2, 1.2)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_exit_entered)

func _on_encounter_entered(body: Node3D, citizen_id: String) -> void:
	if body.name != "Elias_GreyCapsule" or encounter_open:
		return
	if current_beat >= ENCOUNTER_ORDER.size() or ENCOUNTER_ORDER[current_beat] != citizen_id:
		return
	_open_encounter(citizen_id)

func _open_encounter(citizen_id: String) -> void:
	current_encounter_id = citizen_id
	encounter_open = true
	player.call("set_input_enabled", false)
	virtual_stick.visible = false
	var copy: Dictionary = _encounter_copy(citizen_id)
	encounter_title.text = String(copy["title"])
	encounter_text.text = String(copy["text"])
	encounter_panel.visible = true

func _on_follow_pressed() -> void:
	if not encounter_open or current_encounter_id.is_empty():
		return
	_join_citizen(current_encounter_id)
	encounter_open = false
	current_encounter_id = ""
	encounter_panel.visible = false
	virtual_stick.visible = true
	player.call("set_input_enabled", true)
	_update_objective_after_join()

func _join_citizen(citizen_id: String) -> void:
	joined_members[citizen_id] = true
	GameState.add_party_member(citizen_id)
	if current_beat < ENCOUNTER_ORDER.size() and ENCOUNTER_ORDER[current_beat] == citizen_id:
		current_beat += 1

func _update_followers(delta: float) -> void:
	if player == null:
		return
	var maya_behavior: Dictionary = GameState.get_maya_behavior()
	var maya_distance: float = float(maya_behavior["follow_distance"])
	var offsets: Dictionary = {
		"maya": Vector3(-1.05, 0.0, maya_distance),
		"iris": Vector3(1.15, 0.0, 1.85),
		"dante": Vector3(-1.55, 0.0, 3.05),
		"noah": Vector3(1.55, 0.0, 3.15),
	}
	for citizen_id: String in party_markers.keys():
		if not joined_members.has(citizen_id):
			continue
		var marker: Node3D = party_markers[citizen_id] as Node3D
		var offset: Vector3 = offsets[citizen_id] as Vector3
		var target: Vector3 = player.global_position + offset
		target.y = 0.90
		marker.global_position = marker.global_position.move_toward(target, delta * 2.7)

func _update_objective_after_join() -> void:
	match current_beat:
		1:
			status_label.text = "IRIS ENTROU NO GRUPO // continue pela rota."
		2:
			status_label.text = "DANTE ENTROU NO GRUPO // siga para a estação."
		3:
			status_label.text = "GRUPO: 5 PESSOAS // alcance o CZI-07."

func _encounter_copy(citizen_id: String) -> Dictionary:
	match citizen_id:
		"iris":
			return {
				"title": "IRIS — MÉDICA",
				"text": "Um posto médico improvisado. Os suprimentos estão no fim.\n\nIRIS: Aqui eu só estou adiando o inevitável.\n\nElias menciona o CZI-07: energia de emergência e espaço para uma enfermaria.",
			}
		"dante":
			return {
				"title": "DANTE — BATEDOR",
				"text": "Uma barricada fecha a rota direta. Dante vinha observando o grupo.\n\nDANTE: Por aqui vocês não passam. Eu conheço uma rota segura.\n\nO destino interessa a ele. O conhecimento da região interessa ao grupo.",
			}
		"noah":
			return {
				"title": "NOAH — OPERADOR",
				"text": "Uma estação de comunicação ainda recebe um padrão impossível.\n\nBLACK SIGNAL\nNÃO RESPONDAM AO OUTRO SINAL.\n\nNoah tenta entender isso há semanas. O CZI-07 tem equipamento melhor.",
			}
	return {"title": "", "text": ""}

func _citizen_color(citizen_id: String) -> Color:
	match citizen_id:
		"maya":
			return Color("e8a33d")
		"iris":
			return Color("c79e76")
		"dante":
			return Color("b5502a")
		"noah":
			return Color("8d8a62")
		_:
			return Color("aaaaaa")

func _on_exit_entered(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	if current_beat < ENCOUNTER_ORDER.size():
		status_label.text = "A JORNADA AINDA NÃO TERMINOU."
		return
	get_tree().change_scene_to_file("res://scenes/vertical_slice/scene_03_czi_approach.tscn")

func apply_encounter_for_test(citizen_id: String) -> void:
	if current_beat >= ENCOUNTER_ORDER.size() or ENCOUNTER_ORDER[current_beat] != citizen_id:
		return
	_join_citizen(citizen_id)

func get_joined_count() -> int:
	return joined_members.size()
