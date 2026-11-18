extends CanvasLayer
## The household creator: one rolled person on a stand, with Reroll and Done. Done prints
## the spec and starts a game with it. Opened with TP_SCREEN=create. Built from the HUD's
## own helpers, so it looks like the rest of the game.

const STAND := Vector3(400, 0, 400)  # far from the lot, so nothing of the lot is in view

static var from_done := false  # set by Done, read once by the game that follows the reload

const MAX_MEMBERS := 4
## The life stages a new member can start in. There is no baby stage (a child is anyone under
## Defs.CHILD_DAYS, and babies join later through the game's own "expecting" event), and no
## teen stage (the game has only child, adult and elder).
const STAGES := ["child", "adult", "elder"]

var game
var stand: Node3D
var cam: Camera3D
var person: Person
var members: Array = []  # [{name, age, look, traits}], the household being made
var sel := 0
var rng := RandomNumberGenerator.new()
var name_l: Label
var info_l: Label
var style_btns: Array = []
var fam_e: LineEdit
var first_e: LineEdit
var why_l: Label
var done_b: Button
var remove_b: Button
var chips_box: HBoxContainer
var stage_btns: Array = []
var skin_btns: Array = []
var hair_btns: Array = []
var shirt_btns: Array = []
var pants_btns: Array = []
var h_slider: HSlider
var look_box: VBoxContainer
var traits_box: VBoxContainer
var tab_btns: Array = []
var trait_sliders := {}
var points_l: Label
var pairs_box: VBoxContainer
var rels := {}  # "uidA-uidB" -> kind, for pairs the player has set
var _next_uid := 0
var wide_slider: HSlider
var _frames := 0
var _after_done := false


