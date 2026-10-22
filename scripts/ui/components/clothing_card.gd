class_name ClothingCard
extends SelectableCard
## Компактная карточка предмета одежды: иконка и название. Её используют шкаф и
## энциклопедия. Подписи передаёт экран — карточка не знает о языке.

var item: ClothingItem
var _title := ""


static func create(clothing: ClothingItem, title: String, hint: String = "") -> ClothingCard:
	var card := ClothingCard.new()
	card.item = clothing
	card._title = title
	card.tooltip_text = hint
	return card


func _ready() -> void:
	compact = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var icon := TextureRect.new()
	icon.texture = load(item.icon_path) as Texture2D if not item.icon_path.is_empty() else null
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var label := Label.new()
	label.text = _title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	super()
