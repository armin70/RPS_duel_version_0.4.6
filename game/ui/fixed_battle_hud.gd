extends CanvasLayer

# Fixed battle controls that sit on the screen, independent from the 3D board.
# This does NOT replace the enemy energy/special HUD. It only hides the legacy
# local-player mana/end-turn/special controls and draws the new fixed controls.

const BATTLE_TEXTURE: Texture2D = preload(
	"res://art/ui/fixed_battle_hud/battle.png"
)
const MANA_TEXTURE: Texture2D = preload(
	"res://art/ui/fixed_battle_hud/mana.png"
)
const ULTIMATE_EMPTY_TEXTURE: Texture2D = preload(
	"res://art/ui/fixed_battle_hud/ultimate_empty.png"
)
const ULTIMATE_READY_TEXTURE: Texture2D = preload(
	"res://art/ui/fixed_battle_hud/ultimate_ready.png"
)
const CARD_ALPHA_SHADER: Shader = preload(
	"res://game/ui/fixed_card_alpha.gdshader"
)
const SPECIAL_RING_SCRIPT: Script = preload(
	"res://game/ui/special_charge_ring.gd"
)
const SPECIAL_READY_FX_SHADER: Shader = preload(
	"res://game/ui/special_ready_fx.gdshader"
)

# Four 15-point bars = 60 total special energy.
const SPECIAL_MAX_ENERGY: float = 60.0

# Final fixed positions matched to the gameplay board circles.
# Special attack stays in the LEFT stone ring; Battle stays in the RIGHT circle.
# Change ONLY these ratios if you want to fine-tune placement later.
# Final placement requested:
# - Special attack: bottom-left stone ring.
# - Battle: the old Special position on the right side.
# - Mana: one horizontal row slightly above the bottom-left Special button.
const SPECIAL_CENTER_RATIO := Vector2(0.12, 0.838)
const BATTLE_CENTER_RATIO := Vector2(0.785, 0.49)

const BUTTON_HEIGHT_RATIO: float = 0.135

# Size of ONLY the fully-charged artwork. The clickable button keeps its normal size.
# 1.00 = same size as the button, 1.15 = 15% larger, 0.90 = 10% smaller.
const SPECIAL_READY_IMAGE_SCALE: float = 1.15

const MANA_HEIGHT_RATIO: float = 0.058
const MAX_MANA_ICONS: int = 8

# Mana droplets occupy only a fixed arc around the Battle button.
# They start at the top and are added clockwise with CONSTANT spacing.
# The arc never redistributes itself based on the current mana count.
# Screen coordinates: -90 = top, 0 = right, 90 = bottom.
const MANA_ARC_START_DEG: float = -90.0
const MANA_ARC_STEP_DEG: float = 25.0
const MANA_ARC_RADIUS_MULTIPLIER: float = 0.84

# Local player's hand presentation. This modifies only the PlayerHand origin;
# board cards, Hero size/HP/type and opponent hand are untouched.
const HAND_SCALE_MULTIPLIER: float = 2
const HAND_SCREEN_DOWN_WORLD: float = -1.5

var _controller: Node
var _hud: Node
var _legacy_end_turn_button: TextureButton
var _legacy_mana_panel: CanvasItem

var _battle_button: TextureButton
var _special_ring: Control
var _special_button: TextureButton
var _special_ready_fx: TextureRect
var _special_ready_fx_material: ShaderMaterial
var _mana_root: Control
var _mana_icons: Array[TextureRect] = []

var _last_viewport_size := Vector2.ZERO
var _last_mana: int = -999
var _last_special_ready: bool = false
var _special_ready_initialized: bool = false
var _legacy_special_cleanup_timer: float = 0.0

# The current game build can expose Special charge through cumulative score.
# Keep a per-use baseline so the visible ring returns to zero after firing,
# then fills only from points earned after that Special.
var _special_score_cycle_base: float = 0.0
var _special_force_empty: bool = false
var _special_energy_before_use: float = 0.0

# Hand presentation state.
var _hand_layout_applied: bool = false
var _hand_origin: Node3D

