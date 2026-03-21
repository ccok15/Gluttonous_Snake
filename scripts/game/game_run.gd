extends Control

class_name GameRun

signal bean_eaten(bean_position: Vector2i)
signal score_changed(new_score: int)
signal level_up(new_level: int)
signal upgrade_applied(upgrade_id: StringName, level: int)
signal stage_started(stage_number: int)
signal stage_cleared(stage_number: int)
signal run_failed(reason: StringName)

enum RunState {
	ACTIVE,
	STAGE_PAUSE,
	PAUSED,
	UPGRADE_CHOICE,
	GAME_OVER,
}

const MAIN_MENU_SCENE_PATH := "res://scenes/core/MainMenu.tscn"

@export var fallback_run_config: Resource
@export var board_area_origin := Vector2(32, 50)
@export var board_area_size := Vector2(800, 800)

@onready var board_root = $BoardRoot
@onready var floor_tile_map = $BoardRoot/FloorTileMap
@onready var obstacle_tile_map = $BoardRoot/ObstacleTileMap
@onready var bean_tile_map = $BoardRoot/BeanTileMap
@onready var snake_layer = $BoardRoot/SnakeLayer
@onready var preview_layer = $BoardRoot/PreviewLayer
@onready var score_popup_layer = $BoardRoot/ScorePopupLayer
@onready var hud_root = $HudRoot
@onready var debug_hud = $DebugHud
@onready var upgrade_overlay = $UpgradeOverlay
@onready var pause_overlay = $PauseOverlay
@onready var pause_title_label: Label = $PauseOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var pause_hint_label: Label = $PauseOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HintLabel

var rng := RandomNumberGenerator.new()
var run_config
var state := RunState.ACTIVE
var stage_number := 1
var current_stage
var current_board_size := Vector2i.ZERO
var stage_time_left := 180.0
var stage_pause_left := 0.0
var protection_left := 0.0
var step_accumulator := 0.0
var direction := Vector2i.RIGHT
var queued_directions: Array[Vector2i] = []
var snake_cells: Array[Vector2i] = []
var beans: Array[Vector2i] = []
var obstacle_cells := {}
var growth_pending := 0
var score := 0
var xp := 0
var level := 1
var beans_eaten_count := 0
var pending_upgrade_choices := 0
var upgrade_levels := {}
var current_step_interval_ms := 150
var current_turn_buffer_size := 1
var current_magnet_radius := 0
var current_preview_length := 0
var current_stage_reset_grace_seconds := 0.0
var current_lean_growth_cycle := 0
var current_dash_cooldown_seconds := 0.0
var current_critical_bean_min_score := 5
var current_critical_bean_max_score := 10
var current_critical_bean_lifetime_seconds := 5.0
var current_wall_phase_total := 0
var wall_phase_charges := 0
var current_upgrade_lookup := {}
var game_over_reason := &""
var dash_cooldown_left := 0.0
var last_bean_score_gain := 1
var last_direction_input := Vector2i.ZERO
var last_direction_input_time_msec := -1000000
var critical_bean_active := false
var critical_bean_position := Vector2i.ZERO
var critical_bean_time_left := 0.0
var critical_bean_total_lifetime := 0.0
var critical_bean_spawn_timer := 0.0
var critical_bean_age := 0.0
var critical_bean_blink_clock := 0.0

func _ready() -> void:
	rng.randomize()
	run_config = GameApp.run_config if GameApp.run_config != null else fallback_run_config
	if run_config == null:
		push_error("GameRun requires a RunConfig to start.")
		return
	for definition in run_config.upgrade_defs:
		current_upgrade_lookup[definition.upgrade_id] = definition
	upgrade_overlay.option_chosen.connect(_on_upgrade_chosen)
	hud_root.restart_requested.connect(_on_restart_requested)
	start_new_run()
	set_process(true)

func start_new_run() -> void:
	stage_number = 1
	state = RunState.ACTIVE
	score = 0
	xp = 0
	level = 1
	beans_eaten_count = 0
	pending_upgrade_choices = 0
	stage_pause_left = 0.0
	protection_left = 0.0
	step_accumulator = 0.0
	dash_cooldown_left = 0.0
	queued_directions.clear()
	beans.clear()
	score_popup_layer.clear_popups()
	growth_pending = 0
	upgrade_levels.clear()
	current_stage = run_config.get_stage_config(stage_number)
	current_board_size = _get_board_size_for_stage(current_stage)
	direction = _direction_from_name(run_config.initial_direction)
	game_over_reason = &""
	stage_time_left = run_config.initial_stage_time_seconds
	last_bean_score_gain = 1
	last_direction_input = Vector2i.ZERO
	last_direction_input_time_msec = -1000000
	wall_phase_charges = 0
	current_wall_phase_total = 0
	_reset_critical_bean_state()
	_setup_starting_snake()
	_apply_upgrades()
	_schedule_next_critical_bean_spawn()
	_load_stage(stage_number, false)
	upgrade_overlay.hide_overlay()
	emit_signal("score_changed", score)
	_refresh_all_views()

