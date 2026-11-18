class_name World
extends Node3D
## The lot: tile grid, walls on tile edges, floors, objects, pathfinding, and the
## procedural house / garden / neighbourhood generators.

const W := 36
const H := 30
const WALL_H := 2.7

var rng := RandomNumberGenerator.new()
var floors := PackedInt32Array()
## Vector3i(x, y, 0) = north edge of tile (x,y); Vector3i(x, y, 1) = west edge.
## Value: 1 wall, 2 door, 3 window.
var walls := {}
var occ := {}   # Vector2i -> solid SimObject
var soft := {}  # Vector2i -> walk-through SimObject (puddles)
var objects: Array = []
var astar := AStar2D.new()
var nav_dirty := true
var room_of := PackedInt32Array()
var room_scores := {}
var outside_room := 0
var walls_up := false
## Headless lots are fully simulated but build no meshes, materials or scenery.
var headless := false
var night := false
var door_tile := Vector2i.ZERO
var exit_tile := Vector2i.ZERO
var house := Rect2i()
var rooms: Array = []  # [{rect: Rect2i, type: String}]
var wall_color := Color.WHITE

var _wall_root: Node3D
var _floor_root: Node3D
var _obj_root: Node3D
var _floor_mats: Array = []


## Builds the lot from saved `data`, or generates it from `seed_v`. With `empty`, a new
## lot is lawn only: no house and no garden, just an entry tile at the kerb (see _gen_empty).
func setup(seed_v: int, data = null, empty := false) -> void:
	rng.seed = seed_v
	floors.resize(W * H)
	room_of.resize(W * H)
	_floor_root = Node3D.new()
	add_child(_floor_root)
	_wall_root = Node3D.new()
	add_child(_wall_root)
	_obj_root = Node3D.new()
	add_child(_obj_root)
	if not headless:
		for i in Defs.FLOORS.size():
			var f: Dictionary = Defs.FLOORS[i]
			_floor_mats.append(Meshes.tex_mat(f["tex"], f["tint"], seed_v + i) if f.has("tex") else null)
		_build_scenery(seed_v)
	if data != null:
		load_state(data)
	elif empty:
		_gen_empty()
	else:
		for attempt in 40:
			_clear()
			_gen_house()
			if _validate():
				break
		_gen_garden()
	rebuild_walls()
	rebuild_floors()
	nav_dirty = true


# ---------------------------------------------------------------- grid helpers

