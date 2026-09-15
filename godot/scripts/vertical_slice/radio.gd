extends Node3D

# PROTOCOL ZERO — Milestone 0.2
# Primeiro objeto interativo: proximidade -> sintonização -> áudio procedural -> lock do CZI-07.
# Build diagnóstica: além do sinal, o rádio sincroniza o botão diretamente com a UI
# e mostra distância/near na tela para isolar bugs Web/mobile.

signal proximity_changed(is_near: bool)
signal tuning_started
signal tuning_feedback(frequency: float, proximity: float, in_lock_zone: bool, lock_progress: float)
signal signal_locked(frequency: float)

@export var min_frequency: float = 120.0
@export var max_frequency: float = 180.0
@export var target_frequency: float = 147.5
@export var tolerance: float = 0.5
@export var lock_duration: float = 0.6
@export var discovery_band: float = 8.0
@export var interaction_radius: float = 2.35

var current_frequency: float = 126.0
var player_near: bool = false
var tuning: bool = false
var locked: bool = false
var lock_timer: float = 0.0

var _player: CharacterBody3D
var _audio: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _generator: AudioStreamGenerator
var _noise_gain: float = 0.26
var _carrier_gain: float = 0.0
var _carrier_phase: float = 0.0
var _secondary_phase: float = 0.0
var _rng := RandomNumberGenerator.new()

# Diagnóstico temporário do Milestone 0.2.
var _interact_button: Button
var _debug_label: Label
var _horizontal_distance: float = INF

func _ready() -> void:
	_rng.randomize()
	var proximity := get_node_or_null("Proximity") as Area3D
	_audio = get_node_or_null("StaticAudio") as AudioStreamPlayer3D

	# O Area3D continua existindo, mas não é mais a única fonte de verdade.
	if proximity != null:
		proximity.monitoring = true
		proximity.monitorable = true
		proximity.collision_layer = 1
		proximity.collision_mask = 1
		proximity.body_entered.connect(_on_body_entered)
		proximity.body_exited.connect(_on_body_exited)

	if get_parent() != null:
		_player = get_parent().get_node_or_null("Elias_GreyCapsule") as CharacterBody3D

	if _audio != null:
		_generator = AudioStreamGenerator.new()
		_generator.mix_rate = 22050.0
		_generator.buffer_length = 0.35
		_audio.stream = _generator
		_audio.volume_db = -5.0
		_audio.max_distance = 8.0
		_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

	set_process(true)
	call_deferred("_bind_debug_ui")
	call_deferred("_refresh_player_proximity")

func _process(delta: float) -> void:
	_refresh_player_proximity()
	_sync_debug_ui()

	if tuning and not locked:
		_update_lock(delta)
		_fill_audio_buffer()

func begin_tuning() -> bool:
	# Recalcula no instante do toque para não depender de um sinal físico anterior.
	_refresh_player_proximity()
	if locked or not player_near:
		return false

	tuning = true
	lock_timer = 0.0
	_sync_debug_ui()

	# O áudio começa em resposta ao toque/click do jogador, respeitando autoplay mobile.
	if _audio != null and not _audio.playing:
		_audio.play()
		_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback

	_update_audio_character()
	tuning_started.emit()
	return true

func set_frequency(value: float) -> void:
	if locked:
		return
	current_frequency = clamp(value, min_frequency, max_frequency)
	_update_audio_character()

func stop_tuning() -> void:
	tuning = false
	lock_timer = 0.0
	if _audio != null:
		_audio.stop()
	_playback = null
	_sync_debug_ui()

func _bind_debug_ui() -> void:
	if get_parent() == null:
		return

	var ui := get_parent().get_node_or_null("GreyboxUI") as CanvasLayer
	if ui == null:
		return

	_interact_button = ui.get_node_or_null("RadioInteract") as Button
	if _interact_button != null:
		# Para o diagnóstico, eliminamos qualquer dúvida de anchor em retrato.
		# O viewport lógico é 720x1280 e o stretch escala isso para o device.
		_interact_button.anchor_left = 0.0
		_interact_button.anchor_top = 0.0
		_interact_button.anchor_right = 0.0
		_interact_button.anchor_bottom = 0.0
		_interact_button.position = Vector2(490, 1080)
		_interact_button.size = Vector2(200, 78)

	_debug_label = Label.new()
	_debug_label.name = "RadioDebug"
	_debug_label.position = Vector2(430, 140)
	_debug_label.size = Vector2(260, 72)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug_label.text = "RADIO DEBUG"
	ui.add_child(_debug_label)

	_sync_debug_ui()

