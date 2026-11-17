class_name Town
extends RefCounted
## The street, as data: every lot in town and who lives there. No nodes, no drawing.
## A lot is {id, kind, household, seed, slot}:
##   kind       "home" (a household lives there), "vacant" (a house nobody lives in) or
##              "empty" (bare land).
##   household  the household id on a home lot, -1 otherwise.
##   seed       the seed the lot's World is generated from, so the same house can be built
##              again. -1 when it is not known (a neighbour's lot from a save made before towns).
##   slot       the lot's place along the street, 0, 1, 2, ...
## The town has its own rng, so building it never moves a draw in the rest of the game.

const VACANT := 3  # vacant homes in a new town
const EMPTY := 3   # empty lots in a new town

var lots: Array = []
var next_id := 0
var rng := RandomNumberGenerator.new()


func _init(seed_v := 0) -> void:
	rng.seed = seed_v


## A new home lot at the end of the street.
func add_home(household: int, seed_v: int) -> Dictionary:
	return _add("home", household, seed_v)


## Adds the vacant homes and empty lots of a new town, then deals every lot a slot.
func fill(vacant := VACANT, empty := EMPTY) -> void:
	for i in vacant:
		_add("vacant", -1, int(rng.randi()))
	for i in empty:
		_add("empty", -1, int(rng.randi()))
	var slots := range(lots.size())
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = slots[i]
		slots[i] = slots[j]
		slots[j] = t
	for i in lots.size():
		lots[i]["slot"] = slots[i]


## Lots in street order.
func by_slot() -> Array:
	var out := lots.duplicate()
	out.sort_custom(func(a, b): return a["slot"] < b["slot"])
	return out


## The lot a household lives on, or null.
func lot_of(household: int) -> Variant:
	for l in lots:
		if l["kind"] == "home" and l["household"] == household:
			return l
	return null


func lot(id: int) -> Variant:
	for l in lots:
		if l["id"] == id:
			return l
	return null


## A household has gone: its house stays, empty. A house whose seed is not known gets a new
## one, so every vacant lot can be built from its seed.
func vacate(household: int) -> void:
	var l = lot_of(household)
	if l == null:
		return
	l["kind"] = "vacant"
	l["household"] = -1
	if l["seed"] < 0:
		l["seed"] = int(rng.randi())


## A household moves into a vacant home. Returns the lot, or null if it is not vacant.
func take_vacant(id: int, household: int) -> Variant:
	var l = lot(id)
	if l == null or l["kind"] != "vacant":
		return null
	l["kind"] = "home"
	l["household"] = household
	return l


func to_dict() -> Dictionary:
	return {"lots": lots.duplicate(true), "next_id": next_id, "rng": str(rng.state)}


static func from_dict(d: Dictionary) -> Town:
	var t := Town.new()
	for l in d.get("lots", []):
		t.lots.append({"id": int(l["id"]), "kind": str(l["kind"]), "household": int(l["household"]), "seed": int(l["seed"]), "slot": int(l["slot"])})
	t.next_id = int(d.get("next_id", t.lots.size()))
	t.rng.state = int(d.get("rng", "1"))
	return t


func _add(kind: String, household: int, seed_v: int) -> Dictionary:
	var slot := 0
	for l in lots:
		slot = maxi(slot, l["slot"] + 1)
	var l := {"id": next_id, "kind": kind, "household": household, "seed": seed_v, "slot": slot}
	next_id += 1
	lots.append(l)
	return l
