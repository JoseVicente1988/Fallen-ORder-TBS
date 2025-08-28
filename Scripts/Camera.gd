extends Camera2D


# Variables configurables
var edge_margin := 20  # píxeles desde el borde
var camera_speed := 300  # velocidad de desplazamiento en píxeles por segundo

func _process(delta):
	update_camera_scroll(delta)
	# ... tu lógica de hover y demás

func update_camera_scroll(delta):
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var direction := Vector2.ZERO

	if mouse_pos.x <= edge_margin:
		direction.x -= 1
	elif mouse_pos.x >= viewport_size.x - edge_margin:
		direction.x += 1

	if mouse_pos.y <= edge_margin:
		direction.y -= 1
	elif mouse_pos.y >= viewport_size.y - edge_margin:
		direction.y += 1

	if direction != Vector2.ZERO:
		position += direction.normalized() * camera_speed * delta
	
