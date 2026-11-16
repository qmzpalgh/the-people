class_name Person
extends Node3D
## A person: household member or neighbour. Needs, traits, skills, an action queue,
## a rule-based autonomy brain, life stages, and (for neighbours) visiting behaviour.

const WALK := 2.2  # tiles per game minute
const HIP := 0.8

var game
var world: World
var pid := 0
var pname := ""
var resident := true
var household := 0  # 0 = the player's household
var needs := {}
var traits := {}
var skills := {}
var job = null  # {career: int, level: int, perf: float}
var age := 10.0  # days
var lifespan := 42.0
var starve_t := 0.0
var dead := false
var look := {}
var queue: Array = []
var cur = null
var tile := Vector2i.ZERO
var path: Array = []
var away := false
var idle_t := 1.0
var anim_t := 0.0
var bubble_t := 0.0
var work_flag_day := -1
var work_day := -1
var pose := "stand"
var stats := {}
var rng := RandomNumberGenerator.new()
var seed_v := 0

# Neighbour visiting state: off, stroll, arriving, waiting, guest, leaving.
var vstate := "off"
var visit_t := 0.0
var wait_t := 0.0
var stroll_x := 0.0
var stroll_enter := false

var body: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var ring: MeshInstance3D
var bubble: Label3D
var loop_p: AudioStreamPlayer3D
var voice: AudioStreamPlayer3D
var h_scale := 1.0
var _stage := "adult"

var shirt: Color:
	get: return look["shirt"]


func setup(g, w: World, id: int, sv: int, family: String, is_resident := true) -> void:
	game = g
	world = w
	pid = id
	seed_v = sv
	resident = is_resident
	rng.seed = sv
	pname = Defs.first_name(rng) + " " + family
	for n in Defs.NEEDS:
		needs[n] = rng.randf_range(55.0, 90.0)
	for t in Defs.TRAITS:
		traits[t] = rng.randi_range(1, 9)
	for s in Defs.SKILLS:
		skills[s] = 0.0
	var skin_tones := [Color(0.96, 0.8, 0.68), Color(0.87, 0.67, 0.5), Color(0.72, 0.5, 0.35), Color(0.52, 0.35, 0.24), Color(0.36, 0.24, 0.17)]
	var hair_cols := [Color(0.1, 0.08, 0.07), Color(0.35, 0.22, 0.12), Color(0.75, 0.6, 0.3), Color(0.6, 0.25, 0.12), Color(0.3, 0.4, 0.7)]
	look = {
		"skin": skin_tones[rng.randi() % skin_tones.size()], "hair": hair_cols[rng.randi() % hair_cols.size()],
		"shirt": Color.from_hsv(rng.randf(), 0.6, 0.8), "pants": Color.from_hsv(rng.randf(), 0.35, 0.4),
		"style": rng.randi() % 4, "h": rng.randf_range(0.9, 1.08), "wide": rng.randf_range(0.9, 1.15),
		"pitch": rng.randf_range(0.8, 1.25),
	}
	age = rng.randf_range(8.0, 18.0) if is_resident else rng.randf_range(8.0, 36.0)
	lifespan = rng.randf_range(38.0, 46.0)
	_stage = stage()
	_build_fixed()
	_build()


func first() -> String:
	return pname.split(" ")[0]


func stage() -> String:
	if age < Defs.CHILD_DAYS:
		return "child"
	return "elder" if age >= Defs.ELDER_AT else "adult"


func refresh_look() -> void:
	_stage = stage()
	_build()


## True during this person's work or school hours (or within `lead` hours before them).
func busy_now(lead := 0.0) -> bool:
	var c = sched()
	if c == null or game.day % 7 >= 5:
		return false
	var h: float = game.hour()
	return h >= c["start"] - lead and h < c["start"] + c["hours"]


func stage_text() -> String:
	match stage():
		"child": return "Child, grows up in %d days" % ceili(Defs.CHILD_DAYS - age)
		"elder": return "Elder"
	return "Adult, %d days old" % int(age)


func sched() -> Variant:
	if stage() == "child":
		return Defs.SCHOOL
	if job != null:
		return Defs.CAREERS[job.career]
	return null


# ---------------------------------------------------------------- appearance

func _build_fixed() -> void:
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.38
	tm.outer_radius = 0.46
	ring.mesh = tm
	ring.position = Vector3(0, 0.04, 0)
	ring.scale = Vector3(1, 0.3, 1)
	ring.material_override = Meshes.mat(Color(0.95, 0.69, 0.12), 1.5)
	ring.visible = false
	add_child(ring)
	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.font_size = 56
	bubble.outline_size = 14
	bubble.pixel_size = 0.006
	bubble.text = ""
	add_child(bubble)
	loop_p = AudioStreamPlayer3D.new()
	Sfx.setup3(loop_p)
	add_child(loop_p)
	voice = AudioStreamPlayer3D.new()
	Sfx.setup3(voice)
	add_child(voice)