## Builds the screen's nodes on `g` and returns them, for `screens["create"]`.
func setup(g) -> Array:
	game = g
	_after_done = from_done
	from_done = false
	if OS.has_environment("TP_SEED"):
		rng.seed = int(OS.get_environment("TP_SEED")) + 7919
	else:
		rng.randomize()
	game.add_child(self)
	var ui: UI = game.ui
	stand = Node3D.new()
	stand.position = STAND
	game.add_child(stand)
	Meshes.cyl(stand, 0.8, 0.8, 0.12, Vector3(0, -0.06, 0), Color(0.82, 0.8, 0.74))
	Meshes.cyl(stand, 3.0, 3.0, 0.1, Vector3(0, -0.17, 0), Color(0.5, 0.68, 0.4))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(1.5, 3.0, 3.0)
	lamp.light_energy = 0.9
	lamp.omni_range = 12.0
	stand.add_child(lamp)
	cam = Camera3D.new()
	game.add_child(cam)
	cam.position = STAND + Vector3(0, 1.4, 5.4)
	cam.look_at(STAND + Vector3(0.0, 0.95, 0.0))
	cam.fov = 38.0
	cam.current = false

	var panel := PanelContainer.new()
	panel.theme = ui.root.theme
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(24, 0)
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size.x = 270
	panel.add_child(box)
	var head := ui._label(box, "New household", 12)
	head.add_theme_color_override("font_color", UI.MUTED)
	chips_box = HBoxContainer.new()
	chips_box.add_theme_constant_override("separation", 6)
	box.add_child(chips_box)
	name_l = ui._label(box, "", 20)
	info_l = ui._label(box, "", 13)
	info_l.add_theme_color_override("font_color", UI.MUTED)
	fam_e = _name_row(box, "Family", func(): fam_e.text = Defs.surname(rng))
	first_e = _name_row(box, "First name", func(): first_e.text = Defs.first_name(rng))
	var sl := ui._label(box, "Life stage", 12)
	sl.add_theme_color_override("font_color", UI.MUTED)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 4)
	box.add_child(srow)
	for st in STAGES:
		var b := ui._seg(srow, st.capitalize(), set_stage.bind(st))
		stage_btns.append(b)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	box.add_child(tabs)
	tab_btns.append(ui._seg(tabs, "Look", _show_tab.bind("look")))
	tab_btns.append(ui._seg(tabs, "Traits", _show_tab.bind("traits")))
	tab_btns.append(ui._seg(tabs, "People", _show_tab.bind("people")))
	look_box = VBoxContainer.new()
	look_box.add_theme_constant_override("separation", 8)
	box.add_child(look_box)
	traits_box = VBoxContainer.new()
	traits_box.add_theme_constant_override("separation", 8)
	box.add_child(traits_box)
	pairs_box = VBoxContainer.new()
	pairs_box.add_theme_constant_override("separation", 6)
	box.add_child(pairs_box)
	for t in Defs.TRAITS:
		trait_sliders[t] = _trait_row(traits_box, t)
	points_l = ui._label(traits_box, "", 12)
	points_l.add_theme_color_override("font_color", UI.MUTED)
	var hl := ui._label(look_box, "Hair style", 12)
	hl.add_theme_color_override("font_color", UI.MUTED)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 4)
	look_box.add_child(hrow)
	for i in Defs.HAIR_STYLES.size():
		style_btns.append(ui._seg(hrow, Defs.HAIR_STYLES[i], set_style.bind(i)))
	skin_btns = _swatches(look_box, "Skin", Defs.SKIN_TONES, set_skin)
	hair_btns = _swatches(look_box, "Hair colour", Defs.HAIR_COLOURS, set_hair)
	shirt_btns = _swatches(look_box, "Shirt", Defs.SHIRT_COLOURS, set_shirt)
	pants_btns = _swatches(look_box, "Trousers", Defs.TROUSER_COLOURS, set_pants)
	h_slider = _slider(look_box, "Height", Defs.HEIGHT_RANGE, set_height)
	wide_slider = _slider(look_box, "Build", Defs.WIDTH_RANGE, set_build)
	why_l = ui._label(box, "", 12)
	why_l.add_theme_color_override("font_color", UI.MUTED)
	why_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	ui._btn(row, "Reroll", reroll)
	remove_b = ui._btn(row, "Remove", remove_selected)
	var done := ui._btn(row, "Done", finish)
	done_b = done
	done.add_theme_stylebox_override("normal", ui._sb(UI.INK))
	done.add_theme_stylebox_override("hover", ui._sb(UI.INK.lightened(0.15)))
	done.add_theme_color_override("font_color", Color.WHITE)
	done.add_theme_color_override("font_hover_color", Color.WHITE)

	fam_e.text = Defs.surname(rng)
	var stages := ["adult"]
	if OS.has_environment("TP_CREATE_MEMBERS"):  # "adult,adult,child": the household, for tests
		stages = Array(OS.get_environment("TP_CREATE_MEMBERS").split(","))
	for st in stages:
		members.append(_new_member(st.strip_edges()))
	if OS.has_environment("TP_CREATE_NAMES"):  # "Family|First": typed names for the first member
		var parts := OS.get_environment("TP_CREATE_NAMES").split("|")
		fam_e.text = parts[0]
		members[0]["name"] = parts[1] if parts.size() > 1 else ""
	_select(int(OS.get_environment("TP_CREATE_SEL")) if OS.has_environment("TP_CREATE_SEL") else 0)
	if OS.has_environment("TP_CREATE_LOOK"):  # "skin=2,hair=4": clicks those swatches on the selected member
		for kv in OS.get_environment("TP_CREATE_LOOK").split(","):
			var p := kv.split("=")
			if p[0] == "style":
				set_style(int(p[1]))
			elif p[0] == "h":
				set_height(float(p[1]))
			elif p[0] == "wide":
				set_build(float(p[1]))
			elif p[0] == "shirt":
				set_shirt(int(p[1]))
			elif p[0] == "pants":
				set_pants(int(p[1]))
			elif p[0] == "skin":
				set_skin(int(p[1]))
			elif p[0] == "hair":
				set_hair(int(p[1]))
	if OS.has_environment("TP_CREATE_TRAITS"):  # "9,9,5,1,1": set through the slider callbacks, in Defs.TRAITS order
		var vals := OS.get_environment("TP_CREATE_TRAITS").split(",")
		for t in Defs.TRAITS:  # start from all 1s, so no rolled value eats the points being asked for
			set_trait(t, 1)
		for i in Defs.TRAITS.size():
			set_trait(Defs.TRAITS[i], int(vals[i]))
		var tr: Dictionary = members[sel]["traits"]
		print("CREATE traits: asked ", Array(vals), " settled ", Defs.TRAITS.map(func(t): return tr[t]), " total ", _trait_total(tr))
	_show_tab(OS.get_environment("TP_CREATE_TAB") if OS.has_environment("TP_CREATE_TAB") else "look")
	if OS.has_environment("TP_CREATE_RELS"):  # "0-1:partners,0-2:family": the pairs, through the same callback
		for kv in OS.get_environment("TP_CREATE_RELS").split(","):
			var pk := kv.split(":")
			var ij := pk[0].split("-")
			set_rel(int(ij[0]), int(ij[1]), pk[1])
	if OS.has_environment("TP_CREATE_REFUSE"):  # the refusals, scripted: remove and re-stage the only adult
		remove_selected()
		set_stage("child")
	if _after_done:
		if OS.has_environment("TP_SAVE"):
			game.save_game()  # so a second launch can load what was made
		for p in game.people:
			print("CREATE game: ", describe(p.pname, p.age, p.traits, p.look))
		for i in game.people.size():
			for j in range(i + 1, game.people.size()):
				print("CREATE game rel %d-%d: %s" % [i, j, game.get_rel(game.people[i], game.people[j])])
	elif OS.has_environment("TP_CREATE_PRINT"):  # a launch that loaded a save: show who is in it
		for p in game.people:
			print("CREATE loaded: ", describe(p.pname, p.age, p.traits, p.look))
	if not _after_done and OS.has_environment("TP_CREATE_DONE") and OS.has_environment("TP_TEST"):
		finish.call_deferred()  # a headless test run has no frames to wait for
	return [self, stand, cam]


