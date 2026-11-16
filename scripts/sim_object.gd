class_name SimObject
extends Node3D
## A placed object on the lot grid.

var kind := ""
var def := {}
var tile := Vector2i.ZERO  # min corner of the footprint
var rot := 0
var users: Array = []  # fixed-size, null = free slot
var alive := true
var oseed := 0
var label := ""  # e.g. whose memorial this is


func setup(k: String, t: Vector2i, r: int, seed_v: int) -> void:
	oseed = seed_v
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	kind = k
	def = Defs.OBJECTS[k]
	tile = t
	rot = r
	users.resize(capacity())
	Meshes.build_object(self, k, rng)
	var d := dims()
	position = Vector3(t.x + d.x / 2.0, 0, t.y + d.y / 2.0)
	rotation.y = -r * PI / 2.0


func dims() -> Vector2i:
	var s: Vector2i = def["size"]
	return Vector2i(s.y, s.x) if rot % 2 == 1 else s


func footprint() -> Array:
	var out := []
	var d := dims()
	for y in d.y:
		for x in d.x:
			out.append(tile + Vector2i(x, y))
	return out


func capacity() -> int:
	return maxi(1, maxi(def.get("slots", []).size(), def.get("cap", 1)))


func has_room(p = null) -> bool:
	return users.has(p) or users.has(null)


func in_use() -> bool:
	for u in users:
		if u != null:
			return true
	return false


func claim(p) -> int:
	var i := users.find(p)
	if i >= 0:
		return i
	i = users.find(null)
	if i >= 0:
		users[i] = p
	return i


func release(p) -> void:
	var i := users.find(p)
	if i >= 0:
		users[i] = null


## World position of a slot (y = seat / surface height).
func slot_pos(i: int) -> Vector3:
	var slots: Array = def.get("slots", [])
	if slots.is_empty():
		return position
	return position + Basis(Vector3.UP, rotation.y) * slots[clampi(i, 0, slots.size() - 1)]


func interaction(id: String):
	for it in def.get("acts", []):
		if it["id"] == id:
			return it
	return null
