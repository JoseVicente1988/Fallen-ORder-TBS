extends TileMap

const BASE_LAYER = 0
const COLLISION_LAYER = 1
const MOVEMENT_LAYER = 2
const MOVEMENT_TILE_ID = 0
const MOVEMENT_ATLAS = Vector2i(0, 4)
const HOVER_LAYER = 2
const HOVER_TILE_ID = 0

var valid_move_cells: Array[Vector2i] = []
var hover_enabled := true

func local_to_cell(pos: Vector2) -> Vector2i:
	return local_to_map(pos)

func cell_to_local_pos(cell: Vector2i) -> Vector2:
	return map_to_local(cell)

func clear_movement_range():
	for cell in get_used_cells(MOVEMENT_LAYER):
		var tile_id = get_cell_source_id(MOVEMENT_LAYER, cell)
		if tile_id == MOVEMENT_TILE_ID:
			set_cell(MOVEMENT_LAYER, cell, -1)

func is_cell_walkable(cell: Vector2i, unit) -> bool:
	# Verificar si hay tile base
	var tile_data := get_cell_tile_data(BASE_LAYER, cell)
	if tile_data == null:
		return false

	# Obtener tipo de terreno
	var terrain = tile_data.get_custom_data("terrain")

	# Verificar si el terreno es caminable para esta unidad
	if not is_terrain_walkable(terrain, unit):
		return false

	# Verificar si hay obstáculo en la capa de colisión
	var obstacle_tile := get_cell_tile_data(COLLISION_LAYER, cell)
	if obstacle_tile != null:
		return false

	# Verificar si hay otra unidad en la misma celda
	for other in get_tree().get_nodes_in_group("unidades_aliadas") + get_tree().get_nodes_in_group("unidades_enemigas"):
		if other == unit:
			continue
		var other_cell := local_to_cell(to_local(other.global_position))
		if other_cell == cell:
			return false

	return true

func get_neighbors(cell: Vector2i) -> Array:
	var directions = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var neighbors = []

	for dir in directions:
		var neighbor = cell + dir
		if get_cell_tile_data(BASE_LAYER, neighbor) != null:
			neighbors.append(neighbor)

	return neighbors

func get_move_cost(cell: Vector2i, unit) -> int:
	var tile_data = get_cell_tile_data(BASE_LAYER, cell)
	if tile_data == null:
		return -1

	var extra_cost = tile_data.get_custom_data("cost")
	if extra_cost == null or int(extra_cost) < 0:
		extra_cost = 0

	var total_cost = unit.move_cost_per_tile + int(extra_cost)
	return total_cost

func show_movement_range(origin_cell: Vector2i, max_range: int, unit):
	valid_move_cells.clear()
	var frontier: Array[Vector2i] = [origin_cell]
	var cost_so_far: Dictionary = {}
	cost_so_far[origin_cell] = 0

	clear_movement_range()

	var _tile_set := get_tileset()
	if not _tile_set.has_source(MOVEMENT_TILE_ID):
		push_error("❌ El TileSet no tiene fuente para MOVEMENT_TILE_ID")
		return

	var source := _tile_set.get_source(MOVEMENT_TILE_ID)

	while frontier.size() > 0:
		var current = frontier.pop_front()
		var current_cost = cost_so_far[current]

		if current_cost <= max_range:
			if source is TileSetAtlasSource and source.has_tile(MOVEMENT_ATLAS):
				set_cell(MOVEMENT_LAYER, current, MOVEMENT_TILE_ID, MOVEMENT_ATLAS)
				valid_move_cells.append(current)
			else:
				push_warning("⚠️ El tile no existe en el atlas en " + str(MOVEMENT_ATLAS))

		for neighbor in get_neighbors(current):
			if not is_cell_walkable(neighbor, unit):
				continue

			var move_cost = get_move_cost(neighbor, unit)
			if move_cost == -1 or move_cost <= 0:
				move_cost = unit.move_cost_per_tile

			var new_cost = current_cost + move_cost

			if new_cost > max_range:
				continue

			if not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				frontier.append(neighbor)

func get_cells_in_radius(center: Vector2i, radius: int) -> Array:
	var cells := []
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var offset = Vector2i(x, y)
			if offset.length() <= radius:
				cells.append(center + offset)
	return cells

func find_path(start: Vector2i, goal: Vector2i, unit) -> Array:
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var cost_so_far: Dictionary = {}
	cost_so_far[start] = 0

	while frontier.size() > 0:
		var current_node = frontier.pop_front()

		if current_node == goal:
			break

		for neighbor in get_neighbors(current_node):
			if not is_cell_walkable(neighbor, unit):
				continue

			var move_cost = get_move_cost(neighbor, unit)
			if move_cost == -1:
				continue

			var new_cost = cost_so_far[current_node] + move_cost
			if not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				came_from[neighbor] = current_node
				frontier.append(neighbor)

	var path: Array[Vector2i] = []
	var current = goal
	while current != start and came_from.has(current):
		path.insert(0, current)
		current = came_from[current]

	if current == start:
		path.insert(0, start)

	# 🧭 Mostrar el path y coste total
	var total_cost := 0
	for i in range(1, path.size()):
		var cell = path[i]
		var tile_cost = get_move_cost(cell, unit)
		if tile_cost != -1:
			total_cost += tile_cost


	return path

func has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var dx = to_cell.x - from_cell.x
	var dy = to_cell.y - from_cell.y
	var steps = max(abs(dx), abs(dy))

	if steps == 0:
		return true

	var direction = Vector2(dx, dy) / float(steps)

	for i in range(1, steps):
		var pos = Vector2(from_cell.x, from_cell.y) + direction * i
		var cell = Vector2i(round(pos.x), round(pos.y))

		if not is_cell_transparent(cell):
			return false

	return true

func is_cell_transparent(cell: Vector2i) -> bool:
	var tile_id = get_tile_id_at(cell)
	var blocking_tiles = [1, 2, 3] # ← Ajusta según tus obstáculos
	return not blocking_tiles.has(tile_id)

func get_tile_id_at(cell: Vector2i, layer := 0) -> int:
	var atlas_coords = get_cell_atlas_coords(layer, cell)
	if atlas_coords == Vector2i(-1, -1):
		return -1
	return get_cell_source_id(layer, cell)

func is_terrain_walkable(terrain: String, unit) -> bool:
	# Si la unidad puede volar, ignora el terreno
	if "can_fly" in unit and unit.can_fly:
		return true

	# Si puede nadar, permite agua
	if terrain == "agua":
		return "can_swim" in unit and unit.can_swim

	# Terrenos prohibidos
	var blocked_terrain := ["lava", "acantilado", "veneno"]
	if terrain in blocked_terrain:
		return false

	# Terreno caminable por defecto
	return true
