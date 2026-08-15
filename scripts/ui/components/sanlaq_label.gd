class_name SanlaqLabel
extends Label
## Label с типовыми размерами: HERO / TITLE / SUBTITLE / BODY / SMALL.

enum Kind { HERO, TITLE, SUBTITLE, BODY, SMALL }

@export var variant: Kind = Kind.BODY

func _ready() -> void:
	var is_heading := variant == Kind.HERO or variant == Kind.TITLE
	if is_heading:
		add_theme_font_override("font", SanlaqDesignTokens.FONT_BOLD)
	add_theme_font_size_override("font_size", _size_for(variant))

func _size_for(v: Kind) -> int:
	match v:
		Kind.HERO: return SanlaqDesignTokens.FONT_SIZE_HERO
		Kind.TITLE: return SanlaqDesignTokens.FONT_SIZE_TITLE
		Kind.SUBTITLE: return SanlaqDesignTokens.FONT_SIZE_SUBTITLE
		Kind.SMALL: return SanlaqDesignTokens.FONT_SIZE_SMALL
		_: return SanlaqDesignTokens.FONT_SIZE_BODY