func _setup_starting_snake(length_override: int = -1) -> void:
	var starting_length: int = run_config.initial_snake_length if length_override <= 0 else length_override
	var center := Vector2i(current_board_size.x / 2, current_board_size.y / 2)
	var body_offset := -direction
	if body_offset == Vector2i.ZERO:
		body_offset = Vector2i.LEFT
	snake_cells.clear()
	for index in range(starting_length):
		snake_cells.append(center + (body_offset * index))

func _process(delta: float) -> void:
	if run_config == null:
		return
	debug_hud.visible = GameApp.debug_hud_visible
	match state:
		RunState.UPGRADE_CHOICE:
			_refresh_ui()
			return
		RunState.GAME_OVER:
			_refresh_ui()
			return
		RunState.STAGE_PAUSE:
			stage_pause_left = max(stage_pause_left - delta, 0.0)
			if stage_pause_left <= 0.0:
				state = RunState.ACTIVE
			_refresh_ui()
			return
		RunState.PAUSED:
			_refresh_ui()
			return
		_:
			pass
	if protection_left > 0.0:
		protection_left = max(protection_left - delta, 0.0)
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)
	_update_critical_bean(delta)
	stage_time_left = max(stage_time_left - delta, 0.0)
	if stage_time_left <= 0.0 and score < current_stage.target_total_score:
		_fail_run(&"quota_failed")
		return
	step_accumulator += delta
	var step_interval_seconds := current_step_interval_ms / 1000.0
	while step_accumulator >= step_interval_seconds and state == RunState.ACTIVE:
		step_accumulator -= step_interval_seconds
		_advance_snake_one_step()
		if state != RunState.ACTIVE:
			break
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == run_config.get_pause_keycode():
			_toggle_manual_pause()
			return
		match event.physical_keycode:
			KEY_F1:
				GameApp.toggle_debug_hud()
				debug_hud.visible = GameApp.debug_hud_visible
			KEY_ESCAPE:
				if state == RunState.GAME_OVER or state == RunState.ACTIVE or state == RunState.STAGE_PAUSE or state == RunState.PAUSED:
					get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
			KEY_R:
				if state == RunState.GAME_OVER:
					start_new_run()
			KEY_W, KEY_UP:
				_queue_direction(Vector2i.UP)
			KEY_S, KEY_DOWN:
				_queue_direction(Vector2i.DOWN)
			KEY_A, KEY_LEFT:
				_queue_direction(Vector2i.LEFT)
			KEY_D, KEY_RIGHT:
				_queue_direction(Vector2i.RIGHT)

func _queue_direction(candidate: Vector2i) -> void:
	if state != RunState.ACTIVE:
		return
	var current_time_msec := Time.get_ticks_msec()
	if candidate == direction and _can_trigger_dash(candidate, current_time_msec):
		_register_direction_input(candidate, current_time_msec)
		_trigger_dash()
		return
	_register_direction_input(candidate, current_time_msec)
	var reference_direction := direction
	if not queued_directions.is_empty():
		reference_direction = queued_directions[-1]
	if candidate == reference_direction or candidate == -reference_direction:
		return
	if queued_directions.size() >= current_turn_buffer_size:
		return
	queued_directions.append(candidate)

func _advance_snake_one_step(skip_buffered_direction: bool = false) -> bool:
	if not skip_buffered_direction:
		_consume_buffered_direction()
	var movement_result := _resolve_next_head(direction)
	var next_head: Vector2i = movement_result["head"]
	var collision_reason: StringName = movement_result["collision_reason"]
	if movement_result["used_wall_phase"]:
		wall_phase_charges = max(wall_phase_charges - 1, 0)
	if collision_reason != &"":
		if _can_block_collision(next_head):
			_refresh_all_views()
			return false
		_fail_run(collision_reason)
		return false
	var grows_this_step := false
	if critical_bean_active and critical_bean_position == next_head:
		grows_this_step = _consume_critical_bean()
		if grows_this_step:
			growth_pending += 1
	else:
		var direct_bean_index := _find_bean_index(next_head)
		if direct_bean_index >= 0:
			grows_this_step = _consume_bean_at_index(direct_bean_index)
			if grows_this_step:
				growth_pending += 1
	snake_cells.push_front(next_head)
	if growth_pending > 0:
		growth_pending -= 1
	else:
		snake_cells.pop_back()
	_maybe_absorb_nearby_bean()
	_refresh_preview()
	_refresh_all_views()
	if pending_upgrade_choices > 0:
		_show_upgrade_choices()
		return false
	if score >= current_stage.target_total_score:
		_advance_to_next_stage()
		return false
	return true

