extends Node
## Camera-facing screen hands: right/bottom anchored player cards.
## Replace only res://game/table/hand_screen_layout.gd.
## Keeps existing scene references and the original 3D card drag/drop system.

@export_category("Scene References")
@export var match_controller: MatchController3D
@export var game_layout: GameLayout3D
@export var camera_3d: Camera3D

# Configurable options: no version suffixes in property names.
@export_category("My Hand - Closed")
@export var hand_closed_uv: Vector2 = Vector2(0.82, 0.76)
@export_range(0.0, 160.0, 1.0) var hand_closed_right_margin_px: float = 18.0
@export_range(0.0, 160.0, 1.0) var hand_closed_bottom_margin_px: float = 24.0
@export_range(0.06, 0.50, 0.01) var hand_closed_scale: float = 0.17
@export_range(25.0, 180.0, 1.0) var hand_closed_step_px: float = 91.0
@export_range(0.15, 0.85, 0.01) var hand_closed_max_width: float = 0.32
@export_range(0.5, 8.0, 0.05) var hand_closed_depth: float = 2.60

@export_category("My Hand - Open")
@export var hand_open_uv: Vector2 = Vector2(0.50, 0.84)
@export_range(0.0, 160.0, 1.0) var hand_open_bottom_margin_px: float = 28.0
@export_range(0.06, 0.60, 0.01) var hand_open_scale: float = 0.24
@export_range(35.0, 240.0, 1.0) var hand_open_step_px: float = 140.0
@export_range(0.20, 0.90, 0.01) var hand_open_max_width: float = 0.46
@export_range(0.5, 8.0, 0.05) var hand_open_depth: float = 2.05
@export_range(0.0, 5.0, 0.25) var hand_open_fan_degrees: float = 1.0
@export_range(0.0, 24.0, 1.0) var hand_open_arc_px: float = 7.0
@export_range(0.08, 0.8, 0.01) var hand_animation_seconds: float = 0.28

@export_category("Enemy Hand - Top Left")
@export var enemy_hand_uv: Vector2 = Vector2(0.16, 0.18)
@export_range(0.06, 0.50, 0.01) var enemy_hand_scale: float = 0.15
@export_range(15.0, 150.0, 1.0) var enemy_hand_step_px: float = 48.0
@export_range(0.12, 0.65, 0.01) var enemy_hand_max_width: float = 0.24
@export_range(0.5, 8.0, 0.05) var enemy_hand_depth: float = 2.80

const BASE_CARD_WIDTH: float = 0.35
const BASE_CARD_HEIGHT: float = 0.525
const HIT_MARGIN: float = 24.0

var _opened: bool = false
var _open_fraction: float = 0.0
var _my_hand_rect: Rect2 = Rect2()


func _ready() -> void:
	# Apply hand layout after MatchController's regular card reflow.
	process_priority = 100
	if not is_instance_valid(match_controller):
		match_controller = get_tree().get_first_node_in_group("match_controller") as MatchController3D
	if is_instance_valid(match_controller):
		if not is_instance_valid(game_layout):
			game_layout = match_controller.game_layout
		if not is_instance_valid(camera_3d):
			camera_3d = match_controller.camera_3d
	if not is_instance_valid(match_controller) or not is_instance_valid(game_layout):
		push_warning("HandScreenLayout: Connect Match Controller and Game Layout.")


func _input(event: InputEvent) -> void:
	if not _game_is_active():
		return
	if match_controller.deck_selection_active or match_controller.hero_ground_selection_active:
		return
	if is_instance_valid(match_controller.dragged_card):
		return

	var click: Vector2
	if event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return
		click = event.position
	elif event is InputEventScreenTouch:
		if not event.pressed:
			return
		click = event.position
	else:
		return

	if not _opened:
		if _my_hand_rect.has_point(click):
			_opened = true
			get_viewport().set_input_as_handled()
	elif not _my_hand_rect.has_point(click):
		_opened = false
		# Board and HUD clicks must keep their own behavior.


