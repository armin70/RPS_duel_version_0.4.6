class_name MenuDeckLibrary
extends RefCounted

const SAVE_PATH := "user://custom_decks.cfg"
var settings: DeckBuilderSettings
var cards: Dictionary = {}
var saved: Array[Dictionary] = []

func _init(value: DeckBuilderSettings) -> void:
 settings = value
 for card in settings.available_cards:
  if card != null: cards[card.resource_path] = card
 load_saved()

func total(counts: Dictionary) -> int:
 var result := 0
 for n in counts.values(): result += int(n)
 return result

func valid(counts: Dictionary) -> bool:
 if total(counts) != settings.deck_size: return false
 for path in counts:
  var card := cards.get(path) as CardDefinition
  if card == null or int(counts[path]) <= 0 or int(counts[path]) > settings.get_copy_limit(card): return false
 return true

func definition(counts: Dictionary) -> DeckDefinition:
 if not valid(counts): return null
 var deck := DeckDefinition.new()
 for path in counts:
  var entry := DeckEntry.new()
  entry.card = cards[path]
  entry.copies = int(counts[path])
  deck.entries.append(entry)
 return deck

func load_saved() -> void:
 saved.clear()
 var cfg := ConfigFile.new()
 if cfg.load(SAVE_PATH) != OK: return
 var count := int(cfg.get_value("custom_decks", "count", 1 if cfg.has_section("custom_deck_1") else 0))
 for i in range(count):
  var section := "custom_deck_%d" % (i+1)
  if not cfg.has_section(section): continue
  var counts := {}
  for path in cfg.get_value(section,"cards",PackedStringArray()):
   var card := cards.get(str(path)) as CardDefinition
   if card != null and total(counts) < settings.deck_size:
    counts[str(path)] = mini(int(counts.get(str(path),0))+1, settings.get_copy_limit(card))
  saved.append({"name":str(cfg.get_value(section,"name","دستهٔ من")),"counts":counts})

func save_deck(index: int, title: String, counts: Dictionary) -> Error:
 if not valid(counts): return ERR_INVALID_DATA
 var next := saved.duplicate(true)
 var record := {"name":title.strip_edges() if not title.strip_edges().is_empty() else "دستهٔ من", "counts":counts.duplicate()}
 if index >= 0 and index < next.size(): next[index] = record
 else: next.append(record)
 var cfg := ConfigFile.new()
 cfg.set_value("custom_decks","count",next.size())
 for i in range(next.size()):
  var section := "custom_deck_%d" % (i+1)
  var paths := PackedStringArray()
  for path in next[i].counts:
   for n in range(int(next[i].counts[path])): paths.append(path)
  cfg.set_value(section,"name",next[i].name)
  cfg.set_value(section,"cards",paths)
 var err := cfg.save(SAVE_PATH)
 if err == OK: saved.assign(next)
 return err
