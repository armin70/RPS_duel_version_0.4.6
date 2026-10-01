extends CanvasLayer

const MenuArt = preload("res://ui/menu/menu_skin.gd")
const DeckScreen = preload("res://game/deck_builder/deck_selection_screen.gd")
@export var match_controller: MatchController3D
@export var intro_camera: Node
@export var cloud_controller: Node
@export_category("Profile preview — connect to account data when available")
@export var player_name := "رستم دستان"
@export var level := 10
@export var experience := 500
@export var next_level_experience := 1000
@export var coins := 100
@export var gems := 10
var root_control: Control
var background: TextureRect
var content: Control
var profile: Control
var submenu: Control
var selection: TextureRect
var nav_buttons: Array[TextureButton] = []
var deck_screen: DeckSelectionScreen
var active_page := "home"
var active_section := "decks"
var transitioning := false
var sub_tween: Tween
var notice: Control

func _ready() -> void:
 layer = 70
 process_mode = Node.PROCESS_MODE_ALWAYS
 if match_controller == null:
  match_controller = get_tree().get_first_node_in_group("match_controller") as MatchController3D
 root_control = $MenuRoot
 background = $MenuRoot/Background
 content = $MenuRoot/Content
 profile = $MenuRoot/Profile
 submenu = $MenuRoot/Submenu
 selection = $MenuRoot/Selection
 get_viewport().size_changed.connect(_resize)
 _resize()
 _build_navigation()
 _build_toolbar()
 select_page("home")
 var music := get_node_or_null("/root/MusicManager")
 if music: music.play_menu_music()
 # Only the menu continues processing until a real game mode is chosen.
 get_tree().paused = true

func _resize() -> void:
 MenuArt.fit(root_control)

func _exit_tree() -> void:
 if is_instance_valid(deck_screen): deck_screen.queue_free()
 if get_tree() != null: get_tree().paused = false

func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel") and not transitioning:
  if is_instance_valid(notice): notice.queue_free(); notice = null
  elif not is_instance_valid(deck_screen) or not deck_screen.editing: select_page("home")
  get_viewport().set_input_as_handled()

func _build_navigation() -> void:
 var normal := [91,90,89,88,87]
 var hover := [92,93,94,95,96]
 var pressed := [97,98,99,100,101]
 var ids := ["home","battle","collection","rewards","shop"]
 for i in range(5):
  var b := MenuArt.button(root_control,"main btn normal/Group %d.png"%normal[i],"main btn highlighted/Group %d.png"%hover[i],"main btn pressed/Group %d.png"%pressed[i],Rect2(2240,65+i*190,145,176),select_page.bind(ids[i]))
  b.name = ["HomeButton","BattleButton","CollectionButton","RewardsButton","ShopButton"][i]
  nav_buttons.append(b)

func _build_toolbar() -> void:
 MenuArt.button(root_control,"Group 34/Default.png","Group 34/highlighted.png","Group 34/pressed.png",Rect2(55,15,90,90),_settings).tooltip_text = "تنظیمات"
 MenuArt.button(root_control,"bell/Default.png","bell/highlighted.png","bell/pressed.png",Rect2(180,15,58,91),_message.bind("اعلان‌ها","اعلان تازه‌ای ندارید."))
 MenuArt.button(root_control,"notificationbird/Default.png","notificationbird/highlited.png","notificationbird/pressed.png",Rect2(275,19,130,91),_message.bind("پیام‌ها","پیام تازه‌ای ندارید."))
 MenuArt.label(root_control,MenuArt.digits(gems),Rect2(511,15,97,90),52,Color("982aff"))
 MenuArt.label(root_control,MenuArt.digits(coins),Rect2(778,15,106,90),52,Color("ffd33e"))
 for x in [620,880]:
  var b := Button.new()
  b.flat = true
  b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
  MenuArt.place(b,root_control,Rect2(x,15,55,88))
  b.pressed.connect(select_page.bind("shop"))