func _build() -> void:
	if body != null:
		body.free()
	var st := stage()
	var skin: Color = look["skin"]
	var hair: Color = look["hair"]
	if st == "elder":
		hair = hair.lerp(Color(0.82, 0.82, 0.84), 0.85)
	var pants: Color = look["pants"]
	var kid := st == "child"
	h_scale = look["h"] * (0.62 if kid else 1.0)
	var wide: float = look["wide"]
	body = Node3D.new()
	body.scale = Vector3(h_scale * wide, h_scale, h_scale * wide)
	add_child(body)
	leg_l = Node3D.new()
	leg_r = Node3D.new()
	arm_l = Node3D.new()
	arm_r = Node3D.new()
	var i := 0
	for leg in [leg_l, leg_r]:
		leg.position = Vector3(-0.1 + 0.2 * i, HIP, 0)
		body.add_child(leg)
		Meshes.box(leg, Vector3(0.16, 0.8, 0.18), Vector3(0, -0.4, 0), pants)
		Meshes.box(leg, Vector3(0.17, 0.08, 0.27), Vector3(0, -0.76, 0.05), Meshes.DARK)
		i += 1
	Meshes.box(body, Vector3(0.42, 0.6, 0.24), Vector3(0, 1.1, 0), shirt)
	i = 0
	for arm in [arm_l, arm_r]:
		arm.position = Vector3(-0.27 + 0.54 * i, 1.36, 0)
		body.add_child(arm)
		Meshes.box(arm, Vector3(0.11, 0.56, 0.13), Vector3(0, -0.26, 0), shirt.darkened(0.1))
		Meshes.ball(arm, 0.065, Vector3(0, -0.58, 0), skin)
		i += 1
	var hs := 1.3 if kid else 1.0  # children have proportionally bigger heads
	var hy := 1.43 + 0.17 * hs
	Meshes.cyl(body, 0.06, 0.06, 0.1, Vector3(0, 1.43, 0), skin)
	Meshes.ball(body, 0.17 * hs, Vector3(0, hy, 0), skin)
	for sx in [-1.0, 1.0]:
		Meshes.ball(body, 0.025 * hs, Vector3(sx * 0.065 * hs, hy + 0.03, 0.15 * hs), Meshes.DARK)
	match int(look["style"]):
		0:
			Meshes.ball(body, 0.18 * hs, Vector3(0, hy + 0.04, -0.03), hair)
		1:
			Meshes.ball(body, 0.185 * hs, Vector3(0, hy + 0.04, -0.03), hair)
			Meshes.box(body, Vector3(0.34, 0.36, 0.1) * hs, Vector3(0, hy - 0.14 * hs, -0.13 * hs), hair)
		2:
			Meshes.ball(body, 0.18 * hs, Vector3(0, hy + 0.04, -0.03), hair)
			Meshes.ball(body, 0.09 * hs, Vector3(0, hy + 0.23 * hs, -0.06), hair)
		_:
			Meshes.cyl(body, 0.165 * hs, 0.12 * hs, 0.1, Vector3(0, hy + 0.14 * hs, -0.01), hair)
	bubble.position = Vector3(0, 1.85 * h_scale + 0.4, 0)
	set_pose("stand", 0.0)


func set_selected(s: bool) -> void:
	ring.visible = s


func say(text: String, secs := 2.0) -> void:
	bubble.text = text
	bubble_t = secs


func _chirp() -> void:
	if game.sfx == null:
		return
	voice.stream = game.sfx.get_stream("talk%d" % rng.randi_range(0, 2))
	voice.pitch_scale = look["pitch"] * (1.5 if stage() == "child" else 1.0) * rng.randf_range(0.95, 1.05)
	voice.play()


func _loop(n: String) -> void:
	if n == "" or game.sfx == null:
		loop_p.stop()
		return
	loop_p.stream = game.sfx.get_stream(n)
	loop_p.play()


func face(p: Vector3) -> void:
	var d := p - position
	if absf(d.x) + absf(d.z) > 0.01:
		rotation.y = atan2(d.x, d.z)


func set_pose(p: String, h: float) -> void:
	pose = p
	body.rotation = Vector3.ZERO
	match p:
		"sit":
			body.position = Vector3(0, h - HIP * h_scale + 0.03, 0)
		"lie":
			body.rotation.x = -PI / 2.0
			body.position = Vector3(0, h + 0.14, 0.85 * h_scale)
		_:
			body.position = Vector3(0, h, 0)


# ---------------------------------------------------------------- state

func mood() -> float:
	var s := 0.0
	var w := 0.0
	for n in Defs.NEEDS:
		s += needs[n] * Defs.MOOD_W[n]
		w += Defs.MOOD_W[n]
	return s / w


