extends Node3D
## Game controller: clock, money, household and neighbours, modes (live / buy / build),
## input, lighting, saving and loading.

const MULT := [0.0, 1.0, 4.0, 12.0]

const Probe := preload("res://scripts/probe.gd")

static var skip_load := false
static var new_spec := {}  # a household made in the creator, carried across the reload
static var _run := 0
static var _probe: RefCounted

var save_path := "user://the_people_save_v2.json"
var world: World
var cam: Cam
var ui: UI
var sfx: Sfx
var people: Array = []      # household
var neighbours: Array = []  # everyone in the other households
var pending: Array = []     # children on the way: {at, a, b}
var selected: Person
var family := ""
var households := {}        # id -> Household
var home: Household         # the player's household
var town: Town              # every lot on the street, as data
var money: int:
	get: return home.money
	set(v): home.money = v
var minutes := 7.5 * 60.0  # game minutes since day 0, 00:00
var speed := 1
var prev_speed := 1
var mode := "live"
var screen := "lot"         # the screen showing now: "lot" or "town"
var screens := {}           # name -> the nodes shown, and running, only on that screen
var lot: Node3D             # the player's lot as drawn: its world, everyone, the camera
var free_will := true
var rel := {}
var rdt := 0.0
var rng := RandomNumberGenerator.new()
var seed_base := 0
var next_pid := 0
var next_hh := 1
var welcomed := false
var over := false
var age_rate := 1.0
## The lot a new game started on, from TP_LOT: "" for a generated home, "empty" for bare
## land, which counts as bought on moving in (start_household takes LOT_PRICE).
var lot_kind := ""
## True from the start of a build session until the game is first unpaused; the Build panel
## shows the bare-lot hint meanwhile (UI._hint).
var session_hint := false
var _log_frames := 0  # frames seen by _session_log (TP_PAUSELOG)
var _money_set_at_bill := false  # TP_MONEY_AT_BILL has been applied

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
var _last_hour := -1
var _room_t := 0.0
var _light_t := -1.0

var _test_days := 0
var _runs := 1
var _shot := ""
var _frames := 0

var day: int:
	get: return int(minutes / 1440.0)


func hour() -> float:
	return fmod(minutes, 1440.0) / 60.0


func everyone() -> Array:
	return people + neighbours


func _ready() -> void:
	if OS.has_environment("TP_SAVE"):
		save_path = OS.get_environment("TP_SAVE")
	var testing := OS.has_environment("TP_TEST") or OS.has_environment("TP_SHOT")
	# Only the first of several pooled test runs may continue a save; the rest start new.
	var fresh := skip_load or (testing and not OS.has_environment("TP_SAVE")) or OS.has_environment("TP_FRESH") or _run > 0
	skip_load = false
	if testing and not OS.has_environment("TP_SAVE"):
		save_path = "user://tp_test_save.json"
	var data = null if fresh else _read_save()
	var seed_v := randi()
	if OS.has_environment("TP_SEED"):
		seed_v = int(OS.get_environment("TP_SEED")) + _run
	if data != null:
		seed_v = int(data["seed"])
	seed_base = seed_v
	rng.seed = seed_v
	if OS.has_environment("TP_AGE"):
		age_rate = float(OS.get_environment("TP_AGE"))
	get_viewport().gui_embed_subwindows = true
	sfx = Sfx.new()
	add_child(sfx)
	_build_env()
	lot = Node3D.new()
	add_child(lot)
	home = Household.new()
	home.player = true
	households[0] = home
	world = World.new()
	lot.add_child(world)
	home.world = world
	# TP_LOT picks the lot a new game starts on: "empty" is bare land with no house, and
	# "vacant:<seed>" is the generated home built from that seed. A save keeps the lot it was
	# made on. The player's world draws from its own rng, so the game's rng does not move.
	lot_kind = OS.get_environment("TP_LOT") if data == null else ""
	var home_seed := int(lot_kind.get_slice(":", 1)) if lot_kind.begins_with("vacant:") else seed_v
	world.setup(home_seed, data["households"][0]["world"] if data != null else null, lot_kind == "empty")
	if lot_kind.begins_with("vacant:"):
		_move_into_vacant.call_deferred(home_seed)  # once the town has its vacant lots
		if OS.has_environment("TP_RENT"):  # rent the home rather than own it
			home.tenure = "rent"
			home.rent = int(world.value() * Defs.RENT_SHARE)
			world.mark_landlords()  # what came with the home is not theirs to sell
			(func(): msg("Paid a deposit of $%d." % _deposit_paid())).call_deferred()  # once the HUD is up
	if OS.has_environment("TP_TEST") and (lot_kind != "" or OS.has_environment("TP_MONEY")):
		(func(): print("START funds $%d, lot price $%d, deposit $%d, starting money $%d (START_FUNDS $%d)" % [money + _lot_paid() + _deposit_paid(), _lot_paid(), _deposit_paid(), money, Defs.START_FUNDS])).call_deferred()
	if OS.has_environment("TP_TEST") and (lot_kind != "" or OS.has_environment("TP_PRICES")):
		_print_prices.call_deferred()
	# TP_SESSION applies the build session on any start, a loaded one included, for tests.
	if lot_kind == "empty" or OS.has_environment("TP_SESSION"):
		_start_build_session.call_deferred()  # after _ready, so a test's forced speed loses
	if OS.has_environment("TP_PAUSELOG"):
		get_tree().process_frame.connect(_session_log)
	if lot_kind == "empty" and OS.has_environment("TP_ROOM"):
		_room_test.call_deferred()  # once the camera and HUD it clicks through exist
	if home.tenure == "rent" and OS.has_environment("TP_LIMITS"):
		_limits_test.call_deferred()  # after the START line, so that shows the money before it
	# The town draws from its own rng, seeded from the game's, so no other draw moves.
	town = Town.new(hash("town %d" % seed_v))
	town.add_home(0, seed_v)
	if data != null:
		_load_household(data)
	else:
		start_household(_take_spec())
	if data != null and data.has("town"):
		town = Town.from_dict(data["town"])
	else:
		town.fill()  # a new game, or a save from before towns: build the street around its households
	cam = Cam.new()
	lot.add_child(cam)
	# On the house, or on a lot with no house, the middle of its front, so the lawn and the
	# household at the kerb are both in view.
	cam.position = Vector3(world.house.get_center().x + 0.5, 0, world.house.get_center().y + 1.0) if world.house.has_area() else Vector3(World.W / 2.0, 0, World.H - 4.0)
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker = MeshInstance3D.new()
	marker.mesh = BoxMesh.new()
	marker.material_override = ghost_mat
	marker.visible = false
	lot.add_child(marker)
	ui = UI.new()
	ui.game = self
	add_child(ui)
	_build_screens()
	screens["create"] = _make_create()
	if not people.is_empty():
		select(people[0])
	world.update_room_scores()
	_update_light(true)
	_last_day = day
	if data != null:
		msg("Welcome back, %s household." % family)
	else:
		msg("Meet the %s household. Click things to give orders, or just watch. Press H for controls." % family)
	if OS.has_environment("TP_TEST"):
		_test_days = int(OS.get_environment("TP_TEST"))
		if OS.has_environment("TP_RUNS"):
			_runs = int(OS.get_environment("TP_RUNS"))
		if _probe == null:
			_probe = Probe.new()
		_probe.begin(self)
		for p in everyone():
			if p.tile != p.world.door_tile and p.world.path(p.world.door_tile, p.tile) == null:
				print("STUCK: %s (household %d) starts at %s, which cannot be reached from the door" % [p.pname, p.household, p.tile])
		sfx.set_muted(true)
		if data == null:
			for p in people:
				if p.pid != 0 and p.stage() == "adult":
					assign_job(p)
			if people.size() >= 2:
				add_rel(people[0], people[1], 80.0)
				expect_child(people[0], people[1])
	if OS.has_environment("TP_SHOT"):
		_shot = OS.get_environment("TP_SHOT")
		sfx.set_muted(true)
		speed = 3
		if OS.has_environment("TP_MODE"):
			set_mode(OS.get_environment("TP_MODE"))
		if OS.has_environment("TP_WALLS"):
			toggle_walls()
		if OS.has_environment("TP_HOUR"):
			minutes = float(OS.get_environment("TP_HOUR")) * 60.0
		if OS.has_environment("TP_UI"):
			ui.debug_open(OS.get_environment("TP_UI"))
	if OS.has_environment("TP_SCREEN"):
		set_screen(OS.get_environment("TP_SCREEN"))


