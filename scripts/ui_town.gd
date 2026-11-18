class_name UITown
extends CanvasLayer

var game
var root: Control
var banner: VBoxContainer
var card: VBoxContainer
var card_panel: PanelContainer


func _ready() -> void:
	root = Control.new()
	root.theme = game.ui.root.theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	banner = _panel(Vector2(16, 16))
	card = _panel(Vector2(16, -16), true)
	card_panel = card.get_parent()
	card_panel.hide()


func _panel(offset: Vector2, bottom := false) -> VBoxContainer:
	var panel := PanelContainer.new()
	root.add_child(panel)
	if bottom:
		panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position.x = offset.x
	if bottom:
		panel.offset_top = offset.y
		panel.offset_bottom = offset.y
	else:
		panel.position.y = offset.y
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 224
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func show_street(spec: Dictionary) -> void:
	game.ui._clear(banner)
	game.ui._label(banner, "The People · Town", 22)
	if not spec.is_empty():
		game.ui._label(banner, "Find a home for the %s household" % spec["family"], 15)
		game.ui._label(banner, "Available funds  $%d" % spec["money"], 15)
		game.ui._btn(banner, "Edit household", game.open_creator)
	elif game.people.is_empty():
		game.ui._btn(banner, "Create a household", game.open_creator)
	else:
		game.ui._label(banner, "Select a lot to see who lives there.", 14)


func show_lot(record, description: Dictionary, spec: Dictionary) -> void:
	game.ui._clear(card)
	card_panel.visible = record != null
	if record == null:
		return
	var id: int = record["id"]
	match record["kind"]:
		"home":
			var hh: Household = game.households.get(record["household"])
			if hh == null:
				card_panel.hide()
				return
			game.ui._label(card, "The %s household" % hh.family, 19)
			for p in game.household_of(hh.id):
				game.ui._label(card, "%s · %s" % [p.first(), p.stage().capitalize()], 14)
			if hh.player and not game.over:
				game.ui._btn(card, "Play", game.set_screen.bind("lot"))
		"empty":
			game.ui._label(card, "Empty lot", 19)
			game.ui._label(card, "For sale  $%d" % Defs.LOT_PRICE, 15)
			if not spec.is_empty():
				_offer("Buy lot", id, false, Defs.LOT_PRICE, spec)
		"vacant":
			var value: int = description["value"]
			var deposit := Household.rent_for(value)
			game.ui._label(card, "Vacant home", 19)
			game.ui._label(card, "Rent $%d every three days" % deposit, 15)
			game.ui._label(card, "Deposit $%d · Purchase $%d" % [deposit, value], 15)
			if not spec.is_empty():
				var actions: HBoxContainer = game.ui._hbox(card, 6)
				_offer("Rent", id, true, deposit, spec, actions)
				_offer("Buy home", id, false, value, spec, actions)


func _offer(label: String, id: int, rental: bool, cost: int, spec: Dictionary, parent: Control = null) -> void:
	var button: Button = game.ui._btn(card if parent == null else parent, label, game.claim_home.bind(id, rental))
	button.disabled = spec["money"] < cost
	if button.disabled:
		button.tooltip_text = "The household needs $%d more." % (cost - spec["money"])
