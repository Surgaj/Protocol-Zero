extends Node3D

# PROTOCOL ZERO — Vertical Slice / Scene 01 Greybox
# Milestone 0.2: primeiro objeto interativo, rádio + sintonização + áudio procedural.
# Regra: ainda é greybox. Nenhuma arte final antes das quatro cenas funcionarem ponta a ponta.
# Escala humana de referência: Elias 1,80 m; porta 2,20 m; sala 8 x 12 m.

var objective_label: Label
var status_label: Label
var player: CharacterBody3D
var gameplay_camera: Camera3D
var virtual_stick: Control
var radio: Node3D
var radio_interact_button: Button
var tuner_panel: Control
var signal_panel: ColorRect
var signal_label: Label
var scene_signal_locked: bool = false

func _ready() -> void:
	build_environment()
	build_room()
	player = build_player()
	gameplay_camera = build_camera(player)
	player.call("set_movement_camera", gameplay_camera)
	build_ui()
	radio = build_radio()
	build_exit_trigger()

func make_material(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func add_static_box(name_: String, size: Vector3, pos: Vector3, color: Color, parent: Node = self) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.position = pos
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = make_material(color)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("161616")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d0d0d0")
	environment.ambient_light_energy = 0.55
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("f0f0f0")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

func build_room() -> void:
	var grey_floor := Color("777777")
	var grey_wall := Color("666666")
	var grey_door := Color("8a8a8a")

	add_static_box("Floor", Vector3(8.0, 0.30, 12.0), Vector3(0, -0.15, 0), grey_floor)
	add_static_box("LeftWall", Vector3(0.30, 3.0, 12.0), Vector3(-3.85, 1.5, 0), grey_wall)
	add_static_box("RightCutawayLip", Vector3(0.30, 0.65, 12.0), Vector3(3.85, 0.325, 0), Color("5f5f5f"))
	add_static_box("FrontCutawayLip", Vector3(8.0, 0.65, 0.30), Vector3(0, 0.325, 5.85), Color("5f5f5f"))

	add_static_box("BackWallLeft", Vector3(3.30, 3.0, 0.30), Vector3(-2.35, 1.5, -5.85), grey_wall)
	add_static_box("BackWallRight", Vector3(3.30, 3.0, 0.30), Vector3(2.35, 1.5, -5.85), grey_wall)
	add_static_box("DoorLintel", Vector3(1.80, 0.80, 0.45), Vector3(0, 2.60, -5.78), grey_door)
	add_static_box("DoorPostLeft", Vector3(0.20, 2.20, 0.45), Vector3(-0.80, 1.10, -5.78), grey_door)
	add_static_box("DoorPostRight", Vector3(0.20, 2.20, 0.45), Vector3(0.80, 1.10, -5.78), grey_door)

	add_static_box("ExitFloor", Vector3(3.0, 0.30, 4.0), Vector3(0, -0.15, -7.75), Color("707070"))
	add_static_box("ExitWallLeft", Vector3(0.25, 2.6, 4.0), Vector3(-1.38, 1.30, -7.75), Color("5f5f5f"))
	add_static_box("ExitWallRightLip", Vector3(0.25, 0.65, 4.0), Vector3(1.38, 0.325, -7.75), Color("595959"))

	var door_light := OmniLight3D.new()
	door_light.name = "DoorGuideLight"
	door_light.position = Vector3(0, 2.45, -5.1)
	door_light.light_color = Color("d7c08a")
	door_light.light_energy = 1.2
	door_light.omni_range = 3.4
	door_light.shadow_enabled = true
	add_child(door_light)

func build_player() -> CharacterBody3D:
	var new_player := CharacterBody3D.new()
	new_player.name = "Elias_GreyCapsule"
	new_player.position = Vector3(0, 0.90, 3.45)
	new_player.set_script(load("res://scripts/vertical_slice/player_capsule.gd"))
	add_child(new_player)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.80
	mesh.material = make_material(Color("b7b7b7"), 0.95)
	mesh_instance.mesh = mesh
	new_player.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.80
	collision.shape = capsule
	new_player.add_child(collision)
	return new_player

func build_camera(target_player: CharacterBody3D) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "GreyboxCamera"
	camera.set_script(load("res://scripts/vertical_slice/camera_follow.gd"))
	add_child(camera)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 9.4

	# Ângulo aprovado no Milestone 0.1: congelado enquanto construímos interação.
	var offset := Vector3(8.5, 6.0, 10.0)
	camera.set("camera_offset", offset)
	camera.set("follow_min", Vector2(-0.65, -2.8))
	camera.set("follow_max", Vector2(0.65, 2.8))
	camera.global_position = target_player.global_position + offset
	camera.look_at(target_player.global_position + Vector3(0, 0.78, 0), Vector3.UP)
	camera.current = true
	camera.call("set_target", target_player)
	return camera

func build_radio() -> Node3D:
	var radio_root := Node3D.new()
	radio_root.name = "FieldRadio"
	radio_root.position = Vector3(-2.45, 0.0, -1.35)
	radio_root.set_script(load("res://scripts/vertical_slice/radio.gd"))

	# Greybox funcional: caixa/base + corpo do rádio + antena. Sem asset final.
	add_static_box("RadioCrate", Vector3(1.15, 0.65, 0.78), Vector3(0, 0.325, 0), Color("555555"), radio_root)
	add_static_box("RadioBody", Vector3(0.88, 0.48, 0.48), Vector3(0, 0.88, 0), Color("7b7b72"), radio_root)
	add_static_box("RadioAntenna", Vector3(0.045, 0.95, 0.045), Vector3(0.34, 1.50, 0), Color("9b9b94"), radio_root)

	var indicator := OmniLight3D.new()
	indicator.name = "RadioGuideLight"
	indicator.position = Vector3(0, 1.25, 0.05)
	indicator.light_color = Color("d2ad62")
	indicator.light_energy = 1.15
	indicator.omni_range = 2.2
	radio_root.add_child(indicator)

	var proximity := Area3D.new()
	proximity.name = "Proximity"
	proximity.position = Vector3(0, 1.0, 0)
	var proximity_collision := CollisionShape3D.new()
	var proximity_shape := BoxShape3D.new()
	proximity_shape.size = Vector3(3.0, 2.2, 3.0)
	proximity_collision.shape = proximity_shape
	proximity.add_child(proximity_collision)
	radio_root.add_child(proximity)

	var audio := AudioStreamPlayer3D.new()
	audio.name = "StaticAudio"
	audio.position = Vector3(0, 1.0, 0)
	radio_root.add_child(audio)

	add_child(radio_root)

	radio_root.connect("proximity_changed", Callable(self, "_on_radio_proximity_changed"))
	radio_root.connect("tuning_started", Callable(self, "_on_radio_tuning_started"))
	radio_root.connect("tuning_feedback", Callable(self, "_on_radio_tuning_feedback"))
	radio_root.connect("signal_locked", Callable(self, "_on_radio_signal_locked"))
	return radio_root

func build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GreyboxUI"
	add_child(layer)

	var panel := ColorRect.new()
	panel.position = Vector2(24, 22)
	panel.size = Vector2(620, 104)
	panel.color = Color(0.04, 0.04, 0.04, 0.82)
	layer.add_child(panel)

	objective_label = Label.new()
	objective_label.position = Vector2(20, 12)
	objective_label.text = "CENA 1 — O SINAL"
	objective_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(20, 44)
	status_label.text = "OBJETIVO: encontre e sintonize o rádio\nAproxime-se do equipamento iluminado."
	status_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(status_label)

	virtual_stick = Control.new()
	virtual_stick.name = "VirtualStick"
	virtual_stick.set_script(load("res://scripts/vertical_slice/virtual_stick.gd"))
	virtual_stick.anchor_left = 0.0
	virtual_stick.anchor_top = 1.0
	virtual_stick.anchor_right = 0.0
	virtual_stick.anchor_bottom = 1.0
	virtual_stick.offset_left = 30.0
	virtual_stick.offset_top = -218.0
	virtual_stick.offset_right = 218.0
	virtual_stick.offset_bottom = -30.0
	layer.add_child(virtual_stick)

	radio_interact_button = Button.new()
	radio_interact_button.name = "RadioInteract"
	radio_interact_button.text = "INTERAGIR"
	radio_interact_button.anchor_left = 1.0
	radio_interact_button.anchor_top = 1.0
	radio_interact_button.anchor_right = 1.0
	radio_interact_button.anchor_bottom = 1.0
	radio_interact_button.offset_left = -230.0
	radio_interact_button.offset_top = -150.0
	radio_interact_button.offset_right = -30.0
	radio_interact_button.offset_bottom = -72.0
	radio_interact_button.add_theme_font_size_override("font_size", 20)
	radio_interact_button.visible = false
	radio_interact_button.pressed.connect(_on_radio_interact_pressed)
	layer.add_child(radio_interact_button)

	tuner_panel = Control.new()
	tuner_panel.name = "RadioDial"
	tuner_panel.position = Vector2(36, 398)
	tuner_panel.size = Vector2(648, 340)
	tuner_panel.set_script(load("res://scripts/vertical_slice/dial.gd"))
	tuner_panel.visible = false
	tuner_panel.connect("frequency_changed", Callable(self, "_on_dial_frequency_changed"))
	layer.add_child(tuner_panel)

	signal_panel = ColorRect.new()
	signal_panel.name = "DecodedSignal"
	signal_panel.position = Vector2(50, 168)
	signal_panel.size = Vector2(620, 172)
	signal_panel.color = Color(0.025, 0.025, 0.025, 0.94)
	signal_panel.visible = false
	layer.add_child(signal_panel)

	signal_label = Label.new()
	signal_label.position = Vector2(24, 18)
	signal_label.text = ""
	signal_label.add_theme_font_size_override("font_size", 18)
	signal_panel.add_child(signal_label)

func build_exit_trigger() -> void:
	var area := Area3D.new()
	area.name = "Scene01Exit"
	area.position = Vector3(0, 1.0, -6.95)
	add_child(area)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.55, 2.2, 1.2)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_exit_crossed)

