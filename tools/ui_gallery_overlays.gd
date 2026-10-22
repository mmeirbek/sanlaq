extends Control
## Витрина накладных компонентов: шапка с тостом, обратный отсчёт, баннер и
## диалог. Каждый — в своей четверти экрана, чтобы не закрывать друг друга.

## Сколько держать показ: витрина снимается одним кадром.
const HOLD := 60.0


func _ready() -> void:
	var background := ColorRect.new()
	background.color = UiTokens.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", UiTokens.PIXEL)
	grid.add_theme_constant_override("v_separation", UiTokens.PIXEL)
	add_child(grid)

	var header_cell := _cell(grid)
	var header := ScreenHeader.new()
	header.title = "РЕЖИМДЕР"
	header.subtitle = "РЕЖИМДІ ТАҢДА · ОЙЫНДЫ БАСТА"
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, UiTokens.SPACE_S)
	header_cell.add_child(header)
	var toast := Toast.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, UiTokens.SPACE_M)
	header_cell.add_child(toast)
	toast.show_message("Сізді ұстады! Киім: Бөрік", HOLD)

	var countdown := Countdown.new()
	countdown.step_time = HOLD
	_cell(grid).add_child(countdown)
	countdown.start(3)

	var banner := Banner.new()
	_cell(grid).add_child(banner)
	banner.show_banner("ЖЕҢІС!", "Барлық қашқын ұсталды", HOLD)

	var dialog := ConfirmDialog.new()
	dialog.dialog_title = "ШЫҒУ"
	dialog.dialog_message = "Ойыннан шығасыз ба?"
	_cell(grid).add_child(dialog)
	dialog.open()


func _cell(grid: GridContainer) -> Control:
	var cell := Control.new()
	cell.clip_contents = true
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tint := ColorRect.new()
	tint.color = UiTokens.BURGUNDY_DARK
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cell.add_child(tint)
	grid.add_child(cell)
	return cell
