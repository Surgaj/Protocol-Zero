extends SceneTree

# Headless smoke test: carrega a Cena 1 e confirma os nós mínimos.
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

	if player == null:
		push_error("SMOKE FAIL: Elias_GreyCapsule ausente")
		quit(1)
		return

	if camera == null:
		push_error("SMOKE FAIL: GreyboxCamera ausente")
		quit(1)
		return

	if exit_trigger == null:
		push_error("SMOKE FAIL: Scene01Exit ausente")
		quit(1)
		return

	if virtual_stick == null:
		push_error("SMOKE FAIL: VirtualStick ausente")
		quit(1)
		return

	print("SMOKE PASS: scene, player, camera, exit trigger e virtual stick carregados")
	quit(0)
