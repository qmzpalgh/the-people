class_name UICreate
extends CanvasLayer

signal finished(spec: Dictionary)
signal cancelled

const STAGES := ["Adult", "Child", "Elder"]
const AGES := [12.0, 2.0, Defs.ELDER_AT]
const TRAIT_BUDGET := 25
const RELATIONSHIPS := ["Housemates", "Family", "Partners"]
const AFFINITY := [15.0, 55.0, 80.0]
const TRAIT_HINTS := {
	"neat": "Makes hygiene more important when choosing what to do.",
	"outgoing": "Makes social needs and talking to others more important.",
	"active": "Makes skill practice more attractive.",
	"playful": "Makes fun more important and helps jokes land.",
	"nice": "Affects friendly and hostile interactions.",
}

var ui: UI
var rng := RandomNumberGenerator.new()
var members: Array = []
var chosen := 0
var family := ""
var funds := Defs.START_FUNDS
var body: VBoxContainer
var summary: Label
var done: Button
var preview: Person
var member_list: VBoxContainer
var family_field: LineEdit
var tabs: TabContainer
var trait_sliders := {}
var trait_values := {}
var points: Label


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("33464e")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.theme = ui.root.theme
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	var roster := PanelContainer.new()
	row.add_child(roster)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 205
	column.add_theme_constant_override("separation", 10)
	roster.add_child(column)
	ui._label(column, "Create a household", 21)
	ui._label(column, "Family name", 14)
	family_field = _name_field(column, "", func(value): family = value; _validate(), func(): return Defs.surname(rng))
	member_list = VBoxContainer.new()
	column.add_child(member_list)

	var stand := SubViewportContainer.new()
	stand.stretch = true
	stand.custom_minimum_size.x = 200
	stand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stand)
	_build_preview(stand)

	var edit_panel := PanelContainer.new()
	edit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit_panel)
	var editor := VBoxContainer.new()
	editor.custom_minimum_size.x = 340
	editor.add_theme_constant_override("separation", 10)
	edit_panel.add_child(editor)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	editor.add_child(scroll)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	summary = ui._label(editor, "", 14)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := ui._hbox(editor, 6)
	ui._btn(actions, "Back to town", func(): cancelled.emit())
	ui._btn(actions, "Reroll", _reroll)
	done = ui._btn(actions, "Done", _finish)
	done.add_theme_color_override("font_color", Color.WHITE)
	done.add_theme_color_override("font_hover_color", Color.WHITE)
	done.add_theme_stylebox_override("normal", ui._sb(UI.INK))
	done.add_theme_stylebox_override("hover", ui._sb(UI.INK.lightened(0.16)))


func open(seed_value: int, existing: Dictionary) -> void:
	rng.seed = seed_value
	members.clear()
	chosen = 0
	funds = existing.get("money", Defs.START_FUNDS)
	family = existing["family"] if existing.has("family") else Defs.surname(rng)
	if existing.is_empty():
		members.append(_roll_member())
	else:
		members = existing["members"].duplicate(true)
		for member in members:
			member["relations"] = {}
		for link in existing.get("relationships", []):
			members[link["a"]]["relations"][members[link["b"]]["id"]] = link["kind"]
	family_field.text = family
	_refresh()


func _roll_member() -> Dictionary:
	var member := Person.roll(rng)
	var traits: Dictionary = member["traits"]
	var total := _total(traits)
	while total != TRAIT_BUDGET:
		var delta := 1 if total < TRAIT_BUDGET else -1
		var options := Defs.TRAITS.filter(func(t): return traits[t] + delta >= 1 and traits[t] + delta <= 9)
		traits[options[rng.randi_range(0, options.size() - 1)]] += delta
		total += delta
	return {"id": int(rng.randi()), "name": member["name"], "age": member["age"], "look": member["look"], "traits": traits, "relations": {}}


func _total(traits: Dictionary) -> int:
	var total := 0
	for key in Defs.TRAITS:
		total += traits[key]
	return total


func _build_preview(parent: SubViewportContainer) -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	parent.add_child(viewport)
	var world_env := WorldEnvironment.new()
	world_env.environment = Environment.new()
	world_env.environment.background_mode = Environment.BG_COLOR
	world_env.environment.background_color = Color("a2b5b2")
	world_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.environment.ambient_light_color = Color("e8e4d7")
	world_env.environment.ambient_light_energy = 0.65
	viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32, 30, 0)
	light.light_energy = 1.2
	viewport.add_child(light)
	var model := Node3D.new()
	viewport.add_child(model)
	Meshes.cyl(model, 0.68, 0.74, 0.16, Vector3(0, -0.08, 0), Color("617475"))
	preview = Person.new()
	model.add_child(preview)
	preview.rotation.y = -0.17
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.55
	camera.position = Vector3(0, 1.37, 4)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 0.94, 0))
	camera.make_current()