func inb(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H


func idx(t: Vector2i) -> int:
	return t.y * W + t.x


func tile_center(t: Vector2i) -> Vector3:
	return Vector3(t.x + 0.5, 0, t.y + 0.5)


func tile_at(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


func walkable(t: Vector2i) -> bool:
	return inb(t) and not occ.has(t)


func edge_between(a: Vector2i, b: Vector2i) -> Vector3i:
	if b.x > a.x:
		return Vector3i(b.x, b.y, 1)
	if b.x < a.x:
		return Vector3i(a.x, a.y, 1)
	if b.y > a.y:
		return Vector3i(b.x, b.y, 0)
	return Vector3i(a.x, a.y, 0)


## True if a wall or window separates two orthogonally adjacent tiles.
func blocked(a: Vector2i, b: Vector2i) -> bool:
	var w: int = walls.get(edge_between(a, b), 0)
	return w == 1 or w == 3


# ---------------------------------------------------------------- objects

func kind_dims(kind: String, r: int) -> Vector2i:
	var s: Vector2i = Defs.OBJECTS[kind]["size"]
	return Vector2i(s.y, s.x) if r % 2 == 1 else s


func can_place(kind: String, x: int, y: int, r: int) -> bool:
	var d := kind_dims(kind, r)
	for ty in range(y, y + d.y):
		for tx in range(x, x + d.x):
			var t := Vector2i(tx, ty)
			if not inb(t) or occ.has(t) or soft.has(t):
				return false
			if tx > x and walls.get(Vector3i(tx, ty, 1), 0) != 0:
				return false
			if ty > y and walls.get(Vector3i(tx, ty, 0), 0) != 0:
				return false
	return true


func add_object(kind: String, x: int, y: int, r: int, oseed := -1) -> SimObject:
	var o := SimObject.new()
	o.setup(kind, Vector2i(x, y), r, oseed if oseed >= 0 else int(rng.randi()), not headless)
	_obj_root.add_child(o)
	var d: Dictionary = soft if o.def.get("soft", false) else occ
	for t in o.footprint():
		d[t] = o
	objects.append(o)
	var l := o.get_node_or_null("Light")
	if l != null:
		l.visible = night
	nav_dirty = true
	return o


func remove_object(o: SimObject) -> void:
	if not o.alive:
		return
	o.alive = false
	for t in o.footprint():
		if occ.get(t) == o:
			occ.erase(t)
		if soft.get(t) == o:
			soft.erase(t)
	objects.erase(o)
	o.queue_free()
	nav_dirty = true


func object_at(t: Vector2i):
	if occ.has(t):
		return occ[t]
	return soft.get(t)


func nearest_object(kind: String, from: Vector2i):
	var best = null
	var bd := 1e9
	for o in objects:
		if o.kind == kind:
			var d := Vector2(o.tile - from).length()
			if d < bd:
				bd = d
				best = o
	return best


func set_night(n: bool) -> void:
	night = n
	for o in objects:
		var l = o.get_node_or_null("Light")
		if l != null:
			l.visible = n


# ---------------------------------------------------------------- navigation

func ensure_nav() -> void:
	if not nav_dirty:
		return
	nav_dirty = false
	astar.clear()
	astar.reserve_space(W * H)
	for y in H:
		for x in W:
			astar.add_point(y * W + x, Vector2(x, y))
	for y in H:
		for x in W:
			var t := Vector2i(x, y)
			if occ.has(t):
				astar.set_point_disabled(idx(t))
			var r := Vector2i(x + 1, y)
			var d := Vector2i(x, y + 1)
			var rd := Vector2i(x + 1, y + 1)
			var r_ok := x + 1 < W and not blocked(t, r)
			var d_ok := y + 1 < H and not blocked(t, d)
			if r_ok:
				astar.connect_points(idx(t), idx(r))
			if d_ok:
				astar.connect_points(idx(t), idx(d))
			if r_ok and d_ok and not blocked(r, rd) and not blocked(d, rd) \
					and not occ.has(t) and not occ.has(r) and not occ.has(d) and not occ.has(rd):
				astar.connect_points(idx(t), idx(rd))
				astar.connect_points(idx(r), idx(d))
	_compute_rooms()


## Tiles to step through from a to b (excluding a). [] if already there, null if unreachable.
func path(a: Vector2i, b: Vector2i):
	ensure_nav()
	if a == b:
		return []
	if not inb(a) or not inb(b) or occ.has(b):
		return null
	var ids := astar.get_id_path(idx(a), idx(b))
	if ids.is_empty():
		return null
	var out := []
	for i in range(1, ids.size()):
		out.append(Vector2i(ids[i] % W, ids[i] / W))
	return out


func _path_len(p: Array) -> float:
	return float(p.size())


## Walkable tiles next to an object from which it can be used, front side first.
func access_tiles(o: SimObject) -> Array:
	var fp := o.footprint()
	var front: Vector2i = Defs.FRONT[o.rot]
	var a := []
	var b := []
	for f in fp:
		for d in Defs.FRONT:
			var n: Vector2i = f + d
			if fp.has(n) or not walkable(n) or blocked(f, n):
				continue
			if d == front:
				if not a.has(n):
					a.append(n)
			elif not b.has(n) and not a.has(n):
				b.append(n)
	if o.def.get("soft", false):
		a.append(o.tile)
	return a + b


## Shortest path to any access tile of the object, or null.
func find_access(from: Vector2i, o: SimObject):
	var best = null
	for t in access_tiles(o):
		var p = path(from, t)
		if p != null and (best == null or p.size() < best.size()):
			best = p
	return best


## Shortest path to a tile adjacent to `target` with no wall in between, or null.
func path_near(from: Vector2i, target: Vector2i):
	var best = null
	for d in Defs.FRONT:
		var n: Vector2i = target + d
		if not walkable(n) or blocked(target, n):
			continue
		var p = path(from, n)
		if p != null and (best == null or p.size() < best.size()):
			best = p
	return best


func find_seat(near: Vector2i, who, maxd := 7.0):
	ensure_nav()
	var best = null
	var bd := maxd
	var rid := room_of[idx(near)] if inb(near) else -1
	for o in objects:
		if not o.def.get("seat", false) or not o.has_room(who):
			continue
		if room_of[idx(o.tile)] != rid:
			continue
		var d := Vector2(o.tile - near).length()
		if d < bd:
			bd = d
			best = o
	return best


func random_walkable_near(t: Vector2i, radius: int):
	for i in 12:
		var n := t + Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))
		if walkable(n) and n != t:
			return n
	return null


