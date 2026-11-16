class_name Cam
extends Node3D
## Orbit camera rig: WASD / arrows pan, Q/E rotate, wheel zoom, middle-drag orbit.

var cam: Camera3D
var yaw := 0.55
var pitch := 0.95
var dist := 26.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	_apply()


func _apply() -> void:
	rotation = Vector3(0, yaw, 0)
	cam.position = Vector3(0, sin(pitch) * dist, cos(pitch) * dist)
	cam.rotation = Vector3(-pitch, 0, 0)


func _process(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		yaw += delta * 1.5
	if Input.is_key_pressed(KEY_E):
		yaw -= delta * 1.5
	if v != Vector3.ZERO:
		position += Basis(Vector3.UP, yaw) * v.normalized() * delta * dist * 0.8
		position.x = clampf(position.x, -10.0, World.W + 10.0)
		position.z = clampf(position.z, -10.0, World.H + 15.0)
	_apply()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(6.0, dist * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(70.0, dist * 1.1)
	elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		yaw -= e.relative.x * 0.006
		pitch = clampf(pitch + e.relative.y * 0.005, 0.35, 1.5)
