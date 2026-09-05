class_name GameWord
extends Resource
## Слово-карточка для образовательных режимов («Абай айтады» и следующие).
## Категории расширяются без изменения кода: "food", позже "instrument", "yurt_part".
## Пути к иконке и озвучке хранятся строками и грузятся в рантайме — так же, как
## это сделано в ClothingItem (icon_path/texture_path), чтобы .tres оставались
## редактируемыми руками и не тянули ext_resource на каждый ассет.

@export var id: String = ""
@export var category: String = "food"
@export var name_kz: String = ""
@export var name_en: String = ""
@export var icon_path: String = ""
## Озвучка названия. Пока пусто — режим играет свой тон на каждую карточку;
## как только появятся записи, достаточно прописать путь, код подхватит файл.
@export var sound_path: String = ""

func get_name_for_lang(lang: String) -> String:
	match lang:
		"en": return name_en
		_: return name_kz