# ---------------------------------------------------------------- rooms

func _compute_rooms() -> void:
	room_of.fill(-1)
	var next := 0
	for start_i in W * H:
		if room_of[start_i] != -1:
			continue
		room_of[start_i] = next
		var stack := [Vector2i(start_i % W, start_i / W)]
		while not stack.is_empty():
			var t: Vector2i = stack.pop_back()
			for d in Defs.FRONT:
				var n: Vector2i = t + d
				if inb(n) and room_of[idx(n)] == -1 and walls.get(edge_between(t, n), 0) == 0:
					room_of[idx(n)] = next
					stack.append(n)
		next += 1
	outside_room = room_of[0]


func update_room_scores() -> void:
	ensure_nav()
	var area := {}
	var floored := {}
	var decor := {}
	var lit := {}
	for i in W * H:
		var r := room_of[i]
		area[r] = area.get(r, 0) + 1
		if floors[i] != 0:
			floored[r] = floored.get(r, 0) + 1
	for o in objects:
		var r := room_of[idx(o.tile)]
		decor[r] = decor.get(r, 0.0) + o.def.get("room", 0.0)
		if o.def.get("light", false):
			lit[r] = true
	room_scores.clear()
	for r in area:
		if r == outside_room:
			room_scores[r] = 62.0 if not night else 50.0
			continue
		var a: float = area[r]
		var s: float = 40.0 + 10.0 * floored.get(r, 0) / a + clampf(decor.get(r, 0.0) * 60.0 / (a + 10.0), -30.0, 45.0)
		if night and not lit.has(r):
			s -= 15.0
		room_scores[r] = clampf(s, 0.0, 100.0)


func room_score_at(t: Vector2i) -> float:
	if not inb(t):
		return 60.0
	return room_scores.get(room_of[idx(t)], 60.0)


# ---------------------------------------------------------------- rendering

func _wp(c: Vector3, ax: bool, off: float, length: float, y0: float, y1: float, col: Color) -> void:
	if y1 <= y0:
		return
	var size := Vector3(length, y1 - y0, 0.12) if ax else Vector3(0.12, y1 - y0, length)
	var o := Vector3(off, 0, 0) if ax else Vector3(0, 0, off)
	Meshes.box(_wall_root, size, c + o + Vector3(0, (y0 + y1) / 2.0, 0), col)


func rebuild_walls() -> void:
	if headless:
		return
	for c in _wall_root.get_children():
		c.queue_free()
	var h := WALL_H if walls_up else 0.35
	var corners := {}
	var frame := Meshes.WOOD.darkened(0.25)
	var glass := Color(0.65, 0.85, 0.95, 0.4)
	for k in walls:
		var t: int = walls[k]
		var ax: bool = k.z == 0
		var c := Vector3(k.x + 0.5, 0, k.y) if ax else Vector3(k.x, 0, k.y + 0.5)
		corners[Vector2i(k.x, k.y)] = true
		corners[Vector2i(k.x + 1, k.y) if ax else Vector2i(k.x, k.y + 1)] = true
		match t:
			1:
				_wp(c, ax, 0.0, 1.0, 0.0, h, wall_color)
			2:
				var jh := minf(h + 0.1, 2.15)
				_wp(c, ax, -0.42, 0.08, 0.0, jh, frame)
				_wp(c, ax, 0.42, 0.08, 0.0, jh, frame)
				_wp(c, ax, 0.0, 0.84, 0.0, 0.03, frame)
				if walls_up:
					_wp(c, ax, 0.0, 1.0, 2.15, h, wall_color)
			3:
				_wp(c, ax, 0.0, 1.0, 0.0, minf(h, 0.9), wall_color)
				if walls_up:
					_wp(c, ax, 0.0, 0.9, 0.9, 2.0, glass)
					_wp(c, ax, 0.0, 1.0, 2.0, h, wall_color)
				else:
					_wp(c, ax, 0.0, 0.8, h, h + 0.05, glass)
	for k in corners:
		Meshes.box(_wall_root, Vector3(0.12, h, 0.12), Vector3(k.x, h / 2.0, k.y), wall_color)


