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

	root.remove_child(inst)
	inst.queue_free()
	await process_frame

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
