extends Node3D

# PROTOCOL ZERO — Milestone 0.3 / Cena 2 greybox
# Prova: escolha de gameplay altera relação + memória e muda o comportamento visível de Maya.

var player: CharacterBody3D
var maya: CharacterBody3D
var gameplay_camera: Camera3D
var virtual_stick: Control
var objective_label: Label
var status_label: Label
var choice_panel: ColorRect
var choice_timeout_label: Label
var choice_open: bool = false
var choice_resolved: bool = false
var choice_time_left: float = 15.0
var maya_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	GameState.ensure_new_run()
	_build_environment()
	_build_room()
	player = _build_player()
	maya = _build_maya()
	gameplay_camera = _build_camera(player)
	player.call("set_movement_camera", gameplay_camera)
	_build_ui()
	_build_maya_trigger()
	_build_exit_trigger()
	maya_target = maya.global_position

func _process(delta: float) -> void:
	if choice_open and not choice_resolved:
		choice_time_left = maxf(0.0, choice_time_left - delta)
		choice_timeout_label.text = "DECIDA — %.0f s" % ceilf(choice_time_left)
		if choice_time_left <= 0.0:
			_resolve_choice("ignored")

	if maya != null and maya.global_position.distance_to(maya_target) > 0.03:
		maya.global_position = maya.global_position.move_toward(maya_target, delta * 1.9)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _add_box(name_: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
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
	environment.background_color = Color("151515")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d0d0d0")
	environment.ambient_light_energy = 0.52
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

func _build_room() -> void:
	_add_box("Floor", Vector3(8.0, 0.30, 12.0), Vector3(0, -0.15, 0), Color("747474"))
	_add_box("LeftWall", Vector3(0.30, 3.0, 12.0), Vector3(-3.85, 1.5, 0), Color("626262"))
	_add_box("RightLip", Vector3(0.30, 0.65, 12.0), Vector3(3.85, 0.325, 0), Color("5a5a5a"))
	_add_box("FrontLip", Vector3(8.0, 0.65, 0.30), Vector3(0, 0.325, 5.85), Color("5a5a5a"))
	_add_box("BackWallLeft", Vector3(3.3, 3.0, 0.30), Vector3(-2.35, 1.5, -5.85), Color("626262"))
	_add_box("BackWallRight", Vector3(3.3, 3.0, 0.30), Vector3(2.35, 1.5, -5.85), Color("626262"))
	_add_box("GeneratorBase", Vector3(2.5, 0.8, 1.4), Vector3(-1.85, 0.4, -2.65), Color("4e4e4e"))
	_add_box("GeneratorCore", Vector3(1.7, 1.6, 0.9), Vector3(-1.85, 1.2, -2.65), Color("68625a"))
	_add_box("Repeater", Vector3(0.8, 1.3, 0.7), Vector3(1.7, 0.65, -2.4), Color("585d61"))
	var light := OmniLight3D.new()
	light.position = Vector3(-1.85, 2.0, -2.25)
	light.light_color = Color("e0a94f")
	light.light_energy = 1.4
	light.omni_range = 3.0
	add_child(light)

func _build_player() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Elias_GreyCapsule"
	body.position = Vector3(0.8, 0.90, 3.6)
	body.set_script(load("res://scripts/vertical_slice/player_capsule.gd"))
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.80
	mesh.material = _make_material(Color("b7b7b7"))
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.80
	collision.shape = capsule
	body.add_child(collision)
	return body

func _build_maya() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Maya_GreyCapsule"
	body.position = Vector3(-1.2, 0.90, -1.25)
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.78
	mesh.material = _make_material(Color("b28243"))
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.78
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
	camera.set("follow_min", Vector2(-0.65, -2.8))
	camera.set("follow_max", Vector2(0.65, 2.8))
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
	panel.size = Vector2(620, 104)
	panel.color = Color(0.04, 0.04, 0.04, 0.84)
	layer.add_child(panel)
	objective_label = Label.new()
	objective_label.position = Vector2(20, 12)
	objective_label.text = "CENA 2 — MAYA"
	objective_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(objective_label)
	status_label = Label.new()
	status_label.position = Vector2(20, 44)
	status_label.text = "OBJETIVO: aproxime-se da engenheira na subestação."
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

	choice_panel = ColorRect.new()
	choice_panel.name = "MayaChoice"
	choice_panel.position = Vector2(42, 620)
	choice_panel.size = Vector2(636, 430)
	choice_panel.color = Color(0.025, 0.025, 0.025, 0.96)
	choice_panel.visible = false
	layer.add_child(choice_panel)
	var title := Label.new()
	title.position = Vector2(28, 24)
	title.text = "MAYA — O GERADOR ESTÁ INSTÁVEL"
	title.add_theme_font_size_override("font_size", 19)
	choice_panel.add_child(title)
	var context := Label.new()
	context.position = Vector2(28, 70)
	context.size = Vector2(580, 110)
	context.text = "A janela do repetidor está fechando.\nSe forçar o sinal agora, o gerador pode superaquecer."
	context.add_theme_font_size_override("font_size", 16)
	choice_panel.add_child(context)
	var protect := Button.new()
	protect.name = "ProtectGenerator"
	protect.position = Vector2(28, 205)
	protect.size = Vector2(580, 70)
	protect.text = "PROTEGER O GERADOR"
	protect.pressed.connect(func() -> void: _resolve_choice("generator"))
	choice_panel.add_child(protect)
	var capture_button := Button.new()
	capture_button.name = "CaptureSignal"
	capture_button.position = Vector2(28, 292)
	capture_button.size = Vector2(580, 70)
	capture_button.text = "CAPTAR O SINAL AGORA"
	capture_button.pressed.connect(func() -> void: _resolve_choice("signal"))
	choice_panel.add_child(capture_button)
	choice_timeout_label = Label.new()
	choice_timeout_label.position = Vector2(28, 380)
	choice_timeout_label.text = "DECIDA — 15 s"
	choice_panel.add_child(choice_timeout_label)

func _build_maya_trigger() -> void:
	var area := Area3D.new()
	area.name = "MayaTrigger"
	area.position = Vector3(-0.8, 1.0, -0.2)
	add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.5, 2.2, 4.5)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_maya_trigger_entered)