static func stage_of(age: float) -> String:
	if age < Defs.CHILD_DAYS:
		return "child"
	return "elder" if age >= Defs.ELDER_AT else "adult"


## A new member in the given stage, rolled like anyone else; only the age depends on the stage.
func _new_member(st: String) -> Dictionary:
	var r := Person.roll(rng)
	_fit_budget(r["traits"])
	_next_uid += 1
	return {"uid": _next_uid, "name": r["name"], "age": _age_for(st, r["age"]), "look": r["look"], "traits": r["traits"]}


## An age inside the stage: the rolled one if it already fits, else a fresh one.
func _age_for(st: String, now: float) -> float:
	if stage_of(now) == st:
		return now
	match st:
		"child": return rng.randf_range(2.0, Defs.CHILD_DAYS - 0.5)
		"elder": return rng.randf_range(Defs.ELDER_AT, Defs.ELDER_AT + 4.0)
	return rng.randf_range(8.0, 18.0)


## The same fields in the same order for the spec and for the person in the game, so the
## two lines can be compared by eye or by diff.
static func describe(full_name: String, age: float, traits: Dictionary, look: Dictionary) -> String:
	var l := {}
	for k in look:
		l[k] = look[k].to_html(false) if look[k] is Color else snappedf(float(look[k]), 0.0001)
	var t := {}
	for k in traits:
		t[k] = traits[k]
	return "name=%s age=%.3f stage=%s traits=%s look=%s" % [full_name, age, stage_of(age), t, l]


