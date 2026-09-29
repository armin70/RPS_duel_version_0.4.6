class_name IntroCameraController
extends Camera3D

signal camera_arrived_at_game

# Static-camera replacement.
# Existing menu code may still call this method, but the camera never moves.
func move_to_game_position() -> void:
	camera_arrived_at_game.emit()
	return


# Compatibility helpers for older scene/menu versions.
func move_to_menu_position() -> void:
	return


func reset_to_menu_position() -> void:
	return
