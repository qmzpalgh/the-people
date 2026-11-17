class_name UI
extends CanvasLayer
## Heads-up display, built in code. Quiet by default: the clock, the household and one
## line about the selected person. Needs, details, catalogues and controls open on demand.

const INK := Color("23303a")
const PAPER := Color(0.97, 0.975, 0.965, 0.95)
const GOLD := Color("f2b01e")
const GOOD := Color("3fa66b")
const WARN := Color("e0533d")
const MUTED := Color("7c8a93")

const ALERTS := {
	"hunger": "Hungry", "energy": "Tired", "hygiene": "Needs a wash", "bladder": "Needs the toilet",
	"fun": "Bored", "social": "Lonely", "comfort": "Uncomfortable", "room": "Dislikes this room",
}
const SPEED_TEXT := ["II", ">", ">>", ">>>"]
const SPEED_TIP := ["Pause (Space)", "Play (1)", "Fast (2)", "Faster (3)"]
const CONTROLS := [
	["Click an object or person", "Choose what to do"], ["Right-click the ground", "Walk there"],
	["Right-click or Esc", "Put the current tool away"], ["W A S D", "Move the camera"],
	["Q / E, middle-drag", "Turn the camera"], ["Mouse wheel", "Zoom"], ["Tab", "Next household member"],
	["Space, 1 2 3", "Pause and speed"], ["R", "Rotate furniture"], ["F", "Walls up or down"],
	["F5 / F9", "Save / load"], ["H", "Show or hide this list"],
]

