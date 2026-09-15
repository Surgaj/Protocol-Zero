extends Node3D

# PROTOCOL ZERO — Milestone 0.2
# Primeiro objeto interativo: proximidade -> sintonização -> áudio procedural -> lock do CZI-07.

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

var current_frequency: float = 126.0
var player_near: bool = false
var tuning: bool = false
var locked: bool = false
var lock_timer: float = 0.0

var _audio: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _generator: AudioStreamGenerator
var _noise_gain: float = 0.26
var _carrier_gain: float = 0.0
var _carrier_phase: float = 0.0
var _secondary_phase: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var proximity := get_node_or_null("Proximity") as Area3D
	_audio = get_node_or_null("StaticAudio") as AudioStreamPlayer3D

	if proximity != null:
		proximity.body_entered.connect(_on_body_entered)
		proximity.body_exited.connect(_on_body_exited)

	if _audio != null:
		_generator = AudioStreamGenerator.new()
		_generator.mix_rate = 22050.0
		_generator.buffer_length = 0.35
		_audio.stream = _generator
		_audio.volume_db = -5.0
		_audio.max_distance = 8.0
		_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

	set_process(true)

func _process(delta: float) -> void:
	if tuning and not locked:
		_update_lock(delta)
		_fill_audio_buffer()

func begin_tuning() -> bool:
	if locked or not player_near:
		return false

	tuning = true
	lock_timer = 0.0

	# O áudio começa em resposta ao toque/click do jogador, o que também respeita
	# as políticas de autoplay dos navegadores mobile.
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

	# Limpa o ruído imediatamente: o silêncio curto antes da mensagem decodificada
	# funciona como confirmação auditiva do lock.
	if _audio != null:
		_audio.stop()
	_playback = null

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
	player_near = true
	proximity_changed.emit(true)

func _on_body_exited(body: Node3D) -> void:
	if body.name != "Elias_GreyCapsule":
		return
	player_near = false
	if tuning and not locked:
		stop_tuning()
	proximity_changed.emit(false)