func activity() -> String:
	if away and resident:
		return "At school" if stage() == "child" else "At work"
	if cur == null:
		return "Idle"
	return cur.label


func act_use(o: SimObject, it: Dictionary, auto := false) -> Dictionary:
	return {"kind": "use", "obj": o, "def": it, "label": it["label"], "auto": auto, "state": "new", "t": 0.0, "tries": 0}


func act_social(p: Person, sd: Dictionary, auto := false) -> Dictionary:
	return {"kind": "social", "other": p, "def": sd, "label": "%s: %s" % [sd["label"], p.first()], "auto": auto, "state": "new", "t": 0.0, "tries": 0}


func act_goto(t: Vector2i, auto := false, tag := "") -> Dictionary:
	return {"kind": "goto", "tile": t, "label": "Go here" if not auto else "Wander", "auto": auto, "state": "new", "t": 0.0, "tries": 0, "tag": tag}


func enqueue(a: Dictionary) -> void:
	if away or dead or queue.size() >= 8:
		return
	queue.append(a)
	if cur != null and cur.get("auto", false):
		cancel_current()


func cancel_current() -> void:
	if cur != null and not away:
		_finish(cur, false)


func can_socialize() -> bool:
	if away or dead:
		return false
	if not resident and vstate != "waiting" and vstate != "guest":
		return false
	if cur == null:
		return true
	if cur.kind in ["work", "passout", "recv", "social"]:
		return false
	return not (cur.state == "do" and (cur.get("def", {}).get("busy", false) or cur.get("def", {}).get("sleep", false)))


## Whether two people may start a family together.
func can_have_child_with(o: Person) -> bool:
	return resident and o.resident and stage() == "adult" and o.stage() == "adult" \
			and game.people.size() + game.pending.size() < Defs.MAX_HOUSEHOLD


## Rules deciding whether an interaction is possible (and, for autonomy, sensible).
func usable(o: SimObject, it: Dictionary, auto: bool) -> bool:
	if not o.alive or not o.has_room(self):
		return false
	if it.get("adult", false) and stage() == "child":
		return false
	match it.get("cond", ""):
		"no_job":
			if job != null or stage() != "adult":
				return false
		"can_invite":
			var h: float = game.hour()
			if h < 8.0 or h > 21.0 or game.available_neighbour() == null or game.visitors().size() >= 2:
				return false
		"can_adopt":
			if game.people.size() + game.pending.size() >= Defs.MAX_HOUSEHOLD:
				return false
	if it.has("req") and world.nearest_object(it["req"], tile) == null:
		return false
	if it.get("cost", 0) > game.money:
		return false
	if not resident:
		# Guests are polite: no sleeping, bathing, spending or life decisions.
		if it.get("sleep", false) or it.get("cost", 0) > 0 or it.has("special") or it.has("skill") or it.has("then"):
			return false
		if it.get("busy", false) and it["id"] != "use":
			return false
	if auto:
		if it.get("hidden", false) or not it.get("auto", true):
			return false
		if it.has("mood_min") and mood() < it["mood_min"]:
			return false
		if it.has("until") and needs[it["until"]] > 82.0:
			return false
		if it.get("sleep", false) and needs.energy > 65.0:
			return false
		if it.get("special", "") == "invite" and needs.social > 55.0:
			return false
	elif it.has("mood_min") and mood() < it["mood_min"] - 20:
		return false
	return true


# ---------------------------------------------------------------- simulation

func tick(dh: float, ds: float) -> void:
	if dead:
		return
	_age(dh)
	if dead:
		return
	if not resident and not _visitor_tick(dh, ds):
		return
	if away:
		_tick_away(dh)
		return
	_decay(dh)
	_check_critical(dh)
	if dead:
		return
	if cur == null:
		if not queue.is_empty():
			cur = queue.pop_front()
			cur.state = "new"
		elif (resident and game.free_will) or vstate == "guest":
			idle_t -= ds
			if idle_t <= 0.0:
				idle_t = rng.randf_range(2.0, 5.0)
				_autonomous()
	if cur != null:
		match cur.state:
			"new": _begin(cur)
			"walk": _walk(cur, ds)
			"do": _do(cur, dh)
	_animate(ds)


func _age(dh: float) -> void:
	age += dh / 24.0 * game.age_rate
	if resident and away:
		return  # at work or school; catch up when home
	var st := stage()
	if st != _stage:
		_stage = st
		cancel_current()
		_build()
		var known: bool = resident or game.known(self)
		var who := first() if resident else "Your neighbour %s" % pname
		if st == "adult":
			if not resident and rng.randf() < 0.75:
				job = {"career": rng.randi() % Defs.CAREERS.size(), "level": 0, "perf": 0.0}
			if known:
				game.msg("%s has grown up." % who, "jingle")
		elif st == "elder":
			var had_job: bool = job != null
			job = null
			if resident and had_job:
				game.msg("%s became an elder and retired on a pension of $%d a day." % [who, Defs.PENSION], "chime")
			elif known:
				game.msg("%s became an elder." % who, "chime")
	if age >= lifespan:
		die("old age")


