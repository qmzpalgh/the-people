extends SceneTree
## Run with Godot's --script flag in an isolated user-data directory.

const MAIN := preload("res://main.tscn")
var save_path := "user://roadmap-test-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]


func _initialize() -> void:
	_run.call_deferred()


func _boot(load_save := false):
	if load_save:
		OS.unset_environment("TP_FRESH")
	else:
		OS.set_environment("TP_FRESH", "1")
	var game := MAIN.instantiate()
	if not load_save:
		game.start_creator = true
	root.add_child(game)
	current_scene = game
	await process_frame
	return game


func _run() -> void:
	OS.set_environment("TP_SEED", "100")
	OS.set_environment("TP_SAVE", save_path)
	OS.set_environment("TP_AGE", "0")
	var game = await _boot(true)
	assert(game.screen == "town" and game.people.is_empty())
	_press(game.town_ui.banner, "Create a household")
	assert(game.screen == "create")
	var creator: UICreate = game.creator
	assert(creator._adult_count() == 1)
	creator._set_stage(1)
	assert(creator._adult_count() == 1)
	creator.family_field.text = "Vale"
	creator.family_field.text_changed.emit("Vale")
	creator._change_name("")
	creator._finish()
	assert(game.screen == "create")
	creator._change_name("Mina")
	creator._set_look(Defs.SKIN_TONES[3], "skin")
	creator._set_look(Defs.HAIR_COLORS[4], "hair")
	creator._set_look(2, "style")
	creator._set_look(Color.CORAL, "shirt")
	creator._set_look(Color.NAVY_BLUE, "pants")
	creator._set_look(Defs.HEIGHT_RANGE.y, "h")
	creator._set_look(Defs.WIDTH_RANGE.x, "wide")
	var traits: Dictionary = creator.members[0]["traits"].duplicate()
	creator._set_trait(9, "nice")
	assert(creator._total(creator.members[0]["traits"]) == 25)
	assert(creator.members[0]["traits"] == traits)
	creator._add()
	creator._change_name("Evan")
	creator._add()
	creator._change_name("Jo")
	creator._set_stage(1)
	creator._set_relationship(2, 0, 1)
	creator._set_relationship(1, 0, 2)
	creator._finish()
	assert(game.screen == "town" and game.money == 2500)
	assert(game.household_draft["money"] == Defs.START_FUNDS and game.town.lot_of(0) == null)
	var date: float = game.minutes
	await process_frame
	assert(game.minutes == date and game.people.is_empty())
	var lot_id := _find_lot(game, "empty")
	var area: Rect2 = game.town_view.bounds[lot_id]
	var point: Vector2 = game.town_view.rig.cam.unproject_position(Vector3(area.get_center().x, 0, area.get_center().y))
	assert(game.town_view.lot_at(point) == lot_id)
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game.town_view._unhandled_input(click)
	assert(game.selected_lot == lot_id)
	_press(game.town_ui.card, "Buy lot")
	assert(game.screen == "lot" and game.mode == "build" and game.speed == 0)
	assert(game.money == Defs.START_FUNDS - Defs.LOT_PRICE)
	assert(game.world.objects.is_empty() and game.world.door_tile == game.world.exit_tile)
	assert(game.people.map(func(p): return p.first()) == ["Mina", "Evan", "Jo"])
	assert(game.people[2].stage() == "child")
	assert(game.get_rel(game.people[0], game.people[1]) == 80)
	assert(game.get_rel(game.people[0], game.people[2]) == 55)
	_build_room(game)
	assert(game.world.door_tile == Vector2i(18, 23))
	assert(game.world.entry_inside == Vector2i(18, 22))
	assert(game.world.house_bounds() == Rect2i(13, 15, 10, 8))
	assert(game.world.path(game.world.exit_tile, game.world.entry_inside) != null)
	_check_visitor(game)
	game.set_speed(2)
	var hunger: float = game.selected.needs.hunger
	game._process(3.0)
	assert(game.selected.needs.hunger == hunger)
	game.set_mode("buy")
	_place(game, "fridge", Vector3(15.5, 0, 20.5))
	_place(game, "bed_double", Vector3(17, 0, 17))
	_place(game, "bed_single", Vector3(21.5, 0, 17))
	assert(game.world.objects.size() == 3)
	game.set_mode("live")
	assert(game.speed == 2)
	game.set_mode("buy")
	assert(game.speed == 0)
	game.set_mode("live")
	assert(game.speed == 2)
	_check_skip(game)
	_check_card.call_deferred(game)
	await card_checked
	game.set_speed(1)
	while game.day < 1:
		game._step(1.0 / 60.0, 1.0)
	_check_town_round_trip(game)
	game.save_game(true)
	var saved_world: Dictionary = game.world.save_state()
	var state: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	game.free()
	game = await _boot(true)
	assert(game.screen == "town")
	assert(game.minutes == float(state["minutes"]))
	assert(game.money == int(state["households"][0]["money"]))
	assert(game.world.save_state() == saved_world)
	assert(game.people[0].pname == "Mina Vale")
	assert(game.people[0].look["hair"].to_html() == Defs.HAIR_COLORS[4].to_html())
	assert(game.people[0].look["skin"].to_html() == Defs.SKIN_TONES[3].to_html())
	assert(game.people[0].look["shirt"].to_html() == Color.CORAL.to_html())
	assert(game.people[0].look["pants"].to_html() == Color.NAVY_BLUE.to_html())
	assert(int(game.people[0].look["style"]) == 2)
	assert(is_equal_approx(game.people[0].look["h"], Defs.HEIGHT_RANGE.y))
	assert(is_equal_approx(game.people[0].look["wide"], Defs.WIDTH_RANGE.x))
	assert(game.people[0].traits == traits)
	assert(game.get_rel(game.people[0], game.people[1]) == state["rel"]["0|1"])
	print("PASS: creator, town picking, empty-lot purchase, building, day advance and save/load")
	_check_migration(game, state)
	game.free()
	await _check_vacant(true)
	await _check_vacant(false)
	await _check_restart_routes()
	DirAccess.remove_absolute(save_path)
	quit()


