extends Node

# PROTOCOL ZERO — Milestone 0.5 / Quatro Camas.
# Vive DENTRO do CZI-07 persistente: sem troca de cena.
# Só dispara quando a Jornada realmente formou o grupo de cinco.
# Passo de comunicação: instrução concreta + âncora visual no espaço improvisado.

var root_scene: Node3D
var dormitory_room: Node3D
var player: CharacterBody3D
var virtual_stick: Control
var objective_label: Label
var status_label: Label
var choice_panel: ColorRect
var floor_mat_visual: MeshInstance3D

var group_markers: Dictionary = {}
var group_revealed: bool = false
var decision_started: bool = false
var decision_resolved: bool = false
var _pulse_time: float = 0.0

const CITIZEN_ORDER: Array[String] = ["elias", "maya", "iris", "dante", "noah"]
const BED_POSITIONS: Array[Vector3] = [
	Vector3(3.55, 0.14, -2.75),
	Vector3(5.75, 0.14, -2.75),
	Vector3(3.55, 0.14, -6.65),
	Vector3(5.75, 0.14, -6.65),
]
const FLOOR_POSITION: Vector3 = Vector3(4.65, 0.05, -4.72)

func _ready() -> void:
	call_deferred("_late_ready")

func _late_ready() -> void:
	await get_tree().process_frame
	root_scene = get_parent() as Node3D
	if root_scene == null:
		push_error("DormitoryDecision: CZI07Base ausente")
		return

	dormitory_room = root_scene.get_node_or_null("Geometry/DormitoryRoom") as Node3D
	player = root_scene.get_node_or_null("Elias_GreyCapsule") as CharacterBody3D
	virtual_stick = root_scene.get_node_or_null("GreyboxUI/VirtualStick") as Control
	objective_label = root_scene.get_node_or_null("GreyboxUI/Panel/Objective") as Label
	status_label = root_scene.get_node_or_null("GreyboxUI/Panel/Status") as Label

	# Compatibilidade com a UI procedural atual, em que os labels não tinham nome explícito.
	if objective_label == null:
		objective_label = root_scene.get("objective_label") as Label
	if status_label == null:
		status_label = root_scene.get("status_label") as Label

	if dormitory_room == null or player == null:
		push_error("DormitoryDecision: dormitório/player ausente")
		return

	_build_beds()
	_build_group_markers()
	_build_choice_ui()
	set_process(true)

func _process(delta: float) -> void:
	_pulse_time += delta
	if floor_mat_visual != null:
		if decision_started and not decision_resolved:
			var pulse: float = 1.0 + (sin(_pulse_time * 4.0) + 1.0) * 0.045
			floor_mat_visual.scale = Vector3(pulse, 1.0, pulse)
		else:
			floor_mat_visual.scale = Vector3.ONE

	if root_scene == null or decision_resolved:
		return
	var power_complete: bool = bool(root_scene.get("power_complete"))
	var party_complete: bool = GameState.get_party_members().size() >= 5
	if not party_complete:
		return
	if power_complete and not group_revealed:
		_reveal_group_at_entry()
	if power_complete and String(root_scene.get("current_zone")) == "dormitory":
		if status_label != null and not decision_started:
			status_label.text = "DORMITÓRIO // 4 CAMAS // 5 PESSOAS // 1 VAI PARA O CHÃO"
		if not decision_started:
			decision_started = true
			_begin_decision()

