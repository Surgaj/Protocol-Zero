extends Node3D

const CoreState = preload("res://scripts/base/base_state.gd")
const Navigation = preload("res://scripts/base/bunker_navigation.gd")
const Save = preload("res://scripts/base/base_save.gd")
const Worker = preload("res://scripts/base/base_worker.gd")
const WORK_POSITIONS: Dictionary = {"water": Vector3(3.6, 0.9, 0.8), "kitchen": Vector3(6.4, 0.9, 0.8), "workshop": Vector3(10.4, 0.9, 0.8)}
const POINTS: Dictionary = {"generator": Vector3(0, 0.9, -3.25), "services": Vector3(2.8, 0.9, 1.2), "water": Vector3(3.7, 0.9, 0.8), "kitchen": Vector3(6.5, 0.9, 0.8), "pantry": Vector3(8.45, 0.9, 1.2), "workshop": Vector3(10.3, 0.9, 0.8), "salvage:entry": Vector3(1.9, 0.9, 5.7), "salvage:corridor": Vector3(-1.9, 0.9, -5.5)}
const NAMES: Dictionary = {"water": "ÁGUA", "kitchen": "COZINHA", "workshop": "OFICINA", "dormitory": "DORMITÓRIO"}
var state: CoreState
var navigation: Navigation = Navigation.new()
var bunker: Node3D
var wing: Node3D
var player: CharacterBody3D
var camera: Camera3D
var workers: Dictionary = {}
var initialized: bool = false
var paused: bool = false
var booting: bool = false
var panel: PanelContainer
var panel_column: VBoxContainer
var action: Button
var hud: Label
var hint: Label
var menu: Button
var selected: String = ""
var message: String = "Ligue o gerador para recuperar CZI-07."
var sector_lights: Dictionary = {}
var sector_indicators: Dictionary = {}
var conduits: Dictionary = {}
var coils: Array[Node3D] = []
var scrap: Dictionary = {}
var material_pieces: Array[Node3D] = []
var save_path: String = Save.PATH
var save_timer: float = 0.0
var pulse: float = 0.0

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	for i: int in range(5):
		await get_tree().process_frame
	bunker = get_parent() as Node3D
	state = GameState.base_core
	if state == null:
		return
	wing = bunker.get_node("ServiceWing") as Node3D
	player = bunker.get("player") as CharacterBody3D
	camera = bunker.get("gameplay_camera") as Camera3D
	bunker.set_process(false)
	bunker.set("power_started", true)
	(bunker.get("interact_button") as Button).visible = false
	(bunker.get_node("GreyboxUI") as CanvasLayer).visible = false
	var decision: Node = bunker.get_node("DormitoryDecision")
	decision.set_process(false)
	for actor: Node3D in (decision.get("group_markers") as Dictionary).values():
		actor.visible = false
	wing.set_process(false)
	_reframe_world()
	_build_ui()
	player.position = Vector3(1.4, 0.9, -2.0)
	camera.set("follow_min", Vector2(-0.7, -7.0))
	camera.set("follow_max", Vector2(11, 5))
	camera.set("camera_offset", Vector3(8.5, 10.5, 10))
	camera.size = 12
	camera.call("_snap_to_target")
	camera.look_at(player.position + Vector3(0, 0.4, 0))
	camera.set("zoom_enabled", true)
	refresh_world()
	await get_tree().physics_frame
	await get_tree().physics_frame
	navigation.rebuild(get_world_3d(), [player.get_rid()])
	_restore_player()
	for i: int in range(CoreState.IDS.size()):
		var id: String = CoreState.IDS[i]
		var worker: CharacterBody3D = CharacterBody3D.new()
		worker.name = id.capitalize() + "Worker"
		worker.set_script(Worker)
		worker.set("citizen_id", id)
		worker.set("core", self)
		worker.position = _safe_position(state.saved_positions.get(id), Vector3(-1.2 + i * 0.8, 0.9, 4.7))
		add_child(worker)
		workers[id] = worker
	initialized = true
	for worker: Node in workers.values():
		worker.call("reconsider")
	refresh_world()

func _safe_position(saved, fallback: Vector3) -> Vector3:
	if saved is Array and saved.size() == 3:
		for number in saved:
			if not (number is int or number is float) or not is_finite(float(number)):
				return fallback
		var p := Vector3(float(saved[0]), 0.9, float(saved[2]))
		var cell: Vector2i = navigation.cell(p)
		if navigation.grid.is_in_boundsv(cell) and not navigation.grid.is_point_solid(cell):
			return Vector3(cell.x * navigation.CELL, 0.9, cell.y * navigation.CELL)
	return fallback

