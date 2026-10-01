class_name DeckSelectionScreen
extends CanvasLayer

signal deck_selected(deck: DeckDefinition)
signal close_requested

const MenuArt = preload("res://ui/menu/menu_skin.gd")
const Library = preload("res://ui/menu/deck_library.gd")
var settings: DeckBuilderSettings
var preset_decks: Array[DeckDefinition] = []
var preset_previews: Array[CardDefinition] = []
var management_mode := false
var read_only := false
var library: MenuDeckLibrary
var root_control: Control
var selected_counts: Dictionary = {}
var active_index := -1
var editing := false
var page := "gallery"
var search_text := ""
var reverse_sort := false
var sort_by_cost := false
var deck_sort_desc := false
var name_edit: LineEdit
var status_label: Label
var total_label: Label
var save_button: TextureButton
var deck_list: VBoxContainer
var grid_hosts: Array[GridContainer] = []
var count_labels: Dictionary = {}
var plus_buttons: Dictionary = {}
var minus_buttons: Dictionary = {}
var category_labels: Array[Label] = []

# Drag-to-deck support. Existing +/- button behavior remains unchanged.
const DECK_DRAG_THRESHOLD := 18.0
const DECK_DRAG_HORIZONTAL_BIAS := 1.10

var deck_drop_area: Control
var deck_drag_card: CardDefinition
var deck_drag_source: TextureButton
var deck_drag_pointer_index := -1
var deck_drag_start := Vector2.ZERO
var deck_drag_active := false
var deck_drag_cancelled := false
var deck_drag_is_touch := false
var deck_drag_preview: Control

func configure(value: DeckBuilderSettings, decks: Array[DeckDefinition], previews: Array[CardDefinition]) -> void:
 settings = value
 preset_decks.assign(decks)
 preset_previews.assign(previews)

func _ready() -> void:
 layer = 90
 process_mode = Node.PROCESS_MODE_ALWAYS
 if settings == null:
  push_error("Deck builder settings missing")
  queue_free()
  return
 library = Library.new(settings)
 root_control = Control.new()
 root_control.name = "DeckSelectionRoot"
 root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(root_control)
 get_viewport().size_changed.connect(_resize)
 _resize()
 if read_only: open_editor(-1)
 else: show_gallery()

func _resize() -> void:
 MenuArt.fit(root_control)

func _input(event: InputEvent) -> void:
 if read_only or deck_drag_card == null:
  return

 if event is InputEventMouseMotion and not deck_drag_is_touch:
  var motion := event as InputEventMouseMotion
  if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
   _update_deck_drag(motion.position)
  return

 if event is InputEventMouseButton and not deck_drag_is_touch:
  var mouse := event as InputEventMouseButton
  if mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
   _finish_deck_drag(mouse.position)
  return

 if event is InputEventScreenDrag and deck_drag_is_touch:
  var drag := event as InputEventScreenDrag
  if drag.index == deck_drag_pointer_index:
   _update_deck_drag(drag.position)
  return

 if event is InputEventScreenTouch and deck_drag_is_touch:
  var touch := event as InputEventScreenTouch
  if touch.index == deck_drag_pointer_index and not touch.pressed:
   _finish_deck_drag(touch.position)

func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  if editing and not read_only: _cancel_editor()
  else: _close()

func _close() -> void:
 close_requested.emit()
 queue_free()

