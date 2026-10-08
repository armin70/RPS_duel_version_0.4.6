class_name Card3D
extends Area3D


signal drag_requested(
	card_view: Card3D,
	screen_position: Vector2
)

signal inspect_requested(
	card_view: Card3D
)


@export var back_texture: Texture2D

@export_category("Card Inspect")
@export_range(0.20, 1.50, 0.05)
var inspect_hold_time: float = 0.45

@export_range(4.0, 80.0, 1.0)
var inspect_move_cancel_distance: float = 18.0


var card_instance: CardInstance
var home_transform: Transform3D
var is_draggable: bool = false
var is_disabled: bool = false
var is_face_up: bool = true


@onready var card_body: MeshInstance3D = $CardBody
@onready var card_art: MeshInstance3D = $CardArt
@onready var card_name: Label3D = $CardName
@onready var disabled_label: Label3D = $DisabledLabel
@onready var disabled_card: MeshInstance3D = $Disabled_card

@onready var shield_badge: Node3D = %ShieldBadge
@onready var shield_count_label: Label3D = %ShieldCount


const KEEP_RAISE_HEIGHT: float = 0.18


const CARD_FRONT_SIZE := Vector2(0.35, 0.525)
const HERO_ART_SCALE: float = 1.28

@export_category("Hero Board")
@export_range(0.0, 0.50, 0.01)
var hero_board_lift: float = 0.18

const HERO_TYPE_ROCK: Texture2D = preload(
	"res://art/hero_type_icons/rock.png"
)
const HERO_TYPE_PAPER: Texture2D = preload(
	"res://art/hero_type_icons/paper.png"
)
const HERO_TYPE_SCISSORS: Texture2D = preload(
	"res://art/hero_type_icons/scissors.png"
)


var keep_selected: bool = false
var displayed_shield_count: int = 0
var shield_badge_base_scale: Vector3 = Vector3.ONE
var card_material: StandardMaterial3D
var hero_status_label: Label3D
var hero_hp_label: Label3D
var hero_type_icon: MeshInstance3D
var hero_type_material: StandardMaterial3D
var card_status_label: Label3D
var displayed_card_status: String = ""

var _inspect_press_active: bool = false
var _inspect_press_position: Vector2 = Vector2.ZERO
var _inspect_press_serial: int = 0


func _ready() -> void:
	shield_badge_base_scale = shield_badge.scale
	shield_badge.visible = false

	collision_layer = 1
	collision_mask = 0
	input_ray_pickable = true

	_create_card_material()
	_build_hero_status_label()
	_build_hero_hp_label()
	_build_hero_type_icon()
	_build_card_status_label()
	_refresh_gesture_override_label()
	_refresh_hero_hp_visual()


func _build_hero_status_label() -> void:
	if hero_status_label != null:
		return
	hero_status_label = Label3D.new()
	hero_status_label.name = "HeroStatusLabel"
	hero_status_label.position = Vector3(0.0, 0.12, -0.28)
	hero_status_label.font_size = 11
	hero_status_label.outline_size = 5
	hero_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hero_status_label.no_depth_test = true
	hero_status_label.visible = false
	add_child(hero_status_label)


func _build_hero_hp_label() -> void:
	if hero_hp_label != null:
		return

	hero_hp_label = Label3D.new()
	hero_hp_label.name = "HeroHPLabel"
	hero_hp_label.font_size = 100
	hero_hp_label.outline_size = 10
	hero_hp_label.modulate = Color.WHITE
	hero_hp_label.outline_modulate = Color.BLACK
	hero_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_hp_label.no_depth_test = true
	hero_hp_label.visible = false
	add_child(hero_hp_label)