# Runtime alpha materials keyed by CardInstance id. This restores the clean
# transparent-card presentation without replacing card_3d.gd or touching Hero
# size/HP/type layout.
var _card_alpha_materials: Dictionary = {}


func _ready() -> void:
	layer = 90
	_build_controls()
	set_process(true)


func _build_controls() -> void:
	_battle_button = TextureButton.new()
	_battle_button.name = "FixedBattleButton"
	_battle_button.ignore_texture_size = true
	_battle_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_battle_button.texture_normal = BATTLE_TEXTURE
	_battle_button.texture_hover = BATTLE_TEXTURE
	_battle_button.texture_pressed = BATTLE_TEXTURE
	_battle_button.texture_disabled = BATTLE_TEXTURE
	_battle_button.focus_mode = Control.FOCUS_NONE
	_battle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_battle_button.pressed.connect(_on_battle_pressed)
	add_child(_battle_button)

	# Draw the charge ring BEFORE the button so the icon always stays on top.
	_special_ring = SPECIAL_RING_SCRIPT.new() as Control
	_special_ring.name = "FixedSpecialChargeRing"
	_special_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_ring.z_index = 1
	add_child(_special_ring)

	_special_button = TextureButton.new()
	_special_button.name = "FixedSpecialAttackButton"
	_special_button.ignore_texture_size = true
	_special_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	# The skull itself ALWAYS uses the compact/empty art so it stays fitted
	# inside the stone circle. Ready-state lightning is a separate layer.
	_special_button.texture_normal = ULTIMATE_EMPTY_TEXTURE
	_special_button.texture_hover = ULTIMATE_EMPTY_TEXTURE
	_special_button.texture_pressed = ULTIMATE_EMPTY_TEXTURE
	_special_button.texture_disabled = ULTIMATE_EMPTY_TEXTURE
	_special_button.focus_mode = Control.FOCUS_NONE
	_special_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_special_button.z_index = 2
	_special_button.pressed.connect(_on_special_pressed)
	add_child(_special_button)

	# Fully-charged artwork is a separate visual layer. This lets us resize ONLY
	# the ready image without changing the button hitbox/click area.
	_special_ready_fx = TextureRect.new()
	_special_ready_fx.name = "FixedSpecialReadyImage"
	_special_ready_fx.texture = ULTIMATE_READY_TEXTURE
	_special_ready_fx.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_special_ready_fx.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_special_ready_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_ready_fx.z_index = 3
	_special_ready_fx.visible = false
	_special_ready_fx.material = null
	add_child(_special_ready_fx)

	_mana_root = Control.new()
	_mana_root.name = "FixedManaIcons"
	_mana_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mana_root)

	for index: int in range(MAX_MANA_ICONS):
		var icon := TextureRect.new()
		icon.name = "Mana%d" % (index + 1)
		icon.texture = MANA_TEXTURE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		_mana_root.add_child(icon)
		_mana_icons.append(icon)

	visible = false


func _process(delta: float) -> void:
	_resolve_match_nodes()

	if not is_instance_valid(_controller):
		visible = false
		return

	var state: Variant = _controller.get("state")
	if state == null:
		visible = false
		return

	_resolve_legacy_hud_nodes()

	var hud_visible: bool = true
	if is_instance_valid(_hud):
		var hud_visible_variant: Variant = _hud.get("visible")
		if hud_visible_variant is bool:
			hud_visible = bool(hud_visible_variant)

	visible = hud_visible
	if not visible:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_layout_controls(viewport_size)

	_apply_hand_layout_once()
	_hide_legacy_local_controls()
	_refresh_battle_state()
	_refresh_mana(state)
	_refresh_special_state()
	_refresh_card_alpha_fix()

	# HeroEnergyControl is created dynamically. Repeat this small lookup at a
	# low frequency so the local legacy panel stays hidden while the enemy panel
	# remains untouched.
	_legacy_special_cleanup_timer -= delta
	if _legacy_special_cleanup_timer <= 0.0:
		_legacy_special_cleanup_timer = 0.35
		_hide_legacy_local_special_panel()