var game
var root: Control
var clock_l: Label
var money_l: Label
var speed_btns: Array = []
var mode_btns := {}
var chips_box: HBoxContainer
var name_l: Label
var act_l: Label
var mood_bar: ProgressBar
var alerts: HFlowContainer
var queue_box: HFlowContainer
var needs_box: GridContainer
var bars := {}
var stage_box: HBoxContainer
var work_box: VBoxContainer
var work_l: Array = []  # title, detail, next step, needs
var perf_row: HBoxContainer
var perf_bar: ProgressBar
var skills_box: GridContainer
var skill_rows := {}  # skill -> [name, career dot, level, bar]
var traits_box: GridContainer
var trait_marks := {}  # trait -> marker
var people_scroll: ScrollContainer
var people_list: VBoxContainer
var people_rows: Array = []  # [person, fill, word]
var tab_btns := {}
var card_tab := ""
var side: PanelContainer
var side_title: Label
var cat_box: HFlowContainer
var list_box: VBoxContainer
var hint_l: Label
var item_btns := {}
var tool_btns := {}
var cat := "Seating"
var build_tab := "Walls"
var toasts: VBoxContainer
var menu: PopupMenu
var menu_calls: Array = []
var opt_menu: PopupMenu
var help_panel: PanelContainer
var over_panel: PanelContainer
var _sig := {}


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	# Clock, speed, money.
	var top := PanelContainer.new()
	_place(top, Control.PRESET_TOP_LEFT, 12, 12)
	var th := _hbox(top, 10)
	clock_l = _label(th, "", 15)
	clock_l.custom_minimum_size.x = 132
	var sp := _hbox(th, 2)
	for i in 4:
		var b := _seg(sp, SPEED_TEXT[i], game.set_speed.bind(i))
		b.tooltip_text = SPEED_TIP[i]
		b.custom_minimum_size.x = 34
		speed_btns.append(b)
	money_l = _label(th, "", 15)
	money_l.custom_minimum_size.x = 64
	money_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Modes and the options menu.
	var tr := PanelContainer.new()
	_place(tr, Control.PRESET_TOP_RIGHT, -12, 12)
	var trh := _hbox(tr, 2)
	for m in ["live", "buy", "build"]:
		mode_btns[m] = _seg(trh, m.capitalize(), game.set_mode.bind(m))
	var mb := _btn(trh, "Menu", _open_options)
	mb.add_theme_color_override("font_color", MUTED)

	# Household and the selected person.
	var bl := VBoxContainer.new()
	bl.add_theme_constant_override("separation", 8)
	_place(bl, Control.PRESET_BOTTOM_LEFT, 12, -12)
	chips_box = _hbox(bl, 6)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 300
	bl.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	# The stage chip drops under the name when both don't fit on one line.
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 8)
	head.add_theme_constant_override("v_separation", 2)
	cv.add_child(head)
	name_l = _label(head, "", 17)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_box = _hbox(head, 0)
	stage_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act_l = _label(cv, "", 13)
	act_l.add_theme_color_override("font_color", MUTED)
	mood_bar = _bar(cv, 0, 6)
	mood_bar.tooltip_text = "Mood"
	alerts = HFlowContainer.new()
	cv.add_child(alerts)
	queue_box = HFlowContainer.new()
	cv.add_child(queue_box)
	var tabs := _hbox(cv, 2)
	for t in CARD_TABS:
		tab_btns[t] = _tab(tabs, t)
	needs_box = GridContainer.new()
	needs_box.columns = 4
	needs_box.add_theme_constant_override("h_separation", 8)
	needs_box.add_theme_constant_override("v_separation", 5)
	cv.add_child(needs_box)
	for n in Defs.NEEDS:
		var l := _label(needs_box, Defs.NEED_NAMES[n], 13)
		l.custom_minimum_size.x = 58
		bars[n] = _bar(needs_box, 84, 8)
	_build_work(cv)
	_build_skills(cv)
	_build_traits(cv)
	_build_people(cv)

	# Catalogue and build tools.
	side = PanelContainer.new()
	_place(side, Control.PRESET_CENTER_RIGHT, -12, 0)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sv.custom_minimum_size.x = 236
	side.add_child(sv)
	side_title = _label(sv, "", 17)
	cat_box = HFlowContainer.new()
	sv.add_child(cat_box)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 300
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 2)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)
	hint_l = _label(sv, "", 13)
	hint_l.add_theme_color_override("font_color", MUTED)
	hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	toasts = VBoxContainer.new()
	toasts.add_theme_constant_override("separation", 6)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(toasts, Control.PRESET_CENTER_TOP, 0, 64)

	# Controls overlay.
	help_panel = PanelContainer.new()
	_place(help_panel, Control.PRESET_CENTER, 0, 0)
	help_panel.visible = false
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	help_panel.add_child(hv)
	_label(hv, "Controls", 17)
	var hg := GridContainer.new()
	hg.columns = 2
	hg.add_theme_constant_override("h_separation", 24)
	hg.add_theme_constant_override("v_separation", 6)
	hv.add_child(hg)
	var rows := CONTROLS.duplicate()
	if Sfx.ENABLED:
		rows.insert(rows.size() - 1, ["M", "Sound on or off"])
	for row in rows:
		_label(hg, row[0], 14)
		_label(hg, row[1], 14).add_theme_color_override("font_color", MUTED)
	_btn(hv, "Close", toggle_help).size_flags_horizontal = Control.SIZE_SHRINK_END

	menu = PopupMenu.new()
	menu.theme = root.theme
	menu.id_pressed.connect(func(id):
		if id >= 0 and id < menu_calls.size():
			game.sfx.play("click")
			menu_calls[id].call())
	add_child(menu)
	opt_menu = PopupMenu.new()
	opt_menu.theme = root.theme
	opt_menu.id_pressed.connect(_on_option)
	add_child(opt_menu)
	build_side()


# ---------------------------------------------------------------- building blocks