func _build_hero_type_icon() -> void:
	if hero_type_icon != null:
		return

	hero_type_icon = MeshInstance3D.new()
	hero_type_icon.name = "HeroTypeIcon"

	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	hero_type_icon.mesh = quad

	hero_type_material = StandardMaterial3D.new()
	hero_type_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hero_type_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hero_type_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hero_type_material.no_depth_test = true

	hero_type_icon.material_override = hero_type_material
	hero_type_icon.visible = false
	add_child(hero_type_icon)


func _hero_overlay_layout() -> Dictionary:
	if (
		card_instance == null
		or card_instance.definition == null
		or not card_instance.is_hero()
	):
		return {}

	var hero_definition := card_instance.definition as HeroDefinition
	if hero_definition == null:
		return {}

	match hero_definition.hero_kind:
		HeroDefinition.HeroKind.ROSTAM:
			return {
				"hp_center": Vector2(0.7323731, 0.1912160),
				"hp_height": 0.1434475,
				"type_center": Vector2(0.7475098, 0.3845592),
				"type_size": Vector2(0.2179856, 0.1741440)
			}

		HeroDefinition.HeroKind.TAHMINEH:
			return {
				"hp_center": Vector2(0.7845649, 0.1431313),
				"hp_height": 0.1500310,
				"type_center": Vector2(0.7891524, 0.3582052),
				"type_size": Vector2(0.3004651, 0.1990081)
			}

		HeroDefinition.HeroKind.AFRASIAB:
			return {
				"hp_center": Vector2(0.8014690, 0.1572804),
				"hp_height": 0.1607143,
				"type_center": Vector2(0.8250822, 0.3634763),
				"type_size": Vector2(0.3165785, 0.2453704)
			}

	return {}


func _normalized_card_position(
	normalized: Vector2,
	height: float
) -> Vector3:
	var visual_size := CARD_FRONT_SIZE

	if (
		card_instance != null
		and card_instance.is_hero()
		and is_face_up
	):
		visual_size *= HERO_ART_SCALE

	return Vector3(
		(normalized.x - 0.5) * visual_size.x,
		height,
		(normalized.y - 0.5) * visual_size.y
	)


func _apply_hero_overlay_layout() -> void:
	if hero_hp_label == null or hero_type_icon == null:
		return

	var layout: Dictionary = _hero_overlay_layout()
	if layout.is_empty():
		return

	var hp_center: Vector2 = layout.get(
		"hp_center",
		Vector2(0.78, 0.16)
	)
	var hp_height: float = float(
		layout.get("hp_height", 0.15)
	)
	var type_center: Vector2 = layout.get(
		"type_center",
		Vector2(0.79, 0.36)
	)
	var type_size: Vector2 = layout.get(
		"type_size",
		Vector2(0.26, 0.20)
	)

	var face_basis: Basis = card_name.transform.basis

	hero_hp_label.transform = Transform3D(
		face_basis,
		_normalized_card_position(hp_center, 0.092)
	)

	hero_hp_label.pixel_size = (
		(
			hp_height
			* CARD_FRONT_SIZE.y
			* HERO_ART_SCALE
		)
		/ float(hero_hp_label.font_size)
	)

	hero_type_icon.transform = Transform3D(
		face_basis,
		_normalized_card_position(type_center, 0.091)
	)

	var quad := hero_type_icon.mesh as QuadMesh
	if quad != null:
		var visual_size := CARD_FRONT_SIZE * HERO_ART_SCALE
		quad.size = Vector2(
			type_size.x * visual_size.x,
			type_size.y * visual_size.y
		)


func _hero_type_texture(
	gesture: CardGesture.Type
) -> Texture2D:
	match gesture:
		CardGesture.Type.ROCK:
			return HERO_TYPE_ROCK
		CardGesture.Type.PAPER:
			return HERO_TYPE_PAPER
		CardGesture.Type.SCISSORS:
			return HERO_TYPE_SCISSORS

	return null


