extends Node2D
class_name ObstacleTileMap

@export_range(4, 64, 1) var cell_size := 8
@export var obstacle_color := Color("7f4f5a")

var _layout

func set_layout(layout, new_cell_size: int) -> void:
	_layout = layout
	cell_size = new_cell_size
	queue_redraw()

func get_blocked_cells() -> Array[Vector2i]:
	if _layout == null:
		return []
	return _layout.blocked_cells

func _draw() -> void:
	if _layout == null:
		return
	for blocked_cell in _layout.blocked_cells:
		var rect := Rect2(Vector2(blocked_cell) * cell_size, Vector2.ONE * cell_size)
		draw_rect(rect.grow(-1.0), obstacle_color, true)
