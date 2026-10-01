extends Node

const LOBBY_SCRIPT := preload("res://online/online_lobby.gd")

var lobby: RPSOnlineLobby
var starting_match := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("ONLINE BOOTSTRAP READY")
	var session := get_node_or_null("/root/OnlineSession") as RPSOnlineSession
	if session != null:
		session.match_found.connect(_on_match_found)
		session.match_resumed.connect(_on_match_resumed)


func open_lobby() -> void:
	_on_online_button_pressed()

func _on_online_button_pressed() -> void:
	if starting_match:
		return
	if is_instance_valid(lobby):
		lobby.visible = true
		return
	lobby = LOBBY_SCRIPT.new() as RPSOnlineLobby
	lobby.name = "OnlineLobby"
	get_tree().root.add_child(lobby)
	lobby.close_requested.connect(_close_lobby)

func _close_lobby() -> void:
	if is_instance_valid(lobby):
		lobby.queue_free()
		lobby = null

func _on_match_found(payload: Dictionary) -> void:
	await _start_match(payload)

func _on_match_resumed(payload: Dictionary) -> void:
	# If the game scene is still alive after a short disconnect, MatchController
	# will keep its state. Otherwise start from the match setup again.
	var controller := get_tree().get_first_node_in_group(&"match_controller")
	if controller != null and bool(controller.get("online_mode")) and controller.get("state") != null:
		return
	await _start_match(payload)

func _start_match(payload: Dictionary) -> void:
	if starting_match:
		return
	starting_match = true
	_close_lobby()
	get_tree().paused = false

	var menu := get_tree().root.find_child("MainMenu", true, false)
	if menu != null:
		var cloud_controller = menu.get("cloud_controller")
		if is_instance_valid(cloud_controller):
			cloud_controller.queue_free()
		var intro_camera = menu.get("intro_camera")
		if is_instance_valid(intro_camera) and intro_camera.has_method(&"move_to_game_position"):
			await intro_camera.call(&"move_to_game_position")

	var controller := get_tree().get_first_node_in_group(&"match_controller")
	if controller == null:
		push_error("Online: MatchController3D not found.")
		starting_match = false
		return
	if not controller.has_method(&"begin_online_match"):
		push_error("Online: MatchController3D online integration is missing.")
		starting_match = false
		return

	var music_manager := get_node_or_null("/root/MusicManager")
	if music_manager != null and music_manager.has_method(&"play_game_music"):
		music_manager.call(&"play_game_music")

	if menu != null:
		menu.queue_free()
	await controller.call(&"begin_online_match", payload)
	starting_match = false
