extends Node

var building_data := {}
var selected_building_id := ""
var is_building_mode := false
var grid: TileMap
var ghost_building: Node2D = null
var ghost_sprite: Sprite2D = null

# Configuración de tiles
const BUILD_LAYER := 2
const TILE_SOURCE := 0  # Ajusta si tu atlas tiene otro ID
const TILE_VALID := Vector2i(0, 4)
const TILE_INVALID := Vector2i(1, 5)
var occupied_cells := {} # cell → building



func _ready():
	grid = get_node("/root/Main/Grid")  # Ajusta si tu ruta es distinta
	load_building_data()
	set_process(true)

func load_building_data():
	var path = "res://STRUCTURES/buildings.json"
	if not FileAccess.file_exists(path):
		push_error("Archivo de edificios no encontrado: " + path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	var parsed = JSON.parse_string(json_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Error al parsear JSON de edificios")
		return

	building_data = parsed

func start_building_mode(building_id: String):
	selected_building_id = building_id
	is_building_mode = true

	ghost_building = create_ghost_building(building_id)
	if ghost_building != null:
		add_child(ghost_building)
		print("Ghost instanciado correctamente")
	else:
		print("Ghost no se pudo crear")

func cancel_building_mode():
	selected_building_id = ""
	is_building_mode = false

	if ghost_building:
		ghost_building.queue_free()
		ghost_building = null
		ghost_sprite = null

	# Limpiar capa de construcción
	for used_cell in grid.get_used_cells(BUILD_LAYER):
		grid.set_cell(BUILD_LAYER, used_cell, -1)

func create_ghost_building(building_id: String) -> Node2D:
	var info = building_data.get(building_id, {})
	if not info.has("scene_path"):
		push_error("Falta 'scene_path' en la definición del edificio: " + building_id)
		return null

	var scene_path = info["scene_path"]
	var scene = load(scene_path)
	if scene == null:
		push_error("No se pudo cargar la escena: " + scene_path)
		return null

	var building_instance = scene.instantiate()
	if building_instance == null:
		push_error("No se pudo instanciar la escena del edificio")
		return null

	# Buscar el AnimatedSprite2D dentro del edificio
	var ghost_sprite: AnimatedSprite2D = null
	for child in building_instance.get_children():
		if child is AnimatedSprite2D:
			ghost_sprite = child.duplicate()
			break

	if ghost_sprite == null:
		push_error("No se encontró AnimatedSprite2D en la escena del edificio")
		return null

	# Configurar el sprite como ghost
	ghost_sprite.modulate = Color(1, 1, 1, 0.5)
	#ghost_sprite.play()

	# Crear un contenedor para el ghost
	var ghost := Node2D.new()
	ghost.name = "GhostBuilding"
	ghost.add_child(ghost_sprite)

	# Posición inicial (puedes actualizarla luego con el mouse)
	ghost.position = Vector2(200, 200)

	return ghost

func _process(delta):
	if is_building_mode and ghost_building:
		var global_mouse_pos := grid.get_global_mouse_position()
		var local_mouse_pos := grid.to_local(global_mouse_pos)
		var cell := grid.local_to_map(local_mouse_pos)

		var world_pos := grid.map_to_local(cell)
		ghost_building.position = world_pos

		show_building_preview(cell)

func show_building_preview(cell: Vector2i):
	if not is_building_mode or selected_building_id == "":
		return

	var info = building_data.get(selected_building_id, {})
	var size = Vector2i(info["size"][1], info["size"][0])
	var layout = info["layout"]

	var is_valid := true
	var valid_cells := []
	var invalid_cells := []

	for y in range(size.y):
		for x in range(size.x):
			if layout[y][x] == 1:
				var check_cell := cell + Vector2i(x, y)
				var tile_layer0 := grid.get_cell_tile_data(0, check_cell)
				var tile_layer1 := grid.get_cell_tile_data(1, check_cell)

				var blocked := tile_layer0 == null or tile_layer1 != null or has_unit_at(check_cell) or has_building_at(check_cell)
				if blocked:
					is_valid = false
					invalid_cells.append(check_cell)
				else:
					valid_cells.append(check_cell)

	# Limpiar capa de construcción
	for used_cell in grid.get_used_cells(BUILD_LAYER):
		grid.set_cell(BUILD_LAYER, used_cell, -1)

	# Pintar tiles
	for c in valid_cells:
		grid.set_cell(BUILD_LAYER, c, TILE_SOURCE, TILE_VALID)
	for c in invalid_cells:
		grid.set_cell(BUILD_LAYER, c, TILE_SOURCE, TILE_INVALID)

	# Actualizar color del sprite fantasma
	if ghost_sprite:
		ghost_sprite.modulate = Color(0, 1, 0, 0.5) if is_valid else Color(1, 0, 0, 0.5)

func place_building_at_mouse():
	if not is_building_mode:
		return

	var global_mouse_pos := grid.get_global_mouse_position()
	var local_mouse_pos := grid.to_local(global_mouse_pos)
	var cell := grid.local_to_map(local_mouse_pos)

	var info = building_data.get(selected_building_id, {})
	var size = Vector2i(info["size"][1], info["size"][0])
	var layout = info["layout"]

	# Verificar validez del área completa
	for y in range(size.y):
		for x in range(size.x):
			if layout[y][x] == 1:
				var check_cell := cell + Vector2i(x, y)
				var tile_layer0 := grid.get_cell_tile_data(0, check_cell)
				var tile_layer1 := grid.get_cell_tile_data(1, check_cell)

				if tile_layer0 == null or tile_layer1 != null or has_unit_at(check_cell) or has_building_at(check_cell):
					show_warning("Terreno ocupado o inválido")
					return

	# Instanciar edificio desde escena
	if not info.has("scene_path"):
		push_error("Falta 'scene_path' en la definición del edificio: " + selected_building_id)
		return

	var scene := load(info["scene_path"])
	if scene == null:
		push_error("No se pudo cargar la escena: " + info["scene_path"])
		return

	var building = scene.instantiate()
	if building == null:
		push_error("Error al instanciar el edificio desde la escena")
		return

	var world_pos := grid.map_to_local(cell)
	building.position = world_pos
	building.name = info["name"]
	building.get_node("AnimatedSprite2D").play()
	grid.add_child(building)
	
	# Registrar todas las celdas ocupadas
	for y in range(size.y):
		for x in range(size.x):
			if layout[y][x] == 1:
				var occupied_cell := cell + Vector2i(x, y)
				occupied_cells[occupied_cell] = building

	print("Edificio creado:", building.name)
	print("Posición:", building.position)
	
	cancel_building_mode()

func has_unit_at(cell: Vector2i) -> bool:
	for unit in get_tree().get_nodes_in_group("unidades"):
		if unit.has_method("get_cell_position") and unit.get_cell_position() == cell:
			return true
	return false

func has_building_at(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)


func show_warning(message: String):
	var label := $"../CanvasLayer/UI/warning"
	label.text = message
	label.modulate = Color(1, 0, 0)
	label.show()

	var tween := create_tween()
	tween.tween_property(label, "modulate", Color(1, 1, 1), 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(label, "hide")).set_delay(1.0)
