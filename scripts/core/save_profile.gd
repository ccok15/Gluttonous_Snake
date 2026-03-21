extends Resource
class_name SaveProfile

@export var best_score := 0
@export var unlocked_upgrade_ids: Array[StringName] = []
@export var show_debug_hud := true
@export var locale_code: StringName = &"zh_CN"
@export_range(0.0, 1.0, 0.01) var master_volume := 1.0
@export_range(0.0, 1.0, 0.01) var music_volume := 1.0

func is_upgrade_unlocked(upgrade_id: StringName) -> bool:
	return unlocked_upgrade_ids.is_empty() or unlocked_upgrade_ids.has(upgrade_id)