func _sb(c: Color, radius := 8, mh := 10, mv := 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = mh
	s.content_margin_right = mh
	s.content_margin_top = mv
	s.content_margin_bottom = mv
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Nunito", "Quicksand", "Cantarell", "Noto Sans", "sans-serif"])
	t.default_font = f
	t.default_font_size = 14
	t.set_color("font_color", "Label", INK)
	var clear := _sb(Color(0, 0, 0, 0))
	t.set_stylebox("normal", "Button", clear)
	t.set_stylebox("disabled", "Button", clear)
	t.set_stylebox("hover", "Button", _sb(Color(INK, 0.08)))
	t.set_stylebox("pressed", "Button", _sb(Color(INK, 0.14)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	var panel := _sb(PAPER, 14, 14, 12)
	panel.shadow_color = Color(0, 0, 0, 0.2)
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0, 3)
	t.set_stylebox("panel", "PanelContainer", panel)
	var pop := _sb(PAPER, 10, 6, 6)
	pop.shadow_color = Color(0, 0, 0, 0.2)
	pop.shadow_size = 10
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", _sb(Color(GOLD, 0.35), 6))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_color("font_disabled_color", "PopupMenu", MUTED)
	t.set_constant("v_separation", "PopupMenu", 8)
	t.set_constant("item_start_padding", "PopupMenu", 10)
	t.set_constant("item_end_padding", "PopupMenu", 10)
	t.set_stylebox("panel", "TooltipPanel", _sb(INK, 6, 8, 4))
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	return t


func _place(c: Control, preset: int, dx: float, dy: float) -> void:
	root.add_child(c)
	c.set_anchors_preset(preset)
	c.grow_horizontal = Control.GROW_DIRECTION_END
	c.grow_vertical = Control.GROW_DIRECTION_END
	match preset:
		Control.PRESET_TOP_RIGHT:
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_LEFT:
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_RIGHT:
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			c.grow_vertical = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER_TOP:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
		Control.PRESET_CENTER:
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.offset_left = dx
	c.offset_right = dx
	c.offset_top = dy
	c.offset_bottom = dy


func _hbox(parent: Node, sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h


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
	b.pressed.connect(func():
		game.sfx.play("click")
		cb.call())
	parent.add_child(b)
	return b


## A toggle that fills with ink when it is the active choice.
func _seg(parent: Node, text: String, cb: Callable) -> Button:
	var b := _btn(parent, text, cb)
	b.toggle_mode = true
	b.add_theme_stylebox_override("pressed", _sb(INK))
	b.add_theme_stylebox_override("hover_pressed", _sb(INK))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	return b


func _bar(parent: Node, width: float, height: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(width, height)
	b.show_percentage = false
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("background", _sb(Color(INK, 0.1), 4, 0, 0))
	b.add_theme_stylebox_override("fill", _sb(GOOD, 4, 0, 0))
	parent.add_child(b)
	return b


func _set_bar(b: ProgressBar, v: float) -> void:
	b.value = v
	var c := WARN.lerp(GOLD, clampf(v / 45.0, 0.0, 1.0))
	if v > 45.0:
		c = GOLD.lerp(GOOD, clampf((v - 45.0) / 30.0, 0.0, 1.0))
	b.get_theme_stylebox("fill").bg_color = c


func _chip(parent: Node, text: String, c: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color(c, 0.16), 9, 8, 2))
	var l := _label(p, text, 12)
	l.add_theme_color_override("font_color", c.darkened(0.15))
	parent.add_child(p)


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _changed(key: String, value: String) -> bool:
	if _sig.get(key, "") == value:
		return false
	_sig[key] = value
	return true


# ---------------------------------------------------------------- messages and menus

func push_msg(text: String) -> void:
	if toasts == null:
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PAPER, 10, 12, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := _label(p, text, 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if text.length() > 60:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400
	toasts.add_child(p)
	while toasts.get_child_count() > 3:
		var old := toasts.get_child(0)
		toasts.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func show_menu(title: String, items: Array, pos: Vector2) -> void:
	menu.clear()
	menu_calls.clear()
	menu.add_item(title, 999)
	menu.set_item_disabled(0, true)
	if items.is_empty():
		menu.add_item("Nothing to do here", 998)
		menu.set_item_disabled(1, true)
	for i in items.size():
		menu.add_item(items[i][0], i)
		menu_calls.append(items[i][1])
	menu.reset_size()
	menu.position = Vector2i(pos)
	menu.popup()


func _open_options() -> void:
	opt_menu.clear()
	opt_menu.add_check_item("Walls up", 0)
	opt_menu.set_item_checked(0, game.world.walls_up)
	opt_menu.add_check_item("Free will", 1)
	opt_menu.set_item_checked(1, game.free_will)
	if Sfx.ENABLED:
		opt_menu.add_check_item("Sound", 2)
		opt_menu.set_item_checked(opt_menu.get_item_index(2), not game.sfx.muted)
	opt_menu.add_separator()
	opt_menu.add_item("Save", 3)
	opt_menu.add_item("Load last save", 4)
	opt_menu.add_item("Start a new household", 5)
	opt_menu.add_separator()
	opt_menu.add_item("Controls", 6)
	opt_menu.reset_size()
	var vp := root.get_viewport_rect().size
	opt_menu.position = Vector2i(int(vp.x) - opt_menu.size.x - 12, 60)
	opt_menu.popup()


func _on_option(id: int) -> void:
	game.sfx.play("click")
	match id:
		0: game.toggle_walls()
		1: game.free_will = not game.free_will
		2: game.sfx.set_muted(not game.sfx.muted)
		3: game.save_game()
		4: game.load_game()
		5: game.new_game()
		6: toggle_help()


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func show_game_over() -> void:
	if over_panel != null:
		return
	over_panel = PanelContainer.new()
	_place(over_panel, Control.PRESET_CENTER, 0, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	over_panel.add_child(v)
	_label(v, "The %s household has come to an end." % game.family, 20)
	_label(v, "Their story lasted %d days. The house stands empty now." % (game.day + 1), 14).add_theme_color_override("font_color", MUTED)
	var h := _hbox(v, 6)
	var nb := _seg(h, "Start a new household", game.new_game)
	nb.button_pressed = true
	_btn(h, "Load last save", game.load_game)


func debug_open(what: String) -> void:
	card_tab = "needs" if what.contains("needs") else ""
	for t in CARD_TABS:
		if what.contains("tab:" + t):
			card_tab = t
	# pick:<n> selects the n-th household member, counting from 1.
	var pick := what.find("pick:")
	if pick >= 0:
		var n := what.substr(pick + 5, 1).to_int() - 1
		if n >= 0 and n < game.people.size():
			game.select(game.people[n])
	if what.contains("help"):
		toggle_help()
	if what.contains("floors"):
		build_tab = "Floors"
		build_side()
	if what.contains("options"):
		_open_options.call_deferred()


# ---------------------------------------------------------------- side panel

func build_side() -> void:
	if side == null:
		return
	_clear(cat_box)
	_clear(list_box)
	item_btns.clear()
	tool_btns.clear()
	side.visible = game.mode != "live"
	if game.mode == "buy":
		side_title.text = "Furnish"
		for c in Defs.CATS:
			var b := _seg(cat_box, c, _pick_cat.bind(c))
			b.button_pressed = c == cat and not game.sell
			b.add_theme_font_size_override("font_size", 13)
		var sb := _seg(cat_box, "Sell", _pick_sell)
		sb.button_pressed = game.sell
		sb.add_theme_font_size_override("font_size", 13)
		sb.add_theme_color_override("font_color", WARN)
		if not game.sell:
			for k in Defs.OBJECTS:
				var d: Dictionary = Defs.OBJECTS[k]
				if d["cat"] == cat:
					item_btns[k] = _row(d["name"], "$%d" % d["price"], game.set_buy.bind(k))
	elif game.mode == "build":
		side_title.text = "Build"
		for c in ["Walls", "Floors"]:
			var b := _seg(cat_box, c, _pick_tab.bind(c))
			b.button_pressed = c == build_tab
		if build_tab == "Walls":
			tool_btns["wall"] = _row("Wall", "$%d" % Defs.WALL_PRICE, _pick_tool.bind("wall"))
			tool_btns["door"] = _row("Door", "$%d" % Defs.DOOR_PRICE, _pick_tool.bind("door"))
			tool_btns["window"] = _row("Window", "$%d" % Defs.WINDOW_PRICE, _pick_tool.bind("window"))
			tool_btns["erase"] = _row("Remove wall", "", _pick_tool.bind("erase"))
		else:
			for i in range(1, Defs.FLOORS.size()):
				var f: Dictionary = Defs.FLOORS[i]
				tool_btns["floor:%d" % i] = _row(f["name"], "$%d" % f["price"], _pick_tool.bind("floor:%d" % i), f["tint"])
			tool_btns["floor:0"] = _row("Remove floor", "", _pick_tool.bind("floor:0"))


func _row(text: String, right: String, cb: Callable, swatch = null) -> Button:
	var b := _seg(list_box, text, cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if swatch != null:
		var sw := ColorRect.new()
		sw.color = swatch
		sw.custom_minimum_size = Vector2(14, 14)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(sw)
		sw.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		sw.offset_left = 10
		sw.offset_right = 24
		sw.offset_top = -7
		sw.offset_bottom = 7
		b.text = "      " + text
	if right != "":
		var l := _label(b, right, 13)
		l.add_theme_color_override("font_color", MUTED)
		l.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		l.grow_vertical = Control.GROW_DIRECTION_BOTH
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.offset_left = -10
		l.offset_right = -10
		l.offset_top = -10
		l.offset_bottom = 10
	return b


func _pick_cat(c: String) -> void:
	cat = c
	game.set_buy("")
	build_side()


func _pick_sell() -> void:
	game.set_buy("")
	game.sell = true
	build_side()


func _pick_tab(c: String) -> void:
	build_tab = c
	game.tool = ""
	build_side()


func _pick_tool(t: String) -> void:
	game.tool = "" if game.tool == t else t


func _hint() -> String:
	if game.mode == "buy":
		if game.sell:
			return "Click an object to sell it for 70% of its price."
		if game.buy_kind == "":
			return "Pick something to place."
		if game.money < Defs.OBJECTS[game.buy_kind]["price"]:
			return "The household can't afford this yet."
		return "Click to place it. R rotates. Right-click puts it back."
	match game.tool:
		"": return "Pick a tool."
		"wall": return "Drag along the grid to raise walls."
		"erase": return "Drag along a wall to take it down."
		"door": return "Click a wall to put a door in it."
		"window": return "Click a wall to put a window in it."
	return "Click or drag over tiles to lay this floor."


# ---------------------------------------------------------------- per-frame refresh

func refresh() -> void:
	var h: float = game.hour()
	clock_l.text = "%s %02d:%02d" % [Defs.DAYS[game.day % 7], int(h), int(fmod(h, 1.0) * 60.0)]
	clock_l.tooltip_text = "Day %d" % (game.day + 1)
	money_l.text = "$%d" % game.money
	money_l.add_theme_color_override("font_color", WARN if game.money < 0 else INK)
	for i in 4:
		speed_btns[i].set_pressed_no_signal(game.speed == i)
	for m in mode_btns:
		mode_btns[m].set_pressed_no_signal(game.mode == m)
	if side.visible:
		for k in item_btns:
			item_btns[k].set_pressed_no_signal(game.buy_kind == k)
			item_btns[k].disabled = Defs.OBJECTS[k]["price"] > game.money
		for k in tool_btns:
			tool_btns[k].set_pressed_no_signal(game.tool == k)
		hint_l.text = _hint()
	_refresh_chips()
	_refresh_card()


func _refresh_chips() -> void:
	var guests: Array = game.neighbours.filter(func(n): return n.vstate in ["waiting", "guest"])
	var sig := ""
	for p in game.people + guests:
		sig += "%d%s%s%s|" % [p.pid, p == game.selected, p.away, p.stage()]
	if not _changed("chips", sig):
		return
	_clear(chips_box)
	for p in game.people + guests:
		var b := _btn(chips_box, p.first().substr(0, 1), game.select.bind(p) if p.resident else func(): pass)
		var d := 30 if p.stage() == "child" else 38
		b.custom_minimum_size = Vector2(d, d)
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.tooltip_text = p.pname if p.resident else "%s (visiting)" % p.pname
		var s := _sb(p.shirt if p.resident else PAPER, d / 2, 0, 0)
		if p == game.selected:
			s.set_border_width_all(3)
			s.border_color = GOLD
		elif not p.resident:
			s.set_border_width_all(2)
			s.border_color = p.shirt
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, s)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color.WHITE if p.resident else INK)
		b.modulate.a = 0.45 if p.away else 1.0


func _refresh_card() -> void:
	var s: Person = game.selected
	if s == null or not is_instance_valid(s):
		return
	name_l.text = s.pname
	if _changed("stage", _stage_words(s)):
		_clear(stage_box)
		_chip(stage_box, _sig["stage"], MUTED)
	act_l.text = s.activity()
	_set_bar(mood_bar, s.mood())
	for t in tab_btns:
		tab_btns[t].set_pressed_no_signal(t == card_tab)
	needs_box.visible = card_tab == "needs"
	work_box.visible = card_tab == "work"
	skills_box.visible = card_tab == "skills"
	traits_box.visible = card_tab == "traits"
	people_scroll.visible = card_tab == "people"

	# Only the needs that want attention surface on their own.
	var low := []
	if card_tab != "needs" and not s.away:
		for n in Defs.NEEDS:
			if s.needs[n] < 30.0:
				low.append(n)
	alerts.visible = not low.is_empty()
	if _changed("alerts", ",".join(low)):
		_clear(alerts)
		for n in low:
			_chip(alerts, ALERTS[n], WARN)

	var labels := []
	if not s.away and (not s.queue.is_empty() or (s.cur != null and not s.cur.get("auto", false))):
		if s.cur != null:
			labels.append(s.cur.label)
		for a in s.queue:
			labels.append(a.label)
	queue_box.visible = not labels.is_empty()
	if _changed("queue", s.pname + "|".join(labels)):
		_clear(queue_box)
		for i in labels.size():
			var b := _btn(queue_box, labels[i] + "  ×", game.cancel_action.bind(s, i))
			b.add_theme_font_size_override("font_size", 12)
			b.add_theme_stylebox_override("normal", _sb(Color(INK, 0.07), 9, 8, 2))
			b.tooltip_text = "Cancel"

	if card_tab == "needs":
		for n in Defs.NEEDS:
			_set_bar(bars[n], s.needs[n])
	if work_box.visible:
		_refresh_work(s)
	if skills_box.visible:
		_refresh_skills(s)
	if traits_box.visible:
		_refresh_traits(s)
	if people_scroll.visible:
		_refresh_people(s)


# ---------------------------------------------------------------- person card tabs

## One block of the card is open at a time, or none. "" means the card is closed.
const CARD_TABS := ["needs", "work", "skills", "traits", "people"]


func _tab(parent: Node, t: String) -> Button:
	var b := _seg(parent, t.capitalize(), _pick_card_tab.bind(t))
	b.add_theme_font_size_override("font_size", 13)
	# Slimmer than a standard button, so all five fit the card at its narrowest.
	b.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), 8, 8))
	b.add_theme_stylebox_override("hover", _sb(Color(INK, 0.08), 8, 8))
	for st in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, _sb(INK, 8, 8))
	return b


