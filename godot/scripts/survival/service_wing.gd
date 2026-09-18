extends Node3D

# Two physical extensions of CZI-07. Doors own actual collision, not a scene switch.
const POINTS: Dictionary = {
	"area:services": Vector3(2.8, 0.9, 1.2),
	"area:pantry": Vector3(8.45, 0.9, 1.2),
	"object:reservoir": Vector3(4.2, 0.9, -0.1),
	"object:kitchen": Vector3(6.6, 0.9, -0.1),
	"object:table": Vector3(6.0, 0.9, 2.1),
	"object:power": Vector3(0, 0.9, -8.25),
	"rest": Vector3(4.65, 0.9, -4.72),
}
var bunker: Node3D
var gates: Dictionary = {}
var rooms: Dictionary = {}
var tank_level: MeshInstance3D
var food_crates: Array[MeshInstance3D] = []
var portions: Array[MeshInstance3D] = []
var service_light: OmniLight3D
var pantry_light: OmniLight3D
var back_walls: Array[MeshInstance3D] = []
var hint: Label3D
var steam: MeshInstance3D
var shown_water: int = -1
var shown_food: int = -1
var shown_meals: int = -1

func _ready() -> void:
	bunker = get_parent() as Node3D
	_build()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat

func box(parent: Node3D, name_: String, size: Vector3, pos: Vector3, color: Color, solid: bool = false) -> Node3D:
	var visual := MeshInstance3D.new()
	visual.name = name_
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	visual.mesh = mesh
	if not solid:
		visual.position = pos
		parent.add_child(visual)
		return visual
	var body := StaticBody3D.new()
	body.name = name_
	body.position = pos
	parent.add_child(body)
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body