func _name_field(parent: VBoxContainer, value: String, change: Callable, random_name: Callable) -> LineEdit:
	var row := ui._hbox(parent, 6)
	var input := LineEdit.new()
	input.text = value
	input.max_length = 24
	input.add_theme_color_override("font_color", UI.INK)
	input.add_theme_color_override("caret_color", UI.INK)
	input.add_theme_stylebox_override("normal", ui._sb(Color("d0dcd6"), 6, 8, 4))
	input.add_theme_stylebox_override("focus", ui._sb(Color("c5d8d2"), 6, 8, 4))
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	input.text_changed.connect(change)
	ui._btn(row, "Random", func():
		input.text = random_name.call()
		change.call(input.text))
	return input


func _refresh(page := 0) -> void:
	ui._clear(member_list)
	for i in members.size():
		var button := ui._seg(member_list, _member_name(i), _select.bind(i))
		button.set_pressed_no_signal(i == chosen)
	var add := ui._btn(member_list, "Add member", _add)
	add.disabled = members.size() >= 4
	var remove := ui._btn(member_list, "Remove member", _remove)
	remove.disabled = members.size() == 1 or (_stage(members[chosen]) == 0 and _adult_count() == 1)
	if remove.disabled and members.size() > 1:
		remove.tooltip_text = "Keep at least one adult in the household."
	ui._clear(body)
	tabs = TabContainer.new()
	tabs.add_theme_stylebox_override("panel", ui._sb(Color("e0e6e2"), 6, 0, 0))
	tabs.add_theme_stylebox_override("tab_unselected", ui._sb(Color("d5dfdb"), 5, 8, 5))
	tabs.add_theme_stylebox_override("tab_hovered", ui._sb(Color("c5d8d2"), 5, 8, 5))
	tabs.add_theme_stylebox_override("tab_selected", ui._sb(UI.INK, 5, 8, 5))
	tabs.add_theme_color_override("font_unselected_color", UI.INK)
	tabs.add_theme_color_override("font_hovered_color", UI.INK)
	tabs.add_theme_color_override("font_selected_color", Color.WHITE)
	body.add_child(tabs)
	var appearance := _page("Appearance")
	_build_appearance(appearance)
	_build_traits(_page("Traits"))
	_build_relationships(_page("Relationships"))
	tabs.current_tab = page
	_update_preview()
	_validate()


func _page(title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 10)
	tabs.add_child(margin)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	margin.add_child(form)
	return form


func _build_appearance(form: VBoxContainer) -> void:
	var member: Dictionary = members[chosen]
	ui._label(form, "First name", 14)
	_name_field(form, member["name"], _change_name, func(): return Defs.first_name(rng))
	_option(form, "Life stage", STAGES, _stage(member), _set_stage)
	_swatches(form, "Skin tone", "skin", Defs.SKIN_TONES)
	_swatches(form, "Hair colour", "hair", Defs.HAIR_COLORS)
	_option(form, "Hair style", Defs.HAIR_STYLES, member["look"]["style"], _set_look.bind("style"))
	for pair in [["Shirt colour", "shirt"], ["Trouser colour", "pants"]]:
		var row := ui._hbox(form, 8)
		ui._label(row, pair[0], 14).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var picker := ColorPickerButton.new()
		picker.color = member["look"][pair[1]]
		picker.edit_alpha = false
		picker.custom_minimum_size.x = 82
		picker.color_changed.connect(_set_look.bind(pair[1]))
		row.add_child(picker)
	for item in [["Height", "h", Defs.HEIGHT_RANGE], ["Width", "wide", Defs.WIDTH_RANGE]]:
		var row := ui._hbox(form, 8)
		ui._label(row, item[0], 14).custom_minimum_size.x = 56
		_slider(row, item[2], member["look"][item[1]], 0.01, _set_look.bind(item[1]))


func _option(parent: VBoxContainer, title: String, choices: Array, selected: int, change: Callable) -> void:
	var row := ui._hbox(parent, 8)
	ui._label(row, title, 14).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := OptionButton.new()
	for choice in choices:
		button.add_item(choice)
	button.select(selected)
	button.item_selected.connect(change)
	row.add_child(button)


func _swatches(parent: VBoxContainer, title: String, key: String, colours: Array) -> void:
	ui._label(parent, title, 14)
	var row := ui._hbox(parent, 6)
	var group := ButtonGroup.new()
	for i in colours.size():
		var colour: Color = colours[i]
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(35, 29)
		button.tooltip_text = "%s %d" % [title, i + 1]
		button.add_theme_stylebox_override("normal", ui._sb(colour, 5, 4, 2))
		button.add_theme_stylebox_override("hover", ui._sb(colour.lightened(0.18), 5, 4, 2))
		var selected := ui._sb(colour, 5, 4, 2)
		selected.set_border_width_all(3)
		selected.border_color = UI.INK
		button.add_theme_stylebox_override("pressed", selected)
		button.button_pressed = members[chosen]["look"][key] == colour
		button.pressed.connect(_set_look.bind(colour, key))
		row.add_child(button)


