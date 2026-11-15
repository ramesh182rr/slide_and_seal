class_name LeaveDialog
extends ConfirmDialog
## "Leave this puzzle?" for Android Back / Escape (P-009): a ConfirmDialog with Stay / Leave.

signal stay_requested
signal leave_requested


func _init() -> void:
	setup("Leave this puzzle?", "Your progress in this puzzle will be lost.", "Stay", "Leave")
	cancelled.connect(func() -> void: stay_requested.emit())
	confirmed.connect(func() -> void: leave_requested.emit())
