extends CanvasLayer
## The household creator: one rolled person on a stand, with Reroll and Done. Done prints
## the spec and starts a game with it. Opened with TP_SCREEN=create. Built from the HUD's
## own helpers, so it looks like the rest of the game.

const STAND := Vector3(400, 0, 400)  # far from the lot, so nothing of the lot is in view

static var from_done := false  # set by Done, read once by the game that follows the reload

var game
var stand: Node3D
var cam: Camera3D
var person: Person
var spec := {}
var rng := RandomNumberGenerator.new()
var rolls := 0
var name_l: Label
var info_l: Label
var look_l: Label
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
	box.custom_minimum_size.x = 230
	panel.add_child(box)
	var head := ui._label(box, "New household", 12)
	head.add_theme_color_override("font_color", UI.MUTED)
	name_l = ui._label(box, "", 20)
	info_l = ui._label(box, "", 13)
	info_l.add_theme_color_override("font_color", UI.MUTED)
	look_l = ui._label(box, "", 13)
	look_l.add_theme_color_override("font_color", UI.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	ui._btn(row, "Reroll", reroll)
	var done := ui._btn(row, "Done", finish)
	done.add_theme_stylebox_override("normal", ui._sb(UI.INK))
	done.add_theme_stylebox_override("hover", ui._sb(UI.INK.lightened(0.15)))
	done.add_theme_color_override("font_color", Color.WHITE)
	done.add_theme_color_override("font_hover_color", Color.WHITE)
	reroll()
	if _after_done:
		print("CREATE game: ", describe(game.people[0].pname, game.people[0].age, game.people[0].traits, game.people[0].look))
	return [self, stand, cam]


## The same fields in the same order for the spec and for the person in the game, so the
## two lines can be compared by eye or by diff.
static func describe(full_name: String, age: float, traits: Dictionary, look: Dictionary) -> String:
	var l := {}
	for k in look:
		l[k] = look[k].to_html(false) if look[k] is Color else snappedf(float(look[k]), 0.0001)
	var t := {}
	for k in traits:
		t[k] = traits[k]
	return "name=%s age=%.3f traits=%s look=%s" % [full_name, age, t, l]


func reroll() -> void:
	rolls += 1
	var fam := Defs.surname(rng)
	var r := Person.roll(rng)
	spec = {"family": fam, "money": Household.new().money,
		"members": [{"name": r["name"], "age": r["age"], "look": r["look"], "traits": r["traits"]}]}
	if person != null:
		person.free()
	person = Person.new()
	person.setup(game, game.world, 0, rng.randi(), fam, true, spec["members"][0])
	person.process_mode = Node.PROCESS_MODE_DISABLED  # a model on a stand: no needs, no orders
	stand.add_child(person)
	var m: Dictionary = spec["members"][0]
	name_l.text = person.pname
	info_l.text = person.stage_text()
	look_l.text = "Hair: %s" % Defs.HAIR_STYLES[int(m["look"]["style"])]


func finish() -> void:
	var m: Dictionary = spec["members"][0]
	print("CREATE spec: ", describe(person.pname, m["age"], m["traits"], person.look))
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
