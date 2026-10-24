class_name StoryChapter
extends Resource
## Глава «Тарих жолы»: шаги, люди в мире, диалоги, финал. Финал зависит от
## бірлік: набрал finale_alt_min_unity — звучит другой текст, ally_min_unity —
## в мире появляются союзники.

@export var id: String = ""
@export var hero: String = ""
@export var title: String = ""
@export var subtitle: String = ""
@export_multiline var intro: String = ""
@export var finale_title: String = ""
@export_multiline var finale_text: String = ""
@export_multiline var finale_alt_text: String = ""
@export var finale_alt_min_unity: int = 0
@export var ally_min_unity: int = 0
@export var ally_message: String = ""
## В жекпе-жеке помогает жасақтас, если бірлік не меньше; 0 — никогда.
@export var duel_ally_min_unity: int = 0
@export var beats: Array[StoryBeat] = []
@export var placements: Array[StoryPlacement] = []
@export var allies: Array[StoryPlacement] = []
@export var dialogues: Array[StoryDialogue] = []
