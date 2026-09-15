extends SceneTree

# Headless smoke test: carrega a Cena 1 e confirma os nós mínimos dos Milestones 0.1 e 0.2.
# godot --headless --path godot --script res://tests/smoke_test.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/vertical_slice/scene_01_greybox.tscn") as PackedScene
	if packed == null:
		push_error("SMOKE FAIL: não foi possível carregar scene_01_greybox.tscn")
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var player := scene.get_node_or_null("Elias_GreyCapsule")
	var camera := scene.get_node_or_null("GreyboxCamera")
	var exit_trigger := scene.get_node_or_null("Scene01Exit")
	var virtual_stick := scene.get_node_or_null("GreyboxUI/VirtualStick")
	var radio := scene.get_node_or_null("FieldRadio")
	var proximity := scene.get_node_or_null("FieldRadio/Proximity")
	var audio := scene.get_node_or_null("FieldRadio/StaticAudio")
	var interact := scene.get_node_or_null("GreyboxUI/RadioInteract")
	var dial := scene.get_node_or_null("GreyboxUI/RadioDial")
	var decoded := scene.get_node_or_null("GreyboxUI/DecodedSignal")

	var required := {
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

	for label in required:
		if required[label] == null:
			push_error("SMOKE FAIL: %s ausente" % label)
			quit(1)
			return

	print("SMOKE PASS: movimento/câmera/touch + rádio/proximidade/dial/áudio/sinal carregados")
	quit(0)