func rebuild_floors() -> void:
	if headless:
		return
	for c in _floor_root.get_children():
		c.queue_free()
	for f in range(1, Defs.FLOORS.size()):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		for y in H:
			for x in W:
				if floors[y * W + x] != f:
					continue
				any = true
				var v := [Vector3(x, 0.015, y), Vector3(x + 1, 0.015, y), Vector3(x + 1, 0.015, y + 1), Vector3(x, 0.015, y + 1)]
				var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
				for i in [0, 1, 2, 0, 2, 3]:
					st.set_normal(Vector3.UP)
					st.set_uv(uv[i])
					st.add_vertex(v[i])
		if not any:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _floor_mats[f]
		_floor_root.add_child(mi)


func _build_scenery(seed_v: int) -> void:
	var srng := RandomNumberGenerator.new()
	srng.seed = seed_v + 99
	var root := Node3D.new()
	add_child(root)
	# Lot lawn and the wider landscape.
	var lawn := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(W, H)
	lawn.mesh = pm
	lawn.position = Vector3(W / 2.0, 0, H / 2.0)
	lawn.material_override = Meshes.tex_mat("grass", Color.WHITE, seed_v, W / 4.0)
	root.add_child(lawn)
	var land := MeshInstance3D.new()
	var pm2 := PlaneMesh.new()
	pm2.size = Vector2(500, 500)
	land.mesh = pm2
	land.position = Vector3(W / 2.0, -0.03, H / 2.0)
	var lm := Meshes.tex_mat("grass", Color.WHITE, seed_v + 1, 100.0)
	lm.albedo_color = Color(0.82, 0.88, 0.8)
	land.material_override = lm
	root.add_child(land)
	# Hedge around three sides of the lot.
	var hedge := Meshes.LEAF.darkened(0.25)
	Meshes.box(root, Vector3(W + 0.6, 0.5, 0.3), Vector3(W / 2.0, 0.25, -0.15), hedge)
	Meshes.box(root, Vector3(0.3, 0.5, H), Vector3(-0.15, 0.25, H / 2.0), hedge)
	Meshes.box(root, Vector3(0.3, 0.5, H), Vector3(W + 0.15, 0.25, H / 2.0), hedge)
	# Sidewalk and road in front (south).
	Meshes.box(root, Vector3(500, 0.06, 2.0), Vector3(W / 2.0, 0.0, H + 1.0), Color(0.72, 0.72, 0.7))
	Meshes.box(root, Vector3(500, 0.04, 7.0), Vector3(W / 2.0, 0.0, H + 5.5), Color(0.2, 0.2, 0.22))
	for i in range(-30, 31):
		Meshes.box(root, Vector3(1.6, 0.045, 0.15), Vector3(W / 2.0 + i * 4.0, 0.0, H + 5.5), Color(0.9, 0.85, 0.5))
	Meshes.box(root, Vector3(500, 0.06, 2.0), Vector3(W / 2.0, 0.0, H + 10.0), Color(0.72, 0.72, 0.7))
	# Neighbouring houses across the road and beside the lot.
	var spots := []
	for i in range(-4, 6):
		spots.append(Vector3(i * 15.0 + srng.randf_range(-2, 2), 0, H + 18.0 + srng.randf_range(-1, 2)))
	for i in [-3, -2, -1, 4, 5, 6]:
		spots.append(Vector3(i * 15.0, 0, H * 0.45 + srng.randf_range(-3, 3)))
	for s in spots:
		var hs := Node3D.new()
		hs.position = s
		hs.rotation.y = srng.randf_range(-0.08, 0.08)
		root.add_child(hs)
		var bw := srng.randf_range(7.0, 10.0)
		var bd := srng.randf_range(6.0, 8.0)
		var bh := srng.randf_range(3.0, 3.8)
		var col := Color.from_hsv(srng.randf(), 0.2, 0.9)
		Meshes.box(hs, Vector3(bw, bh, bd), Vector3(0, bh / 2.0, 0), col)
		var roof := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(bw + 0.8, srng.randf_range(1.8, 2.8), bd + 0.8)
		roof.mesh = pr
		roof.position = Vector3(0, bh + pr.size.y / 2.0, 0)
		roof.material_override = Meshes.mat(Color.from_hsv(srng.randf_range(0.0, 0.08), 0.5, 0.45))
		hs.add_child(roof)
		Meshes.box(hs, Vector3(1.0, 2.1, 0.1), Vector3(srng.randf_range(-2, 2), 1.05, -bd / 2.0 - 0.03), Meshes.WOOD.darkened(0.2))
		for wx in [-bw * 0.32, bw * 0.32]:
			Meshes.box(hs, Vector3(1.2, 1.1, 0.1), Vector3(wx, 1.7, -bd / 2.0 - 0.03), Color(0.6, 0.8, 0.95))
	# Scattered trees beyond the lot.
	for i in 140:
		var p := Vector3(srng.randf_range(-90, W + 90), 0, srng.randf_range(-70, H + 80))
		if p.x > -3 and p.x < W + 3 and p.z > -3 and p.z < H + 12:
			continue
		if p.z > H - 1 and p.z < H + 12:
			continue
		var near_house := false
		for s in spots:
			if p.distance_to(s) < 8.0:
				near_house = true
		if near_house:
			continue
		var tr := Node3D.new()
		tr.position = p
		var sc := srng.randf_range(0.9, 1.6)
		tr.scale = Vector3(sc, sc, sc)
		root.add_child(tr)
		Meshes.build_object(tr, "tree" if srng.randf() < 0.8 else "bush", srng)


