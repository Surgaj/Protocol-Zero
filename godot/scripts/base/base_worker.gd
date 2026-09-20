extends CharacterBody3D

# Collision-driven locomotion. Work starts only after the real body reaches its station.
var citizen_id: String = ""
var core: Node3D
var state: String = "IDLE"
var destination_state: String = "IDLE"
var path: Array[Vector3] = []
var station: String = ""
var timer: float = 0.0
var work_cycles: int = 0
var leisure_index: int = 0
var visual: Node
var stuck_time: float = 0.0
var last_position: Vector3

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.70
	shape.shape = capsule
	add_child(shape)
	load("res://scripts/visual/citizen_visual.gd").attach(self, citizen_id)
	visual = get_node("CitizenVisual")
	var label := Label3D.new()
	label.text = citizen_id.capitalize()
	label.position.y = 1.25
	label.font_size = 26
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	last_position = position
	timer = 1.0 + ["maya", "iris", "dante", "noah"].find(citizen_id) * 1.3

func command(target: Vector3, arrival_state: String, job: String = "") -> bool:
	var route: Array[Vector3] = core.get("navigation").route(position, target)
	if route.is_empty():
		state = "BLOCKED"
		path.clear()
		return false
	path = route
	destination_state = arrival_state
	station = job
	state = "WALKING"
	timer = 0
	stuck_time = 0
	visual.set("activity", "")
	return true

func reconsider() -> void:
	var job: String = core.get("state").jobs[citizen_id]
	if not job.is_empty():
		command(core.call("work_position", job), "WORKING", job)
	else:
		_leisure()

func _leisure() -> void:
	var index: int = ["maya", "iris", "dante", "noah"].find(citizen_id)
	leisure_index = (leisure_index + 1) % 4
	var base = core.get("state")
	if leisure_index == 1 and base.unlocked("water"):
		command(Vector3(4.8, 0.9, 0.8 + index * 0.4), "DRINKING")
	elif leisure_index == 2 and base.unlocked("kitchen"):
		command(Vector3(5.2 + index * 0.4, 0.9, 1.2), "EATING")
	elif leisure_index == 3:
		command(Vector3(3.6 + (index % 2) * 1.8, 0.9, -3.6 - (index / 2) * 2.1), "SLEEPING")
	else:
		command(Vector3(-1.4 + index * 0.8, 0.9, 4.7), "TALKING")

func _arrive() -> void:
	state = destination_state
	timer = 0
	velocity = Vector3.ZERO
	var activities: Dictionary = {"WORKING": {"water": "pump", "kitchen": "cook", "workshop": "generator"}.get(station, ""), "DRINKING": "drink", "EATING": "eat", "SLEEPING": "rest", "TALKING": "communication"}
	visual.set("activity", activities.get(state, ""))
	if state == "WORKING":
		var focus: Vector3 = core.call("work_position", station)
		focus.z -= 1.0
		var direction: Vector3 = focus - position
		rotation.y = atan2(direction.x, direction.z)
	elif state == "EATING":
		rotation.y = 0.0
	elif state == "DRINKING":
		rotation.y = PI
	var ledger = core.get("state").resources
	if state == "DRINKING" and ledger.water > 0:
		ledger.water -= 1
	elif state == "EATING" and ledger.meals > 0:
		ledger.meals -= 1
	elif state in ["EATING", "DRINKING"]:
		visual.set("activity", "empty_table")
	core.call("refresh_world")

func _physics_process(delta: float) -> void:
	if core == null or not bool(core.get("initialized")) or bool(core.get("paused")):
		return
	if state == "WALKING":
		if path.is_empty():
			_arrive()
		else:
			var offset: Vector3 = path[0] - position
			offset.y = 0
			if offset.length() < 0.10:
				path.pop_front()
				velocity.x = 0
				velocity.z = 0
			else:
				var speed: float = minf(2.2, offset.length() / maxf(delta, 0.001))
				velocity.x = offset.normalized().x * speed
				velocity.z = offset.normalized().z * speed
				rotation.y = lerp_angle(rotation.y, atan2(offset.x, offset.z), minf(1, delta * 10))
			if position.distance_to(last_position) < 0.005:
				stuck_time += delta
			else:
				stuck_time = 0
			if stuck_time > 2.0:
				state = "BLOCKED"
				path.clear()
			last_position = position
	else:
		velocity.x = 0
		velocity.z = 0
		timer += delta
		if state == "WORKING":
			var supplied: bool = core.get("state").power.supplied(station) and not bool(core.get("booting"))
			visual.set("activity", {"water": "pump", "kitchen": "cook", "workshop": "generator"}.get(station, "") if supplied else "")
			if not supplied:
				timer = 0
			elif timer >= 6.0:
				timer = 0
				if core.get("state").produce(citizen_id, station):
					core.call("production_feedback", station)
					work_cycles += 1
					if work_cycles >= 4:
						work_cycles = 0
						_leisure()
		elif timer >= (8.0 if state == "SLEEPING" else 4.0):
			reconsider()
	velocity.y = -0.1 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
