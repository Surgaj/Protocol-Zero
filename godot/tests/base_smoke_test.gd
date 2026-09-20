extends SceneTree

const Core = preload("res://scripts/base/base_state.gd")
const Save = preload("res://scripts/base/base_save.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, text_: String) -> void:
	if not ok:
		failures += 1
		push_error("BASE FAIL: " + text_)

func _model_tests() -> void:
	var base := Core.new()
	base.initialize_resources()
	check(base.power.capacity() == 0 and base.resources.parts == 8, "new base starts dark with repair resources")
	check(not base.repair("services"), "repair requires live generator")
	base.power.running = true
	check(base.power.capacity() == 4 and base.power.consumption() == 1, "level one capacity and dorm circuit")
	check(base.repair("services") and base.resources.parts == 6, "repair consumes materials once")
	check(not base.repair("services") and base.resources.parts == 6, "repair is idempotent")
	check(base.power.switch_sector("water"), "water fits remaining energy")
	check(not base.power.switch_sector("kitchen") and not base.power.supplied("kitchen"), "overload rejected without switching another circuit")
	check(base.assign("iris", "water"), "any existing survivor can work at water")
	check(base.produce("iris", "water") and base.resources.water == 6, "assigned powered worker produces")
	check(not base.produce("maya", "water"), "unassigned worker cannot produce")
	base.power.running = false
	check(not base.produce("iris", "water"), "generator off halts production")
	base.power.running = true
	check(base.upgrade() and base.resources.parts == 0 and base.power.capacity() == 8, "upgrade expands capacity and spends materials")
	check(base.power.switch_sector("kitchen"), "level two powers water kitchen and dorm")
	check(base.assign("maya", "kitchen"), "kitchen job")
	var water: int = base.resources.water
	var food: int = base.resources.food
	check(base.produce("maya", "kitchen") and base.resources.water == water - 1 and base.resources.food == food - 1 and base.resources.meals == 5, "kitchen recipe consumes stock")
	check(base.collect_salvage("entry") and not base.collect_salvage("entry"), "physical salvage cannot duplicate rewards")
	check(base.repair("pantry"), "workshop expansion")
	check(not base.power.switch_sector("workshop"), "third sector creates an energy choice")
	base.power.switch_sector("kitchen")
	check(base.power.switch_sector("workshop"), "reallocate energy to workshop")
	base.assign("noah", "workshop")
	check(base.produce("noah", "workshop") and base.resources.parts == 1, "workshop supplies future upgrades")
	base.assign("dante", "workshop")
	check(base.jobs.noah == "" and base.jobs.dante == "workshop", "one worker per station without duplicate jobs")
	var data: Dictionary = base.snapshot()
	check(Save.write(data, "user://base_test_roundtrip.json") == OK, "save write")
	var restored := Core.new()
	check(restored.restore(Save.read_data("user://base_test_roundtrip.json")), "save loads")
	check(restored.power.level == 2 and restored.resources.parts == 1 and restored.jobs.dante == "workshop" and restored.resources.areas.pantry, "save preserves energy resources jobs and doors")
	var bad: Dictionary = data.duplicate(true)
	bad.level = 99
	check(not restored.restore(bad) and restored.power.level == 2, "invalid save does not mutate live state")
	bad = data.duplicate(true)
	bad.enabled.kitchen = true
	check(not restored.restore(bad), "overloaded save rejected")
	check(not restored.restore({"version": 900}), "unsupported save rejected")
	var file := FileAccess.open("user://base_corrupt.json", FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	check(Save.read_data("user://base_corrupt.json").is_empty(), "corrupt save safe fallback")

func _wait_worker(worker: Node, wanted: String, seconds: float = 40.0) -> bool:
	var elapsed: float = 0.0
	while elapsed < seconds:
		if worker.get("state") == wanted:
			return true
		await create_timer(0.2).timeout
		elapsed += 0.2
	print("BASE ROUTE DIAGNOSTIC: ", worker.get("state"), " position=", worker.get("position"), " path=", worker.get("path"))
	return false

func _run() -> void:
	_model_tests()
	Engine.time_scale = 4.0
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
	controller.set("save_path", "user://base_integration_test.json")
	for frame: int in range(80):
		if controller.get("initialized"):
			break
		await create_timer(0.05).timeout
	check(controller.get("initialized"), "continuous map and base controller load")
	var player: CharacterBody3D = scene.get("player") as CharacterBody3D
	player.set_physics_process(false)
	var instance: int = scene.get_instance_id()
	var nav = controller.get("navigation")
	check(nav.route(Vector3(1.6, 0.9, 2), Vector3(3.6, 0.9, 0.8)).is_empty(), "closed door blocks route into services")
	player.position = Vector3(1.4, 0.91, -2.6)
	check(controller.call("open_panel", "generator"), "generator interaction is reachable at spawn")
	controller.call("toggle_generator")
	await create_timer(2.0).timeout
	check(base.power.running and (scene.get("generator_light") as OmniLight3D).light_energy > 4, "startup sequence restores generator light")
	player.position = Vector3(1.7, 0.91, 1.2)
	await physics_frame
	check(player.test_move(player.global_transform, Vector3(1.6, 0, 0)), "closed services door physically blocks player")
	check(controller.call("open_panel", "services") and controller.call("repair_selected"), "repair via actual door control")
	await create_timer(0.5).timeout
	await physics_frame
	check(not player.test_move(player.global_transform, Vector3(1.6, 0, 0)), "open door allows crossing")
	check(not nav.route(Vector3(1.6, 0.9, 2), Vector3(3.6, 0.9, 0.8)).is_empty(), "navigation rebuild exposes new sector")
	player.position = Vector3(3.6, 0.91, 0.8)
	check(player.test_move(player.global_transform, Vector3(0.55, 0, -0.9)), "water machine is solid")
	check(controller.call("open_panel", "water"), "water station contextual UI")
	check(controller.call("switch_circuit", "water"), "water circuit fits initial budget")
	var before: int = base.resources.water
	check(controller.call("assign_worker", "iris", "water"), "assign Iris to physical water station")
	var worker: CharacterBody3D = controller.get("workers")["iris"] as CharacterBody3D
	check(worker.get("state") == "WALKING" and base.resources.water == before, "no production while walking")
	check(await _wait_worker(worker, "WORKING"), "worker navigates door and reaches machine without teleport")
	check(Vector2(worker.position.x - 3.6, worker.position.z - 0.8).length() < 0.55, "worker arrives at correct physical station")
	await create_timer(6.4).timeout
	check(base.produced.water > 0, "arrived worker begins real production")
	base.power.running = false
	controller.call("refresh_world")
	var produced_before: int = base.produced.water
	await create_timer(7).timeout
	check(base.produced.water == produced_before and (controller.get("sector_lights")["water"] as OmniLight3D).light_energy == 0, "power cut stops machine output and light")
	base.power.running = true
	player.position = Vector3(1.4, 0.91, -2.6)
	controller.call("open_panel", "generator")
	check(controller.call("upgrade_generator"), "physical generator upgrade")
	check((controller.get("coils")[1] as Node3D).visible, "upgrade changes generator mesh")
	controller.call("close_panel")
	var camera: Camera3D = scene.get("gameplay_camera") as Camera3D
	camera.call("apply_zoom", 0.01)
	check(camera.size == 7.0, "zoom minimum")
	camera.call("apply_zoom", 100)
	check(camera.size == 20.0, "zoom maximum")
	check(controller.call("save_now"), "live base save")
	var loaded := Core.new()
	check(loaded.restore(Save.read_data("user://base_integration_test.json")) and loaded.jobs.iris == "water", "live worker assignment roundtrips")
	check(scene.get_instance_id() == instance and player.get_parent() == scene, "same bunker and Elias survive every operation")
	check(scene.get_node("DormitoryDecision").get("decision_resolved"), "base mode does not replay tutorial")
	for w: Node in controller.get("workers").values():
		check(w is CharacterBody3D and w.get("collision_mask") == 1, "all survivors use physical collision")
	scene.queue_free()
	await process_frame
	gs.set("survival", loaded.resources)
	gs.set("base_core", loaded)
	var reloaded_scene: Node = load("res://scenes/vertical_slice/czi07_base.tscn").instantiate()
	root.add_child(reloaded_scene)
	var reloaded_core: Node = reloaded_scene.get_node("BaseCore")
	reloaded_core.set("save_path", "user://base_integration_test.json")
	await create_timer(1.0).timeout
	check(reloaded_core.get("initialized"), "saved base reconstructs into playable scene")
	check(reloaded_scene.get_node("ServiceWing").get("gates")["services"].collision_layer == 0, "saved opened door remains physically open")
	check(reloaded_core.get("workers")["iris"].get("station") == "water", "saved worker resumes assigned route")
	reloaded_scene.queue_free()
	await process_frame
	gs.call("reset_new_game")
	check(not gs.get("base_mode") and gs.get("base_core") == null, "prologue reset remains independent")
	Engine.time_scale = 1
	if failures == 0:
		print("BASE PASS: generator budgets + sectors + physical worker navigation + arrival production + upgrade + save/load + mobile zoom + persistent map")
	quit(0 if failures == 0 else 1)