func _find_lot(game, kind: String) -> int:
	for record in game.town.by_slot():
		if record["kind"] == kind:
			return record["id"]
	assert(false, "Missing %s lot" % kind)
	return -1


func _press(parent: Node, text: String) -> void:
	var button := _button(parent, text)
	assert(button != null and not button.disabled, "Unavailable button: " + text)
	button.pressed.emit()


func _button(parent: Node, text: String) -> Button:
	for node in parent.get_children():
		if node is Button and node.text == text:
			return node
		var found := _button(node, text)
		if found != null:
			return found
	return null


func _project(game, point: Vector3) -> Vector2:
	return game.cam.cam.unproject_position(point)


func _build_room(game) -> void:
	var corners := [Vector3(13, 0, 15), Vector3(23, 0, 15), Vector3(23, 0, 23), Vector3(13, 0, 23)]
	game.tool = "wall"
	for i in corners.size():
		game._click_build(_project(game, corners[i]))
		game._release(_project(game, corners[(i + 1) % corners.size()]))
	game.tool = "door"
	game._click_build(_project(game, Vector3(18.5, 0, 23.04)))


func _check_visitor(game) -> void:
	var visitor: Person = game.neighbours[0]
	visitor.start_visit(true)
	for tick in 120:
		visitor.tick(1.0 / 60.0, 1.0)
		if visitor.vstate == "waiting":
			break
	assert(visitor.vstate == "waiting" and visitor.world == game.world)
	assert(visitor.tile == game.world.door_tile)
	visitor.leave()


func _place(game, kind: String, position: Vector3) -> void:
	game.set_buy(kind)
	game._click_buy(_project(game, position))


func _check_skip(game) -> void:
	game.set_speed(1)
	for person in game.people:
		person.away = true
	game._update_away_speed()
	assert(game.speed == 3)
	game.people[0].away = false
	game._update_away_speed()
	assert(game.speed == 1)
	game.people[0].away = true
	game._update_away_speed()
	game.set_speed(2)
	game._update_away_speed()
	assert(game.speed == 2)
	game.set_speed(0)
	game._update_away_speed()
	assert(game.speed == 0)
	for person in game.people:
		person.away = false


signal card_checked


func _check_card(game) -> void:
	game.ui.tab_btns["needs"].pressed.emit()
	for frame in 4:
		await process_frame
	await create_timer(0.25).timeout
	var y := -1.0
	for tab in UI.CARD_TABS:
		if tab != "needs":
			game.ui.tab_btns[tab].pressed.emit()
		for frame in 3:
			await process_frame
		var current: float = game.ui.tab_btns[tab].global_position.y
		print("Card tab ", tab, " y=", current)
		assert(y == -1.0 or is_equal_approx(y, current))
		y = current
	card_checked.emit()