func show_gallery() -> void:
 _cancel_deck_drag()
 editing = false
 page = "gallery"
 MenuArt.clear(root_control)
 library.load_saved()
 if not management_mode:
  MenuArt.image(root_control,"main pages/Base-Minimized.png",Rect2(0,0,2400,1080))
  MenuArt.label(root_control,"دستهٔ نبردت را انتخاب کن",Rect2(450,120,1400,95),58)
  MenuArt.text_button(root_control,"بازگشت به خانه",Rect2(45,28,290,75),func():
   get_tree().paused = false
   get_tree().change_scene_to_file("res://game/main_game.tscn"))
 var scroll := ScrollContainer.new()
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
 scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.scroll_deadzone = 8
 MenuArt.place(scroll,root_control,Rect2(275,330,1510,625))
 var row := HBoxContainer.new()
 row.add_theme_constant_override("separation",35)
 scroll.add_child(row)
 # The order matches the prototype: Abjeez, Sang, Normal, Add.
 for idx in [2,1,0]:
  if idx >= preset_decks.size() or preset_decks[idx] == null: continue
  var cover: String = ["normal", "Sang", "Abjeez"][idx]
  var pressed: String = "Sand pressed" if idx == 1 else cover + " pressed"
  var tile := Control.new()
  tile.custom_minimum_size = Vector2(279,565)
  row.add_child(tile)
  var b := MenuArt.button(tile,"Decks/"+cover+".png","Decks/"+cover+" highlighted.png","Decks/"+pressed+".png",Rect2(0,0,279,485),_choose_preset.bind(idx))
  b.name = "Preset%d" % idx
  b.tooltip_text = "انتخاب دسته" if not management_mode else "مشاهده و ساخت یک نسخهٔ قابل ویرایش"
 for i in range(library.saved.size()):
  var tile := Control.new()
  tile.custom_minimum_size = Vector2(279,565)
  row.add_child(tile)
  var art := MenuArt.button(tile,"Decks/normal.png","Decks/normal highlighted.png","Decks/normal pressed.png",Rect2(0,0,279,474),_choose_custom.bind(i))
  art.name = "Custom%d" % i
  var strip := ColorRect.new()
  strip.color = Color("242130")
  strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
  MenuArt.place(strip,tile,Rect2(0,405,279,80))
  MenuArt.label(tile,str(library.saved[i].name),Rect2(0,410,279,70),32)
  MenuArt.text_button(tile,"ویرایش",Rect2(40,493,200,60),open_editor.bind(i))
 var add := Control.new()
 add.custom_minimum_size = Vector2(279,565)
 row.add_child(add)
 var new_button := MenuArt.button(add,"Decks/Add/Default.png","Decks/Add/highlighted.png","Decks/Add/pressed.png",Rect2(0,0,279,390),open_editor.bind(-1))
 new_button.name = "NewDeck"
 new_button.tooltip_text = "ساخت دستهٔ جدید"

func _choose_preset(index: int) -> void:
 if not management_mode:
  deck_selected.emit(preset_decks[index])
  return
 open_editor(-1)
 name_edit.text = ["یک دستهٔ معمول", "مرام سیبیل", "انتقام آبجیز"][index]
 selected_counts.clear()
 for entry in preset_decks[index].entries:
  if entry.card != null and library.cards.has(entry.card.resource_path):
   selected_counts[entry.card.resource_path] = entry.copies
 _update_counts()

func _choose_custom(index: int) -> void:
 if management_mode:
  open_editor(index)
  return
 var deck := library.definition(library.saved[index].counts)
 if deck == null:
  open_editor(index)
  _status("این دسته باید کامل و ذخیره شود.")
 else: deck_selected.emit(deck)

