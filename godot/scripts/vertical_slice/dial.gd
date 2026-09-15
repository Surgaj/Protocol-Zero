extends Control

# PROTOCOL ZERO — UI touch do sintonizador.
# Sem indicar visualmente a frequência-alvo: o jogador descobre pelo áudio e pelo feedback de sinal.

signal frequency_changed(value: float)

var min_frequency: float = 120.0
var max_frequency: float = 180.0
var current_frequency: float = 126.0
var proximity: float = 0.0
var lock_progress: float = 0.0
var locked: bool = false

var _touch_id: int = -1
var _mouse_active: bool = false
var _frequency_label: Label
var _status_label: Label
var _progress_bar: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_labels()
	queue_redraw()

func setup(min_value: float, max_value: float, start_value: float) -> void:
	min_frequency = min_value
	max_frequency = max_value
	current_frequency = clamp(start_value, min_frequency, max_frequency)
	locked = false
	lock_progress = 0.0
	_update_labels()
	queue_redraw()

func set_feedback(value: float, new_proximity: float, in_lock_zone: bool, new_lock_progress: float) -> void:
	current_frequency = clamp(value, min_frequency, max_frequency)
	proximity = clamp(new_proximity, 0.0, 1.0)
	lock_progress = clamp(new_lock_progress, 0.0, 1.0)

	if _status_label != null:
		if locked:
			_status_label.text = "SINAL TRAVADO"
		elif in_lock_zone:
			_status_label.text = "MANTENHA..."
		elif proximity > 0.72:
			_status_label.text = "SINAL FORTE"
		elif proximity > 0.36:
			_status_label.text = "SINAL FRACO"
		else:
			_status_label.text = "ESTÁTICA"

	if _progress_bar != null:
		_progress_bar.scale.x = max(0.001, lock_progress)

	_update_labels()
	queue_redraw()

func set_locked() -> void:
	locked = true
	lock_progress = 1.0
	if _status_label != null:
		_status_label.text = "SINAL TRAVADO"
	if _progress_bar != null:
		_progress_bar.scale.x = 1.0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if locked:
		return

	# Em _gui_input, position já chega no espaço local do Control.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_id == -1:
			_touch_id = touch.index
			_update_from_local_x(touch.position.x)
			accept_event()
		elif not touch.pressed and touch.index == _touch_id:
			_touch_id = -1
			accept_event()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_id:
			_update_from_local_x(drag.position.x)
			accept_event()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_mouse_active = mouse_button.pressed
			if _mouse_active:
				_update_from_local_x(mouse_button.position.x)
			accept_event()
		return

	if event is InputEventMouseMotion and _mouse_active:
		var motion := event as InputEventMouseMotion
		_update_from_local_x(motion.position.x)
		accept_event()

func _update_from_local_x(local_x: float) -> void:
	var track_left := 44.0
	var track_right := max(track_left + 1.0, size.x - 44.0)
	var ratio := clamp((local_x - track_left) / (track_right - track_left), 0.0, 1.0)
	current_frequency = lerp(min_frequency, max_frequency, ratio)
	frequency_changed.emit(current_frequency)
	_update_labels()
	queue_redraw()

func _draw() -> void:
	var bg := Rect2(Vector2.ZERO, size)
	draw_rect(bg, Color(0.035, 0.035, 0.035, 0.96))
	draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, 4)), Color(0.70, 0.58, 0.32, 0.95))

	var track_left := 44.0
	var track_right := max(track_left + 1.0, size.x - 44.0)
	var track_y := size.y * 0.58

	draw_line(Vector2(track_left, track_y), Vector2(track_right, track_y), Color(0.38, 0.38, 0.38), 5.0)

	for i in range(13):
		var t := float(i) / 12.0
		var x := lerp(track_left, track_right, t)
		var h := 18.0 if i % 3 == 0 else 10.0
		draw_line(Vector2(x, track_y - h * 0.5), Vector2(x, track_y + h * 0.5), Color(0.62, 0.62, 0.62), 2.0)

	var value_ratio := inverse_lerp(min_frequency, max_frequency, current_frequency)
	var knob_x := lerp(track_left, track_right, value_ratio)
	var glow_radius := 22.0 + proximity * 10.0
	draw_circle(Vector2(knob_x, track_y), glow_radius, Color(0.78, 0.68, 0.42, 0.10 + proximity * 0.14))
	draw_circle(Vector2(knob_x, track_y), 12.0, Color(0.84, 0.84, 0.82))

func _build_labels() -> void:
	var title := Label.new()
	title.text = "SINTONIZADOR"
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	_frequency_label = Label.new()
	_frequency_label.position = Vector2(28, 58)
	_frequency_label.add_theme_font_size_override("font_size", 26)
	add_child(_frequency_label)

	_status_label = Label.new()
	_status_label.position = Vector2(28, 102)
	_status_label.add_theme_font_size_override("font_size", 16)
	add_child(_status_label)

	var progress_bg := ColorRect.new()
	progress_bg.position = Vector2(28, size.y - 38)
	progress_bg.size = Vector2(max(1.0, size.x - 56.0), 8)
	progress_bg.color = Color(0.16, 0.16, 0.16, 0.95)
	progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress_bg)

	_progress_bar = ColorRect.new()
	_progress_bar.position = progress_bg.position
	_progress_bar.size = progress_bg.size
	_progress_bar.color = Color(0.78, 0.64, 0.34, 0.95)
	_progress_bar.scale = Vector2(0.001, 1.0)
	_progress_bar.pivot_offset = Vector2.ZERO
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress_bar)

	_update_labels()

func _update_labels() -> void:
	if _frequency_label != null:
		_frequency_label.text = "%.1f MHz" % current_frequency
	if _status_label != null and not locked and _status_label.text.is_empty():
		_status_label.text = "ESTÁTICA"
