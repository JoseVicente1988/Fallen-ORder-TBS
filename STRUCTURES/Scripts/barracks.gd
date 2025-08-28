extends Node2D

# ============================================================
# VARIABLES
# ============================================================

var grid
var base_cell: Vector2i
var size: Vector2i

# ============================================================
# CICLO DE VIDA
# ============================================================

func _ready():
	grid = get_node("/root/Main/Grid")
	if has_meta("data"):
		size = get_meta("data").get("size", Vector2i(2, 2))

	if has_meta("real_building") and get_meta("real_building"):
		add_to_group("edificios")

# ============================================================
# UTILIDADES
# ============================================================

func get_cell_position() -> Vector2i:
	var grid := get_parent()
	if grid is TileMap:
		return grid.local_to_map(position)
	return Vector2i.ZERO
