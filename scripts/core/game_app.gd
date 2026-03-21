extends Node

signal locale_changed(locale_code: StringName)

const DEFAULT_SAVE_PATH := "user://save_profile.tres"
const SAVE_PROFILE_RESOURCE = preload("res://scripts/core/save_profile.gd")

var run_config
var save_profile
var debug_hud_visible := true
var localization_packs := {}
var current_locale: StringName = &"zh_CN"

func set_run_config(config) -> void:
	run_config = config

func load_or_create_save_profile():
	if FileAccess.file_exists(DEFAULT_SAVE_PATH):
		var loaded_profile = ResourceLoader.load(DEFAULT_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded_profile != null:
			save_profile = loaded_profile
	if save_profile == null:
		save_profile = SAVE_PROFILE_RESOURCE.new()
		save_profile.show_debug_hud = true
		save_profile.best_score = 0
		save_profile.locale_code = current_locale
		save_profile_to_disk()
	debug_hud_visible = save_profile.show_debug_hud
	if save_profile.locale_code != &"":
		current_locale = save_profile.locale_code
	return save_profile

func save_profile_to_disk() -> void:
	if save_profile == null:
		return
	save_profile.show_debug_hud = debug_hud_visible
	save_profile.locale_code = current_locale
	var error := ResourceSaver.save(save_profile, DEFAULT_SAVE_PATH)
	if error != OK:
		push_warning("Failed to save profile to %s. Error code: %d" % [DEFAULT_SAVE_PATH, error])

func register_language_packs(packs: Array, default_locale: StringName) -> void:
	localization_packs.clear()
	current_locale = default_locale
	for pack in packs:
		if pack == null:
			continue
		localization_packs[pack.locale_code] = pack
	if save_profile != null and save_profile.locale_code != &"" and localization_packs.has(save_profile.locale_code):
		current_locale = save_profile.locale_code
	elif not localization_packs.has(current_locale) and not localization_packs.is_empty():
		var available_locales = localization_packs.keys()
		current_locale = available_locales[0]
	emit_signal("locale_changed", current_locale)

func set_locale(locale_code: StringName) -> void:
	if not localization_packs.has(locale_code):
		return
	current_locale = locale_code
	save_profile_to_disk()
	emit_signal("locale_changed", current_locale)

func tr_key(key: StringName, replacements: Dictionary = {}, fallback: String = "") -> String:
	var translated = fallback if not fallback.is_empty() else String(key)
	if localization_packs.has(current_locale):
		var pack = localization_packs[current_locale]
		var localized_text = pack.get_text(key)
		if not localized_text.is_empty():
			translated = localized_text
	for replacement_key in replacements.keys():
		translated = translated.replace("{%s}" % replacement_key, str(replacements[replacement_key]))
	return translated

func toggle_debug_hud() -> bool:
	debug_hud_visible = not debug_hud_visible
	if save_profile != null:
		save_profile.show_debug_hud = debug_hud_visible
		save_profile_to_disk()
	return debug_hud_visible

func mark_score(score: int) -> void:
	if save_profile == null:
		return
	if score > save_profile.best_score:
		save_profile.best_score = score
		save_profile_to_disk()
