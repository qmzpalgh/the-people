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
var hud: UITown
var hover := -1           # id of the lot under the mouse, or -1
var picked := -1          # id of the lot whose card is open, or -1
var _hover_n: MeshInstance3D
var _pick_n: MeshInstance3D
var _home_n: Node3D       # a gold frame round the player's own lot
var _frame := 0
var lit := {}             # home lot id -> {mat, light}: the windows and glow to switch at night
var _night := -1          # 1 or 0 once the lights match the clock, -1 when they need setting
var labels := {}          # lot id -> its floating label
var houses := {}          # lot id -> the house's node, for home and vacant lots


func _init(g: Node = null, t: Town = null) -> void:
	game = g
	town = t


func _ready() -> void:
	hud = UITown.new(game)
	add_child(hud)
	hud.dismissed.connect(_recolour)
	cam = Cam.new()
	cam.yaw = 0.0
	cam.pitch = 0.75
	cam.max_dist = 260.0
	cam.min_pos = Vector2(-20.0, -40.0)
	add_child(cam)
	_build()
	var length := _length()
	cam.dist = clampf(length * 1.3, 60.0, 250.0)
	cam.position = Vector3(length / 2.0 - PITCH / 2.0, 0, 0)


func _length() -> float:
	return ceili(town.lots.size() / float(BOTH)) * PITCH


## Draws the street, the plates, the houses and the labels from the town record and the
## worlds as they are now.
func _build() -> void:
	var length := _length()
	var mid := length / 2.0 - PITCH / 2.0
	_street(length, mid)
	_hover_n = _marker(Color(UI.GOLD, 0.15))
	_pick_n = _marker(Color(1, 1, 1, 0.3))
	_home_n = _ring(UI.GOLD)
	for l in town.lots:
		_plate(l)
	cam.max_pos = Vector2(length, 40.0)
	if OS.has_environment("TP_SHOT"):
		for id in houses:
			var h: Node3D = houses[id]
			var g: Vector3 = h.get_child(0).global_position
			var bd: float = (h.get_child(0) as MeshInstance3D).mesh.size.z
			print("lot %d side %s: house front to road edge %.1f, back to far edge %.1f" % [id, "S" if g.z > 0 else "N", absf(g.z) - ROAD / 2.0 - WALK - bd / 2.0, World.H - (absf(g.z) - ROAD / 2.0 - WALK) - bd / 2.0])
		print("town view: %d plates for %d lots, %d houses drawn, %d homes without a house" % [plates.size(), town.lots.size(), houses.size(), town.lots.filter(func(l): return l["kind"] == "home" and not houses.has(l["id"])).size()])


## Draws the town again, so it matches the record and the worlds, and opens the player's
## card. The camera stays where it is.
func refresh() -> void:
	for c in get_children():
		if c != hud and c != cam:
			c.free()
	plates.clear()
	houses.clear()
	labels.clear()
	lit.clear()
	_night = -1
	hover = -1
	picked = -1
	_build()
	open_home()


## The first launch, with no save: no lot is framed and no card is open, only the prompt.
func ask_create() -> void:
	hud.show_prompt()
	_recolour()


