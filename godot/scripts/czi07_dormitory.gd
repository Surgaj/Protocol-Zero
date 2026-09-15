extends Node3D

# PROTOCOL ZERO — CZI-07 Dormitory 3D Blockout
# Objetivo: provar câmera 3/4, volume, iluminação e leitura de sala.
# Os meshes são placeholders procedurais e serão substituídos por arte 3D estilizada.

func _ready() -> void:
	build_environment()
	build_room_shell()
	build_beds()
	build_props()
	build_lighting()
	build_camera()

func make_material(color: Color, roughness := 0.78, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func add_box(name_: String, size: Vector3, pos: Vector3, color: Color, parent: Node = self, metallic := 0.0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = make_material(color, 0.76, metallic)
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance

func add_cylinder(name_: String, radius: float, height: float, pos: Vector3, color: Color, parent: Node = self) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name_
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = make_material(color, 0.62, 0.35)
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance

func build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080704")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a5131")
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.85
	world.environment = env
	add_child(world)

func build_room_shell() -> void:
	# Chão e paredes espessas para abandonar a sensação de 'quadro plano'.
	add_box("Floor", Vector3(12.0, 0.35, 8.0), Vector3(0, -0.2, 0), Color("2a2118"))
	add_box("BackWall", Vector3(12.0, 4.6, 0.35), Vector3(0, 2.1, -3.82), Color("211b15"))
	add_box("LeftWall", Vector3(0.35, 4.6, 8.0), Vector3(-5.82, 2.1, 0), Color("1c1814"))
	add_box("RightWall", Vector3(0.35, 4.6, 8.0), Vector3(5.82, 2.1, 0), Color("1c1814"))

	# Faixa técnica e conduíte de parede.
	add_box("BackRail", Vector3(10.6, 0.18, 0.22), Vector3(0, 3.55, -3.55), Color("6b4826"), self, 0.15)
	var pipe := add_cylinder("UtilityPipe", 0.11, 10.2, Vector3(0, 3.05, -3.48), Color("5a4633"))
	pipe.rotation_degrees = Vector3(0, 0, 90)

func build_beds() -> void:
	var bed_positions := [
		Vector3(-3.7, 0.35, -1.85),
		Vector3(-1.25, 0.35, -1.85),
		Vector3(-3.7, 0.35, 1.05),
		Vector3(-1.25, 0.35, 1.05)
	]

	for i in bed_positions.size():
		var p: Vector3 = bed_positions[i]
		add_box("BedFrame_%d" % i, Vector3(2.0, 0.35, 0.92), p, Color("40372d"), self, 0.18)
		add_box("Mattress_%d" % i, Vector3(1.82, 0.24, 0.78), p + Vector3(0, 0.28, 0), Color("75684e"))
		add_box("Pillow_%d" % i, Vector3(0.45, 0.15, 0.6), p + Vector3(-0.58, 0.46, 0), Color("a28d69"))

	# Quinto lugar improvisado: visualmente diferente dos quatro leitos.
	add_box("ImprovisedBlanket", Vector3(1.9, 0.10, 0.95), Vector3(3.55, 0.04, 1.35), Color("7f432c"))
	add_box("ImprovisedBag", Vector3(0.55, 0.45, 0.55), Vector3(4.25, 0.22, 1.8), Color("4d4030"))

func build_props() -> void:
	# Armários altos.
	add_box("LockerA", Vector3(0.85, 2.25, 0.72), Vector3(4.6, 1.1, -2.55), Color("39413d"), self, 0.22)
	add_box("LockerB", Vector3(0.85, 2.25, 0.72), Vector3(3.65, 1.1, -2.55), Color("313936"), self, 0.22)

	# Caixas pessoais e banco, para dar densidade e escala humana.
	add_box("CrateA", Vector3(1.1, 0.75, 0.9), Vector3(2.7, 0.35, -2.35), Color("60452f"))
	add_box("CrateB", Vector3(0.85, 0.55, 0.7), Vector3(2.2, 0.28, -1.5), Color("4c3828"))
	add_box("Bench", Vector3(2.15, 0.38, 0.62), Vector3(3.7, 0.3, -0.35), Color("584633"))

	# Prateleira e objetos pequenos.
	add_box("Shelf", Vector3(2.7, 0.16, 0.65), Vector3(3.7, 2.55, -3.35), Color("4b4137"), self, 0.2)
	add_box("TinA", Vector3(0.28, 0.36, 0.28), Vector3(3.1, 2.78, -3.25), Color("6c6c60"), self, 0.35)
	add_box("TinB", Vector3(0.32, 0.42, 0.32), Vector3(3.55, 2.81, -3.25), Color("77543b"), self, 0.2)
	add_box("MedBox", Vector3(0.62, 0.38, 0.38), Vector3(4.3, 2.76, -3.24), Color("76634a"))

	# Tapete central quebra o chão plano.
	add_box("WornRug", Vector3(2.8, 0.035, 1.6), Vector3(0.95, 0.005, 0.2), Color("4f3125"))

func build_lighting() -> void:
	# Luz quente principal com sombras reais.
	var key := OmniLight3D.new()
	key.name = "WarmCeilingLight"
	key.position = Vector3(-0.8, 3.9, -0.5)
	key.light_color = Color("f2a84b")
	key.light_energy = 3.4
	key.omni_range = 9.0
	key.shadow_enabled = true
	add_child(key)

	# Luz de recorte fria para dar contraste premium e separar volumes.
	var rim := OmniLight3D.new()
	rim.name = "ColdRimLight"
	rim.position = Vector3(4.8, 2.3, 2.7)
	rim.light_color = Color("55b7ae")
	rim.light_energy = 1.25
	rim.omni_range = 5.4
	rim.shadow_enabled = true
	add_child(rim)

	# Luz fraca perto do improvisado para guiar narrativa sem texto.
	var story := OmniLight3D.new()
	story.name = "ImprovisedBedAccent"
	story.position = Vector3(3.6, 1.25, 1.2)
	story.light_color = Color("b9502b")
	story.light_energy = 0.75
	story.omni_range = 2.6
	add_child(story)

func build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.3
	camera.position = Vector3(10.8, 10.2, 12.6)
	camera.look_at_from_position(camera.position, Vector3(0, 1.05, 0), Vector3.UP)
	camera.current = true
	add_child(camera)