func die(cause: String) -> void:
	if dead:
		return
	cancel_current()
	queue.clear()
	_loop("")
	dead = true
	game.on_death(self, cause)


func _decay(dh: float) -> void:
	var rates := {}
	var sleeping := false
	if cur != null and cur.state == "do":
		rates = cur.get("rates", {})
		sleeping = cur.get("def", {}).get("sleep", false)
	for n in Defs.NEEDS:
		if n == "room":
			continue
		var r: float = -Defs.DECAY[n]
		match n:
			"hygiene": r *= 1.25 - traits.neat * 0.05
			"social": r *= 0.6 + traits.outgoing * 0.08
			"fun": r *= 0.7 + traits.playful * 0.06
			"energy": r *= (1.2 - traits.active * 0.04) * (1.25 if _stage == "elder" else 1.0)
		if sleeping and n != "energy":
			r *= 0.4
		if rates.has(n):
			var x: float = rates[n]
			r = x if x > 0.0 else r + x
		needs[n] = clampf(needs[n] + r * dh, 0.0, 100.0)
	needs.room = move_toward(needs.room, world.room_score_at(tile), 60.0 * dh)


func _check_critical(dh: float) -> void:
	if needs.hunger <= 0.0:
		if starve_t == 0.0:
			game.msg("%s is starving and needs food now." % first(), "error")
		starve_t += dh
		if starve_t >= 10.0:
			die("starvation")
			return
	else:
		starve_t = 0.0
	if needs.energy <= 0.0 and (cur == null or cur.kind != "passout"):
		queue.clear()
		cancel_current()
		cur = {"kind": "passout", "label": "Passed out", "state": "do", "t": 0.0, "dur": 3.0,
			"rates": {"energy": 12.0}, "posed": true, "def": {"sleep": true, "bubble": "Zzz"}}
		set_pose("lie", 0.0)
		game.msg("%s collapsed from exhaustion." % first())
		_count("passed out")
	if needs.bladder <= 0.0:
		needs.bladder = 100.0
		needs.hygiene = maxf(0.0, needs.hygiene - 60.0)
		needs.comfort = maxf(0.0, needs.comfort - 30.0)
		say("Oops!", 3.0)
		game.msg("%s had an accident." % first())
		_count("accident")
		if world.can_place("puddle", tile.x, tile.y, 0):
			world.add_object("puddle", tile.x, tile.y, 0)


func _begin(a: Dictionary) -> void:
	a.tries += 1
	if a.tries > 4:
		_fail(a)
		return
	match a.kind:
		"goto":
			var p = world.path(tile, a.tile)
			if p == null:
				_fail(a)
				return
			path = p
		"use":
			if not is_instance_valid(a.obj) or not usable(a.obj, a.def, false):
				_fail(a, "No!" if is_instance_valid(a.obj) and a.obj.has_room(self) else "?")
				return
			var o: SimObject = a.obj
			o.claim(self)
			var target: SimObject = o
			a.seat = null
			if a.def.get("seat", false):
				var s = world.find_seat(o.tile, self)
				if s != null and world.find_access(tile, s) != null:
					s.claim(self)
					a.seat = s
					target = s
			var p = world.find_access(tile, target)
			if p == null:
				_fail(a)
				return
			path = p
		"eat":
			a.seat = null
			path = []
			var s = world.find_seat(tile, self)
			if s != null:
				var p = world.find_access(tile, s)
				if p != null:
					s.claim(self)
					a.seat = s
					path = p
		"social":
			if not is_instance_valid(a.other) or a.other.away or a.other.dead:
				_fail(a)
				return
			var p = world.path_near(tile, a.other.tile)
			if p == null:
				_fail(a)
				return
			path = p
		"work":
			var p = world.path(tile, world.exit_tile)
			if p == null:
				_fail(a)
				return
			path = p
	a.state = "walk"


func _walk(a: Dictionary, ds: float) -> void:
	var step := WALK * ds * (0.75 if _stage == "elder" else 1.0)
	while step > 0.0 and not path.is_empty():
		var nt: Vector2i = path[0]
		if not world.walkable(nt):
			path = []
			a.state = "new"
			return
		var target := world.tile_center(nt)
		var d := target - position
		var dist := d.length()
		if dist <= step:
			position = target
			tile = nt
			path.pop_front()
			step -= dist
		else:
			position += d / dist * step
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 0.35)
			step = 0.0
	if path.is_empty():
		_arrive(a)


