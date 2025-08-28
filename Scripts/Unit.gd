extends CharacterBody2D
class_name Unit

@warning_ignore("unused_signal")
signal action_completed
@warning_ignore("unused_signal")
signal selected

@export var unit_id: String = "soldier"

var grid: TileMap
var is_selected: bool = false
var has_moved: bool = false
var is_player_turn: bool = true

# Datos cargados desde JSON
var name_unit : String
var max_action_points: int
var action_points: int
var move_cost_per_tile: int = 10
var move_range: int
var hp: int
var ignora_obstaculos: bool

# Datos de ataque
var light_attack_data: Dictionary
var heavy_attack_data: Dictionary

# Animaciones
var current_direction: String = "down"
var sprite_frames: SpriteFrames
@onready var animated_sprite = $AnimatedSprite2D
@onready var energy_bar := $"../../CanvasLayer/UI/VBoxContainer/Action/VBoxContainer/ProgressBar"
@onready var energy_label := $"../../CanvasLayer/UI/VBoxContainer/Action/VBoxContainer/ProgressBar/Label"

func update_energy_display(current_energy: int, max_energy: int):
	if energy_bar == null or energy_label == null:
		return

	energy_bar.max_value = max_energy
	energy_bar.value = current_energy

	var ratio := float(current_energy) / float(max_energy)
	var color : Color

	if ratio > 0.66:
		color = Color(0.2, 0.8, 0.2) # Verde
	elif ratio > 0.33:
		color = Color(1.0, 0.8, 0.0) # Amarillo
	else:
		color = Color(0.9, 0.2, 0.2) # Rojo

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = color
	energy_bar.add_theme_stylebox_override("fill", stylebox)

	energy_label.text = "Energía: %d / %d" % [current_energy, max_energy]

func _ready():
	if not is_in_group("unidades_aliadas") and not is_in_group("unidades_enemigas"):
		add_to_group("unidades_enemigas")

	load_unit_data(unit_id)

	# Obtener el TileMap si no está asignado
	if grid == null:
		grid = $"../../Grid" # Ajustá el path si es distinto

	# Centrar la unidad en su celda
	if grid != null:
		var cell := grid.local_to_map(global_position)
		var centered_pos := grid.map_to_local(cell)
		global_position = grid.to_global(centered_pos)


func load_unit_data(_unit_id: String):
	var path = "res://UNITS/units.json"
	if not FileAccess.file_exists(path):
		push_error("Archivo JSON no encontrado: " + path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el archivo JSON")
		return

	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)

	if typeof(data) != TYPE_DICTIONARY or not data.has(_unit_id):
		push_error("Unidad no encontrada en JSON: " + _unit_id)
		return

	var unit_data = data[_unit_id]

	var required_fields = [
		"name","max_action_points", "move_cost_per_tile",
		"hp", "ignora_obstaculos", "sprite_frames_path",
		"light_attack", "heavy_attack"
	]

	for field in required_fields:
		if not unit_data.has(field):
			push_error("Falta el campo: " + field)
			return

	name_unit = String(unit_data["name"])
	max_action_points = int(unit_data["max_action_points"])
	action_points = max_action_points
	move_cost_per_tile = int(unit_data["move_cost_per_tile"])
	hp = int(unit_data["hp"])
	ignora_obstaculos = bool(unit_data["ignora_obstaculos"])

	light_attack_data = load_attack_data(unit_data["light_attack"])
	heavy_attack_data = load_attack_data(unit_data["heavy_attack"])

	var frames_path = unit_data["sprite_frames_path"]
	if ResourceLoader.exists(frames_path):
		var frames = load(frames_path)
		if frames is SpriteFrames:
			sprite_frames = frames
			animated_sprite.frames = sprite_frames
			play_animation("idle")

func load_attack_data(attack_name: String) -> Dictionary:
	var path = "res://Attacks/Attacks.json"
	if not FileAccess.file_exists(path):
		push_error("Archivo de ataques no encontrado: " + path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir el archivo de ataques")
		return {}

	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)

	if typeof(data) != TYPE_DICTIONARY or not data.has(attack_name):
		push_error("Ataque no encontrado: " + attack_name)
		return {}

	return data[attack_name]

