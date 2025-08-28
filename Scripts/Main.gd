extends Node2D

var is_player_turn: bool = true
var is_unit_busy: bool = false
var attack_mode: String = ""
var attack_tile_atlas := Vector2i(1, 4)
var valid_movement_cells: Array = []
var hovered_cell := Vector2i(0, 5)
var previous_cell := Vector2i(0, 4)

var selected_unit: Node = null
var attack_range_tiles: Array = []
var hovered_attack_cell: Vector2i = Vector2i(-1, -1)
var previous_attack_cell: Vector2i = Vector2i(-1, -1)
var movement_tiles: Array = []
var movement_mode := false


@onready var tooltip := $CanvasLayer/UI/VBoxContainer/Action/VBoxContainer/Attack
@onready var name_unit := $CanvasLayer/UI/VBoxContainer/Action/VBoxContainer/name

func _ready():
	for unit in $UnitManager.get_children():
		unit.grid = $Grid
		if not unit.is_in_group("unidades_aliadas") and not unit.is_in_group("unidades_enemigas"):
			unit.add_to_group("unidades_aliadas")

func _process(delta):
	var cell: Vector2i = $Grid.local_to_map($Grid.to_local(get_global_mouse_position()))

	# 🧹 Limpieza si se sale del modo movimiento
	if not movement_mode and hovered_cell != Vector2i(-1, -1):
		$Grid.set_cell($Grid.MOVEMENT_LAYER, hovered_cell, -1)
		hovered_cell = Vector2i(-1, -1)
		movement_mode = false

	# 🏗️ Hover de construcción (prioridad máxima)
	if $"BuildingManager".is_building_mode:
		$"BuildingManager".show_building_preview(cell)

	# 🟦 Hover de movimiento
	elif movement_mode and attack_mode == "" and not is_unit_busy and $Grid.hover_enabled and movement_mode == false:
		if cell != hovered_cell:
			# Restaurar celda anterior si era válida
			if hovered_cell in movement_tiles:
				$Grid.set_cell($Grid.MOVEMENT_LAYER, hovered_cell, $Grid.MOVEMENT_TILE_ID, Vector2i(0, 4))
				movement_mode = true
			elif hovered_cell != Vector2i(-1, -1):
				$Grid.set_cell($Grid.MOVEMENT_LAYER, hovered_cell, -1)

			hovered_cell = cell

			# Pintar celda nueva si es válida
			if cell in movement_tiles and movement_mode == true:
				$Grid.set_cell($Grid.MOVEMENT_LAYER, cell, $Grid.MOVEMENT_TILE_ID, Vector2i(0, 5))

	# 🔴 Hover de ataque
	elif attack_mode != "" and not is_unit_busy:
		if cell != hovered_attack_cell:
			# Restaurar área anterior
			if previous_attack_cell != Vector2i(-1, -1):
				var previous_area := get_area_centered_on(previous_attack_cell, get_attack_area_size())
				for c in previous_area:
					if c in attack_range_tiles:
						$Grid.set_cell($Grid.MOVEMENT_LAYER, c, $Grid.MOVEMENT_TILE_ID, Vector2i(1, 4))
					else:
						$Grid.set_cell($Grid.MOVEMENT_LAYER, c, -1)

			hovered_attack_cell = cell

			# Pintar nueva área si está en rango
			if cell in attack_range_tiles:
				previous_attack_cell = cell
				var area := get_area_centered_on(cell, get_attack_area_size())
				for c in area:
					$Grid.set_cell($Grid.MOVEMENT_LAYER, c, $Grid.MOVEMENT_TILE_ID, Vector2i(1, 5))

			show_attack_tooltip(cell)

func get_attack_area_size() -> int:
	if selected_unit == null:
		return 3

	if attack_mode == "light":
		return selected_unit.light_attack_data.get("area_size", 3)
	elif attack_mode == "heavy":
		return selected_unit.heavy_attack_data.get("area_size", 3)

	return 3



