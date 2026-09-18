extends SceneTree

# Render real production nodes through the Compatibility renderer (software GL in CI).
# Evidence for visual review, not a substitute for an iPhone playtest.
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.call("reset_new_game")
	for id: String in ["maya", "iris", "dante", "noah"]:
		state.call("add_party_member", id)
	var scene: Node = (load("res://scenes/vertical_slice/czi07_base.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var player: Node3D = scene.get("player") as Node3D
	player.set_physics_process(false)
	var camera: Camera3D = scene.get("gameplay_camera") as Camera3D
	camera.set_process(false)
	camera.set_physics_process(false)
	var helper: Node = scene.get_node("DormitoryDecision")
	# Hold story decisions while photographing the same physical map.
	helper.set_process(false)
	scene.call("apply_power_stage_for_test", 3)
	var actors: Dictionary = helper.get("group_markers") as Dictionary
	for id: String in actors:
		var actor: Node3D = actors[id] as Node3D
		actor.visible = true
		if not actor.has_node("CitizenVisual/Body/Head"):
			push_error("VISUAL FAIL: missing character " + id)
			failures += 1
	if not player.has_node("CitizenVisual/Body/Radio"):
		push_error("VISUAL FAIL: Elias identity missing")
		failures += 1
	if scene.get_node("BunkerDressing").find_children("*", "CollisionObject3D", true, false).size() > 0:
		push_error("VISUAL FAIL: decoration changed collisions")
		failures += 1
	DirAccess.make_dir_recursive_absolute("/tmp/pz-visual")
	var lineup: Array[String] = ["maya", "iris", "dante", "noah"]
	for i: int in range(4):
		(actors[lineup[i]] as Node3D).position = Vector3(-1.25 + i * 0.9, 0.9, 4.5)
	player.position = Vector3(0, 0.9, 5.8)
	await _capture(camera, "entrance", Vector3(0, 0.85, 5.0), 8.8)
	player.position = Vector3(1.3, 0.9, -7.0)
	(actors["maya"] as Node3D).position = Vector3(-1.5, 0.9, -7.1)
	await _capture(camera, "generator", Vector3(0, 0.8, -8.0), 8.0)
	player.position = Vector3(4.6, 0.9, -3.6)
	(actors["iris"] as Node3D).position = Vector3(5.4, 0.9, -4.7)
	await _capture(camera, "dormitory", Vector3(4.4, 0.8, -4.8), 8.5)
	# Day 1 picture includes the real interaction controls and persistent traces.
	state.call("record_sleep_assignment", "maya")
	var day := Node.new()
	day.name = "CZI07DayController"
	day.set_script(load("res://scripts/vertical_slice/czi07_day_controller.gd"))
	scene.add_child(day)
	day.call("start", helper)
	for motion: Tween in day.get("motions"):
		motion.custom_step(12.0)
	player.position = Vector3(4.6, 0.9, -4.4)
	await _capture(camera, "day-one", Vector3(4.4, 0.8, -4.8), 8.5)
	# Last capture uses the actual follow camera and size on a 720x1280 viewport.
	camera.set_process(true)
	camera.set_physics_process(true)
	camera.size = 9.4
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pz-visual/mobile-gameplay.png")
	# Continue into the real survival extension for visual review.
	state.set("day_phase", 5)
	state.set("cough_resolved", true)
	state.call("sleep_to_next_day")
	for motion: Tween in day.get("motions"):
		motion.custom_step(12.0)
	player.position = Vector3(1.9, 0.9, 1.2)
	day.call("use_survival_action", "area:services")
	for motion: Tween in day.get("motions"):
		motion.custom_step(12.0)
	camera.set_process(false)
	camera.set_physics_process(false)
	await _capture(camera, "services-cooking", Vector3(5.5, 0.8, 1.0), 8.5)
	player.position = Vector3(7.2, 0.9, 1.2)
	day.call("use_survival_action", "area:pantry")
	for motion: Tween in day.get("motions"):
		motion.custom_step(12.0)
	await _capture(camera, "services-meal", Vector3(6.2, 0.8, 1.0), 9.4)
	player.position = Vector3(10.1, 0.9, 1.4)
	await _capture(camera, "pantry-open", Vector3(10.0, 0.8, 1.0), 7.8)
	if failures == 0:
		print("VISUAL PASS: character identities + cosmetic-only geometry + five rendered views")
	quit(0 if failures == 0 else 1)

func _capture(camera: Camera3D, name_: String, target: Vector3, size_: float) -> void:
	camera.size = size_
	camera.position = target + Vector3(8.5, 6, 10)
	camera.look_at(target)
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("/tmp/pz-visual/" + name_ + ".png")
	if result != OK:
		failures += 1
		push_error("VISUAL FAIL: capture " + name_)
