class_name Thumbs
extends Node
## Thumbnail pictures for menus. A model is built in a small off-screen viewport that has
## its own world and its own light, framed by its measured size, and copied into a cached
## texture. Requests queue up and one is drawn per frame, so a menu full of pictures never
## stalls: a caller gets its texture at once, blank, and it fills in when its turn comes.
## Without a display (--headless) nothing is built or drawn and textures stay blank.
## TP_THUMBS=<folder> writes one PNG per entry in Defs.OBJECTS.

## A picture has been drawn into its texture.
signal drawn(key: String, tex: ImageTexture)

## Pixels along each side. Menus draw these at 40 to 64 px; the rest is for big screens.
const SIZE := 128
## The camera stands to the model's front right and looks down on it (radians).
const YAW := 0.6
const PITCH := 0.5
## Frame width as a share of the model's, so nothing touches the edge.
const MARGIN := 1.08

static var _grey: ShaderMaterial

var _cache := {}
var _queue: Array = []  # [key, build] waiting their turn
var _busy := ""  # key being drawn this frame
var _vp: SubViewport
var _cam: Camera3D
var _model: Node3D
var _unmul := PackedFloat32Array()
var _dump := ""
var _dump_left := 0


func _ready() -> void:
	set_process(false)
	var folder := OS.get_environment("TP_THUMBS")
	if folder == "":
		return
	if not _can_draw():
		_dump_end("thumbs: TP_THUMBS needs a display, nothing written")
		return
	DirAccess.make_dir_recursive_absolute(folder)
	_dump = folder
	_dump_left = Defs.OBJECTS.size()
	drawn.connect(_dump_png)
	for k in Defs.OBJECTS:
		object(k)


## Picture of an object kind from Defs.OBJECTS, as it stands in the game facing front.
func object(kind: String) -> ImageTexture:
	return request(kind, func(p: Node3D) -> void:
		# Its own dice, so the catalogue looks the same every time and the game's are untouched.
		var rng := RandomNumberGenerator.new()
		rng.seed = kind.hash()
		Meshes.build_object(p, kind, rng))


## Picture of anything. `build` is called once with an empty Node3D to put meshes under,
## origin on the ground and front = +Z. The same key always returns the same texture.
func request(key: String, build: Callable) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(Image.create_empty(SIZE, SIZE, true, Image.FORMAT_RGBA8))
	_cache[key] = tex
	if _can_draw():
		_queue.append([key, build])
		set_process(true)
	return tex


## Material for a control whose picture should look out of reach: drains its colour.
static func greyed() -> ShaderMaterial:
	if _grey == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	COLOR.rgb = mix(COLOR.rgb, vec3(g), 0.85);
}
"""
		_grey = ShaderMaterial.new()
		_grey.shader = sh
	return _grey


func _can_draw() -> bool:
	return DisplayServer.get_name() != "headless"


func _process(_delta: float) -> void:
	if _busy != "":
		return
	if _queue.is_empty():
		set_process(false)
		return
	var job: Array = _queue.pop_front()
	if _vp == null:
		_build_stage()
	_model = Node3D.new()
	job[1].call(_model)
	_vp.add_child(_model)
	_frame(_model)
	_busy = job[0]
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_collect, CONNECT_ONE_SHOT)


## The frame holding the model has been drawn: copy it out and clear the stage.
func _collect() -> void:
	var img := _vp.get_texture().get_image()
	_vp.remove_child(_model)
	_model.queue_free()
	_model = null
	var key := _busy
	_busy = ""
	if img == null:
		return
	img.convert(Image.FORMAT_RGBA8)
	_straighten(img)
	img.fix_alpha_edges()
	img.generate_mipmaps()
	var tex: ImageTexture = _cache[key]
	tex.set_image(img)
	drawn.emit(key, tex)


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	# Soft daylight in the game's colours, fixed, so a picture never changes with the game's clock.
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.0
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.environment = env
	_cam.basis = Basis.from_euler(Vector3(-PITCH, YAW, 0))
	_vp.add_child(_cam)
	# Key light over the viewer's left shoulder: top brightest, front next, side in shade.
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-1.1, YAW - 1.0, 0)
	key.light_color = Color(1.0, 0.97, 0.9)
	key.light_energy = 0.57
	_vp.add_child(key)


## Points the camera at the middle of the model and sizes the view to hold all of it.
func _frame(model: Node3D) -> void:
	var pts := PackedVector3Array()
	_gather(model, Transform3D.IDENTITY, pts)
	var inv := _cam.basis.inverse()
	var lo := Vector3.ZERO
	var hi := Vector3.ZERO
	for i in pts.size():
		var q := inv * pts[i]
		lo = q if i == 0 else lo.min(q)
		hi = q if i == 0 else hi.max(q)
	var mid := (lo + hi) / 2.0
	_cam.size = maxf(maxf(hi.x - lo.x, hi.y - lo.y), 0.1) * MARGIN
	_cam.position = _cam.basis * Vector3(mid.x, mid.y, hi.z + 1.0)
	_cam.near = 0.05
	_cam.far = hi.z - lo.z + 2.0


## Every mesh corner under `n`, in the model's own space.
func _gather(n: Node, xf: Transform3D, pts: PackedVector3Array) -> void:
	for c in n.get_children():
		if not c is Node3D or not c.visible:
			continue
		var cxf: Transform3D = xf * c.transform
		if c is MeshInstance3D and c.mesh != null:
			for v in c.mesh.get_faces():
				pts.append(cxf * v)
		_gather(c, cxf, pts)


## The viewport hands back colour already multiplied by alpha, which would draw soft edges
## and glass too dark. Divide it out again; only part-covered pixels need it. The blend
## happened in linear light, so the factor is gamma-corrected for these sRGB bytes.
func _straighten(img: Image) -> void:
	if _unmul.is_empty():
		_unmul.resize(256)
		for a in range(1, 256):
			_unmul[a] = pow(255.0 / a, 1.0 / 2.2)
	var d := img.get_data()
	for i in range(3, d.size(), 4):
		var a := d[i]
		if a == 0 or a == 255:
			continue
		var m := _unmul[a]
		d[i - 3] = mini(255, int(d[i - 3] * m))
		d[i - 2] = mini(255, int(d[i - 2] * m))
		d[i - 1] = mini(255, int(d[i - 1] * m))
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)


func _dump_png(key: String, tex: ImageTexture) -> void:
	if not Defs.OBJECTS.has(key):
		return
	var img := tex.get_image()
	img.clear_mipmaps()
	img.save_png(_dump.path_join(key + ".png"))
	_dump_left -= 1
	if _dump_left == 0:
		_dump_end("thumbs: wrote %d PNGs to %s" % [Defs.OBJECTS.size(), _dump])


## A TP_THUMBS run that nothing else will end (TP_SHOT, TP_TEST) ends itself.
func _dump_end(note: String) -> void:
	print(note)
	if not (OS.has_environment("TP_SHOT") or OS.has_environment("TP_TEST")):
		get_tree().quit()