func _sync_debug_ui() -> void:
	if _interact_button != null:
		# Fonte de verdade temporária: o botão lê o estado atual a cada frame.
		# Assim isolamos completamente a hipótese de um signal ter sido perdido.
		_interact_button.visible = player_near and not tuning and not locked
		_interact_button.disabled = not player_near

	if _debug_label != null:
		var distance_text := "--" if is_inf(_horizontal_distance) else "%.2f" % _horizontal_distance
		_debug_label.text = "dist: %s m\nnear: %s" % [distance_text, str(player_near)]

func _refresh_player_proximity() -> void:
	if locked:
		_horizontal_distance = INF
		_set_player_near(false)
		return

	if _player == null or not is_instance_valid(_player):
		if get_parent() != null:
			_player = get_parent().get_node_or_null("Elias_GreyCapsule") as CharacterBody3D
		if _player == null:
			_horizontal_distance = INF
			return

	# Só usamos distância horizontal. Diferenças pequenas de Y não devem impedir
	# o prompt de aparecer quando o jogador está claramente ao lado do aparelho.
	var radio_pos := global_position
	var player_pos := _player.global_position
	_horizontal_distance = Vector2(
		player_pos.x - radio_pos.x,
		player_pos.z - radio_pos.z
	).length()

	_set_player_near(_horizontal_distance <= interaction_radius)

func _set_player_near(value: bool) -> void:
	if player_near == value:
		return

	player_near = value
	if not player_near and tuning and not locked:
		stop_tuning()
	proximity_changed.emit(player_near)

func _update_lock(delta: float) -> void:
	var distance := abs(current_frequency - target_frequency)
	var in_lock_zone := distance <= tolerance

	if in_lock_zone:
		lock_timer += delta
	else:
		lock_timer = max(0.0, lock_timer - delta * 2.0)

	var proximity := _frequency_proximity()
	var progress := clamp(lock_timer / lock_duration, 0.0, 1.0)
	tuning_feedback.emit(current_frequency, proximity, in_lock_zone, progress)

	if lock_timer >= lock_duration:
		_complete_lock()

func _complete_lock() -> void:
	if locked:
		return
	locked = true
	tuning = false
	current_frequency = target_frequency

	if _audio != null:
		_audio.stop()
	_playback = null

	_sync_debug_ui()
	tuning_feedback.emit(current_frequency, 1.0, true, 1.0)
	signal_locked.emit(current_frequency)

func _frequency_proximity() -> float:
	var distance := abs(current_frequency - target_frequency)
	return 1.0 - clamp(distance / discovery_band, 0.0, 1.0)

func _update_audio_character() -> void:
	var proximity := _frequency_proximity()

	# Longe: ruído branco dominante. Perto: ruído cai e um carrier tonal surge.
	_noise_gain = lerp(0.30, 0.055, proximity)
	if proximity <= 0.18:
		_carrier_gain = 0.0
	else:
		_carrier_gain = ((proximity - 0.18) / 0.82) * 0.18

func _fill_audio_buffer() -> void:
	if _audio == null or not _audio.playing:
		return
	if _playback == null:
		_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null or _generator == null:
		return

	var frames := _playback.get_frames_available()
	var mix_rate := _generator.mix_rate
	var proximity := _frequency_proximity()
	var carrier_hz := 760.0 + current_frequency * 1.25
	var secondary_gain := max(0.0, (proximity - 0.62) / 0.38) * 0.075

	for _i in range(frames):
		var noise := _rng.randf_range(-1.0, 1.0) * _noise_gain
		var carrier := sin(_carrier_phase) * _carrier_gain
		var secondary := sin(_secondary_phase) * secondary_gain
		var sample := clamp(noise + carrier + secondary, -0.92, 0.92)
		_playback.push_frame(Vector2(sample, sample))

		_carrier_phase = fmod(_carrier_phase + TAU * carrier_hz / mix_rate, TAU)
		_secondary_phase = fmod(_secondary_phase + TAU * 214.0 / mix_rate, TAU)

func _on_body_entered(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	_player = body as CharacterBody3D
	_set_player_near(true)

func _on_body_exited(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	# Não força false aqui: o cálculo horizontal decide e evita flicker na borda.
	_refresh_player_proximity()
