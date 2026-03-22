extends PanelContainer
class_name GameHud

signal restart_requested

@onready var header_label: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var stage_value: Label = $MarginContainer/VBoxContainer/StatsColumns/LeftStats/StageValue
@onready var score_value: Label = $MarginContainer/VBoxContainer/StatsColumns/LeftStats/ScoreValue
@onready var time_value: Label = $MarginContainer/VBoxContainer/StatsColumns/LeftStats/TimeValue
@onready var level_value: Label = $MarginContainer/VBoxContainer/StatsColumns/LeftStats/LevelValue
@onready var length_value: Label = $MarginContainer/VBoxContainer/StatsColumns/LeftStats/LengthValue
@onready var speed_value: Label = $MarginContainer/VBoxContainer/StatsColumns/RightStats/SpeedValue
@onready var dash_value: Label = $MarginContainer/VBoxContainer/StatsColumns/RightStats/DashValue
@onready var bean_score_value: Label = $MarginContainer/VBoxContainer/StatsColumns/RightStats/BeanScoreValue
@onready var critical_bean_value: Label = $MarginContainer/VBoxContainer/StatsColumns/RightStats/CriticalBeanValue
@onready var wall_phase_value: Label = $MarginContainer/VBoxContainer/StatsColumns/RightStats/WallPhaseValue
@onready var protection_value: Label = $MarginContainer/VBoxContainer/StatsColumns/RightStats/ProtectionValue
@onready var upgrades_header: Label = $MarginContainer/VBoxContainer/DetailColumns/LeftColumn/UpgradesHeader
@onready var upgrades_value: Label = $MarginContainer/VBoxContainer/DetailColumns/LeftColumn/UpgradesValue
@onready var status_header: Label = $MarginContainer/VBoxContainer/DetailColumns/RightColumn/StatusHeader
@onready var status_value: Label = $MarginContainer/VBoxContainer/DetailColumns/RightColumn/StatusValue
@onready var hint_header: Label = $MarginContainer/VBoxContainer/DetailColumns/RightColumn/HintHeader
@onready var hint_value: Label = $MarginContainer/VBoxContainer/DetailColumns/RightColumn/HintValue
@onready var restart_button: Button = $MarginContainer/VBoxContainer/RestartButton

func _ready() -> void:
	GameApp.locale_changed.connect(_on_locale_changed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	wall_phase_value.visible = false
	_refresh_headers()

func update_view(data: Dictionary) -> void:
	stage_value.text = GameApp.tr_key(&"hud.stage", {"value": data.get("stage_number", 1)}, "Stage %d" % data.get("stage_number", 1))
	score_value.text = GameApp.tr_key(&"hud.score", {"score": data.get("score", 0), "target": data.get("target_score", 0)}, "Score %d / %d" % [data.get("score", 0), data.get("target_score", 0)])
	time_value.text = GameApp.tr_key(&"hud.time", {"value": _format_seconds(data.get("time_left", 0.0))}, "Time %s" % _format_seconds(data.get("time_left", 0.0)))
	level_value.text = GameApp.tr_key(&"hud.level", {"level": data.get("level", 1), "xp": data.get("xp", 0), "next_xp": data.get("next_xp", 0)}, "Level %d  XP %d / %d" % [data.get("level", 1), data.get("xp", 0), data.get("next_xp", 0)])
	length_value.text = GameApp.tr_key(&"hud.length", {"value": data.get("snake_length", 0)}, "Length %d" % data.get("snake_length", 0))
	speed_value.text = GameApp.tr_key(&"hud.speed", {"value": data.get("step_interval_ms", 0)}, "Speed %d ms/step" % data.get("step_interval_ms", 0))
	dash_value.text = GameApp.tr_key(&"hud.dash", {"value": data.get("dash_status", "-")}, "Dash %s" % data.get("dash_status", "-"))
	bean_score_value.text = GameApp.tr_key(
		&"hud.bean_score",
		{"normal": data.get("normal_bean_score", 1), "last": data.get("last_bean_score_gain", 1)},
		"Normal Bean +%d (Last +%d)" % [data.get("normal_bean_score", 1), data.get("last_bean_score_gain", 1)]
	)
	critical_bean_value.text = data.get("critical_bean_status", GameApp.tr_key(&"hud.critical_bean_inactive", {}, "暴击豆未出现"))
	protection_value.text = GameApp.tr_key(&"hud.protection", {"value": "%.1f" % data.get("protection_left", 0.0)}, "Protection %.1fs" % data.get("protection_left", 0.0))
	upgrades_value.text = data.get("upgrade_summary", GameApp.tr_key(&"hud.no_upgrades", {}, "No upgrades yet."))
	status_value.text = data.get("status_text", "")
	hint_value.text = data.get("hint_text", "")
	restart_button.visible = data.get("show_restart_button", false)
	restart_button.disabled = not restart_button.visible

func _on_locale_changed(_locale_code: StringName) -> void:
	_refresh_headers()

func _refresh_headers() -> void:
	header_label.text = GameApp.tr_key(&"hud.run_status", {}, header_label.text)
	upgrades_header.text = GameApp.tr_key(&"hud.selected_upgrades", {}, upgrades_header.text)
	status_header.text = GameApp.tr_key(&"hud.status", {}, status_header.text)
	hint_header.text = GameApp.tr_key(&"hud.hints", {}, hint_header.text)
	restart_button.text = GameApp.tr_key(&"hud.restart_run", {}, restart_button.text)

func _on_restart_button_pressed() -> void:
	emit_signal("restart_requested")

func _format_seconds(seconds: float) -> String:
	var safe_seconds = maxf(seconds, 0.0)
	var whole_seconds: int = int(floor(safe_seconds))
	var minutes: int = whole_seconds / 60
	var remaining_seconds: int = whole_seconds % 60
	var deciseconds: int = int((safe_seconds - whole_seconds) * 10.0)
	return "%02d:%02d.%d" % [minutes, remaining_seconds, deciseconds]