func _restore_player() -> void:
	player.position = _safe_position(state.saved_positions.get("elias"), player.position)
	camera.call("_snap_to_target")

func _box(name_: String, size_: Vector3, pos: Vector3, color: Color, solid: bool = false) -> Node3D:
	if solid:
		return bunker.call("_add_static_box", name_, size_, pos, color, self) as Node3D
	var mesh := BoxMesh.new()
	mesh.size = size_
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh.material = mat
	var item := MeshInstance3D.new()
	item.name = name_
	item.mesh = mesh
	item.position = pos
	add_child(item)
	return item

func _reframe_world() -> void:
	# Bring the existing generator into the central corridor, preserving story geometry in story mode.
	for name_: String in ["AuxGenerator", "GeneratorTop", "GeneratorPipe"]:
		(bunker.get_node("Geometry/GeneratorRoom/" + name_) as Node3D).position.z += 5.0
	var dressing: Node3D = bunker.get_node("BunkerDressing") as Node3D
	dressing.set_process(false)
	for child: Node in dressing.get_children():
		if child.name.begins_with("GeneratorBase") or child.name.begins_with("MachineCorner") or child.name.begins_with("CoolingGrille") or child.name.begins_with("ControlPanel") or child.name.begins_with("Gauge") or child.name.begins_with("SafetyStripe"):
			(child as Node3D).position.z += 5.0
		if child is Label3D:
			(child as Label3D).visible = false
	for wall: MeshInstance3D in dressing.get("cutaway_meshes"):
		wall.scale.y = 0.22
		wall.position.y = -1.18
	for wall: MeshInstance3D in wing.get("back_walls"):
		wall.scale.y = 0.18
		wall.position.y = -1.08
	# Reduce the foreground partition without altering its collision.
	var partition: MeshInstance3D = bunker.get_node("Geometry/DormitoryRoom/DormitoryPartitionFront").get_child(0) as MeshInstance3D
	partition.scale.y = 0.20
	partition.position.y = -1.24
	for label: Node in wing.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	# Close the old outer edge: all actors remain on the supported continuous floor.
	_box("EntrySafetyGate", Vector3(5.7, 0.9, 0.2), Vector3(0, 0.45, 7.4), Color("485b54"), true)
	for item_name: String in ["EntryLocker", "MaintenanceCabinet", "DormLocker"]:
		var prop: MeshInstance3D = dressing.get_node_or_null(item_name) as MeshInstance3D
		if prop != null and prop.mesh is BoxMesh:
			_box(item_name + "Solid", (prop.mesh as BoxMesh).size, prop.position, Color.WHITE, true).get_child(0).set("visible", false)
	_box("GeneratorFootprint", Vector3(2.1, 1.4, 1.5), Vector3(0, 0.7, -3.25), Color.WHITE, true).get_child(0).set("visible", false)
	for z: float in [1.72, 2.94]:
		_box("BenchSolid", Vector3(1.9, 0.45, 0.24), Vector3(6, 0.225, z), Color.WHITE, true).get_child(0).set("visible", false)
	# Tank/shelf are visible solids, not walk-through decorations in the base simulation.
	_box("TankCollider", Vector3(0.95, 1.7, 0.80), Vector3(4.15, 0.85, -0.2), Color("617b73"), true).get_child(0).set("visible", false)
	for crate: MeshInstance3D in wing.get("food_crates"):
		crate.visible = false
	_box("WorkshopBench", Vector3(2.0, 0.9, 0.8), Vector3(10.25, 0.45, -0.2), Color("81745c"), true)
	_box("WorkshopTop", Vector3(2.1, 0.12, 0.9), Vector3(10.25, 0.96, -0.2), Color("b0a382"))
	for i: int in range(5):
		material_pieces.append(_box("RecoveredMaterial", Vector3(0.23, 0.16, 0.4), Vector3(9.5 + i * 0.34, 1.1, -0.2), Color("c4a760")))
	for i: int in range(3):
		var coil := MeshInstance3D.new()
		coil.name = "GeneratorUpgradeCoil%d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.21
		mesh.bottom_radius = 0.21
		mesh.height = 0.72
		mesh.radial_segments = 16
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("b78b46")
		mat.metallic = 0.45
		mat.roughness = 0.4
		mesh.material = mat
		coil.mesh = mesh
		coil.position = Vector3(-0.58 + i * 0.56, 1.86, -3.25)
		add_child(coil)
		coils.append(coil)
	_box("GeneratorCrown", Vector3(2.0, 0.12, 1.35), Vector3(0, 2.30, -3.25), Color("40534c"))
	for sector: String in ["water", "kitchen", "workshop", "dormitory"]:
		var target: Vector3 = Vector3(4.7, 0.03, -4.5) if sector == "dormitory" else WORK_POSITIONS[sector] as Vector3
		target.y = 0.03
		var segments: Array[Node3D] = []
		var z: float = -3.7 if sector == "dormitory" else 1.2
		var x: float = 1.9 + ["water", "kitchen", "workshop", "dormitory"].find(sector) * 0.07
		segments.append(_box("PowerCable", Vector3(0.045, 0.04, absf(z + 3.25) + 0.2), Vector3(x, 0.04, (z - 3.25) / 2), Color("34413c")))
		segments.append(_box("SectorCable", Vector3(target.x - x, 0.04, 0.045), Vector3((target.x + x) / 2, 0.04, z), Color("34413c")))
		conduits[sector] = segments
		var light := OmniLight3D.new()
		light.position = target + Vector3(0, 2.3, 0)
		light.light_color = Color("9acbd1") if sector == "water" else Color("f4cf88")
		light.omni_range = 3.4
		add_child(light)
		sector_lights[sector] = light
		var indicator: Node3D = _box("CircuitIndicator", Vector3(0.5, 0.08, 0.12), target + Vector3(0, 1.45, -0.7), Color("715344"))
		sector_indicators[sector] = indicator
	for id: String in ["entry", "corridor"]:
		var p: Vector3 = POINTS["salvage:" + id]
		scrap[id] = _box("SalvageCrate", Vector3(0.65, 0.45, 0.65), Vector3(p.x, 0.225, p.z), Color("b49b65"), true)
	# Physical sockets show the expansion path without ten empty rooms.
	_box("WorkshopDoorSign", Vector3(0.08, 0.36, 0.7), Vector3(8.3, 1.85, 1.2), Color("9d8759"))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BaseUI"
	layer.layer = 12
	add_child(layer)
	(bunker.get("virtual_stick") as Control).reparent(layer)
	(bunker.get("virtual_stick") as Control).visible = true
	var header := PanelContainer.new()
	header.position = Vector2(24, 24)
	header.size = Vector2(672, 128)
	layer.add_child(header)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 23)
	header.add_child(hud)
	hint = Label.new()
	hint.position = Vector2(32, 165)
	hint.size = Vector2(540, 80)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 19)
	layer.add_child(hint)
	action = Button.new()
	action.name = "BaseContextAction"
	action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	action.offset_left = -275
	action.offset_right = -24
	action.offset_top = -205
	action.offset_bottom = -120
	action.add_theme_font_size_override("font_size", 21)
	action.pressed.connect(func() -> void: open_panel(closest_station()))
	layer.add_child(action)
	menu = Button.new()
	menu.text = "•••"
	menu.position = Vector2(602, 163)
	menu.size = Vector2(90, 58)
	menu.pressed.connect(func() -> void: open_panel("menu"))
	layer.add_child(menu)
	for i: int in range(2):
		var zoom := Button.new()
		zoom.text = "+" if i == 0 else "−"
		zoom.position = Vector2(632, 248 + i * 66)
		zoom.size = Vector2(60, 60)
		zoom.pressed.connect(func() -> void: camera.call("apply_zoom", 0.85 if i == 0 else 1.18))
		layer.add_child(zoom)
	panel = PanelContainer.new()
	panel.name = "BaseStationPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = 290
	panel.offset_bottom = -30
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	panel_column = VBoxContainer.new()
	panel_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_column.add_theme_constant_override("separation", 14)
	scroll.add_child(panel_column)
	panel.visible = false

