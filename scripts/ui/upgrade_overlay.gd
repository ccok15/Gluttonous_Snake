extends Control
class_name UpgradeOverlay

signal option_chosen(definition)

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var option_one_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionOneButton
@onready var option_two_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionTwoButton
@onready var option_three_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/OptionThreeButton

var _buttons: Array[Button] = []
var _choices: Array = []
var _levels: Dictionary = {}

func _ready() -> void:
	_buttons = [option_one_button, option_two_button, option_three_button]
	for index in range(_buttons.size()):
		_buttons[index].pressed.connect(_on_option_pressed.bind(index))
	GameApp.locale_changed.connect(_on_locale_changed)
	hide_overlay()

func show_choices(choices: Array, current_levels: Dictionary) -> void:
	_choices = choices
	_levels = current_levels.duplicate(true)
	title_label.text = GameApp.tr_key(&"overlay.choose_upgrade", {}, "Choose an Upgrade")
	subtitle_label.text = GameApp.tr_key(&"overlay.timer_paused", {}, "The timer is paused while you decide.")
	for index in range(_buttons.size()):
		var button := _buttons[index]
		if index < choices.size():
			var definition = choices[index]
			var current_level := int(_levels.get(definition.upgrade_id, 0))
			button.visible = true
			button.disabled = false
			button.text = "%s\n%s" % [
				definition.get_option_title(current_level),
				definition.get_option_description(current_level),
			]
		else:
			button.visible = false
			button.disabled = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	option_one_button.grab_focus.call_deferred()

func hide_overlay() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_locale_changed(_locale_code: StringName) -> void:
	if visible and not _choices.is_empty():
		show_choices(_choices, _levels)
		return
	title_label.text = GameApp.tr_key(&"overlay.choose_upgrade", {}, title_label.text)
	subtitle_label.text = GameApp.tr_key(&"overlay.timer_paused", {}, subtitle_label.text)

func _on_option_pressed(index: int) -> void:
	if index >= _choices.size():
		return
	emit_signal("option_chosen", _choices[index])
