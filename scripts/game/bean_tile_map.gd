extends Node2D
class_name BeanTileMap

@export_range(4, 64, 1) var cell_size := 8
@export var bean_color := Color("ffb84d")
@export var critical_ring_color := Color("fff2a0")
@export var critical_core_color := Color("ff5c7a")

var _normal_beans: Array[Vector2i] = []
var _critical_bean := {}

func set_bean_state(normal_beans: Array[Vector2i], critical_bean: Dictionary, new_cell_size: int) -> void:
	_normal_beans = normal_beans.duplicate()
	_critical_bean = critical_bean.duplicate(true)
	cell_size = new_cell_size
	queue_redraw()

func _draw() -> void:
	var radius = maxf(float(cell_size) * 0.32, 2.0)
	for bean in _normal_beans:
		var center := (Vector2(bean) * cell_size) + Vector2.ONE * (cell_size * 0.5)
		draw_circle(center, radius, bean_color)
	_draw_critical_bean(radius)

func _draw_critical_bean(base_radius: float) -> void:
	if not _critical_bean.get("active", false):
		return
	if not _critical_bean.get("visible", true):
		return
	var bean: Vector2i = _critical_bean.get("position", Vector2i.ZERO)
	var center := (Vector2(bean) * cell_size) + Vector2.ONE * (cell_size * 0.5)
	var spawn_progress := clampf(float(_critical_bean.get("spawn_progress", 1.0)), 0.0, 1.0)
	var life_ratio := clampf(float(_critical_bean.get("life_ratio", 1.0)), 0.0, 1.0)
	var pulse_scale := lerpf(1.35, 1.0, spawn_progress)
	var ring_alpha := lerpf(0.25, 0.45, 1.0 - life_ratio)
	var ring_radius := base_radius * 1.85 * pulse_scale
	var diamond_radius := base_radius * 1.2
	var highlight_radius := maxf(base_radius * 0.42, 1.5)
	var diamond_points := PackedVector2Array([
		center + Vector2(0.0, -diamond_radius),
		center + Vector2(diamond_radius, 0.0),
		center + Vector2(0.0, diamond_radius),
		center + Vector2(-diamond_radius, 0.0),
	])
	var ring_color := critical_ring_color
	ring_color.a = ring_alpha
	var highlight_color := Color.WHITE
	highlight_color.a = 0.9
	draw_circle(center, ring_radius, ring_color)
	draw_colored_polygon(diamond_points, critical_core_color)
	draw_circle(center, highlight_radius, highlight_color)
