class_name UITown
extends CanvasLayer
## The town screen's HUD: the card that opens when a lot is clicked. Built from the same
## helpers and colours as the lot HUD (`ui.gd`): quiet by default, detail on demand.

var game: Node
var ui: UI
var card: PanelContainer
var body: VBoxContainer
var play_btn: Button
var prompt: CenterContainer
var create_btn: Button
var title := ""             # the card's title now, "" when the card is closed


func _init(g: Node = null) -> void:
	game = g


func _ready() -> void:
	ui = game.ui
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ui.root.theme
	add_child(root)
	card = PanelContainer.new()
	card.custom_minimum_size.x = 300
	root.add_child(card)
	card.position = Vector2(12, 12)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)
	card.hide()
	prompt = CenterContainer.new()
	prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt)
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = 320
	prompt.add_child(pc)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	pc.add_child(pv)
	ui._label(pv, "Welcome to town", 17)
	ui._label(pv, "No household lives here yet.", 13).add_theme_color_override("font_color", UI.MUTED)
	create_btn = ui._btn(pv, "Create a household", _create)
	create_btn.add_theme_stylebox_override("normal", ui._sb(UI.INK))
	create_btn.add_theme_stylebox_override("hover", ui._sb(UI.INK.lightened(0.15)))
	create_btn.add_theme_color_override("font_color", Color.WHITE)
	create_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	prompt.hide()


func show_prompt() -> void:
	prompt.show()


func asking() -> bool:
	return prompt.visible


## Until the household creator exists, this starts the random household already loaded.
func _create() -> void:
	prompt.hide()
	game.set_screen("lot")


## Opens the card for a lot, or closes it for null.
func show_lot(l: Variant) -> void:
	play_btn = null
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	if l == null:
		title = ""
		card.hide()
		return
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 8)
	body.add_child(head)
	match l["kind"]:
		"home":
			var hh: Household = game.households[l["household"]]
			title = hh.family
			var n := ui._label(head, title, 17)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if l["household"] == 0:
				ui._chip(head, "Your home", UI.GOLD.darkened(0.3))
			var folk: Array = game.household_of(l["household"])
			var sub := ui._label(body, "%d %s" % [folk.size(), "person" if folk.size() == 1 else "people"], 13)
			sub.add_theme_color_override("font_color", UI.MUTED)
			for p in folk:
				var row := ui._hbox(body, 8)
				var nm := ui._label(row, p.first(), 14)
				nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ui._chip(row, p.stage().capitalize(), UI.MUTED)
			if l["household"] == 0:
				play_btn = ui._btn(body, "Play", game.set_screen.bind("lot"))
				play_btn.add_theme_stylebox_override("normal", ui._sb(UI.INK))
				play_btn.add_theme_stylebox_override("hover", ui._sb(UI.INK.lightened(0.15)))
				play_btn.add_theme_color_override("font_color", Color.WHITE)
				play_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		"vacant":
			title = "To let"
			ui._label(head, title, 17)
			ui._label(body, "A house, empty", 13).add_theme_color_override("font_color", UI.MUTED)
		_:
			title = "For sale"
			ui._label(head, title, 17)
			ui._label(body, "Bare land", 13).add_theme_color_override("font_color", UI.MUTED)
	card.show()
