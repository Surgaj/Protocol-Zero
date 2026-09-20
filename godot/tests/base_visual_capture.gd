extends SceneTree

const Core = preload("res://scripts/base/base_state.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func capture(name_: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("/tmp/pz-visual/" + name_ + ".png") != OK:
		failures += 1

func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.call("reset_new_game")
	gs.set("base_mode", true)
	var base := Core.new(gs.get("survival"))
	base.initialize_resources()
	gs.set("base_core", base)
	for id: String in Core.IDS:
		gs.call("add_party_member", id)
	var scene: Node = load("res://scenes/vertical_slice/czi07_base.tscn").instantiate()
	root.add_child(scene)
	var controller: Node = scene.get_node("BaseCore")
	controller.set("save_path", "user://base_capture.json")
	await create_timer(1).timeout
	var player: Node3D = scene.get("player") as Node3D
	player.set_physics_process(false)
	var camera: Camera3D = scene.get("gameplay_camera") as Camera3D
	DirAccess.make_dir_recursive_absolute("/tmp/pz-visual")
	await capture("core-01-dark")
	player.position = Vector3(1.4, 0.9, -2.6)
	controller.call("open_panel", "generator")
	controller.call("toggle_generator")
	await create_timer(2).timeout
	await capture("core-02-generator")
	player.position = Vector3(1.7, 0.9, 1.2)
	controller.call("open_panel", "services")
	controller.call("repair_selected")
	await create_timer(0.6).timeout
	player.position = Vector3(3.6, 0.9, 0.8)
	controller.call("open_panel", "water")
	controller.call("switch_circuit", "water")
	controller.call("assign_worker", "iris", "water")
	await create_timer(13).timeout
	await capture("core-03-water")
	player.position = Vector3(1.4, 0.9, -2.6)
	controller.call("open_panel", "generator")
	controller.call("upgrade_generator")
	await capture("core-04-power-panel")
	controller.call("close_panel")
	player.position = Vector3(6.4, 0.9, 0.8)
	controller.call("open_panel", "kitchen")
	controller.call("switch_circuit", "kitchen")
	controller.call("assign_worker", "maya", "kitchen")
	await create_timer(13).timeout
	camera.size = 13
	player.position = Vector3(3, 0.9, -0.6)
	await create_timer(1).timeout
	await capture("core-05-living-base")
	if failures == 0:
		print("BASE VISUAL PASS: cold core + startup + water worker + power panel + living base")
	quit(0 if failures == 0 else 1)
