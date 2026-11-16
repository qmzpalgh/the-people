class_name UI
extends CanvasLayer
## Heads-up display, built entirely in code.

var game
var root: Control
var clock_l: Label
var money_l: Label
var speed_btns: Array = []
var mode_btns := {}
var people_box: HBoxContainer
var name_l: Label
var job_l: Label
var act_l: Label
var queue_box: HBoxContainer
var bars := {}
var mood_bar: ProgressBar
var info_l: Label
var side: PanelContainer
var side_box: VBoxContainer
var msg_box: VBoxContainer
var menu: PopupMenu
var menu_calls: Array = []
var will_btn: CheckButton
var _queue_sig := ""
var _people_sig := ""


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top-left: clock, speed, money.
	var top := _panel(Control.PRESET_TOP_LEFT, Vector2(10, 10))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	top.add_child(th)
	clock_l = _label(th, "", 20)
	clock_l.custom_minimum_size.x = 170
	var names := ["Pause", "Play", "Fast", "Faster"]
	for i in 4:
		var b := _btn(th, names[i], game.set_speed.bind(i))
		b.toggle_mode = true
		speed_btns.append(b)
	money_l = _label(th, "", 20)
	money_l.custom_minimum_size.x = 100

	# Top-right: modes and options.
	var tr := _panel(Control.PRESET_TOP_RIGHT, Vector2(-10, 10))
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var trh := HBoxContainer.new()
	trh.add_theme_constant_override("separation", 8)
	tr.add_child(trh)
	for m in ["live", "buy", "build"]:
		var b := _btn(trh, m.capitalize(), game.set_mode.bind(m))
		b.toggle_mode = true
		mode_btns[m] = b
	_btn(trh, "Walls (F)", game.toggle_walls)
	will_btn = CheckButton.new()
	will_btn.text = "Free will"
	will_btn.button_pressed = true
	will_btn.focus_mode = Control.FOCUS_NONE
	will_btn.toggled.connect(func(on): game.free_will = on)
	trh.add_child(will_btn)

	# Bottom-left: household and selected person.
	var bl := _panel(Control.PRESET_BOTTOM_LEFT, Vector2(10, -10))
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	bl.add_child(bv)
	people_box = HBoxContainer.new()
	bv.add_child(people_box)
	name_l = _label(bv, "", 20)
	job_l = _label(bv, "", 14)
	act_l = _label(bv, "", 14)
	queue_box = HBoxContainer.new()
	queue_box.custom_minimum_size.y = 32
	bv.add_child(queue_box)
	var mh := HBoxContainer.new()
	bv.add_child(mh)
	_label(mh, "Mood", 14).custom_minimum_size.x = 70
	mood_bar = _bar(mh, 330)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	bv.add_child(grid)
	for n in Defs.NEEDS:
		_label(grid, Defs.NEED_NAMES[n], 14).custom_minimum_size.x = 62
		bars[n] = _bar(grid, 130)
	info_l = _label(bv, "", 13)

	# Right: catalog / build tools.
	side = _panel(Control.PRESET_CENTER_RIGHT, Vector2(-10, 0))
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 620)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sc)
	side_box = VBoxContainer.new()
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(side_box)

	# Messages.
	msg_box = VBoxContainer.new()
	msg_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_box.position = Vector2(-260, 64)
	msg_box.custom_minimum_size.x = 520
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg_box)

	# Help.
	var help := _label(root, "WASD pan · Q/E rotate · wheel zoom · middle-drag orbit · click object/person: interact\nright-click: go here / cancel tool · Tab: next person · Space: pause · 1-3: speed · R: rotate · F: walls", 12)
	help.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_left = -10
	help.offset_right = -10
	help.offset_top = -8
	help.offset_bottom = -8
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 4)

	menu = PopupMenu.new()
	menu.id_pressed.connect(func(id): if id >= 0 and id < menu_calls.size(): menu_calls[id].call())
	add_child(menu)
	build_side()