func _pose_slot(o: SimObject, p: String, face_back: bool) -> void:
	var sp := o.slot_pos(o.users.find(self))
	position = Vector3(sp.x, 0, sp.z)
	rotation.y = o.rotation.y + (PI if face_back else 0.0)
	set_pose(p, sp.y)


func _arrive(a: Dictionary) -> void:
	match a.kind:
		"goto":
			_finish(a, true)
		"use", "eat":
			var it: Dictionary = a.def
			var cost: int = it.get("cost", 0)
			if cost > game.money:
				_fail(a, "$?")
				return
			game.money -= cost
			var rates: Dictionary = it.get("needs", {}).duplicate()
			var o = a.get("obj")
			var seat = a.get("seat")
			if seat != null:
				_pose_slot(seat, "sit", false)
				if not rates.has("comfort"):
					rates["comfort"] = seat.def.get("comfort", 25.0)
			elif o != null and o.def.has("slots"):
				_pose_slot(o, it.get("pose", "stand"), o.def.get("face_back", false))
			elif o != null:
				face(o.position)
			a.posed = true
			var dur: float = it.get("dur", 1.0)
			if it["id"] == "cook":
				dur *= 1.0 - skills.cooking * 0.05
			elif it["id"] == "eat":
				rates["hunger"] *= 1.0 + skills.cooking * 0.04
			a.rates = rates
			a.dur = dur
			a.t = 0.0
			a.state = "do"
			_loop(it.get("snd", ""))
		"social":
			var o: Person = a.other
			if not is_instance_valid(o) or o.away or o.dead:
				_fail(a)
				return
			if maxi(absi(o.tile.x - tile.x), absi(o.tile.y - tile.y)) > 1:
				a.state = "new"
				return
			var sd: Dictionary = a.def
			if not o.can_socialize() or (sd["id"] == "baby" and not can_have_child_with(o)):
				_fail(a, "...")
				return
			var rel: float = game.get_rel(self, o)
			var chance: float = 0.65 + rel / 150.0 + (o.traits[sd["trait"]] - 5) * 0.04
			a.ok = sd["id"] in ["insult", "greet"] or rng.randf() < clampf(chance, 0.1, 0.97)
			a.rates = {"social": sd["social"]}
			if sd["fun"] > 0.0:
				a.rates["fun"] = sd["fun"]
			a.dur = sd["dur"]
			a.t = 0.0
			a.state = "do"
			face(o.position)
			o.receive_social(self, a)
			if o.vstate == "waiting" and resident:
				o.vstate = "guest"
				o.visit_t = 0.0
				game.msg("%s came in to visit." % o.first())
		"work":
			var c = sched()
			if c == null or game.hour() >= c["start"] + c["hours"] - 0.5:
				say("Late!", 3.0)
				_finish(a, false)
				return
			away = true
			visible = false
			work_day = game.day
			a.state = "away"


func receive_social(from: Person, src: Dictionary) -> void:
	if cur != null:
		var c: Dictionary = cur
		_finish(c, false)
		if not c.get("auto", false) and c.kind in ["use", "goto"] and c.get("tag", "") == "":
			c.state = "new"
			c.t = 0.0
			c.tries = 0
			queue.push_front(c)
	path = []
	cur = {"kind": "recv", "other": from, "def": {"bubble": "..." if src.ok else "Hmph"}, "label": "Talk with %s" % from.first(),
		"auto": true, "state": "do", "t": 0.0, "dur": src.dur, "rates": src.rates if src.ok else {}}
	face(from.position)


func _do(a: Dictionary, dh: float) -> void:
	a.t += dh
	var it: Dictionary = a.get("def", {})
	for s in it.get("skill", {}):
		var before := int(skills[s])
		skills[s] = minf(10.0, skills[s] + it["skill"][s] * dh)
		if int(skills[s]) > before:
			game.msg("%s reached %s level %d." % [first(), s, int(skills[s])], "jingle")
	if it.has("bubble") and bubble_t <= 0.0:
		say(it["bubble"], 1.5)
		if a.kind in ["social", "recv"] or it.get("talk", false):
			_chirp()
	var done: bool = a.t >= a.get("dur", 1.0)
	var u: String = it.get("until", "")
	if u != "" and needs[u] >= 99.5:
		done = true
	if it.get("sleep", false) and a.kind != "passout" and (needs.hunger < 8.0 or needs.bladder < 8.0):
		done = true
	if done:
		_finish(a, true)


func _release(a: Dictionary) -> void:
	for k in ["obj", "seat"]:
		var o = a.get(k)
		if o != null and is_instance_valid(o):
			o.release(self)


func _fail(a: Dictionary, text := "?") -> void:
	say(text, 2.5)
	_count("failed")
	_finish(a, false)
	if a.get("tag", "") != "":
		_walk_off()


