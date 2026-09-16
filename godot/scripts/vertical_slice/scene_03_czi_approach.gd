extends Node3D

# PROTOCOL ZERO — Cena 3 / aproximação do CZI-07.
# Maya mantém comportamento relacional; o grupo formado na Jornada chega junto e espera na entrada.
# Comunicação: o jogador recebe uma ação explícita ao alcançar a porta, sem depender de inferência.

var player: CharacterBody3D
var maya: CharacterBody3D
var gameplay_camera: Camera3D
var virtual_stick: Control
var objective_label: Label
var status_label: Label
var door_light: OmniLight3D
var entry_button: Button
var group_markers: Dictionary = {}
var _door_pulse_time: float = 0.0

func _ready() -> void:
	GameState.ensure_new_run()
	_build_environment()
	_build_approach()
	player = _build_player()
	maya = _build_maya()
	_build_recruited_group()
	gameplay_camera = _build_camera(player)
	player.call("set_movement_camera", gameplay_camera)
	maya.call("configure", player, Vector3(-0.9, 0.90, -5.0), Vector3(-1.65, 0.90, -5.15))
	_build_ui()
	_build_entry_trigger()

func _process(delta: float) -> void:
	_door_pulse_time += delta
	if door_light != null:
		# Âncora visual discreta: a própria luz da porta respira.
		door_light.light_energy = 1.28 + sin(_door_pulse_time * 3.0) * 0.32

	if player == null:
		return
	var offsets: Dictionary = {
		"iris": Vector3(1.25, 0.0, 1.8),
		"dante": Vector3(-1.55, 0.0, 2.7),
		"noah": Vector3(1.60, 0.0, 2.9),
	}
	for citizen_id: String in group_markers.keys():
		var marker: Node3D = group_markers[citizen_id] as Node3D
		var target: Vector3 = player.global_position + (offsets[citizen_id] as Vector3)
		target.y = 0.90
		# Os três param do lado de fora; Elias é quem cruza o limiar primeiro.
		target.z = maxf(target.z, -4.55)
		marker.global_position = marker.global_position.move_toward(target, delta * 2.5)

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
	environment.background_color = Color("121212")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9c9c9")
	environment.ambient_light_energy = 0.48
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)

func _build_approach() -> void:
	_add_box("Ground", Vector3(8.0, 0.30, 15.0), Vector3(0, -0.15, -0.5), Color("666666"))
	_add_box("LeftBoundary", Vector3(0.30, 1.2, 15.0), Vector3(-3.85, 0.6, -0.5), Color("4f4f4f"))
	_add_box("RightBoundary", Vector3(0.30, 0.55, 15.0), Vector3(3.85, 0.275, -0.5), Color("484848"))
	_add_box("CZIWallLeft", Vector3(3.2, 3.6, 0.45), Vector3(-2.4, 1.8, -6.2), Color("55585a"))
	_add_box("CZIWallRight", Vector3(3.2, 3.6, 0.45), Vector3(2.4, 1.8, -6.2), Color("55585a"))
	_add_box("CZILintel", Vector3(1.9, 1.0, 0.45), Vector3(0, 3.05, -6.2), Color("686b6d"))
	_add_box("CZIDoorLeft", Vector3(0.75, 2.2, 0.36), Vector3(-0.42, 1.10, -6.05), Color("73777a"))
	_add_box("CZIDoorRight", Vector3(0.75, 2.2, 0.36), Vector3(0.42, 1.10, -6.05), Color("73777a"))
	_add_box("AccessPanel", Vector3(0.45, 0.85, 0.22), Vector3(-1.65, 1.15, -5.78), Color("777266"))
	door_light = OmniLight3D.new()
	door_light.name = "CZIEntryGuideLight"
	door_light.position = Vector3(0, 2.8, -5.4)
	door_light.light_color = Color("d0b16d")
	door_light.light_energy = 1.28
	door_light.omni_range = 4.2
	add_child(door_light)

func _build_player() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "Elias_GreyCapsule"
	body.position = Vector3(0.6, 0.90, 4.4)
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
	body.position = Vector3(-0.8, 0.90, 3.1)
	body.set_script(load("res://scripts/vertical_slice/maya_greybox.gd"))
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

func _build_recruited_group() -> void:
	var starts: Dictionary = {
		"iris": Vector3(1.25, 0.90, 3.5),
		"dante": Vector3(-1.5, 0.90, 4.2),
		"noah": Vector3(1.6, 0.90, 4.4),
	}
	for citizen_id: String in ["iris", "dante", "noah"]:
		if not GameState.is_party_member(citizen_id):
			continue
		var marker := Node3D.new()
		marker.name = "%s_GroupMarker" % citizen_id.capitalize()
		marker.position = starts[citizen_id] as Vector3
		add_child(marker)
		var mesh_instance := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.29
		mesh.height = 1.70
		mesh.material = _make_material(_citizen_color(citizen_id))
		mesh_instance.mesh = mesh
		marker.add_child(mesh_instance)
		group_markers[citizen_id] = marker

func _citizen_color(citizen_id: String) -> Color:
	match citizen_id:
		"iris":
			return Color("c79e76")
		"dante":
			return Color("b5502a")
		"noah":
			return Color("8d8a62")
		_:
			return Color("aaaaaa")

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
	camera.set("follow_min", Vector2(-0.65, -4.0))
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
	panel.name = "ObjectivePanel"
	panel.position = Vector2(24, 22)
	panel.size = Vector2(620, 104)
	panel.color = Color(0.04, 0.04, 0.04, 0.84)
	layer.add_child(panel)
	objective_label = Label.new()
	objective_label.position = Vector2(20, 12)
	objective_label.text = "CENA 3 — ENTRADA DO BUNKER"
	objective_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(objective_label)
	status_label = Label.new()
	status_label.position = Vector2(20, 44)
	status_label.text = "OBJETIVO: caminhe até a PORTA ILUMINADA.\nAo chegar, toque ENTRAR NO BUNKER."
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

	entry_button = Button.new()
	entry_button.name = "EnterBunker"
	entry_button.text = "ENTRAR NO BUNKER"
	entry_button.anchor_left = 1.0
	entry_button.anchor_top = 1.0
	entry_button.anchor_right = 1.0
	entry_button.anchor_bottom = 1.0
	entry_button.offset_left = -270.0
	entry_button.offset_top = -164.0
	entry_button.offset_right = -30.0
	entry_button.offset_bottom = -76.0
	entry_button.add_theme_font_size_override("font_size", 20)
	entry_button.visible = false
	entry_button.pressed.connect(_on_entry_button_pressed)
	layer.add_child(entry_button)

func _build_entry_trigger() -> void:
	# O limiar não troca mais de cena automaticamente.
	# Ele revela uma ação inequívoca: ENTRAR NO BUNKER.
	var area := Area3D.new()
	area.name = "CZIEntryTrigger"
	area.position = Vector3(0, 1.0, -5.30)
	add_child(area)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.2, 1.25)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_czi_entry_reached)
	area.body_exited.connect(_on_czi_entry_exited)

func _on_czi_entry_reached(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	entry_button.visible = true
	status_label.text = "VOCÊ CHEGOU À ENTRADA.\nToque ENTRAR NO BUNKER para atravessar a porta."

func _on_czi_entry_exited(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	entry_button.visible = false
	status_label.text = "OBJETIVO: caminhe até a PORTA ILUMINADA.\nAo chegar, toque ENTRAR NO BUNKER."

func _on_entry_button_pressed() -> void:
	if entry_button == null or not entry_button.visible:
		return
	get_tree().change_scene_to_file("res://scenes/vertical_slice/czi07_base.tscn")