func _build_exit_trigger() -> void:
	var area := Area3D.new()
	area.name = "Scene02Exit"
	area.position = Vector3(0, 1.0, -5.45)
	add_child(area)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.3, 2.2, 0.8)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_exit_entered)

func _on_maya_trigger_entered(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule" or choice_resolved or choice_open:
		return
	_open_choice()

func _open_choice() -> void:
	choice_open = true
	choice_time_left = 15.0
	player.call("set_input_enabled", false)
	virtual_stick.visible = false
	choice_panel.visible = true
	status_label.text = "Maya precisa de uma prioridade. A decisão será lembrada."

func _resolve_choice(choice: String) -> void:
	if choice_resolved:
		return
	choice_resolved = true
	choice_open = false
	GameState.record_maya_substation_choice(choice)
	choice_panel.visible = false
	virtual_stick.visible = true
	player.call("set_input_enabled", true)

	match choice:
		"generator":
			maya_target = Vector3(-0.2, 0.90, -1.0)
			status_label.text = "Gerador estabilizado. Maya permanece perto.\nOBJETIVO: siga para o CZI-07."
		"signal":
			maya_target = Vector3(-2.55, 0.90, -2.65)
			status_label.text = "Sinal priorizado. Maya volta ao gerador sem esperar.\nOBJETIVO: siga para o CZI-07."
		"ignored":
			maya_target = Vector3(-2.15, 0.90, -2.20)
			status_label.text = "Maya resolveu o problema sozinha.\nOBJETIVO: siga para o CZI-07."

func apply_choice_for_test(choice: String) -> void:
	_resolve_choice(choice)

func _on_exit_entered(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	if not choice_resolved:
		_resolve_choice("ignored")
	get_tree().change_scene_to_file("res://scenes/vertical_slice/scene_03_czi_approach.tscn")