func get_area_centered_on(center: Vector2i, size: int) -> Array:
	var area := []
	size = max(1, size | 1) # fuerza que sea impar

	var half := size / 2
	for x in range(center.x - half, center.x + half + 1):
		for y in range(center.y - half, center.y + half + 1):
			area.append(Vector2i(x, y))

	return area


func apply_area_damage(center: Vector2i, size: int, damage: int, attacker: Unit):
	var area := get_area_centered_on(center, size)
	var enemy_group := "unidades_enemigas" if attacker.is_in_group("unidades_aliadas") else "unidades_aliadas"

	for cell in area:
		var target = get_unit_at_cell(cell, enemy_group)
		if target != null:
			target.receive_damage(damage)
			show_warning("Daño causado: %d" % damage)



func _input(event):
	if not is_player_turn or is_unit_busy:
		return

	var clicked_cell = $Grid.local_to_cell($Grid.to_local(get_global_mouse_position()))
	var selected_unit = get_selected_unit()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if attack_mode != "":
			var target = get_unit_at_cell(clicked_cell, "unidades_enemigas")
			if selected_unit != null and clicked_cell in attack_range_tiles:
				var cost := 0
				var damage := 0
				var area_size := 1

				var attack_data := {}
				if attack_mode == "light":
					attack_data = selected_unit.light_attack_data
				elif attack_mode == "heavy":
					attack_data = selected_unit.heavy_attack_data

				cost = attack_data.get("energy_cost", 1)
				damage = attack_data.get("damage", 1)
				area_size = attack_data.get("area_size", 1)

				if selected_unit.action_points >= cost:
					is_unit_busy = true
					$Grid.hover_enabled = false
					apply_area_damage(clicked_cell, area_size, damage, selected_unit)
					$Grid.hover_enabled = true
					selected_unit.action_points -= cost
					update_action_bar(selected_unit)

					await get_tree().create_timer(0.5).timeout
					is_unit_busy = false
					#$Grid.HoverTimer.start()

					var can_continue := false
					if attack_mode == "light":
						can_continue = selected_unit.action_points >= selected_unit.light_attack_data.get("energy_cost", 1)
					elif attack_mode == "heavy":
						can_continue = selected_unit.action_points >= selected_unit.heavy_attack_data.get("energy_cost", 1)

					if can_continue:
						show_attack_range(selected_unit)
					else:
						clear_attack_area()
						attack_mode = ""
						tooltip.text = ""
						name_unit.text = ""

						if selected_unit.action_points > 0:
							movement_mode = true
							show_movement_range(selected_unit)
						else:
							movement_mode = false
							clear_action_bar()
							valid_movement_cells.clear()
							deselect_all_units()

							if hovered_cell != Vector2i(-1, -1):
								$Grid.set_cell($Grid.MOVEMENT_LAYER, hovered_cell, -1)
								hovered_cell = Vector2i(-1, -1)

					check_end_of_turn()

			return

		var unit = get_unit_at_cell(clicked_cell, "unidades_aliadas")
		if unit != null:
			$Grid.clear_movement_range()
			deselect_all_units()
			unit.set_selected(true)
			update_action_bar(unit)
			show_movement_range(unit)
			movement_mode = true

			if unit.is_connected("action_completed", Callable(self, "_on_unit_action_completed")):
				unit.disconnect("action_completed", Callable(self, "_on_unit_action_completed"))
			unit.connect("action_completed", Callable(self, "_on_unit_action_completed"))

		elif selected_unit != null and selected_unit.action_points > 0:
			var path = selected_unit.find_path_to(clicked_cell)
			if path.size() > 1:
				is_unit_busy = true
				$Grid.hover_enabled = false
				await selected_unit.move_along_path(path)
				is_unit_busy = false
				$Grid.get_node("HoverTimer").start()
				update_action_bar(selected_unit)
				print("show")


				if selected_unit.action_points > 0:
					$Grid.clear_movement_range()
					movement_mode = true
					show_movement_range(selected_unit)
				else:
					$Grid.clear_movement_range()
					movement_mode = false
					clear_action_bar()
					valid_movement_cells.clear()
					deselect_all_units()

					if hovered_cell != Vector2i(-1, -1):
						$Grid.set_cell($Grid.MOVEMENT_LAYER, hovered_cell, -1)
						hovered_cell = Vector2i(-1, -1)

				name_unit.text = ""
				check_end_of_turn()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if $BuildingManager.is_building_mode:
			$BuildingManager.place_building_at_mouse()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if attack_mode != "":
			clear_attack_area()
			attack_mode = ""
			tooltip.text = ""
			name_unit.text = ""

			if selected_unit and selected_unit.action_points > 0:
				movement_mode = true
				show_movement_range(selected_unit)
			else:
				movement_mode = false
				clear_action_bar()
				valid_movement_cells.clear()
				$Grid.clear_movement_range()
				deselect_all_units()

				if hovered_cell != Vector2i(-1, -1):
					$Grid.set_cell($Grid.MOVEMENT_LAYER, hovered_cell, -1)
					hovered_cell = Vector2i(-1, -1)

		elif movement_mode:
			movement_mode = false
			clear_action_bar()
			valid_movement_cells.clear()
			$Grid.clear_movement_range()
			deselect_all_units()
			tooltip.text = ""
			name_unit.text = ""

			if hovered_cell != Vector2i(-1, -1):
				$Grid.set_cell($Grid.MOVEMENT_LAYER, hovered_cell, -1)
				hovered_cell = Vector2i(-1, -1)

