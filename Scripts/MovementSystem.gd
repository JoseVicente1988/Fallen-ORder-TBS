extends Node

@export var overlay_scene: PackedScene  # Escena que representa una celda de rango (ej. ColorRect o Sprite2D)

var overlays := []

func show_movement_range(origin: Vector2i, range: int, unit: Node) -> void:
	clear_overlay()
	var open_set := [origin]
	var visited := {}

	while not open_set.is_empty():
		var current = open_set.pop_front()
		var distance = origin.distance_to(current)
		if distance > range or visited.has(current):
			continue
		visited[current] = true

		var overlay = overlay_scene.instantiate()
		overlay.position = unit.terrain_map.map_to_world(current) + unit.terrain_map.cell_size * 0.5
		add_child(overlay)
		overlays.append(overlay)

		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			open_set.append(current + dir)

func clear_overlay() -> void:
	for overlay in overlays:
		overlay.queue_free()
	overlays.clear()
