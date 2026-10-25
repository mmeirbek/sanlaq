extends StoryTaskRunner
## «Жау ізін табу»: стрелок нет, только «алыс / жылы / ыстық» на баннере — это
## и есть поиск (в atilla стрелки вели прямо к цели). След виден вблизи.

const VISIBLE_METERS := 6.0
const WARM_METERS := 14.0
const FOUND_METERS := 2.2

var _target: Node2D
var _distance := 99.0


func picture_name() -> String:
	return "tracks"


func setup() -> void:
	_target = spawn("tracks", task.points[0])
	_target.visible = false


func status() -> String:
	if _distance < VISIBLE_METERS:
		return tr("ЫСТЫҚ! ІЗ КӨРІНДІ")
	if _distance < WARM_METERS:
		return tr("ЖЫЛЫ")
	return tr("СУЫҚ")


func tick(_delta: float) -> void:
	var before := status()
	_distance = flat_distance(_target.position, player.position)
	_target.visible = _distance < VISIBLE_METERS
	if status() != before:
		report()
	if _distance < FOUND_METERS:
		celebrate(_target.position, tr("ТАБЫЛДЫ: %s") % tr(task.item_label))
		finish()
