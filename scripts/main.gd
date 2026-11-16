extends Node3D
## Game controller: clock, money, modes (live / buy / build), input and lighting.

const MULT := [0.0, 1.0, 4.0, 12.0]

var world: World
var cam: Cam
var ui: UI
var people: Array = []
var selected: Person
var money := 2500
var minutes := 7.5 * 60.0  # game minutes since day 0, 00:00
var speed := 1
var prev_speed := 1
var mode := "live"
var free_will := true
var rel := {}
var rdt := 0.0
var rng := RandomNumberGenerator.new()

var buy_kind := ""
var buy_rot := 0
var sell := false
var tool := ""
var drag_start = null
var ghost: Node3D
var ghost_plate: MeshInstance3D
var ghost_mat: StandardMaterial3D
var marker: MeshInstance3D

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var _last_day := 0
var _room_t := 0.0
var _light_t := -1.0

var _test_days := 0
var _samples := {}
var _shot := ""
var _frames := 0

var day: int:
	get: return int(minutes / 1440.0)


func hour() -> float:
	return fmod(minutes, 1440.0) / 60.0


func _ready() -> void:
	var seed_v := randi()
	if OS.has_environment("TP_SEED"):
		seed_v = int(OS.get_environment("TP_SEED"))
	rng.seed = seed_v
	get_viewport().gui_embed_subwindows = true
	_build_env()
	world = World.new()
	add_child(world)
	world.setup(seed_v)
	var family := Defs.surname(rng)
	var spots := world.free_tiles_in("living")
	for i in rng.randi_range(2, 3):
		var p := Person.new()
		p.setup(self, world, i, seed_v * 7 + i * 131, family)
		p.tile = spots[rng.randi() % spots.size()]
		p.position = world.tile_center(p.tile)
		p.rotation.y = rng.randf() * TAU
		add_child(p)
		people.append(p)
	for a in people:
		for b in people:
			if a.pid < b.pid:
				rel[_rk(a, b)] = rng.randf_range(5.0, 45.0)
	cam = Cam.new()
	add_child(cam)
	cam.position = Vector3(world.house.get_center().x + 0.5, 0, world.house.get_center().y + 1.0)
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker = MeshInstance3D.new()
	marker.mesh = BoxMesh.new()
	marker.material_override = ghost_mat
	marker.visible = false
	add_child(marker)
	ui = UI.new()
	ui.game = self
	add_child(ui)
	select(people[0])
	world.update_room_scores()
	_update_light(true)
	msg("Welcome, %s family! Click an object to use it, or let them live on their own." % family)
	if OS.has_environment("TP_TEST"):
		_test_days = int(OS.get_environment("TP_TEST"))
		for p in people:
			if p.pid != 0:
				assign_job(p)
	if OS.has_environment("TP_SHOT"):
		_shot = OS.get_environment("TP_SHOT")
		speed = 3
		if OS.has_environment("TP_MODE"):
			set_mode(OS.get_environment("TP_MODE"))
		if OS.has_environment("TP_WALLS"):
			toggle_walls()
		if OS.has_environment("TP_HOUR"):
			minutes = float(OS.get_environment("TP_HOUR")) * 60.0


func _build_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _update_light(force := false) -> void:
	var h := hour()
	if not force and absf(h - _light_t) < 0.05:
		return
	_light_t = h
	var dayf := clampf(sin((h - 5.5) / 13.5 * PI), 0.0, 1.0)
	var soft := pow(dayf, 0.5)
	sun.rotation_degrees = Vector3(-(12.0 + 55.0 * dayf), 40.0 - (h - 12.0) * 9.0, 0)
	sun.light_energy = 1.3 * soft
	sun.light_color = Color(1.0, 0.72, 0.5).lerp(Color(1.0, 0.97, 0.9), dayf)
	sun.visible = soft > 0.02
	env.ambient_light_color = Color(0.34, 0.4, 0.62).lerp(Color(0.75, 0.8, 0.9), soft)
	env.ambient_light_energy = 0.8 + 0.1 * soft
	sky_mat.sky_top_color = Color(0.02, 0.03, 0.09).lerp(Color(0.25, 0.48, 0.85), soft)
	sky_mat.sky_horizon_color = Color(0.08, 0.09, 0.18).lerp(Color(0.68, 0.8, 0.92), soft).lerp(Color(0.95, 0.6, 0.4), (1.0 - dayf) * soft)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.03, 0.05, 0.04).lerp(Color(0.2, 0.3, 0.2), soft)
	var n := soft < 0.35
	if n != world.night:
		world.set_night(n)
		world.update_room_scores()


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	rdt = delta
	if _test_days > 0:
		for i in 240:
			_step(1.0 / 60.0, 1.0)
			if int(minutes) % 60 == 0:
				_sample()
		if day >= _test_days:
			_report()
			get_tree().quit()
			return
	else:
		var m: float = MULT[speed]
		if m > 0.0:
			_step(delta * m / 60.0, delta * m)
	_update_light()
	_update_ghost()
	ui.refresh()
	if _shot != "":
		_frames += 1
		if _frames == 150 and OS.has_environment("TP_SELFTEST"):
			_selftest()
		if _frames == 200:
			get_viewport().get_texture().get_image().save_png(_shot)
			get_tree().quit()


