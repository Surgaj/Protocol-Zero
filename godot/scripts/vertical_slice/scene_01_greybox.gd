extends Node3D

# PROTOCOL ZERO — Vertical Slice / Scene 01 Greybox
# Meta mínima: cápsula cinza anda, atravessa uma porta cinza, cena reconhece a travessia.

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
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color("f0f0f0")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

func build_room() -> void:
	var grey_floor := Color("777777")
	var grey_wall := Color("666666")
	var grey_door := Color("8a8a8a")

	# Sala 14 x 20. Tudo propositalmente sem arte.
	add_static_box("Floor", Vector3(14.0, 0.5, 20.0), Vector3(0, -0.25, 0), grey_floor)
	add_static_box("LeftWall", Vector3(0.5, 3.5, 20.0), Vector3(-6.75, 1.75, 0), grey_wall)
	add_static_box("RightWall", Vector3(0.5, 3.5, 20.0), Vector3(6.75, 1.75, 0), grey_wall)
	add_static_box("FrontWall", Vector3(14.0, 3.5, 0.5), Vector3(0, 1.75, 9.75), grey_wall)

	# Parede do fundo dividida para deixar uma abertura real de porta.
	add_static_box("BackWallLeft", Vector3(5.5, 3.5, 0.5), Vector3(-4.25, 1.75, -9.75), grey_wall)
	add_static_box("BackWallRight", Vector3(5.5, 3.5, 0.5), Vector3(4.25, 1.75, -9.75), grey_wall)
	add_static_box("DoorLintel", Vector3(3.0, 0.65, 0.75), Vector3(0, 3.18, -9.62), grey_door)
	add_static_box("DoorPostLeft", Vector3(0.35, 3.0, 0.75), Vector3(-1.68, 1.5, -9.62), grey_door)
	add_static_box("DoorPostRight", Vector3(0.35, 3.0, 0.75), Vector3(1.68, 1.5, -9.62), grey_door)

	# Pequeno corredor depois da porta para a travessia ser inequívoca.
	add_static_box("ExitFloor", Vector3(4.5, 0.5, 5.0), Vector3(0, -0.25, -12.25), Color("707070"))
	add_static_box("ExitWallLeft", Vector3(0.4, 3.0, 5.0), Vector3(-2.05, 1.5, -12.25), Color("5f5f5f"))
	add_static_box("ExitWallRight", Vector3(0.4, 3.0, 5.0), Vector3(2.05, 1.5, -12.25), Color("5f5f5f"))

func build_player() -> CharacterBody3D:
	var new_player := CharacterBody3D.new()
	new_player.name = "Elias_GreyCapsule"
	new_player.position = Vector3(0, 1.15, 6.25)
	new_player.set_script(load("res://scripts/vertical_slice/player_capsule.gd"))
	add_child(new_player)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.48
	mesh.height = 2.2
	mesh.material = make_material(Color("b7b7b7"), 0.95)
	mesh_instance.mesh = mesh
	new_player.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 2.2
	collision.shape = capsule
	new_player.add_child(collision)
	return new_player

func build_camera(target_player: CharacterBody3D) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "GreyboxCamera"
	camera.set_script(load("res://scripts/vertical_slice/camera_follow.gd"))
	add_child(camera)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Retrato 9:16: size 26 mantém a largura de 14 m da sala legível.
	camera.size = 26.0
	camera.global_position = target_player.global_position + Vector3(14.5, 17.5, 18.5)
	camera.look_at(target_player.global_position + Vector3(0, 0.7, 0), Vector3.UP)
	camera.current = true
	camera.call("set_target", target_player)
	return camera

func build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GreyboxUI"
	add_child(layer)

	var panel := ColorRect.new()
	panel.position = Vector2(24, 22)
	panel.size = Vector2(620, 92)
	panel.color = Color(0.04, 0.04, 0.04, 0.78)
	layer.add_child(panel)

	objective_label = Label.new()
	objective_label.position = Vector2(20, 12)
	objective_label.text = "CENA 1 — GREYBOX"
	objective_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(objective_label)

	status_label = Label.new()
	status_label.position = Vector2(20, 44)
	status_label.text = "OBJETIVO: atravesse a porta cinza  •  WASD / setas"
	status_label.add_theme_font_size_override("font_size", 15)
	panel.add_child(status_label)

func build_exit_trigger() -> void:
	var area := Area3D.new()
	area.name = "Scene01Exit"
	area.position = Vector3(0, 1.0, -11.3)
	add_child(area)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.4, 2.5, 1.4)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_exit_crossed)

func _on_exit_crossed(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	objective_label.text = "CENA 1 — PASSAGEM VALIDADA"
	status_label.text = "A cápsula atravessou a porta. Próximo: interação + sinal."
