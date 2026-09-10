extends SceneTree
## Headless UI audit: loads each top-level UI scene, lets layout settle, then
## reports (a) any pair of visible leaf Controls whose ON-SCREEN rects overlap
## beyond a small tolerance, and (b) whether the KZ/EN translation round-trip
## works. Run with: godot --headless -s res://tools/ui_audit.gd
##
## Two known non-bug patterns are filtered out on purpose:
## - Content clipped by an ancestor ScrollContainer (e.g. a 2nd/3rd grid row
##   that's only reachable by scrolling) is intersected against that
##   ScrollContainer's own rect first, since that's what's actually visible.
## - `flat = true` Buttons are deliberate transparent click-catchers layered
##   over visible sibling content (see codex.gd's card pattern) and are
##   excluded entirely rather than flagged.

const SCENES := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/lobby.tscn",
	"res://scenes/ui/wardrobe.tscn",
	"res://scenes/ui/codex.tscn",
	"res://scenes/ui/settings.tscn",
	"res://scenes/ui/results.tscn",
	"res://scenes/ui/about.tscn",
	"res://scenes/ui/mode_select.tscn",
	"res://scenes/ui/mode_briefing.tscn",
	"res://scenes/ui/abai_says.tscn",
	"res://scenes/ui/togyz_qumalaq.tscn",
	"res://scenes/ui/aq_suyek.tscn",
]

const LEAF_TYPES := ["Button", "CheckButton", "Label", "LineEdit", "HSlider", "TextureRect", "RichTextLabel"]
const TOLERANCE := 2.0

func _init() -> void:
	await process_frame
	await process_frame

	print("\n==================== TRANSLATION CHECK ====================")
	_check_translation()

	print("\n==================== OVERLAP AUDIT ====================")
	for scene_path in SCENES:
		await _audit_scene(scene_path)

	print("\n==================== DONE ====================")
	quit()

func _check_translation() -> void:
	var probe_key := "БАПТАУЛАР"
	TranslationServer.set_locale("kk")
	var kk_result := tr(probe_key)
	TranslationServer.set_locale("en")
	var en_result := tr(probe_key)
	TranslationServer.set_locale("kk")
	var kk_again := tr(probe_key)
	print("kk -> '%s'" % kk_result)
	print("en -> '%s'" % en_result)
	print("kk (again) -> '%s'" % kk_again)
	if kk_result == probe_key and en_result == "SETTINGS" and kk_again == probe_key:
		print("RESULT: PASS - round trip kk -> en -> kk works correctly")
	else:
		print("RESULT: FAIL - see values above")