# ---------------------------------------------------------------- generation

func _clear() -> void:
	for o in objects:
		o.free()
	objects.clear()
	occ.clear()
	soft.clear()
	walls.clear()
	rooms.clear()
	floors.fill(0)
	nav_dirty = true


func _shared_edges(a: Rect2i, b: Rect2i) -> Array:
	var out := []
	if a.end.x == b.position.x or b.end.x == a.position.x:
		var x := b.position.x if a.end.x == b.position.x else a.position.x
		for y in range(maxi(a.position.y, b.position.y), mini(a.end.y, b.end.y)):
			out.append(Vector3i(x, y, 1))
	if a.end.y == b.position.y or b.end.y == a.position.y:
		var y := b.position.y if a.end.y == b.position.y else a.position.y
		for x in range(maxi(a.position.x, b.position.x), mini(a.end.x, b.end.x)):
			out.append(Vector3i(x, y, 0))
	return out


func _gen_house() -> void:
	var hw := rng.randi_range(12, 16)
	var hh := rng.randi_range(8, 11)
	var hx := (W - hw) / 2 + rng.randi_range(-3, 3)
	var hy := rng.randi_range(6, 9)
	house = Rect2i(hx, hy, hw, hh)
	wall_color = Color.from_hsv(rng.randf(), 0.16, 0.93)
	# Binary space partition into rooms.
	var rects: Array = [house]
	var want := rng.randi_range(5, 6)
	while rects.size() < want:
		rects.sort_custom(func(a, b): return a.get_area() > b.get_area())
		var done := false
		for i in rects.size():
			var r: Rect2i = rects[i]
			var horiz := r.size.x >= r.size.y
			var dim := r.size.x if horiz else r.size.y
			if dim < 6:
				continue
			var cut := rng.randi_range(3, dim - 3)
			var a: Rect2i
			var b: Rect2i
			if horiz:
				a = Rect2i(r.position, Vector2i(cut, r.size.y))
				b = Rect2i(r.position + Vector2i(cut, 0), Vector2i(r.size.x - cut, r.size.y))
			else:
				a = Rect2i(r.position, Vector2i(r.size.x, cut))
				b = Rect2i(r.position + Vector2i(0, cut), Vector2i(r.size.x, r.size.y - cut))
			rects.remove_at(i)
			rects.append(a)
			rects.append(b)
			done = true
			break
		if not done:
			break
	# Room roles: biggest = living, smallest = bathroom, a living-adjacent one = kitchen.
	rects.sort_custom(func(a, b): return a.get_area() > b.get_area())
	var types := []
	types.resize(rects.size())
	types.fill("bedroom")
	types[0] = "living"
	types[rects.size() - 1] = "bathroom"
	var kitchen := -1
	for i in range(1, rects.size() - 1):
		if not _shared_edges(rects[0], rects[i]).is_empty():
			kitchen = i
			break
	if kitchen == -1:
		kitchen = 1
	types[kitchen] = "kitchen"
	for i in rects.size():
		rooms.append({"rect": rects[i], "type": types[i]})
	# Walls and floors.
	var carpet := 3 if rng.randf() < 0.5 else 6
	var wood := 1 if rng.randf() < 0.5 else 7
	for rm in rooms:
		var r: Rect2i = rm["rect"]
		for x in range(r.position.x, r.end.x):
			walls[Vector3i(x, r.position.y, 0)] = 1
			walls[Vector3i(x, r.end.y, 0)] = 1
		for y in range(r.position.y, r.end.y):
			walls[Vector3i(r.position.x, y, 1)] = 1
			walls[Vector3i(r.end.x, y, 1)] = 1
		var fl := wood
		match rm["type"]:
			"kitchen": fl = 5
			"bathroom": fl = 2
			"bedroom": fl = carpet
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				floors[y * W + x] = fl
	# Interior doors: spanning tree from the living room.
	var keep := {}
	var seen := {0: true}
	var frontier := [0]
	while not frontier.is_empty():
		var a: int = frontier.pop_front()
		for b in rooms.size():
			if seen.has(b):
				continue
			var edges := _shared_edges(rects[a], rects[b])
			if edges.is_empty():
				continue
			seen[b] = true
			frontier.append(b)
			_make_door(edges[rng.randi() % edges.size()], keep)
	# Front door on the south side, preferring the living room.
	var south := house.end.y
	var front := -1
	for i in rooms.size():
		if rects[i].end.y == south and (front == -1 or types[i] == "living"):
			front = i
			if types[i] == "living":
				break
	var fr: Rect2i = rects[front]
	var fx := rng.randi_range(fr.position.x + 1, fr.end.x - 2) if fr.size.x >= 3 else fr.position.x
	_make_door(Vector3i(fx, south, 0), keep)
	door_tile = Vector2i(fx, south)
	exit_tile = Vector2i(fx, H - 1)
	for y in range(south, H):
		floors[y * W + fx] = 4
	# Windows on exterior walls.
	for k in walls.keys():
		if walls[k] != 1:
			continue
		var ext: bool = (k.z == 0 and (k.y == house.position.y or k.y == house.end.y)) \
				or (k.z == 1 and (k.x == house.position.x or k.x == house.end.x))
		if ext and rng.randf() < 0.3:
			walls[k] = 3
	_furnish(keep)