func _process(delta: float) -> void:
	if not _game_is_active():
		_my_hand_rect = Rect2()
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		camera = camera_3d
	if not is_instance_valid(camera):
		return

	var screen: Vector2 = get_viewport().get_visible_rect().size
	if screen.x < 1.0 or screen.y < 1.0:
		return
	var goal: float = 1.0 if _opened else 0.0
	_open_fraction = move_toward(_open_fraction, goal,
		delta / maxf(hand_animation_seconds, 0.001))
	var blend: float = _open_fraction * _open_fraction * (3.0 - 2.0 * _open_fraction)
	var px_ratio: float = screen.y / 1080.0

	# Preserve the compact card scales. Only change screen placement.
	var center: Vector2 = hand_closed_uv.lerp(hand_open_uv, blend) * screen
	var depth: float = lerpf(hand_closed_depth, hand_open_depth, blend)
	var scale_value: float = lerpf(hand_closed_scale, hand_open_scale, blend)
	var desired_step: float = lerpf(hand_closed_step_px, hand_open_step_px, blend) * px_ratio
	var max_width: float = lerpf(hand_closed_max_width, hand_open_max_width, blend) * screen.x
	var face_basis: Basis = camera.global_transform.basis.orthonormalized() * Basis(Vector3.RIGHT, PI / 2.0)

	_set_hand_origin(game_layout.player_hand_origin, camera, face_basis, center, depth, scale_value)
	var enemy_center: Vector2 = enemy_hand_uv * screen
	_set_hand_origin(game_layout.opponent_hand_origin, camera, face_basis,
		enemy_center, enemy_hand_depth, enemy_hand_scale)

	_update_own_cards(camera, face_basis, center, depth, scale_value,
		desired_step, max_width, blend)
	_update_enemy_cards(camera, face_basis, enemy_center, screen, px_ratio)


func _set_hand_origin(origin: Node3D, camera: Camera3D, facing: Basis,
		pixel_center: Vector2, depth: float, scale_value: float) -> void:
	if not is_instance_valid(origin):
		return
	origin.global_transform = Transform3D(
		facing.scaled(Vector3.ONE * scale_value),
		camera.project_position(pixel_center, depth))


func _screen_card_size(camera: Camera3D, face_basis: Basis, pixel_center: Vector2,
		depth: float, scale_value: float) -> Vector2:
	# Measurement is used ONLY for spacing/hit targets, never for scaling a card.
	var middle: Vector3 = camera.project_position(pixel_center, depth)
	var half_x: Vector3 = face_basis.x * (BASE_CARD_WIDTH * scale_value * 0.5)
	var half_y: Vector3 = face_basis.z * (BASE_CARD_HEIGHT * scale_value * 0.5)
	var width: float = camera.unproject_position(middle + half_x).distance_to(
		camera.unproject_position(middle - half_x))
	var height: float = camera.unproject_position(middle + half_y).distance_to(
		camera.unproject_position(middle - half_y))
	return Vector2(maxf(width, 1.0), maxf(height, 1.0))


func _effective_step(wanted_step: float, count: int, card_width: float,
		max_row_width: float) -> float:
	if count <= 1:
		return 0.0
	var fit_step: float = (max_row_width - card_width) / float(count - 1)
	return maxf(6.0, minf(wanted_step, fit_step))


