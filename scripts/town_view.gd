class_name TownView
extends Node3D
## Street geometry, lot selection and the town camera.

signal lot_picked(id: int)

const WIDTH := 7.0
const DEPTH := 8.0
const GRASS := Color("688147")
const HIGHLIGHT := Color("8d9f52")
const SELECTED := Color("a1a355")

var rig: Cam
var scenery: Node3D
var plates := {}
var bounds := {}
var windows: Array[MeshInstance3D] = []
var selected := -1
var hovered := -1


func _ready() -> void:
	rig = Cam.new()
	rig.position = Vector3(18, 0, 15)
	rig.yaw = 0.12
	rig.pitch = 1.13
	rig.dist = 54.0
	add_child(rig)


func rebuild(town: Town, households: Dictionary, homes: Dictionary, night: bool) -> void:
	if scenery != null:
		scenery.free()
	scenery = Node3D.new()
	add_child(scenery)
	plates.clear()
	bounds.clear()
	windows.clear()
	hovered = -1
	var street_width := maxf(50.0, ceilf(town.lots.size() / 2.0) * WIDTH + 10.0)
	Meshes.box(scenery, Vector3(street_width + 140.0, 0.12, 140), Vector3(18, -0.16, 15), Color("59714a"))
	Meshes.box(scenery, Vector3(street_width, 0.08, 4.8), Vector3(18, -0.04, 15), Color("47555d"))
	for z in [11.9, 18.1]:
		Meshes.box(scenery, Vector3(street_width, 0.10, 1.0), Vector3(18, -0.035, z), Color("b7b2a1"))
	for x in range(-6, int(street_width) - 15, 4):
		Meshes.box(scenery, Vector3(1.4, 0.02, 0.09), Vector3(x, 0.007, 15), Color("d9c99f"))
	var ordered := town.by_slot()
	var columns := 5 if ordered.is_empty() else maxi(5, int(ordered.back()["slot"]) / 2 + 1)
	for record in ordered:
		_draw_lot(record, households, homes, columns)
	set_night(night)
	_recolour()


func _draw_lot(record: Dictionary, households: Dictionary, homes: Dictionary, columns: int) -> void:
	var slot: int = record["slot"]
	var id: int = record["id"]
	var south := slot % 2 == 1
	var x := 18.0 + (slot / 2 - (columns - 1) / 2.0) * WIDTH
	var z := 23.1 if south else 6.9
	var base := Vector3(x, 0, z)
	bounds[id] = Rect2(Vector2(x - WIDTH / 2, z - DEPTH / 2), Vector2(WIDTH, DEPTH))
	var yard := Node3D.new()
	scenery.add_child(yard)
	yard.position = base
	plates[id] = Meshes.box(yard, Vector3(WIDTH - 0.18, 0.14, DEPTH - 0.16), Vector3(0, -0.025, 0), GRASS)
	var facing := -1.0 if south else 1.0
	var description: Dictionary = homes.get(id, {})
	var label := "For sale" if record["kind"] == "empty" else "To let"
	if record["kind"] == "home":
		var household: Household = households.get(record["household"])
		if household != null:
			label = household.family
	if description.get("house", Rect2i()).has_area():
		var rect: Rect2i = description["house"]
		var size := Vector2(clampf(rect.size.x * 0.27, 2.7, 5.8), clampf(rect.size.y * 0.27, 2.3, 4.8))
		_draw_house(yard, size, description["colour"], facing, record["kind"] == "home")
	var tag := Label3D.new()
	tag.text = label
	tag.font_size = 46
	tag.outline_size = 11
	tag.pixel_size = 0.014
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 0.75, 3.0 * facing)
	yard.add_child(tag)


func _draw_house(yard: Node3D, size: Vector2, colour: Color, facing: float, occupied: bool) -> void:
	Meshes.box(yard, Vector3(size.x, 1.65, size.y), Vector3(0, 0.86, 0), colour)
	var roof_size := size + Vector2(0.24, 0.24)
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left := -roof_size.x / 2.0
	var right := -left
	var front := roof_size.y / 2.0
	var back := -front
	var a := Vector3(left, 1.67, front)
	var b := Vector3(right, 1.67, front)
	var c := Vector3(right, 1.67, back)
	var d := Vector3(left, 1.67, back)
	var e := Vector3(left, 2.5, 0)
	var f := Vector3(right, 2.5, 0)
	for vertex in [a, e, f, a, f, b, d, c, f, d, f, e, a, d, e, b, f, c]:
		roof.add_vertex(vertex)
	roof.generate_normals()
	var roof_node := MeshInstance3D.new()
	roof_node.mesh = roof.commit()
	roof_node.material_override = Meshes.mat(Color("4c4549"))
	yard.add_child(roof_node)
	var wall := facing * (size.y / 2.0 + 0.03)
	Meshes.box(yard, Vector3(0.42, 0.9, 0.09), Vector3(0, 0.48, wall), Color("6d5446"))
	for wall_z in [wall, -wall]:
		for x in [-size.x * 0.3, size.x * 0.3]:
			var pane := Meshes.box(yard, Vector3(0.62, 0.45, 0.1), Vector3(x, 1.05, wall_z), Color("638190"))
			if occupied:
				windows.append(pane)
	var drive_depth := 4.0 - size.y / 2.0
	Meshes.box(yard, Vector3(0.63, 0.04, drive_depth), Vector3(0, 0.047, facing * (4.0 - drive_depth / 2.0)), Color("c2bba8"))


func set_night(night: bool) -> void:
	var material := Meshes.mat(Color("ffc56b"), 2.0) if night else Meshes.mat(Color("638190"))
	for pane in windows:
		pane.material_override = material


func select(id: int) -> void:
	selected = id
	_recolour()


func _recolour() -> void:
	for id in plates:
		var shade := SELECTED if id == selected else (HIGHLIGHT if id == hovered else GRASS)
		plates[id].material_override = Meshes.mat(shade)


func lot_at(mouse: Vector2) -> int:
	var origin := rig.cam.project_ray_origin(mouse)
	var direction := rig.cam.project_ray_normal(mouse)
	var ground = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	if ground != null:
		for id in bounds:
			if bounds[id].has_point(Vector2(ground.x, ground.z)):
				return id
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var id := lot_at(event.position)
		if hovered != id:
			hovered = id
			_recolour()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := lot_at(event.position)
		if id >= 0:
			lot_picked.emit(id)
			get_viewport().set_input_as_handled()
