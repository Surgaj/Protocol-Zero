extends CharacterBody3D

# PROTOCOL ZERO — Maya greybox behavior.
# Cena 3 lê somente relação/memória via GameState. Nunca lê a escolha bruta da Cena 2.

@export var move_speed: float = 2.6

var follow_distance: float = 1.6
var waits_at_doors: bool = false
var takes_initiative: bool = false

var _player: CharacterBody3D
var _door_wait_point: Vector3 = Vector3(0, 0.90, -5.0)
var _panel_point: Vector3 = Vector3(-1.65, 0.90, -5.15)

func configure(player_ref: CharacterBody3D, door_wait_point: Vector3, panel_point: Vector3) -> void:
	_player = player_ref
	_door_wait_point = door_wait_point
	_panel_point = panel_point
	_apply_social_state()

func _apply_social_state() -> void:
	var behavior: Dictionary = GameState.get_maya_behavior()
	follow_distance = float(behavior["follow_distance"])
	waits_at_doors = bool(behavior["waits_at_doors"])
	takes_initiative = bool(behavior["takes_initiative"])

func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		velocity = Vector3.ZERO
		return

	var target: Vector3 = _movement_target()
	var flat_delta: Vector3 = target - global_position
	flat_delta.y = 0.0
	var distance: float = flat_delta.length()

	if distance < 0.08:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var direction: Vector3 = flat_delta / distance
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y = -0.1
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.18)
	move_and_slide()

func _movement_target() -> Vector3:
	if takes_initiative:
		# Maya tensa não espera Elias: vai direto ao painel técnico.
		return _panel_point

	var target: Vector3 = _player.global_position + Vector3(-0.90, 0.0, -follow_distance)
	target.y = 0.90

	if waits_at_doors:
		# Maya cooperativa chega à porta, mas não a atravessa sem Elias.
		if target.z < _door_wait_point.z:
			target.z = _door_wait_point.z
		if global_position.z <= _door_wait_point.z + 0.20 and _player.global_position.z > _door_wait_point.z + 1.60:
			return _door_wait_point

	return target