func _label(text_: String, size_: int = 23) -> void:
	var label := Label.new()
	label.text = text_
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size_)
	panel_column.add_child(label)

func _button(text_: String, callback: Callable, disabled: bool = false) -> void:
	var button := Button.new()
	button.text = text_
	button.custom_minimum_size.y = 65
	button.add_theme_font_size_override("font_size", 21)
	button.disabled = disabled
	button.pressed.connect(callback)
	panel_column.add_child(button)

func closest_station() -> String:
	var closest: String = ""
	var distance: float = 1.85
	for id: String in POINTS:
		if id in ["services", "pantry"] and state.resources.areas[id]:
			continue
		if id in ["water", "kitchen", "workshop"] and not state.unlocked(id):
			continue
		if id.begins_with("salvage:") and state.salvage.has(id.trim_prefix("salvage:")):
			continue
		var p: Vector3 = POINTS[id]
		var d: float = Vector2(player.position.x - p.x, player.position.z - p.z).length()
		if d < distance:
			distance = d
			closest = id
	return closest

func open_panel(id: String) -> bool:
	if not initialized or booting or id.is_empty() or (id != "menu" and id != closest_station()):
		return false
	selected = id
	paused = true
	player.call("set_input_enabled", false)
	(bunker.get("virtual_stick") as Control).call("release_control")
	(bunker.get("virtual_stick") as Control).visible = false
	camera.set("zoom_enabled", false)
	panel.visible = true
	_render_panel()
	return true