func _update_own_cards(camera: Camera3D, facing: Basis, center: Vector2,
		depth: float, scale_value: float, desired_step: float,
		max_width: float, blend: float) -> void:
	_my_hand_rect = Rect2()
	var player: PlayerState = match_controller.state.get_player(match_controller.local_player_id)
	if player == null:
		return
	var count: int = player.hand.size()
	if count == 0:
		return

	var card_size: Vector2 = _screen_card_size(camera, facing, center, depth, scale_value)
	var step: float = _effective_step(desired_step, count, card_size.x, max_width)
	var entire_width: float = card_size.x + step * float(count - 1)
	var arc: float = hand_open_arc_px * blend * (get_viewport().get_visible_rect().size.y / 1080.0)
	_my_hand_rect = Rect2(
		center - Vector2(entire_width * 0.5, card_size.y * 0.5) - Vector2.ONE * HIT_MARGIN,
		Vector2(entire_width + HIT_MARGIN * 2.0, card_size.y + arc + HIT_MARGIN * 2.0))

	for i: int in range(count):
		var card: CardInstance = player.hand[i]
		var view: Card3D = match_controller.card_views.get(card.instance_id, null) as Card3D
		if not is_instance_valid(view) or view == match_controller.dragged_card:
			continue
		if view.card_instance == null or view.card_instance.zone != CardZone.Type.HAND:
			continue
		var offset: float = float(i) - float(count - 1) * 0.5
		var relative: float = offset / maxf(float(count - 1) * 0.5, 1.0)
		var screen_pos: Vector2 = center + Vector2(offset * step, arc * relative * relative)
		var rotation: Basis = Basis(Vector3.UP, deg_to_rad(
			-offset * hand_open_fan_degrees * blend))
		view.move_home(Transform3D(
			(facing * rotation).scaled(Vector3.ONE * scale_value),
			camera.project_position(screen_pos, depth - 0.002 * float(i))))

	# Align the actual rendered artwork, not the hand's guessed center.
	# This also handles different hand counts without accumulating drift.
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var bounds: Rect2 = _player_cards_screen_rect(camera, player)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var closed_right: float = screen.x - hand_closed_right_margin_px * screen.y / 1080.0
	var x_closed_shift: float = closed_right - bounds.end.x
	var x_open_shift: float = screen.x * 0.5 - bounds.get_center().x
	var bottom_margin: float = lerpf(hand_closed_bottom_margin_px,
		hand_open_bottom_margin_px, blend) * screen.y / 1080.0
	var offset_px: Vector2 = Vector2(
		lerpf(x_closed_shift, x_open_shift, blend),
		screen.y - bottom_margin - bounds.end.y)

	if is_instance_valid(game_layout.player_hand_origin):
		var anchor: Node3D = game_layout.player_hand_origin
		var anchor_transform: Transform3D = anchor.global_transform
		anchor_transform.origin = camera.project_position(
			camera.unproject_position(anchor.global_position) + offset_px, depth)
		anchor.global_transform = anchor_transform

	for i: int in range(count):
		var card: CardInstance = player.hand[i]
		var view: Card3D = match_controller.card_views.get(card.instance_id, null) as Card3D
		if not is_instance_valid(view) or view == match_controller.dragged_card:
			continue
		if view.card_instance == null or view.card_instance.zone != CardZone.Type.HAND:
			continue
		var move_transform: Transform3D = view.home_transform
		var view_depth: float = depth - 0.002 * float(i)
		move_transform.origin = camera.project_position(
			camera.unproject_position(view.global_position) + offset_px, view_depth)
		view.move_home(move_transform)

	# Use real card dimensions for click-to-open and click-away hit tests.
	_my_hand_rect = _player_cards_screen_rect(camera, player).grow(HIT_MARGIN)


func _player_cards_screen_rect(camera: Camera3D, player: PlayerState) -> Rect2:
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var found: bool = false
	for card: CardInstance in player.hand:
		var view: Card3D = match_controller.card_views.get(card.instance_id, null) as Card3D
		if not is_instance_valid(view) or view == match_controller.dragged_card:
			continue
		if view.card_instance == null or view.card_instance.zone != CardZone.Type.HAND:
			continue
		var artwork: MeshInstance3D = view.card_art
		if not is_instance_valid(artwork) or artwork.mesh == null:
			continue
		var mesh_bounds: AABB = artwork.mesh.get_aabb()
		# CardArt uses a QuadMesh in its XY local plane, rotated by the child node.
		for x in [mesh_bounds.position.x, mesh_bounds.end.x]:
			for y in [mesh_bounds.position.y, mesh_bounds.end.y]:
				var local_corner: Vector3 = Vector3(x, y, mesh_bounds.position.z)
				var point: Vector2 = camera.unproject_position(
					artwork.global_transform * local_corner)
				minimum = minimum.min(point)
				maximum = maximum.max(point)
				found = true
	if not found:
		return Rect2()
	return Rect2(minimum, maximum - minimum)


func _update_enemy_cards(camera: Camera3D, facing: Basis,
		center: Vector2, screen: Vector2, px_ratio: float) -> void:
	var enemy_id: int = 2 if match_controller.local_player_id == 1 else 1
	var opponent: PlayerState = match_controller.state.get_player(enemy_id)
	if opponent == null:
		return
	var count: int = opponent.hand.size()
	if count == 0:
		return
	var size: Vector2 = _screen_card_size(camera, facing, center,
		enemy_hand_depth, enemy_hand_scale)
	var step: float = _effective_step(enemy_hand_step_px * px_ratio, count,
		size.x, enemy_hand_max_width * screen.x)
	for i: int in range(count):
		var card: CardInstance = opponent.hand[i]
		var view: Card3D = match_controller.opponent_hand_views.get(card.instance_id, null) as Card3D
		if not is_instance_valid(view):
			continue
		if view.card_instance == null or view.card_instance.zone != CardZone.Type.HAND:
			continue
		var offset: float = float(i) - float(count - 1) * 0.5
		var pixel: Vector2 = center + Vector2(offset * step, 0.0)
		view.move_home(Transform3D(
			facing.scaled(Vector3.ONE * enemy_hand_scale),
			camera.project_position(pixel, enemy_hand_depth - 0.002 * float(i))))


func _game_is_active() -> bool:
	return is_instance_valid(match_controller) \
		and is_instance_valid(game_layout) \
		and match_controller.state != null