func play_animation(base_name: String):
	var anim_name = base_name + "_" + current_direction
	if sprite_frames and sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		animated_sprite.play("idle_" + current_direction)

func set_direction(dir: String):
	if dir in ["up", "down", "left", "right"]:
		current_direction = dir

func set_selected(value: bool):
	is_selected = value

func deselect():
	is_selected = false

func move_along_path(path: Array):
	if path.size() < 2:
		emit_signal("action_completed")
		return

	var full_cost := 0
	for i in range(1, path.size()):
		var cell = path[i]
		var cost = grid.get_move_cost(cell, self)
		if cost == -1:
			full_cost = -1
			break
		full_cost += cost

	if full_cost == -1 or full_cost > action_points:
		if self.is_in_group("unidades_aliadas"):
			show_warning("¡No puedes llegar hasta ahí!")
		emit_signal("action_completed")
		return

	var total_cost := 0
	var valid_path := []

	for i in range(1, path.size()):
		var cell = path[i]
		var cost = grid.get_move_cost(cell, self)
		total_cost += cost
		valid_path.append(cell)

	var prev_cell = path[0]

	for cell in valid_path:
		var from_pos = grid.cell_to_local_pos(prev_cell)
		var to_pos = grid.cell_to_local_pos(cell)
		var delta_cell = cell - prev_cell

		var dir = get_isometric_direction(delta_cell)
		set_direction(dir)
		play_animation("walk")

		var tween = create_tween()
		var tween_step = tween.tween_property(self, "global_position", to_pos, 0.2)
		if tween_step != null:
			tween_step.set_trans(Tween.TRANS_LINEAR)
			tween_step.set_ease(Tween.EASE_IN_OUT)
			await tween_step.finished
		else:
			push_error("Tween falló en celda: " + str(cell))

		prev_cell = cell

	# ✅ Ahora sí: actualizar estado después del movimiento
	has_moved = true
	action_points -= total_cost

	play_animation("idle")
	emit_signal("action_completed")

func get_isometric_direction(delta: Vector2i) -> String:
	if delta == Vector2i(1, 0):
		return "right"
	elif delta == Vector2i(-1, 0):
		return "left"
	elif delta == Vector2i(0, 1):
		return "down"
	elif delta == Vector2i(0, -1):
		return "up"
	else:
		return current_direction




func _on_tween_finished():
	play_animation("idle")
	emit_signal("action_completed")

func get_enemies_in_range() -> Array:
	var origin = grid.local_to_cell(grid.to_local(global_position))
	var targets = []
	var my_group = "unidades_enemigas" if is_in_group("unidades_aliadas") else "unidades_aliadas"

	for enemy in get_tree().get_nodes_in_group(my_group):
		var enemy_cell = grid.local_to_cell(grid.to_local(enemy.global_position))
		var distance = origin.distance_to(enemy_cell)
		if distance <= max(light_attack_data.get("range", 1), heavy_attack_data.get("range", 1)):
			targets.append(enemy)

	return targets

func is_target_in_attack_range(attacker: Node2D, target: Node2D, range: int) -> bool:
	var grid = get_node("/root/Main/Grid")
	var attacker_cell = grid.local_to_cell(grid.to_local(attacker.global_position))
	var target_cell = grid.local_to_cell(grid.to_local(target.global_position))
	var distance = attacker_cell.distance_to(target_cell)
	return distance <= range

func can_attack_target(target: Unit, range: int) -> bool:
	var origin = grid.local_to_cell(grid.to_local(global_position))
	var target_cell = grid.local_to_cell(grid.to_local(target.global_position))
	if not is_target_in_attack_range(self, target, range):
		if self.is_in_group("unidades_aliadas"):
			show_warning("¡Objetivo fuera de rango!")
		return false

	if ignora_obstaculos:
		return true

	return grid.has_line_of_sight(origin, target_cell)

