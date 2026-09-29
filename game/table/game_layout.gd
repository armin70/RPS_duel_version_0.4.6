class_name GameLayout3D
extends Node3D

# PHYSICAL BOARD MODE
# Move BoardPlane under this GameLayout node in the scene tree.
# Then transform GameLayout itself in the editor.
# PlayerBoard / DealerRow / OpponentBoard / collisions / CardAnchors will all
# physically inherit the same transform. Runtime code never overwrites them.




@export_category("Hand Layout")
@export var hand_spacing: float = 0.25
@export var hand_angle_degrees: float = 10.0
@export var hand_arc_depth: float = 0.03


@onready var player_hand_origin: Node3D = $PlayerHand
@onready var opponent_hand_origin: Node3D = $OpponentHand

@onready var dealer_places: Dictionary = {
	DealerSlotID.Type.LEFT:
		$DealerRow/DealerLeft,

	DealerSlotID.Type.MIDDLE_0:
		$DealerRow/DealerMiddle0,

	DealerSlotID.Type.MIDDLE_1:
		$DealerRow/DealerMiddle1,

	DealerSlotID.Type.RIGHT:
		$DealerRow/DealerRight
}


@onready var board_places: Dictionary = {
	1: {
		SlotID.Type.FRONT_LEFT:
			$PlayerBoard/FrontRow/FrontLeft,
		SlotID.Type.FRONT_MIDDLE_0:
			$PlayerBoard/FrontRow/FrontMiddle0,
		SlotID.Type.FRONT_MIDDLE_1:
			$PlayerBoard/FrontRow/FrontMiddle1,
		SlotID.Type.FRONT_RIGHT:
			$PlayerBoard/FrontRow/FrontRight,

		SlotID.Type.BACK_LEFT:
			$PlayerBoard/BackRow/BackLeft,
		SlotID.Type.BACK_MIDDLE_0:
			$PlayerBoard/BackRow/BackMiddle0,
		SlotID.Type.BACK_MIDDLE_1:
			$PlayerBoard/BackRow/BackMiddle1,
		SlotID.Type.BACK_RIGHT:
			$PlayerBoard/BackRow/BackRight
	},

	2: {
		SlotID.Type.FRONT_LEFT:
			$OpponentBoard/FrontRow/FrontLeft,
		SlotID.Type.FRONT_MIDDLE_0:
			$OpponentBoard/FrontRow/FrontMiddle0,
		SlotID.Type.FRONT_MIDDLE_1:
			$OpponentBoard/FrontRow/FrontMiddle1,
		SlotID.Type.FRONT_RIGHT:
			$OpponentBoard/FrontRow/FrontRight,

		SlotID.Type.BACK_LEFT:
			$OpponentBoard/BackRow/BackLeft,
		SlotID.Type.BACK_MIDDLE_0:
			$OpponentBoard/BackRow/BackMiddle0,
		SlotID.Type.BACK_MIDDLE_1:
			$OpponentBoard/BackRow/BackMiddle1,
		SlotID.Type.BACK_RIGHT:
			$OpponentBoard/BackRow/BackRight
	}
}

@onready var pile_entities: Dictionary = {
	1: {
		CardPile3D.Type.DRAW:
			$PlayerPiles/DrawPile,

		CardPile3D.Type.DISCARD:
			$PlayerPiles/DiscardPile,

		CardPile3D.Type.RESERVE:
			$PlayerPiles/ReservePile
	},

	2: {
		CardPile3D.Type.DRAW:
			$OpponentPiles/DrawPile,

		CardPile3D.Type.DISCARD:
			$OpponentPiles/DiscardPile,

		CardPile3D.Type.RESERVE:
			$OpponentPiles/ReservePile
	}
}


func _ready() -> void:
	# Scene transforms are now the single source of truth.
	# Nothing here moves, rotates or scales the board, camera, hands or slots.
	_configure_dealer_places()
	_configure_board_places()


func _configure_dealer_places() -> void:
	for slot_id: int in dealer_places:
		var place := dealer_places[slot_id] as CardPlace3D

		_configure_place(
			place,
			CardPlace3D.Kind.DEALER,
			0,
			slot_id
		)


func _configure_board_places() -> void:
	for visual_player_id: int in board_places:
		var player_places: Dictionary = board_places[
			visual_player_id
		]
		var logical_owner_id: int = _visual_to_logical_player_id(
			visual_player_id
		)

		for slot_id: int in player_places:
			var place := (
				player_places[slot_id] as CardPlace3D
			)

			_configure_place(
				place,
				CardPlace3D.Kind.PLAYER_BOARD,
				logical_owner_id,
				slot_id
			)


func _configure_place(
	place: CardPlace3D,
	kind: CardPlace3D.Kind,
	owner_id: int,
	logical_id: int
) -> void:
	if place == null:
		return

	place.kind = kind
	place.owner_id = owner_id
	place.logical_id = logical_id

	# Layer 2 is reserved for board drop targets.
	place.collision_layer = 2
	place.collision_mask = 0
	place.input_ray_pickable = true


func get_dealer_anchor(
	slot_id: int
) -> Marker3D:
	var place := dealer_places.get(
		slot_id,
		null
	) as CardPlace3D

	if place == null:
		return null

	return place.card_anchor


func _controller_bool_property(
	controller: Node,
	property_name: StringName
) -> bool:
	if controller == null:
		return false

	for property_info: Dictionary in controller.get_property_list():
		if StringName(property_info.get("name", "")) == property_name:
			return bool(controller.get(property_name))

	return false