func _pick_card_tab(t: String) -> void:
	card_tab = "" if card_tab == t else t


## The life stage and age, for the chip beside the name.
func _stage_words(s: Person) -> String:
	match s.stage():
		"child":
			var left := ceili(Defs.CHILD_DAYS - s.age)
			return "Child, grows up in %d %s" % [left, "day" if left == 1 else "days"]
		"elder":
			return "Elder, day %d" % int(s.age)
	return "Adult, day %d" % int(s.age)


# ---------------------------------------------------------------- work tab

func _build_work(parent: Node) -> void:
	work_box = VBoxContainer.new()
	work_box.add_theme_constant_override("separation", 4)
	parent.add_child(work_box)
	work_l.append(_label(work_box, "", 14))
	work_l.append(_label(work_box, "", 13))
	work_l[1].add_theme_color_override("font_color", MUTED)
	perf_row = _hbox(work_box, 8)
	_label(perf_row, "Performance", 13)
	perf_bar = _bar(perf_row, 0, 8)
	perf_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perf_bar.tooltip_text = "Full performance and enough skill earn a promotion."
	work_l.append(_label(work_box, "", 13))
	work_l.append(_label(work_box, "", 13))
	work_l[3].add_theme_color_override("font_color", MUTED)


## Title, detail, next step and what it needs, for the work tab.
func _work_lines(s: Person) -> Array:
	if s.job == null:
		if s.stage() == "child":
			return ["At school", "%d:00 to %d:00 on weekdays" % [int(Defs.SCHOOL["start"]), int(Defs.SCHOOL["start"] + Defs.SCHOOL["hours"])],
				"", "Each school day adds a little Logic."]
		if s.stage() == "elder":
			return ["Retired", "A pension of $%d a day." % Defs.PENSION, "", ""]
		return ["No job yet", "A computer can find one.", "", ""]
	var c: Dictionary = Defs.CAREERS[s.job.career]
	var lv: int = s.job.level
	var lines := ["%s, %s" % [c["titles"][lv], c["name"]],
		"$%d a day, %d:00 to %d:00 on weekdays" % [c["pay"][lv], int(c["start"]), int(c["start"] + c["hours"])]]
	if lv >= 4:
		return lines + ["Top of the career. There is nothing higher.", ""]
	lines.append("Next: " + c["titles"][lv + 1])
	var need := (lv + 1) * 2
	var has: float = s.skills[c["skill"]]
	var skill := "%s %d" % [c["skill"].capitalize(), need]
	var full: bool = s.job.perf >= 100.0
	if has < need and full:
		lines.append("Needs %s (has %d)" % [skill, int(has)])
	elif has < need:
		lines.append("Needs %s and full performance" % skill)
	elif not full:
		lines.append("Needs full performance")
	else:
		lines.append("Due after the next workday")
	return lines