func _on_radio_proximity_changed(is_near: bool) -> void:
	if scene_signal_locked:
		radio_interact_button.visible = false
		return
	radio_interact_button.visible = is_near and not tuner_panel.visible
	if is_near:
		status_label.text = "RÁDIO AO ALCANCE\nToque INTERAGIR para abrir o sintonizador."
	else:
		status_label.text = "OBJETIVO: encontre e sintonize o rádio\nAproxime-se do equipamento iluminado."

func _on_radio_interact_pressed() -> void:
	if radio == null or scene_signal_locked:
		return
	var started := bool(radio.call("begin_tuning"))
	if not started:
		return

	player.call("set_input_enabled", false)
	virtual_stick.visible = false
	radio_interact_button.visible = false
	tuner_panel.visible = true
	tuner_panel.call(
		"setup",
		float(radio.get("min_frequency")),
		float(radio.get("max_frequency")),
		float(radio.get("current_frequency"))
	)
	objective_label.text = "CENA 1 — SINTONIZAÇÃO"
	status_label.text = "Arraste o dial. Ouça a estática mudar conforme o sinal se aproxima."

func _on_radio_tuning_started() -> void:
	# Mantido separado para futura animação/feedback do rádio.
	pass

func _on_dial_frequency_changed(value: float) -> void:
	if radio != null:
		radio.call("set_frequency", value)

