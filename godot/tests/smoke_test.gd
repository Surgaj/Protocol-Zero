extends SceneTree

# Headless smoke test: carrega a Cena 1 e valida nós, scripts e o fluxo real do rádio.
# godot --headless --path godot --script res://tests/smoke_test.gd

var _proximity_true_seen: bool = false
var _signal_locked_seen: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("SMOKE FAIL: %s" % message)
	quit(1)

func _on_test_proximity(is_near: bool) -> void:
	if is_near:
		_proximity_true_seen = true

func _on_test_signal_locked(_frequency: float) -> void:
	_signal_locked_seen = true

func _run() -> void:
	var packed: PackedScene = load("res://scenes/vertical_slice/scene_01_greybox.tscn") as PackedScene
	if packed == null:
		_fail("não foi possível carregar scene_01_greybox.tscn")
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player: CharacterBody3D = scene.get_node_or_null("Elias_GreyCapsule") as CharacterBody3D
	var camera: Node = scene.get_node_or_null("GreyboxCamera")
	var exit_trigger: Node = scene.get_node_or_null("Scene01Exit")
	var virtual_stick: Node = scene.get_node_or_null("GreyboxUI/VirtualStick")
	var radio: Node3D = scene.get_node_or_null("FieldRadio") as Node3D
	var proximity: Node = scene.get_node_or_null("FieldRadio/Proximity")
	var audio: AudioStreamPlayer3D = scene.get_node_or_null("FieldRadio/StaticAudio") as AudioStreamPlayer3D
	var interact: Button = scene.get_node_or_null("GreyboxUI/RadioInteract") as Button
	var dial: Control = scene.get_node_or_null("GreyboxUI/RadioDial") as Control
	var decoded: Control = scene.get_node_or_null("GreyboxUI/DecodedSignal") as Control

	var required: Dictionary = {
		"Elias_GreyCapsule": player,
		"GreyboxCamera": camera,
		"Scene01Exit": exit_trigger,
		"VirtualStick": virtual_stick,
		"FieldRadio": radio,
		"RadioProximity": proximity,
		"StaticAudio": audio,
		"RadioInteract": interact,
		"RadioDial": dial,
		"DecodedSignal": decoded,
	}

	for label: String in required:
		if required[label] == null:
			_fail("%s ausente" % label)
			return

	if radio.get_script() == null or not radio.has_method("begin_tuning"):
		_fail("radio.gd não anexou/parseou corretamente")
		return
	if not radio.has_signal("proximity_changed") or not radio.has_signal("signal_locked"):
		_fail("sinais do radio.gd ausentes")
		return
	if dial.get_script() == null or not dial.has_signal("frequency_changed"):
		_fail("dial.gd não anexou/parseou corretamente")
		return

	# Prova comportamento, não só existência: aproxima Elias e exige evento de proximidade.
	radio.connect("proximity_changed", Callable(self, "_on_test_proximity"))
	radio.connect("signal_locked", Callable(self, "_on_test_signal_locked"))

	player.global_position = Vector3(
		radio.global_position.x + 0.8,
		0.90,
		radio.global_position.z
	)
	await process_frame
	await process_frame

	if not bool(radio.get("player_near")):
		_fail("rádio não reconheceu Elias dentro do raio de interação")
		return
	if not _proximity_true_seen:
		_fail("proximity_changed(true) não foi emitido")
		return
	if not interact.visible:
		_fail("botão INTERAGIR não ficou visível após proximidade")
		return

	# Prova início da sintonia.
	var tuning_started: bool = bool(radio.call("begin_tuning"))
	if not tuning_started or not bool(radio.get("tuning")):
		_fail("begin_tuning não iniciou a sintonia")
		return
	if audio.stream == null:
		_fail("rádio não configurou AudioStreamGenerator")
		return

	# Prova lock e transição narrativa sem depender de relógio real do runner.
	var target: float = float(radio.get("target_frequency"))
	radio.call("set_frequency", target)
	radio.call("_update_lock", 1.0)
	await process_frame

	if not bool(radio.get("locked")) or not _signal_locked_seen:
		_fail("sinal não travou na frequência-alvo")
		return
	if not bool(scene.get("scene_signal_locked")):
		_fail("Cena 1 não recebeu a transição signal_locked")
		return
	if not decoded.visible:
		_fail("painel POSITION TRIANGULATED não apareceu após lock")
		return

	print("SMOKE PASS: movimento + proximidade + INTERAGIR + áudio + sintonia + lock + transição narrativa")
	quit(0)
