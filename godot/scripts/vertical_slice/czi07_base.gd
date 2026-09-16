extends Node3D

# PROTOCOL ZERO — CZI-07 persistente / arquitetura híbrida.
# A partir da entrada do bunker, salas são um único lugar físico.
# Eventos/minigames podem continuar como overlays ou cenas externas.

@export var generator_interaction_radius: float = 2.1

var geometry_root: Node3D
var entrance_hall: Node3D
var main_corridor: Node3D
var generator_room: Node3D
var dormitory_room: Node3D

var player: CharacterBody3D
var gameplay_camera: Camera3D
var virtual_stick: Control
var interact_button: Button
var objective_label: Label
var status_label: Label
var generator_body: StaticBody3D
var dormitory_trigger: Area3D

var generator_light: OmniLight3D
var entry_light: OmniLight3D
var corridor_light: OmniLight3D
var dormitory_light: OmniLight3D
var emergency_light: OmniLight3D
var interior_fill_light: DirectionalLight3D
var bunker_environment: Environment

var drone_player: AudioStreamPlayer
var drone_generator: AudioStreamGenerator
var drone_playback: AudioStreamGeneratorPlayback
var _drone_phase: float = 0.0
var _drone_second_phase: float = 0.0
var _drone_third_phase: float = 0.0
var _drone_gain: float = 0.0
var _drone_target_gain: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var power_started: bool = false
var power_complete: bool = false
var current_zone: String = "interior"
var _scene_elapsed: float = 0.0

func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_room_roots()
	_build_bunker_layout()
	_build_lights()
	interior_fill_light = get_node_or_null("DeadInteriorFill") as DirectionalLight3D
	player = _build_player()
	gameplay_camera = _build_camera(player)
	player.call("set_movement_camera", gameplay_camera)
	_build_ui()
	_build_audio()
	_build_dormitory_trigger()
	set_process(true)

func _process(delta: float) -> void:
	_scene_elapsed += delta
	_update_emergency_beacon()
	_refresh_generator_proximity()
	_drone_gain = move_toward(_drone_gain, _drone_target_gain, delta * 0.08)
	_fill_drone_buffer()

