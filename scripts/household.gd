class_name Household
extends RefCounted
## A family unit: its own lot, its own money. The player's household is id 0 and its lot
## is the one on screen; every other household's lot is simulated without being drawn.

var id := 0
var family := ""
var world: World
var money := 2500
var player := false
var tenure := "own"
var rent := 0


static func rent_for(value: int) -> int:
	return maxi(1, roundi(value * Defs.RENT_RATE))