func _consume_buffered_direction() -> void:
	while not queued_directions.is_empty():
		var next_direction: Vector2i = queued_directions.pop_front()
		if next_direction == direction or next_direction == -direction:
			continue
		direction = next_direction
		break

func _resolve_next_head(step_direction: Vector2i) -> Dictionary:
	var raw_next_head := snake_cells[0] + step_direction
	if _is_out_of_bounds(raw_next_head):
		if wall_phase_charges <= 0:
			return {
				"head": raw_next_head,
				"collision_reason": &"wall",
				"used_wall_phase": false,
			}
		var wrapped_head := _wrap_cell(raw_next_head)
		return {
			"head": wrapped_head,
			"collision_reason": _get_non_wall_collision_reason(wrapped_head),
			"used_wall_phase": true,
		}
	return {
		"head": raw_next_head,
		"collision_reason": _get_non_wall_collision_reason(raw_next_head),
		"used_wall_phase": false,
	}

func _get_collision_reason(next_head: Vector2i) -> StringName:
	if _is_out_of_bounds(next_head):
		return &"wall"
	return _get_non_wall_collision_reason(next_head)

func _get_non_wall_collision_reason(next_head: Vector2i) -> StringName:
	if obstacle_cells.has(next_head):
		return &"obstacle"
	for index in range(snake_cells.size()):
		var cell := snake_cells[index]
		if cell != next_head:
			continue
		var tail_is_safe := index == snake_cells.size() - 1 and not _has_any_bean_at(next_head) and growth_pending <= 0
		if tail_is_safe:
			return &""
		return &"self"
	return &""

func _is_out_of_bounds(cell: Vector2i) -> bool:
	return cell.x < 0 or cell.y < 0 or cell.x >= current_board_size.x or cell.y >= current_board_size.y

func _wrap_cell(cell: Vector2i) -> Vector2i:
	var wrapped_x := posmod(cell.x, current_board_size.x)
	var wrapped_y := posmod(cell.y, current_board_size.y)
	return Vector2i(wrapped_x, wrapped_y)

func _can_block_collision(_next_head: Vector2i) -> bool:
	return protection_left > 0.0

func _consume_bean_at_index(index: int) -> bool:
	var bean_position := beans[index]
	beans.remove_at(index)
	emit_signal("bean_eaten", bean_position)
	last_bean_score_gain = 1
	score += last_bean_score_gain
	xp += 1
	beans_eaten_count += 1
	emit_signal("score_changed", score)
	score_popup_layer.spawn_popup(bean_position, run_config.cell_size, last_bean_score_gain, false)
	_check_for_level_ups()
	_spawn_beans_up_to_target()
	return _should_grow_from_current_bean()

func _consume_critical_bean() -> bool:
	emit_signal("bean_eaten", critical_bean_position)
	last_bean_score_gain = _roll_critical_bean_score()
	score += last_bean_score_gain
	xp += 1
	beans_eaten_count += 1
	emit_signal("score_changed", score)
	score_popup_layer.spawn_popup(critical_bean_position, run_config.cell_size, last_bean_score_gain, true)
	_clear_critical_bean()
	_schedule_next_critical_bean_spawn()
	_check_for_level_ups()
	return _should_grow_from_current_bean()

func _should_grow_from_current_bean() -> bool:
	if current_lean_growth_cycle <= 0:
		return true
	return beans_eaten_count % current_lean_growth_cycle != 0

func _check_for_level_ups() -> void:
	while xp >= run_config.get_level_threshold_for_level(level + 1):
		level += 1
		pending_upgrade_choices += 1
		emit_signal("level_up", level)

func _maybe_absorb_nearby_bean() -> void:
	if current_magnet_radius <= 0:
		return
	var head := snake_cells[0]
	var nearest_distance := 1000000
	var nearest_index := -1
	var absorb_critical := false
	for index in range(beans.size()):
		var bean_position := beans[index]
		var distance: int = abs(bean_position.x - head.x) + abs(bean_position.y - head.y)
		if distance == 0 or distance > current_magnet_radius:
			continue
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	if critical_bean_active:
		var critical_distance: int = abs(critical_bean_position.x - head.x) + abs(critical_bean_position.y - head.y)
		if critical_distance > 0 and critical_distance <= current_magnet_radius and critical_distance < nearest_distance:
			nearest_distance = critical_distance
			absorb_critical = true
	if absorb_critical:
		var critical_growth := _consume_critical_bean()
		if critical_growth:
			growth_pending += 1
		return
	if nearest_index >= 0:
		var should_grow := _consume_bean_at_index(nearest_index)
		if should_grow:
			growth_pending += 1