func show_attack_range(unit):
	if $Grid.hover_enabled:
		selected_unit = unit

		var origin = $Grid.local_to_cell($Grid.to_local(unit.global_position))
		var range := 0

		if attack_mode == "light":
			range = unit.light_attack_data.get("range", 1)
		elif attack_mode == "heavy":
			range = unit.heavy_attack_data.get("range", 1)

		attack_range_tiles = $Grid.get_cells_in_radius(origin, range)

		# Pintamos el rango de ataque (las celdas que puedo atacar)
		for cell in attack_range_tiles:
			$Grid.set_cell($Grid.MOVEMENT_LAYER, cell, $Grid.MOVEMENT_TILE_ID, Vector2i(1, 4))


func show_attack_tooltip(cell: Vector2i):
	var _selected_unit = get_selected_unit()
	if _selected_unit == null:
		return

	var attack_data := {}
	if attack_mode == "light":
		attack_data = _selected_unit.light_attack_data
	elif attack_mode == "heavy":
		attack_data = _selected_unit.heavy_attack_data

	var name_unit = attack_data.get("name", "???")
	var damage = attack_data.get("damage", 0)
	var cost = attack_data.get("energy_cost", 0)

	tooltip.text = name_unit + " Daño: " + str(damage) + " Coste: " + str(cost)
	tooltip.show()

func hide_attack_tooltip():
	pass#tooltip.hide()

func clear_attack_area():
	$Grid.clear_layer($Grid.MOVEMENT_LAYER)
	attack_range_tiles.clear()
	hovered_attack_cell = Vector2i(-1, -1)
	previous_attack_cell = Vector2i(-1, -1)
	hide_attack_tooltip()
	tooltip.text = ""

func start_attack_mode(type: String):
	attack_mode = type
	clear_attack_area()

	var selected_unit = get_selected_unit()
	if selected_unit != null:
		show_attack_range(selected_unit)
		update_action_bar(selected_unit)

func get_selected_unit():
	for unit in get_tree().get_nodes_in_group("unidades_aliadas"):
		if unit.is_selected:
			
			name_unit.text = unit.name_unit
			return unit
	return null