func _count(key: String) -> void:
	stats[key] = stats.get(key, 0) + 1


func _finish(a: Dictionary, ok: bool) -> void:
	_release(a)
	_loop("")
	if a.get("posed", false):
		position = world.tile_center(tile)
		set_pose("stand", 0.0)
	path = []
	if cur == a:
		cur = null
	idle_t = rng.randf_range(0.5, 2.0)
	if not ok:
		return
	_count(a.label.split(":")[0].split(" (")[0])
	var it: Dictionary = a.get("def", {})
	if it.has("end_snd") and game.sfx != null:
		game.sfx.play_at(it["end_snd"], position)
	match a.kind:
		"goto":
			match a.get("tag", ""):
				"arrive":
					vstate = "waiting"
					wait_t = 1.5
					face(world.tile_center(tile + Vector2i(0, -1)))
					game.msg("%s is at the door. Greet them to let them in." % pname, "knock")
				"leave":
					_walk_off()
		"use", "eat":
			match it.get("special", ""):
				"job":
					game.assign_job(self)
				"paint":
					var v := int(20 + skills.creativity * 30 + rng.randi_range(0, 40))
					game.money += v
					game.msg("%s sold a painting for $%d." % [first(), v], "coin")
				"remove":
					game.remove_object(a.obj)
				"invite":
					game.invite(self, a.get("who"))
				"adopt":
					game.expect_child(self, null)
			var th = it.get("then")
			if th != null:
				if th["kind"] == "self":
					queue.push_front({"kind": "eat", "def": Defs.EAT, "label": "Eat", "auto": a.auto, "state": "new", "t": 0.0, "tries": 0})
				else:
					var o2 = world.nearest_object(th["kind"], tile)
					if o2 != null:
						var a2 := act_use(o2, o2.interaction(th["id"]), a.auto)
						queue.push_front(a2)
		"social":
			var o: Person = a.other
			if is_instance_valid(o) and not o.dead:
				var sd: Dictionary = it
				if a.get("ok", false):
					game.add_rel(self, o, sd["rel"])
					if sd["id"] == "insult":
						o.needs.fun = maxf(0.0, o.needs.fun - 12.0)
						o.say("Hey!", 2.0)
					elif sd["id"] == "baby" and can_have_child_with(o):
						game.expect_child(self, o)
				else:
					game.add_rel(self, o, -3.0)
					say("Aww", 2.0)


func go_to_work() -> void:
	if away or sched() == null:
		return
	if cur != null and cur.get("auto", false):
		cancel_current()
	var label := "Go to school" if stage() == "child" else "Go to work"
	queue.push_front({"kind": "work", "label": label, "auto": false, "state": "new", "t": 0.0, "tries": 0})


func _tick_away(dh: float) -> void:
	needs.hunger = maxf(20.0, needs.hunger - 3.0 * dh)
	needs.energy = maxf(10.0, needs.energy - 4.5 * dh)
	needs.fun = maxf(10.0, needs.fun - 3.0 * dh)
	needs.hygiene = maxf(20.0, needs.hygiene - 2.5 * dh)
	needs.comfort = maxf(20.0, needs.comfort - 2.0 * dh)
	needs.social = minf(100.0, needs.social + 3.0 * dh)
	needs.bladder = maxf(45.0, needs.bladder - 3.0 * dh)
	var c = sched()
	var h: float = game.hour()
	if c != null and h < c["start"] + c["hours"] and h >= c["start"] - 1.5:
		return
	away = false
	visible = true
	cur = null
	tile = world.exit_tile
	position = world.tile_center(tile)
	_count("worked")
	if job == null or c == null:
		skills.logic = minf(10.0, skills.logic + 0.12)
		game.msg("%s is home from school." % first())
		return
	var pay: int = c["pay"][job.level]
	game.money += pay
	job.perf += 14.0 + (mood() - 50.0) * 0.5
	game.msg("%s is home from work (+$%d)." % [first(), pay], "coin")
	if job.level < 4 and job.perf >= 100.0:
		if skills[c["skill"]] >= (job.level + 1) * 2.0:
			job.level += 1
			job.perf = 0.0
			game.msg("%s was promoted to %s." % [first(), c["titles"][job.level]], "jingle")
		else:
			job.perf = 100.0


# ---------------------------------------------------------------- visiting

## Brings a neighbour onto the street; if `enter`, they walk up to the front door.
func start_visit(enter: bool) -> void:
	var left := rng.randf() < 0.5
	position = Vector3(-28.0 if left else World.W + 28.0, 0, World.H + 1.0)
	stroll_enter = enter
	stroll_x = world.exit_tile.x + 0.5 if enter else (World.W + 28.0 if left else -28.0)
	vstate = "stroll"
	away = true
	visible = true
	cur = null
	queue.clear()
	set_pose("stand", 0.0)


