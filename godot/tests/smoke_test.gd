extends SceneTree

# Headless smoke test: carrega a Cena 1 e confirma nós + scripts dos Milestones 0.1 e 0.2.
# godot --headless --path godot --script res://tests/smoke_test.gd

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("SMOKE FAIL: %s" % message)
	quit(1)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/vertical_slice/scene_01_greybox.tscn") as PackedScene
	if packed == null:
		_fail("não foi possível carregar scene_01_greybox.tscn")
		return

	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var player: Node = scene.get_node_or_null("Elias_GreyCapsule")
	var camera: Node = scene.get_node_or_null("GreyboxCamera")
	var exit_trigger: Node = scene.get_node_or_null("Scene01Exit")
	var virtual_stick: Node = scene.get_node_or_null("GreyboxUI/VirtualStick")
	var radio: Node = scene.get_node_or_null("FieldRadio")
	var proximity: Node = scene.get_node_or_null("FieldRadio/Proximity")
	var audio: Node = scene.get_node_or_null("FieldRadio/StaticAudio")
	var interact: Node = scene.get_node_or_null("GreyboxUI/RadioInteract")
	var dial: Node = scene.get_node_or_null("GreyboxUI/RadioDial")
	var decoded: Node = scene.get_node_or_null("GreyboxUI/DecodedSignal")
	var debug_label: Node = scene.get_node_or_null("GreyboxUI/RadioDebug")

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
		"RadioDebug": debug_label,
	}

	for label: String in required:
		if required[label] == null:
			_fail("%s ausente" % label)
			return

	if radio.get_script() == null:
		_fail("radio.gd não anexou ao FieldRadio")
		return
	if not radio.has_method("begin_tuning"):
		_fail("FieldRadio não possui begin_tuning; radio.gd falhou")
		return
	if not radio.has_signal("proximity_changed"):
		_fail("FieldRadio não possui proximity_changed; radio.gd falhou")
		return
	if dial.get_script() == null:
		_fail("dial.gd não anexou ao RadioDial")
		return
	if not dial.has_signal("frequency_changed"):
		_fail("RadioDial não possui frequency_changed; dial.gd falhou")
		return

	print("SMOKE PASS: cena + scripts reais de movimento, rádio, dial, debug e UI carregados")
	quit(0)