func open_editor(index: int = -1) -> void:
 _cancel_deck_drag()
 active_index = index
 selected_counts = library.saved[index].counts.duplicate() if index >= 0 else {}
 editing = true
 page = "editor"
 search_text = ""
 MenuArt.clear(root_control)
 grid_hosts.clear()
 category_labels.clear()
 count_labels.clear()
 plus_buttons.clear()
 minus_buttons.clear()
 MenuArt.image(root_control,"main pages/deckbuilder.png",Rect2(0,0,2400,1080))
 _top_tools()
 MenuArt.image(root_control,"main pages/deckbuiler_title.png",Rect2(65,118,1870,124))
 # Three independent scroll columns retain the prototype's scissors/rock/paper order.
 for column in range(3):
  var panel := Panel.new()
  var accent: Color = [Color("a62b42"),Color("3e6dbb"),Color("b8983f")][column]
  panel.add_theme_stylebox_override("panel",MenuArt.style(Color(accent.r,accent.g,accent.b,0.10),Color(accent.r,accent.g,accent.b,0.65),10))
  panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
  MenuArt.place(panel,root_control,Rect2(60+column*625,226,616,840))
  var scroll := ScrollContainer.new()
  scroll.name = ["ScissorsScroll","RockScroll","PaperScroll"][column]
  scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
  scroll.scroll_deadzone = 8
  MenuArt.place(scroll,root_control,Rect2(65+column*625,242,610,812))
  var grid := GridContainer.new()
  grid.columns = 2
  grid.add_theme_constant_override("h_separation",18)
  grid.add_theme_constant_override("v_separation",20)
  scroll.add_child(grid)
  grid_hosts.append(grid)
 name_edit = LineEdit.new()
 name_edit.text = str(library.saved[index].name) if index >= 0 else "دستهٔ من"
 name_edit.placeholder_text = "نام دسته"
 name_edit.max_length = 32
 name_edit.add_theme_font_override("font",MenuArt.FONT)
 name_edit.add_theme_font_size_override("font_size",32)
 name_edit.add_theme_stylebox_override("normal",MenuArt.style(Color(0.12,0.12,0.19,0.65)))
 MenuArt.place(name_edit,root_control,Rect2(2015,915,370,50))
 name_edit.tooltip_text = "نام دسته"
 MenuArt.button(root_control,"Sort/Default.png","Sort/Default.png","Sort/pressed.png",Rect2(2010,10,278,103),func(): deck_sort_desc = not deck_sort_desc; _update_counts()).tooltip_text = "مرتب‌سازی کارت‌های انتخاب‌شده"
 name_edit.editable = not read_only
 MenuArt.button(root_control,"Back/Default.png","Back/Default.png","Back/pressed.png",Rect2(2290,18,95,90),_cancel_editor).tooltip_text = "بازگشت"
 for i in range(3):
  category_labels.append(MenuArt.label(root_control,"۰",Rect2(2015+i*125,183,55,46),30))
 var list_scroll := ScrollContainer.new()
 list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 MenuArt.place(list_scroll,root_control,Rect2(2012,242,373,658))
 deck_drop_area = list_scroll
 deck_list = VBoxContainer.new()
 deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 deck_list.add_theme_constant_override("separation",5)
 list_scroll.add_child(deck_list)
 total_label = MenuArt.label(root_control,"",Rect2(2080,970,155,65),40)
 save_button = MenuArt.button(root_control,"Finished/Default.png","Finished/Default.png","Finished/pressed.png",Rect2(2240,972,145,89),_save)
 save_button.name = "SaveDeck"
 save_button.tooltip_text = "ذخیرهٔ دسته"
 save_button.visible = not read_only
 status_label = MenuArt.label(root_control,"",Rect2(500,1005,1280,65),28,Color("f9d585"))
 _rebuild_cards()
 _update_counts()
 if read_only: _status("مجموعهٔ کارت‌ها — برای جزئیات روی کارت بزن")

func _top_tools() -> void:
 MenuArt.button(root_control,"Group 34/Default.png","Group 34/highlighted.png","Group 34/pressed.png",Rect2(30,14,90,90),_toggle_music).tooltip_text = "قطع یا پخش موسیقی"
 MenuArt.button(root_control,"bell/Default.png","bell/highlighted.png","bell/pressed.png",Rect2(145,15,56,88),func(): _status("اعلان تازه‌ای ندارید."))
 MenuArt.button(root_control,"notificationbird/Default.png","notificationbird/highlited.png","notificationbird/pressed.png",Rect2(230,19,123,85),func(): _status("پیام تازه‌ای ندارید."))
 MenuArt.button(root_control,"Sort2/Default.png","Sort2/Default.png","Sort2/pressed.png",Rect2(1410,10,405,103),_sort_cards).tooltip_text = "تغییر ترتیب هزینهٔ کارت‌ها"
 for i in range(3):
  MenuArt.image(root_control,["Sort2/DB-sort-green-rock.png","Sort2/DB-sort-green-paper.png","Sort2/DB-sort-green-scissor.png"][i],Rect2(1578+i*48,46,32,32))
 var search := LineEdit.new()
 search.placeholder_text = "جست‌وجوی کارت…"
 search.visible = false
 search.add_theme_font_override("font",MenuArt.FONT)
 search.add_theme_font_size_override("font_size",30)
 MenuArt.place(search,root_control,Rect2(800,25,590,70))
 search.text_changed.connect(func(value: String): search_text = value; _rebuild_cards(); _update_counts())
 MenuArt.button(root_control,"Search icon/Default.png","Search icon/Default.png","Search icon/pressed.png",Rect2(1830,10,105,103),func(): search.visible = not search.visible; search.grab_focus())