func _show_upgrade_choices() -> void:
	var pool: Array = []
	for definition in run_config.upgrade_defs:
		if GameApp.save_profile != null and not GameApp.save_profile.is_upgrade_unlocked(definition.upgrade_id):
			continue
		var current_level := int(upgrade_levels.get(definition.upgrade_id, 0))
		if definition.can_level(current_level):
			pool.append(definition)
	if pool.is_empty():
		pending_upgrade_choices = 0
		if score >= current_stage.target_total_score:
			_advance_to_next_stage()
		return
	var choices := _pick_weighted_upgrade_choices(pool, 3)
	state = RunState.UPGRADE_CHOICE
	upgrade_overlay.show_choices(choices, upgrade_levels)
	_refresh_ui()

func _on_upgrade_chosen(definition) -> void:
	var current_level := int(upgrade_levels.get(definition.upgrade_id, 0))
	var next_level: int = mini(current_level + 1, definition.max_level)
	upgrade_levels[definition.upgrade_id] = next_level
	if definition.upgrade_id == &"wall_phase":
		wall_phase_charges += definition.get_level_gain(current_level, next_level)
	if definition.upgrade_id == &"critical_bean_duration" and critical_bean_active:
		var lifetime_gain := float(definition.get_level_gain(current_level, next_level))
		critical_bean_time_left += lifetime_gain
		critical_bean_total_lifetime += lifetime_gain
	_apply_upgrades()
	pending_upgrade_choices = max(pending_upgrade_choices - 1, 0)
	upgrade_overlay.hide_overlay()
	emit_signal("upgrade_applied", definition.upgrade_id, int(upgrade_levels[definition.upgrade_id]))
	if pending_upgrade_choices > 0:
		_show_upgrade_choices()
		return
	protection_left = run_config.post_upgrade_invulnerability_seconds
	if score >= current_stage.target_total_score:
		_advance_to_next_stage()
		return
	state = RunState.ACTIVE
	_refresh_preview()
	_refresh_all_views()

func _apply_upgrades() -> void:
	current_step_interval_ms = run_config.initial_step_interval_ms
	if int(upgrade_levels.get(&"move_speed_up", 0)) > 0:
		var speed_bonus_ms: int = _get_upgrade_value(&"move_speed_up", 0)
		current_step_interval_ms = maxi(
			run_config.minimum_step_interval_ms,
			run_config.initial_step_interval_ms - speed_bonus_ms
		)
	current_turn_buffer_size = 1
	current_magnet_radius = _get_upgrade_value(&"micro_magnet", 0)
	current_preview_length = 0
	current_stage_reset_grace_seconds = 0.0
	current_lean_growth_cycle = _get_upgrade_value(&"lean_growth", 0)
	current_dash_cooldown_seconds = float(_get_upgrade_value(&"dash_burst", 0))
	current_critical_bean_min_score = _get_upgrade_value(&"critical_bean_floor", run_config.critical_bean_initial_min_score)
	current_critical_bean_max_score = max(
		current_critical_bean_min_score,
		_get_upgrade_value(&"critical_bean_ceiling", run_config.critical_bean_initial_max_score)
	)
	current_critical_bean_lifetime_seconds = float(_get_upgrade_value(&"critical_bean_duration", int(run_config.critical_bean_lifetime_seconds)))
	current_wall_phase_total = _get_upgrade_value(&"wall_phase", 0)
	wall_phase_charges = min(wall_phase_charges, current_wall_phase_total)
	if current_dash_cooldown_seconds <= 0.0:
		dash_cooldown_left = 0.0
	elif dash_cooldown_left > current_dash_cooldown_seconds:
		dash_cooldown_left = current_dash_cooldown_seconds
	if critical_bean_active:
		critical_bean_total_lifetime = max(critical_bean_total_lifetime, current_critical_bean_lifetime_seconds)
		critical_bean_time_left = min(critical_bean_time_left, critical_bean_total_lifetime)

func _get_upgrade_value(upgrade_id: StringName, default_value: int) -> int:
	var definition = current_upgrade_lookup.get(upgrade_id)
	if definition == null:
		return default_value
	var current_level := int(upgrade_levels.get(upgrade_id, 0))
	if current_level <= 0:
		return default_value
	return definition.get_value_for_level(current_level)

func _pick_weighted_upgrade_choices(pool: Array, choice_count: int) -> Array:
	var available := pool.duplicate()
	var choices: Array = []
	while not available.is_empty() and choices.size() < choice_count:
		var total_weight := 0
		for definition in available:
			total_weight += max(run_config.get_upgrade_weight(definition.upgrade_id), 1)
		var ticket := rng.randi_range(1, total_weight)
		var accumulated := 0
		for index in range(available.size()):
			var definition = available[index]
			accumulated += max(run_config.get_upgrade_weight(definition.upgrade_id), 1)
			if ticket > accumulated:
				continue
			choices.append(definition)
			available.remove_at(index)
			break
	return choices