func get_unit_at_cell(cell: Vector2i, group: String):
	for unit in get_tree().get_nodes_in_group(group):
		var unit_cell = $Grid.local_to_cell($Grid.to_local(unit.global_position))
		if unit_cell == cell:
			return unit
	return null

func deselect_all_units():
	for unit in get_tree().get_nodes_in_group("unidades_aliadas"):
		unit.set_selected(false)

func update_action_bar(unit):
	var bar = $CanvasLayer/UI/VBoxContainer/Action/VBoxContainer/ProgressBar
	var text = $CanvasLayer/UI/VBoxContainer/Action/VBoxContainer/ProgressBar/Label

	bar.modulate.a = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_PASS

	bar.max_value = unit.max_action_points
	bar.value = unit.action_points

	var ratio = float(unit.action_points) / float(unit.max_action_points)
	var color : Color

	if ratio > 0.66:
		color = Color(0.2, 0.8, 0.2) # Verde
	elif ratio > 0.33:
		color = Color(1.0, 0.8, 0.0) # Amarillo
	else:
		color = Color(0.9, 0.2, 0.2) # Rojo

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = color
	bar.add_theme_stylebox_override("fill", stylebox)

	text.text = "Energía: %d / %d" % [unit.action_points, unit.max_action_points]

func get_direction(from: Vector2i, to: Vector2i) -> String:
	var delta = to - from
	if abs(delta.x) > abs(delta.y):
		return "right" if delta.x > 0 else "left"
	else:
		return "down" if delta.y > 0 else "up"

func apply_directional_animation(unit: Unit, direction: String):
	unit.set_direction(direction)
	unit.play_animation("walk")

func clear_action_bar():
	var bar = $CanvasLayer/UI/VBoxContainer/Action/VBoxContainer/ProgressBar
	var text = $CanvasLayer/UI/VBoxContainer/Action/VBoxContainer/ProgressBar/Label

	bar.modulate.a = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	bar.value = 0
	text.text = ""

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.5, 0.5, 0.5) # Gris apagado
	bar.add_theme_stylebox_override("fill", stylebox)


func check_end_of_turn():
	for unit in get_tree().get_nodes_in_group("unidades_aliadas"):
		if unit.action_points > 0:
			return
	end_player_turn()

func end_player_turn():
	is_player_turn = false
	is_unit_busy = false
	deselect_all_units()
	clear_attack_area()
	clear_action_bar()
	await get_tree().create_timer(1.0).timeout
	enemy_turn()

func start_player_turn():
	$Grid.hover_enabled = true
	is_player_turn = true
	is_unit_busy = false
	for unit in get_tree().get_nodes_in_group("unidades_aliadas"):
		unit.action_points = unit.max_action_points
		unit.has_moved = false
		unit.set_selected(false)
	clear_attack_area()
	clear_action_bar()

func _on_ButtonLightAttack_pressed():
	var selected_unit = get_selected_unit()
	if selected_unit == null:
		show_warning("Selecciona unidad primero")
		return
	start_attack_mode("light")

func _on_ButtonHeavyAttack_pressed():
	var selected_unit = get_selected_unit()
	if selected_unit == null:
		show_warning("Selecciona unidad primero")
		return
	start_attack_mode("heavy")

func show_warning(message: String):
	if not is_player_turn:
		return
	var label := $CanvasLayer/UI/warning
	label.text = message
	label.modulate = Color(1, 0, 0)
	label.show()

	var tween := create_tween()
	tween.tween_property(label, "modulate", Color(1, 1, 1), 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(label, "hide")).set_delay(1.0)

func _on_ButtonEndTurn_pressed():
	end_player_turn()