func _sort_cards() -> void:
 if sort_by_cost: reverse_sort = not reverse_sort
 sort_by_cost = true
 _rebuild_cards()
 _update_counts()

func _rebuild_cards() -> void:
 count_labels.clear()
 plus_buttons.clear()
 minus_buttons.clear()
 for grid in grid_hosts: MenuArt.clear(grid)
 var cards: Array[CardDefinition] = []
 cards.assign(settings.available_cards)
 if sort_by_cost:
  cards.sort_custom(func(a: CardDefinition,b: CardDefinition):
   if a.mana_cost == b.mana_cost: return a.display_name < b.display_name
   return a.mana_cost > b.mana_cost if reverse_sort else a.mana_cost < b.mana_cost)
 for card in cards:
  if card == null or card.gesture == CardGesture.Type.DIV: continue
  if not search_text.is_empty() and not (card.display_name+" "+str(card.card_id)+" "+_card_name(card)).to_lower().contains(search_text.to_lower()): continue
  var col := 0 if card.gesture == CardGesture.Type.SCISSORS else (1 if card.gesture == CardGesture.Type.ROCK else 2)
  var tile := Control.new()
  tile.custom_minimum_size = Vector2(280,437)
  grid_hosts[col].add_child(tile)
  var kind: String = ["R","P","S"][card.gesture]
  var counter: String = ["card-counter","card-counter-1","card-counter-2"][card.gesture]
  MenuArt.image(tile,"card counter/"+kind+"/"+counter+".png",Rect2(0,0,170,54))
  count_labels[card.resource_path] = MenuArt.label(tile,"۰",Rect2(43,0,80,50),30)
  var plus: String = ["plus-btn","plus-btn-1","plus-btn-2"][card.gesture]
  var minus: String = ["minus-btn","minus-btn-1","minus-btn-2"][card.gesture]
  var p := MenuArt.button(tile,"card counter/"+kind+"/"+plus+".png","","",Rect2(4,5,43,43),_change.bind(card,1))
  var m := MenuArt.button(tile,"card counter/"+kind+"/"+minus+".png","","",Rect2(124,5,43,43),_change.bind(card,-1))
  plus_buttons[card.resource_path] = p
  minus_buttons[card.resource_path] = m
  if card.mana_cost >= 1 and card.mana_cost <= 10:
   var suffix := "" if card.mana_cost == 1 else "-"+str(card.mana_cost-1)
   # Keep the source mana badge aspect ratio (117x95).
   # 67x54 prevents the icon/number artwork from looking horizontally stretched.
   MenuArt.image(tile,"mana num for DB/mana-badge"+suffix+".png",Rect2(176,0,67,54))
  else: MenuArt.label(tile,MenuArt.digits(card.mana_cost),Rect2(180,0,100,54),32,Color("68dacc"))
  var b := TextureButton.new()
  b.texture_normal = card.front_texture
  b.ignore_texture_size = true
  b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
  MenuArt.place(b,tile,Rect2(0,60,280,375))
  b.tooltip_text = _card_name(card) + " — کلیک: جزئیات، کشیدن به راست: افزودن به دسته"
  b.pressed.connect(_details.bind(card))
  b.gui_input.connect(_on_deck_card_drag_input.bind(card,b))
  b.mouse_entered.connect(func(): b.modulate = Color(1.12,1.12,1.12))
  b.mouse_exited.connect(func(): b.modulate = Color.WHITE)

func _on_deck_card_drag_input(event: InputEvent, card: CardDefinition, source: TextureButton) -> void:
 if read_only or card == null or source == null:
  return

 if event is InputEventMouseButton:
  var mouse := event as InputEventMouseButton
  if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
   _begin_deck_drag(card,source,-1,mouse.position,false)
  return

 if event is InputEventScreenTouch:
  var touch := event as InputEventScreenTouch
  if touch.pressed:
   _begin_deck_drag(card,source,touch.index,touch.position,true)


func _begin_deck_drag(card: CardDefinition, source: TextureButton, pointer_index: int, position: Vector2, is_touch: bool) -> void:
 _cancel_deck_drag()
 deck_drag_card = card
 deck_drag_source = source
 deck_drag_pointer_index = pointer_index
 deck_drag_start = position
 deck_drag_active = false
 deck_drag_cancelled = false
 deck_drag_is_touch = is_touch


