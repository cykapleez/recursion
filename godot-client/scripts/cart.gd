extends Node3D

const FOLLOW_DIST  := 1.4   # world units behind player
const FOLLOW_SPEED := 7.0   # lerp speed — higher = snappier
const BOB_SPEED    := 9.0   # bounce frequency when moving
const BOB_AMOUNT   := 0.05  # bounce height amplitude

var _player:   CharacterBody3D
var _bob_time: float  = 0.0
var _last_dir: Vector3 = Vector3(0, 0, 1)

func _ready() -> void:
	_build_cart()
	call_deferred("_find_player")

func _find_player() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D:
			_player = node as CharacterBody3D
			global_position = _player.global_position - _last_dir * FOLLOW_DIST
			return

func _process(delta: float) -> void:
	if _player == null:
		return

	var flat    := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var moving  := flat.length() > 0.5

	if moving:
		_last_dir = flat.normalized()
		_bob_time += delta * BOB_SPEED

	var target := _player.global_position - _last_dir * FOLLOW_DIST
	var bob_y  := sin(_bob_time) * BOB_AMOUNT if moving else 0.0

	global_position = Vector3(
		lerpf(global_position.x, target.x, FOLLOW_SPEED * delta),
		lerpf(global_position.y, bob_y,    8.0 * delta),
		lerpf(global_position.z, target.z, FOLLOW_SPEED * delta)
	)

	# Keep front of cart facing toward the player
	var to_player := _player.global_position - global_position
	to_player.y   = 0.0
	if to_player.length() > 0.1:
		look_at(global_position + to_player, Vector3.UP)

func _build_cart() -> void:
	var wood := _mat(Color(0.55, 0.35, 0.15))
	var dark  := _mat(Color(0.15, 0.10, 0.05))

	# Cart body
	var body_mesh  := BoxMesh.new()
	body_mesh.size  = Vector3(0.72, 0.28, 0.52)
	var body        := MeshInstance3D.new()
	body.mesh        = body_mesh
	body.material_override = wood
	body.position    = Vector3(0, 0.43, 0)
	add_child(body)

	# Side rails
	var sides: Array[float] = [-0.36, 0.36]
	for side in sides:
		var rail_mesh  := BoxMesh.new()
		rail_mesh.size  = Vector3(0.04, 0.14, 0.50)
		var rail        := MeshInstance3D.new()
		rail.mesh        = rail_mesh
		rail.material_override = wood
		rail.position    = Vector3(side, 0.64, 0)
		add_child(rail)

	# Four wheels
	var wheel_positions: Array[Vector3] = [
		Vector3(-0.38, 0.15, -0.22),
		Vector3( 0.38, 0.15, -0.22),
		Vector3(-0.38, 0.15,  0.22),
		Vector3( 0.38, 0.15,  0.22),
	]
	for wp in wheel_positions:
		var wm             := CylinderMesh.new()
		wm.top_radius       = 0.14
		wm.bottom_radius    = 0.14
		wm.height           = 0.06
		var wi             := MeshInstance3D.new()
		wi.mesh             = wm
		wi.material_override = dark
		wi.position         = wp
		wi.rotation_degrees = Vector3(0, 0, 90)
		add_child(wi)

	# Axles
	var axle_z: Array[float] = [-0.22, 0.22]
	for az in axle_z:
		var am             := BoxMesh.new()
		am.size             = Vector3(0.76, 0.04, 0.04)
		var ai             := MeshInstance3D.new()
		ai.mesh             = am
		ai.material_override = dark
		ai.position         = Vector3(0, 0.15, az)
		add_child(ai)

func _mat(color: Color) -> StandardMaterial3D:
	var m              := StandardMaterial3D.new()
	m.albedo_color      = color
	return m
