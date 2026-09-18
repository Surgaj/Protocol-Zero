extends Node3D

# Lightweight mesh characters. Cosmetic only: never owns movement or game state.
const OUTFITS: Dictionary = {"elias": "405452", "maya": "bf833d", "iris": "d9cfb7", "dante": "955138", "noah": "737465"}
const SKINS: Dictionary = {"elias": "bd8a69", "maya": "a76e50", "iris": "d6ab87", "dante": "b88a67", "noah": "c1a087"}
var citizen_id: String = "elias"
var model: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var previous_position: Vector3
var stride: float = 0.0
var clock: float = 0.0
var walking: float = 0.0
var activity: String = ""

static func attach(actor: Node3D, id: String) -> void:
	if actor.has_node("CitizenVisual"):
		return
	for child: Node in actor.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	var visual := Node3D.new()
	visual.name = "CitizenVisual"
	visual.set_script(load("res://scripts/visual/citizen_visual.gd"))
	visual.set("citizen_id", id)
	actor.add_child(visual)

func _ready() -> void:
	position.y = -0.90
	previous_position = get_parent().global_position
	model = Node3D.new()
	model.name = "Body"
	add_child(model)
	_build_person()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	return material

func _box(parent: Node3D, name_: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	return _mesh(parent, name_, mesh, pos)

func _round(parent: Node3D, name_: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = _material(color)
	return _mesh(parent, name_, mesh, pos)

func _mesh(parent: Node3D, name_: String, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = name_
	item.mesh = mesh
	item.position = pos
	parent.add_child(item)
	return item

func _limb(name_: String, pos: Vector3, width: float, length_: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name_
	pivot.position = pos
	model.add_child(pivot)
	_box(pivot, "Clothing", Vector3(width, length_, width), Vector3(0, -length_ * 0.5, 0), color)
	return pivot

func _build_person() -> void:
	var cloth := Color(String(OUTFITS[citizen_id]))
	var skin := Color(String(SKINS[citizen_id]))
	var dark := Color("303333")
	var hair := Color("302a25")
	var width: float = 0.57 if citizen_id == "dante" else 0.45
	_box(model, "Jacket", Vector3(width, 0.60, 0.32), Vector3(0, 1.08, 0), cloth)
	_round(model, "Shoulders", width * 0.58, 0.24, Vector3(0, 1.32, 0), cloth)
	_box(model, "Collar", Vector3(0.25, 0.10, 0.28), Vector3(0, 1.39, 0), dark)
	_box(model, "Zipper", Vector3(0.025, 0.45, 0.025), Vector3(0, 1.10, 0.172), Color("ddd4ba"))
	_box(model, "Belt", Vector3(width + 0.03, 0.085, 0.35), Vector3(0, 0.79, 0), dark)
	_round(model, "Head", 0.235, 0.48, Vector3(0, 1.65, 0.02), skin)
	_round(model, "Hair", 0.243, 0.24, Vector3(0, 1.84, -0.015), hair)
	_round(model, "Nose", 0.05, 0.09, Vector3(0, 1.63, 0.25), skin)
	for x: float in [-0.083, 0.083]:
		_box(model, "Eye", Vector3(0.04, 0.036, 0.035), Vector3(x, 1.71, 0.225), Color("252727"))
	left_leg = _limb("LeftLeg", Vector3(-0.135, 0.76, 0), 0.18, 0.55, dark)
	right_leg = _limb("RightLeg", Vector3(0.135, 0.76, 0), 0.18, 0.55, dark)
	for leg: Node3D in [left_leg, right_leg]:
		_box(leg, "Boot", Vector3(0.22, 0.17, 0.34), Vector3(0, -0.62, 0.065), Color("39332c"))
		_box(leg, "Sole", Vector3(0.23, 0.045, 0.35), Vector3(0, -0.715, 0.065), Color("202524"))
	left_arm = _limb("LeftArm", Vector3(-width * 0.64, 1.30, 0), 0.15, 0.43, cloth)
	right_arm = _limb("RightArm", Vector3(width * 0.64, 1.30, 0), 0.15, 0.43, cloth)
	for arm: Node3D in [left_arm, right_arm]:
		_round(arm, "Hand", 0.085, 0.16, Vector3(0, -0.48, 0), skin)
	_box(model, "Backpack", Vector3(0.33, 0.43, 0.18), Vector3(0, 1.07, -0.25), cloth.darkened(0.25))
	match citizen_id:
		"elias":
			_box(model, "TealShoulderPatch", Vector3(0.12, 0.14, 0.025), Vector3(-0.12, 1.23, 0.18), Color("5fd1c0"))
			_box(model, "Radio", Vector3(0.11, 0.19, 0.08), Vector3(0.15, 1.18, 0.21), dark)
			_box(model, "RadioAntenna", Vector3(0.024, 0.16, 0.024), Vector3(0.18, 1.34, 0.21), dark)
			_round(model, "Headset", 0.065, 0.14, Vector3(0.225, 1.69, 0), dark)
		"maya":
			_box(model, "WorkApron", Vector3(0.32, 0.40, 0.035), Vector3(0, 1.02, 0.18), Color("6c5841"))
			_box(model, "GoggleStrap", Vector3(0.46, 0.06, 0.12), Vector3(0, 1.84, 0.13), dark)
			for x: float in [-0.10, 0.10]:
				_round(model, "Goggle", 0.078, 0.12, Vector3(x, 1.84, 0.205), Color("929d97"))
			_box(right_arm, "WrenchHandle", Vector3(0.045, 0.30, 0.045), Vector3(0, -0.57, 0.1), Color("b8b8a9"))
			_box(right_arm, "WrenchHead", Vector3(0.15, 0.065, 0.06), Vector3(0, -0.74, 0.1), Color("b8b8a9"))
		"iris":
			_round(model, "HairBun", 0.145, 0.27, Vector3(0, 1.87, -0.18), hair)
			_box(model, "MedicalBag", Vector3(0.21, 0.27, 0.23), Vector3(-0.31, 0.79, 0.015), Color("73765d"))
			_box(model, "BagPatch", Vector3(0.11, 0.1, 0.018), Vector3(-0.31, 0.8, 0.14), Color("e9e2d2"))
			_box(model, "Scarf", Vector3(0.28, 0.13, 0.34), Vector3(0, 1.37, 0.02), Color("9f8262"))
		"dante":
			_round(model, "Beard", 0.21, 0.20, Vector3(0, 1.51, 0.035), Color("494037"))
			_box(model, "FieldVest", Vector3(0.47, 0.43, 0.045), Vector3(0, 1.07, 0.18), Color("655d41"))
			for x: float in [-0.15, 0.15]:
				_box(model, "VestPocket", Vector3(0.15, 0.17, 0.085), Vector3(x, 1.05, 0.23), Color("847757"))
		"noah":
			_box(model, "Hood", Vector3(0.38, 0.16, 0.27), Vector3(0, 1.4, -0.14), cloth.darkened(0.2))
			_box(left_arm, "Receiver", Vector3(0.18, 0.24, 0.075), Vector3(0.01, -0.40, 0.13), dark)
			_box(left_arm, "ReceiverScreen", Vector3(0.12, 0.10, 0.012), Vector3(0.01, -0.36, 0.175), Color("c4b57c"))
			model.rotation.x = 0.04
	# Low cost contact shadow, no extra shadow-casting lights.
	var shadow := CylinderMesh.new()
	shadow.top_radius = 0.36
	shadow.bottom_radius = 0.36
	shadow.height = 0.008
	shadow.radial_segments = 16
	var shadow_material := _material(Color(0.025, 0.025, 0.018, 0.28))
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material = shadow_material
	var contact: MeshInstance3D = _mesh(self, "ContactShadow", shadow, Vector3(0, 0.025, 0))
	contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	clock += delta
	var actor: Node3D = get_parent() as Node3D
	var displacement: Vector3 = actor.global_position - previous_position
	previous_position = actor.global_position
	displacement.y = 0
	var speed: float = displacement.length() / maxf(delta, 0.001)
	walking = lerpf(walking, minf(speed / 2.5, 1.0), minf(delta * 12, 1))
	stride += delta * (4.0 + walking * 7.0)
	if speed > 0.08 and not actor is CharacterBody3D:
		rotation.y = lerp_angle(rotation.y, atan2(displacement.x, displacement.z), minf(delta * 9, 1))
	left_leg.rotation.x = sin(stride) * 0.45 * walking
	right_leg.rotation.x = -left_leg.rotation.x
	left_arm.rotation.x = -sin(stride) * 0.32 * walking
	right_arm.rotation.x = sin(stride) * 0.32 * walking
	model.position.y = absf(sin(stride)) * 0.032 * walking + sin(clock * 1.8) * 0.006
	if walking < 0.05 and not activity.is_empty() and activity != "rest":
		right_arm.rotation.x = -0.65 + sin(clock * 2.5) * 0.10
		left_arm.rotation.x = -0.3
