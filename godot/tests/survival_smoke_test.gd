extends SceneTree

const Life = preload("res://scripts/survival/survival_state.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("SURVIVAL FAIL: " + message)

func settle(controller: Node) -> void:
	for tween: Tween in controller.get("motions"):
		if tween.is_valid():
			tween.custom_step(12.0)

func _economy_tests() -> void:
	var life := Life.new()
	check(not life.step(1, 0), "Day 1 has no survival tick")
	life.start()
	check(not life.unlock("pantry"), "cannot unlock pantry before services")
	life.powered = false
	check(not life.unlock("services") and life.parts == 4, "unpowered door costs nothing")
	life.powered = true
	life.parts = 1
	check(not life.unlock("services") and life.parts == 1, "insufficient parts cannot unlock")
	life.parts = 4
	check(life.unlock("services") and life.parts == 2, "unlock consumes exactly two parts")
	check(not life.unlock("services") and life.parts == 2, "cannot pay twice")
	life.water = 10
	life.step(2, 0)
	check(life.water == 20 and life.jobs.get("maya") == "pump", "powered autonomous pump capped at 20")
	check(not life.step(2, 0) and life.water == 20, "same tick cannot duplicate production")
	life.step(2, 1)
	check(life.water == 18 and life.food == 7 and life.meals == 10, "cooking consumes water and food")
	life.step(2, 2)
	check(life.water == 13 and life.meals == 5, "five people drink and eat")
	life.powered = false
	life.step(2, 3)
	check(life.water == 13, "no power means no pumping")
	life.step(2, 4)
	check(life.food == 7 and life.meals == 5, "no power means no cooking")
	life.powered = true
	check(life.unlock("pantry") and life.food == 25 and life.parts == 0, "pantry supplies one finite stock")
	check(not life.unlock("pantry") and life.food == 25, "pantry not infinite food")
	life.people["maya"]["alive"] = false
	life.step(3, 0)
	check(life.jobs.get("noah") == "pump" and not life.jobs.has("maya"), "living worker takes over; dead citizen cannot work")
	var dry := Life.new()
	dry.start()
	dry.water = 0
	dry.food = 0
	dry.meals = 0
	for tick: int in range(12):
		dry.step(2 + tick / 6, tick % 6)
	check(dry.condition("elias") == "critical" and not dry.game_over, "warning stage precedes death")
	for tick: int in range(12, 18):
		dry.step(2 + tick / 6, tick % 6)
	check(dry.game_over and not dry.alive("elias"), "prolonged unaddressed deprivation kills")
	check(not dry.step(9, 1), "game over stops simulation")
	var rescue := Life.new()
	rescue.start()
	rescue.people["iris"]["thirst"] = 12
	rescue.people["iris"]["hunger"] = 18
	rescue.step(2, 2)
	check(rescue.condition("iris") == "well", "serving water and food reverses deprivation before death")
	check(rescue.water >= 0 and rescue.meals >= 0, "stocks never go negative")

func _run() -> void:
	_economy_tests()
	var state: Node = root.get_node("GameState")
	state.call("reset_new_game")
	state.call("record_sleep_assignment", "elias")
	for id: String in ["maya", "iris", "dante", "noah"]:
		state.call("add_party_member", id)
	state.call("start_day")
	state.set("day_phase", 5)
	state.call("begin_cough")
	check(not state.call("sleep_to_next_day"), "night choice must finish before survival")
	state.call("resolve_cough", true)
	var scene: Node = (load("res://scenes/vertical_slice/czi07_base.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	await physics_frame
	var player: CharacterBody3D = scene.get("player") as CharacterBody3D
	player.set_physics_process(false)
	var helper: Node = scene.get_node("DormitoryDecision")
	helper.set("decision_resolved", true)
	helper.set_process(false)
	scene.call("apply_power_stage_for_test", 3)
	var day := Node.new()
	day.name = "CZI07DayController"
	day.set_script(load("res://scripts/vertical_slice/czi07_day_controller.gd"))
	scene.add_child(day)
	day.call("start", helper)
	settle(day)
	var wing: Node = scene.get_node("ServiceWing")
	var gates: Dictionary = wing.get("gates")
	check((gates["services"] as StaticBody3D).collision_layer != 0, "service door physically locked")
	check(not state.get("survival").active, "Day 1 preserved")
	player.position = Vector3(4.65, 0.9, -4.4)
	check(day.call("use_survival_action", "rest"), "contextual sleep begins day 2")
	settle(day)
	var life: Life = state.get("survival") as Life
	check(state.get("day") == 2 and state.get("day_phase") == 0 and life.active, "survival begins next morning")
	check(state.get("checked_cough"), "previous night decision retained")
	var original_map: int = scene.get_instance_id()
	var water_before: int = life.water
	player.position = Vector3(0, 0.9, 3.0)
	check(not day.call("use_survival_action", "area:services"), "unlock cannot be invoked remotely")
	await process_frame
	await process_frame
	check(life.water == water_before and state.get("day_phase") == 0, "walking/waiting do not consume supplies")
	player.position = Vector3(1.9, 0.91, 1.2)
	await physics_frame
	check(player.test_move(player.global_transform, Vector3(1.5, 0, 0)), "locked door blocks physical crossing")
	check(day.call("use_survival_action", "area:services"), "nearby door repairs successfully")
	settle(day)
	await physics_frame
	check(not player.test_move(player.global_transform, Vector3(1.5, 0, 0)), "opened door is actually traversable")
	check(state.get("day_phase") == 1 and life.parts == 2, "unlock is one significant action")
	check(not day.call("use_survival_action", "area:services") and life.parts == 2, "repeated unlock no extra cost")
	player.position = Vector3(7.2, 0.91, 1.2)
	check(day.call("use_survival_action", "area:pantry"), "pantry unlock")
	settle(day)
	check(life.areas["pantry"] and life.parts == 0, "both areas stay unlocked")
	check((gates["pantry"] as StaticBody3D).collision_layer == 0, "pantry collision removed")
	check(wing.get("shown_water") == life.water and wing.get("shown_food") == life.food, "physical resource visuals follow state")
	var floor: Node = scene.get_node("ServiceWing/Services/Floor")
	check(floor != null and scene.get_instance_id() == original_map and player.get_parent() == scene, "extensions preserve physical map")
	var route: Array = day.call("route_between", Vector3(4.65, 0.9, -4.4), Vector3(6.35, 0.9, 0.85))
	check(route.has(Vector3(1.65, 0.9, -3.7)) and route.has(Vector3(1.65, 0.9, 1.2)), "NPC uses both actual doorways")
	var pump_water: int = life.water
	check(day.call("perform_action", "object:kitchen"), "next phase")
	settle(day)
	check(life.water == mini(20, pump_water + 12), "Maya replenishes reservoir while player does another task")
	player.position = Vector3(1.3, 0.9, -7.25)
	check(day.call("use_survival_action", "object:power"), "generator switch works by proximity")
	settle(day)
	check(not life.powered and life.jobs.get("iris") == "empty_pot", "power cut interrupts kitchen")
	check((wing.get("service_light") as OmniLight3D).light_energy == 0, "power cut visible in new wing")
	check(day.call("perform_action", "observe:noah"), "advance to night")
	settle(day)
	player.position = Vector3(4.65, 0.9, -4.4)
	check(day.call("use_survival_action", "rest"), "can sleep into third day")
	settle(day)
	check(state.get("day") == 3 and life.areas["services"] and life.areas["pantry"], "unlocks persist between days")
	life.people["elias"]["alive"] = false
	life.people["elias"]["cause"] = "água"
	life.game_over = true
	day.call("_process", 0.1)
	check(day.get("game_over_panel") != null and not player.get("input_enabled"), "fatal deprivation has playable restart screen")
	check(not day.call("perform_action", "object:generator"), "game over blocks time")
	scene.queue_free()
	await process_frame
	state.call("reset_new_game")
	check(not state.get("survival").active and not state.get("survival").areas["services"], "new game clears survival and unlocks")
	if failures == 0:
		print("SURVIVAL PASS: connected production/consumption + visible shortages + recovery/death + two physical unlocks + day rollover + Day 1 retained")
	quit(0 if failures == 0 else 1)