func _panel(preset: int, offset: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(preset)
	p.position = offset
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16, 0.86)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	root.add_child(p)
	return p


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _bar(parent: Node, width: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(width, 16)
	b.show_percentage = false
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color.WHITE
	fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b


func _set_bar(b: ProgressBar, v: float) -> void:
	b.value = v
	var c := Color(0.9, 0.25, 0.2).lerp(Color(0.95, 0.8, 0.2), clampf(v / 50.0, 0, 1))
	if v > 50.0:
		c = Color(0.95, 0.8, 0.2).lerp(Color(0.3, 0.8, 0.35), (v - 50.0) / 50.0)
	b.get_theme_stylebox("fill").bg_color = c


func push_msg(text: String) -> void:
	if msg_box == null:
		return
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_box.add_child(l)
	if msg_box.get_child_count() > 5:
		msg_box.get_child(0).queue_free()
	get_tree().create_timer(7.0).timeout.connect(func(): if is_instance_valid(l): l.queue_free())


func show_menu(title: String, items: Array, pos: Vector2) -> void:
	menu.clear()
	menu_calls.clear()
	menu.add_item(title, 999)
	menu.set_item_disabled(0, true)
	if items.is_empty():
		menu.add_item("(nothing to do here)", 998)
		menu.set_item_disabled(1, true)
	for i in items.size():
		menu.add_item(items[i][0], i)
		menu_calls.append(items[i][1])
	menu.reset_size()
	menu.position = Vector2i(pos)
	menu.popup()


func build_side() -> void:
	if side_box == null:
		return
	for c in side_box.get_children():
		c.queue_free()
	side.visible = game.mode != "live"
	if game.mode == "buy":
		_label(side_box, "Buy mode", 18)
		var sb := _btn(side_box, "Sell tool (70% refund)", func(): game.set_buy(""); game.sell = true)
		sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for cat in Defs.CATS:
			_label(side_box, cat, 14).add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
			for k in Defs.OBJECTS:
				var d: Dictionary = Defs.OBJECTS[k]
				if d["cat"] == cat:
					var b := _btn(side_box, "%s   $%d" % [d["name"], d["price"]], game.set_buy.bind(k))
					b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	elif game.mode == "build":
		_label(side_box, "Build mode", 18)
		var tools := [["wall", "Wall (drag)   $%d" % Defs.WALL_PRICE], ["door", "Door (click wall)   $%d" % Defs.DOOR_PRICE],
			["window", "Window (click wall)   $%d" % Defs.WINDOW_PRICE], ["erase", "Remove wall (drag)"]]
		for t in tools:
			_btn(side_box, t[1], func(): game.tool = t[0]).alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label(side_box, "Floors (click / drag)", 14).add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		for i in Defs.FLOORS.size():
			var f: Dictionary = Defs.FLOORS[i]
			var text := "Remove floor" if i == 0 else "%s   $%d" % [f["name"], f["price"]]
			_btn(side_box, text, func(): game.tool = "floor:%d" % i).alignment = HORIZONTAL_ALIGNMENT_LEFT


func refresh() -> void:
	var h: float = game.hour()
	clock_l.text = "Day %d  %s  %02d:%02d" % [game.day + 1, Defs.DAYS[game.day % 7], int(h), int(fmod(h, 1.0) * 60.0)]
	money_l.text = "$%d" % game.money
	money_l.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if game.money < 0 else Color(0.6, 1, 0.6))
	for i in 4:
		speed_btns[i].set_pressed_no_signal(game.speed == i)
	for m in mode_btns:
		mode_btns[m].set_pressed_no_signal(game.mode == m)

	var psig := ""
	for p in game.people:
		psig += p.pname + str(p == game.selected) + str(p.away)
	if psig != _people_sig:
		_people_sig = psig
		for c in people_box.get_children():
			c.queue_free()
		for p in game.people:
			var b := _btn(people_box, p.first() + (" (work)" if p.away else ""), game.select.bind(p))
			b.toggle_mode = true
			b.button_pressed = p == game.selected
			var sw := StyleBoxFlat.new()
			sw.bg_color = p.shirt
			sw.set_corner_radius_all(4)
			sw.set_content_margin_all(6)
			b.add_theme_stylebox_override("pressed", sw)

	var s: Person = game.selected
	if s == null:
		return
	name_l.text = s.pname
	if s.job != null:
		var c: Dictionary = Defs.CAREERS[s.job.career]
		job_l.text = "%s · %s · $%d/day · %d:00-%d:00 Mon-Fri · performance %d%%" % [c["name"], c["titles"][s.job.level],
			c["pay"][s.job.level], int(c["start"]), int(c["start"] + c["hours"]), int(clampf(s.job.perf, 0, 100))]
	else:
		job_l.text = "Unemployed (use a computer to find a job)"
	act_l.text = "Doing: " + s.activity()
	var labels := []
	if s.cur != null and not s.away:
		labels.append(s.cur.label)
	for a in s.queue:
		labels.append(a.label)
	var qsig := s.pname + "|".join(labels)
	if qsig != _queue_sig:
		_queue_sig = qsig
		for c in queue_box.get_children():
			c.queue_free()
		for i in labels.size():
			var b := _btn(queue_box, labels[i] + "  x", game.cancel_action.bind(s, i))
			b.add_theme_font_size_override("font_size", 12)
			b.tooltip_text = "Cancel"
	_set_bar(mood_bar, s.mood())
	for n in Defs.NEEDS:
		_set_bar(bars[n], s.needs[n])
	var sk := []
	for k in Defs.SKILLS:
		sk.append("%s %d" % [k.capitalize(), int(s.skills[k])])
	var rl := []
	for p in game.people:
		if p != s:
			rl.append("%s %+d" % [p.first(), int(game.get_rel(s, p))])
	var tr := []
	for t in Defs.TRAITS:
		tr.append("%s %d" % [t.capitalize(), s.traits[t]])
	info_l.text = "Skills: %s\nTraits: %s\nRelationships: %s" % [", ".join(sk), ", ".join(tr), ", ".join(rl)]
