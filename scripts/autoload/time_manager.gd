extends Node
## TimeManager — tracks the in-game day counter and emits signals when the day changes.
## Days advance only when the player clicks the "Следующий день" button.

signal day_changed(new_day: int)

var current_day: int = 1


func advance_day() -> void:
	current_day += 1
	day_changed.emit(current_day)


func reset() -> void:
	current_day = 1
	day_changed.emit(current_day)