func select_page(id: String) -> void:
 if transitioning: return
 if is_instance_valid(deck_screen):
  deck_screen.queue_free()
  deck_screen = null
 var previous := active_page
 active_page = id
 MenuArt.clear(content)
 MenuArt.clear(submenu)
 var expanded := id == "battle" or id == "collection"
 background.texture = MenuArt.tex("main pages/Base-Expand.png" if expanded else "main pages/Base-Minimized.png")
 selection.position = Vector2(2224,42+["home","battle","collection","rewards","shop"].find(id)*190)
 _build_profile(id == "home")
 submenu.visible = expanded
 if sub_tween != null: sub_tween.kill()
 submenu.position = Vector2(1893,0)
 if expanded:
  _build_submenu(id)
  if previous != id:
   submenu.modulate.a = 0.0
   submenu.position.x += 30
   sub_tween = create_tween().set_parallel(true)
   sub_tween.tween_property(submenu,"modulate:a",1.0,0.18)
   sub_tween.tween_property(submenu,"position:x",1893.0,0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 else:
  if id == "shop": _empty_page("دکان","فروشگاه هنوز به سیستم خرید متصل نشده است.")
  elif id == "rewards": _empty_page("پاداش","سیستم دریافت پاداش هنوز فعال نشده است.")
 if id == "collection": _section("decks")

func _build_profile(big: bool) -> void:
 MenuArt.clear(profile)
 profile.position = Vector2(1560,28) if big else Vector2(1590,18)
 var factor := 1.0 if big else 0.49
 profile.scale = Vector2.ONE*factor
 MenuArt.image(profile,"Profile diassembled/profile big.png",Rect2(60,0,541,203))
 var atlas := AtlasTexture.new()
 atlas.atlas = load("res://art/heroes/rostam.png") as Texture2D
 atlas.region = Rect2(235,25,270,290)
 MenuArt.texture(profile,atlas,Rect2(409,10,180,181))
 MenuArt.label(profile,player_name,Rect2(55,7,344,90),58)
 var progress := ProgressBar.new()
 progress.show_percentage = false
 progress.max_value = maxi(next_level_experience,1)
 progress.value = experience
 progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
 progress.add_theme_stylebox_override("background",MenuArt.style(Color("292339"),Color("b5a042"),0))
 progress.add_theme_stylebox_override("fill",MenuArt.style(Color("17c1d3"),Color("b5a042"),0))
 MenuArt.place(progress,profile,Rect2(65,111,334,39))
 MenuArt.label(profile,MenuArt.digits(experience)+"/"+MenuArt.digits(next_level_experience),Rect2(200,105,192,49),28)
 MenuArt.label(profile,"جوان پهلوان",Rect2(160,151,239,52),40,Color("cf292b"))
 MenuArt.image(profile,"Profile diassembled/profile level big.png",Rect2(-45,83,125,125))
 MenuArt.label(profile,MenuArt.digits(level),Rect2(-35,98,104,85),57,Color("ffd34a"))

func _sub_asset(number: int) -> String:
 return "main pages/btn/Btn Main"+("" if number < 0 else "-"+str(number))+".png"

func _build_submenu(id: String) -> void:
 # Each group contains exported normal/selected/pressed artwork.
 var specs: Array = [["decks",2,7,12],["cards",-1,5,10],["boards",1,6,11],["heroes",3,8,13],["emotes",4,9,14]]
 if id == "battle": specs = [["online",15,16,17],["rush",21,22,23],["bot",18,19,20]]
 for i in range(specs.size()):
  var item: Array = specs[i]
  var b := MenuArt.button(submenu,_sub_asset(item[1]),_sub_asset(item[2]),_sub_asset(item[3]),Rect2(18,265+i*102,295,100),_section.bind(item[0]))
  b.name = "Section_"+str(item[0])
  b.set_meta("normal",item[1])
  b.set_meta("selected",item[2])
 if id == "battle":
  MenuArt.text_button(submenu,"آموزش",Rect2(40,610,250,70),_start_game.bind("tutorial"))
  MenuArt.text_button(submenu,"تمرین دشوار",Rect2(40,695,250,70),_start_game.bind("hardcore"))

func _section(id: String) -> void:
 active_section = id
 for n in submenu.get_children():
  if n is TextureButton and n.has_meta("selected"):
   n.texture_normal = MenuArt.tex(_sub_asset(n.get_meta("selected") if n.name == "Section_"+id else n.get_meta("normal")))
 if is_instance_valid(deck_screen):
  deck_screen.queue_free()
  deck_screen = null
 MenuArt.clear(content)
 match id:
  "decks", "cards": _open_collection(id == "cards")
  "online":
   var online := get_node_or_null("/root/OnlineBootstrap")
   if online: online.open_lobby()
   else: _message("نبرد آنلاین","سرویس آنلاین در دسترس نیست.")
  "rush": _start_game("rush")
  "bot": _start_game("bot")
  "heroes":
   for i in range(3):
    var path: String = ["rostam","tahmineh","afrasiab"][i]
    var b := TextureButton.new()
    b.texture_normal = load("res://art/heroes/"+path+".png")
    b.ignore_texture_size = true
    b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    MenuArt.place(b,content,Rect2(310+i*455,245,360,620))
    b.pressed.connect(_message.bind(["رستم","تهمینه","افراسیاب"][i],"قهرمان را پیش از شروع نبرد انتخاب می‌کنی."))
  "boards":
   MenuArt.texture(content,load("res://art/main_land/Land2.5D_V1.1.png"),Rect2(270,240,1390,620))
   MenuArt.label(content,"زمین فعلی نبرد",Rect2(600,875,700,75),45)
  "emotes": _empty_page("ادا و اشاره","این بخش هنوز فعال نشده است.")

func _open_collection(cards_only: bool) -> void:
 if match_controller == null: return
 deck_screen = DeckScreen.new()
 deck_screen.management_mode = true
 deck_screen.read_only = cards_only
 var decks: Array[DeckDefinition] = [match_controller.player_one_deck,match_controller.player_one_deck_2,match_controller.player_one_deck_3]
 var previews: Array[CardDefinition] = [match_controller.deck_one_preview_card,match_controller.deck_two_preview_card,match_controller.deck_three_preview_card]
 deck_screen.configure(match_controller.deck_builder_settings,decks,previews)
 deck_screen.close_requested.connect(func(): deck_screen = null; _section("decks"))
 add_child(deck_screen)

func _start_game(mode: String) -> void:
 if transitioning or match_controller == null: return
 transitioning = true
 ProjectSettings.set_setting("gameplay/hardcore_bot",mode == "hardcore")
 match_controller.tutorial_enabled = mode == "tutorial"
 match_controller.rush_mode_enabled = mode == "rush"
 root_control.hide()
 get_tree().paused = false
 var music := get_node_or_null("/root/MusicManager")
 if music: music.play_game_music()
 if mode == "tutorial": await match_controller.begin_tutorial_match()
 elif mode == "rush": await match_controller.begin_rush_match()
 else: match_controller.begin_deck_selection()
 queue_free()

func _empty_page(title: String, text: String) -> void:
 MenuArt.label(content,title,Rect2(390,325,1150,120),70,Color("edcb71"))
 MenuArt.label(content,text,Rect2(260,470,1420,120),39)

func _message(title: String, text: String) -> void:
 if is_instance_valid(notice): notice.queue_free()
 var veil := ColorRect.new()
 veil.color = Color(0.01,0.01,0.03,0.82)
 MenuArt.place(veil,root_control,Rect2(0,0,2400,1080))
 notice = veil
 var panel := Panel.new()
 panel.add_theme_stylebox_override("panel",MenuArt.style(Color("302d41")))
 MenuArt.place(panel,veil,Rect2(600,290,1200,480))
 MenuArt.label(panel,title,Rect2(60,30,1080,100),58,Color("e9c670"))
 MenuArt.label(panel,text,Rect2(60,135,1080,180),36)
 MenuArt.text_button(panel,"بستن",Rect2(440,350,320,80),func(): veil.queue_free(); notice = null)

func _settings() -> void:
 _message("تنظیمات","موسیقی بازی")
 var music := get_node_or_null("/root/MusicManager")
 if music == null: return
 var b := MenuArt.text_button(notice,"پخش موسیقی" if music.is_music_paused() else "قطع موسیقی",Rect2(955,525,490,75),Callable())
 b.pressed.connect(func():
  if music.is_music_paused(): music.resume_music()
  else: music.pause_music()
  b.text = "پخش موسیقی" if music.is_music_paused() else "قطع موسیقی")
