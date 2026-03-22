extends Node

const GAME_RUN_SCENE := preload("res://scenes/game/GameRun.tscn")
const RUN_CONFIG := preload("res://data/config/run/default_run_config.tres")
const SAVE_PROFILE_RESOURCE := preload("res://scripts/core/save_profile.gd")
const WALL_PHASE_DEF := preload("res://data/config/upgrades/wall_phase.tres")

var _failures: Array[String] = []
var _checks: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_bootstrap_game_app()
	_test_move_speed_weight()
	await _test_critical_bean_ignores_magnet()
	await _test_wall_traversal()
	await _test_self_traversal()
	await _test_traversal_visuals_and_hidden_counter()
	_test_traversal_upgrade_copy()
	_finish()

func _bootstrap_game_app() -> void:
	GameApp.set_run_config(RUN_CONFIG)
	GameApp.save_profile = SAVE_PROFILE_RESOURCE.new()
	var unlocked_ids: Array[StringName] = []
	GameApp.save_profile.unlocked_upgrade_ids = unlocked_ids
	GameApp.save_profile.show_debug_hud = false
	GameApp.debug_hud_visible = false
	GameApp.register_language_packs(RUN_CONFIG.language_packs, RUN_CONFIG.default_locale)
	GameApp.set_locale(RUN_CONFIG.default_locale)

func _test_move_speed_weight() -> void:
	_expect(
		RUN_CONFIG.get_upgrade_weight(&"move_speed_up") == RUN_CONFIG.default_upgrade_weight,
		"move_speed_up uses the default upgrade weight"
	)

func _test_critical_bean_ignores_magnet() -> void:
	var run = await _spawn_game_run()
	run.current_magnet_radius = 2
	var snake_cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(4, 5), Vector2i(3, 5)]
	var beans: Array[Vector2i] = [Vector2i(5, 7)]
	run.snake_cells = snake_cells
	run.beans = beans
	run.critical_bean_active = true
	run.critical_bean_position = Vector2i(5, 6)
	run.score = 0
	run.xp = 0
	run.beans_eaten_count = 0
	run.growth_pending = 0
	run._maybe_absorb_nearby_bean()
	_expect(run.critical_bean_active, "critical bean is not auto-absorbed by magnet")
	_expect(run.critical_bean_position == Vector2i(5, 6), "critical bean position stays unchanged after magnet tick")
	_expect(
		run.score == 1 and run._find_bean_index(Vector2i(5, 7)) == -1,
		"normal bean still gets absorbed when critical bean is nearby"
	)
	await _cleanup_run(run)

func _test_wall_traversal() -> void:
	var run = await _spawn_game_run()
	run.current_board_size = Vector2i(10, 10)
	var snake_cells: Array[Vector2i] = [Vector2i(9, 5), Vector2i(8, 5), Vector2i(7, 5)]
	run.snake_cells = snake_cells
	run.direction = Vector2i.RIGHT
	run.wall_phase_charges = 1
	run.beans.clear()
	run.obstacle_cells.clear()
	run.growth_pending = 0
	run.critical_bean_active = false
	run.state = run.RunState.ACTIVE
	var advanced := run._advance_snake_one_step(true)
	_expect(advanced, "wall traversal step resolves without ending the run")
	_expect(run.state == run.RunState.ACTIVE, "wall traversal keeps the run active")
	_expect(run.snake_cells[0] == Vector2i(0, 5), "wall traversal wraps the head to the opposite side")
	_expect(run.wall_phase_charges == 0, "wall traversal consumes exactly one traversal charge")
	await _cleanup_run(run)

func _test_self_traversal() -> void:
	var run = await _spawn_game_run()
	run.current_board_size = Vector2i(10, 10)
	var snake_cells: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3)]
	run.snake_cells = snake_cells
	run.direction = Vector2i.RIGHT
	run.wall_phase_charges = 1
	run.beans.clear()
	run.obstacle_cells.clear()
	run.growth_pending = 0
	run.critical_bean_active = false
	run.state = run.RunState.ACTIVE
	var advanced := run._advance_snake_one_step(true)
	_expect(advanced, "self traversal step resolves without ending the run")
	_expect(run.state == run.RunState.ACTIVE, "self traversal keeps the run active")
	_expect(run.snake_cells[0] == Vector2i(3, 2), "self traversal allows entering the occupied body cell")
	_expect(run.wall_phase_charges == 0, "self traversal consumes exactly one traversal charge")
	await _cleanup_run(run)

func _test_traversal_visuals_and_hidden_counter() -> void:
	var run = await _spawn_game_run()
	run.upgrade_levels[&"wall_phase"] = 1
	run.wall_phase_charges = 1
	run._refresh_all_views()
	_expect(run.snake_layer._traversal_available, "snake head switches to traversal visual when charges remain")
	_expect(not run.hud_root.wall_phase_value.visible, "HUD traversal count stays hidden")
	_expect(run._build_upgrade_summary().contains("穿越术 1 次"), "upgrade summary shows the current traversal count in the parameter panel")
	run.wall_phase_charges = 0
	run._refresh_all_views()
	_expect(not run.snake_layer._traversal_available, "snake head visual resets when traversal is exhausted")
	_expect(run._build_upgrade_summary().contains("穿越术 0 次"), "upgrade summary updates after traversal charges are consumed")
	await _cleanup_run(run)

func _test_traversal_upgrade_copy() -> void:
	_expect(WALL_PHASE_DEF.get_localized_name() == "穿越术", "traversal upgrade is renamed in localized copy")
	_expect(WALL_PHASE_DEF.get_option_description(0) == "增加 1 次穿越机会。", "traversal option card only says it adds one traversal chance")
	_expect(WALL_PHASE_DEF.get_applied_summary(5) == "穿越术 5 次", "traversal summary template includes the traversal count")

func _spawn_game_run() -> GameRun:
	var run: GameRun = GAME_RUN_SCENE.instantiate()
	get_tree().root.add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame
	return run

func _cleanup_run(run: GameRun) -> void:
	if is_instance_valid(run):
		run.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		_checks.append("PASS: %s" % description)
		return
	_failures.append(description)
	_checks.append("FAIL: %s" % description)

func _finish() -> void:
	for line in _checks:
		print(line)
	if _failures.is_empty():
		print("VALIDATION PASSED")
		get_tree().quit(0)
		return
	push_error("VALIDATION FAILED")
	for failure in _failures:
		push_error("- %s" % failure)
	get_tree().quit(1)