func _render_panel() -> void:
	for child: Node in panel_column.get_children():
		panel_column.remove_child(child)
		child.queue_free()
	_button("FECHAR", close_panel)
	if selected == "generator":
		_label("GERADOR CZI-07 • NÍVEL %d" % state.power.level, 27)
		_label("Energia %d / %d • %s" % [state.power.consumption(), state.power.capacity(), "LIGADO" if state.power.running else "DESLIGADO"])
		_button("DESLIGAR GERADOR" if state.power.running else "ATIVAR GERADOR", toggle_generator)
		_button("MELHORAR • %d MATERIAIS" % state.upgrade_cost() if state.power.level < 3 else "GERADOR NO NÍVEL MÁXIMO", upgrade_generator, state.power.level >= 3 or state.resources.parts < state.upgrade_cost() or not state.power.running)
		_label("CIRCUITOS • escolha onde usar energia", 20)
		for sector: String in state.power.DEMAND:
			var supplied: bool = state.power.supplied(sector)
			var text_: String = "%s • %d E • %s" % [NAMES[sector], state.power.DEMAND[sector], "LIGADO" if supplied else "DESLIGADO"]
			if not state.unlocked(sector):
				text_ = NAMES[sector] + " • RECUPERE O SETOR"
			_button(text_, switch_circuit.bind(sector), not state.unlocked(sector))
	elif selected in ["services", "pantry"]:
		var cost: int = 2 if selected == "services" else 4
		_label("RECUPERAR SERVIÇOS" if selected == "services" else "RECUPERAR OFICINA", 27)
		_label("Água e cozinha aguardam energia e trabalhadores." if selected == "services" else "Recupere peças e prepare a próxima expansão.", 21)
		_button("REPARAR PORTA • %d MATERIAIS" % cost, repair_selected, not state.power.running or state.resources.parts < cost)
		if not state.power.running:
			_label("Ligue o gerador primeiro.", 19)
	elif selected in ["water", "kitchen", "workshop"]:
		_label(NAMES[selected], 27)
		_label("%d E • %s" % [state.power.DEMAND[selected], "CIRCUITO ATIVO" if state.power.supplied(selected) else "SEM ENERGIA"])
		_button("DESLIGAR CIRCUITO" if state.power.enabled[selected] else "LIGAR CIRCUITO", switch_circuit.bind(selected))
		_label({"water": "+2 água por ciclo de trabalho", "kitchen": "1 mantimento + 1 água → 2 porções", "workshop": "+1 material por ciclo de trabalho"}[selected], 21)
		for id: String in CoreState.IDS:
			_button("%s • %s" % [id.capitalize(), "ATRIBUÍDO" if state.jobs[id] == selected else "ATRIBUIR"], assign_worker.bind(id, selected))
		_label("O trabalho começa ao chegar. Pausas para comer, beber e descansar são automáticas.", 18)
	elif selected.begins_with("salvage:"):
		_label("SUPRIMENTOS RECUPERÁVEIS", 27)
		_label("+4 materiais • +8 mantimentos")
		_button("RECOLHER", collect_selected)
	elif selected == "menu":
		_label("CZI-07 VOLTA À VIDA", 27)
		_label("A base produz enquanto você joga. Não há perda de recursos ao fechar o jogo.", 21)
		_button("SALVAR AGORA", func() -> void: save_now(); close_panel())
		_button("JOGAR O PRÓLOGO", play_prologue)
		_label("Água e cozinha → gerador nível 2 → oficina. Explore as caixas no corredor e na entrada.", 21)
		_label("Missões, heróis e expedições entram após este núcleo.", 18)
	_label(message, 18)

