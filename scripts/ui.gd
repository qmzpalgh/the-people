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
var info_l: Label
var needs_btn: Button
var info_btn: Button
var needs_open := false
var info_open := false
var side: PanelContainer
var side_title: Label
var cat_box: HFlowContainer
var list_box: VBoxContainer
var hint_l: Label
var item_btns := {}
var tool_btns := {}
var cat := "Seating"
var build_tab := "Walls"
## Side of a thumbnail on a row and on a catalogue tile, in pixels.
const PIC := 40
const TILE_PIC := 64
var thumbs: Thumbs
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
	var head := _hbox(cv, 2)
	name_l = _label(head, "", 17)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	needs_btn = _seg(head, "Needs", func(): needs_open = not needs_open)
	info_btn = _seg(head, "About", func(): info_open = not info_open)
	act_l = _label(cv, "", 13)
	act_l.add_theme_color_override("font_color", MUTED)
	mood_bar = _bar(cv, 0, 6)
	mood_bar.tooltip_text = "Mood"
	alerts = HFlowContainer.new()
	cv.add_child(alerts)
	queue_box = HFlowContainer.new()
	cv.add_child(queue_box)
	needs_box = GridContainer.new()
	needs_box.columns = 4
	needs_box.add_theme_constant_override("h_separation", 8)
	needs_box.add_theme_constant_override("v_separation", 5)
	cv.add_child(needs_box)
	for n in Defs.NEEDS:
		var l := _label(needs_box, Defs.NEED_NAMES[n], 13)
		l.custom_minimum_size.x = 58
		bars[n] = _bar(needs_box, 84, 8)
	info_l = _label(cv, "", 13)

	# Catalogue and build tools.
	side = PanelContainer.new()
	_place(side, Control.PRESET_CENTER_RIGHT, -12, 0)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sv.custom_minimum_size.x = 268
	side.add_child(sv)
	side_title = _label(sv, "", 17)
	cat_box = HFlowContainer.new()
	sv.add_child(cat_box)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 352
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 2)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)
	thumbs = Thumbs.new()
	add_child(thumbs)
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
	needs_open = what.contains("needs")
	info_open = what.contains("info")
	if what.contains("help"):
		toggle_help()
	if what.contains("floors"):
		build_tab = "Floors"
		build_side()
	if _ui_word(what, "cat:") in Defs.CATS:
		cat = _ui_word(what, "cat:")
		build_side()
	if Defs.OBJECTS.has(_ui_word(what, "buy:")):
		game.set_buy(_ui_word(what, "buy:"))
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
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 6)
			list_box.add_child(grid)
			for k in Defs.OBJECTS:
				if Defs.OBJECTS[k]["cat"] == cat:
					item_btns[k] = _tile(grid, k)
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
				tool_btns["floor:%d" % i] = _row(f["name"], "$%d" % f["price"], _pick_tool.bind("floor:%d" % i), thumbs.floor_swatch(i))
			tool_btns["floor:0"] = _row("Remove floor", "", _pick_tool.bind("floor:0"))


