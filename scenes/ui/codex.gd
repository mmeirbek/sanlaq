extends Control
## Энциклопедия: два раздела. «Киім» — коллекция одежды по слотам и описание
## вещи с иллюстрацией (иконка и персонаж, на котором она надета). «Тарих» —
## статьи «Дала жолы» по рубрикам; закрытая статья подсказывает, в какой
## главе она открывается. Статьи общие для всех героев.

const RARITY_NAMES := {
	ClothingItem.Rarity.COMMON: "Кәдімгі",
	ClothingItem.Rarity.RARE: "Сирек",
	ClothingItem.Rarity.LEGENDARY: "Аңыз",
}
const CATEGORIES := ["ТҰЛҒАЛАР", "ОҚИҒАЛАР", "ЖЕР-СУ", "МӘДЕНИЕТ"]
const SUBTITLES := ["ҰЛТТЫҚ КИІМ · ТАРИХЫН ТАНЫ", "ДАЛА ЖОЛЫ · ТҰЛҒАЛАР МЕН ОҚИҒАЛАР"]
const LORE := ["Әр заттың тарихын оқып, өз образыңды жина.",
	"Батырлармен бірге Дала жолынан өтіп, жаңа беттерді аш."]
const CHARACTER_SCENE := preload("res://scenes/entities/character_visual.tscn")
## Персонаж в иллюстрации — ×3, целым масштабом.
const MANNEQUIN_SCALE := 3
const PICTURE_SIZE := Vector2(192, 192)

enum Section { CLOTHING, HISTORY }

var section := Section.CLOTHING
var _current_slot: ClothingItem.SlotType = ClothingItem.SlotType.HEAD
var _category := 0
var _mannequin: CharacterVisual
var _section_buttons: Array[PixelButton] = []
var _categories: HBoxContainer
## Статья -> название главы, в которой она открывается.
var _where := {}

@onready var _tabs: SlotTabs = %Tabs
@onready var _grid: GridContainer = %Grid
@onready var _mannequin_slot: Control = %MannequinSlot
@onready var _header: ScreenHeader = %Header


func _ready() -> void:
	_header.back_pressed.connect(SceneRouter.go_to_main_menu)
	_tabs.slot_selected.connect(_show_slot)
	_build_sections()
	_build_mannequin()
	_index_chapters()
	show_section(SceneRouter.codex_section)
	SceneRouter.codex_section = Section.CLOTHING


func _build_sections() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiTokens.SPACE_S)
	var column := _tabs.get_parent()
	column.add_child(row)
	column.move_child(row, 0)
	for i in 2:
		var button := PixelButton.new()
		button.text = tr(["КИІМ", "ТАРИХ"][i])
		button.toggle_mode = true
		button.theme_type_variation = "ButtonSecondary"
		button.pressed.connect(show_section.bind(i))
		row.add_child(button)
		_section_buttons.append(button)
	_categories = HBoxContainer.new()
	_categories.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_categories)
	column.move_child(_categories, _tabs.get_index() + 1)
	for i in CATEGORIES.size():
		var card := SelectableCard.new()
		card.compact = true
		var label := Label.new()
		label.text = tr(CATEGORIES[i])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		card.pressed.connect(_show_category.bind(i))
		_categories.add_child(card)


func _build_mannequin() -> void:
	_mannequin = CHARACTER_SCENE.instantiate()
	_mannequin.scale = Vector2.ONE * MANNEQUIN_SCALE
	_mannequin.set_direction(Vector2.DOWN)
	_mannequin_slot.add_child(_mannequin)
	var step := UiTokens.PIXEL * MANNEQUIN_SCALE
	_mannequin.set_rest_position((_mannequin_slot.custom_minimum_size / 2 / step).floor() * step)


## Где открывается каждая статья: шаги и костры глав всех героев.
func _index_chapters() -> void:
	var cast := AssetRegistry.get_story_cast()
	if cast == null:
		return
	for hero in cast.heroes:
		var chapter := AssetRegistry.get_story_chapter(hero.chapter)
		if chapter == null:
			continue
		for beat in chapter.beats:
			for entry_id in beat.unlock:
				_where[entry_id] = chapter.title
			for topic in beat.topics:
				_where[topic.entry] = chapter.title