func cylinder(parent: Node3D, name_: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = name_
	visual.position = pos
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.material = _material(color)
	visual.mesh = mesh
	parent.add_child(visual)
	return visual

func sign_(parent: Node3D, copy: String, pos: Vector3, size_: int = 34) -> Label3D:
	var sign_node := Label3D.new()
	sign_node.text = copy
	sign_node.font_size = size_
	sign_node.pixel_size = 0.008
	sign_node.position = pos
	sign_node.modulate = Color("e9e2d2")
	sign_node.outline_modulate = Color("253b35")
	parent.add_child(sign_node)
	return sign_node

func _build_room(id: String, center_x: float, width: float) -> Node3D:
	var room := Node3D.new()
	room.name = id.capitalize()
	add_child(room)
	rooms[id] = room
	box(room, "Floor", Vector3(width, 0.3, 4.4), Vector3(center_x, -0.15, 1.15), Color("766e57"), true)
	var back: Node3D = box(room, "BackWall", Vector3(width, 2.65, 0.2), Vector3(center_x, 1.325, -1.05), Color("667064"), true)
	back_walls.append(back.get_child(0) as MeshInstance3D)
	box(room, "FrontCutaway", Vector3(width, 0.55, 0.2), Vector3(center_x, 0.275, 3.35), Color("444f46"), true)
	return room

func _door(id: String, x: float) -> void:
	var gate: Node3D = box(self, id.capitalize() + "Gate", Vector3(0.20, 2.3, 1.6), Vector3(x, 1.15, 1.2), Color("716d53"), true)
	gates[id] = gate
	box(self, "DoorPost", Vector3(0.28, 2.65, 0.14), Vector3(x, 1.325, 0.37), Color("a69c78"), true)
	box(self, "DoorPost", Vector3(0.28, 2.65, 0.14), Vector3(x, 1.325, 2.03), Color("a69c78"), true)
	var label := Label3D.new()
	label.name = "DoorLabel"
	label.text = "SERVIÇOS\n2 PEÇAS" if id == "services" else "DEPÓSITO\n2 PEÇAS"
	label.font_size = 32
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(x, 2.6, 1.2)
	add_child(label)

func _build() -> void:
	var service: Node3D = _build_room("services", 5.65, 5.6)
	var pantry: Node3D = _build_room("pantry", 10.25, 3.6)
	_door("services", 2.84)
	_door("pantry", 8.45)
	for z: float in [-0.32, 2.72]:
		box(service, "PantryPartition", Vector3(0.18, 0.7, 1.25), Vector3(8.45, 0.35, z), Color("616753"), true)
	box(pantry, "EastCutaway", Vector3(0.2, 0.7, 4.4), Vector3(12.05, 0.35, 1.15), Color("616753"), true)
	# Tank frame exposes an actual rising/falling blue water column.
	box(service, "TankBase", Vector3(0.9, 0.2, 0.75), Vector3(4.15, 0.1, -0.2), Color("3c514a"), true)
	for x: float in [3.72, 4.58]:
		box(service, "TankFrame", Vector3(0.07, 1.6, 0.75), Vector3(x, 0.95, -0.2), Color("97a28b"))
	box(service, "TankTop", Vector3(0.93, 0.12, 0.78), Vector3(4.15, 1.8, -0.2), Color("97a28b"))
	tank_level = box(service, "WaterLevel", Vector3(0.74, 1.45, 0.62), Vector3(4.15, 0.94, -0.2), Color("5385a0")) as MeshInstance3D
	cylinder(service, "Pump", 0.19, 0.5, Vector3(3.35, 0.25, -0.25), Color("b18d52"))
	box(service, "PumpPipe", Vector3(0.08, 0.1, 0.8), Vector3(3.65, 0.45, -0.25), Color("a28b61"))
	sign_(service, "ÁGUA", Vector3(4.1, 2.1, -0.8))
	box(service, "KitchenBench", Vector3(1.5, 0.80, 0.8), Vector3(6.55, 0.4, -0.25), Color("8b8165"), true)
	box(service, "Worktop", Vector3(1.6, 0.09, 0.9), Vector3(6.55, 0.86, -0.25), Color("c3b99c"))
	cylinder(service, "StoveRing", 0.3, 0.07, Vector3(6.35, 0.94, -0.25), Color("343c35"))
	cylinder(service, "CookingPot", 0.25, 0.32, Vector3(6.35, 1.13, -0.25), Color("777d68"))
	steam = cylinder(service, "Steam", 0.09, 0.28, Vector3(6.35, 1.46, -0.25), Color("d5d3bc"))
	steam.visible = false
	box(service, "ChoppingBoard", Vector3(0.4, 0.04, 0.5), Vector3(7.0, 0.95, -0.3), Color("ba915f"))
	sign_(service, "COZINHA", Vector3(6.55, 2.1, -0.8))
	box(service, "CommunalTable", Vector3(1.95, 0.1, 0.75), Vector3(6, 0.8, 2.3), Color("a28c61"), true)
	for x: float in [5.2, 6.8]:
		box(service, "TableLeg", Vector3(0.10, 0.75, 0.55), Vector3(x, 0.38, 2.3), Color("535a48"), true)
	for z: float in [1.72, 2.94]:
		box(service, "Bench", Vector3(1.9, 0.12, 0.24), Vector3(6, 0.40, z), Color("87754f"))
	for i: int in range(5):
		var x: float = 5.24 + i * 0.38
		cylinder(service, "Plate", 0.15, 0.03, Vector3(x, 0.87, 2.3), Color("d8caa5"))
		portions.append(cylinder(service, "Serving", 0.1, 0.05, Vector3(x, 0.91, 2.3), Color("c99046")))
	for i: int in range(6):
		var crate: MeshInstance3D = box(pantry, "FoodCrate", Vector3(0.65, 0.48, 0.65), Vector3(9.35 + (i % 3) * 0.85, 0.25 + (i / 3) * 0.50, -0.3), Color("aa8955")) as MeshInstance3D
		food_crates.append(crate)
	box(pantry, "StorageShelf", Vector3(2.75, 0.08, 0.8), Vector3(10.2, 0.03, -0.3), Color("4d594b"))
	sign_(pantry, "MANTIMENTOS", Vector3(10.2, 1.9, -0.85))
	hint = sign_(service, "", Vector3(5.9, 2.6, -0.75), 27)
	service_light = _light(Vector3(5.65, 2.45, 1.0), Color("e6d2a7"))
	pantry_light = _light(Vector3(10.2, 2.45, 1.0), Color("d1d7b7"))
	sync_state()

func _light(pos: Vector3, color: Color) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = 0.0
	lamp.omni_range = 5.8
	lamp.shadow_enabled = false
	add_child(lamp)
	return lamp

func sync_state() -> void:
	var life = GameState.survival
	for id: String in gates:
		var gate: StaticBody3D = gates[id] as StaticBody3D
		var unlocked: bool = bool(life.areas[id])
		gate.visible = not unlocked
		gate.collision_layer = 0 if unlocked else 1
	service_light.light_energy = 3.4 if life.areas["services"] and life.powered else 0.0
	pantry_light.light_energy = 3.0 if life.areas["pantry"] and life.powered else 0.0
	var ratio: float = float(life.water) / float(life.WATER_CAPACITY)
	tank_level.visible = ratio > 0
	tank_level.scale.y = maxf(ratio, 0.01)
	tank_level.position.y = 0.22 + 0.725 * ratio
	shown_water = life.water
	shown_food = life.food
	shown_meals = life.meals
	for i: int in range(food_crates.size()):
		food_crates[i].visible = not life.areas["pantry"] or life.food > i * 5
	for i: int in range(portions.size()):
		portions[i].visible = life.meals > i
	hint.text = "" if not life.active else "Água %d  •  Mantimentos %d  •  Porções %d" % [life.water, life.food, life.meals]
	if life.areas["services"]:
		var camera: Camera3D = bunker.get("gameplay_camera") as Camera3D
		camera.set("follow_max", Vector2(11.0 if life.areas["pantry"] else 7.2, 5.0))

func _process(_delta: float) -> void:
	var player: Node3D = bunker.get("player") as Node3D
	var behind: bool = player != null and player.position.z < -1.0
	for wall: MeshInstance3D in back_walls:
		wall.scale.y = 0.22 if behind else 1.0
		wall.position.y = -1.0335 if behind else 0.0

func closest_action(pos: Vector3) -> String:
	var found: String = ""
	var best: float = 1.8
	for source: String in POINTS:
		if source == "rest":
			if GameState.day_phase != 5 or (GameState.day == 1 and not GameState.cough_resolved):
				continue
		elif not GameState.survival.active:
			continue
		elif source == "area:services" and GameState.survival.areas["services"]:
			continue
		elif source == "area:pantry" and (not GameState.survival.areas["services"] or GameState.survival.areas["pantry"]):
			continue
		elif source in ["object:reservoir", "object:kitchen", "object:table"] and not GameState.survival.areas["services"]:
			continue
		var target: Vector3 = POINTS[source] as Vector3
		var distance: float = Vector2(pos.x - target.x, pos.z - target.z).length()
		if distance < best:
			best = distance
			found = source
	return found

func action_text(source: String) -> String:
	match source:
		"rest": return "DESCANSAR\nATÉ AMANHÃ"
		"area:services": return "ABRIR SERVIÇOS\n2 PEÇAS (%d)" % GameState.survival.parts
		"area:pantry": return "ABRIR DEPÓSITO\n2 PEÇAS (%d)" % GameState.survival.parts
		"object:reservoir": return "CONFERIR ÁGUA\n%d / 20" % GameState.survival.water
		"object:kitchen": return "VERIFICAR\nCOZINHA"
		"object:table": return "CONFERIR\nREFEIÇÃO"
		"object:power": return "DESLIGAR\nENERGIA" if GameState.survival.powered else "LIGAR\nENERGIA"
	return ""