func _refresh_hero_hp_visual() -> void:
	if hero_hp_label == null:
		_build_hero_hp_label()

	if (
		card_instance == null
		or not card_instance.is_hero()
		or not is_face_up
	):
		hero_hp_label.visible = false
		return

	_apply_hero_overlay_layout()

	hero_hp_label.text = str(
		maxi(0, card_instance.hero_health)
	)
	hero_hp_label.visible = true


func _build_card_status_label() -> void:
	if card_status_label != null:
		return

	card_status_label = Label3D.new()
	card_status_label.name = "CardStatusLabel"
	card_status_label.position = Vector3(0.0, 0.16, 0.05)
	card_status_label.font_size = 15
	card_status_label.outline_size = 6
	card_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	card_status_label.no_depth_test = true
	card_status_label.visible = false
	add_child(card_status_label)


func refresh_card_status(
	turn_number: int,
	animate_change: bool = true
) -> void:
	if card_status_label == null:
		_build_card_status_label()

	if card_instance == null or not is_face_up:
		card_status_label.visible = false
		displayed_card_status = ""
		return

	var status: String = ""

	if card_instance.rooted_by_card_turn == turn_number:
		status = "ROOT"
	elif card_instance.rooted_by_card_turn == turn_number + 1:
		status = "ROOT NEXT"
	elif card_instance.debuffed_no_win_turn == turn_number:
		status = "DEBUFF"
	elif card_instance.debuffed_no_win_turn == turn_number + 1:
		status = "DEBUFF NEXT"

	var changed: bool = status != displayed_card_status
	displayed_card_status = status
	card_status_label.text = status
	card_status_label.visible = not status.is_empty()

	if animate_change and changed and not status.is_empty():
		_play_card_status_pulse()


func _play_card_status_pulse() -> void:
	if card_status_label == null:
		return

	card_status_label.scale = Vector3.ONE * 1.45
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		card_status_label,
		"scale",
		Vector3.ONE,
		0.28
	)


func refresh_hero_status(turn_number: int) -> void:
	if hero_status_label == null:
		_build_hero_status_label()

	_refresh_hero_hp_visual()

	if (
		card_instance == null
		or not card_instance.is_hero()
		or not is_face_up
	):
		hero_status_label.visible = false
		return

	var parts: Array[String] = []

	if card_instance.shield_count > 0:
		parts.append("SHIELD %d" % card_instance.shield_count)

	if card_instance.is_hero_furious(turn_number):
		parts.append("FURY x2")

	if card_instance.is_hero_sleeping(turn_number):
		parts.append("SLEEP")

	if card_instance.is_hero_rooted(turn_number):
		parts.append("ROOT")

	if card_instance.is_hero_type_locked(turn_number):
		parts.append("TYPE LOCK")

	if card_instance.is_hero_afrasiab_active(turn_number):
		parts.append("POISON TRAP")

	hero_status_label.text = " | ".join(parts)
	hero_status_label.visible = not parts.is_empty()

	_refresh_gesture_override_label()


func _create_card_material() -> void:
	if card_material != null:
		return

	card_material = StandardMaterial3D.new()
	card_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	card_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	card_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	card_material.albedo_color = Color.WHITE
	card_art.material_override = card_material

func _refresh_card_art_shape() -> void:
	if card_art == null:
		return

	var is_face_up_hero := (
		is_face_up
		and card_instance != null
		and card_instance.is_hero()
	)

	# The champion PNGs are intentionally cut-out artwork that extends beyond
	# a normal card rectangle. Enlarge only the face-up hero presentation.
	var visual_scale := HERO_ART_SCALE if is_face_up_hero else 1.0
	card_art.scale = Vector3(
		visual_scale,
		visual_scale,
		visual_scale
	)

	# Keep the PNG's transparent background visible.
	# CardBody is the large solid rectangle that was appearing behind the artwork.
	if card_body != null:
		card_body.visible = false

	card_art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func setup(
	new_card_instance: CardInstance,
	new_home_transform: Transform3D,
	new_is_draggable: bool,
	start_face_up: bool = true
) -> void:
	card_instance = new_card_instance
	home_transform = new_home_transform
	is_draggable = new_is_draggable

	global_transform = home_transform

	_create_card_material()
	set_face_up(start_face_up)
	_refresh_card_art_shape()
	_refresh_gesture_override_label()
	refresh_card_status(-999, false)