func _load_stage(target_stage_number: int, with_pause: bool) -> void:
	var previous_board_size := current_board_size
	stage_number = target_stage_number
	current_stage = run_config.get_stage_config(stage_number)
	current_board_size = _get_board_size_for_stage(current_stage)
	_shift_runtime_cells_for_board_resize(previous_board_size, current_board_size)
	_update_board_layout()
	_sanitize_snake_for_board()
	_filter_beans_for_current_board()
	floor_tile_map.configure(current_board_size, run_config.cell_size)
	obstacle_tile_map.set_layout(current_stage.obstacle_layout, run_config.cell_size)
	_rebuild_obstacle_cache()
	_spawn_beans_up_to_target()
	if with_pause:
		state = RunState.STAGE_PAUSE
		stage_pause_left = run_config.stage_transition_pause_seconds + current_stage_reset_grace_seconds
	else:
		state = RunState.ACTIVE
		stage_pause_left = 0.0
	emit_signal("stage_started", stage_number)
	_refresh_preview()
	_refresh_all_views()

func _advance_to_next_stage() -> void:
	emit_signal("stage_cleared", stage_number)
	stage_time_left += run_config.stage_clear_bonus_seconds
	_load_stage(stage_number + 1, true)

func _rebuild_obstacle_cache() -> void:
	obstacle_cells.clear()
	for blocked_cell in obstacle_tile_map.get_blocked_cells():
		obstacle_cells[blocked_cell] = true

func _spawn_beans_up_to_target() -> void:
	var bean_target: int = current_stage.bean_count_override if current_stage != null and current_stage.bean_count_override > 0 else run_config.default_bean_count
	while beans.size() > bean_target:
		beans.pop_back()
	while beans.size() < bean_target:
		var next_cell := _pick_random_empty_cell()
		if next_cell == Vector2i(-1, -1):
			break
		beans.append(next_cell)

func _schedule_next_critical_bean_spawn() -> void:
	if run_config.critical_bean_max_active <= 0:
		critical_bean_spawn_timer = -1.0
		return
	critical_bean_spawn_timer = run_config.critical_bean_spawn_interval_seconds + rng.randf_range(0.0, run_config.critical_bean_spawn_interval_random_seconds)

func _reset_critical_bean_state() -> void:
	critical_bean_active = false
	critical_bean_position = Vector2i.ZERO
	critical_bean_time_left = 0.0
	critical_bean_total_lifetime = 0.0
	critical_bean_spawn_timer = 0.0
	critical_bean_age = 0.0
	critical_bean_blink_clock = 0.0

func _update_critical_bean(delta: float) -> void:
	if critical_bean_active:
		critical_bean_time_left = max(critical_bean_time_left - delta, 0.0)
		critical_bean_age += delta
		critical_bean_blink_clock += delta
		if critical_bean_time_left <= 0.0:
			_clear_critical_bean()
			_schedule_next_critical_bean_spawn()
		return
	if critical_bean_spawn_timer < 0.0:
		return
	critical_bean_spawn_timer = max(critical_bean_spawn_timer - delta, 0.0)
	if critical_bean_spawn_timer <= 0.0:
		_spawn_critical_bean()

func _spawn_critical_bean() -> void:
	if critical_bean_active:
		return
	var next_cell := _pick_random_empty_cell()
	if next_cell == Vector2i(-1, -1):
		_schedule_next_critical_bean_spawn()
		return
	critical_bean_active = true
	critical_bean_position = next_cell
	critical_bean_total_lifetime = current_critical_bean_lifetime_seconds
	critical_bean_time_left = current_critical_bean_lifetime_seconds
	critical_bean_age = 0.0
	critical_bean_blink_clock = 0.0

func _clear_critical_bean() -> void:
	critical_bean_active = false
	critical_bean_position = Vector2i.ZERO
	critical_bean_time_left = 0.0
	critical_bean_total_lifetime = 0.0
	critical_bean_age = 0.0
	critical_bean_blink_clock = 0.0

func _pick_random_empty_cell() -> Vector2i:
	for _attempt in range(512):
		var candidate := Vector2i(
			rng.randi_range(0, current_board_size.x - 1),
			rng.randi_range(0, current_board_size.y - 1)
		)
		if _is_cell_empty(candidate):
			return candidate
	for y in range(current_board_size.y):
		for x in range(current_board_size.x):
			var fallback := Vector2i(x, y)
			if _is_cell_empty(fallback):
				return fallback
	return Vector2i(-1, -1)

func _is_cell_empty(cell: Vector2i) -> bool:
	if obstacle_cells.has(cell):
		return false
	if _has_any_bean_at(cell):
		return false
	for snake_cell in snake_cells:
		if snake_cell == cell:
			return false
	return true

func _find_bean_index(cell: Vector2i) -> int:
	for index in range(beans.size()):
		if beans[index] == cell:
			return index
	return -1

func _has_any_bean_at(cell: Vector2i) -> bool:
	return _find_bean_index(cell) >= 0 or (critical_bean_active and critical_bean_position == cell)