func _update_deck_drag(position: Vector2) -> void:
 if deck_drag_card == null or deck_drag_cancelled:
  return

 var movement := position - deck_drag_start

 if not deck_drag_active:
  if movement.length() < DECK_DRAG_THRESHOLD:
   return

  # On touch, vertical movement still belongs to the existing card-list scroll.
  if deck_drag_is_touch and absf(movement.y) > absf(movement.x) * DECK_DRAG_HORIZONTAL_BIAS:
   deck_drag_cancelled = true
   return

  # The selected-deck panel is to the right, Hearthstone-style.
  if movement.x <= 0.0:
   deck_drag_cancelled = true
   return

  _start_deck_drag_preview()

 if deck_drag_active:
  _position_deck_drag_preview(position)
  _set_deck_drag_hover(_point_is_over_deck(position))


func _start_deck_drag_preview() -> void:
 if deck_drag_active or deck_drag_card == null:
  return

 deck_drag_active = true

 var preview := PanelContainer.new()
 preview.name = "DeckDragPreview"
 preview.custom_minimum_size = Vector2(165,225)
 preview.size = Vector2(165,225)
 preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
 preview.z_index = 1000
 preview.modulate = Color(1,1,1,0.94)
 preview.add_theme_stylebox_override(
  "panel",
  MenuArt.style(
   Color(0.05,0.05,0.08,0.96),
   Color(0.85,0.72,0.36,0.95),
   10
  )
 )

 var image := TextureRect.new()
 image.texture = deck_drag_card.front_texture
 image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 image.mouse_filter = Control.MOUSE_FILTER_IGNORE
 preview.add_child(image)

 root_control.add_child(preview)
 preview.move_to_front()
 deck_drag_preview = preview


func _position_deck_drag_preview(position: Vector2) -> void:
 if not is_instance_valid(deck_drag_preview):
  return

 deck_drag_preview.global_position = (
  position
  - deck_drag_preview.size * 0.5
  + Vector2(0,-28)
 )


func _point_is_over_deck(position: Vector2) -> bool:
 if not is_instance_valid(deck_drop_area):
  return false

 return deck_drop_area.get_global_rect().has_point(position)


func _set_deck_drag_hover(hovered: bool) -> void:
 if not is_instance_valid(deck_drop_area):
  return

 deck_drop_area.modulate = (
  Color(1.10,1.08,0.94,1.0)
  if hovered
  else Color.WHITE
 )


func _finish_deck_drag(position: Vector2) -> void:
 if deck_drag_card == null:
  return

 var card := deck_drag_card
 var should_add := (
  deck_drag_active
  and not deck_drag_cancelled
  and _point_is_over_deck(position)
 )

 _cancel_deck_drag()

 if should_add and card != null:
  # Reuse the exact same validation/count logic as the existing + button.
  _change(card,1)


func _cancel_deck_drag() -> void:
 _set_deck_drag_hover(false)

 if is_instance_valid(deck_drag_preview):
  deck_drag_preview.queue_free()

 deck_drag_preview = null
 deck_drag_card = null
 deck_drag_source = null
 deck_drag_pointer_index = -1
 deck_drag_active = false
 deck_drag_cancelled = false
 deck_drag_is_touch = false


func _change(card: CardDefinition, delta: int) -> void:
 if read_only: return
 var current := int(selected_counts.get(card.resource_path,0))
 if delta > 0:
  if library.total(selected_counts) >= settings.deck_size:
   _status("دسته پر است؛ ابتدا یک کارت کم کن.")
   return
  if current >= settings.get_copy_limit(card):
   _status("به سقف تعداد این کارت رسیده‌ای.")
   return
 var count := maxi(0,current+delta)
 if count == 0: selected_counts.erase(card.resource_path)
 else: selected_counts[card.resource_path] = count
 _update_counts()

