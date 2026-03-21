extends Node2D
class_name ScorePopupLayer

const POPUP_LIFETIME := 0.65
const FLOAT_DISTANCE := 18.0

var _popups: Array[Dictionary] = []

func _ready() -> void:
	set_process(true)

func clear_popups() -> void:
	for popup in _popups:
		var label: Label = popup.get("label")
		if is_instance_valid(label):
			label.queue_free()
	_popups.clear()

func spawn_popup(cell: Vector2i, cell_size: int, score_gain: int, is_critical: bool) -> void:
	var label := Label.new()
	label.text = "+%d" % score_gain
	label.position = (Vector2(cell) * cell_size) + Vector2(cell_size * 0.15, -cell_size * 0.2)
	label.z_index = 20
	label.modulate = Color("fff3cf") if is_critical else Color("f7f7f7")
	label.add_theme_font_size_override("font_size", max(16, int(cell_size * 1.5)))
	add_child(label)
	_popups.append({
		"label": label,
		"start_position": label.position,
		"elapsed": 0.0,
	})

func _process(delta: float) -> void:
	if _popups.is_empty():
		return
	var expired: Array[int] = []
	for index in range(_popups.size()):
		var popup := _popups[index]
		var label: Label = popup.get("label")
		if not is_instance_valid(label):
			expired.append(index)
			continue
		popup["elapsed"] = float(popup.get("elapsed", 0.0)) + delta
		var elapsed: float = popup["elapsed"]
		var progress := clampf(elapsed / POPUP_LIFETIME, 0.0, 1.0)
		var start_position: Vector2 = popup.get("start_position", Vector2.ZERO)
		label.position = start_position + Vector2(0.0, -FLOAT_DISTANCE * progress)
		label.modulate.a = 1.0 - progress
		_popups[index] = popup
		if progress >= 1.0:
			label.queue_free()
			expired.append(index)
	for index in range(expired.size() - 1, -1, -1):
		_popups.remove_at(expired[index])