func _make_material(color: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_static_box(name_: String, size: Vector3, pos: Vector3, color: Color, parent: Node) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.position = pos
	parent.add_child(body)

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
	bunker_environment = Environment.new()
	bunker_environment.background_mode = Environment.BG_COLOR
	bunker_environment.background_color = Color("050505")
	bunker_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	bunker_environment.ambient_light_color = Color("a7adb0")
	bunker_environment.ambient_light_energy = 0.12
	world.environment = bunker_environment
	add_child(world)

func _build_room_roots() -> void:
	geometry_root = Node3D.new()
	geometry_root.name = "Geometry"
	add_child(geometry_root)

	entrance_hall = Node3D.new()
	entrance_hall.name = "EntranceHall"
	geometry_root.add_child(entrance_hall)

	main_corridor = Node3D.new()
	main_corridor.name = "MainCorridor"
	geometry_root.add_child(main_corridor)

	generator_room = Node3D.new()
	generator_room.name = "GeneratorRoom"
	geometry_root.add_child(generator_room)

	dormitory_room = Node3D.new()
	dormitory_room.name = "DormitoryRoom"
	geometry_root.add_child(dormitory_room)

func _build_bunker_layout() -> void:
	var floor_color := Color("4b4d4d")
	var wall_color := Color("555859")
	var steel_color := Color("686b6c")
	var lip_color := Color("484b4c")

	# Entrada: é o mesmo espaço físico que continua no corredor.
	_add_static_box("EntranceFloor", Vector3(6.0, 0.30, 4.0), Vector3(0, -0.15, 5.5), floor_color, entrance_hall)
	_add_static_box("EntranceLeftWall", Vector3(0.32, 3.4, 4.0), Vector3(-2.84, 1.70, 5.5), wall_color, entrance_hall)
	_add_static_box("EntranceRightLip", Vector3(0.32, 0.68, 4.0), Vector3(2.84, 0.34, 5.5), lip_color, entrance_hall)
	_add_static_box("EntryLintel", Vector3(6.0, 0.65, 0.36), Vector3(0, 3.0, 7.28), steel_color, entrance_hall)

	# Corredor principal. A parede direita é interrompida por uma passagem REAL para o dormitório.
	_add_static_box("CorridorFloor", Vector3(6.0, 0.30, 10.0), Vector3(0, -0.15, -1.5), floor_color, main_corridor)
	_add_static_box("CorridorLeftWall", Vector3(0.32, 3.4, 10.0), Vector3(-2.84, 1.70, -1.5), wall_color, main_corridor)
	_add_static_box("CorridorRightLipFront", Vector3(0.32, 0.68, 6.4), Vector3(2.84, 0.34, 0.3), lip_color, main_corridor)
	_add_static_box("CorridorRightLipRear", Vector3(0.32, 0.68, 2.0), Vector3(2.84, 0.34, -5.5), lip_color, main_corridor)
	_add_static_box("DormDoorPostFront", Vector3(0.32, 2.55, 0.18), Vector3(2.84, 1.275, -2.98), steel_color, main_corridor)
	_add_static_box("DormDoorPostRear", Vector3(0.32, 2.55, 0.18), Vector3(2.84, 1.275, -4.42), steel_color, main_corridor)
	_add_static_box("DormDoorLintel", Vector3(0.32, 0.55, 1.62), Vector3(2.84, 2.425, -3.70), steel_color, main_corridor)

	# Sala do gerador: continuação do mesmo piso, sem troca de cena.
	_add_static_box("GeneratorFloor", Vector3(6.0, 0.30, 4.0), Vector3(0, -0.15, -8.5), floor_color, generator_room)
	_add_static_box("GeneratorLeftWall", Vector3(0.32, 3.4, 4.0), Vector3(-2.84, 1.70, -8.5), wall_color, generator_room)
	_add_static_box("GeneratorRightLip", Vector3(0.32, 0.68, 4.0), Vector3(2.84, 0.34, -8.5), lip_color, generator_room)
	_add_static_box("GeneratorBackWall", Vector3(6.0, 3.4, 0.32), Vector3(0, 1.70, -10.35), wall_color, generator_room)
	generator_body = _add_static_box("AuxGenerator", Vector3(1.75, 1.25, 1.15), Vector3(0, 0.625, -8.25), Color("666a5f"), generator_room)
	_add_static_box("GeneratorTop", Vector3(1.35, 0.28, 0.86), Vector3(0, 1.36, -8.25), Color("7b7e70"), generator_room)
	_add_static_box("GeneratorPipe", Vector3(0.22, 1.35, 0.22), Vector3(-0.62, 1.65, -8.32), Color("5b5e59"), generator_room)

	# Dormitório: vazio por enquanto. Cena 5 adicionará camas e decisão social AQUI,
	# sem carregar outro mapa. O jogador já pode entrar e voltar andando.
	_add_static_box("DormitoryFloor", Vector3(4.2, 0.30, 6.0), Vector3(4.85, -0.15, -4.85), Color("4a4d4e"), dormitory_room)
	_add_static_box("DormitoryPartitionFront", Vector3(0.30, 3.1, 1.05), Vector3(2.72, 1.55, -2.375), Color("525657"), dormitory_room)
	_add_static_box("DormitoryPartitionRear", Vector3(0.30, 3.1, 3.35), Vector3(2.72, 1.55, -6.175), Color("525657"), dormitory_room)
	_add_static_box("DormitoryCutawayLip", Vector3(0.30, 0.68, 6.0), Vector3(6.82, 0.34, -4.85), lip_color, dormitory_room)
	_add_static_box("DormitoryBackWall", Vector3(4.2, 3.1, 0.30), Vector3(4.85, 1.55, -7.85), Color("525657"), dormitory_room)
	_add_static_box("DormitoryFrontLip", Vector3(4.2, 0.68, 0.30), Vector3(4.85, 0.34, -1.85), lip_color, dormitory_room)

func _build_lights() -> void:
	generator_light = OmniLight3D.new()
	generator_light.name = "GeneratorRoomLight"
	generator_light.position = Vector3(0, 2.55, -7.55)
	generator_light.light_color = Color("ded6bd")
	generator_light.light_energy = 0.0
	generator_light.omni_range = 6.2
	generator_light.shadow_enabled = true
	add_child(generator_light)

	entry_light = OmniLight3D.new()
	entry_light.name = "EntryCeilingLight"
	entry_light.position = Vector3(0, 2.55, 4.8)
	entry_light.light_color = Color("d9d0b2")
	entry_light.light_energy = 0.0
	entry_light.omni_range = 6.0
	entry_light.shadow_enabled = true
	add_child(entry_light)

	corridor_light = OmniLight3D.new()
	corridor_light.name = "CorridorLight"
	corridor_light.position = Vector3(0, 2.55, -1.8)
	corridor_light.light_color = Color("cec9b8")
	corridor_light.light_energy = 0.0
	corridor_light.omni_range = 6.5
	corridor_light.shadow_enabled = true
	add_child(corridor_light)

	dormitory_light = OmniLight3D.new()
	dormitory_light.name = "DormitoryLight"
	dormitory_light.position = Vector3(4.85, 2.15, -4.85)
	dormitory_light.light_color = Color("c9d1c4")
	dormitory_light.light_energy = 0.0
	dormitory_light.omni_range = 6.5
	dormitory_light.shadow_enabled = false
	add_child(dormitory_light)

	emergency_light = OmniLight3D.new()
	emergency_light.name = "EmergencyBeacon"
	emergency_light.position = Vector3(0, 2.05, -7.55)
	emergency_light.light_color = Color("b23a2e")
	emergency_light.light_energy = 0.08
	emergency_light.omni_range = 5.2
	emergency_light.shadow_enabled = false
	add_child(emergency_light)

func _build_player() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Elias_GreyCapsule"
	body.position = Vector3(0, 0.90, 5.35)
	body.set_script(load("res://scripts/vertical_slice/player_capsule.gd"))
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.80
	mesh.material = _make_material(Color("c8c8c8"), 0.95)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.80
	collision.shape = capsule
	body.add_child(collision)
	return body

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
	camera.set("follow_min", Vector2(-0.70, -8.0))
	camera.set("follow_max", Vector2(5.15, 5.0))
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
	panel.position = Vector2(24, 22)
	panel.size = Vector2(620, 92)
	panel.color = Color(0.025, 0.025, 0.025, 0.88)
	layer.add_child(panel)

	objective_label = Label.new()
	objective_label.position = Vector2(20, 11)
	objective_label.text = "CZI-07 — INTERIOR"
	objective_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(20, 43)
	status_label.text = "INTERIOR SEM ENERGIA"
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

	interact_button = Button.new()
	interact_button.name = "GeneratorInteract"
	interact_button.text = "INTERAGIR"
	interact_button.anchor_left = 1.0
	interact_button.anchor_top = 1.0
	interact_button.anchor_right = 1.0
	interact_button.anchor_bottom = 1.0
	interact_button.offset_left = -230.0
	interact_button.offset_top = -150.0
	interact_button.offset_right = -30.0
	interact_button.offset_bottom = -72.0
	interact_button.add_theme_font_size_override("font_size", 20)
	interact_button.visible = false
	interact_button.pressed.connect(_on_generator_interact_pressed)
	layer.add_child(interact_button)

func _build_audio() -> void:
	drone_player = AudioStreamPlayer.new()
	drone_player.name = "BunkerDrone"
	add_child(drone_player)

	drone_generator = AudioStreamGenerator.new()
	drone_generator.mix_rate = 22050.0
	drone_generator.buffer_length = 0.35
	drone_player.stream = drone_generator
	drone_player.volume_db = -7.0

func _build_dormitory_trigger() -> void:
	dormitory_trigger = Area3D.new()
	dormitory_trigger.name = "DormitoryTrigger"
	dormitory_trigger.position = Vector3(4.85, 1.0, -4.85)
	add_child(dormitory_trigger)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.4, 2.0, 4.8)
	collision.shape = shape
	dormitory_trigger.add_child(collision)
	dormitory_trigger.body_entered.connect(_on_dormitory_entered)
	dormitory_trigger.body_exited.connect(_on_dormitory_exited)

