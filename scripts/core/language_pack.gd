extends Resource
class_name LanguagePack

@export var locale_code: StringName = &"zh_CN"
@export var display_name := "简体中文"
@export var entries: Dictionary = {}

func get_text(key: StringName) -> String:
	var normalized_key = String(key)
	if not entries.has(normalized_key):
		return ""
	return str(entries[normalized_key])
