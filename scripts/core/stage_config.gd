extends Resource
class_name StageConfig

@export_range(1, 999, 1) var stage_number := 1
@export_range(1, 100000, 1) var target_total_score := 30
@export_range(10.0, 600.0, 1.0) var time_limit_seconds := 180.0
@export var board_size := Vector2i(20, 20)
@export_range(-1, 64, 1) var bean_count_override := -1
@export var obstacle_layout: Resource
@export var modifier_tags: Array[String] = []