func _make_person(id: int, sv: int, fam: String, hh: Household, spec := {}) -> Person:
	var p := Person.new()
	p.setup(self, hh.world, id, sv, fam, hh.player, spec)
	p.hh = hh
	p.household = hh.id
	lot.add_child(p)
	if hh.player:
		people.append(p)
	else:
		p.visible = false
		neighbours.append(p)
	next_pid = maxi(next_pid, id + 1)
	return p


## A random household for a new game: {family, money, members: [{name, age, look, traits}]}.
## `name` is a first name; `look` and `traits` have the shapes a Person keeps in memory.
## `money` is optional and wins when present. It is left out for a household on a lot with no
## house or renting its home, so that start_household gives it START_FUNDS. TP_MONEY sets
## it, for tests.
func random_spec() -> Dictionary:
	var spec := {"family": Defs.surname(rng), "money": Household.new().money, "members": []}
	if _gets_start_funds():
		spec.erase("money")
	if OS.has_environment("TP_MONEY"):
		spec["money"] = int(OS.get_environment("TP_MONEY"))
	for i in rng.randi_range(2, 3):
		var r := Person.roll(_rng_for(_member_seed(i)))
		spec["members"].append({"name": r["name"], "age": r["age"], "look": r["look"], "traits": r["traits"]})
	return spec


## The seed of the i-th member of a new player household: their needs, lifespan and
## everything they roll later come from it.
func _member_seed(i: int) -> int:
	return seed_base * 7 + i * 131