func _check_town_round_trip(game) -> void:
	var clock: float = game.minutes
	var balance: int = game.money
	var roster: Array = game.people.duplicate()
	game.return_to_town()
	game._process(20.0)
	assert(game.town_view.selected == game.town.lot_of(0)["id"])
	_press(game.town_ui.card, "Play")
	assert(game.screen == "lot" and game.minutes == clock and game.money == balance and game.people == roster)
	print("PASS: simulation paused in Build and Town, speed restored, card tabs held their position")


func _check_migration(game, state: Dictionary) -> void:
	var old := state.duplicate(true)
	old.erase("town")
	old.erase("career_catalog")
	old["people"][0]["job"] = {"career": 2, "level": 3, "perf": 80}
	old["people"][1]["job"] = {"career": 4, "level": 2, "perf": 40}
	old["households"][0]["world"]["objects"].append({"k": "easel", "x": 10, "y": 10, "r": 0, "s": 4})
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var migrated: Dictionary = game._read_save()
	assert(int(migrated["households"][0]["money"]) == game.money + 350)
	assert(migrated["households"][0]["world"]["objects"].size() == game.world.objects.size())
	assert(migrated["people"][0]["job"]["level"] == 0)
	assert(Defs.CAREERS[int(migrated["people"][1]["job"]["career"])]["name"] == "Business")
	print("PASS: legacy catalogue refund and career migration")


func _check_vacant(rental: bool) -> void:
	var game = await _boot()
	game.creator._finish()
	var id := _find_lot(game, "vacant")
	game.household_draft["money"] = 0
	game._select_town_lot(id)
	assert(_button(game.town_ui.card, "Rent").disabled and _button(game.town_ui.card, "Buy home").disabled)
	game.claim_home(id, rental)
	assert(game.town.lot_of(0) == null)
	game.household_draft["money"] = Defs.START_FUNDS
	game._select_town_lot(id)
	var value: int = game._describe_lot(game.town.lot(id))["value"]
	var rent := Household.rent_for(value)
	_press(game.town_ui.card, "Rent" if rental else "Buy home")
	assert(game.world.value() == value)
	assert(game.money == Defs.START_FUNDS - (rent if rental else value))
	assert(game.home.rent == (rent if rental else 0))
	assert(game.home.tenure == ("rent" if rental else "own"))
	if rental:
		var balance: int = game.money
		var enclosed: Dictionary = game.world.walls.duplicate()
		var furniture: SimObject = game.world.objects[0]
		var location := furniture.position + Vector3(0, furniture.def["h"] * 0.5, 0)
		game.set_mode("build")
		assert(game.mode == "live")
		game.tool = "wall"
		game._click_build(_project(game, Vector3(2, 0, 2)))
		game._release(_project(game, Vector3(6, 0, 2)))
		assert(game.world.walls == enclosed)
		game.set_mode("buy")
		game.sell = true
		assert(furniture.included)
		game._click_buy(_project(game, location))
		assert(game.money == balance and furniture.alive)
		_place(game, "sculpture", Vector3(3.5, 0, 3.5))
		var purchase: SimObject = game.world.object_at(Vector2i(3, 3))
		assert(purchase != null and not purchase.included)
		game.sell = true
		game._click_buy(_project(game, purchase.position + Vector3(0, 0.4, 0)))
		assert(not purchase.alive)
		game.save_game(true)
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		assert(saved["households"][0]["world"]["objects"].all(func(object): return object["included"]))
	var bill := 25 * int(game.people.size())
	var object_value := 0
	for object in game.world.objects:
		object_value += int(object.def["price"])
	bill += int(object_value * 0.03)
	game.money = 0
	game.minutes = 3 * 1440.0
	game._new_day()
	assert(game.money == -bill - (rent if rental else 0))
	if rental:
		var toast: Control = game.ui.toasts.get_child(game.ui.toasts.get_child_count() - 1)
		assert(toast.get_child(0).text == "You are behind on rent.")
	game.free()
	print("PASS: ", "rental deposit, protected furnishings, bills and arrears" if rental else "home purchase and bills")


func _check_restart_routes() -> void:
	var game = await _boot(true)
	game.set_screen("lot")
	game.ui._on_option(5)
	await scene_changed
	assert(current_scene.screen == "create" and current_scene.people.is_empty())
	current_scene.free()
	game = await _boot(true)
	game.set_screen("lot")
	game.over = true
	game.ui.show_game_over()
	_press(game.ui.over_panel, "Start a new household")
	await scene_changed
	assert(current_scene.screen == "create" and current_scene.people.is_empty())
	print("PASS: menu and game-over restart routes open the creator")