func _on_radio_tuning_feedback(frequency: float, proximity: float, in_lock_zone: bool, lock_progress: float) -> void:
	if tuner_panel != null and tuner_panel.visible:
		tuner_panel.call("set_feedback", frequency, proximity, in_lock_zone, lock_progress)

func _on_radio_signal_locked(frequency: float) -> void:
	if scene_signal_locked:
		return
	scene_signal_locked = true
	tuner_panel.call("set_feedback", frequency, 1.0, true, 1.0)
	tuner_panel.call("set_locked")

	signal_panel.visible = true
	signal_label.text = "CZI-07\nNODE OFFLINE\nEMERGENCY POWER AVAILABLE\n\nPOSITION TRIANGULATED"
	objective_label.text = "CENA 1 — SINAL ADQUIRIDO"
	status_label.text = "Frequência travada. Decodificando transmissão..."

	await get_tree().create_timer(1.35).timeout
	tuner_panel.visible = false
	virtual_stick.visible = true
	player.call("set_input_enabled", true)
	objective_label.text = "CENA 1 — CONCLUÍDA"
	status_label.text = "POSITION TRIANGULATED\nOBJETIVO: siga as coordenadas do CZI-07."

func _on_exit_crossed(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	if scene_signal_locked:
		status_label.text = "CZI-07 localizado. Próximo: encontro com Maya."
	else:
		status_label.text = "Sem coordenadas. Volte e sintonize o rádio antes de seguir."
