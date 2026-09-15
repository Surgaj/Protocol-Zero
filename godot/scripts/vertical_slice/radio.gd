extends Node3D

# PROTOCOL ZERO — Milestone 0.2
# Primeiro objeto interativo: proximidade -> sintonização -> áudio procedural -> lock do CZI-07.
# O áudio da sintonia usa saída não-posicional para Web/mobile: durante o minigame,
# clareza e confiabilidade importam mais que espacialização 3D.

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
var _legacy_audio_3d: AudioStreamPlayer3D
var _audio: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _generator: AudioStreamGenerator
var _noise_gain: float = 0.26
var _carrier_gain: float = 0.0
var _carrier_phase: float = 0.0
var _secondary_phase: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _horizontal_distance: float = INF

func _ready() -> void:
	_rng.randomize()
	var proximity_area: Area3D = get_node_or_null("Proximity") as Area3D
	_legacy_audio_3d = get_node_or_null("StaticAudio") as AudioStreamPlayer3D

	# Area3D + distância horizontal: redundância intencional para Web/mobile.
	if proximity_area != null:
		proximity_area.monitoring = true
		proximity_area.monitorable = true
		proximity_area.collision_layer = 1
		proximity_area.collision_mask = 1
		proximity_area.body_entered.connect(_on_body_entered)
		proximity_area.body_exited.connect(_on_body_exited)

	if get_parent() != null:
		_player = get_parent().get_node_or_null("Elias_GreyCapsule") as CharacterBody3D

	# AudioStreamGenerator é criado no carregamento, mas só toca depois do toque em INTERAGIR.
	# A saída principal é AudioStreamPlayer (não-posicional), mais previsível no Web/mobile.
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = 22050.0
	_generator.buffer_length = 0.45

	_audio = AudioStreamPlayer.new()
	_audio.name = "StaticAudioMobileSafe"
	_audio.stream = _generator
	_audio.volume_db = -1.0
	add_child(_audio)

	# Mantemos o nó 3D configurado por compatibilidade/inspeção do greybox e smoke test,
	# mas ele não é reproduzido para evitar diferenças de atenuação entre browsers.
	if _legacy_audio_3d != null:
		_legacy_audio_3d.stream = _generator
		_legacy_audio_3d.volume_db = -1.0
		_legacy_audio_3d.max_distance = 8.0
		_legacy_audio_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

	set_process(true)
	call_deferred("_refresh_player_proximity")

func _process(delta: float) -> void:
	_refresh_player_proximity()

	if tuning and not locked:
		_update_lock(delta)
		_fill_audio_buffer()

func begin_tuning() -> bool:
	_refresh_player_proximity()
	if locked or not player_near:
		return false

	tuning = true
	lock_timer = 0.0

	# Esta função é chamada diretamente pelo botão INTERAGIR: o play() acontece dentro
	# do gesto do usuário, requisito importante para navegadores mobile/iOS.
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, false)

	if _audio != null and not _audio.playing:
		_audio.play()
		_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback

	_update_audio_character()
	# Pré-enche o buffer ainda no gesto de interação para reduzir underrun no primeiro frame Web.
	_fill_audio_buffer()
	tuning_started.emit()
	return true

func set_frequency(value: float) -> void:
	if locked:
		return
	current_frequency = clampf(value, min_frequency, max_frequency)
	_update_audio_character()

func stop_tuning() -> void:
	tuning = false
	lock_timer = 0.0
	if _audio != null:
		_audio.stop()
	if _legacy_audio_3d != null:
		_legacy_audio_3d.stop()
	_playback = null

func get_horizontal_distance() -> float:
	return _horizontal_distance

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

	var radio_pos: Vector3 = global_position
	var player_pos: Vector3 = _player.global_position
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
	var distance: float = absf(current_frequency - target_frequency)
	var in_lock_zone: bool = distance <= tolerance

	if in_lock_zone:
		lock_timer += delta
	else:
		lock_timer = maxf(0.0, lock_timer - delta * 2.0)

	var frequency_proximity: float = _frequency_proximity()
	var progress: float = clampf(lock_timer / lock_duration, 0.0, 1.0)
	tuning_feedback.emit(current_frequency, frequency_proximity, in_lock_zone, progress)

	if lock_timer >= lock_duration:
		_complete_lock()

func _complete_lock() -> void:
	if locked:
		return
	locked = true
	tuning = false
	current_frequency = target_frequency

	# O ruído corta no lock; o pequeno silêncio funciona como confirmação auditiva.
	if _audio != null:
		_audio.stop()
	if _legacy_audio_3d != null:
		_legacy_audio_3d.stop()
	_playback = null

	tuning_feedback.emit(current_frequency, 1.0, true, 1.0)
	signal_locked.emit(current_frequency)

func _frequency_proximity() -> float:
	var distance: float = absf(current_frequency - target_frequency)
	return 1.0 - clampf(distance / discovery_band, 0.0, 1.0)

func _update_audio_character() -> void:
	var frequency_proximity: float = _frequency_proximity()

	_noise_gain = lerpf(0.34, 0.065, frequency_proximity)
	if frequency_proximity <= 0.18:
		_carrier_gain = 0.0
	else:
		_carrier_gain = ((frequency_proximity - 0.18) / 0.82) * 0.22

func _fill_audio_buffer() -> void:
	if _audio == null or not _audio.playing:
		return
	if _playback == null:
		_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if _playback == null or _generator == null:
		return

	var frames: int = _playback.get_frames_available()
	var mix_rate: float = _generator.mix_rate
	var frequency_proximity: float = _frequency_proximity()
	var carrier_hz: float = 760.0 + current_frequency * 1.25
	var secondary_gain: float = maxf(0.0, (frequency_proximity - 0.62) / 0.38) * 0.09

	for _i: int in range(frames):
		var noise: float = _rng.randf_range(-1.0, 1.0) * _noise_gain
		var carrier: float = sin(_carrier_phase) * _carrier_gain
		var secondary: float = sin(_secondary_phase) * secondary_gain
		var sample: float = clampf(noise + carrier + secondary, -0.92, 0.92)
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
	_refresh_player_proximity()
