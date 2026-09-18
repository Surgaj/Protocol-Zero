extends Node3D

# Visual layer only. No collisions, triggers, time progression or narrative state.
var bunker: Node3D
var rotor: Node3D
var fixtures: Array[MeshInstance3D] = []
var cached_power: bool = false
const STEEL: Color = Color("555c57")
const DARK: Color = Color("323c3b")
const PAPER: Color = Color("e9e2d2")
const AMBER: Color = Color("e8a33d")

func _ready() -> void:
	bunker = get_parent() as Node3D
	call_deferred("_build")

func _mat(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = metal
	return mat

func _mesh(name_: String, mesh: Mesh, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = name_
	visual.mesh = mesh
	visual.position = pos
	(mesh as PrimitiveMesh).material = _mat(color)
	if parent == null:
		parent = self
	parent.add_child(visual)
	return visual

func _box(name_: String, size: Vector3, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(name_, shape, pos, color, parent)

func _cylinder(name_: String, radius: float, height: float, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 12
	return _mesh(name_, shape, pos, color, parent)

func _sign(name_: String, copy: String, pos: Vector3, size: int = 48) -> Label3D:
	var label := Label3D.new()
	label.name = name_
	label.text = copy
	label.position = pos
	label.font_size = size
	label.pixel_size = 0.011
	label.modulate = PAPER
	label.outline_size = 3
	label.outline_modulate = Color("26312d")
	label.shaded = true
	add_child(label)
	return label

func _build() -> void:
	_dress_structure()
	_dress_generator()
	_dress_entry()
	_dress_corridor()
	await get_tree().process_frame
	_dress_dormitory()

func _dress_structure() -> void:
	# Shared palette keeps the original solids and all collision dimensions intact.
	for path: String in ["EntranceHall/EntranceFloor", "MainCorridor/CorridorFloor", "GeneratorRoom/GeneratorFloor"]:
		var solid: Node = bunker.get_node("Geometry/" + path)
		(solid.get_child(0) as MeshInstance3D).material_override = _mat(Color("59625d"))
	(bunker.get_node("Geometry/DormitoryRoom/DormitoryFloor").get_child(0) as MeshInstance3D).material_override = _mat(Color("766c58"))
	# Floor seams and two service rails establish scale and perspective.
	for i: int in range(12):
		_box("FloorSeam", Vector3(5.4, 0.009, 0.028), Vector3(0, 0.008, 6.8 - i * 1.4), Color("424b46"))
	for x: float in [-2.2, 2.15]:
		_box("ServiceRail", Vector3(0.055, 0.018, 16.9), Vector3(x, 0.012, -1.55), Color("aaa487"))
	for i: int in range(6):
		var z: float = 6.4 - i * 3.0
		_box("WallRib", Vector3(0.16, 2.8, 0.16), Vector3(-2.62, 1.4, z), Color("788075"))
		_box("RibFoot", Vector3(0.32, 0.22, 0.30), Vector3(-2.56, 0.11, z), DARK)
		_box("WallPanelInset", Vector3(0.055, 0.9, 1.5), Vector3(-2.64, 1.16, z - 1.25), Color("646f66"))
	var pipe: MeshInstance3D = _cylinder("MainCopperPipe", 0.11, 17.1, Vector3(-2.40, 2.55, -1.4), Color("97724c"))
	pipe.rotation_degrees.x = 90
	var cable: MeshInstance3D = _cylinder("CableConduit", 0.055, 17.1, Vector3(-2.40, 2.22, -1.4), DARK)
	cable.rotation_degrees.x = 90
	for z: float in [5.5, 0.0, -5.5, -9.0]:
		_box("PipeClamp", Vector3(0.3, 0.34, 0.09), Vector3(-2.4, 2.5, z), STEEL)
	# A bevel-like bright cap and dark plinth give the cutaway walls thickness.
	for layout: Vector3 in [Vector3(2.84, 0.7, 5.5), Vector3(2.84, 0.7, -8.5)]:
		_box("CutawayCap", Vector3(0.38, 0.045, 3.9), layout, Color("898b79"))
	_box("DormCutawayCap", Vector3(0.36, 0.045, 5.9), Vector3(6.82, 0.7, -4.85), Color("a2997b"))

func _fixture(pos: Vector3, warm: bool) -> void:
	_box("LampHousing", Vector3(0.18, 0.27, 0.85), pos, DARK)
	var lamp: MeshInstance3D = _box("LampDiffuser", Vector3(0.05, 0.12, 0.65), pos + Vector3(0.11, 0, 0), Color("f1d2a0") if warm else Color("dae1d3"))
	fixtures.append(lamp)

func _dress_generator() -> void:
	_box("GeneratorBase", Vector3(2.1, 0.13, 1.5), Vector3(0, 0.08, -8.25), DARK)
	for x: float in [-0.78, 0.78]:
		_box("MachineCorner", Vector3(0.09, 1.22, 0.09), Vector3(x, 0.76, -7.64), Color("b9ac7c"))
	for i: int in range(7):
		_box("CoolingGrille", Vector3(0.09, 0.64, 0.04), Vector3(-0.58 + i * 0.14, 0.82, -7.66), DARK)
	_box("ControlPanel", Vector3(0.48, 0.29, 0.07), Vector3(0.46, 1.27, -7.65), Color("384a43"))
	for x: float in [0.32, 0.46, 0.60]:
		var gauge: MeshInstance3D = _cylinder("Gauge", 0.048, 0.02, Vector3(x, 1.31, -7.599), PAPER)
		gauge.rotation_degrees.x = 90
		_box("GaugeNeedle", Vector3(0.012, 0.045, 0.012), Vector3(x, 1.32, -7.58), DARK)
	for x: float in [-1.80, -1.20]:
		_cylinder("ReserveCylinder", 0.23, 1.08, Vector3(x, 0.58, -9.62), Color("967147"))
		_cylinder("CylinderCollar", 0.25, 0.09, Vector3(x, 0.94, -9.62), DARK)
		_box("CylinderValve", Vector3(0.21, 0.06, 0.07), Vector3(x, 1.20, -9.62), Color("b5502a"))
	_box("BackVent", Vector3(1.70, 1.12, 0.12), Vector3(0.7, 2.0, -10.12), DARK)
	rotor = Node3D.new()
	rotor.name = "VentilationRotor"
	rotor.position = Vector3(0.7, 2.0, -10.01)
	add_child(rotor)
	for angle: float in [0, 60, 120]:
		var blade: MeshInstance3D = _box("FanBlade", Vector3(0.96, 0.16, 0.025), Vector3.ZERO, STEEL, rotor)
		blade.rotation_degrees.z = angle
	for i: int in range(6):
		_box("VentGuard", Vector3(1.5, 0.035, 0.05), Vector3(0.7, 1.55 + i * 0.18, -9.94), Color("8b8d78"))
	_sign("GeneratorSign", "ENERGIA  /  01", Vector3(-0.45, 2.98, -10.10), 38)
	for i: int in range(7):
		var stripe: MeshInstance3D = _box("SafetyStripe", Vector3(0.22, 0.015, 0.38), Vector3(-0.9 + i * 0.3, 0.016, -7.29), AMBER.darkened(0.2))
		stripe.rotation_degrees.y = -30
	_fixture(Vector3(-2.54, 2.10, -8.2), true)

func _dress_entry() -> void:
	_box("DoorFrame", Vector3(3.5, 2.75, 0.16), Vector3(0, 1.38, 7.31), DARK)
	for x: float in [-0.83, 0.83]:
		_box("EntranceDoor", Vector3(1.5, 2.40, 0.11), Vector3(x, 1.29, 7.17), Color("657065"))
		_box("DoorBrace", Vector3(1.36, 0.13, 0.08), Vector3(x, 0.80, 7.07), Color("92947c"))
		_box("DoorWindow", Vector3(0.52, 0.39, 0.045), Vector3(x, 1.84, 7.08), Color("283b37"))
	_box("Threshold", Vector3(3.4, 0.045, 0.45), Vector3(0, 0.025, 6.92), Color("9a895e"))
	# Front-facing sign for the established isometric camera.
	_sign("BunkerIdentity", "CZI—07", Vector3(-1.6, 2.7, 4.7), 45).rotation_degrees.y = 35
	_box("EntryLocker", Vector3(0.6, 1.7, 0.65), Vector3(-2.15, 0.85, 4.1), Color("747761"))
	for y: float in [0.6, 1.3]:
		_box("LockerHandle", Vector3(0.04, 0.20, 0.05), Vector3(-2.02, y, 4.45), PAPER.darkened(0.25))
	_fixture(Vector3(-2.54, 2.1, 5.4), true)

func _dress_corridor() -> void:
	_box("MaintenanceCabinet", Vector3(0.32, 1.0, 0.85), Vector3(-2.43, 1.30, 1.7), Color("747d6a"))
	_box("CabinetLatch", Vector3(0.05, 0.24, 0.08), Vector3(-2.23, 1.3, 1.98), AMBER)
	_box("WallCableTray", Vector3(0.25, 0.12, 8.2), Vector3(-2.38, 2.85, -0.55), DARK)
	for z: float in [-1.8, -0.6, 0.6]:
		_box("CableTrayBracket", Vector3(0.37, 0.05, 0.10), Vector3(-2.4, 2.77, z), STEEL)
	_fixture(Vector3(-2.54, 2.10, -1.7), false)
	_fixture(Vector3(-2.54, 2.10, -5.4), false)
	_sign("DormitoryWayfinding", "02  /  REPOUSO  ›", Vector3(1.45, 2.6, -3.9), 28)
	# Recessed workbench detail behind the existing communication interaction point.
	_box("CommsBackplate", Vector3(0.08, 0.83, 0.85), Vector3(-2.55, 1.35, -0.4), Color("424d47"))
	for z: float in [-0.68, -0.42, -0.16]:
		_box("Connector", Vector3(0.055, 0.16, 0.12), Vector3(-2.47, 1.35, z), Color("ae9c6e"))
	_box("NoticeBoard", Vector3(0.05, 0.74, 0.8), Vector3(-2.58, 1.65, -4.3), Color("89734d"))
	for z: float in [-4.53, -4.23]:
		_box("PaperNote", Vector3(0.02, 0.43, 0.23), Vector3(-2.53, 1.67, z), PAPER.darkened(0.1))

func _dress_dormitory() -> void:
	var positions: Array[Vector3] = [Vector3(3.55, 0, -2.75), Vector3(5.75, 0, -2.75), Vector3(3.55, 0, -6.65), Vector3(5.75, 0, -6.65)]
	var blankets: Array[Color] = [Color("73826a"), Color("aa855b"), Color("807e63"), Color("8b6f57")]
	for i: int in range(4):
		var p: Vector3 = positions[i]
		_box("BedBlanket", Vector3(0.85, 0.085, 0.69), p + Vector3(0.18, 0.40, 0), blankets[i])
		_box("BlanketHem", Vector3(0.08, 0.095, 0.7), p + Vector3(-0.18, 0.405, 0), blankets[i].lightened(0.2))
		_box("Pillow", Vector3(0.30, 0.13, 0.52), p + Vector3(-0.47, 0.425, 0), PAPER)
		for x: float in [-0.7, 0.7]:
			_box("BedEndFrame", Vector3(0.045, 0.55, 0.83), p + Vector3(x, 0.32, 0), Color("454e45"))
		_box("UnderBedBag", Vector3(0.37, 0.19, 0.42), p + Vector3(0.22, 0.16, 0.44), Color("5c5844"))
		_box("BagStrap", Vector3(0.055, 0.20, 0.45), p + Vector3(0.22, 0.17, 0.44), Color("a08d64"))
	# Personal objects stay at the walls, outside the original passage and routine paths.
	_box("DormLocker", Vector3(1.1, 1.3, 0.38), Vector3(5.3, 0.65, -7.5), Color("858269"))
	for x: float in [5.08, 5.57]:
		_box("LockerDoor", Vector3(0.015, 0.85, 0.02), Vector3(x, 0.82, -7.3), DARK)
	_box("FoldedTowel", Vector3(0.40, 0.13, 0.32), Vector3(5.15, 1.38, -7.48), Color("cdbb99"))
	_box("SideShelf", Vector3(0.65, 0.08, 0.30), Vector3(6.35, 0.7, -5.9), Color("937950"))
	_cylinder("Mug", 0.08, 0.14, Vector3(6.4, 0.82, -5.92), Color("beb49a"))
	_cylinder("Thermos", 0.09, 0.31, Vector3(6.15, 0.9, -5.92), Color("676c55"))
	_box("FloorBlanket", Vector3(1.15, 0.045, 0.62), Vector3(4.72, 0.115, -4.72), Color("9f774e"))
	_box("FloorPillow", Vector3(0.27, 0.1, 0.47), Vector3(4.03, 0.13, -4.72), Color("c2ae87"))
	_box("DormLampShelf", Vector3(0.45, 0.06, 0.30), Vector3(3.2, 1.65, -7.54), STEEL)
	var lamp: MeshInstance3D = _cylinder("DormLantern", 0.11, 0.30, Vector3(3.2, 1.83, -7.54), Color("eed4a0"))
	fixtures.append(lamp)
	_sign("DormWallSign", "REPOUSO", Vector3(4.7, 2.25, -7.66), 34)

func _process(delta: float) -> void:
	var power: bool = bool(bunker.get("power_complete")) if bunker != null else false
	if power and rotor != null:
		rotor.rotation.z += delta * 1.1
	if power != cached_power:
		cached_power = power
		for lamp: MeshInstance3D in fixtures:
			var mat: StandardMaterial3D = lamp.mesh.surface_get_material(0) as StandardMaterial3D
			mat.emission_enabled = power
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 0.65
