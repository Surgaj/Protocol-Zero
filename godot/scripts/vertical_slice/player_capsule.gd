extends CharacterBody3D

# PROTOCOL ZERO — Vertical Slice greybox player
# Regra: nenhuma arte final antes das quatro cenas funcionarem ponta a ponta.

@export var move_speed: float = 4.5
@export var turn_speed: float = 10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	var input_vec := Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vec.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vec.y += 1.0

	input_vec = input_vec.normalized()
	var direction := Vector3(input_vec.x, 0.0, input_vec.y)

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	if direction.length_squared() > 0.01:
		var target_yaw := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, min(1.0, turn_speed * delta))

	move_and_slide()
