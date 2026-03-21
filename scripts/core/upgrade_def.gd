extends Resource
class_name UpgradeDef

@export var upgrade_id: StringName
@export var display_name := ""
@export_multiline var base_description := ""
@export_multiline var option_description_template := ""
@export var summary_template := ""
@export_range(1, 99, 1) var max_level := 1
@export var level_values: Array[int] = []

func can_level(current_level: int) -> bool:
	return current_level < max_level

func get_localized_name() -> String:
	var key := StringName("upgrade.%s.name" % String(upgrade_id))
	return GameApp.tr_key(key, {}, display_name)

func get_next_level(current_level: int) -> int:
	return min(current_level + 1, max_level)

func get_value_for_level(level: int) -> int:
	if level_values.is_empty():
		return level
	var clamped_index: int = clamp(level - 1, 0, level_values.size() - 1)
	return level_values[clamped_index]

func get_option_title(current_level: int) -> String:
	return GameApp.tr_key(
		&"upgrade.option_title",
		{
			"name": get_localized_name(),
			"level": get_next_level(current_level),
		},
		"%s Lv.%d" % [display_name, get_next_level(current_level)]
	)

func get_option_description(current_level: int) -> String:
	var next_level := get_next_level(current_level)
	var replacements := _build_replacements(next_level)
	var fallback := _format_template(option_description_template, replacements, base_description)
	return GameApp.tr_key(
		StringName("upgrade.%s.option_desc" % String(upgrade_id)),
		replacements,
		fallback if not fallback.is_empty() else GameApp.tr_key(&"upgrade.generic.option_desc", {}, "Apply a new run modifier.")
	)

func get_applied_summary(level: int) -> String:
	var replacements := _build_replacements(level)
	var fallback := _format_template(summary_template, replacements, "%s Lv.%d" % [display_name, level])
	return GameApp.tr_key(
		StringName("upgrade.%s.summary" % String(upgrade_id)),
		replacements,
		fallback if not fallback.is_empty() else GameApp.tr_key(&"upgrade.generic.summary", replacements, "%s Lv.%d" % [display_name, level])
	)

func get_level_gain(previous_level: int, new_level: int) -> int:
	var previous_value := 0
	if previous_level > 0:
		previous_value = get_value_for_level(previous_level)
	return max(get_value_for_level(new_level) - previous_value, 0)

func _build_replacements(level: int) -> Dictionary:
	var value := get_value_for_level(level)
	var replacements := {
		"name": get_localized_name(),
		"level": level,
		"value": value,
		"cycle": value,
	}
	if String(upgrade_id) == "lean_growth":
		replacements["value"] = max(value - 1, 0)
		replacements["cycle"] = value
	return replacements

func _format_template(template: String, replacements: Dictionary, default_text: String = "") -> String:
	if template.is_empty():
		return default_text
	var formatted := template
	for replacement_key in replacements.keys():
		formatted = formatted.replace("{%s}" % replacement_key, str(replacements[replacement_key]))
	return formatted
