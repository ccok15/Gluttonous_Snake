extends Node2D
class_name SnakeLayer

@export_range(4, 64, 1) var cell_size := 8
@export var head_color := Color("9be1a4")
@export var body_color := Color("67c587")
@export var protection_outline_color := Color("ffe57f")
@export var phase_badge_color := Color("f97316")
@export var phase_badge_text_color := Color("1b1208")

var _snake_cells: Array[Vector2i] = []
var _protection_active := false
var _wall_phase_charges := 0

func set_snake(snake_cells: Array[Vector2i], new_cell_size: int, protection_active: bool, wall_phase_charges: int) -> void:
	_snake_cells = snake_cells.duplicate()
	cell_size = new_cell_size
	_protection_active = protection_active
	_wall_phase_charges = wall_phase_charges
	queue_redraw()

func _draw() -> void:
	for index in range(_snake_cells.size()):
		var snake_cell := _snake_cells[index]
		var rect := Rect2(Vector2(snake_cell) * cell_size, Vector2.ONE * cell_size).grow(-1.0)
		draw_rect(rect, head_color if index == 0 else body_color, true)
		if index == 0 and _protection_active:
			draw_rect(rect.grow(1.0), protection_outline_color, false, 2.0)
		if index == 0 and _wall_phase_charges > 0:
			_draw_phase_badge(rect, str(_wall_phase_charges))

func _draw_phase_badge(head_rect: Rect2, text: String) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var font_size: int = maxi(8, cell_size)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var badge_size := Vector2(max(text_size.x + 8.0, 14.0), max(text_size.y + 4.0, 14.0))
	var badge_position := head_rect.position + Vector2(head_rect.size.x - badge_size.x * 0.5, -badge_size.y * 0.55)
	if badge_position.y < 0.0:
		badge_position.y = head_rect.position.y + head_rect.size.y * 0.1
	var badge_rect := Rect2(badge_position, badge_size)
	draw_rect(badge_rect, phase_badge_color, true)
	draw_rect(badge_rect, Color.WHITE, false, 1.0)
	var text_position := badge_rect.position + Vector2((badge_rect.size.x - text_size.x) * 0.5, badge_rect.size.y - 3.0)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, phase_badge_text_color)
