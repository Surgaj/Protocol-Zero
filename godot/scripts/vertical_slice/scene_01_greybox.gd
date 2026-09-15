extends Node3D

# PROTOCOL ZERO — Vertical Slice / Scene 01 Greybox
# Pass 0.1b: escala humana + câmera 3/4 mais baixa + touch circular.
# Meta mínima: cápsula cinza anda, atravessa uma porta cinza, cena reconhece a travessia.
# Escala humana de referência: Elias 1,80 m; porta 2,20 m; sala 8 x 12 m.

var objective_label: Label
var status_label: Label
var player: CharacterBody3D
var gameplay_camera: Camera3D

func _ready() -> void:
	build_environment()
	build_room()
	player = build_player()
	gameplay_camera = build_camera(player)
	player.call("set_movement_camera", gameplay_camera)
	build_ui()
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

	# Sala humana, não galpão: 8 m x 12 m, paredes de 3 m.
	add_static_box("Floor", Vector3(8.0, 0.30, 12.0), Vector3(0, -0.15, 0), grey_floor)

	# Paredes distantes mantêm altura total; paredes perto da câmera viram cutaway.
	add_static_box("LeftWall", Vector3(0.30, 3.0, 12.0), Vector3(-3.85, 1.5, 0), grey_wall)
	add_static_box("RightCutawayLip", Vector3(0.30, 0.65, 12.0), Vector3(3.85, 0.325, 0), Color("5f5f5f"))
	add_static_box("FrontCutawayLip", Vector3(8.0, 0.65, 0.30), Vector3(0, 0.325, 5.85), Color("5f5f5f"))

	# Parede do fundo com vão real de 1,40 m x 2,20 m.
	add_static_box("BackWallLeft", Vector3(3.30, 3.0, 0.30), Vector3(-2.35, 1.5, -5.85), grey_wall)
	add_static_box("BackWallRight", Vector3(3.30, 3.0, 0.30), Vector3(2.35, 1.5, -5.85), grey_wall)
	add_static_box("DoorLintel", Vector3(1.80, 0.80, 0.45), Vector3(0, 2.60, -5.78), grey_door)
	add_static_box("DoorPostLeft", Vector3(0.20, 2.20, 0.45), Vector3(-0.80, 1.10, -5.78), grey_door)
	add_static_box("DoorPostRight", Vector3(0.20, 2.20, 0.45), Vector3(0.80, 1.10, -5.78), grey_door)

	# Corredor curto depois da porta: apenas o suficiente para provar a travessia.
	add_static_box("ExitFloor", Vector3(3.0, 0.30, 4.0), Vector3(0, -0.15, -7.75), Color("707070"))
	add_static_box("ExitWallLeft", Vector3(0.25, 2.6, 4.0), Vector3(-1.38, 1.30, -7.75), Color("5f5f5f"))
	add_static_box("ExitWallRightLip", Vector3(0.25, 0.65, 4.0), Vector3(1.38, 0.325, -7.75), Color("595959"))

	# Greybox de direção: uma luz discreta puxa o olho para a saída sem virar arte final.
	var door_light := OmniLight3D.new()
	door_light.name = "DoorGuideLight"
	door_light.position = Vector3(0, 2.45, -5.1)
	door_light.light_color = Color("d7c08a")
	door_light.light_energy = 1.6
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

	# 3/4 mais baixo: preserva leitura mobile, mas mostra volume/fachadas como diorama.
	var offset := Vector3(8.5, 6.0, 10.0)
	camera.set("camera_offset", offset)
	camera.set("follow_min", Vector2(-0.65, -2.8))
	camera.set("follow_max", Vector2(0.65, 2.8))
	camera.global_position = target_player.global_position + offset
	camera.look_at(target_player.global_position + Vector3(0, 0.78, 0), Vector3.UP)
	camera.current = true
	camera.call("set_target", target_player)
	return camera

func build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GreyboxUI"
	add_child(layer)

	var panel := ColorRect.new()
	panel.position = Vector2(24, 22)
	panel.size = Vector2(620, 104)
	panel.color = Color(0.04, 0.04, 0.04, 0.78)
	layer.add_child(panel)

	objective_label = Label.new()
	objective_label.position = Vector2(20, 12)
	objective_label.text = "CENA 1 — GREYBOX"
	objective_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(20, 44)
	status_label.text = "OBJETIVO: atravesse a porta iluminada\nTeclado: WASD/setas  •  Mobile/Web: arraste o círculo"
	status_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(status_label)

	var virtual_stick := Control.new()
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

func _on_exit_crossed(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	objective_label.text = "CENA 1 — PASSAGEM VALIDADA"
	status_label.text = "A cápsula atravessou a porta. Escala + câmera + touch em teste."