func _refresh_preview() -> void:
	var preview_cells: Array[Vector2i] = []
	if current_preview_length > 0 and not snake_cells.is_empty():
		var preview_head := snake_cells[0]
		for _step in range(current_preview_length):
			preview_head += direction
			if _get_collision_reason(preview_head) != &"":
				break
			preview_cells.append(preview_head)
	preview_layer.set_preview_cells(preview_cells, run_config.cell_size)

func _refresh_all_views() -> void:
	_refresh_bean_visuals()
	snake_layer.set_snake(snake_cells, run_config.cell_size, protection_left > 0.0, wall_phase_charges)
	_refresh_preview()
	_refresh_ui()

func _refresh_ui() -> void:
	_refresh_bean_visuals()
	hud_root.update_view({
		"stage_number": stage_number,
		"score": score,
		"target_score": current_stage.target_total_score if current_stage != null else 0,
		"time_left": stage_time_left,
		"level": level,
		"xp": xp,
		"next_xp": run_config.get_level_threshold_for_level(level + 1),
		"snake_length": snake_cells.size(),
		"step_interval_ms": current_step_interval_ms,
		"dash_status": _get_dash_status_text(),
		"normal_bean_score": 1,
		"last_bean_score_gain": last_bean_score_gain,
		"critical_bean_status": _get_critical_bean_status_text(),
		"wall_phase_charges": wall_phase_charges,
		"protection_left": protection_left,
		"upgrade_summary": _build_upgrade_summary(),
		"status_text": _get_status_text(),
		"hint_text": _get_hint_text(),
		"show_restart_button": state == RunState.GAME_OVER,
	})
	debug_hud.set_debug_lines(_build_debug_lines())
	_refresh_pause_overlay()

func _refresh_bean_visuals() -> void:
	bean_tile_map.set_bean_state(beans, _build_critical_bean_visual_state(), run_config.cell_size)

func _build_upgrade_summary() -> String:
	var summaries: Array[String] = []
	for definition in run_config.upgrade_defs:
		var current_level := int(upgrade_levels.get(definition.upgrade_id, 0))
		if current_level <= 0:
			continue
		summaries.append(definition.get_applied_summary(current_level))
	if summaries.is_empty():
		return _tr(&"hud.no_upgrades", {}, "No upgrades yet.")
	return "\n".join(summaries)

func _build_debug_lines() -> Array[String]:
	return [
		_tr(&"debug.state", {"value": _get_localized_state_name()}, "State: %s" % _state_to_string(state)),
		_tr(&"debug.head", {"value": str(snake_cells[0] if not snake_cells.is_empty() else Vector2i.ZERO)}, "Head: %s" % str(snake_cells[0] if not snake_cells.is_empty() else Vector2i.ZERO)),
		_tr(&"debug.direction", {"value": str(direction)}, "Direction: %s" % str(direction)),
		_tr(&"debug.board_size", {"value": "%dx%d" % [current_board_size.x, current_board_size.y]}, "Board: %dx%d" % [current_board_size.x, current_board_size.y]),
		_tr(&"debug.queue", {"value": str(queued_directions)}, "Queued: %s" % str(queued_directions)),
		_tr(&"debug.beans", {"value": beans.size()}, "Beans: %d" % beans.size()),
		_tr(&"debug.critical_bean", {"value": _get_critical_bean_debug_text()}, "Critical Bean: %s" % _get_critical_bean_debug_text()),
		_tr(&"debug.wall_phase_charges", {"value": wall_phase_charges}, "Wall Phase: %d" % wall_phase_charges),
		_tr(&"debug.dash_cooldown", {"value": _get_dash_status_text()}, "Dash: %s" % _get_dash_status_text()),
		_tr(&"debug.pause_left", {"value": "%.2f" % stage_pause_left}, "Pause Left: %.2f" % stage_pause_left),
		_tr(&"debug.protection_left", {"value": "%.2f" % protection_left}, "Protection Left: %.2f" % protection_left),
	]

func _get_status_text() -> String:
	match state:
		RunState.UPGRADE_CHOICE:
			return _tr(&"status.choose_upgrade", {}, "Choose one upgrade.")
		RunState.STAGE_PAUSE:
			return _tr(&"status.stage_clear", {"stage": max(stage_number - 1, 1), "bonus": int(run_config.stage_clear_bonus_seconds)}, "Stage %d clear. +%d seconds added." % [max(stage_number - 1, 1), int(run_config.stage_clear_bonus_seconds)])
		RunState.PAUSED:
			return _tr(&"status.paused", {}, "Paused.")
		RunState.GAME_OVER:
			return _get_game_over_text()
		_:
			if protection_left > 0.0:
				return _tr(&"status.protected", {}, "Protected. Dangerous cells will block you, not kill you.")
			return _tr(&"status.active", {}, "Keep eating beans and reach the stage quota.")

