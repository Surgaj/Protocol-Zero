extends Camera3D

# PROTOCOL ZERO — Greybox isometric camera follow
# A câmera mantém rotação fixa e acompanha apenas posição.

@export var follow_speed: float = 6.0
@export var camera_offset: Vector3 = Vector3(14.5, 17.5, 18.5)
@export var follow_min: Vector2 = Vector2(-1.4, -5.2)
@export var follow_max: Vector2 = Vector2(1.4, 5.2)

var target: Node3D

func set_target(node: Node3D) -> void:
	target = node
	_snap_to_target()

func _process(delta: float) -> void:
	if target == null:
		return

	var desired := _desired_position()
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired, weight)

func _snap_to_target() -> void:
	if target == null:
		return
	global_position = _desired_position()

func _desired_position() -> Vector3:
	var anchor := target.global_position
	anchor.x = clamp(anchor.x, follow_min.x, follow_max.x)
	anchor.z = clamp(anchor.z, follow_min.y, follow_max.y)
	return anchor + camera_offset