func _row(text: String, right: String, cb: Callable, pic: Texture2D = null) -> Button:
	var b := _seg(list_box, text, cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if pic != null:
		_pic(b, pic)
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


## Puts a thumbnail left of a row's name. It is drawn at a fixed size, so the row keeps its
## height while the picture is still blank, and greys with the row (see refresh).
func _pic(b: Button, pic: Texture2D) -> void:
	b.icon = pic
	b.add_theme_constant_override("icon_max_width", PIC)
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), 8, 6, 2))
	b.add_theme_stylebox_override("disabled", _sb(Color(0, 0, 0, 0), 8, 6, 2))
	b.add_theme_stylebox_override("hover", _sb(Color(INK, 0.08), 8, 6, 2))
	b.add_theme_stylebox_override("pressed", _sb(INK, 8, 6, 2))
	b.add_theme_stylebox_override("hover_pressed", _sb(INK, 8, 6, 2))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.5))
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## A catalogue tile: the object's picture on top, its name under it and the price under
## that. Selecting and greying work as for a row.
func _tile(parent: Node, kind: String) -> Button:
	var d: Dictionary = Defs.OBJECTS[kind]
	var b := _seg(parent, d["name"], game.set_buy.bind(kind))
	_pic(b, thumbs.object(kind))
	b.add_theme_constant_override("icon_max_width", TILE_PIC)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 13)
	for st in [["normal", Color(0, 0, 0, 0)], ["disabled", Color(0, 0, 0, 0)], ["hover", Color(INK, 0.08)],
			["pressed", INK], ["hover_pressed", INK]]:
		var sb := _sb(st[1], 10, 6, 8)
		sb.content_margin_bottom = 26
		b.add_theme_stylebox_override(st[0], sb)
	var l := _label(b, "$%d" % d["price"], 12)
	l.add_theme_color_override("font_color", MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -26
	l.offset_bottom = -8
	b.tooltip_text = _details(kind)
	return b


## What an object is for, in a few short lines: what people can do with it (as its click
## menu names them), then how comfortable it is and what it does for the room, if anything.
func _details(kind: String) -> String:
	var d: Dictionary = Defs.OBJECTS[kind]
	var lines := []
	var uses := []
	var comfort: float = d.get("comfort", 0.0)
	for it in d.get("acts", []):
		comfort = maxf(comfort, it.get("needs", {}).get("comfort", 0.0))
		if it.get("hidden", false):
			continue
		var label: String = it["label"]
		if it.has("req"):
			label += " with a " + Defs.OBJECTS[it["req"]]["name"].to_lower()
		uses.append(label)
	# An object with only hidden acts is used from another one (the stove, from the fridge).
	for k in Defs.OBJECTS:
		for it in Defs.OBJECTS[k].get("acts", []):
			if uses.is_empty() and (it.get("req", "") == kind or it.get("then", {}).get("kind", "") == kind):
				uses.append("Needed to %s at the %s" % [it["label"].get_slice(" (", 0).to_lower(), Defs.OBJECTS[k]["name"].to_lower()])
	if d.get("light", false):
		uses.append("Lights the room at night")
	if uses.is_empty():
		uses.append("Garden decoration" if d["cat"] == "Garden" else "Decoration")
	lines.append(_wrap(uses, 34))
	if d.get("seat", false):
		lines.append("A seat for meals, TV and reading")
	if comfort >= 45.0:
		lines.append("Very comfortable")
	elif comfort >= 25.0:
		lines.append("Comfortable")
	elif comfort > 0.0:
		lines.append("A little comfortable")
	var room: float = d.get("room", 0.0)
	var nicer := ""
	if room >= 5.0:
		nicer = "Makes the room much nicer"
	elif room >= 2.0:
		nicer = "Makes the room nicer"
	elif room > 0.0:
		nicer = "Makes the room a little nicer"
	elif room < 0.0:
		nicer = "Makes the room worse"
	# Outdoors has a fixed room score, so garden things only count inside a room.
	if nicer != "" and d["cat"] == "Garden":
		nicer += " (indoors only)"
	if nicer != "":
		lines.append(nicer)
	return "\n".join(lines)


## Joins `items` with commas, starting a new line between items rather than past `width`.
func _wrap(items: Array, width: int) -> String:
	var out := ""
	var line := ""
	for w in items:
		if line != "" and line.length() + 2 + w.length() > width:
			out += line + ",\n"
			line = w
		else:
			line = w if line == "" else line + ", " + w
	return out + line


## The text after `key` in a TP_UI string, up to the next comma or space ("cat:Fun" gives "Fun").
func _ui_word(what: String, key: String) -> String:
	var i := what.find(key)
	if i < 0:
		return ""
	return what.substr(i + key.length()).get_slice(",", 0).get_slice(" ", 0)


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
			var gm: Material = Thumbs.greyed() if item_btns[k].disabled else null
			if item_btns[k].material != gm:
				item_btns[k].material = gm
			# The price on a selected (ink) tile is lighter so it can be read.
			var pl: Label = item_btns[k].get_child(0)
			var pc := Color(1, 1, 1, 0.65) if item_btns[k].button_pressed else MUTED
			if pl.get_theme_color("font_color") != pc:
				pl.add_theme_color_override("font_color", pc)
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
	act_l.text = s.activity()
	_set_bar(mood_bar, s.mood())
	needs_btn.set_pressed_no_signal(needs_open)
	info_btn.set_pressed_no_signal(info_open)
	needs_box.visible = needs_open
	info_l.visible = info_open

	# Only the needs that want attention surface on their own.
	var low := []
	if not needs_open and not s.away:
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

	if needs_open:
		for n in Defs.NEEDS:
			_set_bar(bars[n], s.needs[n])
	if info_open:
		var lines := [s.stage_text()]
		if s.job != null:
			var c: Dictionary = Defs.CAREERS[s.job.career]
			lines.append("%s, $%d a day, %d:00 to %d:00 on weekdays" % [c["titles"][s.job.level], c["pay"][s.job.level],
				int(c["start"]), int(c["start"] + c["hours"])])
			lines.append("Work performance %d%%" % int(clampf(s.job.perf, 0, 100)))
		elif s.stage() == "child":
			lines.append("At school 8:00 to 14:00 on weekdays")
		elif s.stage() == "elder":
			lines.append("Retired, $%d a day pension" % Defs.PENSION)
		else:
			lines.append("No job yet. A computer can find one.")
		var sk := []
		for k in Defs.SKILLS:
			if s.skills[k] >= 1.0:
				sk.append("%s %d" % [k.capitalize(), int(s.skills[k])])
		if not sk.is_empty():
			lines.append("Skills: " + ", ".join(sk))
		var tr := []
		for t in Defs.TRAITS:
			if s.traits[t] >= 7:
				tr.append(t.capitalize())
			elif s.traits[t] <= 3:
				tr.append("Not " + t)
		if not tr.is_empty():
			lines.append(", ".join(tr))
		var rl := []
		for p in game.everyone():
			var r: float = game.get_rel(s, p)
			if p != s and (p.resident or absf(r) >= 5.0):
				rl.append("%s %+d" % [p.first(), int(r)])
		if not rl.is_empty():
			lines.append("Knows " + ", ".join(rl))
		info_l.text = "\n".join(lines)
