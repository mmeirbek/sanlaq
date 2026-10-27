class_name EntryCard
extends SelectableCard
## Карточка статьи энциклопедии «Дала жолы»: иконка или портрет человека и
## заголовок. Закрытая статья — знак вопроса вместо картинки и названия.

const PORTRAIT_SCALE := 2
const PORTRAIT_SIZE := Vector2(64, 64)

var entry: EncyclopediaEntry
var opened := false


static func create(story_entry: EncyclopediaEntry, is_open: bool, hint: String = "") -> EntryCard:
	var card := EntryCard.new()
	card.entry = story_entry
	card.opened = is_open
	card.tooltip_text = hint
	return card


func _ready() -> void:
	compact = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.add_child(picture(entry, opened, PORTRAIT_SCALE, PORTRAIT_SIZE))
	var label := Label.new()
	label.text = tr(entry.title) if opened else "? ? ?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 120
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	super()


## Картинка статьи: иконка предмета, портрет человека (голова и плечи) или «?».
static func picture(story_entry: EncyclopediaEntry, is_open: bool, scale: int, frame: Vector2) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = frame
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not is_open:
		var mark := Label.new()
		mark.text = "?"
		mark.theme_type_variation = "TitleLabel"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(mark)
	elif not story_entry.look.is_empty():
		var person := StoryLooks.create(story_entry.look)
		person.scale = Vector2.ONE * scale
		slot.add_child(person)
		# Лицо (строка 10 клетки 32×32) — в середине рамки, как в окне диалога.
		person.set_rest_position(frame / 2 + Vector2(0, 6 * UiTokens.PIXEL * scale))
	elif not story_entry.icon.is_empty():
		var icon := TextureRect.new()
		icon.texture = load("res://assets/sprites/story/icon_%s.png" % story_entry.icon) as Texture2D
		# Иконка 64×64; в рамке кратной величины — целым масштабом.
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(icon)
	return slot