func _refresh_generator_proximity() -> void:
	if player == null or generator_body == null or interact_button == null:
		return
	if power_started:
		interact_button.visible = false
		return

	var player_pos: Vector3 = player.global_position
	var generator_pos: Vector3 = generator_body.global_position
	var distance: float = Vector2(player_pos.x - generator_pos.x, player_pos.z - generator_pos.z).length()
	var near_generator: bool = distance <= generator_interaction_radius
	interact_button.visible = near_generator
	if near_generator:
		status_label.text = "ENERGIA AUXILIAR // INTERAÇÃO DISPONÍVEL"
	else:
		_refresh_status_for_zone()

func _refresh_status_for_zone() -> void:
	if status_label == null:
		return
	if power_started and not power_complete:
		return
	if current_zone == "dormitory":
		status_label.text = "ÁREA HABITÁVEL // SEM MOBILIÁRIO" if power_complete else "DORMITÓRIO // SEM ENERGIA"
	else:
		status_label.text = "ENERGIA AUXILIAR RESTABELECIDA" if power_complete else "INTERIOR SEM ENERGIA"

func _update_emergency_beacon() -> void:
	if emergency_light == null:
		return
	if power_complete:
		emergency_light.light_energy = 0.0
		return
	var phase: float = fmod(_scene_elapsed, 4.0)
	emergency_light.light_energy = 0.62 if phase < 0.34 else 0.08