func _rng_for(sv: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = sv
	return r


## Moves the household in `spec` onto the player's lot, then fills the street around it.
func start_household(spec: Dictionary) -> void:
	family = spec["family"]
	home.family = family
	home.money = int(spec["money"]) if spec.has("money") else (Defs.START_FUNDS if _gets_start_funds() else Household.new().money)
	home.money -= _lot_paid() + _deposit_paid()
	var spots := world.arrival_tiles()
	for i in spec["members"].size():
		var p := _make_person(i, _member_seed(i), family, home, spec["members"][i])
		p.tile = spots[rng.randi() % spots.size()]
		p.position = world.tile_center(p.tile)
		p.rotation.y = rng.randf() * TAU
	for a in people:
		for b in people:
			if a.pid < b.pid:
				rel[_rk(a, b)] = _spec_rel(spec, a.pid, b.pid, rng.randf_range(5.0, 45.0))
	next_pid = 100
	for i in 3:
		_new_family(rng.randi_range(1, 3), true)


## Another household, with a generated lot of its own that is simulated but never drawn.
func _add_household(id: int, data = null) -> Household:
	var hh := Household.new()
	hh.id = id
	var w := World.new()
	w.headless = true
	w.visible = false
	add_child(w)
	var wseed := int(rng.randi())
	w.setup(wseed, data)
	# A loaded world is rebuilt from its saved state, so the seed it was first made from is not known here.
	town.add_home(id, wseed if data == null else -1)
	w.set_night(world.night)
	hh.world = w
	households[id] = hh
	next_hh = maxi(next_hh, id + 1)
	return hh


## A neighbouring household: one or two adults (or elders) and sometimes children.
func _new_family(size: int, established: bool) -> void:
	var fam := Defs.surname(rng)
	while households.values().any(func(h): return h.family == fam):
		fam = Defs.surname(rng)
	var hh := _add_household(next_hh)
	hh.family = fam
	hh.money = rng.randi_range(1800, 3200)
	var spots := hh.world.free_tiles_in("living")
	var members := []
	for i in size:
		var n := _make_person(next_pid, int(rng.randi()), fam, hh)
		if i < 2:
			var elders := established and i == 0 and rng.randf() < 0.3
			n.age = rng.randf_range(Defs.ELDER_AT, Defs.ELDER_AT + 6.0) if elders else rng.randf_range(8.0, 24.0)
			if members.size() == 1 and members[0].stage() == "elder":
				n.age = rng.randf_range(Defs.ELDER_AT - 4.0, Defs.ELDER_AT + 6.0)
			if established and n.stage() == "adult" and rng.randf() < 0.6:
				n.job = {"career": rng.randi() % Defs.CAREERS.size(), "level": 0, "perf": 0.0}
		else:
			n.age = rng.randf_range(0.0, Defs.CHILD_DAYS - 0.5)
		n.refresh_look()
		n.tile = spots[rng.randi() % spots.size()]
		n.position = hh.world.tile_center(n.tile)
		for m in members:
			rel[_rk(m, n)] = rng.randf_range(50.0, 90.0)
		members.append(n)


func known(p: Person) -> bool:
	for o in people:
		if absf(get_rel(o, p)) >= 5.0:
			return true
	return false


func household_of(id: int) -> Array:
	return everyone().filter(func(p): return p.household == id)


## Members plus children on the way.
func hh_count(hh: Household) -> int:
	return household_of(hh.id).size() + pending.filter(func(pc): return int(pc["hh"]) == hh.id).size()


## Everyone physically on a given lot right now.
func present(w: World) -> Array:
	return everyone().filter(func(p): return p.world == w and not p.away)


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
	sfx.set_day(soft)
	var n := soft < 0.35
	if n != world.night:
		for hh in households.values():
			hh.world.set_night(n)
			hh.world.update_room_scores()


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	rdt = delta
	if _test_days > 0:
		for i in 240:
			_step(1.0 / 60.0, 1.0)
			_probe.step(1.0 / 60.0)
		if day >= _test_days or over:
			# TP_RUNS repeats the run on consecutive seeds and pools the balance report.
			_run += 1
			_report()
			if _run < _runs:
				get_tree().reload_current_scene()
			else:
				_probe.report()
				get_tree().quit()
			return
	else:
		var m: float = MULT[speed]
		if m > 0.0 and not over:
			_step(delta * m / 60.0, delta * m)
	_update_light()
	if screen == "lot":
		_update_ghost()
		ui.refresh()
	if _shot != "":
		_frames += 1
		if _frames == 150 and OS.has_environment("TP_SELFTEST"):
			_selftest()
		if _frames == 200:
			var img := get_viewport().get_texture().get_image()
			if img != null:  # null when running without a display
				img.save_png(_shot)
			get_tree().quit()


func _step(dh: float, ds: float) -> void:
	minutes += dh * 60.0
	for p in everyone():
		p.tick(dh, ds)
	if over:
		return
	var h := hour()
	if day % 7 < 5:
		for p in everyone():
			if p.away or p.vstate != "home" or p.work_flag_day == day:
				continue
			var c = p.sched()
			if c != null and h >= c["start"] - Defs.COMMUTE and h < c["start"] + 2.0:
				p.work_flag_day = day
				p.go_to_work()
	_room_t -= dh
	if _room_t <= 0.0:
		_room_t = 0.2
		for hh in households.values():
			hh.world.update_room_scores()
	for pc in pending.duplicate():
		if minutes >= pc["at"]:
			pending.erase(pc)
			_spawn_child(pc)
	if int(h) != _last_hour:
		_last_hour = int(h)
		_hourly(int(h))
	if day != _last_day:
		_last_day = day
		_new_day()


func _hourly(h: int) -> void:
	if h < 9 or h > 19:
		return
	var home := people.filter(func(p): return not p.away)
	if home.is_empty():
		return
	if not welcomed and h >= 10:
		welcomed = true
		var n = available_neighbour()
		if n != null:
			n.start_visit(true)
			msg("A neighbour, %s, is coming by to say hello." % n.pname)
		return
	if rng.randf() < 0.12:
		var n = available_neighbour()
		if n != null:
			var best := -100.0
			for p in people:
				best = maxf(best, get_rel(p, n))
			n.start_visit(visitors().is_empty() and rng.randf() < 0.35 + clampf(best, 0.0, 60.0) / 150.0)


func _new_day() -> void:
	for p in everyone():
		if p.job != null and (day - 1) % 7 < 5 and p.work_day != day - 1:
			p.job.perf -= 15.0
			if p.resident:
				msg("%s missed work yesterday." % p.first())
		if p.stage() == "elder":
			p.hh.money += Defs.PENSION
	_neighbourhood_day()
	if day % 3 == 0:
		for hh in households.values():
			var value := 0
			for o in hh.world.objects:
				value += o.def["price"]
			var bill := int(value * 0.03) + 25 * household_of(hh.id).size()
			var rent: int = hh.rent if hh.tenure == "rent" else 0
			if hh.player and OS.has_environment("TP_MONEY_AT_BILL") and not _money_set_at_bill:
				_money_set_at_bill = true  # a test: the player's money just before the first bill
				hh.money = int(OS.get_environment("TP_MONEY_AT_BILL"))
			var before: int = hh.money
			hh.money -= bill + rent
			if hh.player:
				msg("Bills paid: $%d." % bill if rent == 0 else "Bills paid: $%d, and rent: $%d." % [bill, rent])
				if _test_days > 0 and lot_kind != "":
					print("BILLS day %d: money before $%d, bills $%d, rent $%d, money after $%d" % [day, before, bill, rent, hh.money])
				# A renter left in debt is warned; exactly $0 is paid up. Eviction is for later.
				if hh.tenure == "rent" and hh.money < 0:
					msg("You're $%d behind on the rent. Pay it off before the next bills." % -hh.money, "error")
	if _test_days == 0 and _shot == "":
		save_game(true)


# ---------------------------------------------------------------- game API

func msg(text: String, snd := "") -> void:
	if _test_days > 0:
		if _runs == 1:
			print("[d%d %05.2f] %s" % [day, hour(), text])
		return
	if ui != null:
		ui.push_msg(text)
	if snd != "":
		sfx.play(snd)


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
	p._msg("%s got a job as %s, $%d a day, starting at %d:00 on weekdays." % [p.first(), c["titles"][0], c["pay"][0], int(c["start"])], "chime")


## Empty lots are cleared, and new families move in when the street thins out.
func _neighbourhood_day() -> void:
	for id in households.keys():
		var hh: Household = households[id]
		if not hh.player and hh_count(hh) == 0:
			hh.world.queue_free()
			households.erase(id)
			town.vacate(id)
	if neighbours.size() < 5 and rng.randf() < 0.5:
		_new_family(rng.randi_range(1, 2), false)
		msg("The %s family moved in down the street." % households[next_hh - 1].family)


func available_neighbour():
	var off := neighbours.filter(func(n): return n.vstate == "home" and not n.away and not n.busy_now(1.0))
	if off.is_empty():
		return null
	return off[rng.randi() % off.size()]


## Neighbours currently on, or heading to, the lot.
func visitors() -> Array:
	return neighbours.filter(func(n): return n.vstate in ["arriving", "waiting", "guest"] or (n.vstate in ["stroll", "heading"] and n.stroll_enter))


func invite(caller: Person, who) -> void:
	var n = who if who != null and is_instance_valid(who) and who.vstate == "home" and not who.away else available_neighbour()
	if n == null:
		msg("Nobody picked up.")
		return
	if rng.randf() < 0.6 + get_rel(caller, n) / 120.0:
		n.start_visit(true)
		add_rel(caller, n, 1.0)
		msg("%s is on the way over." % n.pname, "chime")
	else:
		msg("%s can't come over right now." % n.pname)


func expect_child(a: Person, b) -> void:
	pending.append({"at": (day + 1) * 1440.0 + 8.0 * 60.0, "hh": a.household, "a": a.pid, "b": b.pid if b != null else -1})
	if not a.resident:
		return
	if b != null:
		msg("%s and %s are expecting. A child joins the household tomorrow morning." % [a.first(), b.first()], "jingle")
	else:
		msg("The adoption went through. A child joins the household tomorrow morning.", "jingle")


func _by_pid(id: int):
	for p in everyone():
		if p.pid == id:
			return p
	return null


func _spawn_child(pc: Dictionary) -> void:
	var hh = households.get(int(pc["hh"]))
	if hh == null:
		return
	var pa = _by_pid(int(pc["a"]))
	var pb = _by_pid(int(pc["b"]))
	var c := _make_child(pa, pb, hh)
	var inside: Vector2i = hh.world.door_inside
	c.tile = inside if hh.world.walkable(inside) else hh.world.exit_tile
	c.position = hh.world.tile_center(c.tile)
	if hh.player:
		msg("%s has joined the %s household." % [c.first(), family], "jingle")
	elif (pa != null and known(pa)) or (pb != null and known(pb)):
		msg("The %s family next door had a child, %s." % [hh.family, c.first()], "chime")


## A newborn of one or two parents, joining the given household.
func _make_child(pa, pb, hh: Household) -> Person:
	var c := _make_person(next_pid, int(rng.randi()), hh.family, hh)
	c.age = 0.0
	if pa != null:
		var other: Person = pb if pb != null else pa
		c.look["skin"] = pa.look["skin"].lerp(other.look["skin"], rng.randf())
		c.look["hair"] = pa.look["hair"] if rng.randf() < 0.5 else other.look["hair"]
		if pb != null:
			for t in Defs.TRAITS:
				c.traits[t] = clampi(int((pa.traits[t] + pb.traits[t]) / 2.0) + rng.randi_range(-2, 2), 1, 9)
	for p in household_of(hh.id):
		if p != c:
			rel[_rk(p, c)] = 55.0 if (p == pa or p == pb) else 25.0
	c.refresh_look()
	return c


func on_death(p: Person, cause: String) -> void:
	var on_lot: bool = not p.away
	if p.resident or (on_lot and p.world == world) or known(p):
		msg("%s has died of %s." % [p.pname if p.resident else "Your neighbour %s" % p.pname, cause], "toll")
	if on_lot:
		var t = p.world.free_tile_near(p.tile)
		if t != null:
			var g: SimObject = p.world.add_object("grave", t.x, t.y, 0)
			g.label = p.pname
	people.erase(p)
	neighbours.erase(p)
	for o in everyone():
		if o.cur != null and o.cur.get("other") == p:
			o.cancel_current()
		o.queue = o.queue.filter(func(a): return a.get("other") != p)
	for o in people:
		var r := get_rel(o, p)
		if r > 10.0:
			o.needs.fun = maxf(0.0, o.needs.fun - r * 0.4)
			o.needs.social = maxf(0.0, o.needs.social - r * 0.3)
			o.say("...", 4.0)
	p.queue_free()
	if selected == p:
		selected = null
		if not people.is_empty():
			select(people[0])
	if people.is_empty() and not over:
		over = true
		for n in neighbours:
			n.leave()
		if ui != null:
			ui.show_game_over()


func remove_object(o: SimObject, w: World = null) -> void:
	for p in everyone():
		if p.cur != null and (p.cur.get("obj") == o or p.cur.get("seat") == o):
			p.cancel_current()
		p.queue = p.queue.filter(func(a): return a.get("obj") != o)
	(w if w != null else world).remove_object(o)


func select(p: Person) -> void:
	if selected != null:
		selected.set_selected(false)
	selected = p
	p.set_selected(true)


func set_speed(s: int) -> void:
	if s == 0 and speed != 0:
		prev_speed = speed
	speed = s
	for p in everyone():
		p.loop_p.stream_paused = s == 0


## Lists what each screen shows. The town is a placeholder for now: a name tag, and a
## camera left where the lot's camera starts so that a lot still drawn would be seen.
func _build_screens() -> void:
	var town := CanvasLayer.new()
	add_child(town)
	var tag := PanelContainer.new()
	tag.theme = ui.root.theme
	tag.position = Vector2(12, 12)
	town.add_child(tag)
	var l := Label.new()
	l.text = "Town"
	l.add_theme_color_override("font_color", UI.MUTED)
	tag.add_child(l)
	var town_cam := Camera3D.new()
	add_child(town_cam)
	town_cam.global_transform = cam.cam.global_transform
	town_cam.fov = cam.cam.fov
	screens = {"lot": [lot, ui, cam.cam], "town": [town, town_cam]}
	for n in screens["town"]:
		_show_node(n, false)


## Shows one screen and hides the rest. A hidden screen's nodes stop processing as well,
## so its camera and controls ignore the mouse and keys.
func set_screen(s: String) -> void:
	if not screens.has(s):
		push_error("There is no screen called '%s'." % s)
		return
	screen = s
	for k in screens:
		if k != s:
			for n in screens[k]:
				_show_node(n, false)
	for n in screens[s]:
		_show_node(n, true)
	if s != "lot":
		drag_start = null
		ui.menu.hide()
		ui.opt_menu.hide()


func _show_node(n: Node, on: bool) -> void:
	n.visible = on
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if n is Camera3D:
		n.current = on


func set_mode(m: String) -> void:
	if m == "build" and _renting():
		msg(Defs.RENT_NO_BUILD, "error")
		return
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
	lot.add_child(ghost)
	Meshes.build_object(ghost, kind, rng)
	var s: Vector2i = Defs.OBJECTS[kind]["size"]
	ghost_plate = Meshes.box(ghost, Vector3(s.x, 0.04, s.y), Vector3(0, 0.03, 0), Color.WHITE)
	ghost_plate.material_override = ghost_mat


func clear_tool() -> void:
	set_buy("")
	tool = ""
	sell = false
	drag_start = null


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


# ---------------------------------------------------------------- saving

func save_game(quiet := false) -> void:
	if over:
		return
	var hhs := []
	for id in households:  # the player's household (id 0) was added first
		var hh: Household = households[id]
		hhs.append({"id": hh.id, "family": hh.family, "money": hh.money, "build_hint": hh.build_hint, "tenure": hh.tenure, "rent": hh.rent, "world": hh.world.save_state()})
	var d := {
		"v": 2, "seed": seed_base, "minutes": minutes, "rel": rel,
		"next_pid": next_pid, "next_hh": next_hh, "welcomed": welcomed, "pending": pending, "free_will": free_will,
		"households": hhs, "town": town.to_dict(),
		"people": everyone().map(func(p): return p.save_state()),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		msg("Could not write the save file.", "error")
		return
	f.store_string(JSON.stringify(d))
	f.close()
	if not quiet:
		msg("Saved.", "chime")


func _read_save():
	if not FileAccess.file_exists(save_path):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if d is Dictionary and d.get("v") == 2 and d.has("households") and int(d["households"][0]["id"]) == 0:
		return d
	return null


func _load_household(d: Dictionary) -> void:
	minutes = d["minutes"]
	rel = d["rel"]
	welcomed = d.get("welcomed", true)
	free_will = d.get("free_will", true)
	for hd in d["households"]:
		var hh: Household = home if int(hd["id"]) == 0 else _add_household(int(hd["id"]), hd["world"])
		hh.family = hd["family"]
		hh.money = int(hd["money"])
		hh.build_hint = bool(hd.get("build_hint", false))
		hh.tenure = str(hd.get("tenure", "own"))
		hh.rent = int(hd.get("rent", 0))
	family = home.family
	for pc in d.get("pending", []):
		pending.append({"at": float(pc["at"]), "hh": int(pc["hh"]), "a": int(pc["a"]), "b": int(pc["b"])})
	for pd in d["people"]:
		var hh = households.get(int(pd["household"]))
		if hh != null:
			_make_person(int(pd["pid"]), int(pd["seed"]), hh.family, hh).load_state(pd)
	next_pid = maxi(next_pid, int(d.get("next_pid", 0)))
	next_hh = maxi(next_hh, int(d.get("next_hh", 1)))
	rng.seed = seed_base + int(minutes)


func load_game() -> void:
	if _read_save() == null:
		msg("There is no saved household yet. Press F5 to save one.", "error")
		return
	get_tree().reload_current_scene()


func new_game() -> void:
	skip_load = true
	get_tree().reload_current_scene()


## The household made in the creator, if there is one; otherwise a random one.
func _take_spec() -> Dictionary:
	if new_spec.is_empty():
		return random_spec()
	var s := new_spec
	new_spec = {}
	return s


## The starting relationship of members `a` and `b` (indexes into the spec): the value of the kind
## the spec chose for the pair, or `drawn`. The random draw is made for every pair either way.
func _spec_rel(spec: Dictionary, a: int, b: int, drawn: float) -> float:
	for r in spec.get("rels", []):
		if int(r["a"]) == a and int(r["b"]) == b and Defs.REL_KINDS.has(r["kind"]):
			return Defs.REL_KINDS[r["kind"]]
	return drawn


## The creator's nodes, hidden until the `create` screen is shown.
func _make_create() -> Array:
	var nodes: Array = load("res://scripts/ui_create.gd").new().setup(self)
	for n in nodes:
		_show_node(n, false)
	return nodes


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
	for p in everyone():
		if not p.visible:
			continue
		for hy in [0.5, 1.0, 1.5]:
			var v: Vector3 = p.shown_pos() + Vector3(0, hy * p.h_scale, 0) - o
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
	if screen != "lot":
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE: set_speed(prev_speed if speed == 0 else 0)
			KEY_1: set_speed(1)
			KEY_2: set_speed(2)
			KEY_3: set_speed(3)
			KEY_TAB:
				if not people.is_empty():
					select(people[(people.find(selected) + 1) % people.size()])
			KEY_R: buy_rot = (buy_rot + 1) % 4
			KEY_F: toggle_walls()
			KEY_H: ui.toggle_help()
			KEY_M: sfx.set_muted(not sfx.muted)
			KEY_F5: save_game()
			KEY_F9: load_game()
			KEY_ESCAPE:
				clear_tool()
				ui.build_side()
	elif e is InputEventMouseButton:
		if over:
			return
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
				clear_tool()
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
		if p.resident and (p == selected or selected == null or selected.away):
			select(p)
			return
		if selected == null:
			return
		var r := get_rel(selected, p)
		var title := "%s, %s, %s" % [p.pname, p.stage(), _rel_word(r)]
		if not p.resident and p.vstate == "stroll":
			if not p.stroll_enter:
				items.append(["Invite in", _wave_in.bind(p)])
			ui.show_menu(title, items, mpos)
			return
		if p.resident:
			items.append(["Switch to %s" % p.first(), select.bind(p)])
		elif p.vstate == "waiting":
			items.append(["Greet", selected.enqueue.bind(selected.act_social(p, Defs.GREET))])
		for sd in Defs.SOCIALS:
			if r < sd["min_rel"]:
				continue
			if sd["id"] == "baby" and not selected.can_have_child_with(p):
				continue
			items.append([sd["label"], selected.enqueue.bind(selected.act_social(p, sd))])
		if not p.resident and p.vstate == "guest":
			items.append(["Ask to leave", p.leave])
		ui.show_menu(title, items, mpos)
		return
	var o = pick_object(mpos)
	if o == null or selected == null:
		return
	for it in o.def.get("acts", []):
		if it.get("hidden", false) or (it.get("adult", false) and selected.stage() == "child"):
			continue
		if it.get("cond", "") == "no_job" and (selected.job != null or selected.stage() != "adult"):
			continue
		if it.has("req") and world.nearest_object(it["req"], o.tile) == null:
			continue
		if it.get("special", "") == "invite":
			for n in neighbours:
				if n.vstate == "home" and not n.away:
					var a: Dictionary = selected.act_use(o, it)
					a["who"] = n
					a["label"] = "Invite %s" % n.first()
					items.append(["Invite %s over (%s)" % [n.pname, _rel_word(get_rel(selected, n))], selected.enqueue.bind(a)])
			continue
		items.append([it["label"], selected.enqueue.bind(selected.act_use(o, it))])
	var title: String = o.def["name"]
	if o.label != "":
		title = "In memory of %s" % o.label
	ui.show_menu(title, items, mpos)


func _rel_word(r: float) -> String:
	if r >= 70.0:
		return "close"
	if r >= 35.0:
		return "friend"
	if r >= 10.0:
		return "friendly"
	if r > -10.0:
		return "acquaintance"
	return "on bad terms"


func _wave_in(n: Person) -> void:
	if rng.randf() < 0.75 + get_rel(selected, n) / 150.0:
		n.come_in()
		msg("%s is coming over." % n.first())
	else:
		msg("%s is in a hurry today." % n.first())


func _ghost_anchor(mpos: Vector2) -> Vector2i:
	var d := world.kind_dims(buy_kind, buy_rot)
	var p := _ray_plane(mpos, 0.0)
	return Vector2i(floori(p.x - (d.x - 1) / 2.0), floori(p.z - (d.y - 1) / 2.0))


func _placeable(a: Vector2i) -> bool:
	if not world.can_place(buy_kind, a.x, a.y, buy_rot):
		return false
	var d := world.kind_dims(buy_kind, buy_rot)
	for p in present(world):
		if Rect2i(a, d).has_point(p.tile):
			return false
	return money >= Defs.OBJECTS[buy_kind]["price"]


func _click_buy(mpos: Vector2) -> void:
	if sell:
		var o = pick_object(mpos)
		if o != null and _renting() and world.landlords(o):
			msg("That came with the home, so it isn't yours to sell.", "error")
			return
		if o != null and o.kind != "puddle":
			var v := int(o.def["price"] * 0.7)
			remove_object(o)
			money += v
			msg("Sold %s for $%d." % [o.def["name"], v], "coin")
		return
	if buy_kind == "":
		return
	var a := _ghost_anchor(mpos)
	if _placeable(a):
		world.add_object(buy_kind, a.x, a.y, buy_rot)
		money -= Defs.OBJECTS[buy_kind]["price"]
		world.update_room_scores()
		sfx.play("place")
	else:
		sfx.play("error")


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
	if _renting() and tool != "":
		msg(Defs.RENT_NO_BUILD, "error")
		return
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
				sfx.play("place")
			else:
				sfx.play("error")
		_:
			if tool.begins_with("floor"):
				_paint(mpos)


func _release(mpos: Vector2) -> void:
	if mode != "build" or drag_start == null:
		return
	if _renting():
		drag_start = null
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
		sfx.play("place")


func _walls_changed() -> void:
	world.rebuild_walls()
	world.nav_dirty = true
	world.update_room_scores()
	world.update_front_door()


## The build session a household arriving on an empty lot starts in: Build mode, paused,
## with Space resuming at speed 1. The first time for this household, the Build panel shows
## the bare-lot hint until the game is unpaused. Safe to call again (say, when the lot is
## first shown after another screen restored a speed): it only re-pauses and re-opens Build.
func _start_build_session() -> void:
	set_mode("build")
	set_speed(0)
	prev_speed = 1
	if not home.build_hint:
		home.build_hint = true
		session_hint = true


## TP_PAUSELOG: prints the clock, speed and the selected person's needs at frames 2, 100 and
## 190. With TP_UNPAUSE=<frame>, presses Space (through the real key handler) at that frame.
func _session_log() -> void:
	_log_frames += 1
	var f := _log_frames
	if f in [2, 100, 190] and selected != null:
		var nd := []
		for n in Defs.NEEDS:
			nd.append("%s %.3f" % [n.substr(0, 3), selected.needs[n]])
		print("PAUSELOG frame %d: minutes %.3f, speed %d, mode %s, hint %s | %s: %s" % [f, minutes, speed, mode, session_hint, selected.first(), ", ".join(nd)])
	if OS.has_environment("TP_UNPAUSE") and f == int(OS.get_environment("TP_UNPAUSE")):
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.pressed = true
		_unhandled_input(e)
		print("PAUSELOG frame %d: pressed Space, speed now %d" % [f, speed])


## TP_LOT=vacant:<seed>: puts the move into the town record and proves the house. If the
## seed is one of the town's vacant lots, household 0 takes that lot and the lot it was given
## first becomes vacant, keeping the seed of the house it would have had. Otherwise lot 0 keeps
## household 0 with the new seed. Then prints the player's home beside a fresh headless World
## built from the same seed, as the town view would build it.
func _move_into_vacant(s: int) -> void:
	var vac := town.lots.filter(func(l): return l["kind"] == "vacant")
	print("TOWN vacant lots: " + ", ".join(vac.map(func(l): return "lot %d seed %d" % [l["id"], l["seed"]])))
	var taken = null
	for l in vac:
		if l["seed"] == s:
			taken = l
	var first = town.lot_of(0)
	if taken != null:
		town.vacate(0)
		town.take_vacant(taken["id"], 0)
		print("TOWN household 0 moved into vacant lot %d (seed %d); lot %d is vacant now (seed %d)" % [taken["id"], s, first["id"], first["seed"]])
	else:
		first["seed"] = s
		print("TOWN seed %d is not a vacant lot in this town; lot %d keeps household 0, now with seed %d" % [s, first["id"], s])
	var w := World.new()
	w.headless = true
	w.setup(s)
	print("HOME player's: " + _home_line(world))
	print("HOME from seed: " + _home_line(w))
	var mine := world.save_state()
	for od in mine["objects"]:
		od.erase("ll")  # a rental marks the landlord's furniture; the house itself is the same
	print("HOME identical: %s" % (JSON.stringify(mine) == JSON.stringify(w.save_state())))
	w.free()


func _home_line(w: World) -> String:
	return "house %s, wall colour %s, value $%d, %d wall edges, %d objects, door %s" % [w.house, w.wall_color.to_html(false), w.value(), w.walls.size(), w.objects.size(), w.door_tile]


## True when the player's lot came with no house, so the household has to house itself.
func _houses_itself() -> bool:
	return world != null and not world.house.has_area()


## What the household paid for its lot on moving in: LOT_PRICE for a TP_LOT=empty start,
## which stands in for buying an empty lot until the town sells them (N2); nothing otherwise.
func _lot_paid() -> int:
	return Defs.LOT_PRICE if lot_kind == "empty" else 0


## True when a new household starts from START_FUNDS rather than Household's $2,500: on a
## lot with no house, or renting its home. A household that owns a generated home it moves
## into keeps $2,500 until N4 decides what buying a home costs.
func _gets_start_funds() -> bool:
	return _houses_itself() or (home != null and home.tenure == "rent")


## The deposit paid on moving in: one rent period for a TP_LOT=vacant rental (TP_RENT), which
## stands in for renting from the town until it lets homes (N3); nothing otherwise. Not saved:
## it is always one period of the saved rent, and nothing after the start reads it.
func _deposit_paid() -> int:
	return home.rent if lot_kind.begins_with("vacant:") and home.tenure == "rent" else 0


## Renters can furnish but not rebuild: no Build mode, no wall, door, window or floor edits,
## and no selling what came with the home.
func _renting() -> bool:
	return home != null and home.tenure == "rent"


## TP_LIMITS (on a TP_LOT=vacant rental): tries what a renter may not do, and what they may,
## through the functions the player's clicks use, printing each result and the money.
func _limits_test() -> void:
	var m0 := money
	set_mode("build")
	print("LIMITS enter Build: %s, mode %s, money $%d -> $%d" % ["allowed" if mode == "build" else "refused", mode, m0, money])
	mode = "build"  # as if a script got past set_mode: the clicks must refuse on their own
	m0 = money
	var had := world.walls.has(Vector3i(3, 2, 0))
	tool = "wall"
	_click_build(_at(2, 2))
	_release(_at(6, 2))
	var walled := world.walls.has(Vector3i(3, 2, 0)) and not had
	print("LIMITS wall on the lawn: %s, money $%d -> $%d" % ["allowed" if walled else "refused", m0, money])
	m0 = money
	var f0 := world.floors[world.idx(Vector2i(3, 3))]
	tool = "floor:1"
	_click_build(_at(3.5, 3.5))
	var floored := world.floors[world.idx(Vector2i(3, 3))] != f0
	print("LIMITS floor tile: %s, money $%d -> $%d" % ["allowed" if floored else "refused", m0, money])
	tool = ""
	mode = "live"
	set_mode("buy")
	var o = world.nearest_object("fridge", Vector2i.ZERO)
	sell = true
	var mp := cam.cam.unproject_position(o.position + Vector3(0, 0.5, 0))
	var aimed: bool = pick_object(mp) == o
	m0 = money
	_click_buy(mp)
	print("LIMITS sell the landlord's %s (click lands on it: %s): %s, money $%d -> $%d" % [o.def["name"], aimed, "allowed" if not o.alive else "refused", m0, money])
	set_buy("plant")
	var t = world.free_tile_near(Vector2i(3, 3))
	m0 = money
	_click_buy(_at(t.x + 0.5, t.y + 0.5))
	var p = world.object_at(t)
	var m1 := money
	set_buy("")
	sell = true
	var bought: bool = p != null and p.kind == "plant" and not world.landlords(p)
	var sold := false
	if bought:
		mp = cam.cam.unproject_position(p.position + Vector3(0, 0.3, 0))
		aimed = pick_object(mp) == p
		_click_buy(mp)
		sold = not p.alive
	print("LIMITS buy a plant ($%d) then sell it (click lands on it: %s): bought %s, money $%d -> $%d; sold %s, money -> $%d" % [Defs.OBJECTS["plant"]["price"], aimed, bought, m0, m1, sold, money])
	set_mode("live")


## TP_PRICES (or any TP_LOT) under TP_TEST: one line with the funds, the lot price and the
## value of every generated home in this town, the player's, the neighbours' and the vacant
## ones. Each is built afresh from its lot's seed, so nothing lived in has changed it yet.
## A bare player lot is not a generated home and is left out.
func _print_prices() -> void:
	var vals := []
	for l in town.by_slot():
		if l["kind"] == "empty" or l["seed"] < 0:
			continue
		if l["kind"] == "home" and l["household"] == 0 and _houses_itself():
			continue
		var w := World.new()
		w.headless = true
		w.setup(l["seed"])
		vals.append(w.value())
		if l["kind"] == "home" and households.has(l["household"]) and households[l["household"]].world.value() != vals.back():
			print("PRICES mismatch on lot %d: lived-in home $%d, built from seed $%d" % [l["id"], households[l["household"]].world.value(), vals.back()])
		w.free()
	vals.sort()
	if vals.is_empty():
		return
	var spare: int = Defs.START_FUNDS - Defs.LOT_PRICE - vals[0]
	print("PRICES seed %d: START_FUNDS $%d, LOT_PRICE $%d | %d homes: cheapest $%d, median $%d, dearest $%d | spare after lot + cheapest $%d (%.1f%% of their cost)" % [
		seed_base, Defs.START_FUNDS, Defs.LOT_PRICE, vals.size(), vals[0], vals[vals.size() / 2], vals.back(), spare, 100.0 * spare / (Defs.LOT_PRICE + vals[0])])


## Where a point on the ground shows on screen, for scripted clicks.
func _at(x: float, y: float) -> Vector2:
	return cam.cam.unproject_position(Vector3(x, 0, y))


## TP_ROOM (with TP_LOT=empty): builds a 5 x 5 room with a door in its south wall through the
## player's own build clicks, then brings a neighbour over, printing where the front door is
## and where the visitor stops. Then checks the fallbacks: a second door on the west wall,
## the south door made a window (a second visitor, and a new child, at the west door), and
## the west door erased.
func _room_test() -> void:
	set_mode("build")
	tool = "wall"
	var c := [Vector2(10, 14), Vector2(15, 14), Vector2(15, 19), Vector2(10, 19), Vector2(10, 14)]
	for i in 4:
		_click_build(_at(c[i].x, c[i].y))
		_release(_at(c[i + 1].x, c[i + 1].y))
	tool = "door"
	_click_build(_at(12.5, 19.05))
	set_mode("live")
	print("ROOM built: %d wall edges, door edge (12, 19, 0) = %d, money $%d" % [world.walls.size(), world.walls.get(Vector3i(12, 19, 0), 0), money])
	print("ROOM front door tile: %s, inside %s (kerb entry %s)" % [world.door_tile, world.door_inside, world.exit_tile])
	_room_visit()
	set_mode("build")
	tool = "door"
	_click_build(_at(10.05, 16.5))
	print("ROOM second door on the west wall, edge (10, 16, 1) = %d; front door tile: %s" % [world.walls.get(Vector3i(10, 16, 1), 0), world.door_tile])
	tool = "window"
	_click_build(_at(12.5, 19.05))
	print("ROOM south door made a window, edge (12, 19, 0) = %d; front door tile: %s, inside %s" % [world.walls.get(Vector3i(12, 19, 0), 0), world.door_tile, world.door_inside])
	_room_visit()
	if not people.is_empty():
		_spawn_child({"hh": 0, "a": people[0].pid, "b": -1})
		print("ROOM new child %s appeared at %s (front door %s, inside %s)" % [people.back().first(), people.back().tile, world.door_tile, world.door_inside])
	tool = "erase"
	_click_build(_at(10, 16))
	_release(_at(10, 17))
	print("ROOM west door erased, edge (10, 16, 1) = %d; front door tile: %s, inside %s" % [world.walls.get(Vector3i(10, 16, 1), 0), world.door_tile, world.door_inside])
	set_mode("live")


## For TP_ROOM: sends a neighbour over and runs the clock until they wait at the door, then
## prints where they stand and which tile they face.
func _room_visit() -> void:
	var v = null
	for i in 1440:
		if v == null:
			v = available_neighbour()
			if v != null:
				v.start_visit(true)
				print("ROOM visitor sent: %s at %05.2f" % [v.pname, hour()])
		elif not is_instance_valid(v) or v.vstate == "waiting":
			break
		_step(1.0 / 60.0, 1.0)
		if _probe != null and _test_days > 0:
			_probe.step(1.0 / 60.0)
	if v != null and is_instance_valid(v) and v.vstate == "waiting":
		print("ROOM visitor %s arrived at %s at %05.2f (front door %s), facing %s" % [v.pname, v.tile, hour(), world.door_tile, _facing(v)])
	else:
		print("ROOM visitor did not arrive")


## The tile next to a person in the direction they face.
func _facing(p: Person) -> Vector2i:
	return p.tile + Vector2i(roundi(sin(p.rotation.y)), roundi(cos(p.rotation.y)))


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

func _report() -> void:
	print("=== %d days simulated, household %d, over=%s ===" % [day, people.size(), over])
	for id in households:
		var hh: Household = households[id]
		print("--- household %d %s%s: $%d, %d objects" % [id, hh.family, " (player)" if hh.player else "", hh.money, hh.world.objects.size()])
		var v := hh.world.value_parts()
		print("      home value $%d (walls $%d, doors $%d, windows $%d, floors $%d, objects $%d)" % [v["total"], v["walls"], v["doors"], v["windows"], v["floors"], v["objects"]])
		for p in household_of(id):
			var line := "  %-9s %-5s age %4.1f %s |" % [p.first(), p.stage(), p.age, p.vstate]
			for n in Defs.NEEDS:
				line += " %s %2d" % [n.substr(0, 3), int(p.needs[n])]
			print(line)
			var jb := "none"
			if p.job != null:
				jb = "%s L%d" % [Defs.CAREERS[p.job.career]["name"], p.job.level]
			print("      job %s, doing %s, actions %s" % [jb, p.activity(), p.stats])
	for l in town.by_slot():
		print("   lot %d slot %d %s%s seed %d" % [l["id"], l["slot"], l["kind"], " household %d" % l["household"] if l["kind"] == "home" else "", l["seed"]])
	print("   memorials: ", households.values().map(func(h): return h.world.objects.filter(func(o): return o.kind == "grave").map(func(o): return o.label)))
	if OS.has_environment("TP_SAVE") and _runs == 1:
		save_game(true)
		print("   saved to ", save_path)


func _selftest() -> void:
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
	set_mode(OS.get_environment("TP_MODE") if OS.has_environment("TP_MODE") else "live")
	for o in world.objects:
		if o.kind == "phone":
			_click_live(cam.cam.unproject_position(o.position + Vector3(0, 0.5, 0)))
			print("selftest phone menu items: ", ui.menu.item_count)
			if ui.menu_calls.size() > 1:
				ui.menu_calls[1].call()
	ui.menu.hide()
	for p in people:
		if p != selected:
			_click_live(cam.cam.unproject_position(p.position + Vector3(0, 1.0, 0)))
			print("selftest social menu items: ", ui.menu.item_count)
			ui.menu_calls[1].call()
			break
	ui.menu.hide()
	print("selftest queue: ", selected.queue.map(func(a): return a.label), " cur: ", selected.activity())
	save_game()
	print("selftest save exists: ", FileAccess.file_exists(save_path))
	ui.toggle_help()
	ui.toggle_help()