func _make_material(color: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_static_box(name_: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.position = pos
	dormitory_room.add_child(body)

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

func _add_visual_box(parent: Node3D, name_: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name_
	mesh_instance.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _make_material(color)
	mesh_instance.mesh = mesh
	parent.add_child(mesh_instance)
	return mesh_instance

func _build_beds() -> void:
	var frame_color := Color("6f716d")
	var mattress_color := Color("aaa696")
	for i: int in range(BED_POSITIONS.size()):
		var bed_pos: Vector3 = BED_POSITIONS[i]
		_add_static_box("Bed%02d" % (i + 1), Vector3(1.45, 0.28, 0.78), bed_pos, frame_color)
		_add_visual_box(dormitory_room, "Mattress%02d" % (i + 1), Vector3(1.28, 0.10, 0.66), bed_pos + Vector3(0, 0.19, 0), mattress_color)

	floor_mat_visual = _add_visual_box(dormitory_room, "ImprovisedFloorMat", Vector3(1.55, 0.05, 0.82), FLOOR_POSITION, Color("8a5e3b"))

func _build_group_markers() -> void:
	var start_positions: Dictionary = {
		"maya": Vector3(-1.25, 0.90, 5.15),
		"iris": Vector3(-0.42, 0.90, 5.55),
		"dante": Vector3(0.45, 0.90, 5.55),
		"noah": Vector3(1.28, 0.90, 5.15),
	}
	for citizen_id: String in ["maya", "iris", "dante", "noah"]:
		if not GameState.is_party_member(citizen_id):
			continue
		var marker := Node3D.new()
		marker.name = "%s_SocialMarker" % citizen_id.capitalize()
		marker.position = start_positions[citizen_id] as Vector3
		marker.visible = false
		root_scene.add_child(marker)

		var mesh_instance := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.68
		capsule.material = _make_material(_citizen_color(citizen_id), 0.88)
		mesh_instance.mesh = capsule
		marker.add_child(mesh_instance)
		group_markers[citizen_id] = marker

func _build_choice_ui() -> void:
	var layer: CanvasLayer = root_scene.get_node_or_null("GreyboxUI") as CanvasLayer
	if layer == null:
		push_error("DormitoryDecision: GreyboxUI ausente")
		return

	choice_panel = ColorRect.new()
	choice_panel.name = "FourBedsChoice"
	choice_panel.anchor_left = 0.08
	choice_panel.anchor_top = 0.12
	choice_panel.anchor_right = 0.92
	choice_panel.anchor_bottom = 0.88
	choice_panel.color = Color(0.035, 0.035, 0.035, 0.96)
	choice_panel.visible = false
	layer.add_child(choice_panel)

	var column := VBoxContainer.new()
	column.anchor_right = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = 22.0
	column.offset_top = 20.0
	column.offset_right = -22.0
	column.offset_bottom = -20.0
	column.add_theme_constant_override("separation", 8)
	choice_panel.add_child(column)

	var title := Label.new()
	title.text = "4 CAMAS. 5 PESSOAS."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)

	var question := Label.new()
	question.text = "Uma pessoa terá de dormir no chão."
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.add_theme_font_size_override("font_size", 17)
	column.add_child(question)

	var instruction := Label.new()
	instruction.name = "ChoiceInstruction"
	instruction.text = "Toque no NOME de quem ficará no espaço improvisado."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.custom_minimum_size = Vector2(0, 48)
	instruction.add_theme_font_size_override("font_size", 15)
	column.add_child(instruction)

	for citizen_id: String in CITIZEN_ORDER:
		var button := Button.new()
		button.name = "Choice_%s" % citizen_id.capitalize()
		button.text = "%s DORME NO CHÃO" % citizen_id.to_upper()
		button.custom_minimum_size = Vector2(0, 50)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_resolve_sleep_choice.bind(citizen_id))
		column.add_child(button)

func _reveal_group_at_entry() -> void:
	group_revealed = true
	for citizen_id: String in group_markers.keys():
		var marker: Node3D = group_markers[citizen_id] as Node3D
		marker.visible = true

func _begin_decision() -> void:
	_move_group_into_dormitory()
	if status_label != null:
		status_label.text = "4 CAMAS // 5 PESSOAS // ESCOLHA QUEM DORME NO CHÃO"
	await get_tree().create_timer(1.55).timeout
	if decision_resolved:
		return
	if String(root_scene.get("current_zone")) != "dormitory":
		decision_started = false
		return
	player.call("set_input_enabled", false)
	if virtual_stick != null:
		virtual_stick.visible = false
	if objective_label != null:
		objective_label.text = "CENA 5 — QUATRO CAMAS"
	choice_panel.visible = true

func _move_group_into_dormitory() -> void:
	var waiting_positions: Dictionary = {
		"maya": Vector3(3.45, 0.90, -3.45),
		"iris": Vector3(5.70, 0.90, -3.45),
		"dante": Vector3(3.45, 0.90, -5.95),
		"noah": Vector3(5.70, 0.90, -5.95),
	}
	var tween := create_tween()
	tween.set_parallel(true)
	for citizen_id: String in group_markers.keys():
		var marker: Node3D = group_markers[citizen_id] as Node3D
		marker.visible = true
		var target: Vector3 = waiting_positions[citizen_id] as Vector3
		tween.tween_property(marker, "position", target, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _resolve_sleep_choice(citizen_id: String) -> void:
	if decision_resolved or not CITIZEN_ORDER.has(citizen_id):
		return
	decision_resolved = true
	choice_panel.visible = false
	GameState.record_sleep_assignment(citizen_id)
	_apply_assignment_visuals(citizen_id)
	player.call("set_input_enabled", true)
	if virtual_stick != null:
		virtual_stick.visible = true
	if objective_label != null:
		objective_label.text = "CZI-07 — DORMITÓRIO"
	if status_label != null:
		status_label.text = "%s DORMIRÁ NO CHÃO // DECISÃO REGISTRADA" % citizen_id.to_upper()

func _apply_assignment_visuals(floor_id: String) -> void:
	var previous: Node = dormitory_room.get_node_or_null("SleepAssignmentVisuals")
	if previous != null:
		previous.queue_free()

	var visuals := Node3D.new()
	visuals.name = "SleepAssignmentVisuals"
	dormitory_room.add_child(visuals)

	var bed_occupants: Array[String] = []
	for citizen_id: String in CITIZEN_ORDER:
		if citizen_id != floor_id:
			bed_occupants.append(citizen_id)

	for i: int in range(mini(4, bed_occupants.size())):
		var occupant: String = bed_occupants[i]
		_add_visual_box(visuals, "Bed_%s" % occupant, Vector3(1.10, 0.07, 0.54), BED_POSITIONS[i] + Vector3(0, 0.33, 0), _citizen_color(occupant))

	_add_visual_box(visuals, "Floor_%s" % floor_id, Vector3(1.24, 0.07, 0.58), FLOOR_POSITION + Vector3(0, 0.07, 0), _citizen_color(floor_id))
	_move_npcs_to_assignments(floor_id, bed_occupants)

func _move_npcs_to_assignments(floor_id: String, bed_occupants: Array[String]) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for citizen_id: String in group_markers.keys():
		var marker: Node3D = group_markers[citizen_id] as Node3D
		var target: Vector3 = FLOOR_POSITION + Vector3(0, 0.86, 0.70)
		if citizen_id != floor_id:
			var bed_index: int = bed_occupants.find(citizen_id)
			if bed_index >= 0 and bed_index < BED_POSITIONS.size():
				target = BED_POSITIONS[bed_index] + Vector3(0, 0.86, 0.68)
		tween.tween_property(marker, "position", target, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _citizen_color(citizen_id: String) -> Color:
	match citizen_id:
		"elias":
			return Color("5fd1c0")
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

func apply_sleep_choice_for_test(citizen_id: String) -> void:
	_resolve_sleep_choice(citizen_id)