func _slider(parent: HBoxContainer, limits: Vector2, value: float, step: float, change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(change)
	parent.add_child(slider)
	return slider


func _build_traits(form: VBoxContainer) -> void:
	trait_sliders.clear()
	trait_values.clear()
	points = ui._label(form, "", 15)
	for key in Defs.TRAITS:
		var row := ui._hbox(form, 6)
		var ends: Array = UI.TRAIT_ENDS[key]
		ui._label(row, ends[0], 13).custom_minimum_size.x = 68
		var slider := _slider(row, Vector2(1, 9), members[chosen]["traits"][key], 1, _set_trait.bind(key))
		slider.tooltip_text = TRAIT_HINTS[key]
		ui._label(row, ends[1], 13).custom_minimum_size.x = 58
		trait_sliders[key] = slider
		trait_values[key] = ui._label(row, str(int(slider.value)), 13)
	_update_points()


func _build_relationships(form: VBoxContainer) -> void:
	if members.size() < 2:
		ui._label(form, "Add another member to set starting relationships.", 14)
	for i in members.size():
		for j in range(i + 1, members.size()):
			var kinds := RELATIONSHIPS if _stage(members[i]) != 1 and _stage(members[j]) != 1 else RELATIONSHIPS.slice(0, 2)
			var kind: int = members[i]["relations"].get(members[j]["id"], 0)
			_option(form, "%s and %s" % [_member_name(i), _member_name(j)], kinds, mini(kind, kinds.size() - 1), _set_relationship.bind(i, j))


func _member_name(index: int) -> String:
	var value: String = members[index]["name"].strip_edges()
	return value if not value.is_empty() else "Member %d" % (index + 1)


func _stage(member: Dictionary) -> int:
	var age: float = member["age"]
	return 1 if age < Defs.CHILD_DAYS else (2 if age >= Defs.ELDER_AT else 0)


func _adult_count() -> int:
	return members.filter(func(member): return _stage(member) == 0).size()


func _select(index: int) -> void:
	chosen = index
	_refresh(tabs.current_tab)


func _add() -> void:
	if members.size() < 4:
		members.append(_roll_member())
		chosen = members.size() - 1
		_refresh()


func _remove() -> void:
	if members.size() == 1 or (_stage(members[chosen]) == 0 and _adult_count() == 1):
		return
	var id: int = members[chosen]["id"]
	members.remove_at(chosen)
	for member in members:
		member["relations"].erase(id)
	chosen = mini(chosen, members.size() - 1)
	_refresh()


func _reroll() -> void:
	var replacement := _roll_member()
	for key in ["id", "age", "relations"]:
		replacement[key] = members[chosen][key]
	members[chosen] = replacement
	_refresh(tabs.current_tab)


func _change_name(value: String) -> void:
	members[chosen]["name"] = value
	member_list.get_child(chosen).text = _member_name(chosen)
	_validate()


func _set_stage(index: int) -> void:
	if _stage(members[chosen]) == 0 and index != 0 and _adult_count() == 1:
		_refresh()
		summary.text = "Keep at least one adult in the household."
		return
	members[chosen]["age"] = AGES[index]
	if index == 1:
		for i in members.size():
			if i != chosen:
				var a := mini(i, chosen)
				var b := maxi(i, chosen)
				if members[a]["relations"].get(members[b]["id"], 0) == 2:
					_set_relationship(1, a, b)
	_refresh()


func _set_look(value, key: String) -> void:
	members[chosen]["look"][key] = value
	_update_preview()


func _set_trait(value: float, key: String) -> void:
	var traits: Dictionary = members[chosen]["traits"]
	var limit := TRAIT_BUDGET - _total(traits) + int(traits[key])
	traits[key] = mini(int(value), limit)
	trait_sliders[key].set_value_no_signal(traits[key])
	trait_values[key].text = str(traits[key])
	_update_points()


func _update_points() -> void:
	points.text = "%d of %d trait points used" % [_total(members[chosen]["traits"]), TRAIT_BUDGET]


func _set_relationship(kind: int, a: int, b: int) -> void:
	members[a]["relations"][members[b]["id"]] = kind


func _update_preview() -> void:
	preview.age = members[chosen]["age"]
	preview.look = members[chosen]["look"]
	preview.refresh_look()


func _validate() -> void:
	var valid := not family.strip_edges().is_empty() and members.all(func(member): return not member["name"].strip_edges().is_empty())
	done.disabled = not valid or _adult_count() == 0
	summary.text = "Enter a family name and a first name for each member." if not valid else ""


func _finish() -> void:
	_validate()
	if done.disabled:
		return
	var spec := {"family": family.strip_edges(), "money": funds, "members": members.duplicate(true), "relationships": []}
	for i in members.size():
		spec["members"][i]["name"] = members[i]["name"].strip_edges()
		spec["members"][i].erase("relations")
		for j in range(i + 1, members.size()):
			var kind: int = members[i]["relations"].get(members[j]["id"], 0)
			spec["relationships"].append({"a": i, "b": j, "kind": kind, "value": AFFINITY[kind]})
	finished.emit(spec)