## A labelled name field with a button that fills it with a random name.
func _name_row(box: Node, label: String, fill: Callable) -> LineEdit:
	var ui: UI = game.ui
	var l := ui._label(box, label, 12)
	l.add_theme_color_override("font_color", UI.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var e := LineEdit.new()
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.max_length = 20
	var sb: StyleBoxFlat = ui._sb(Color(0.9, 0.92, 0.91))
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", sb)
	e.add_theme_color_override("font_color", UI.INK)
	e.add_theme_color_override("caret_color", UI.INK)
	e.text_changed.connect(func(_t): _names_changed())
	row.add_child(e)
	ui._btn(row, "Random", func():
		fill.call()
		_names_changed())
	return e


## The member strip: one chip per member in their shirt colour, gold ring on the selected one,
## and a "+" while there is room. Drawn like the household chips on the lot HUD.
func _rebuild_chips() -> void:
	var ui: UI = game.ui
	for c in chips_box.get_children():
		c.queue_free()
	for i in members.size():
		var m: Dictionary = members[i]
		var nm: String = str(m["name"]).strip_edges()
		var b := ui._btn(chips_box, nm.substr(0, 1) if nm != "" else "?", _select.bind(i))
		var d := 30 if stage_of(m["age"]) == "child" else 38
		b.custom_minimum_size = Vector2(d, d)
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.tooltip_text = nm
		var sb: StyleBoxFlat = ui._sb(m["look"]["shirt"], d / 2, 0, 0)
		if i == sel:
			sb.set_border_width_all(3)
			sb.border_color = UI.GOLD
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color.WHITE)
	if members.size() < MAX_MEMBERS:
		var add := ui._btn(chips_box, "+", add_member)
		add.custom_minimum_size = Vector2(38, 38)
		add.size_flags_vertical = Control.SIZE_SHRINK_END
		add.tooltip_text = "Add a member"
		var ps: StyleBoxFlat = ui._sb(UI.PAPER, 19, 0, 0)
		for st in ["normal", "hover", "pressed"]:
			add.add_theme_stylebox_override(st, ps)
		add.add_theme_color_override("font_color", UI.INK)


