class_name Meshes
extends RefCounted
## Procedural geometry and textures. Every asset in the game is built here from primitives.

static var _mats := {}

const WOOD := Color(0.55, 0.38, 0.22)
const DARK := Color(0.16, 0.16, 0.18)
const WHITE := Color(0.93, 0.93, 0.9)
const METAL := Color(0.6, 0.62, 0.66)
const LEAF := Color(0.24, 0.52, 0.22)


static func mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var key := c.to_html() + str(emit)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func box(p: Node3D, size: Vector3, pos: Vector3, c: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat(c, emit)
	p.add_child(mi)
	return mi


static func cyl(p: Node3D, r_bot: float, r_top: float, h: float, pos: Vector3, c: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.bottom_radius = r_bot
	m.top_radius = r_top
	m.height = h
	m.radial_segments = 14
	m.rings = 1
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat(c, emit)
	p.add_child(mi)
	return mi


static func ball(p: Node3D, r: float, pos: Vector3, c: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 8
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat(c, emit)
	p.add_child(mi)
	return mi


static func accent(rng: RandomNumberGenerator, sat := 0.5, val := 0.75) -> Color:
	return Color.from_hsv(rng.randf(), sat, val)


static func _legs(p: Node3D, hx: float, hz: float, h: float, c: Color, t := 0.06) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(p, Vector3(t, h, t), Vector3(sx * hx, h / 2.0, sz * hz), c)


## Builds the model for an object kind under `p`. Origin = footprint centre on the ground, front = +Z.
static func build_object(p: Node3D, kind: String, rng: RandomNumberGenerator) -> void:
	var ac := accent(rng)
	match kind:
		"bed_single", "bed_double":
			var w := 0.9 if kind == "bed_single" else 1.9
			box(p, Vector3(w, 0.3, 1.9), Vector3(0, 0.2, 0), WOOD)
			box(p, Vector3(w - 0.06, 0.16, 1.82), Vector3(0, 0.42, 0), WHITE)
			box(p, Vector3(w - 0.04, 0.07, 1.15), Vector3(0, 0.5, 0.34), ac)
			box(p, Vector3(w, 0.85, 0.08), Vector3(0, 0.42, -0.94), WOOD.darkened(0.2))
			var n := 1 if kind == "bed_single" else 2
			for i in n:
				var px := 0.0 if n == 1 else (-0.5 + i)
				box(p, Vector3(0.6, 0.1, 0.35), Vector3(px, 0.54, -0.68), WHITE.lightened(0.3))
		"sofa", "armchair":
			var w := 1.9 if kind == "sofa" else 0.9
			box(p, Vector3(w, 0.3, 0.8), Vector3(0, 0.25, 0), ac)
			box(p, Vector3(w, 0.55, 0.2), Vector3(0, 0.62, -0.3), ac.darkened(0.15))
			for sx in [-1.0, 1.0]:
				box(p, Vector3(0.14, 0.42, 0.8), Vector3(sx * (w / 2.0 - 0.07), 0.5, 0), ac.darkened(0.15))
			_legs(p, w / 2.0 - 0.08, 0.32, 0.1, DARK)
		"chair":
			box(p, Vector3(0.46, 0.05, 0.46), Vector3(0, 0.46, 0), WOOD)
			box(p, Vector3(0.46, 0.5, 0.05), Vector3(0, 0.74, -0.21), WOOD)
			_legs(p, 0.19, 0.19, 0.45, WOOD.darkened(0.2), 0.05)
		"table":
			box(p, Vector3(0.96, 0.06, 0.96), Vector3(0, 0.76, 0), WOOD.lightened(0.1))
			_legs(p, 0.4, 0.4, 0.74, WOOD.darkened(0.2), 0.07)
		"tv":
			box(p, Vector3(0.9, 0.45, 0.4), Vector3(0, 0.225, -0.1), WOOD)
			box(p, Vector3(0.86, 0.52, 0.06), Vector3(0, 0.78, -0.1), DARK)
			box(p, Vector3(0.78, 0.44, 0.01), Vector3(0, 0.78, -0.065), Color(0.35, 0.6, 0.9), 1.2)
		"stereo":
			box(p, Vector3(0.5, 0.7, 0.35), Vector3(0, 0.35, -0.1), DARK)
			box(p, Vector3(0.4, 0.12, 0.01), Vector3(0, 0.55, 0.08), Color(0.3, 0.9, 0.5), 1.0)
			for sx in [-1.0, 1.0]:
				box(p, Vector3(0.2, 0.9, 0.25), Vector3(sx * 0.37, 0.45, -0.1), DARK.lightened(0.1))
				cyl(p, 0.07, 0.07, 0.02, Vector3(sx * 0.37, 0.6, 0.03), METAL).rotation.x = PI / 2.0
		"bookshelf":
			box(p, Vector3(0.95, 1.8, 0.06), Vector3(0, 0.9, -0.42), WOOD.darkened(0.2))
			for sx in [-1.0, 1.0]:
				box(p, Vector3(0.05, 1.8, 0.36), Vector3(sx * 0.45, 0.9, -0.26), WOOD)
			for i in 5:
				var y := 0.04 + i * 0.44
				box(p, Vector3(0.9, 0.04, 0.36), Vector3(0, y, -0.26), WOOD)
				if i < 4:
					var x := -0.4
					while x < 0.36:
						var bw := rng.randf_range(0.05, 0.11)
						var bh := rng.randf_range(0.25, 0.36)
						box(p, Vector3(bw, bh, 0.24), Vector3(x + bw / 2.0, y + 0.02 + bh / 2.0, -0.26), accent(rng, 0.55, 0.65))
						x += bw + 0.01
		"computer":
			box(p, Vector3(0.96, 0.05, 0.5), Vector3(0, 0.72, -0.22), WOOD.lightened(0.15))
			for sx in [-1.0, 1.0]:
				box(p, Vector3(0.05, 0.7, 0.46), Vector3(sx * 0.44, 0.35, -0.22), WOOD)
			box(p, Vector3(0.46, 0.32, 0.04), Vector3(0, 1.0, -0.36), DARK)
			box(p, Vector3(0.4, 0.26, 0.01), Vector3(0, 1.0, -0.335), Color(0.5, 0.8, 0.95), 1.2)
			box(p, Vector3(0.08, 0.1, 0.06), Vector3(0, 0.8, -0.36), DARK)
			box(p, Vector3(0.36, 0.02, 0.12), Vector3(0, 0.76, -0.14), DARK.lightened(0.2))
			cyl(p, 0.18, 0.18, 0.06, Vector3(0, 0.44, 0.25), ac)
			cyl(p, 0.04, 0.04, 0.42, Vector3(0, 0.21, 0.25), METAL)
		"easel":
			for sx in [-1.0, 1.0]:
				box(p, Vector3(0.05, 1.6, 0.05), Vector3(sx * 0.25, 0.8, -0.1), WOOD).rotation.x = -0.15
			box(p, Vector3(0.05, 1.5, 0.05), Vector3(0, 0.75, -0.32), WOOD).rotation.x = 0.25
			box(p, Vector3(0.62, 0.04, 0.08), Vector3(0, 0.85, -0.04), WOOD)
			box(p, Vector3(0.6, 0.5, 0.03), Vector3(0, 1.13, -0.08), WHITE)
			for i in 5:
				box(p, Vector3(rng.randf_range(0.08, 0.2), rng.randf_range(0.06, 0.18), 0.005),
					Vector3(rng.randf_range(-0.18, 0.18), 1.13 + rng.randf_range(-0.14, 0.14), -0.062), accent(rng, 0.7, 0.85))
		"weights":
			box(p, Vector3(0.4, 0.1, 1.3), Vector3(0, 0.42, 0.1), DARK.lightened(0.15))
			_legs(p, 0.15, 0.5, 0.38, METAL)
			for sx in [-1.0, 1.0]:
				box(p, Vector3(0.05, 1.05, 0.05), Vector3(sx * 0.35, 0.52, -0.6), METAL)
				cyl(p, 0.16, 0.16, 0.06, Vector3(sx * 0.48, 1.05, -0.6), DARK).rotation.z = PI / 2.0
			cyl(p, 0.02, 0.02, 1.1, Vector3(0, 1.05, -0.6), METAL).rotation.z = PI / 2.0
		"mirror":
			box(p, Vector3(0.62, 1.6, 0.05), Vector3(0, 0.9, -0.3), WOOD)
			box(p, Vector3(0.52, 1.48, 0.01), Vector3(0, 0.9, -0.27), Color(0.75, 0.88, 0.95), 0.15)
			box(p, Vector3(0.5, 0.06, 0.4), Vector3(0, 0.05, -0.3), WOOD)
		"phone":
			cyl(p, 0.22, 0.22, 0.04, Vector3(0, 0.7, 0), WOOD)
			cyl(p, 0.04, 0.04, 0.7, Vector3(0, 0.35, 0), WOOD.darkened(0.2))
			cyl(p, 0.16, 0.16, 0.04, Vector3(0, 0.02, 0), WOOD.darkened(0.2))
			box(p, Vector3(0.2, 0.07, 0.16), Vector3(0, 0.755, 0), ac)
			box(p, Vector3(0.26, 0.04, 0.05), Vector3(0, 0.81, 0), ac.darkened(0.3))
		"fridge":
			box(p, Vector3(0.8, 1.8, 0.7), Vector3(0, 0.9, -0.1), WHITE)
			box(p, Vector3(0.78, 0.015, 0.01), Vector3(0, 1.25, 0.255), DARK.lightened(0.3))
			box(p, Vector3(0.04, 0.4, 0.04), Vector3(-0.3, 0.9, 0.27), METAL)
			box(p, Vector3(0.04, 0.25, 0.04), Vector3(-0.3, 1.5, 0.27), METAL)
		"stove":
			box(p, Vector3(0.9, 0.88, 0.7), Vector3(0, 0.44, -0.1), WHITE)
			box(p, Vector3(0.9, 0.02, 0.7), Vector3(0, 0.89, -0.1), DARK)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					cyl(p, 0.12, 0.12, 0.02, Vector3(sx * 0.22, 0.905, -0.1 + sz * 0.17), Color(0.5, 0.15, 0.1))
			box(p, Vector3(0.6, 0.35, 0.01), Vector3(0, 0.42, 0.255), DARK)
			box(p, Vector3(0.9, 0.18, 0.05), Vector3(0, 0.98, -0.42), WHITE.darkened(0.1))
		"sink":
			box(p, Vector3(0.9, 0.84, 0.6), Vector3(0, 0.42, -0.15), WOOD.lightened(0.2))
			box(p, Vector3(0.92, 0.05, 0.62), Vector3(0, 0.865, -0.15), WHITE)
			box(p, Vector3(0.5, 0.02, 0.36), Vector3(0, 0.895, -0.12), METAL.darkened(0.25))
			box(p, Vector3(0.04, 0.2, 0.04), Vector3(0, 0.98, -0.38), METAL)
			box(p, Vector3(0.04, 0.04, 0.16), Vector3(0, 1.07, -0.3), METAL)
		"toilet":
			cyl(p, 0.2, 0.15, 0.4, Vector3(0, 0.2, 0.08), WHITE)
			cyl(p, 0.22, 0.22, 0.04, Vector3(0, 0.42, 0.08), WHITE.darkened(0.08))
			box(p, Vector3(0.42, 0.4, 0.18), Vector3(0, 0.62, -0.3), WHITE)
		"shower":
			box(p, Vector3(0.92, 0.08, 0.92), Vector3(0, 0.04, 0), WHITE)
			_legs(p, 0.44, 0.44, 2.0, METAL, 0.04)
			var glass := Color(0.7, 0.88, 0.95, 0.3)
			box(p, Vector3(0.02, 1.9, 0.88), Vector3(-0.44, 1.03, 0), glass)
			box(p, Vector3(0.02, 1.9, 0.88), Vector3(0.44, 1.03, 0), glass)
			box(p, Vector3(0.88, 1.9, 0.02), Vector3(0, 1.03, -0.44), WHITE.darkened(0.1))
			box(p, Vector3(0.04, 0.04, 0.3), Vector3(0, 1.95, -0.3), METAL)
			cyl(p, 0.08, 0.05, 0.05, Vector3(0, 1.92, -0.15), METAL)
		"bathtub":
			box(p, Vector3(1.9, 0.5, 0.82), Vector3(0, 0.27, 0), WHITE)
			box(p, Vector3(1.7, 0.02, 0.62), Vector3(0, 0.525, 0), Color(0.45, 0.7, 0.9, 0.8))
			box(p, Vector3(0.04, 0.2, 0.04), Vector3(-0.85, 0.62, 0), METAL)
		"lamp":
			cyl(p, 0.16, 0.16, 0.04, Vector3(0, 0.02, 0), DARK)
			cyl(p, 0.02, 0.02, 1.4, Vector3(0, 0.72, 0), METAL)
			cyl(p, 0.24, 0.14, 0.3, Vector3(0, 1.52, 0), Color(1.0, 0.9, 0.65), 0.8)
			var l := OmniLight3D.new()
			l.name = "Light"
			l.position = Vector3(0, 1.5, 0)
			l.light_color = Color(1.0, 0.86, 0.6)
			l.light_energy = 2.2
			l.omni_range = 6.5
			l.visible = false
			p.add_child(l)
		"plant":
			cyl(p, 0.16, 0.2, 0.3, Vector3(0, 0.15, 0), Color(0.7, 0.4, 0.28))
			for i in 5:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.0, 0.14)
				ball(p, rng.randf_range(0.14, 0.24), Vector3(cos(a) * r, rng.randf_range(0.5, 0.9), sin(a) * r), LEAF.lightened(rng.randf() * 0.25))
		"sculpture":
			box(p, Vector3(0.5, 0.4, 0.5), Vector3(0, 0.2, 0), WHITE.darkened(0.15))
			var y := 0.4
			for i in rng.randi_range(3, 5):
				var s := rng.randf_range(0.14, 0.3)
				var pos := Vector3(rng.randf_range(-0.08, 0.08), y + s * 0.5, rng.randf_range(-0.08, 0.08))
				var mi: MeshInstance3D
				match rng.randi() % 3:
					0: mi = box(p, Vector3(s, s, s), pos, ac)
					1: mi = ball(p, s * 0.55, pos, ac.lightened(0.2))
					_: mi = cyl(p, s * 0.5, s * 0.15, s, pos, ac.darkened(0.2))
				mi.rotation = Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)
				y += s * 0.8
		"tree":
			var th := rng.randf_range(1.2, 2.0)
			cyl(p, 0.14, 0.09, th, Vector3(0, th / 2.0, 0), Color(0.4, 0.28, 0.18))
			var green := LEAF.lerp(Color(0.4, 0.6, 0.2), rng.randf())
			if rng.randf() < 0.4:
				for i in 3:
					cyl(p, 0.75 - i * 0.2, 0.05, 1.0, Vector3(0, th + 0.3 + i * 0.55, 0), green.darkened(0.15))
			else:
				for i in rng.randi_range(3, 5):
					var a := rng.randf() * TAU
					var r := rng.randf_range(0.0, 0.45)
					ball(p, rng.randf_range(0.5, 0.8), Vector3(cos(a) * r, th + rng.randf_range(0.2, 0.9), sin(a) * r), green.lightened(rng.randf() * 0.15))
		"bush":
			for i in 4:
				var a := rng.randf() * TAU
				ball(p, rng.randf_range(0.22, 0.34), Vector3(cos(a) * 0.15, rng.randf_range(0.2, 0.4), sin(a) * 0.15), LEAF.darkened(rng.randf() * 0.2))
		"flowers":
			box(p, Vector3(0.9, 0.06, 0.9), Vector3(0, 0.03, 0), Color(0.3, 0.22, 0.15))
			var fc := accent(rng, 0.7, 0.95)
			for i in 9:
				var pos := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
				var h := rng.randf_range(0.15, 0.32)
				box(p, Vector3(0.02, h, 0.02), pos + Vector3(0, h / 2.0, 0), LEAF)
				ball(p, 0.06, pos + Vector3(0, h, 0), fc.lightened(rng.randf() * 0.3))
		"puddle":
			cyl(p, 0.36, 0.36, 0.012, Vector3(0, 0.02, 0), Color(0.45, 0.65, 0.85, 0.75))
			cyl(p, 0.2, 0.2, 0.012, Vector3(0.25, 0.02, 0.15), Color(0.45, 0.65, 0.85, 0.75))
		_:
			box(p, Vector3(0.8, 0.8, 0.8), Vector3(0, 0.4, 0), ac)


## Procedural 64px surface texture.
static func make_tex(kind: String, tint: Color, seed_v: int) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.09
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for y in n:
		for x in n:
			var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var c := tint
			match kind:
				"grass":
					c = Color(0.23, 0.46, 0.2).lerp(Color(0.36, 0.6, 0.26), v)
					if rng.randf() < 0.08:
						c = c.lightened(0.12)
				"wood":
					var plank := y / 16
					var g := noise.get_noise_2d(x * 0.25, y * 3.0 + plank * 40.0) * 0.5 + 0.5
					c = tint.darkened(0.3 * g).lightened(0.05 * (plank % 2))
					if y % 16 == 0 or (x + plank * 23) % 64 == 0:
						c = c.darkened(0.45)
				"tile":
					var odd := (x / 32 + y / 32) % 2 == 1
					c = tint.lightened(0.55) if odd else tint
					c = c.darkened(0.06 * v)
					if x % 32 == 0 or y % 32 == 0:
						c = Color(0.75, 0.75, 0.72)
				"carpet":
					c = tint.darkened(rng.randf() * 0.18).lightened(0.08 * v)
				"stone":
					c = tint.darkened(0.3 * v)
					if rng.randf() < 0.05:
						c = c.darkened(0.2)
					if x % 32 == 0 or (y + (x / 32) * 16) % 32 == 0:
						c = c.darkened(0.35)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func tex_mat(kind: String, tint: Color, seed_v: int, uv_scale := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = make_tex(kind, tint, seed_v)
	m.roughness = 0.9
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	return m