func _update_counts() -> void:
 var total := library.total(selected_counts)
 for path in count_labels:
  var n := int(selected_counts.get(path,0))
  count_labels[path].text = MenuArt.digits(n)
  plus_buttons[path].disabled = read_only or n >= settings.get_copy_limit(library.cards[path]) or total >= settings.deck_size
  minus_buttons[path].disabled = read_only or n == 0
 MenuArt.clear(deck_list)
 var totals := [0,0,0]
 var ordered_paths := selected_counts.keys()
 ordered_paths.sort_custom(func(a: String,b: String): return library.cards[a].mana_cost > library.cards[b].mana_cost if deck_sort_desc else library.cards[a].mana_cost < library.cards[b].mana_cost)
 for path in ordered_paths:
  var card := library.cards.get(path) as CardDefinition
  if card == null: continue
  var n := int(selected_counts[path])
  if card.gesture < 3: totals[card.gesture] += n
  var row := Control.new()
  row.custom_minimum_size = Vector2(353,48)
  deck_list.add_child(row)
  MenuArt.image(row,"Card bars/"+["rock","paper","scissor"][card.gesture]+".png",Rect2(0,0,353,48))
  MenuArt.label(row,MenuArt.digits(n),Rect2(0,0,30,48),28)
  MenuArt.label(row,_card_name(card),Rect2(28,0,245,48),24)
  MenuArt.label(row,MenuArt.digits(card.mana_cost),Rect2(305,0,43,48),26,Color("67dfcd"))
  var remove := Button.new()
  remove.flat = true
  MenuArt.place(remove,row,Rect2(0,0,353,48))
  remove.tooltip_text = "کلیک: کم‌کردن یک نسخه"
  remove.pressed.connect(_change.bind(card,-1))
 for i in range(3): category_labels[i].text = MenuArt.digits(totals[i])
 total_label.text = MenuArt.digits(total)+"/"+MenuArt.digits(settings.deck_size)
 total_label.add_theme_color_override("font_color",Color("80e2cc") if library.valid(selected_counts) else Color("efb076"))
 save_button.disabled = read_only or not library.valid(selected_counts)
 save_button.modulate.a = 0.55 if save_button.disabled else 1.0

func _save() -> void:
 if not library.valid(selected_counts):
  _status("دسته باید دقیقاً %s کارت داشته باشد." % MenuArt.digits(settings.deck_size))
  return
 var err := library.save_deck(active_index,name_edit.text,selected_counts)
 if err != OK:
  _status("ذخیره نشد؛ دوباره تلاش کن.")
  return
 show_gallery()

func _cancel_editor() -> void:
 if read_only: _close()
 elif not selected_counts.is_empty():
  var dialog := ConfirmationDialog.new()
  dialog.title = "بازگشت"
  dialog.dialog_text = "تغییرات ذخیره‌نشده کنار گذاشته شود؟"
  dialog.ok_button_text = "بله، بازگشت"
  dialog.cancel_button_text = "ادامهٔ ویرایش"
  add_child(dialog)
  dialog.confirmed.connect(func(): dialog.queue_free(); show_gallery())
  dialog.canceled.connect(dialog.queue_free)
  dialog.popup_centered(Vector2i(560,200))
 else: show_gallery()

func _status(text: String) -> void:
 if is_instance_valid(status_label): status_label.text = text

func _toggle_music() -> void:
 var music := get_node_or_null("/root/MusicManager")
 if music == null: return
 if music.is_music_paused(): music.resume_music()
 else: music.pause_music()

func _details(card: CardDefinition) -> void:
 var veil := ColorRect.new()
 veil.color = Color(0.02,0.02,0.04,0.93)
 MenuArt.place(veil,root_control,Rect2(0,0,2400,1080))
 MenuArt.texture(veil,card.info_image if card.info_image != null else card.front_texture,Rect2(300,60,1800,900))
 MenuArt.text_button(veil,"بستن",Rect2(1000,980,400,70),veil.queue_free)

func _card_name(card: CardDefinition) -> String:
 # Most cards already have Persian names printed on their artwork.
 var names := {"normal_rock":"سنگ","normal_paper":"کاغذ","normal_scissors":"قیچی", "mustache_rock":"سنگ سیبیل", "chainsaw":"اره‌برقی", "buffer_rock":"تقویت سنگ", "buffer_paper":"تقویت کاغذ", "buffer_scissors":"تقویت قیچی", "killer_rock":"آبجی آبی", "defense_rock":"سپر", "defense_paper":"دیوار", "changeling_rock":"مهندس", "changeling_paper":"مهندس", "changeling_scissors":"مهندس"}
 return str(names.get(str(card.card_id),card.display_name))