func enemy_turn():
	for enemy in get_tree().get_nodes_in_group("unidades_enemigas"):
		if enemy.grid == null:
			enemy.grid = $Grid

		enemy.action_points = enemy.max_action_points
		enemy.has_moved = false

		var target_unit = null
		var shortest_path := []
		var shortest_cost := INF

		for ally in get_tree().get_nodes_in_group("unidades_aliadas"):
			if not enemy.has_method("find_best_path_to_target"):
				continue

			var path = enemy.find_best_path_to_target(ally)
			var cost := 0
			for i in range(1, path.size()):
				var cell = path[i]
				var tile_cost = $Grid.get_move_cost(cell, enemy)
				if tile_cost == -1:
					continue
				cost += tile_cost

			if path.size() > 1 and cost < shortest_cost:
				target_unit = ally
				shortest_path = path
				shortest_cost = cost

		if target_unit != null and shortest_path.size() > 1:
			var trimmed_path := []
			var accumulated_cost := 0

			for i in range(1, shortest_path.size()):
				var cell = shortest_path[i]
				var tile_cost = $Grid.get_move_cost(cell, enemy)
				if tile_cost == -1:
					continue
				if accumulated_cost + tile_cost > enemy.action_points:
					break
				accumulated_cost += tile_cost
				trimmed_path.append(cell)

			if trimmed_path.size() > 0:
				var full_path = [shortest_path[0]] + trimmed_path
				var tween := enemy.create_tween()

				for i in range(1, full_path.size()):
					var from_cell = full_path[i - 1]
					var to_cell = full_path[i]
					var to_pos = $Grid.cell_to_local_pos(to_cell)

					var direction = get_direction(from_cell, to_cell)
					apply_directional_animation(enemy, direction)

					var cost = $Grid.get_move_cost(to_cell, enemy)
					enemy.action_points -= cost

					var segment_duration := 0.2
					tween.tween_property(enemy, "global_position", to_pos, segment_duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

				await tween.finished

				var final_direction = get_direction(full_path[full_path.size() - 2], full_path[full_path.size() - 1])
				#apply_idle_animation(enemy, final_direction)

				enemy.has_moved = true

		var enemies_in_range = enemy.get_enemies_in_range()
		while enemies_in_range.size() > 0:
			var cost = enemy.heavy_attack_data.get("energy_cost", 1)
			if enemy.action_points >= cost:
				await enemy.attack_heavy(enemies_in_range[0])
				enemies_in_range = enemy.get_enemies_in_range()
			else:
				break

	start_player_turn()

func can_unit_attack(unit) -> bool:
	if attack_mode == "light":
		var cost = unit.light_attack_data.get("cost", 0)
		return unit.action_points >= cost
	elif attack_mode == "heavy":
		var cost = unit.heavy_attack_data.get("cost", 0)
		return unit.action_points >= cost
	return false


func show_movement_range(unit):
	valid_movement_cells.clear()
	movement_tiles.clear()

	var origin = $Grid.local_to_cell($Grid.to_local(unit.global_position))

	var open := [origin]
	var visited := {}
	visited[origin] = 0

	while open.size() > 0:
		var current = open.pop_front()
		var current_cost = visited[current]

		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor = current + offset

			if visited.has(neighbor):
				continue

			var move_cost = $Grid.get_move_cost(neighbor, unit)
			if move_cost == -1:
				continue

			var tile_data = $Grid.get_cell_tile_data(1, neighbor)
			if tile_data != null:
				continue

			var total_cost = current_cost + move_cost
			if total_cost <= unit.action_points:
				visited[neighbor] = total_cost
				open.append(neighbor)
				valid_movement_cells.append(neighbor)
				movement_tiles.append(neighbor)
				$Grid.set_cell($Grid.MOVEMENT_LAYER, neighbor, $Grid.MOVEMENT_TILE_ID, Vector2i(0, 4))

func _on_unit_action_completed():
	var selected_unit = get_selected_unit()
	if selected_unit != null:
		clear_attack_area()
		show_movement_range(selected_unit)
		update_action_bar(selected_unit)
		$Grid.get_node("HoverTimer").start()
		$Grid.hover_enabled = true



func BuildMode() -> void:
	$BuildingManager.start_building_mode("mine")