func set_face_up(value: bool) -> void:
	is_face_up = value

	if not value:
		_cancel_inspect_hold()

	_create_card_material()

	if card_material == null:
		return

	if value:
		if (
			card_instance != null
			and card_instance.definition != null
			and card_instance.definition.front_texture != null
		):
			card_material.albedo_texture = \
				card_instance.definition.front_texture
		else:
			card_material.albedo_texture = null

			push_warning(
				"Card front texture is missing."
			)
	else:
		card_material.albedo_texture = back_texture

	_refresh_card_art_shape()
	_refresh_gesture_override_label()
	_refresh_hero_hp_visual()
	if not value and card_status_label != null:
		card_status_label.visible = false


func refresh_front_visual() -> void:
	if not is_face_up:
		return

	_create_card_material()
	if card_material == null:
		return

	if (
		card_instance != null
		and card_instance.definition != null
		and card_instance.definition.front_texture != null
	):
		card_material.albedo_texture = \
			card_instance.definition.front_texture

	_refresh_card_art_shape()
	_refresh_gesture_override_label()
	_refresh_hero_hp_visual()


func refresh_gesture_override_label() -> void:
	_refresh_gesture_override_label()


func _refresh_gesture_override_label() -> void:
	if card_name == null:
		return

	if hero_type_icon == null:
		_build_hero_type_icon()

	if card_instance == null or not is_face_up:
		card_name.visible = false
		if hero_type_icon != null:
			hero_type_icon.visible = false
		return

	var gesture: CardGesture.Type = card_instance.get_gesture()

	if gesture not in [
		CardGesture.Type.ROCK,
		CardGesture.Type.PAPER,
		CardGesture.Type.SCISSORS
	]:
		card_name.visible = false
		hero_type_icon.visible = false
		return

	if card_instance.is_hero():
		card_name.visible = false
		_apply_hero_overlay_layout()

		var icon: Texture2D = _hero_type_texture(gesture)
		if icon == null or hero_type_material == null:
			hero_type_icon.visible = false
			return

		hero_type_material.albedo_texture = icon
		hero_type_icon.visible = true
		return

	# Keep the old text only for normal Rush-transformed cards.
	hero_type_icon.visible = false

	if not card_instance.has_gesture_override():
		card_name.visible = false
		return

	card_name.text = CardGesture.Type.keys()[gesture]
	card_name.font_size = 11
	card_name.outline_size = 4
	card_name.modulate = Color.WHITE
	card_name.visible = true


func move_home(
	new_home_transform: Transform3D
) -> void:
	home_transform = new_home_transform
	_apply_home_transform()


func return_home() -> void:
	_apply_home_transform()


func set_keep_selected(value: bool) -> void:
	keep_selected = value
	_apply_home_transform()


func _apply_home_transform() -> void:
	global_transform = home_transform

	if (
		card_instance != null
		and card_instance.is_hero()
		and is_face_up
		and card_instance.zone == CardZone.Type.BOARD
	):
		global_position += Vector3.UP * hero_board_lift

	if (
		keep_selected
		and card_instance != null
		and card_instance.zone == CardZone.Type.HAND
	):
		global_position += \
			Vector3.UP * KEEP_RAISE_HEIGHT


func _input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_index: int
) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_inspect_hold(event.position)

			if is_draggable:
				drag_requested.emit(
					self,
					event.position
				)
		else:
			_cancel_inspect_hold()

	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			_begin_inspect_hold(event.position)

			if is_draggable:
				drag_requested.emit(
					self,
					event.position
				)
		else:
			_cancel_inspect_hold()


