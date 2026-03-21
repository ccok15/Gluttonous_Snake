extends PanelContainer
class_name DebugHud

@onready var body_label: Label = $MarginContainer/BodyLabel

func set_debug_lines(lines: Array[String]) -> void:
	body_label.text = "\n".join(lines)