func _get_hint_text() -> String:
	if state == RunState.GAME_OVER:
		return _tr(&"hint.game_over", {}, "按“重新开始”按钮或 R 重新开始，按 Esc 返回主菜单，F1 切换调试 HUD。")
	if state == RunState.PAUSED:
		return _tr(&"hint.paused", {}, "按 P 继续，按 Esc 返回主菜单。")
	return _tr(&"hint.active", {}, "Use WASD or Arrow Keys. P pauses. Esc returns to menu. F1 toggles debug HUD.")

func _get_dash_status_text() -> String:
	if current_dash_cooldown_seconds <= 0.0:
		return _tr(&"hud.dash_unavailable", {}, "未解锁")
	if dash_cooldown_left <= 0.0:
		return _tr(&"hud.dash_ready", {}, "就绪")
	return _tr(&"hud.dash_cooldown_seconds", {"value": "%.1f" % dash_cooldown_left}, "{value} 秒")

func _get_critical_bean_status_text() -> String:
	if critical_bean_active:
		return _tr(
			&"hud.critical_bean_active",
			{"min": current_critical_bean_min_score, "max": current_critical_bean_max_score, "time": _format_ui_seconds(critical_bean_time_left)},
			"Critical Bean %d~%d (%s)" % [current_critical_bean_min_score, current_critical_bean_max_score, _format_ui_seconds(critical_bean_time_left)]
		)
	return _tr(
		&"hud.critical_bean_waiting",
		{"min": current_critical_bean_min_score, "max": current_critical_bean_max_score, "time": _format_ui_seconds(critical_bean_spawn_timer)},
		"Critical Bean %d~%d (Next %s)" % [current_critical_bean_min_score, current_critical_bean_max_score, _format_ui_seconds(critical_bean_spawn_timer)]
	)

func _get_critical_bean_debug_text() -> String:
	if critical_bean_active:
		return "%s @ %s" % [_format_ui_seconds(critical_bean_time_left), str(critical_bean_position)]
	return _tr(&"debug.critical_bean_waiting", {"value": _format_ui_seconds(critical_bean_spawn_timer)}, "Next %s" % _format_ui_seconds(critical_bean_spawn_timer))

func _roll_critical_bean_score() -> int:
	var minimum_score: int = current_critical_bean_min_score
	var maximum_score: int = maxi(current_critical_bean_min_score, current_critical_bean_max_score)
	if minimum_score >= maximum_score:
		return minimum_score
	var normalized: float = _sample_left_biased_normalized()
	var span: int = maximum_score - minimum_score
	return minimum_score + int(round(normalized * span))

func _direction_from_name(direction_name: String) -> Vector2i:
	match direction_name:
		"UP":
			return Vector2i.UP
		"DOWN":
			return Vector2i.DOWN
		"LEFT":
			return Vector2i.LEFT
		_:
			return Vector2i.RIGHT

func _get_board_size_for_stage(stage_config) -> Vector2i:
	if stage_config != null and stage_config.board_size.x > 0 and stage_config.board_size.y > 0:
		return stage_config.board_size
	return run_config.board_size

func _update_board_layout() -> void:
	var board_pixel_size := Vector2(current_board_size.x * run_config.cell_size, current_board_size.y * run_config.cell_size)
	var centered_offset := (board_area_size - board_pixel_size) * 0.5
	centered_offset.x = maxf(centered_offset.x, 0.0)
	centered_offset.y = maxf(centered_offset.y, 0.0)
	board_root.position = board_area_origin + centered_offset.floor()

func _shift_runtime_cells_for_board_resize(previous_size: Vector2i, new_size: Vector2i) -> void:
	if previous_size == Vector2i.ZERO or previous_size == new_size:
		return
	var shift_offset := Vector2i(
		int(floor((new_size.x - previous_size.x) / 2.0)),
		int(floor((new_size.y - previous_size.y) / 2.0))
	)
	if shift_offset == Vector2i.ZERO:
		return
	for index in range(snake_cells.size()):
		snake_cells[index] += shift_offset
	for index in range(beans.size()):
		beans[index] += shift_offset
	if critical_bean_active:
		critical_bean_position += shift_offset

func _sanitize_snake_for_board() -> void:
	for cell in snake_cells:
		if _is_out_of_bounds(cell):
			var preserved_length := snake_cells.size()
			queued_directions.clear()
			growth_pending = 0
			direction = _direction_from_name(run_config.initial_direction)
			_setup_starting_snake(preserved_length)
			return

func _filter_beans_for_current_board() -> void:
	var filtered: Array[Vector2i] = []
	for bean_position in beans:
		if _is_out_of_bounds(bean_position):
			continue
		filtered.append(bean_position)
	beans = filtered
	if critical_bean_active and _is_out_of_bounds(critical_bean_position):
		_clear_critical_bean()
		_schedule_next_critical_bean_spawn()

func _register_direction_input(candidate: Vector2i, current_time_msec: int) -> void:
	last_direction_input = candidate
	last_direction_input_time_msec = current_time_msec