## A bare lot: no house, rooms or garden. The entry is one stone tile on the kerb, in the
## middle of the street side, and stands in for the front door until one is built, so the
## door and the exit are the same tile. Draws nothing from rng.
func _gen_empty() -> void:
	_clear()
	house = Rect2i()
	door_tile = Vector2i(W / 2, H - 1)
	exit_tile = door_tile
	floors[idx(door_tile)] = 4


func _make_door(k: Vector3i, keep: Dictionary) -> void:
	walls[k] = 2
	var a := Vector2i(k.x, k.y)
	keep[a] = true
	keep[a + (Vector2i(0, -1) if k.z == 0 else Vector2i(-1, 0))] = true


## [back edge keys, front tiles] for a footprint at rotation r.
func _back_front(x: int, y: int, d: Vector2i, r: int) -> Array:
	var edges := []
	var fronts := []
	match r:
		0:
			for i in d.x:
				edges.append(Vector3i(x + i, y, 0))
				fronts.append(Vector2i(x + i, y + d.y))
		2:
			for i in d.x:
				edges.append(Vector3i(x + i, y + d.y, 0))
				fronts.append(Vector2i(x + i, y - 1))
		1:
			for i in d.y:
				edges.append(Vector3i(x + d.x, y + i, 1))
				fronts.append(Vector2i(x - 1, y + i))
		3:
			for i in d.y:
				edges.append(Vector3i(x, y + i, 1))
				fronts.append(Vector2i(x + d.x, y + i))
	return [edges, fronts]


## Places an object with its back against a wall of room r, keeping its front tiles clear.
func _place_wall(r: Rect2i, kind: String, keep: Dictionary, need_front := true):
	var cands := []
	for rot in 4:
		var d := kind_dims(kind, rot)
		for y in range(r.position.y, r.end.y - d.y + 1):
			for x in range(r.position.x, r.end.x - d.x + 1):
				if not can_place(kind, x, y, rot):
					continue
				var ok := true
				for ty in range(y, y + d.y):
					for tx in range(x, x + d.x):
						if keep.has(Vector2i(tx, ty)):
							ok = false
				var bf := _back_front(x, y, d, rot)
				for e in bf[0]:
					var w: int = walls.get(e, 0)
					if w != 1 and w != 3:
						ok = false
				if need_front:
					for f in bf[1]:
						if not r.has_point(f) or occ.has(f):
							ok = false
				if ok:
					cands.append([x, y, rot, bf[1]])
	if cands.is_empty():
		return null
	var c: Array = cands[rng.randi() % cands.size()]
	var o := add_object(kind, c[0], c[1], c[2])
	if need_front:
		for f in c[3]:
			keep[f] = true
	return o


