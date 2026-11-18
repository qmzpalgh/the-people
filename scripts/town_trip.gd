class_name TownTrip
extends Node
## Test driver for TP_TOWN_TRIP: from the lot, goes to the town through the Town button's
## callback, waits, comes back through Play, and prints what the game looked like on each
## side so the two can be compared.

var game: Node
var _f := 0
var _before := ""


func _init(g: Node = null) -> void:
	game = g


func _record() -> String:
	var folk: Array = game.people.map(func(p): return "%s@%s" % [p.pname, p.tile])
	return "minutes %.3f money %d people %s" % [game.minutes, game.households[0].money, folk]


func _process(_dt: float) -> void:
	_f += 1
	if _f == 30:
		_before = _record()
		print("trip before: ", _before)
		game.go_town()
	elif _f == 60:
		print("trip in town: screen ", game.screen, ", speed ", game.speed, ", card ", game.town_view.hud.title)
		game.town_view.hud.play_btn.pressed.emit()
		var after := _record()
		print("trip after:  ", after)
		print("trip same: ", after == _before, ", screen ", game.screen, ", speed ", game.speed)
		print("trip save file exists: ", FileAccess.file_exists(game.save_path), " (", game.save_path, ")")
