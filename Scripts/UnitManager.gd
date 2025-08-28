extends Node

var units: Array = []


func _ready():
	units = get_children()

func load_units(json_path: String, grid: TileMap):
	var file = FileAccess.open(json_path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())

	for unit_data in data:
		var unit_scene = preload("res://Scenary/Unit.tscn")
		var unit = unit_scene.instantiate()
		unit.setup(unit_data)
		add_child(unit)
		units.append(unit)
