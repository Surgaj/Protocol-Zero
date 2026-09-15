extends Control

# PROTOCOL ZERO — controle virtual de greybox.
# Visual circular simples para evitar o quadrado/artefato do primeiro teste mobile.

@export var max_radius: float = 62.0
@export var input_deadzone: float = 0.12

var _touch_id: int = -1
var _mouse_active: bool = false
var _center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = size * 0.5
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center = size * 0.5
		_knob_offset = Vector2.ZERO
		queue_redraw()

func _draw() -> void:
	var outer_radius := max_radius + 18.0
	draw_circle(_center, outer_radius, Color(0.08, 0.08, 0.08, 0.24))
	draw_arc(_center, outer_radius, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 2.0)
	draw_circle(_center + _knob_offset, 27.0, Color(0.82, 0.82, 0.82, 0.62))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_id == -1 and get_global_rect().has_point(touch.position):
			_touch_id = touch.index
			_update_from_global(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_id:
			_touch_id = -1
			_set_vector(Vector2.ZERO)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_id:
			_update_from_global(drag.position)
			get_viewport().set_input_as_handled()
		return

	# Mouse também controla o pad para teste desktop da build Web.
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed and get_global_rect().has_point(mouse_button.position):
				_mouse_active = true
				_update_from_global(mouse_button.position)
				get_viewport().set_input_as_handled()
			elif not mouse_button.pressed and _mouse_active:
				_mouse_active = false
				_set_vector(Vector2.ZERO)
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _mouse_active:
		var motion := event as InputEventMouseMotion
		_update_from_global(motion.position)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_release_actions()

func _update_from_global(global_pos: Vector2) -> void:
	var local_pos := global_pos - global_position
	var offset := local_pos - _center
	if offset.length() > max_radius:
		offset = offset.normalized() * max_radius
	var vector := offset / max_radius
	_set_vector(vector)

func _set_vector(vector: Vector2) -> void:
	_release_actions()

	if vector.length() < input_deadzone:
		vector = Vector2.ZERO

	if vector.x < 0.0:
		Input.action_press("move_left", abs(vector.x))
	elif vector.x > 0.0:
		Input.action_press("move_right", vector.x)

	if vector.y < 0.0:
		Input.action_press("move_forward", abs(vector.y))
	elif vector.y > 0.0:
		Input.action_press("move_back", vector.y)

	_knob_offset = vector * max_radius
	queue_redraw()

func _release_actions() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_back")