func come_in() -> void:
	if vstate == "stroll":
		stroll_enter = true
		stroll_x = world.exit_tile.x + 0.5


func leave() -> void:
	if vstate not in ["waiting", "guest", "arriving"]:
		return
	cancel_current()
	queue.clear()
	vstate = "leaving"
	cur = act_goto(world.exit_tile, false, "leave")
	cur.label = "Heading home"


func _walk_off() -> void:
	cur = null
	queue.clear()
	vstate = "stroll"
	away = true
	stroll_enter = false
	stroll_x = -28.0 if rng.randf() < 0.5 else World.W + 28.0


## Returns true when the neighbour is on the lot and should run the normal tick.
func _visitor_tick(dh: float, ds: float) -> bool:
	match vstate:
		"off":
			# Home life happens off the lot: they look after themselves there.
			for n in Defs.NEEDS:
				needs[n] = move_toward(needs[n], 85.0, 12.0 * dh)
			return false
		"stroll":
			var step := WALK * ds
			position.z = move_toward(position.z, World.H + 1.0, step)
			var dx := stroll_x - position.x
			if absf(dx) <= step:
				position.x = stroll_x
				if stroll_enter:
					vstate = "arriving"
					away = false
					tile = world.exit_tile
					position = world.tile_center(tile)
					cur = act_goto(world.door_tile, false, "arrive")
					cur.label = "Visiting"
				else:
					vstate = "off"
					visible = false
			else:
				position.x += signf(dx) * step
				rotation.y = PI / 2.0 * signf(dx)
				anim_t += ds
				var sw := sin(anim_t * 9.0) * 0.7
				leg_l.rotation.x = sw
				leg_r.rotation.x = -sw
				arm_l.rotation.x = -sw * 0.8
				arm_r.rotation.x = sw * 0.8
			return false
		"waiting":
			wait_t -= dh
			if wait_t <= 0.0:
				game.msg("%s gave up waiting and went home." % first())
				leave()
		"guest":
			visit_t += dh
			var h: float = game.hour()
			if visit_t > 3.5 or h >= 23.0 or h < 6.0 or needs.energy < 25.0 or needs.hunger < 22.0 or mood() < 32.0 or busy_now(1.0):
				game.msg("%s said goodbye and went home." % first())
				leave()
	return true


# ---------------------------------------------------------------- autonomy

func _gains(it: Dictionary) -> Dictionary:
	if it.has("gain"):
		return it["gain"]
	var out := {}
	var nd: Dictionary = it.get("needs", {})
	var dur: float = it.get("dur", 1.0)
	var u: String = it.get("until", "")
	if u != "" and nd.get(u, 0.0) > 0.0:
		dur = minf(dur, (100.0 - needs[u]) / nd[u])
	for n in nd:
		out[n] = nd[n] * dur
	return out


func _score(g: Dictionary, it: Dictionary) -> float:
	var s := 0.0
	for n in g:
		var v: float = g[n]
		if v > 0.0:
			var cur_v: float = needs[n]
			var w := pow((100.0 - cur_v) / 100.0, 2.0)
			if cur_v < 20.0:
				w *= 2.0
			var m := 1.0
			match n:
				"fun": m = 0.7 + traits.playful * 0.06
				"social": m = 0.6 + traits.outgoing * 0.08
				"hygiene": m = 0.7 + traits.neat * 0.06
			s += minf(v, 100.0 - cur_v) * w * m
		else:
			s += v * 0.15
	if it.has("skill"):
		s += 3.0 + traits.active * 0.3
		if job != null and it["skill"].has(Defs.CAREERS[job.career]["skill"]):
			s += 7.0
	if it.get("special", "") == "job":
		s += 18.0
	if it.get("sleep", false):
		var h: float = game.hour()
		if h >= 21.0 or h < 5.0:
			s *= 2.5
	return s


