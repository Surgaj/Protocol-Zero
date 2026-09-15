extends CharacterBody3D

# PROTOCOL ZERO — Vertical Slice greybox player
# Regra: nenhuma arte final antes das quatro cenas funcionarem ponta a ponta.

@export var move_speed: float = 4.5
@export var turn_speed: float = 10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var movement_camera: Camera3D

func set_movement_camera(camera: Camera3D) -> void:
	movement_camera = camera

func _physics_process(delta: float) -> void:
	var input_vec := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var direction := _camera_relative(input_vec)

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	if direction.length_squared() > 0.01:
		var target_yaw := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(
			rotation.y,
			target_yaw,
			min(1.0, turn_speed * delta)
		)

	move_and_slide()

func _camera_relative(input_vec: Vector2) -> Vector3:
	# Input.get_vector retorna Y negativo para move_forward.
	# Por isso usamos -input_vec.y para caminhar na direção frontal da câmera.
	if movement_camera == null:
		return Vector3(input_vec.x, 0.0, -input_vec.y).normalized()

	var cam_forward := -movement_camera.global_transform.basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()

	var cam_right := movement_camera.global_transform.basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()

	return (
		cam_right * input_vec.x
		+ cam_forward * -input_vec.y
	).normalized()
