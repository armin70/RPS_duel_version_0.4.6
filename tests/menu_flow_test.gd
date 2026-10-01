extends SceneTree
var failures := 0
func check(condition: bool, message: String) -> void:
 if condition: print("PASS ",message)
 else:
  failures += 1
  push_error("FAIL "+message)
func tick() -> void:
 for i in range(4): await process_frame
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var scene = load("res://game/main_game.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 await tick()
 var menu = scene.get_node("MainMenu")
 check(paused,"menu pauses game")
 check(menu.root_control.visible,"home visible")
 menu.select_page("collection")
 await tick()
 var deck = menu.deck_screen
 check(is_instance_valid(deck),"collection opens")
 check(deck.page == "gallery","deck gallery")
 deck.open_editor(-1)
 await tick()
 check(deck.grid_hosts.size() == 3,"three columns")
 var added := 0
 for card in deck.settings.available_cards:
  for i in range(deck.settings.get_copy_limit(card)):
   if added < deck.settings.deck_size:
    deck._change(card,1)
    added += 1
 check(deck.library.total(deck.selected_counts) == deck.settings.deck_size,"deck full")
 deck._change(deck.settings.available_cards[0],1)
 check(deck.library.total(deck.selected_counts) == deck.settings.deck_size,"overflow blocked")
 check(not deck.save_button.disabled,"complete deck can save")
 deck.name_edit.text = "آزمون ذخیره"
 deck._save()
 await tick()
 check(deck.page == "gallery","save returns gallery")
 var data = load("res://ui/menu/deck_library.gd").new(deck.settings)
 check(data.saved.size() > 0,"saved deck reloads")
 check(data.valid(data.saved[-1].counts),"saved deck valid")
 deck.open_editor(data.saved.size()-1)
 await tick()
 check(deck.name_edit.text == "آزمون ذخیره","saved title restored")
 deck._sort_cards()
 await tick()
 check(deck.grid_hosts[0].get_child_count() > 0,"sorting preserves scissors")
 menu.select_page("home")
 await tick()
 check(not is_instance_valid(menu.deck_screen),"collection removed on home")
 menu.select_page("collection")
 await tick()
 menu._section("cards")
 await tick()
 check(menu.deck_screen.read_only,"card collection read-only")
 menu.select_page("battle")
 await tick()
 check(menu.submenu.get_child_count() == 5,"battle actions available")
 menu._start_game("bot")
 await tick()
 check(not paused,"game unpaused")
 var controller = scene.get_node("MatchController3D")
 check(controller.deck_selection_active,"offline deck selection opens")
 check(is_instance_valid(controller.deck_selection_screen),"new deck selection used before match")
 controller.deck_selection_screen._choose_preset(0)
 await tick()
 check(controller.state != null,"match state created with selected deck")
 controller.hud._confirm_return_to_menu()
 await tick()
 await tick()
 check(current_scene != null and current_scene.has_node("MainMenu"),"return from game restores new menu")
 check(paused,"returned menu pauses game")
 print("FLOW FAILURES ",failures)
 paused = false
 current_scene.queue_free()
 await tick()
 quit(failures)
