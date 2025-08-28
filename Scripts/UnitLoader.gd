extends Node

var units: Dictionary = {}

func _ready():
	load_units()

func load_units():
	var file = FileAccess.open("res://UNITS/units.json", FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir units.json")
		return

	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)

	if typeof(data) != TYPE_DICTIONARY:
		push_error("Formato incorrecto en units.json")
		return

	for key in data.keys():
		var unit_data = data[key]
		var unit = Unit.new()
		unit.name = unit_data.get("name", key)
		unit.move_range = unit_data.get("move_range", 1)
		unit.move_cost_per_tile = unit_data.get("move_cost_per_tile", 1)
		#unit.can_traverse = unit_data.get("can_traverse", [])
		units[key] = unit
