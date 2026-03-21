extends Control

@export_file("*.tscn") var game_scene_path := "res://scenes/game/GameRun.tscn"

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var best_score_header: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BestScoreHeader
@onready var continue_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var best_score_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BestScoreValue
@onready var start_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	GameApp.locale_changed.connect(_on_locale_changed)
	continue_button.disabled = true
	_refresh_texts()
	start_button.grab_focus.call_deferred()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)

func _on_continue_button_pressed() -> void:
	pass

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_locale_changed(_locale_code: StringName) -> void:
	_refresh_texts()

func _refresh_texts() -> void:
	title_label.text = GameApp.tr_key(&"menu.title", {}, title_label.text)
	subtitle_label.text = GameApp.tr_key(&"menu.subtitle", {}, subtitle_label.text)
	best_score_header.text = GameApp.tr_key(&"menu.best_score", {}, best_score_header.text)
	start_button.text = GameApp.tr_key(&"menu.start_run", {}, start_button.text)
	continue_button.text = GameApp.tr_key(&"menu.continue_soon", {}, continue_button.text)
	quit_button.text = GameApp.tr_key(&"menu.quit", {}, quit_button.text)
	best_score_value.text = str(GameApp.save_profile.best_score if GameApp.save_profile != null else 0)