func _on_generator_interact_pressed() -> void:
	if power_started:
		return
	power_started = true
	interact_button.visible = false
	virtual_stick.visible = false
	player.call("set_input_enabled", false)
	objective_label.text = "CZI-07 — GERADOR AUXILIAR"
	status_label.text = "ENERGIA AUXILIAR // PARTIDA..."
	_start_mobile_safe_drone()
	_run_power_sequence()

func _start_mobile_safe_drone() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, false)
	if drone_player != null and not drone_player.playing:
		drone_player.play()
		drone_playback = drone_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_drone_target_gain = 0.18
	_fill_drone_buffer()

func _fill_drone_buffer() -> void:
	if drone_player == null or not drone_player.playing or drone_generator == null:
		return
	if drone_playback == null:
		drone_playback = drone_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if drone_playback == null:
		return

	var frames: int = drone_playback.get_frames_available()
	var mix_rate: float = drone_generator.mix_rate
	for _i: int in range(frames):
		var fundamental: float = sin(_drone_phase) * _drone_gain
		var second: float = sin(_drone_second_phase) * (_drone_gain * 0.38)
		var third: float = sin(_drone_third_phase) * (_drone_gain * 0.16)
		var machine_noise: float = _rng.randf_range(-1.0, 1.0) * (_drone_gain * 0.045)
		var sample: float = clampf(fundamental + second + third + machine_noise, -0.86, 0.86)
		drone_playback.push_frame(Vector2(sample, sample))
		_drone_phase = fmod(_drone_phase + TAU * 82.0 / mix_rate, TAU)
		_drone_second_phase = fmod(_drone_second_phase + TAU * 164.0 / mix_rate, TAU)
		_drone_third_phase = fmod(_drone_third_phase + TAU * 246.0 / mix_rate, TAU)

func _run_power_sequence() -> void:
	# Timing aprovado no device: 0 s gerador; 1.5 s sala; 3 s corredor/entrada; 5 s dormitório.
	await get_tree().create_timer(1.50).timeout
	generator_light.light_energy = 5.2
	await get_tree().create_timer(0.12).timeout
	generator_light.light_energy = 0.55
	await get_tree().create_timer(0.16).timeout
	generator_light.light_energy = 4.4
	await get_tree().create_timer(0.14).timeout
	generator_light.light_energy = 0.85
	await get_tree().create_timer(0.16).timeout
	generator_light.light_energy = 4.8

	await get_tree().create_timer(0.92).timeout
	_apply_power_stage(2)

	await get_tree().create_timer(2.00).timeout
	_apply_power_stage(3)
	_complete_power_sequence()

func _apply_power_stage(stage: int) -> void:
	if stage >= 1 and generator_light != null:
		generator_light.light_energy = 4.8
	if stage >= 2:
		if corridor_light != null:
			corridor_light.light_energy = 4.0
		if entry_light != null:
			entry_light.light_energy = 3.6
		if bunker_environment != null:
			bunker_environment.ambient_light_energy = 0.26
		if interior_fill_light != null:
			interior_fill_light.light_energy = 0.62
	if stage >= 3:
		if dormitory_light != null:
			dormitory_light.light_energy = 5.0
		if bunker_environment != null:
			bunker_environment.ambient_light_energy = 0.50
		if interior_fill_light != null:
			interior_fill_light.light_energy = 0.82

func _complete_power_sequence() -> void:
	power_complete = true
	_apply_power_stage(3)
	_drone_target_gain = 0.14
	objective_label.text = "CZI-07 — INTERIOR"
	_refresh_status_for_zone()
	player.call("set_input_enabled", true)
	virtual_stick.visible = true

func _on_dormitory_entered(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	current_zone = "dormitory"
	objective_label.text = "CZI-07 — DORMITÓRIO"
	_refresh_status_for_zone()

func _on_dormitory_exited(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	current_zone = "interior"
	objective_label.text = "CZI-07 — INTERIOR"
	_refresh_status_for_zone()

func apply_power_stage_for_test(stage: int) -> void:
	power_started = true
	_apply_power_stage(stage)
	if stage >= 3:
		power_complete = true
		_refresh_status_for_zone()