func _is_online_match_active() -> bool:
	var tree := get_tree()
	if tree == null:
		return false

	var controller := tree.get_first_node_in_group(
		&"match_controller"
	)

	if controller == null:
		return false

	# Current controller uses `online_mode`. Keep the legacy property check too
	# so older main_game scene/script combinations do not break this fix.
	if _controller_bool_property(controller, &"online_mode"):
		return true

	return _controller_bool_property(
		controller,
		&"online_mode_enabled"
	)


var _forced_local_view_player_id: int = 0


func set_local_view_player_id(player_id: int) -> void:
	# Online seat becomes known after GameLayout._ready().
	# Re-assign the physical CardPlace owners as soon as the real seat is known.
	_forced_local_view_player_id = player_id if player_id in [1, 2] else 0
	_configure_board_places()


func _get_local_view_player_id() -> int:
	# Prefer the explicit seat supplied by MatchController once online setup starts.
	if _forced_local_view_player_id in [1, 2]:
		return _forced_local_view_player_id

	# IMPORTANT:
	# A stale OnlineSession.current_match can survive after leaving an online
	# match. It must NEVER change the Single Player camera/hand ownership.
	#
	# Only a controller that is actively running an online match may swap the
	# logical server seat onto the local visual side.
	if not _is_online_match_active():
		return 1

	var session := get_node_or_null("/root/OnlineSession")
	if session == null:
		return 1

	var current_match_variant = session.get("current_match")
	if not (current_match_variant is Dictionary):
		return 1

	var current_match: Dictionary = current_match_variant
	if current_match.is_empty():
		return 1

	var seat: int = int(current_match.get("seat", 1))
	if seat not in [1, 2]:
		return 1

	return seat


func _logical_to_visual_player_id(logical_player_id: int) -> int:
	if logical_player_id not in [1, 2]:
		return logical_player_id

	var local_view_player_id: int = _get_local_view_player_id()

	# Visual side 1 is always "me"; visual side 2 is always "opponent".
	if logical_player_id == local_view_player_id:
		return 1
	return 2


func _visual_to_logical_player_id(visual_player_id: int) -> int:
	if visual_player_id not in [1, 2]:
		return visual_player_id

	var local_view_player_id: int = _get_local_view_player_id()

	if visual_player_id == 1:
		return local_view_player_id
	return 2 if local_view_player_id == 1 else 1


func get_board_place(
	player_id: int,
	slot_id: int
) -> CardPlace3D:
	var visual_player_id: int = _logical_to_visual_player_id(
		player_id
	)
	var player_places: Dictionary = board_places.get(
		visual_player_id,
		{}
	)

	return player_places.get(
		slot_id,
		null
	) as CardPlace3D


func get_hand_transform(
	player_id: int,
	index: int,
	card_count: int
) -> Transform3D:
	var hand_origin: Node3D
	var visual_player_id: int = _logical_to_visual_player_id(
		player_id
	)

	if visual_player_id == 1:
		hand_origin = player_hand_origin
	else:
		hand_origin = opponent_hand_origin

	if card_count <= 0:
		return hand_origin.global_transform

	var center: float = float(card_count - 1) / 2.0
	var offset: float = float(index) - center

	var local_position := Vector3(
		offset * hand_spacing,
		0.0,
		abs(offset) * hand_arc_depth
	)

	var angle: float = deg_to_rad(
		-offset * hand_angle_degrees
	)

	var local_transform := Transform3D(
		Basis(Vector3.UP, angle),
		local_position
	)

	return hand_origin.global_transform * local_transform


func get_pile_entity(
	player_id: int,
	pile_type: CardPile3D.Type
) -> CardPile3D:
	var visual_player_id: int = _logical_to_visual_player_id(
		player_id
	)
	var player_piles: Dictionary = \
		pile_entities.get(
			visual_player_id,
			{}
		)

	return player_piles.get(
		pile_type,
		null
	) as CardPile3D


func get_board_anchor_transform(
	player_id: int,
	slot_id: int
) -> Transform3D:
	var place: CardPlace3D = get_board_place(
		player_id,
		slot_id
	)

	if place == null or place.card_anchor == null:
		return Transform3D.IDENTITY

	return place.card_anchor.global_transform


func get_middle_row_center_transform(
	player_id: int,
	row: int
) -> Transform3D:
	var first_slot_id: int
	var second_slot_id: int

	if row == SlotID.Row.FRONT:
		first_slot_id = SlotID.Type.FRONT_MIDDLE_0
		second_slot_id = SlotID.Type.FRONT_MIDDLE_1
	else:
		first_slot_id = SlotID.Type.BACK_MIDDLE_0
		second_slot_id = SlotID.Type.BACK_MIDDLE_1

	var first_transform: Transform3D = get_board_anchor_transform(
		player_id,
		first_slot_id
	)
	var second_transform: Transform3D = get_board_anchor_transform(
		player_id,
		second_slot_id
	)

	var centered: Transform3D = first_transform
	centered.origin = (
		first_transform.origin
		+ second_transform.origin
	) * 0.5

	return centered


func get_board_visual_transform(
	player_id: int,
	slot_id: int,
	_middle_row_card_count: int = 2
) -> Transform3D:
	if not SlotID.is_valid(slot_id):
		return Transform3D.IDENTITY

	# Middle cards remain on their exact upper/lower half of the tall printed
	# middle rectangle; a single middle card is not re-centered.
	return get_board_anchor_transform(
		player_id,
		slot_id
	)