func close_panel() -> void:
	panel.visible = false
	paused = false
	player.call("set_input_enabled", true)
	(bunker.get("virtual_stick") as Control).visible = true
	camera.set("zoom_enabled", true)

func toggle_generator() -> void:
	if selected != "generator" or closest_station() != "generator" or booting:
		return
	if state.power.running:
		state.power.running = false
		message = "Gerador desligado. Os circuitos pararam."
		refresh_world()
		save_now()
		_render_panel()
		return
	close_panel()
	booting = true
	message = "Restabelecendo o núcleo…"
	for stage: int in range(1, 4):
		(bunker.get("generator_light") as OmniLight3D).light_energy = stage * 1.4
		(bunker.get("corridor_light") as OmniLight3D).light_energy = stage * 0.6
		await get_tree().create_timer(0.5).timeout
	state.power.running = true
	booting = false
	message = "O núcleo voltou. Recupere SERVIÇOS na porta do corredor."
	refresh_world()
	save_now()

func upgrade_generator() -> bool:
	if selected != "generator" or closest_station() != "generator" or not state.upgrade():
		return false
	message = "Gerador ampliado: %d de capacidade." % state.power.capacity()
	refresh_world()
	save_now()
	_render_panel()
	return true

func switch_circuit(sector: String) -> bool:
	if not (selected == "generator" or selected == sector) or not state.unlocked(sector) or not state.power.switch_sector(sector):
		message = "Capacidade insuficiente. Desligue outro circuito ou melhore o gerador."
		_render_panel()
		return false
	message = "%s: %s" % [NAMES[sector], "energia conectada" if state.power.supplied(sector) else "energia desligada"]
	refresh_world()
	save_now()
	_render_panel()
	return true

func repair_selected() -> bool:
	if selected != closest_station() or not state.repair(selected):
		return false
	message = "Porta recuperada. Entre, conecte energia e atribua um trabalhador."
	close_panel()
	refresh_world()
	_rebuild_navigation()
	save_now()
	return true

func _rebuild_navigation() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	navigation.rebuild(get_world_3d(), [player.get_rid()])
	for worker: Node in workers.values():
		worker.call("reconsider")

func assign_worker(id: String, sector: String) -> bool:
	if selected != sector or closest_station() != sector or not state.assign(id, sector):
		return false
	for worker: Node in workers.values():
		worker.call("reconsider")
	message = "%s está a caminho de %s." % [id.capitalize(), NAMES[sector]]
	close_panel()
	save_now()
	return true

func collect_selected() -> bool:
	var id: String = selected.trim_prefix("salvage:")
	if selected != closest_station() or not state.collect_salvage(id):
		return false
	(scrap[id] as StaticBody3D).collision_layer = 0
	message = "Materiais e mantimentos recuperados."
	close_panel()
	refresh_world()
	_rebuild_navigation()
	save_now()
	return true

