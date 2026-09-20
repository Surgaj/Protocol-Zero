extends Camera3D

# PROTOCOL ZERO — Greybox isometric camera follow
# A câmera mantém rotação fixa e acompanha apenas posição.

@export var follow_speed: float = 6.0
@export var camera_offset: Vector3 = Vector3(8.5, 6.0, 10.0)
@export var follow_min: Vector2 = Vector2(-0.65, -2.8)
@export var follow_max: Vector2 = Vector2(0.65, 2.8)

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


var zoom_enabled: bool = false
var zoom_touches: Dictionary = {}
var pinch_distance: float = 0.0
const MIN_ZOOM: float = 7.0
const MAX_ZOOM: float = 20.0

func apply_zoom(factor: float) -> void:
	if zoom_enabled:
		size = clampf(size * factor, MIN_ZOOM, MAX_ZOOM)

func _input(event: InputEvent) -> void:
	if not zoom_enabled:
		zoom_touches.clear()
		pinch_distance = 0
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch.position.y > 220 and touch.position.y < get_viewport().get_visible_rect().size.y - 240:
			zoom_touches[touch.index] = touch.position
		elif not touch.pressed:
			zoom_touches.erase(touch.index)
		pinch_distance = 0
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if zoom_touches.has(drag.index):
			zoom_touches[drag.index] = drag.position
			if zoom_touches.size() == 2:
				var points: Array = zoom_touches.values()
				var distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
				if pinch_distance > 1 and distance > 1:
					apply_zoom(pinch_distance / distance)
				pinch_distance = distance
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			apply_zoom(0.90)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			apply_zoom(1.10)