func _resolve_match_nodes() -> void:
	if is_instance_valid(_controller):
		return

	_controller = get_tree().get_first_node_in_group(&"match_controller")
	_hud = null
	_legacy_end_turn_button = null
	_legacy_mana_panel = null
	_last_mana = -999
	_special_ready_initialized = false
	_last_special_ready = false
	_special_score_cycle_base = 0.0
	_special_force_empty = false
	_special_energy_before_use = 0.0
	_hand_layout_applied = false
	_hand_origin = null


func _resolve_legacy_hud_nodes() -> void:
	if not is_instance_valid(_controller):
		return

	if not is_instance_valid(_hud):
		var hud_variant: Variant = _controller.get("hud")
		if hud_variant is Node:
			_hud = hud_variant as Node

	if not is_instance_valid(_hud):
		return

	if not is_instance_valid(_legacy_end_turn_button):
		var end_turn_variant: Variant = _hud.get("end_turn_button")
		if end_turn_variant is TextureButton:
			_legacy_end_turn_button = end_turn_variant as TextureButton
		else:
			var found_end_turn := _find_node_by_name(
				_hud,
				["EndTurnButton", "FightButton", "BattleButton"]
			)
			if found_end_turn is TextureButton:
				_legacy_end_turn_button = found_end_turn as TextureButton

	if not is_instance_valid(_legacy_mana_panel):
		var mana_panel_variant: Variant = _hud.get("player_mana_panel")
		if mana_panel_variant is CanvasItem:
			_legacy_mana_panel = mana_panel_variant as CanvasItem
		else:
			var mana_label_variant: Variant = _hud.get("player_mana_label")
			if mana_label_variant is CanvasItem:
				var mana_item := mana_label_variant as CanvasItem
				if mana_item.get_parent() is CanvasItem:
					_legacy_mana_panel = mana_item.get_parent() as CanvasItem


func _hide_legacy_local_controls() -> void:
	if is_instance_valid(_legacy_end_turn_button):
		_legacy_end_turn_button.visible = false

	if is_instance_valid(_legacy_mana_panel):
		_legacy_mana_panel.visible = false