func _furnish(keep: Dictionary) -> void:
	var bedrooms := 0
	var extras := ["computer", "easel", "mirror", "weights", "bookshelf"]
	for rm in rooms:
		var r: Rect2i = rm["rect"]
		match rm["type"]:
			"living":
				for k in ["sofa", "tv", "bookshelf", "phone", "armchair", "stereo"]:
					_place_wall(r, k, keep)
				_place_wall(r, "lamp", keep, false)
				_place_wall(r, "plant", keep, false)
			"kitchen":
				for k in ["fridge", "stove", "sink"]:
					_place_wall(r, k, keep)
				for i in 2:
					var t = _place_wall(r, "table", keep)
					if t != null:
						var f: Vector2i = t.tile + Defs.FRONT[t.rot]
						if can_place("chair", f.x, f.y, 0):
							add_object("chair", f.x, f.y, (t.rot + 2) % 4)
							for d in Defs.FRONT:
								keep[f + d] = true
			"bathroom":
				for k in ["toilet", "shower", "sink"]:
					_place_wall(r, k, keep)
			"bedroom":
				_place_wall(r, "bed_double" if bedrooms == 0 else "bed_single", keep)
				if bedrooms > 0 and r.get_area() >= 16:
					_place_wall(r, "bed_single", keep)
				_place_wall(r, extras[bedrooms % extras.size()], keep)
				_place_wall(r, "lamp", keep, false)
				bedrooms += 1
	if nearest_object("computer", Vector2i.ZERO) == null:
		for rm in rooms:
			if _place_wall(rm["rect"], "computer", keep) != null:
				break


func _validate() -> bool:
	nav_dirty = true
	ensure_nav()
	for o in objects.duplicate():
		if o.def.has("acts") and find_access(door_tile, o) == null:
			remove_object(o)
	for k in ["fridge", "stove", "toilet", "shower", "sofa", "bed_double", "computer"]:
		if nearest_object(k, Vector2i.ZERO) == null:
			return false
	var slots := 0
	for o in objects:
		if o.kind.begins_with("bed"):
			slots += o.capacity()
	return slots >= 3


func _gen_garden() -> void:
	var yard := house.grow(1)
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 400:
		tries += 1
		var t := Vector2i(rng.randi_range(0, W - 1), rng.randi_range(0, H - 1))
		if yard.has_point(t) or abs(t.x - door_tile.x) <= 1 or occ.has(t):
			continue
		var kind := "tree"
		var roll := rng.randf()
		if roll > 0.7:
			kind = "flowers"
		elif roll > 0.4:
			kind = "bush"
		add_object(kind, t.x, t.y, rng.randi() % 4)
		placed += 1
	# Flower beds flanking the front door.
	for dx in [-1, 1]:
		var t := door_tile + Vector2i(dx, 0)
		if can_place("flowers", t.x, t.y, 0):
			add_object("flowers", t.x, t.y, 0)


## Empty tiles in rooms of this type that can be walked to from the front door, so
## nobody is put down in a corner that furniture has boxed in.
func free_tiles_in(type: String) -> Array:
	var out := []
	for rm in rooms:
		if rm["type"] != type:
			continue
		var r: Rect2i = rm["rect"]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var t := Vector2i(x, y)
				if not occ.has(t) and path(door_tile, t) != null:
					out.append(t)
	if out.is_empty():
		out.append(door_tile)
	return out


## Where a household moving in is put down: free tiles in the living room, or on a lot with
## no living room, the lawn just inside the entry.
func arrival_tiles() -> Array:
	for rm in rooms:
		if rm["type"] == "living":
			return free_tiles_in("living")
	var out := []
	for dy in range(-2, 1):
		for dx in range(-2, 3):
			var t := door_tile + Vector2i(dx, dy)
			if walkable(t) and path(door_tile, t) != null:
				out.append(t)
	if out.is_empty():
		out.append(door_tile)
	return out