func _step(dh: float, ds: float) -> void:
	minutes += dh * 60.0
	for p in people:
		p.tick(dh, ds)
	var h := hour()
	if day % 7 < 5:
		for p in people:
			if p.job == null or p.away or p.work_flag_day == day:
				continue
			var c: Dictionary = Defs.CAREERS[p.job.career]
			if h >= c["start"] - 1.0 and h < c["start"] + 2.0:
				p.work_flag_day = day
				p.go_to_work()
				msg("%s is heading to work." % p.first())
	_room_t -= dh
	if _room_t <= 0.0:
		_room_t = 0.2
		world.update_room_scores()
	if day != _last_day:
		_last_day = day
		for p in people:
			if p.job != null and (day - 1) % 7 < 5 and p.work_day != day - 1:
				p.job.perf -= 15.0
				msg("%s missed work yesterday." % p.first())
		if day % 3 == 0:
			var value := 0
			for o in world.objects:
				value += o.def["price"]
			var bill := int(value * 0.03) + 25 * people.size()
			money -= bill
			msg("Bills paid: $%d." % bill)


# ---------------------------------------------------------------- game API

func msg(text: String) -> void:
	if _test_days > 0:
		print("[d%d %05.2f] %s" % [day, hour(), text])
	elif ui != null:
		ui.push_msg(text)


func _rk(a: Person, b: Person) -> String:
	return "%d|%d" % [mini(a.pid, b.pid), maxi(a.pid, b.pid)]


func get_rel(a: Person, b: Person) -> float:
	return rel.get(_rk(a, b), 0.0)


func add_rel(a: Person, b: Person, d: float) -> void:
	rel[_rk(a, b)] = clampf(get_rel(a, b) + d, -100.0, 100.0)


func assign_job(p: Person) -> void:
	var best := 0
	var bv := -1.0
	for i in Defs.CAREERS.size():
		var v: float = p.skills[Defs.CAREERS[i]["skill"]] + p.rng.randf() * 2.0
		if v > bv:
			bv = v
			best = i
	p.job = {"career": best, "level": 0, "perf": 0.0}
	var c: Dictionary = Defs.CAREERS[best]
	msg("%s got a job as %s (%s, $%d/day, starts %d:00)." % [p.first(), c["titles"][0], c["name"], c["pay"][0], int(c["start"])])


func remove_object(o: SimObject) -> void:
	for p in people:
		if p.cur != null and (p.cur.get("obj") == o or p.cur.get("seat") == o):
			p.cancel_current()
		p.queue = p.queue.filter(func(a): return a.get("obj") != o)
	world.remove_object(o)


func select(p: Person) -> void:
	if selected != null:
		selected.set_selected(false)
	selected = p
	p.set_selected(true)


func set_speed(s: int) -> void:
	if s == 0 and speed != 0:
		prev_speed = speed
	speed = s


func set_mode(m: String) -> void:
	mode = m
	set_buy("")
	tool = ""
	sell = false
	drag_start = null
	if ui != null:
		ui.build_side()


