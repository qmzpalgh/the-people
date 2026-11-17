class_name TownView
extends Node3D
## The town as a place: a street with one plate per lot, drawn from the Town record.
## Lots sit on both sides of the road, in slot order, so slots 0 and 1 face each other.

const PITCH := 42.0       # distance along the street from one lot to the next
const ROAD := 7.0
const WALK := 2.0
const BOTH := 2           # lots across from each other

var town: Town
var cam: Cam
var plates := {}          # lot id -> the plate's node


func _init(t: Town = null) -> void:
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
	cam.pitch = 1.0
	cam.dist = clampf(length * 1.3, 60.0, 250.0)
	cam.max_dist = 260.0
	cam.min_pos = Vector2(-20.0, -40.0)
	cam.max_pos = Vector2(length, 40.0)
	add_child(cam)
	cam.position = Vector3(mid, 0, 0)
	if OS.has_environment("TP_SHOT"):
		print("town view: %d plates for %d lots" % [plates.size(), town.lots.size()])


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
