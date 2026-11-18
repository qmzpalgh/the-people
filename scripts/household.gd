class_name Household
extends RefCounted
## A family unit: its own lot, its own money. The player's household is id 0 and its lot
## is the one on screen; every other household's lot is simulated without being drawn.

var id := 0
var family := ""
var world: World
var money := 2500
var player := false
## True once this household has been shown the build-session hint for a bare lot, so it is
## shown only once. Saved as the optional key "build_hint".
var build_hint := false
## "own" or "rent". A renter pays `rent` with every three-day bill: a share of the home's
## value (Defs.RENT_SHARE), fixed at move-in so the furniture they buy does not raise it.
## Both are saved as optional keys.
var tenure := "own"
var rent := 0
