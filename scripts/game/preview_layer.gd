extends Node2D
class_name PreviewLayer

@export_range(4, 64, 1) var cell_size := 8
@export var preview_color := Color(0.75, 0.91, 1.0, 0.45)

var _preview_cells: Array[Vector2i] = []

func set_preview_cells(preview_cells: Array[Vector2i], new_cell_size: int) -> void:
	_preview_cells = preview_cells.duplicate()
	cell_size = new_cell_size
	queue_redraw()

func _draw() -> void:
	for preview_cell in _preview_cells:
		var rect := Rect2(Vector2(preview_cell) * cell_size, Vector2.ONE * cell_size).grow(-2.0)
		draw_rect(rect, preview_color, false, 2.0)