## Moves the front door after building: door_tile becomes the outdoor tile in front of the
## outside door nearest the street, or the kerb entry (exit_tile) when there is none.
## An outside door has an enclosed room on one side (a region that does not reach the edge
## of the lot) and, on the other, the outdoors that the kerb entry is in, reachable on foot
## from it. A door in a free-standing wall has outdoors on both sides and does not count.
## A generated house has exactly one such door, the one the generator made, so this leaves
## it where it is. exit_tile, the kerb entry, never moves. Draws nothing from rng.
func update_front_door() -> void:
	ensure_nav()
	var street := room_of[idx(exit_tile)]
	var open := {}  # regions that reach the edge of the lot: open land, not rooms
	for x in W:
		open[room_of[idx(Vector2i(x, 0))]] = true
		open[room_of[idx(Vector2i(x, H - 1))]] = true
	for y in H:
		open[room_of[idx(Vector2i(0, y))]] = true
		open[room_of[idx(Vector2i(W - 1, y))]] = true
	var best := exit_tile
	var found := false
	for k in walls:
		if walls[k] != 2:
			continue
		var b := Vector2i(k.x, k.y)
		var a := b + (Vector2i(0, -1) if k.z == 0 else Vector2i(-1, 0))
		if not inb(a) or not inb(b):
			continue
		for side in [[a, b], [b, a]]:
			var inside: Vector2i = side[0]
			var o: Vector2i = side[1]
			if room_of[idx(o)] != street or open.has(room_of[idx(inside)]):
				continue
			if o != exit_tile and path(exit_tile, o) == null:
				continue
			if not found or _nearer_street(o, best):
				best = o
				found = true
	door_tile = best


## True if outdoor tile a is nearer the street than b: further south, then nearer the kerb
## entry across, then further west, so the choice never depends on the order of `walls`.
func _nearer_street(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y > b.y
	var da := absi(a.x - exit_tile.x)
	var db := absi(b.x - exit_tile.x)
	if da != db:
		return da < db
	return a.x < b.x


# ---------------------------------------------------------------- persistence

func save_state() -> Dictionary:
	var w := []
	for k in walls:
		w.append([k.x, k.y, k.z, walls[k]])
	var objs := []
	for o in objects:
		objs.append({"k": o.kind, "x": o.tile.x, "y": o.tile.y, "r": o.rot, "s": o.oseed, "label": o.label})
	var rms := []
	for rm in rooms:
		var r: Rect2i = rm["rect"]
		rms.append({"rect": [r.position.x, r.position.y, r.size.x, r.size.y], "type": rm["type"]})
	return {
		"house": [house.position.x, house.position.y, house.size.x, house.size.y],
		"rooms": rms, "door": [door_tile.x, door_tile.y], "exit": [exit_tile.x, exit_tile.y],
		"wall_color": wall_color.to_html(), "floors": Array(floors), "walls": w, "objects": objs,
		"rng": str(rng.state),
	}


func load_state(d: Dictionary) -> void:
	_clear()
	var h: Array = d["house"]
	house = Rect2i(int(h[0]), int(h[1]), int(h[2]), int(h[3]))
	for rm in d["rooms"]:
		var r: Array = rm["rect"]
		rooms.append({"rect": Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])), "type": rm["type"]})
	door_tile = Vector2i(int(d["door"][0]), int(d["door"][1]))
	exit_tile = Vector2i(int(d["exit"][0]), int(d["exit"][1]))
	wall_color = Color.html(d["wall_color"])
	var fl: Array = d["floors"]
	for i in mini(fl.size(), W * H):
		floors[i] = int(fl[i])
	for w in d["walls"]:
		walls[Vector3i(int(w[0]), int(w[1]), int(w[2]))] = int(w[3])
	for o in d["objects"]:
		if Defs.OBJECTS.has(o["k"]):
			var obj := add_object(o["k"], int(o["x"]), int(o["y"]), int(o["r"]), int(o["s"]))
			obj.label = o.get("label", "")
	rng.state = int(d.get("rng", "1"))


## What the lot as it stands would cost to build at build and buy prices.
func value() -> int:
	return value_parts()["total"]


## value() by part: {walls, doors, windows, floors, objects, total}. A door or window goes into
## a wall that is already there, as the build tools charge, so its edge counts a wall as well.
## Grass is free; scenery beyond the lot is not an object and counts nothing.
func value_parts() -> Dictionary:
	var v := {"walls": 0, "doors": 0, "windows": 0, "floors": 0, "objects": 0}
	for k in walls:
		v["walls"] += Defs.WALL_PRICE
		match int(walls[k]):
			2: v["doors"] += Defs.DOOR_PRICE
			3: v["windows"] += Defs.WINDOW_PRICE
	for f in floors:
		v["floors"] += int(Defs.FLOORS[f]["price"])
	for o in objects:
		v["objects"] += int(o.def["price"])
	v["total"] = v["walls"] + v["doors"] + v["windows"] + v["floors"] + v["objects"]
	return v


## Nearest tile to `t` where a 1x1 object can go.
func free_tile_near(t: Vector2i):
	for r in 6:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := t + Vector2i(dx, dy)
				if can_place("grave", n.x, n.y, 0):
					return n
	return null