func _audit_scene(scene_path: String) -> void:
	print("\n--- %s ---" % scene_path)
	var pack := load(scene_path) as PackedScene
	if pack == null:
		print("  ERROR: could not load scene")
		return
	# Брифинг общий для всех режимов и содержание берёт из того, что ему передал
	# экран выбора, — иначе он уйдёт обратно и аудировать будет нечего. Автолоад
	# берём из дерева: по имени он в --script-скрипте ещё не зарегистрирован.
	if scene_path.ends_with("mode_briefing.tscn"):
		root.get_node("/root/SceneRouter").set_pending_briefing("togyz_qumalaq")

	var inst := pack.instantiate()
	root.add_child(inst)
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	await process_frame

	var leaves: Array[Control] = []
	_collect_leaves(inst, leaves)

	var overlap_count := 0
	for i in leaves.size():
		for j in range(i + 1, leaves.size()):
			var a := leaves[i]
			var b := leaves[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			if not a.is_visible_in_tree() or not b.is_visible_in_tree():
				continue
			if _is_click_catcher(a) or _is_click_catcher(b):
				continue
			var ra := _visible_rect(a)
			var rb := _visible_rect(b)
			if ra.size.x <= 0 or ra.size.y <= 0 or rb.size.x <= 0 or rb.size.y <= 0:
				continue  # fully clipped by an ancestor ScrollContainer -> not actually on screen
			var inter := ra.intersection(rb)
			if inter.size.x > TOLERANCE and inter.size.y > TOLERANCE:
				overlap_count += 1
				print("  OVERLAP: [%s]'%s' %s  x  [%s]'%s' %s  (overlap %s)" % [
					a.get_class(), _path_of(a), ra,
					b.get_class(), _path_of(b), rb,
					inter.size,
				])
	print("  leaf controls found: %d, overlaps: %d" % [leaves.size(), overlap_count])
	_report_covered_by_panels(inst, leaves)
	_report_button_contrast(inst)

	root.remove_child(inst)
	inst.queue_free()
	await process_frame

## Второй вид беды: контрол не пересекается с другим контролом, но его накрывает
## панель, нарисованная позже. Так карточка «ОЙЫНҒА» на экране настроек закрывала
## строку статистики соседней карточки, а проверка выше этого не видела — панели
## не листья, и в сравнение не попадали.
func _report_covered_by_panels(root_node: Node, leaves: Array[Control]) -> void:
	var order: Array[Node] = []
	_flatten(root_node, order)

	var covered := 0
	for panel in order:
		if not (panel is PanelContainer or panel is Panel):
			continue
		var panel_ctrl := panel as Control
		if not panel_ctrl.is_visible_in_tree():
			continue
		var panel_rect := panel_ctrl.get_global_rect()
		for leaf in leaves:
			if not leaf.is_visible_in_tree():
				continue
			# Панель поверх собственного содержимого — это норма.
			if panel_ctrl.is_ancestor_of(leaf) or leaf.is_ancestor_of(panel_ctrl):
				continue
			# Накрывает только то, что нарисовано раньше неё.
			if order.find(panel) < order.find(leaf):
				continue
			var inter := panel_rect.intersection(_visible_rect(leaf))
			if inter.size.x > TOLERANCE and inter.size.y > TOLERANCE:
				covered += 1
				print("  COVERED: [%s]'%s' скрыт панелью '%s' (на %s)" % [
					leaf.get_class(), _path_of(leaf), _path_of(panel_ctrl), inter.size,
				])
	print("  controls covered by later panels: %d" % covered)

## Третий вид беды: кнопка переопределяет часть цветов, но не все, и в каком-то
## состоянии текст совпадает с фоном — нажал, и надпись пропала. Тема сама по
## себе согласована, ломают именно точечные theme_override на сценах.
const BUTTON_STATES := [
	["normal", "font_color"],
	["hover", "font_hover_color"],
	["pressed", "font_pressed_color"],
	# Включённый тумблер под курсором. Забыли задать — и Godot берёт из своей
	# дефолтной темы пустой фон с белым текстом, кнопка пропадает.
	["hover_pressed", "font_hover_pressed_color"],
	["disabled", "font_disabled_color"],
]
## Ниже этого отношения яркостей надпись перестаёт читаться. У кнопок шрифт
## крупный, поэтому берём порог мягче рекомендованных для мелкого текста 4.5.
const MIN_CONTRAST := 2.5

func _report_button_contrast(root_node: Node) -> void:
	var order: Array[Node] = []
	_flatten(root_node, order)

	var bad := 0
	for node in order:
		if not (node is Button):
			continue
		var btn := node as Button
		if btn.flat:
			continue  # прозрачные перехватчики кликов, у них надписи нет
		for state in BUTTON_STATES:
			# Тип не указываем намеренно: с явным типом Godot смотрит только в
			# тему и проходит мимо theme_override на самой кнопке — а ломают
			# как раз они.
			var box := btn.get_theme_stylebox(state[0])
			if not (box is StyleBoxFlat):
				# Состояние не описано в теме: сюда подставился чужой стиль, и
				# как кнопка будет выглядеть — уже не наше решение.
				bad += 1
				print("  UNSTYLED: '%s' — состояние %s не задано в теме" % [
					_path_of(btn), state[0]])
				continue
			var flat := box as StyleBoxFlat
			if not flat.draw_center:
				continue  # рамка фокуса, фона у неё нет
			var bg: Color = flat.bg_color
			var fg: Color = btn.get_theme_color(state[1])
			var ratio := _contrast(bg, fg)
			if ratio < MIN_CONTRAST:
				bad += 1
				print("  LOW CONTRAST: '%s' в состоянии %s — текст %s на фоне %s (%.2f)" % [
					_path_of(btn), state[0], fg.to_html(false), bg.to_html(false), ratio,
				])
	print("  buttons with unreadable states: %d" % bad)

func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)

func _channel(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)

func _flatten(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child in node.get_children():
		_flatten(child, out)

func _is_click_catcher(c: Control) -> bool:
	return c is Button and (c as Button).flat

## Rect actually visible on screen: clipped to the nearest ancestor ScrollContainer, if any.
func _visible_rect(c: Control) -> Rect2:
	var rect := c.get_global_rect()
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			rect = rect.intersection((p as Control).get_global_rect())
		p = p.get_parent() if p is Node else null
	return rect

func _collect_leaves(node: Node, out: Array[Control]) -> void:
	if node is Control:
		var is_leaf := true
		for child in node.get_children():
			if child is Control:
				is_leaf = false
				break
		if is_leaf and node.get_class() in LEAF_TYPES:
			out.append(node)
	for child in node.get_children():
		_collect_leaves(child, out)

func _path_of(n: Node) -> String:
	return str(n.get_path()).replace(str(n.get_tree().root.get_path()), "")