func _input(event: InputEvent) -> void:
	if not _inspect_press_active:
		return

	if event is InputEventScreenDrag:
		_cancel_inspect_if_moved(event.position)

	elif event is InputEventMouseMotion:
		_cancel_inspect_if_moved(event.position)

	elif event is InputEventScreenTouch:
		if not event.pressed:
			_cancel_inspect_hold()

	elif event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and not event.pressed
		):
			_cancel_inspect_hold()


func _begin_inspect_hold(
	screen_position: Vector2
) -> void:
	# Never reveal information for a face-down card.
	if not is_face_up:
		return

	if card_instance == null:
		return

	if card_instance.definition == null:
		return

	_inspect_press_active = true
	_inspect_press_position = screen_position
	_inspect_press_serial += 1

	var current_serial: int = _inspect_press_serial
	_wait_for_inspect_hold(current_serial)


func _wait_for_inspect_hold(
	serial: int
) -> void:
	await get_tree().create_timer(
		inspect_hold_time
	).timeout

	if not _inspect_press_active:
		return

	if serial != _inspect_press_serial:
		return

	if not is_face_up:
		_cancel_inspect_hold()
		return

	_inspect_press_active = false
	_inspect_press_serial += 1

	inspect_requested.emit(self)


func _cancel_inspect_if_moved(
	screen_position: Vector2
) -> void:
	if (
		screen_position.distance_to(
			_inspect_press_position
		)
		> inspect_move_cancel_distance
	):
		_cancel_inspect_hold()


func _cancel_inspect_hold() -> void:
	if not _inspect_press_active:
		return

	_inspect_press_active = false
	_inspect_press_serial += 1


func set_disabled(
	value: bool,
	_animate_change: bool = true
) -> float:
	is_disabled = value

	# DisabledLabel is intentionally not used in the current presentation.
	# disabled_label.visible = value
	disabled_card.visible = value

	# A disabled card can still be picked so game logic can decide whether
	# the interaction is allowed.
	input_ray_pickable = true

	# One-shot disabled-hit VFX is now handled by CardVFXManager3D.
	return 0.0


func set_shield_count(
	new_count: int,
	animate_change: bool = true
) -> void:
	new_count = maxi(new_count, 0)

	var previous_count: int = displayed_shield_count
	displayed_shield_count = new_count

	shield_badge.visible = new_count > 0

	if new_count <= 0:
		return

	shield_count_label.text = str(new_count)

	if animate_change and new_count != previous_count:
		_play_shield_badge_pulse()


func _play_shield_badge_pulse() -> void:
	shield_badge.scale = (
		shield_badge_base_scale
		* 1.35
	)

	var tween: Tween = create_tween()

	tween.set_trans(
		Tween.TRANS_BACK
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		shield_badge,
		"scale",
		shield_badge_base_scale,
		0.25
	)


# Rush unused-mana penalty presentation. The card rises out of the current
# hand and fades before MatchController rebuilds the next-turn hand.
func play_rush_penalty_remove(
	raise_height: float = 0.55,
	duration: float = 0.55
) -> float:
	is_draggable = false
	input_ray_pickable = false
	_cancel_inspect_hold()

	_create_card_material()

	if card_material == null:
		return 0.0

	# Hand cards do not need status overlays while they disappear.
	disabled_card.visible = false
	shield_badge.visible = false

	var start_color: Color = card_material.albedo_color
	start_color.a = 1.0
	card_material.albedo_color = start_color

	var end_color: Color = start_color
	end_color.a = 0.0

	var target_position: Vector3 = (
		global_position
		+ Vector3.UP * raise_height
	)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"global_position",
		target_position,
		duration
	)
	tween.tween_property(
		card_material,
		"albedo_color",
		end_color,
		duration
	)
	tween.tween_property(
		self,
		"scale",
		scale * 0.86,
		duration
	)

	return duration