func set_buy(kind: String) -> void:
	buy_kind = kind
	sell = false
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if kind == "":
		return
	ghost = Node3D.new()
	add_child(ghost)
	Meshes.build_object(ghost, kind, rng)
	var s: Vector2i = Defs.OBJECTS[kind]["size"]
	ghost_plate = Meshes.box(ghost, Vector3(s.x, 0.04, s.y), Vector3(0, 0.03, 0), Color.WHITE)
	ghost_plate.material_override = ghost_mat


func toggle_walls() -> void:
	world.walls_up = not world.walls_up
	world.rebuild_walls()


func cancel_action(p: Person, i: int) -> void:
	if i == 0 and p.cur != null:
		p.cancel_current()
	else:
		var qi := i - (1 if p.cur != null else 0)
		if qi >= 0 and qi < p.queue.size():
			p.queue.remove_at(qi)


# ---------------------------------------------------------------- picking

func _ray_plane(mpos: Vector2, y: float) -> Vector3:
	var o := cam.cam.project_ray_origin(mpos)
	var d := cam.cam.project_ray_normal(mpos)
	if absf(d.y) < 0.0001:
		return Vector3(-999, 0, -999)
	return o + d * ((y - o.y) / d.y)


func pick_tile(mpos: Vector2) -> Vector2i:
	return world.tile_at(_ray_plane(mpos, 0.0))


func pick_person(mpos: Vector2):
	var o := cam.cam.project_ray_origin(mpos)
	var d := cam.cam.project_ray_normal(mpos)
	var best = null
	var bt := 1e9
	for p in people:
		if p.away:
			continue
		for hy in [0.5, 1.0, 1.5]:
			var v: Vector3 = p.position + Vector3(0, hy, 0) - o
			var t := v.dot(d)
			if (v - d * t).length() < 0.4 and t < bt:
				bt = t
				best = p
	return best


func pick_object(mpos: Vector2):
	for y in [1.5, 1.0, 0.5, 0.0]:
		var t := world.tile_at(_ray_plane(mpos, y))
		var o = world.object_at(t)
		if o != null and o.def.get("h", 1.0) >= y:
			return o
	return null


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE: set_speed(prev_speed if speed == 0 else 0)
			KEY_1: set_speed(1)
			KEY_2: set_speed(2)
			KEY_3: set_speed(3)
			KEY_TAB: select(people[(people.find(selected) + 1) % people.size()])
			KEY_R: buy_rot = (buy_rot + 1) % 4
			KEY_F: toggle_walls()
			KEY_ESCAPE:
				set_buy("")
				tool = ""
				sell = false
				drag_start = null
				ui.build_side()
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_click(e.position)
			else:
				_release(e.position)
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			if mode == "live":
				var t := pick_tile(e.position)
				if world.walkable(t) and selected != null:
					selected.enqueue(selected.act_goto(t))
			else:
				set_buy("")
				tool = ""
				sell = false
				drag_start = null
				ui.build_side()
	elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if mode == "build" and tool.begins_with("floor"):
			_paint(e.position)


func _click(mpos: Vector2) -> void:
	match mode:
		"live": _click_live(mpos)
		"buy": _click_buy(mpos)
		"build": _click_build(mpos)


func _click_live(mpos: Vector2) -> void:
	var p = pick_person(mpos)
	var items := []
	if p != null:
		if p == selected or selected == null or selected.away:
			select(p)
			return
		items.append(["Switch to %s" % p.first(), select.bind(p)])
		var r := get_rel(selected, p)
		for sd in Defs.SOCIALS:
			if r >= sd["min_rel"]:
				items.append([sd["label"], selected.enqueue.bind(selected.act_social(p, sd))])
		ui.show_menu("%s  (relationship %+d)" % [p.pname, int(r)], items, mpos)
		return
	var o = pick_object(mpos)
	if o == null or selected == null:
		return
	for it in o.def.get("acts", []):
		if it.get("hidden", false):
			continue
		if it.get("cond", "") == "no_job" and selected.job != null:
			continue
		if it.has("req") and world.nearest_object(it["req"], o.tile) == null:
			continue
		items.append([it["label"], selected.enqueue.bind(selected.act_use(o, it))])
	ui.show_menu(o.def["name"], items, mpos)


func _ghost_anchor(mpos: Vector2) -> Vector2i:
	var d := world.kind_dims(buy_kind, buy_rot)
	var p := _ray_plane(mpos, 0.0)
	return Vector2i(floori(p.x - (d.x - 1) / 2.0), floori(p.z - (d.y - 1) / 2.0))


