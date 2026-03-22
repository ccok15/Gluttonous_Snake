extends Node2D
class_name SnakeLayer

@export_range(4, 64, 1) var cell_size := 8
@export var head_color := Color("9be1a4")
@export var traversal_head_color := Color("58c4ff")
@export var body_color := Color("67c587")
@export var protection_outline_color := Color("ffe57f")

var _snake_cells: Array[Vector2i] = []
var _protection_active := false
var _traversal_available := false

func set_snake(snake_cells: Array[Vector2i], new_cell_size: int, protection_active: bool, traversal_available: bool) -> void:
	_snake_cells = snake_cells.duplicate()
	cell_size = new_cell_size
	_protection_active = protection_active
	_traversal_available = traversal_available
	queue_redraw()

func _draw() -> void:
	for index in range(_snake_cells.size()):
		var snake_cell := _snake_cells[index]
		var rect := Rect2(Vector2(snake_cell) * cell_size, Vector2.ONE * cell_size).grow(-1.0)
		var fill_color := body_color
		if index == 0:
			fill_color = traversal_head_color if _traversal_available else head_color
		draw_rect(rect, fill_color, true)
		if index == 0 and _protection_active:
			draw_rect(rect.grow(1.0), protection_outline_color, false, 2.0)