func _can_trigger_dash(candidate: Vector2i, current_time_msec: int) -> bool:
	if state != RunState.ACTIVE:
		return false
	if current_dash_cooldown_seconds <= 0.0 or dash_cooldown_left > 0.0:
		return false
	if last_direction_input != candidate:
		return false
	var elapsed_seconds := float(current_time_msec - last_direction_input_time_msec) / 1000.0
	return elapsed_seconds <= run_config.dash_double_tap_window_seconds

func _trigger_dash() -> void:
	dash_cooldown_left = current_dash_cooldown_seconds
	queued_directions.clear()
	step_accumulator = 0.0
	for _step in range(run_config.dash_distance):
		if state != RunState.ACTIVE:
			return
		if not _advance_snake_one_step(true):
			return

func _get_game_over_text() -> String:
	match game_over_reason:
		&"wall":
			return _tr(&"game_over.wall", {}, "Game over. You slammed into the wall.")
		&"self":
			return _tr(&"game_over.self", {}, "Game over. You bit your own body.")
		&"obstacle":
			return _tr(&"game_over.obstacle", {}, "Game over. You hit an obstacle.")
		&"quota_failed":
			return _tr(&"game_over.quota_failed", {}, "Game over. Time ran out before you hit the score target.")
		_:
			return _tr(&"game_over.generic", {}, "Game over.")

func _state_to_string(run_state: int) -> String:
	match run_state:
		RunState.ACTIVE:
			return "ACTIVE"
		RunState.STAGE_PAUSE:
			return "STAGE_PAUSE"
		RunState.PAUSED:
			return "PAUSED"
		RunState.UPGRADE_CHOICE:
			return "UPGRADE_CHOICE"
		RunState.GAME_OVER:
			return "GAME_OVER"
		_:
			return "UNKNOWN"

func _get_localized_state_name() -> String:
	match state:
		RunState.ACTIVE:
			return _tr(&"debug.state_active", {}, "ACTIVE")
		RunState.STAGE_PAUSE:
			return _tr(&"debug.state_stage_pause", {}, "STAGE_PAUSE")
		RunState.PAUSED:
			return _tr(&"debug.state_paused", {}, "PAUSED")
		RunState.UPGRADE_CHOICE:
			return _tr(&"debug.state_upgrade_choice", {}, "UPGRADE_CHOICE")
		RunState.GAME_OVER:
			return _tr(&"debug.state_game_over", {}, "GAME_OVER")
		_:
			return _tr(&"debug.state_unknown", {}, "UNKNOWN")

func _tr(key: StringName, replacements: Dictionary = {}, fallback: String = "") -> String:
	return GameApp.tr_key(key, replacements, fallback)

func _fail_run(reason: StringName) -> void:
	game_over_reason = reason
	state = RunState.GAME_OVER
	emit_signal("run_failed", reason)
	GameApp.mark_score(score)
	upgrade_overlay.hide_overlay()
	_refresh_ui()

func _on_restart_requested() -> void:
	if state != RunState.GAME_OVER:
		return
	start_new_run()

func _toggle_manual_pause() -> void:
	if state == RunState.GAME_OVER or state == RunState.UPGRADE_CHOICE:
		return
	if state == RunState.STAGE_PAUSE:
		return
	if state == RunState.PAUSED:
		state = RunState.ACTIVE
	else:
		state = RunState.PAUSED
	_refresh_ui()

func _build_critical_bean_visual_state() -> Dictionary:
	if not critical_bean_active:
		return {"active": false}
	var lifetime := maxf(critical_bean_total_lifetime, 0.01)
	var life_ratio := clampf(critical_bean_time_left / lifetime, 0.0, 1.0)
	var blink_frequency := lerpf(2.0, 9.0, 1.0 - life_ratio)
	var blink_visible := fposmod(critical_bean_blink_clock * blink_frequency, 1.0) < 0.68
	var spawn_progress := clampf(critical_bean_age / 0.35, 0.0, 1.0)
	return {
		"active": true,
		"position": critical_bean_position,
		"visible": blink_visible,
		"life_ratio": life_ratio,
		"spawn_progress": spawn_progress,
	}

func _sample_left_biased_normalized() -> float:
	for _attempt in range(8):
		var sample: float = rng.randfn(0.24, 0.18)
		if sample >= 0.0 and sample <= 1.0:
			return sample
	return clampf(rng.randfn(0.24, 0.18), 0.0, 1.0)

func _refresh_pause_overlay() -> void:
	pause_overlay.visible = state == RunState.PAUSED
	if not pause_overlay.visible:
		return
	pause_title_label.text = _tr(&"pause.title", {}, "已暂停")
	pause_hint_label.text = _tr(&"pause.hint", {}, "按 P 继续，按 Esc 返回主菜单。")

func _format_ui_seconds(seconds: float) -> String:
	return "%.1f 秒" % maxf(seconds, 0.0)