func _layout_controls(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var button_size: float = clampf(
		viewport_size.y * BUTTON_HEIGHT_RATIO,
		125.0,
		205.0
	)
	var button_vector := Vector2(button_size, button_size)

	_special_button.size = button_vector
	_special_button.position = (
		viewport_size * SPECIAL_CENTER_RATIO
		- button_vector * 0.5
	)

	# Resize only the fully-charged artwork. The real TextureButton remains
	# button_size x button_size, so its click area never changes.
	if is_instance_valid(_special_ready_fx):
		var ready_size: float = button_size * SPECIAL_READY_IMAGE_SCALE
		var ready_vector := Vector2(ready_size, ready_size)
		_special_ready_fx.size = ready_vector
		_special_ready_fx.position = (
			viewport_size * SPECIAL_CENTER_RATIO
			- ready_vector * 0.5
		)

	# The ring sits just outside the Special icon and shares the exact center.
	if is_instance_valid(_special_ring):
		var ring_size: float = button_size * 1.12
		var ring_vector := Vector2(ring_size, ring_size)
		_special_ring.size = ring_vector
		_special_ring.position = (
			viewport_size * SPECIAL_CENTER_RATIO
			- ring_vector * 0.5
		)

	_battle_button.size = button_vector
	_battle_button.position = (
		viewport_size * BATTLE_CENTER_RATIO
		- button_vector * 0.5
	)

	_mana_root.position = Vector2.ZERO
	_mana_root.size = viewport_size
	_layout_mana_arc(viewport_size, button_size)


func _refresh_battle_state() -> void:
	if not is_instance_valid(_battle_button):
		return

	var disabled: bool = false

	# Mirror the real hidden end-turn button whenever possible. That keeps all
	# existing turn/tutorial/online interaction rules intact.
	if is_instance_valid(_legacy_end_turn_button):
		disabled = _legacy_end_turn_button.disabled
	elif is_instance_valid(_controller):
		var locked_variant: Variant = _controller.get("interaction_locked")
		if locked_variant is bool:
			disabled = bool(locked_variant)

	_battle_button.disabled = disabled
	_battle_button.modulate.a = 0.58 if disabled else 1.0


func _refresh_mana(state: Variant) -> void:
	if not is_instance_valid(_controller):
		return

	var local_id_variant: Variant = _controller.get("local_player_id")
	if not (local_id_variant is int):
		return
	var local_player_id: int = int(local_id_variant)

	if not state.has_method("get_player"):
		return
	var player: Variant = state.call("get_player", local_player_id)
	if player == null:
		return

	var mana_variant: Variant = player.get("current_mana")
	if not (mana_variant is int or mana_variant is float):
		return
	var mana: int = clampi(int(mana_variant), 0, MAX_MANA_ICONS)

	if mana == _last_mana:
		return
	_last_mana = mana

	for index: int in range(_mana_icons.size()):
		_mana_icons[index].visible = index < mana

	if _last_viewport_size != Vector2.ZERO:
		var button_size: float = clampf(
			_last_viewport_size.y * BUTTON_HEIGHT_RATIO,
			125.0,
			205.0
		)
		_layout_mana_arc(_last_viewport_size, button_size)


func _layout_mana_arc(
	viewport_size: Vector2,
	button_size: float
) -> void:
	if not is_instance_valid(_mana_root):
		return
	if not is_instance_valid(_battle_button):
		return

	var visible_count: int = clampi(_last_mana, 0, MAX_MANA_ICONS)
	if visible_count <= 0:
		return

	var mana_height: float = clampf(
		viewport_size.y * MANA_HEIGHT_RATIO,
		46.0,
		74.0
	)
	var mana_width: float = mana_height * (56.0 / 78.0)
	var radius: float = button_size * MANA_ARC_RADIUS_MULTIPLIER
	var battle_center: Vector2 = viewport_size * BATTLE_CENTER_RATIO

	for index: int in range(_mana_icons.size()):
		var icon := _mana_icons[index]
		icon.size = Vector2(mana_width, mana_height)

		if index >= visible_count:
			icon.visible = false
			continue

		# Fixed spacing: mana 1 stays at the top. Each new mana simply
		# occupies the next slot clockwise. Existing icons never spread out.
		var angle_deg: float = (
			MANA_ARC_START_DEG
			+ float(index) * MANA_ARC_STEP_DEG
		)
		var angle: float = deg_to_rad(angle_deg)
		var center := battle_center + Vector2(
			cos(angle) * radius,
			sin(angle) * radius
		)

		icon.visible = true
		icon.position = center - icon.size * 0.5


func _apply_hand_layout_once() -> void:
	if _hand_layout_applied:
		return
	if not is_instance_valid(_controller):
		return

	var layout_variant: Variant = _controller.get("game_layout")
	if not (layout_variant is Node):
		return
	var layout := layout_variant as Node

	var hand_variant: Variant = layout.get("player_hand_origin")
	if not (hand_variant is Node3D):
		return
	_hand_origin = hand_variant as Node3D

	# Slightly enlarge the whole local hand while keeping controller placement,
	# dragging and return_home logic intact.
	_hand_origin.scale *= HAND_SCALE_MULTIPLIER

	# Move the hand down in screen direction using the actual gameplay camera.
	# This is more reliable than guessing a board X/Z axis.
	var camera_variant: Variant = _controller.get("camera_3d")
	if camera_variant is Camera3D:
		var camera := camera_variant as Camera3D
		var screen_up_world := camera.global_transform.basis.y.normalized()
		_hand_origin.global_position -= screen_up_world * HAND_SCREEN_DOWN_WORLD
	else:
		# Fallback for unusual test scenes.
		_hand_origin.position.z += HAND_SCREEN_DOWN_WORLD

	_hand_layout_applied = true

	# Existing cards may have cached old home transforms. Ask the controller to
	# regenerate them once from the updated PlayerHand origin.
	if _controller.has_method("_refresh_hand_positions"):
		_controller.call_deferred("_refresh_hand_positions")



func _refresh_special_state() -> void:
	if not is_instance_valid(_controller):
		return

	var engine: Variant = _controller.get("engine")
	var local_id_variant: Variant = _controller.get("local_player_id")
	if engine == null or not (local_id_variant is int):
		_special_button.visible = false
		if is_instance_valid(_special_ring):
			_special_ring.visible = false
		if is_instance_valid(_special_ready_fx):
			_special_ready_fx.visible = false
		return

	# Rush does not use the normal Hero special system.
	var rush_variant: Variant = _controller.get("rush_mode_enabled")
	if rush_variant is bool and bool(rush_variant):
		_special_button.visible = false
		if is_instance_valid(_special_ring):
			_special_ring.visible = false
		if is_instance_valid(_special_ready_fx):
			_special_ready_fx.visible = false
		return

	_special_button.visible = true
	if is_instance_valid(_special_ring):
		_special_ring.visible = true

	# The button itself always keeps the normal/empty artwork. The charged
	# artwork is drawn in a separate TextureRect so its visual size is independent
	# from the button hitbox.

	var local_player_id: int = int(local_id_variant)
	var ready: bool = false
	if engine.has_method("can_use_special_attack"):
		ready = bool(engine.call("can_use_special_attack", local_player_id))

	var snapshot: Dictionary = _get_local_special_energy_snapshot(local_player_id)
	var energy_value: float = float(snapshot.get("value", 0.0))
	var maximum: float = float(snapshot.get("maximum", SPECIAL_MAX_ENERGY))
	var uses_score: bool = bool(snapshot.get("uses_score", false))

	if maximum <= 0.0:
		maximum = SPECIAL_MAX_ENERGY

	var energy_ratio: float = 0.0
	if uses_score:
		# Score is cumulative in this mode, so one Special spends the visible
		# 0..60 cycle without changing the player's lifetime score.
		energy_ratio = clampf(
			(energy_value - _special_score_cycle_base) / maximum,
			0.0,
			1.0
		)
	else:
		# Dedicated energy properties are expected to reset themselves. While an
		# online/offline request is being applied, keep the ring empty until the
		# underlying value actually drops (or the engine reports not-ready).
		if _special_force_empty:
			if energy_value < _special_energy_before_use - 0.001 or not ready:
				_special_force_empty = false
			else:
				energy_ratio = 0.0
		if not _special_force_empty:
			energy_ratio = clampf(energy_value / maximum, 0.0, 1.0)

	# Readiness from MatchEngine stays authoritative, but the button is only
	# presented as READY after the visible charge cycle itself is full.
	var display_ready: bool = (
		ready
		and energy_ratio >= 0.999
		and not _special_force_empty
	)

	if is_instance_valid(_special_ring) and _special_ring.has_method("set_progress_ratio"):
		_special_ring.call("set_progress_ratio", energy_ratio)

	if not _special_ready_initialized or display_ready != _last_special_ready:
		_special_ready_initialized = true
		_last_special_ready = display_ready

	# Keep the clickable button at its normal size and artwork. Only the separate
	# ready layer changes visibility/size.
	_special_button.texture_normal = ULTIMATE_EMPTY_TEXTURE
	_special_button.texture_hover = ULTIMATE_EMPTY_TEXTURE
	_special_button.texture_pressed = ULTIMATE_EMPTY_TEXTURE
	_special_button.texture_disabled = ULTIMATE_EMPTY_TEXTURE
	if is_instance_valid(_special_ready_fx):
		_special_ready_fx.visible = display_ready

	var locked: bool = false
	var locked_variant: Variant = _controller.get("interaction_locked")
	if locked_variant is bool:
		locked = bool(locked_variant)

	_special_button.disabled = locked or not display_ready
	_special_button.modulate.a = 0.72 if locked else 1.0


func _get_local_special_energy_snapshot(local_player_id: int) -> Dictionary:
	if not is_instance_valid(_controller):
		return {
			"value": 0.0,
			"maximum": SPECIAL_MAX_ENERGY,
			"uses_score": false
		}

	var state: Variant = _controller.get("state")
	if state == null or not state.has_method("get_player"):
		return {
			"value": 0.0,
			"maximum": SPECIAL_MAX_ENERGY,
			"uses_score": false
		}

	var player: Variant = state.call("get_player", local_player_id)
	if player == null:
		return {
			"value": 0.0,
			"maximum": SPECIAL_MAX_ENERGY,
			"uses_score": false
		}

	var maximum: float = _read_numeric_property(
		player,
		["hero_energy_max", "max_energy", "special_energy_max", "energy_max"],
		SPECIAL_MAX_ENERGY
	)
	if maximum <= 0.0:
		maximum = SPECIAL_MAX_ENERGY

	# Prefer a real energy field if this PlayerState has one.
	var dedicated_names: Array[String] = [
		"hero_energy",
		"current_energy",
		"special_energy",
		"energy"
	]
	var available: Dictionary = {}
	for property_info: Dictionary in player.get_property_list():
		available[String(property_info.get("name", ""))] = true

	for candidate: String in dedicated_names:
		if not available.has(candidate):
			continue
		var value: Variant = player.get(candidate)
		if value is int or value is float:
			return {
				"value": float(value),
				"maximum": maximum,
				"uses_score": false
			}

	# Current build fallback: Special charge is derived from cumulative score.
	var score_value: float = _read_numeric_property(player, ["score"], 0.0)
	return {
		"value": score_value,
		"maximum": maximum,
		"uses_score": true
	}


func _get_local_special_energy_ratio(local_player_id: int) -> float:
	var snapshot: Dictionary = _get_local_special_energy_snapshot(local_player_id)
	var value: float = float(snapshot.get("value", 0.0))
	var maximum: float = float(snapshot.get("maximum", SPECIAL_MAX_ENERGY))
	if maximum <= 0.0:
		maximum = SPECIAL_MAX_ENERGY
	if bool(snapshot.get("uses_score", false)):
		value -= _special_score_cycle_base
	return clampf(value / maximum, 0.0, 1.0)


func _read_numeric_property(
	object: Object,
	candidate_names: Array[String],
	fallback: float
) -> float:
	if object == null:
		return fallback

	var available: Dictionary = {}
	for property_info: Dictionary in object.get_property_list():
		available[String(property_info.get("name", ""))] = true

	for candidate: String in candidate_names:
		if not available.has(candidate):
			continue
		var value: Variant = object.get(candidate)
		if value is int or value is float:
			return float(value)

	return fallback


func _on_battle_pressed() -> void:
	if not is_instance_valid(_controller):
		return
	if _battle_button.disabled:
		return

	# Call the same controller entry point used by the original Fight button.
	if _controller.has_method("_on_end_turn_pressed"):
		_controller.call("_on_end_turn_pressed")


func _on_special_pressed() -> void:
	if not is_instance_valid(_controller):
		return
	if _special_button.disabled:
		return

	var local_id_variant: Variant = _controller.get("local_player_id")
	if local_id_variant is int:
		var snapshot: Dictionary = _get_local_special_energy_snapshot(int(local_id_variant))
		var current_value: float = float(snapshot.get("value", 0.0))
		if bool(snapshot.get("uses_score", false)):
			# Cumulative score does not necessarily decrease when Special is used.
			# Start a fresh visible 0..60 cycle from the exact score at this press.
			_special_score_cycle_base = current_value
			_special_force_empty = false
		else:
			_special_energy_before_use = current_value
			_special_force_empty = true

	# Empty the meter and return to the normal skull immediately on press.
	if is_instance_valid(_special_ring) and _special_ring.has_method("set_progress_ratio"):
		_special_ring.call("set_progress_ratio", 0.0)
	_special_button.texture_normal = ULTIMATE_EMPTY_TEXTURE
	_special_button.texture_hover = ULTIMATE_EMPTY_TEXTURE
	_special_button.texture_pressed = ULTIMATE_EMPTY_TEXTURE
	_special_button.texture_disabled = ULTIMATE_EMPTY_TEXTURE
	_special_button.disabled = true
	_last_special_ready = false
	_special_ready_initialized = true
	if is_instance_valid(_special_ready_fx):
		_special_ready_fx.visible = false

	# Keep all damage, online validation and authoritative game-state changes in
	# the existing MatchController path.
	if _controller.has_method("_on_special_attack_requested"):
		_controller.call("_on_special_attack_requested")


func _hide_legacy_local_special_panel() -> void:
	if not is_instance_valid(_controller):
		return

	var energy_control_variant: Variant = _controller.get("hero_energy_control")
	if not (energy_control_variant is Node):
		return
	var energy_control := energy_control_variant as Node
	if not is_instance_valid(energy_control):
		return

	var viewport_size := get_viewport().get_visible_rect().size
	_hide_lower_right_special_branch(energy_control, viewport_size)


func _hide_lower_right_special_branch(
	node: Node,
	viewport_size: Vector2
) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var control := child as Control
			var rect := control.get_global_rect()
			var center := rect.position + rect.size * 0.5

			var is_local_bottom_right := (
				center.x > viewport_size.x * 0.52
				and center.y > viewport_size.y * 0.54
			)
			var sensible_panel_size := (
				rect.size.x > 120.0
				and rect.size.y > 28.0
				and rect.size.x < viewport_size.x * 0.80
				and rect.size.y < viewport_size.y * 0.55
			)

			if (
				is_local_bottom_right
				and sensible_panel_size
				and _contains_special_hud_text(control)
			):
				control.visible = false
				continue

		_hide_lower_right_special_branch(child, viewport_size)


func _contains_special_hud_text(node: Node) -> bool:
	if node is Label:
		var label_text := String((node as Label).text).to_upper()
		if (
			"SPECIAL ATTACK" in label_text
			or "HERO HP" in label_text
			or "ENERGY" in label_text
		):
			return true
	elif node is Button:
		var button_text := String((node as Button).text).to_upper()
		if "SPECIAL ATTACK" in button_text:
			return true

	for child: Node in node.get_children():
		if _contains_special_hud_text(child):
			return true
	return false


func _refresh_card_alpha_fix() -> void:
	if not is_instance_valid(_controller):
		return

	var views_variant: Variant = _controller.get("card_views")
	if not (views_variant is Dictionary):
		return

	var views: Dictionary = views_variant as Dictionary
	var alive_ids: Dictionary = {}

	for raw_id: Variant in views.keys():
		var card_variant: Variant = views.get(raw_id, null)
		if not (card_variant is Node):
			continue

		var card_view := card_variant as Node
		if not is_instance_valid(card_view):
			continue

		alive_ids[raw_id] = true

		var art := card_view.get_node_or_null("CardArt") as MeshInstance3D
		if art == null:
			continue

		# The old clean-alpha presentation intentionally had no opaque card box
		# behind CardArt. Keep it that way for every card.
		var body := card_view.get_node_or_null("CardBody") as MeshInstance3D
		if body != null:
			body.visible = false

		art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# If Card3D already uses its own ShaderMaterial, leave it alone. This
		# makes the patch compatible with the earlier card_alpha.gdshader build.
		var source_variant: Variant = card_view.get("card_material")
		if source_variant is ShaderMaterial:
			continue

		var source_material := source_variant as StandardMaterial3D
		if source_material == null:
			continue

		var fixed_material: ShaderMaterial = _card_alpha_materials.get(
			raw_id,
			null
		) as ShaderMaterial

		if fixed_material == null:
			fixed_material = ShaderMaterial.new()
			fixed_material.shader = CARD_ALPHA_SHADER
			_card_alpha_materials[raw_id] = fixed_material

		fixed_material.set_shader_parameter(
			"texture_albedo",
			source_material.albedo_texture
		)
		fixed_material.set_shader_parameter(
			"fade_alpha",
			source_material.albedo_color.a
		)

		if art.material_override != fixed_material:
			art.material_override = fixed_material

	# Drop materials for cards that were removed from the match.
	for raw_id: Variant in _card_alpha_materials.keys():
		if not alive_ids.has(raw_id):
			_card_alpha_materials.erase(raw_id)


func _find_node_by_name(
	root: Node,
	candidate_names: Array[String]
) -> Node:
	for candidate: String in candidate_names:
		var found := root.find_child(candidate, true, false)
		if found != null:
			return found
	return null
