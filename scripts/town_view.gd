class_name TownView
extends Node3D
## The town as a place: a street with one plate per lot, drawn from the Town record.
## Lots sit on both sides of the road, in slot order, so slots 0 and 1 face each other.

const PITCH := 42.0       # distance along the street from one lot to the next
const ROAD := 7.0
const WALK := 2.0
const BOTH := 2           # lots across from each other

var game: Node            # the Main node, for its households
var town: Town
var cam: Cam
var plates := {}          # lot id -> the plate's node
var houses := {}          # lot id -> the house's node, for home and vacant lots


func _init(g: Node = null, t: Town = null) -> void:
	game = g
	town = t


func _ready() -> void:
	var cols := ceili(town.lots.size() / float(BOTH))
	var length := cols * PITCH
	var mid := length / 2.0 - PITCH / 2.0
	_street(length, mid)
	for l in town.lots:
		_plate(l)
	cam = Cam.new()
	cam.yaw = 0.0
	cam.pitch = 0.75
	cam.dist = clampf(length * 1.3, 60.0, 250.0)
	cam.max_dist = 260.0
	cam.min_pos = Vector2(-20.0, -40.0)
	cam.max_pos = Vector2(length, 40.0)
	add_child(cam)
	cam.position = Vector3(mid, 0, 0)
	if OS.has_environment("TP_SHOT"):
		print("town view: %d plates for %d lots, %d houses for %d home and vacant lots" % [plates.size(), town.lots.size(), houses.size(), town.lots.filter(func(l): return l["kind"] != "empty").size()])


## Where a lot's top-left corner sits. Even slots are on the north side of the road.
static func origin(l: Dictionary) -> Vector3:
	var s: int = l["slot"]
	var x := (s / BOTH) * PITCH
	var side := ROAD / 2.0 + WALK
	if s % BOTH == 0:
		return Vector3(x - World.W / 2.0, 0, -side - World.H)
	return Vector3(x - World.W / 2.0, 0, side)


func _street(length: float, mid: float) -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(length + 300.0, 300.0)
	ground.mesh = pm
	ground.position = Vector3(mid, -0.03, 0)
	var gm := Meshes.tex_mat("grass", Color.WHITE, 1, 100.0)
	gm.albedo_color = Color(0.82, 0.88, 0.8)
	ground.material_override = gm
	add_child(ground)
	var w := length + 120.0
	Meshes.box(self, Vector3(w, 0.04, ROAD), Vector3(mid, 0.0, 0), Color(0.2, 0.2, 0.22))
	var walk := Color(0.72, 0.72, 0.7)
	for s in [-1.0, 1.0]:
		Meshes.box(self, Vector3(w, 0.06, WALK), Vector3(mid, 0.0, s * (ROAD + WALK) / 2.0), walk)
	for i in int(w / 4.0):
		Meshes.box(self, Vector3(1.6, 0.045, 0.15), Vector3(mid - w / 2.0 + i * 4.0 + 2.0, 0.0, 0), Color(0.9, 0.85, 0.5))


## One lot's plate: lawn the size of a real lot, with a hedge along the sides and back.
## Empty lots are bare earth, so they read as land for sale from across the street.
func _plate(l: Dictionary) -> void:
	var n := Node3D.new()
	n.name = "Lot%d" % l["id"]
	n.position = origin(l)
	add_child(n)
	var lawn := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(World.W, World.H)
	lawn.mesh = pm
	lawn.position = Vector3(World.W / 2.0, 0.01, World.H / 2.0)
	if l["kind"] == "empty":
		lawn.material_override = Meshes.mat(Color(0.62, 0.55, 0.4))
	else:
		lawn.material_override = Meshes.tex_mat("grass", Color.WHITE, int(l["seed"]), World.W / 4.0)
	n.add_child(lawn)
	var hedge := Meshes.LEAF.darkened(0.25)
	var north: bool = l["slot"] % BOTH == 0
	var back: float = 0.0 if north else float(World.H)
	Meshes.box(n, Vector3(World.W + 0.6, 0.5, 0.3), Vector3(World.W / 2.0, 0.25, back + (-0.15 if north else 0.15)), hedge)
	Meshes.box(n, Vector3(0.3, 0.5, World.H), Vector3(-0.15, 0.25, World.H / 2.0), hedge)
	Meshes.box(n, Vector3(0.3, 0.5, World.H), Vector3(World.W + 0.15, 0.25, World.H / 2.0), hedge)
	plates[l["id"]] = n
	var look := _look(l)
	if not look.is_empty():
		houses[l["id"]] = _house(n, look["house"], look["color"], l["slot"] % BOTH != 0)


## The footprint and wall colour of the house on a lot, or {} for bare land. A home reads
## its household's own world. A vacant house is built again from its seed in a throwaway
## headless World, which has its own rng and is freed at once, so nothing else moves.
func _look(l: Dictionary) -> Dictionary:
	if l["kind"] == "home":
		var w: World = game.households[l["household"]].world
		return {"house": w.house, "color": w.wall_color}
	if l["kind"] == "vacant":
		var w := World.new()
		w.headless = true
		w.setup(int(l["seed"]))
		var out := {"house": w.house, "color": w.wall_color}
		w.free()
		return out
	return {}


## A block house with a roof and a door, in the style of the houses across the road in a lot.
## The lot's front is on its high-z side; a plate on the south of the road is turned round
## so that its front faces the street.
func _house(plate: Node3D, r: Rect2i, wall: Color, turn: bool) -> Node3D:
	var hs := Node3D.new()
	hs.position = Vector3(World.W / 2.0, 0, World.H / 2.0)
	if turn:
		hs.rotation.y = PI
	plate.add_child(hs)
	var bw := float(r.size.x)
	var bd := float(r.size.y)
	var bh := 3.2
	var c := Vector3(r.position.x + bw / 2.0 - World.W / 2.0, 0, r.position.y + bd / 2.0 - World.H / 2.0)
	Meshes.box(hs, Vector3(bw, bh, bd), c + Vector3(0, bh / 2.0, 0), wall)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(bw + 0.8, 2.4, bd + 0.8)
	roof.mesh = pr
	roof.position = c + Vector3(0, bh + pr.size.y / 2.0, 0)
	roof.material_override = Meshes.mat(Color.from_hsv(0.04, 0.5, 0.45))
	hs.add_child(roof)
	Meshes.box(hs, Vector3(1.0, 2.1, 0.1), c + Vector3(0, 1.05, bd / 2.0 + 0.03), Meshes.WOOD.darkened(0.2))
	for wx in [-bw * 0.32, bw * 0.32]:
		Meshes.box(hs, Vector3(1.2, 1.1, 0.1), c + Vector3(wx, 1.7, bd / 2.0 + 0.03), Color(0.6, 0.8, 0.95))
	return hs