## A flat tint the size of a lot, moved onto the lot that is hovered or picked.
func _marker(c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(World.W, 0.06, World.H)
	m.mesh = b
	var mt := StandardMaterial3D.new()
	mt.albedo_color = c
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mt
	m.visible = false
	add_child(m)
	return m


## A thin frame round a lot, in a colour, laid on the player's lot.
func _ring(c: Color) -> Node3D:
	var n := Node3D.new()
	var w := 0.5
	Meshes.box(n, Vector3(World.W, 0.12, w), Vector3(0, 0.08, -World.H / 2.0 + w / 2.0), c, 0.3)
	Meshes.box(n, Vector3(World.W, 0.12, w), Vector3(0, 0.08, World.H / 2.0 - w / 2.0), c, 0.3)
	Meshes.box(n, Vector3(w, 0.12, World.H), Vector3(-World.W / 2.0 + w / 2.0, 0.08, 0), c, 0.3)
	Meshes.box(n, Vector3(w, 0.12, World.H), Vector3(World.W / 2.0 - w / 2.0, 0.08, 0), c, 0.3)
	n.visible = false
	add_child(n)
	return n


## Frames the player's lot and opens its card, as the game does on boot.
func open_home() -> void:
	var l = town.lot_of(0)
	if l == null:
		return
	_home_n.position = origin(l) + Vector3(World.W / 2.0, 0, World.H / 2.0)
	_home_n.visible = true
	picked = l["id"]
	_show_marker(_pick_n, picked)
	hud.show_lot(l)
	cam.position = Vector3(_home_n.position.x, 0, 0)


## The lot under a screen position, or null. The mouse ray meets the ground, and the point
## is tested against each plate's rectangle.
func lot_at(mpos: Vector2) -> Variant:
	var o := cam.cam.project_ray_origin(mpos)
	var d := cam.cam.project_ray_normal(mpos)
	if absf(d.y) < 0.0001:
		return null
	var p := o + d * (-o.y / d.y)
	for l in town.lots:
		var a := origin(l)
		if p.x >= a.x and p.x <= a.x + World.W and p.z >= a.z and p.z <= a.z + World.H:
			return l
	return null


func _show_marker(m: MeshInstance3D, id: int) -> void:
	m.visible = id >= 0
	if id >= 0:
		m.position = origin(town.lot(id)) + Vector3(World.W / 2.0, 0.05, World.H / 2.0)


## A click on a lot opens its card; a click on nothing closes it. Returns the card title.
func click(mpos: Vector2) -> String:
	if hud.asking():
		return ""
	var l = lot_at(mpos)
	picked = -1 if l == null else l["id"]
	_show_marker(_pick_n, picked)
	hud.show_lot(l)
	return hud.title


func _process(_dt: float) -> void:
	var l = null if hud.asking() else lot_at(get_viewport().get_mouse_position())
	hover = -1 if l == null else l["id"]
	_show_marker(_hover_n, hover)
	_frame += 1
	if _night != int(game.world.night):
		_set_lights(game.world.night)
	if _frame == 5 and OS.has_environment("TP_TOWN_CLICK"):
		var id := int(OS.get_environment("TP_TOWN_CLICK"))
		var a := origin(town.lot(id)) + Vector3(World.W / 2.0, 0, World.H / 2.0)
		print("town card: ", click(cam.cam.unproject_position(a)))
	if _frame == 8 and OS.has_environment("TP_TOWN_CREATE") and hud.asking():
		hud.create_btn.pressed.emit()
		print("town create: screen ", game.screen, ", prompt ", hud.asking())
	if _frame == 8 and OS.has_environment("TP_TOWN_PLAY"):
		hud.play_btn.pressed.emit()
		print("town play: screen ", game.screen, ", speed ", game.speed)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		click(e.position)


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
		if l["kind"] == "home":
			_glow(l["id"], houses[l["id"]])
	_label(l, n)


## The footprint and wall colour of the house on a lot, or {} for bare land or a home
## with no house. A home reads
## its household's own world. A vacant house is built again from its seed in a throwaway
## headless World, which has its own rng and is freed at once, so nothing else moves.
func _look(l: Dictionary) -> Dictionary:
	if l["kind"] == "home":
		var w: World = game.households[l["household"]].world
		if not w.house.has_area():
			return {}  # a household on bare land: the plate stays lawn
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
		Meshes.box(hs, Vector3(1.2, 1.1, 0.1), c + Vector3(wx, 1.7, bd / 2.0 + 0.03), Color(0.6, 0.8, 0.95)).name = "Window"
	hs.set_meta("centre", c)
	return hs


## Gives an occupied home its own window material and a soft warm light, both switched on
## at night. Vacant houses and bare land keep plain windows and no light.
func _glow(id: int, hs: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.8, 0.95)
	for w in hs.get_children():
		if w.name.begins_with("Window"):
			w.material_override = m
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.78, 0.45)
	o.omni_range = 16.0
	o.light_energy = 1.6
	o.shadow_enabled = false
	o.position = (hs.get_meta("centre") as Vector3) + Vector3(0, 2.5, 3.0)
	o.visible = false
	hs.add_child(o)
	lit[id] = {"mat": m, "light": o}


## Windows glow and the warm light comes on in occupied homes when the lot's night is on.
func _set_lights(night: bool) -> void:
	_night = 1 if night else 0
	for id in lit:
		var m: StandardMaterial3D = lit[id]["mat"]
		m.albedo_color = Color(1.0, 0.85, 0.55) if night else Color(0.6, 0.8, 0.95)
		m.emission_enabled = night
		m.emission = Color(1.0, 0.75, 0.4)
		m.emission_energy_multiplier = 2.0
		lit[id]["light"].visible = night
	_recolour()
	if OS.has_environment("TP_SHOT"):
		print("town lights: %d of %d homes lit (night %s)" % [lit.values().filter(func(d): return d["light"].visible).size(), lit.size(), night])


## The text a lot's label shows: the family name, "To let" for a house nobody lives in, or
## "For sale" for bare land.
func label_text(l: Dictionary) -> String:
	match l["kind"]:
		"home":
			return "%s" % game.households[l["household"]].family
		"vacant":
			return "To let"
	return "For sale"


## The player's own home is gold, except while the prompt is up: there is no home yet.
func _label_colour(l: Dictionary) -> Color:
	var night := _night == 1
	if l["kind"] != "home":
		return UI.MUTED.lightened(0.45) if night else UI.MUTED
	if l["household"] == 0 and not hud.asking():
		return UI.GOLD if night else UI.GOLD.darkened(0.55)
	return Color(0.93, 0.95, 0.97) if night else UI.INK


func _recolour() -> void:
	for id in labels:
		labels[id].modulate = _label_colour(town.lot(id))


## A label that floats above the house (above the middle of the plate on bare land) and
## always faces the camera. A home is in ink, the player's own home in gold, and the
## for-sale and to-let notices are quiet grey, as in the HUD.
func _label(l: Dictionary, plate: Node3D) -> void:
	var t := Label3D.new()
	var txt := label_text(l)
	t.text = txt
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	t.fixed_size = true
	t.pixel_size = 0.00024
	t.font_size = 80
	t.outline_size = 2
	t.render_priority = 1
	t.outline_render_priority = 0
	var f: Font = game.ui.root.theme.default_font
	if f != null:
		t.font = f
	t.modulate = _label_colour(l)
	t.outline_modulate = Color(0.97, 0.975, 0.965, 0.9)  # thin, so it only edges the letters
	var at := Vector3(World.W / 2.0, 3.0, World.H / 2.0)
	if houses.has(l["id"]):
		var hp: Vector3 = (houses[l["id"]] as Node3D).get_child(0).global_position
		at = plate.to_local(hp) + Vector3(0, 13.0, 0)
	t.position = at
	plate.add_child(t)
	labels[l["id"]] = t
	if OS.has_environment("TP_SHOT"):
		print("label lot %d slot %d: %s" % [l["id"], l["slot"], txt.replace("\n", " / ")])