func show_section(index: int) -> void:
	section = index as Section
	for i in _section_buttons.size():
		_section_buttons[i].set_pressed_no_signal(i == index)
	_header.subtitle = tr(SUBTITLES[index])
	_tabs.visible = section == Section.CLOTHING
	%SlotName.visible = section == Section.CLOTHING
	_categories.visible = section == Section.HISTORY
	%LoreText.text = tr(LORE[index])
	if section == Section.CLOTHING:
		_show_slot(_current_slot)
	else:
		_show_category(_category)


func _clear_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()


# --- Киім ---------------------------------------------------------------------

func _show_slot(slot: ClothingItem.SlotType) -> void:
	if section != Section.CLOTHING:
		show_section(Section.CLOTHING)
		return
	_current_slot = slot
	_tabs.select(slot)
	%SlotName.text = ClothingItem.SLOT_NAMES[slot]
	_clear_grid()
	var lang := GameSettings.get_lang_code()
	var items := AssetRegistry.get_clothing(slot)
	for item in items:
		var card := ClothingCard.create(item, item.get_name_for_lang(lang))
		card.pressed.connect(_select.bind(item))
		_grid.add_child(card)
	if not items.is_empty():
		_select(items[0])


func _select(item: ClothingItem) -> void:
	for card in _grid.get_children():
		(card as ClothingCard).selected = (card as ClothingCard).item.id == item.id
	var lang := GameSettings.get_lang_code()
	%Icon.texture = load(item.icon_path) as Texture2D
	%Icon.visible = true
	_show_picture(null)
	%NameLabel.text = item.get_name_for_lang(lang)
	%MetaLabel.text = "%s · %s" % [tr(ClothingItem.SLOT_NAMES[item.slot_type]), tr(RARITY_NAMES[item.rarity])]
	%DescLabel.text = item.get_desc_for_lang(lang)
	_dress_mannequin(item)


## Персонаж в стартовом образе, но с выбранной вещью — так её видно на человеке.
func _dress_mannequin(item: ClothingItem) -> void:
	OutfitApplier.dress(_mannequin, OutfitApplier.starter_outfit_with(item))


# --- Тарих --------------------------------------------------------------------

func _show_category(index: int) -> void:
	_category = index
	for i in _categories.get_child_count():
		(_categories.get_child(i) as SelectableCard).selected = i == index
	_clear_grid()
	var cast := AssetRegistry.get_story_cast()
	var first: EntryCard = null
	for entry in cast.entries if cast != null else []:
		if entry.category != CATEGORIES[index]:
			continue
		var open := StoryState.entry_open(SaveManager.story, entry)
		var card := EntryCard.create(entry, open, "" if open else _locked_hint(entry))
		card.pressed.connect(_select_entry.bind(card))
		_grid.add_child(card)
		if first == null:
			first = card
	if first != null:
		_select_entry(first)


func _locked_hint(entry: EncyclopediaEntry) -> String:
	if _where.has(entry.id):
		return tr("%s — осы тарауда ашылады.") % tr(_where[entry.id])
	return tr("Дала жолында ашылады.")


func _select_entry(chosen: EntryCard) -> void:
	for card in _grid.get_children():
		(card as EntryCard).selected = card == chosen
	var entry := chosen.entry
	%Icon.visible = false
	_show_picture(EntryCard.picture(entry, chosen.opened, MANNEQUIN_SCALE, PICTURE_SIZE))
	if chosen.opened:
		%NameLabel.text = tr(entry.title)
		%MetaLabel.text = tr(entry.category)
		%DescLabel.text = tr(entry.text)
	else:
		%NameLabel.text = tr("Әлі ашылмаған")
		%MetaLabel.text = tr(entry.category)
		%DescLabel.text = _locked_hint(entry)


## В рамке иллюстрации — либо манекен с одеждой, либо картинка статьи.
func _show_picture(picture: Control) -> void:
	for child in _mannequin_slot.get_children():
		if child != _mannequin:
			child.queue_free()
	_mannequin.visible = picture == null
	if picture != null:
		_mannequin_slot.add_child(picture)