func _autonomous() -> void:
	var cands: Array = []
	var low := ""
	var lowv := 25.0
	for n in Defs.NEEDS:
		if n != "room" and needs[n] < lowv:
			lowv = needs[n]
			low = n
	for o in world.objects:
		for it in o.def.get("acts", []):
			if not usable(o, it, true):
				continue
			var g := _gains(it)
			var dist := Vector2(o.tile - tile).length()
			cands.append([_score(g, it) / (1.0 + 0.03 * dist), act_use(o, it, true), g])
	for p in game.everyone():
		if p == self or not p.can_socialize():
			continue
		if resident and p.vstate == "waiting":
			# Rule: someone at the door gets answered before anything else.
			cands.append([60.0, act_social(p, Defs.GREET, true), {"social": 10.0}])
			low = ""
			continue
		if not resident and not p.resident:
			continue
		var r: float = game.get_rel(self, p)
		var dist := Vector2(p.tile - tile).length()
		for sd in Defs.SOCIALS:
			if r < sd["min_rel"] or not sd.get("auto", true):
				continue
			if sd["id"] == "insult" and (r > -30.0 or traits.nice > 3):
				continue
			var g := {"social": sd["social"] * sd["dur"], "fun": sd["fun"] * sd["dur"]}
			var sc: float = _score(g, sd) * (0.5 + traits.outgoing * 0.1) / (1.0 + 0.03 * dist)
			if not p.resident or not resident:
				sc *= 1.6  # hosts and guests seek each other out
			cands.append([sc, act_social(p, sd, true), g])
	if low != "":
		var f := cands.filter(func(c): return c[2].get(low, 0.0) > 0.0)
		if not f.is_empty():
			cands = f
	if cands.is_empty():
		_wander()
		return
	cands.sort_custom(func(a, b): return a[0] > b[0])
	if cands[0][0] < 5.0:
		if rng.randf() < 0.3:
			_wander()
		return
	var top := cands.slice(0, 3)
	if top[0][0] >= 60.0:
		top = [top[0]]
	var total := 0.0
	for c in top:
		total += maxf(c[0], 0.01)
	var roll := rng.randf() * total
	var pick: Array = top[0]
	for c in top:
		roll -= maxf(c[0], 0.01)
		if roll <= 0.0:
			pick = c
			break
	cur = pick[1]
	cur.state = "new"


func _wander() -> void:
	var t = world.random_walkable_near(tile, 4)
	if t != null and world.path(tile, t) != null:
		cur = act_goto(t, true)


# ---------------------------------------------------------------- animation

func _animate(ds: float) -> void:
	anim_t += ds
	bubble_t -= game.rdt
	if bubble_t <= 0.0 and bubble.text != "":
		bubble.text = ""
	var walking: bool = cur != null and cur.state == "walk" and not path.is_empty()
	var doing: bool = cur != null and cur.state == "do"
	var sw := sin(anim_t * 9.0) * 0.7 if walking else 0.0
	var leg_base := -PI / 2.0 if pose == "sit" else 0.0
	leg_l.rotation.x = leg_base + sw
	leg_r.rotation.x = leg_base - sw
	var al := -sw * 0.8
	var ar := sw * 0.8
	if doing and pose != "lie" and cur.kind in ["use", "eat", "social", "recv"] and not cur.get("def", {}).get("sleep", false):
		al = -0.9 + sin(anim_t * 5.0) * 0.3
		ar = -0.9 + cos(anim_t * 4.0) * 0.3
		if cur.get("def", {}).get("dance", false):
			body.position.y = absf(sin(anim_t * 6.0)) * 0.1
			rotation.y += ds * 2.5
			al = -2.4 + sin(anim_t * 6.0) * 0.5
			ar = -2.4 + cos(anim_t * 6.0) * 0.5
	arm_l.rotation.x = al
	arm_r.rotation.x = ar


# ---------------------------------------------------------------- persistence

func save_state() -> Dictionary:
	var lk := {}
	for k in look:
		lk[k] = look[k].to_html() if look[k] is Color else look[k]
	return {
		"pid": pid, "seed": seed_v, "household": household, "name": pname, "resident": resident, "age": age, "lifespan": lifespan,
		"look": lk, "needs": needs, "traits": traits, "skills": skills, "job": job, "tile": [tile.x, tile.y],
		"away": away and resident, "work_day": work_day, "work_flag_day": work_flag_day, "starve_t": starve_t,
	}


func load_state(d: Dictionary) -> void:
	pname = d["name"]
	household = int(d.get("household", 0 if resident else 1))
	age = d["age"]
	lifespan = d["lifespan"]
	for k in d["look"]:
		look[k] = Color.html(d["look"][k]) if d["look"][k] is String else d["look"][k]
	for n in Defs.NEEDS:
		needs[n] = float(d["needs"].get(n, 70.0))
	for t in Defs.TRAITS:
		traits[t] = int(d["traits"].get(t, 5))
	for s in Defs.SKILLS:
		skills[s] = float(d["skills"].get(s, 0.0))
	job = null
	if d.get("job") != null:
		job = {"career": int(d["job"]["career"]), "level": int(d["job"]["level"]), "perf": float(d["job"]["perf"])}
	tile = Vector2i(int(d["tile"][0]), int(d["tile"][1]))
	work_day = int(d["work_day"])
	work_flag_day = int(d["work_flag_day"])
	starve_t = d.get("starve_t", 0.0)
	_stage = stage()
	_build()
	if resident:
		position = world.tile_center(tile)
		if d.get("away", false) and sched() != null:
			away = true
			visible = false
			cur = {"kind": "work", "label": "At work", "auto": false, "state": "away", "t": 0.0, "tries": 0}