func _placeable(a: Vector2i) -> bool:
	if not world.can_place(buy_kind, a.x, a.y, buy_rot):
		return false
	var d := world.kind_dims(buy_kind, buy_rot)
	for p in people:
		if not p.away and Rect2i(a, d).has_point(p.tile):
			return false
	return money >= Defs.OBJECTS[buy_kind]["price"]


func _click_buy(mpos: Vector2) -> void:
	if sell:
		var o = pick_object(mpos)
		if o != null and o.kind != "puddle":
			var v := int(o.def["price"] * 0.7)
			remove_object(o)
			money += v
			msg("Sold %s for $%d." % [o.def["name"], v])
		return
	if buy_kind == "":
		return
	var a := _ghost_anchor(mpos)
	if _placeable(a):
		world.add_object(buy_kind, a.x, a.y, buy_rot)
		money -= Defs.OBJECTS[buy_kind]["price"]
		world.update_room_scores()


func _corner(mpos: Vector2) -> Vector2i:
	var p := _ray_plane(mpos, 0.0)
	return Vector2i(clampi(roundi(p.x), 0, World.W), clampi(roundi(p.z), 0, World.H))


func _nearest_edge(mpos: Vector2) -> Vector3i:
	var p := _ray_plane(mpos, 0.0)
	var t := world.tile_at(p)
	var fx := p.x - t.x
	var fy := p.z - t.y
	var m := minf(minf(fx, 1.0 - fx), minf(fy, 1.0 - fy))
	if m == fy:
		return Vector3i(t.x, t.y, 0)
	if m == 1.0 - fy:
		return Vector3i(t.x, t.y + 1, 0)
	if m == fx:
		return Vector3i(t.x, t.y, 1)
	return Vector3i(t.x + 1, t.y, 1)


func _click_build(mpos: Vector2) -> void:
	match tool:
		"wall", "erase":
			drag_start = _corner(mpos)
		"door", "window":
			var k := _nearest_edge(mpos)
			var price: int = Defs.DOOR_PRICE if tool == "door" else Defs.WINDOW_PRICE
			if world.walls.get(k, 0) != 0 and money >= price:
				world.walls[k] = 2 if tool == "door" else 3
				money -= price
				_walls_changed()
		_:
			if tool.begins_with("floor"):
				_paint(mpos)


func _release(mpos: Vector2) -> void:
	if mode != "build" or drag_start == null:
		return
	var a: Vector2i = drag_start
	var b := _corner(mpos)
	drag_start = null
	var keys := []
	if a.x == b.x:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y)):
			keys.append(Vector3i(a.x, y, 1))
	elif a.y == b.y:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x)):
			keys.append(Vector3i(x, a.y, 0))
	for k in keys:
		if tool == "erase":
			world.walls.erase(k)
		elif not world.walls.has(k) and money >= Defs.WALL_PRICE:
			world.walls[k] = 1
			money -= Defs.WALL_PRICE
	if not keys.is_empty():
		_walls_changed()


func _walls_changed() -> void:
	world.rebuild_walls()
	world.nav_dirty = true
	world.update_room_scores()


func _paint(mpos: Vector2) -> void:
	var t := pick_tile(mpos)
	if not world.inb(t):
		return
	var f := int(tool.get_slice(":", 1))
	var price: int = Defs.FLOORS[f]["price"]
	if world.floors[world.idx(t)] != f and money >= price:
		world.floors[world.idx(t)] = f
		money -= price
		world.rebuild_floors()


