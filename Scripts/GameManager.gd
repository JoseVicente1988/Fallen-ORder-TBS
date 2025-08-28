extends Node

@onready var grid: TileMap = $"../Grid"
@onready var unit_container: Node = $"../UnitManager"  # Nodo donde están las unidades en la escena

var selected_unit: Node2D = null
var units: Array[Node2D] = []

func _ready():
	# Recoge todas las unidades que están como hijos de unit_container
	for unit in unit_container.get_children():
		if unit is Node2D:
			units.append(unit)
			unit.connect("selected", Callable(self, "select_unit"))

func select_unit(unit: Node2D):
	selected_unit = unit  # ← se actualiza siempre
	grid.clear_movement_range()
	grid.show_movement_range(unit.cell_position, unit.movement_points, unit)
