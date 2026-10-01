class_name MenuSkin
extends RefCounted

const ASSETS := "res://ui/menu/assets/"
const DESIGN := Vector2(2400, 1080)
const FONT = preload("res://ui/menu/fonts/Lalezar-Regular.ttf")

static func tex(path: String) -> Texture2D:
 return load(ASSETS + path) as Texture2D

static func place(node: Control, parent: Node, rect: Rect2) -> void:
 parent.add_child(node)
 node.position = rect.position
 node.size = rect.size

static func image(parent: Node, path: String, rect: Rect2) -> TextureRect:
 var n := TextureRect.new()
 n.texture = tex(path)
 n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 n.stretch_mode = TextureRect.STRETCH_SCALE
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 place(n, parent, rect)
 return n

static func texture(parent: Node, value: Texture2D, rect: Rect2) -> TextureRect:
 var n := TextureRect.new()
 n.texture = value
 n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 n.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 place(n, parent, rect)
 return n

static func label(parent: Node, text: String, rect: Rect2, font_size: int = 36, color: Color = Color.WHITE) -> Label:
 var n := Label.new()
 n.text = text
 n.add_theme_font_override("font", FONT)
 n.add_theme_font_size_override("font_size", font_size)
 n.add_theme_color_override("font_color", color)
 n.add_theme_color_override("font_outline_color", Color(0.07,0.06,0.09))
 n.add_theme_constant_override("outline_size", 5)
 n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 place(n, parent, rect)
 return n

static func button(parent: Node, normal: String, hover: String, pressed: String, rect: Rect2, action: Callable) -> TextureButton:
 var n := TextureButton.new()
 n.texture_normal = tex(normal)
 n.texture_hover = tex(hover if not hover.is_empty() else normal)
 n.texture_pressed = tex(pressed if not pressed.is_empty() else normal)
 n.ignore_texture_size = true
 n.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
 n.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 n.focus_mode = Control.FOCUS_ALL
 place(n, parent, rect)
 if action.is_valid(): n.pressed.connect(action)
 return n

static func style(color: Color, border: Color = Color(0.52,0.43,0.25), radius: int = 18) -> StyleBoxFlat:
 var s := StyleBoxFlat.new()
 s.bg_color = color
 s.border_color = border
 s.set_border_width_all(2)
 s.set_corner_radius_all(radius)
 return s

static func text_button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
 var n := Button.new()
 n.text = text
 n.add_theme_font_override("font", FONT)
 n.add_theme_font_size_override("font_size", 32)
 n.add_theme_stylebox_override("normal", style(Color("262331")))
 n.add_theme_stylebox_override("hover", style(Color("176776"), Color("52d7d8")))
 n.add_theme_stylebox_override("pressed", style(Color("123e49")))
 n.add_theme_stylebox_override("focus", style(Color(0,0,0,0), Color("52d7d8")))
 n.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 place(n,parent,rect)
 if action.is_valid(): n.pressed.connect(action)
 return n

static func clear(parent: Node) -> void:
 for child in parent.get_children():
  parent.remove_child(child)
  child.queue_free()

static func fit(root: Control) -> void:
 var area := root.get_viewport_rect().size
 var factor := minf(area.x / DESIGN.x, area.y / DESIGN.y)
 root.scale = Vector2.ONE * factor
 root.position = (area - DESIGN * factor) / 2.0
 root.size = DESIGN

static func digits(value: Variant) -> String:
 var result := str(value)
 for i in range(10): result = result.replace(str(i), "۰۱۲۳۴۵۶۷۸۹"[i])
 return result