func _update_ghost() -> void:
	var mpos := get_viewport().get_mouse_position()
	marker.visible = false
	if mode == "buy" and ghost != null:
		var a := _ghost_anchor(mpos)
		var d := world.kind_dims(buy_kind, buy_rot)
		ghost.position = Vector3(a.x + d.x / 2.0, 0, a.y + d.y / 2.0)
		ghost.rotation.y = -buy_rot * PI / 2.0
		ghost_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.45) if _placeable(a) else Color(1.0, 0.2, 0.2, 0.45)
	elif mode == "build" and tool != "":
		marker.visible = true
		ghost_mat.albedo_color = Color(1.0, 0.3, 0.3, 0.6) if tool == "erase" else Color(0.3, 0.8, 1.0, 0.6)
		if tool == "wall" or tool == "erase":
			var c := _corner(mpos)
			var s: Vector2i = drag_start if drag_start != null else c
			if s.x != c.x and s.y != c.y:
				c = s
			marker.position = Vector3((s.x + c.x) / 2.0, 0.6, (s.y + c.y) / 2.0)
			marker.scale = Vector3(absf(s.x - c.x) + 0.25, 1.2, absf(s.y - c.y) + 0.25)
		elif tool == "door" or tool == "window":
			var k := _nearest_edge(mpos)
			marker.position = Vector3(k.x + 0.5, 0.6, k.y) if k.z == 0 else Vector3(k.x, 0.6, k.y + 0.5)
			marker.scale = Vector3(1.0, 1.2, 0.25) if k.z == 0 else Vector3(0.25, 1.2, 1.0)
		else:
			var t := pick_tile(mpos)
			marker.position = Vector3(t.x + 0.5, 0.05, t.y + 0.5)
			marker.scale = Vector3(1.0, 0.06, 1.0)


# ---------------------------------------------------------------- test harness

func _sample() -> void:
	for p in people:
		for n in Defs.NEEDS:
			var k: String = p.first() + "." + n
			var s: Array = _samples.get(k, [0.0, 0, 100.0])
			s[0] += p.needs[n]
			s[1] += 1
			s[2] = minf(s[2], p.needs[n])
			_samples[k] = s


func _report() -> void:
	print("=== %d days simulated, money $%d ===" % [_test_days, money])
	for p in people:
		var line := "%-10s" % p.first()
		for n in Defs.NEEDS:
			var s: Array = _samples[p.first() + "." + n]
			line += " %s avg %2d min %2d |" % [n.substr(0, 4), int(s[0] / s[1]), int(s[2])]
		print(line)
		print("   job: ", p.job, "  skills: ", p.skills)
		print("   actions: ", p.stats)
	print("   relationships: ", rel)


func _selftest() -> void:
	var c := get_viewport().get_visible_rect().size / 2.0
	var lawn := cam.cam.unproject_position(Vector3(3.5, 0, 3.5))
	set_mode("buy")
	for k in Defs.OBJECTS:
		set_buy(k)
		buy_rot = (buy_rot + 1) % 4
		_update_ghost()
	set_buy("sculpture")
	var before := world.objects.size()
	_click_buy(lawn)
	print("selftest buy placed: ", world.objects.size() - before, " money ", money)
	sell = true
	_click_buy(lawn)
	print("selftest sold, objects delta: ", world.objects.size() - before, " money ", money)
	set_mode("build")
	tool = "wall"
	_click_build(cam.cam.unproject_position(Vector3(2, 0, 2)))
	_update_ghost()
	_release(cam.cam.unproject_position(Vector3(6, 0, 2)))
	print("selftest walls on lawn: ", world.walls.has(Vector3i(3, 2, 0)), " money ", money)
	tool = "door"
	_click_build(cam.cam.unproject_position(Vector3(3.5, 0, 2.05)))
	print("selftest door: ", world.walls.get(Vector3i(3, 2, 0)))
	tool = "floor:1"
	_click_build(lawn)
	_update_ghost()
	print("selftest floor: ", world.floors[world.idx(Vector2i(3, 3))])
	tool = "erase"
	_click_build(cam.cam.unproject_position(Vector3(2, 0, 2)))
	_release(cam.cam.unproject_position(Vector3(6, 0, 2)))
	print("selftest erased: ", not world.walls.has(Vector3i(3, 2, 0)))
	set_mode("live")
	for o in world.objects:
		if o.kind == "fridge":
			_click_live(cam.cam.unproject_position(o.position + Vector3(0, 0.5, 0)))
			print("selftest menu items: ", ui.menu.item_count)
			ui.menu_calls[1].call()
	ui.menu.hide()
	for p in people:
		if p != selected:
			_click_live(cam.cam.unproject_position(p.position + Vector3(0, 1.0, 0)))
			print("selftest social menu items: ", ui.menu.item_count)
			ui.menu_calls[1].call()
			break
	print("selftest queue: ", selected.queue.map(func(a): return a.label), " cur: ", selected.activity())
	cancel_action(selected, 1)
