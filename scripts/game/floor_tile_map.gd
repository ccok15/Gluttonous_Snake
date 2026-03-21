extends Node2D
class_name FloorTileMap

@export var board_size := Vector2i(100, 100)
@export_range(4, 64, 1) var cell_size := 8
@export var background_color := Color("162127")
@export var grid_color := Color("26414a")
@export var border_color := Color("4e7b71")

func configure(new_board_size: Vector2i, new_cell_size: int) -> void:
	board_size = new_board_size
	cell_size = new_cell_size
	queue_redraw()

func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, Vector2(board_size.x * cell_size, board_size.y * cell_size))
	draw_rect(board_rect, background_color, true)
	for x in range(board_size.x + 1):
		var x_pos := float(x * cell_size)
		draw_line(Vector2(x_pos, 0.0), Vector2(x_pos, board_rect.size.y), grid_color, 1.0)
	for y in range(board_size.y + 1):
		var y_pos := float(y * cell_size)
		draw_line(Vector2(0.0, y_pos), Vector2(board_rect.size.x, y_pos), grid_color, 1.0)
	draw_rect(board_rect, border_color, false, 2.0)
