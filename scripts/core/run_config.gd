extends Resource
class_name RunConfig

const STAGE_CONFIG_RESOURCE = preload("res://scripts/core/stage_config.gd")

@export var board_size := Vector2i(20, 20)
@export_range(4, 64, 1) var cell_size := 12
@export_range(1, 128, 1) var default_bean_count := 4
@export_range(2, 32, 1) var initial_snake_length := 4
@export_enum("UP", "DOWN", "LEFT", "RIGHT") var initial_direction := "RIGHT"
@export_range(30, 500, 1) var initial_step_interval_ms := 90
@export_range(30, 500, 1) var minimum_step_interval_ms := 30
@export_range(1, 8, 1) var dash_distance := 3
@export_range(0.05, 0.6, 0.01) var dash_double_tap_window_seconds := 0.22
@export_range(1, 999, 1) var critical_bean_initial_min_score := 5
@export_range(1, 999, 1) var critical_bean_initial_max_score := 10
@export_range(1.0, 60.0, 0.5) var critical_bean_lifetime_seconds := 5.0
@export_range(1.0, 20.0, 0.5) var critical_bean_lifetime_upgrade_seconds := 3.0
@export_range(0.5, 60.0, 0.5) var critical_bean_spawn_interval_seconds := 8.0
@export_range(0.0, 60.0, 0.5) var critical_bean_spawn_interval_random_seconds := 4.0
@export_range(1, 8, 1) var critical_bean_max_active := 1
@export_range(0.0, 5.0, 0.1) var post_upgrade_invulnerability_seconds := 0.5
@export_range(0.0, 5.0, 0.1) var stage_transition_pause_seconds := 0.5
@export_range(1.0, 600.0, 1.0) var initial_stage_time_seconds := 60.0
@export_range(0.0, 600.0, 1.0) var stage_clear_bonus_seconds := 60.0
@export var default_locale: StringName = &"zh_CN"
@export var level_thresholds: Array[int] = [1, 6, 14, 25, 39, 56, 76, 99, 125, 154, 186, 221, 259, 300, 344, 391, 441, 494, 550]
@export_range(1, 200, 1) var level_threshold_overflow_step := 3
@export_range(1, 200, 1) var overflow_score_increment_start := 35
@export_range(0, 50, 1) var overflow_score_increment_step := 5
@export_range(1, 10, 1) var default_upgrade_weight := 1
@export_range(1, 10, 1) var move_speed_up_weight := 3
@export var pause_key := "P"
@export var stage_configs: Array[Resource] = []
@export var upgrade_defs: Array[Resource] = []
@export var language_packs: Array[Resource] = []

func get_level_threshold_for_level(target_level: int) -> int:
	if target_level <= 1:
		return 0
	var threshold_index := target_level - 2
	if threshold_index < level_thresholds.size():
		return level_thresholds[threshold_index]
	if level_thresholds.is_empty():
		return _get_empty_curve_threshold(target_level)
	var overflow_levels := threshold_index - level_thresholds.size() + 1
	var last_threshold := level_thresholds[-1]
	var last_increment := _get_last_level_threshold_increment()
	return last_threshold + _get_overflow_threshold_addition(overflow_levels, last_increment)

func get_stage_target_score(stage_number: int) -> int:
	if stage_configs.is_empty():
		return 30 + ((stage_number - 1) * overflow_score_increment_start)
	if stage_number <= stage_configs.size():
		return stage_configs[stage_number - 1].target_total_score
	var score = stage_configs[-1].target_total_score
	var increment = overflow_score_increment_start
	for overflow_stage in range(stage_configs.size() + 1, stage_number + 1):
		score += increment
		increment += overflow_score_increment_step
	return score

func get_upgrade_weight(upgrade_id: StringName) -> int:
	if upgrade_id == &"move_speed_up":
		return move_speed_up_weight
	return default_upgrade_weight

func get_pause_keycode() -> Key:
	var configured_key := OS.find_keycode_from_string(String(pause_key).to_upper())
	if configured_key == KEY_NONE:
		return KEY_P
	return configured_key

func get_stage_config(stage_number: int):
	if stage_configs.is_empty():
		var fallback_stage = STAGE_CONFIG_RESOURCE.new()
		fallback_stage.stage_number = stage_number
		fallback_stage.target_total_score = get_stage_target_score(stage_number)
		fallback_stage.time_limit_seconds = 180.0
		fallback_stage.board_size = board_size
		fallback_stage.bean_count_override = default_bean_count
		return fallback_stage
	if stage_number <= stage_configs.size():
		return stage_configs[stage_number - 1]
	var last_stage = stage_configs[-1]
	var generated_stage = STAGE_CONFIG_RESOURCE.new()
	generated_stage.stage_number = stage_number
	generated_stage.target_total_score = get_stage_target_score(stage_number)
	generated_stage.time_limit_seconds = last_stage.time_limit_seconds
	generated_stage.board_size = _get_overflow_stage_board_size(stage_number)
	generated_stage.bean_count_override = _get_overflow_stage_bean_count(stage_number)
	generated_stage.obstacle_layout = last_stage.obstacle_layout
	generated_stage.modifier_tags = last_stage.modifier_tags.duplicate()
	return generated_stage

func _get_overflow_stage_board_size(stage_number: int) -> Vector2i:
	if stage_configs.is_empty():
		return board_size
	var last_stage = stage_configs[-1]
	if stage_configs.size() == 1:
		return last_stage.board_size
	var previous_stage = stage_configs[-2]
	var step_size: Vector2i = last_stage.board_size - previous_stage.board_size
	var overflow_count := stage_number - stage_configs.size()
	return last_stage.board_size + (step_size * overflow_count)

func _get_overflow_stage_bean_count(stage_number: int) -> int:
	if stage_configs.is_empty():
		return default_bean_count
	var last_stage = stage_configs[-1]
	if stage_configs.size() == 1:
		return max(last_stage.bean_count_override, default_bean_count)
	var previous_stage = stage_configs[-2]
	var last_value: int = maxi(last_stage.bean_count_override, default_bean_count)
	var previous_value: int = maxi(previous_stage.bean_count_override, default_bean_count)
	var step_value: int = last_value - previous_value
	var overflow_count := stage_number - stage_configs.size()
	return maxi(last_value + (step_value * overflow_count), 1)

func _get_empty_curve_threshold(target_level: int) -> int:
	var level_count := target_level - 1
	return int((level_threshold_overflow_step * level_count * (level_count + 1)) / 2)

func _get_last_level_threshold_increment() -> int:
	if level_thresholds.is_empty():
		return 0
	if level_thresholds.size() == 1:
		return level_thresholds[0]
	return level_thresholds[-1] - level_thresholds[-2]

func _get_overflow_threshold_addition(overflow_levels: int, base_increment: int) -> int:
	var growth_sum := int((overflow_levels * (overflow_levels + 1)) / 2)
	return (overflow_levels * base_increment) + (growth_sum * level_threshold_overflow_step)