func _refresh_work(s: Person) -> void:
	var lines := _work_lines(s)
	for i in work_l.size():
		work_l[i].text = lines[i]
		work_l[i].visible = lines[i] != ""
	perf_row.visible = s.job != null
	if s.job != null:
		perf_bar.value = clampf(s.job.perf, 0.0, 100.0)


# ---------------------------------------------------------------- skills tab

func _build_skills(parent: Node) -> void:
	skills_box = GridContainer.new()
	skills_box.columns = 3
	skills_box.add_theme_constant_override("h_separation", 8)
	skills_box.add_theme_constant_override("v_separation", 5)
	parent.add_child(skills_box)
	for k in Defs.SKILLS:
		var cell := _hbox(skills_box, 5)
		cell.custom_minimum_size.x = 92
		var nm := _label(cell, k.capitalize(), 13)
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", _sb(GOLD, 3, 0, 0))
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(dot)
		var lvl := _label(skills_box, "", 13)
		lvl.custom_minimum_size.x = 18
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var bar := _bar(skills_box, 0, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_rows[k] = [nm, dot, lvl, bar]


## The bar is progress through the current level; at 10 the skill is full.
func _refresh_skills(s: Person) -> void:
	var marked := ""
	var why := ""
	if s.job != null:
		marked = Defs.CAREERS[s.job.career]["skill"]
		why = "Career skill: %s" % Defs.CAREERS[s.job.career]["name"]
	elif s.stage() == "child":
		marked = "logic"
		why = "Practised at school"
	for k in skill_rows:
		var v: float = s.skills[k]
		var row: Array = skill_rows[k]
		row[1].visible = k == marked
		row[1].tooltip_text = why
		row[2].text = str(int(v))
		row[3].value = 100.0 if v >= 10.0 else fmod(v, 1.0) * 100.0
		row[3].tooltip_text = "Top level" if v >= 10.0 else "%d%% of the way to level %d" % [int(fmod(v, 1.0) * 100.0), int(v) + 1]
		# Never practised: greyed, not hidden.
		var a := 0.45 if v <= 0.0 else 1.0
		row[0].modulate.a = a
		row[2].modulate.a = a


# ---------------------------------------------------------------- traits tab

## The word at each end of a trait's 1 to 9 scale: low first, high second.
const TRAIT_ENDS := {
	"neat": ["Messy", "Neat"], "outgoing": ["Shy", "Outgoing"], "active": ["Laid-back", "Active"],
	"playful": ["Serious", "Playful"], "nice": ["Grumpy", "Nice"],
}
const TRAIT_W := 110.0  # every track is the same width, so markers compare down the column


func _build_traits(parent: Node) -> void:
	traits_box = GridContainer.new()
	traits_box.columns = 3
	traits_box.add_theme_constant_override("h_separation", 10)
	traits_box.add_theme_constant_override("v_separation", 5)
	parent.add_child(traits_box)
	for t in Defs.TRAITS:
		var lo := _label(traits_box, TRAIT_ENDS[t][0], 13)
		lo.custom_minimum_size.x = 70
		lo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var track := Control.new()
		track.custom_minimum_size = Vector2(TRAIT_W, 12)
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		traits_box.add_child(track)
		var line := Panel.new()
		line.add_theme_stylebox_override("panel", _sb(Color(INK, 0.1), 2, 0, 0))
		line.position = Vector2(0, 4)
		line.size = Vector2(TRAIT_W, 4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(line)
		var mid := ColorRect.new()
		mid.color = Color(INK, 0.22)
		mid.position = Vector2(TRAIT_W / 2.0 - 0.5, 1)
		mid.size = Vector2(1, 10)
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(mid)
		var mark := Panel.new()
		mark.add_theme_stylebox_override("panel", _sb(INK, 5, 0, 0))
		mark.size = Vector2(10, 10)
		mark.position.y = 1
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(mark)
		trait_marks[t] = mark
		_label(traits_box, TRAIT_ENDS[t][1], 13)


## The marker's centre sits at (value - 1) / 8 along the track: 1 far left, 5 centre, 9 far right.
func _refresh_traits(s: Person) -> void:
	for t in trait_marks:
		var v: float = clampf(s.traits[t], 1, 9)
		trait_marks[t].position.x = (v - 1.0) / 8.0 * TRAIT_W - 5.0
		trait_marks[t].get_parent().tooltip_text = "%s %d of 9" % [t.capitalize(), int(v)]


# ---------------------------------------------------------------- people tab

const REL_W := 52.0  # width of every relationship track
const ROW_H := 24.0
const PEOPLE_ROWS := 6  # rows shown before the list scrolls


func _build_people(parent: Node) -> void:
	people_scroll = ScrollContainer.new()
	people_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(people_scroll)
	# A slim, quiet scroll bar instead of the default grey one.
	var vb := people_scroll.get_v_scroll_bar()
	vb.custom_minimum_size.x = 4
	for st in ["scroll", "scroll_focus"]:
		vb.add_theme_stylebox_override(st, _sb(Color(INK, 0.05), 2, 0, 0))
	vb.add_theme_stylebox_override("grabber", _sb(Color(INK, 0.22), 2, 0, 0))
	vb.add_theme_stylebox_override("grabber_highlight", _sb(Color(INK, 0.38), 2, 0, 0))
	vb.add_theme_stylebox_override("grabber_pressed", _sb(Color(INK, 0.5), 2, 0, 0))
	# The scroll bar is drawn over the list's right edge, so keep the words clear of it.
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_right", 6)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people_scroll.add_child(pad)
	people_list = VBoxContainer.new()
	people_list.add_theme_constant_override("separation", 0)
	pad.add_child(people_list)


## Everyone the selected person knows: the rest of the household always, anyone else
## once the relationship is at least 5 either way. Household first, each group warmest first.
func _known(s: Person) -> Array:
	var home := []
	var others := []
	for p in game.everyone():
		if p == s:
			continue
		var r: float = game.get_rel(s, p)
		if p.resident:
			home.append(p)
		elif absf(r) >= 5.0:
			others.append(p)
	var warmest := func(a, b): return game.get_rel(s, a) > game.get_rel(s, b)
	home.sort_custom(warmest)
	others.sort_custom(warmest)
	return [home, others]


func _refresh_people(s: Person) -> void:
	var groups := _known(s)
	var sig := "%d:" % s.pid
	for g in groups:
		sig += ",".join(g.map(func(p): return str(p.pid))) + ";"
	if _changed("people", sig):
		_clear(people_list)
		people_rows.clear()
		var items := 0
		if groups[0].is_empty() and groups[1].is_empty():
			_people_note("Nobody yet.")
			items += 1
		for g in 2:
			if g == 1 and not groups[1].is_empty() and not groups[0].is_empty():
				_people_note("Neighbours")
				items += 1
			for p in groups[g]:
				_people_row(p)
				items += 1
		people_scroll.custom_minimum_size.y = mini(items, PEOPLE_ROWS) * ROW_H
		people_scroll.scroll_vertical = 0
	for row in people_rows:
		var r: float = clampf(game.get_rel(s, row[0]), -100.0, 100.0)
		var w := absf(r) / 100.0 * REL_W / 2.0
		row[1].color = GOOD if r >= 0.0 else WARN
		row[1].position.x = REL_W / 2.0 if r >= 0.0 else REL_W / 2.0 - w
		row[1].size.x = w
		row[2].text = game._rel_word(r)
		row[1].get_parent().tooltip_text = "%+d" % int(r)


func _people_note(text: String) -> void:
	var l := _label(people_list, text, 12)
	l.add_theme_color_override("font_color", MUTED)
	l.custom_minimum_size.y = ROW_H
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _people_row(p: Person) -> void:
	var row := _hbox(people_list, 5)
	row.custom_minimum_size.y = ROW_H
	# A small version of the household chips: residents filled, visitors outlined.
	var chip := PanelContainer.new()
	var sb := _sb(p.shirt if p.resident else PAPER, 9, 0, 0)
	if not p.resident:
		sb.set_border_width_all(2)
		sb.border_color = p.shirt
	chip.add_theme_stylebox_override("panel", sb)
	chip.custom_minimum_size = Vector2(18, 18)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	var ini := _label(chip, p.first().substr(0, 1), 11)
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ini.add_theme_color_override("font_color", Color.WHITE if p.resident else INK)
	var nm := _label(row, p.pname, 13)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# A track centred on zero, like the trait scales: green to the right, red to the left.
	var track := Control.new()
	track.custom_minimum_size = Vector2(REL_W, 12)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)
	var line := Panel.new()
	line.add_theme_stylebox_override("panel", _sb(Color(INK, 0.1), 2, 0, 0))
	line.position = Vector2(0, 4)
	line.size = Vector2(REL_W, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(line)
	var fill := ColorRect.new()
	fill.position = Vector2(REL_W / 2.0, 4)
	fill.size = Vector2(0, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	var mid := ColorRect.new()
	mid.color = Color(INK, 0.3)
	mid.position = Vector2(REL_W / 2.0 - 0.5, 1)
	mid.size = Vector2(1, 10)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(mid)
	var word := _label(row, "", 12)
	word.add_theme_color_override("font_color", MUTED)
	word.custom_minimum_size.x = 78
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	people_rows.append([p, fill, word])