func refresh_world() -> void:
	state.resources.powered = state.power.running
	wing.call("sync_state")
	(wing.get("service_light") as OmniLight3D).light_energy = 0
	(wing.get("pantry_light") as OmniLight3D).light_energy = 0
	for label: Node in wing.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	for crate: MeshInstance3D in wing.get("food_crates"):
		crate.visible = false
	for sector: String in sector_lights:
		var lit: bool = state.power.supplied(sector) and state.unlocked(sector)
		(sector_lights[sector] as OmniLight3D).light_energy = 2.5 if lit else 0
		for item: MeshInstance3D in conduits[sector]:
			var mat: StandardMaterial3D = item.mesh.material as StandardMaterial3D
			mat.albedo_color = Color("c8b16c") if lit else Color("34413c")
			mat.emission_enabled = lit
			mat.emission = Color("b5a05f")
			mat.emission_energy_multiplier = 0.6
		var indicator: MeshInstance3D = sector_indicators[sector] as MeshInstance3D
		var material: StandardMaterial3D = indicator.mesh.material as StandardMaterial3D
		material.albedo_color = Color("92d6ae") if lit else Color("695249")
		material.emission_enabled = lit
		material.emission = Color("92d6ae")
	for i: int in range(coils.size()):
		coils[i].visible = i < state.power.level
	for i: int in range(material_pieces.size()):
		material_pieces[i].visible = state.resources.parts > i * 2
	for id: String in scrap:
		(scrap[id] as Node3D).visible = not state.salvage.has(id)
		(scrap[id] as StaticBody3D).collision_layer = 0 if state.salvage.has(id) else 1
	(wing.get("steam") as Node3D).visible = state.power.supplied("kitchen") and workers.values().any(func(w: Node) -> bool: return w.get("state") == "WORKING" and w.get("station") == "kitchen")
	bunker.set("power_complete", state.power.running)
	(bunker.get("generator_light") as OmniLight3D).position = Vector3(0, 2.6, -3.25)
	(bunker.get("generator_light") as OmniLight3D).light_energy = 4.2 if state.power.running else 0.25
	(bunker.get("corridor_light") as OmniLight3D).light_energy = 1.5 if state.power.running else 0.25
	(bunker.get("dormitory_light") as OmniLight3D).light_energy = 0
	(bunker.get("entry_light") as OmniLight3D).light_energy = 0.8 if state.power.running else 0.15
	(bunker.get("emergency_light") as OmniLight3D).light_energy = 0.35 if not state.power.running else 0.0
	var fill: DirectionalLight3D = bunker.get("interior_fill_light") as DirectionalLight3D
	fill.light_energy = 0.45
	(bunker.get("bunker_environment") as Environment).ambient_light_energy = 0.28
	var dressing: Node = bunker.get_node("BunkerDressing")
	for fixture: MeshInstance3D in dressing.get("fixtures"):
		var mat: StandardMaterial3D = fixture.mesh.material as StandardMaterial3D
		mat.emission_enabled = state.power.running and fixture.position.x < 2.9
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.5
	camera.set("follow_max", Vector2(11, 5))

func production_feedback(sector: String) -> void:
	message = {"water": "Água chegou ao reservatório.", "kitchen": "Refeição pronta na cozinha.", "workshop": "Uma peça foi recuperada na oficina."}[sector]
	refresh_world()
	var lamp: OmniLight3D = sector_lights[sector] as OmniLight3D
	var flash := create_tween()
	flash.tween_property(lamp, "light_energy", 3.0, 0.15)
	flash.tween_property(lamp, "light_energy", 2.5, 0.4)

func save_now() -> bool:
	if not initialized:
		return false
	state.saved_positions["elias"] = [player.position.x, player.position.y, player.position.z]
	for id: String in workers:
		var p: Vector3 = (workers[id] as Node3D).position
		state.saved_positions[id] = [p.x, p.y, p.z]
	var data: Dictionary = state.snapshot()
	data["story"] = {"sleep_assignment": GameState.bunker_sleep_assignment, "citizens": GameState.citizens.duplicate(true)}
	var ok: bool = Save.write(data, save_path) == OK
	if not ok:
		message = "Não foi possível salvar neste navegador."
	return ok

func play_prologue() -> void:
	save_now()
	GameState.reset_new_game()
	get_tree().change_scene_to_file("res://scenes/vertical_slice/scene_01_greybox.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and initialized:
		save_now()

func _process(delta: float) -> void:
	if not initialized:
		return
	if not paused:
		state.elapsed += minf(delta, 0.1)
		save_timer += delta
		pulse += delta
		if state.power.running:
			var rotor: Node3D = bunker.get_node("BunkerDressing").get("rotor") as Node3D
			rotor.rotation.z += delta * 2
	if save_timer > 8.0:
		save_timer = 0
		save_now()
	var near: String = closest_station()
	action.visible = not near.is_empty() and not panel.visible and not booting
	action.text = {"generator": "GERADOR", "services": "RECUPERAR\nSERVIÇOS", "water": "ÁGUA / TRABALHO", "kitchen": "COZINHA / TRABALHO", "pantry": "RECUPERAR\nOFICINA", "workshop": "OFICINA / TRABALHO", "salvage:entry": "RECOLHER\nSUPRIMENTOS", "salvage:corridor": "RECOLHER\nSUPRIMENTOS"}.get(near, "")
	hud.text = "  CZI-07 • GERADOR NV. %d\n  ENERGIA %d / %d    MATERIAIS %d\n  ÁGUA %d    MANTIMENTOS %d    PORÇÕES %d" % [state.power.level, state.power.consumption(), state.power.capacity(), state.resources.parts, state.resources.water, state.resources.food, state.resources.meals]
	hint.text = message

func work_position(sector: String) -> Vector3:
	return WORK_POSITIONS[sector] as Vector3