## A row of round colour swatches under a small label. Clicking one calls `pick(index)`.
func _swatches(box: Node, label: String, colours: Array, pick: Callable) -> Array:
	var ui: UI = game.ui
	var l := ui._label(box, label, 12)
	l.add_theme_color_override("font_color", UI.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var out := []
	for i in colours.size():
		var b := ui._btn(row, "", pick.bind(i))
		b.custom_minimum_size = Vector2(26, 26)
		b.tooltip_text = "%s %d" % [label, i + 1]
		out.append(b)
	return out


func _style_swatches(btns: Array, colours: Array, current: Color) -> void:
	var ui: UI = game.ui
	for i in btns.size():
		var sb: StyleBoxFlat = ui._sb(colours[i], 13, 0, 0)
		if colours[i].is_equal_approx(current):
			sb.set_border_width_all(3)
			sb.border_color = UI.GOLD
		for st in ["normal", "hover", "pressed", "focus"]:
			btns[i].add_theme_stylebox_override(st, sb)


func set_style(i: int) -> void:
	members[sel]["look"]["style"] = i
	_select(sel)


## A quiet slider over `range`, with a small muted label.
func _slider(box: Node, label: String, range: Vector2, changed: Callable) -> HSlider:
	var ui: UI = game.ui
	var l := ui._label(box, label, 12)
	l.add_theme_color_override("font_color", UI.MUTED)
	var s := _make_slider(range.x, range.y, 0.005)
	s.value_changed.connect(changed)
	box.add_child(s)
	return s


## A quiet slider: light track, ink-coloured filled part.
func _make_slider(lo: float, hi: float, step: float) -> HSlider:
	var ui: UI = game.ui
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size.y = 18
	s.focus_mode = Control.FOCUS_NONE
	var track: StyleBoxFlat = ui._sb(Color(0.86, 0.88, 0.87), 3, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill: StyleBoxFlat = ui._sb(UI.INK, 3, 0, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	return s


static func _trait_total(tr: Dictionary) -> int:
	var n := 0
	for t in Defs.TRAITS:
		n += int(tr[t])
	return n


## Brings a trait set down to the budget by lowering the highest trait one point at a time;
## ties go to the creator's own rng. A set already inside the budget is left alone.
func _fit_budget(tr: Dictionary) -> void:
	while _trait_total(tr) > Defs.TRAIT_BUDGET:
		var top := 0
		for t in Defs.TRAITS:
			top = maxi(top, int(tr[t]))
		var ties := Defs.TRAITS.filter(func(t): return int(tr[t]) == top)
		tr[ties[rng.randi() % ties.size()]] = top - 1


## One trait: the word for 1, a 1 to 9 slider, the word for 9. The words are the card's own.
func _trait_row(box: Node, t: String) -> HSlider:
	var ui: UI = game.ui
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var lo := ui._label(row, UI.TRAIT_ENDS[t][0], 12)
	lo.custom_minimum_size.x = 62
	lo.add_theme_color_override("font_color", UI.MUTED)
	var s := _make_slider(1.0, 9.0, 1.0)
	s.tooltip_text = Defs.TRAIT_HINTS[t]
	lo.tooltip_text = Defs.TRAIT_HINTS[t]
	lo.mouse_filter = Control.MOUSE_FILTER_STOP  # labels ignore the mouse by default, which hides tooltips
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v): set_trait(t, int(v)))
	row.add_child(s)
	var hi := ui._label(row, UI.TRAIT_ENDS[t][1], 12)
	hi.custom_minimum_size.x = 62
	hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hi.add_theme_color_override("font_color", UI.MUTED)
	hi.tooltip_text = Defs.TRAIT_HINTS[t]
	hi.mouse_filter = Control.MOUSE_FILTER_STOP
	if OS.has_environment("TP_SHOT"):
		print("CREATE tooltip %s: %s" % [t, s.tooltip_text])
	return s


## Sets a trait, but never past the budget: the value is clamped to the points left.
func set_trait(t: String, v: int) -> void:
	var tr: Dictionary = members[sel]["traits"]
	var others := _trait_total(tr) - int(tr[t])
	tr[t] = clampi(v, 1, mini(9, Defs.TRAIT_BUDGET - others))
	_refresh()


func _show_tab(which: String) -> void:
	look_box.visible = which == "look"
	traits_box.visible = which == "traits"
	pairs_box.visible = which == "people"
	for i in tab_btns.size():
		tab_btns[i].set_pressed_no_signal(["look", "traits", "people"][i] == which)


static func _is_child(m: Dictionary) -> bool:
	return stage_of(m["age"]) == "child"


func _pair_key(a: Dictionary, b: Dictionary) -> String:
	return "%d-%d" % [mini(a["uid"], b["uid"]), maxi(a["uid"], b["uid"])]


## How members i and j start out: what the player chose, else partners for the first two
## non-children, family for any pair with a child, and housemates for the rest.
func kind_of(i: int, j: int) -> String:
	var a: Dictionary = members[i]
	var b: Dictionary = members[j]
	var k: String = rels.get(_pair_key(a, b), "")
	if k == "partners" and (_is_child(a) or _is_child(b)):
		k = ""  # a member has since become a child
	if k != "":
		return k
	if _is_child(a) or _is_child(b):
		return "family"
	for x in members.size():
		for y in range(x + 1, members.size()):
			if not _is_child(members[x]) and not _is_child(members[y]):
				return "partners" if (x == i and y == j) else "housemates"
	return "housemates"


## Sets how members i and j start. Partners need two non-children.
func set_rel(i: int, j: int, kind: String) -> void:
	if kind == "partners" and (_is_child(members[i]) or _is_child(members[j])):
		_refuse("Partners must both be adults or elders, so this pair stays %s." % kind_of(i, j))
		_refresh()
		return
	rels[_pair_key(members[i], members[j])] = kind
	_refresh()


## One row per pair: both first names, then Partners / Family / Housemates.
func _rebuild_pairs() -> void:
	var ui: UI = game.ui
	for c in pairs_box.get_children():
		c.queue_free()
	if members.size() < 2:
		var l := ui._label(pairs_box, "A household of one has no pairs to set.", 12)
		l.add_theme_color_override("font_color", UI.MUTED)
		return
	for i in members.size():
		for j in range(i + 1, members.size()):
			var nm := func(m): return str(m["name"]).strip_edges() if str(m["name"]).strip_edges() != "" else "?"
			var l := ui._label(pairs_box, "%s and %s" % [nm.call(members[i]), nm.call(members[j])], 12)
			l.add_theme_color_override("font_color", UI.MUTED)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			pairs_box.add_child(row)
			var cur := kind_of(i, j)
			for k in Defs.REL_KINDS:
				var b := ui._seg(row, k.capitalize(), set_rel.bind(i, j, k))
				b.set_pressed_no_signal(k == cur)
				if k == "partners" and (_is_child(members[i]) or _is_child(members[j])):
					b.disabled = true
					b.tooltip_text = "Partners must both be adults or elders."


func set_height(v: float) -> void:
	members[sel]["look"]["h"] = clampf(v, Defs.HEIGHT_RANGE.x, Defs.HEIGHT_RANGE.y)
	_select(sel)


func set_build(v: float) -> void:
	members[sel]["look"]["wide"] = clampf(v, Defs.WIDTH_RANGE.x, Defs.WIDTH_RANGE.y)
	_select(sel)


func set_shirt(i: int) -> void:
	members[sel]["look"]["shirt"] = Defs.SHIRT_COLOURS[i]
	_select(sel)


func set_pants(i: int) -> void:
	members[sel]["look"]["pants"] = Defs.TROUSER_COLOURS[i]
	_select(sel)


func set_skin(i: int) -> void:
	members[sel]["look"]["skin"] = Defs.SKIN_TONES[i]
	_select(sel)


func set_hair(i: int) -> void:
	members[sel]["look"]["hair"] = Defs.HAIR_COLOURS[i]
	_select(sel)


## Shows member `i`: their fields, stage and model.
func _select(i: int) -> void:
	sel = clampi(i, 0, members.size() - 1)
	var m: Dictionary = members[sel]
	first_e.text = m["name"]
	if person != null:
		person.free()
	person = Person.new()
	person.setup(game, game.world, 0, 1000 + sel, fam_e.text.strip_edges(), true, m)
	person.process_mode = Node.PROCESS_MODE_DISABLED  # a model on a stand: no needs, no orders
	stand.add_child(person)
	_refresh()


## Brings the labels, chips and buttons up to date with the member list.
func _refresh() -> void:
	var m: Dictionary = members[sel]
	var fam := fam_e.text.strip_edges()
	var first := str(m["name"]).strip_edges()
	person.pname = (first + " " + fam).strip_edges()
	name_l.text = person.pname
	person.age = m["age"]
	info_l.text = person.stage_text()
	for i in style_btns.size():
		style_btns[i].set_pressed_no_signal(i == int(m["look"]["style"]))
	for i in STAGES.size():
		stage_btns[i].set_pressed_no_signal(STAGES[i] == stage_of(m["age"]))
	remove_b.disabled = members.size() <= 1
	var tr: Dictionary = m["traits"]
	for t in Defs.TRAITS:
		trait_sliders[t].set_value_no_signal(tr[t])
	points_l.text = "Points left: %d of %d" % [Defs.TRAIT_BUDGET - _trait_total(tr), Defs.TRAIT_BUDGET]
	_style_swatches(skin_btns, Defs.SKIN_TONES, m["look"]["skin"])
	_style_swatches(hair_btns, Defs.HAIR_COLOURS, m["look"]["hair"])
	_style_swatches(shirt_btns, Defs.SHIRT_COLOURS, m["look"]["shirt"])
	_style_swatches(pants_btns, Defs.TROUSER_COLOURS, m["look"]["pants"])
	h_slider.set_value_no_signal(m["look"]["h"])
	wide_slider.set_value_no_signal(m["look"]["wide"])
	_rebuild_chips()
	_rebuild_pairs()
	var why := _problem()
	done_b.disabled = why != ""
	if why != "":
		why_l.text = why


func _names_changed() -> void:
	members[sel]["name"] = first_e.text
	_refresh()
	if _problem() == "":
		why_l.text = ""


## Why the household cannot be started yet, or "" when it can.
func _problem() -> String:
	if fam_e.text.strip_edges() == "":
		return "Give the family a name to continue."
	for m in members:
		if str(m["name"]).strip_edges() == "":
			return "Give every member a first name to continue."
	if _grownups() == 0:
		return "The household needs an adult."
	return ""


## Members who can run a home: adults, and elders, who live on their pension without help
## (the game already starts neighbour households with a lone elder). Children cannot.
func _grownups() -> int:
	return members.filter(func(m): return stage_of(m["age"]) != "child").size()


func _refuse(text: String) -> void:
	print("CREATE refused: ", text)
	why_l.text = text


func add_member() -> void:
	if members.size() >= MAX_MEMBERS:
		_refuse("A household has at most %d members." % MAX_MEMBERS)
		return
	members.append(_new_member("adult"))
	_select(members.size() - 1)
	why_l.text = ""


func remove_selected() -> void:
	if members.size() <= 1:
		_refuse("A household needs at least one member.")
		return
	if stage_of(members[sel]["age"]) != "child" and _grownups() == 1:
		_refuse("The only adult cannot be removed. Someone has to run the home.")
		return
	members.remove_at(sel)
	_select(mini(sel, members.size() - 1))
	why_l.text = ""


func set_stage(st: String) -> void:
	var m: Dictionary = members[sel]
	if st == "child" and stage_of(m["age"]) != "child" and _grownups() == 1:
		_refuse("The only adult cannot become a child. Someone has to run the home.")
		_refresh()  # puts the stage buttons back
		return
	m["age"] = _age_for(st, m["age"])
	_select(sel)
	why_l.text = ""


## Rerolls the selected member's look and traits. Their name and life stage stay.
func reroll() -> void:
	var r := Person.roll(rng)
	members[sel]["look"] = r["look"]
	_fit_budget(r["traits"])
	members[sel]["traits"] = r["traits"]
	_select(sel)


func finish() -> void:
	var why := _problem()
	if why != "":
		_refuse(why)
		return
	var out := []
	for m in members:
		out.append({"name": str(m["name"]).strip_edges(), "age": m["age"], "look": m["look"], "traits": m["traits"]})
	var rl := []
	for i in members.size():
		for j in range(i + 1, members.size()):
			rl.append({"a": i, "b": j, "kind": kind_of(i, j)})
	var spec := {"family": fam_e.text.strip_edges(), "money": Household.new().money, "members": out, "rels": rl}
	print("CREATE spec rels: ", rl.map(func(r): return "%d-%d:%s=%s" % [r["a"], r["b"], r["kind"], Defs.REL_KINDS[r["kind"]]]))
	for m in out:
		print("CREATE spec: ", describe(m["name"] + " " + spec["family"], m["age"], m["traits"], m["look"]))
	game.new_spec = spec
	from_done = true
	game.new_game()


func _process(delta: float) -> void:
	if _after_done and game.screen == "create":
		_after_done = false  # TP_SCREEN reopened this after the reload; the game is what we want to see
		game.set_screen("lot")
		return
	if game.speed != 0:
		game.set_speed(0)  # a household is already loaded underneath; keep its clock still
	person.rotation.y += delta * 0.5
	_frames += 1
	if _frames == 20 and OS.has_environment("TP_CREATE_DONE"):
		finish()