func attack_light(target):
	var cost = light_attack_data.get("energy_cost", 1)
	var damage = light_attack_data.get("damage", 1)
	var range = light_attack_data.get("range", 1)

	if action_points < cost or not can_attack_target(target, range):
		show_warning("¡No puedes atacar con " + light_attack_data.get("name", "Ataque Ligero") + "!")
		emit_signal("action_completed")
		return

	var target_cell = grid.local_to_cell(grid.to_local(target.global_position))
	var my_cell = grid.local_to_cell(grid.to_local(global_position))
	var delta = target_cell - my_cell

	if abs(delta.x) > abs(delta.y):
		set_direction("right" if delta.x > 0 else "left")
	else:
		set_direction("down" if delta.y > 0 else "up")

	play_animation("attack_" + current_direction)
	target.receive_damage(damage)
	show_warning("Usaste " + light_attack_data.get("name", "Blaster") + " y causaste " + str(damage) + " de daño.")
	action_points -= cost
	update_energy_display(action_points, max_action_points)

	await get_tree().create_timer(0.7).timeout
	play_animation("idle")
	emit_signal("action_completed")

func attack_heavy(target):
	var cost = heavy_attack_data.get("energy_cost", 1)
	var damage = heavy_attack_data.get("damage", 1)
	var range = heavy_attack_data.get("range", 1)

	if action_points < cost or not can_attack_target(target, range):
		show_warning("¡No puedes atacar con " + heavy_attack_data.get("name", "Ataque Pesado") + "!")
		emit_signal("action_completed")
		return

	var target_cell = grid.local_to_cell(grid.to_local(target.global_position))
	var my_cell = grid.local_to_cell(grid.to_local(global_position))
	var delta = target_cell - my_cell

	if abs(delta.x) > abs(delta.y):
		set_direction("right" if delta.x > 0 else "left")
	else:
		set_direction("down" if delta.y > 0 else "up")

	play_animation("attack")
	target.receive_damage(damage)
	show_warning("Usaste " + heavy_attack_data.get("name", "Riel") + " y causaste " + str(damage) + " de daño.")
	action_points -= cost
	update_energy_display(action_points, max_action_points)
	has_moved = true

	await get_tree().create_timer(0.7).timeout
	play_animation("idle")
	emit_signal("action_completed")

func receive_damage(amount: int):
	hp -= amount
	if hp <= 0:
		play_animation("death")
		await get_tree().create_timer(0.5).timeout
		queue_free()

func get_global_rect() -> Rect2:
	return Rect2(global_position - animated_sprite.texture.get_size() / 2, animated_sprite.texture.get_size())

func find_best_path_to_target(target_unit: Unit) -> Array:
	if grid == null:
		return []

	var start = grid.local_to_cell(grid.to_local(global_position))
	var goal = grid.local_to_cell(grid.to_local(target_unit.global_position))

	var candidate_cells = grid.get_neighbors(goal)
	candidate_cells.append(goal)

	var best_path := []
	var best_cost := INF

	for cell in candidate_cells:
		if not grid.is_cell_walkable(cell, self):
			continue

		var path = grid.find_path(start, cell, self)
		var cost := 0
		for i in range(1, path.size()):
			var c = path[i]
			var tile_cost = grid.get_move_cost(c, self)
			if tile_cost == -1:
				continue
			cost += tile_cost

		if path.size() > 1 and cost < best_cost:
			best_path = path
			best_cost = cost

	return best_path

func find_path_to(cell: Vector2i) -> Array:
	if grid == null:
		return []

	var start = grid.local_to_cell(grid.to_local(global_position))
	var path = grid.find_path(start, cell, self)
	return path

func show_warning(message: String):
	if not $"../..".is_player_turn:
		return  # No mostrar nada si no es tu turno
	var label := $"../../CanvasLayer/UI/warning"
	label.text = message
	label.modulate = Color(1, 0, 0)
	label.show()

	var tween := create_tween()
	tween.tween_property(label, "modulate", Color(1, 1, 1), 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(label, "hide")).set_delay(1.0)


func is_cell_valid_for_movement(cell: Vector2i) -> bool:
	if not is_player_turn or has_moved or not is_selected:
		return false

	var origin = grid.local_to_cell(grid.to_local(global_position))
	if cell == origin:
		return false # ❌ No marcar la celda actual

	var path = find_path_to(cell)
	if path.size() < 2:
		return false

	var total_cost := 0
	for i in range(1, path.size()):
		var cost = grid.get_move_cost(path[i], self)
		if cost == -1:
			return false
		total_cost += cost

	return total_cost <= action_points
