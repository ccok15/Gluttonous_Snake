extends Node

@export var default_run_config: Resource
@export_file("*.tscn") var main_menu_scene := "res://scenes/core/MainMenu.tscn"

func _ready() -> void:
	if default_run_config == null:
		default_run_config = ResourceLoader.load("res://data/config/run/default_run_config.tres")
	if default_run_config == null:
		push_error("Boot could not load a RunConfig.")
		return
	GameApp.set_run_config(default_run_config)
	GameApp.load_or_create_save_profile()
	GameApp.register_language_packs(default_run_config.language_packs, default_run_config.default_locale)
	get_tree().call_deferred("change_scene_to_file", main_menu_scene)
