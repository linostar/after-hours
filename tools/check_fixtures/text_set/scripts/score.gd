extends Node
## Violation: writes words and numbers onto Controls.


func show_score(button: Button, score: int) -> void:
	button.text = str(score)
	button.set_text("Go")


func is_empty(button: Button) -> bool:
	return button.text == ""
