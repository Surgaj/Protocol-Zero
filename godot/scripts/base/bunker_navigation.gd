extends RefCounted

const CELL: float = 0.4
var grid: AStarGrid2D = AStarGrid2D.new()
var world: World3D

func rebuild(world_: World3D) -> void:
	world = world_
	grid.region = Rect2i(-8, -26, 39, 46)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.37
	capsule.height = 1.70
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	for x: int in range(grid.region.position.x, grid.region.end.x):
		for z: int in range(grid.region.position.y, grid.region.end.y):
			var p := Vector3(x * CELL, 0.93, z * CELL)
			query.transform = Transform3D(Basis.IDENTITY, p)
			var ground := PhysicsRayQueryParameters3D.create(Vector3(p.x, 0.04, p.z), Vector3(p.x, -0.2, p.z), 1)
			var solid: bool = world.direct_space_state.intersect_ray(ground).is_empty() or not world.direct_space_state.intersect_shape(query, 1).is_empty()
			grid.set_point_solid(Vector2i(x, z), solid)

func cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))

func nearest(point: Vector3) -> Vector2i:
	var center: Vector2i = cell(point)
	var best: Vector2i = Vector2i(999, 999)
	var distance: float = INF
	for x: int in range(center.x - 3, center.x + 4):
		for z: int in range(center.y - 3, center.y + 4):
			var id := Vector2i(x, z)
			if grid.is_in_boundsv(id) and not grid.is_point_solid(id):
				var d: float = Vector2(x * CELL - point.x, z * CELL - point.z).length_squared()
				if d < distance:
					distance = d
					best = id
	return best

func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var start: Vector2i = nearest(from)
	var end: Vector2i = nearest(to)
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(end):
		return path
	for point: Vector2 in grid.get_point_path(start, end):
		path.append(Vector3(point.x, 0.9, point.y))
	return path
