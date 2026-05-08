extends CharacterBody3D

# Undead Colossus — two configurable profiles:
#   target_type = "player"       → Undead Colossus (player hunter, can climb objects)
#   target_type = "wooden_house" → Verdant Colossus (house breaker, AOE-clears path)

# ── Exported tuning vars ──────────────────────────────────────────────────────
@export var max_hp:             int    = 300
@export var enemy_name:         String = "Undead Colossus"

# Profile
@export var target_type:        String = "player"   # "player" | "wooden_house"
@export var move_speed:         float  = 2.8

# Climbing (player hunter only)
@export var can_climb:          bool   = true
@export var max_climb_height:   float  = 2.0
@export var climb_speed:        float  = 5.0

# Shared attack
@export var attack_range:       float  = 22.0
@export var attack_cooldown:    float  = 4.0
@export var windup_duration:    float  = 1.4
@export var aoe_radius:         float  = 4.5
@export var aoe_damage:         int    = 35
@export var laser_damage:       int    = 55
@export var laser_hit_width:    float  = 2.0

# House-breaker specific
@export var house_attack_range:  float = 4.0
@export var house_attack_damage: int   = 20
@export var house_attack_cd:     float = 2.0

# Shared blocking slam (both types)
@export var block_slam_cd: float = 2.0   # independent of primary attack cooldown

# ── Internal constants ────────────────────────────────────────────────────────
const GRAVITY:        float = 9.8
const WANDER_NEAR:    float = 3.0
const WANDER_FAR:     float = 8.0
const WAYPOINT_REACH: float = 1.5
const ROTATION_SPEED: float = 3.0
const SLAM_OFFSET:    float = 5.0
const INITIAL_DELAY:  float = 2.0

# Head-forward raycast origin (local space, near the snout between the eyes)
const _HEAD_LOCAL:    Vector3 = Vector3(0.0, 3.0, -6.5)
const _HEAD_RAY_DIST: float   = 6.0

enum AttackPhase { IDLE, WINDUP_AOE, WINDUP_LASER }

# ── Per-instance runtime override (set by WaveManager on spawn) ───────────────
var attack_cooldown_override: float = 0.0

# ── Colors (set in _ready based on target_type) ───────────────────────────────
var _body_color:  Color
var _bone_color:  Color
var _armor_color: Color
var _spine_color: Color
var _eye_color:   Color

# ── AI state ──────────────────────────────────────────────────────────────────
var _phase:            AttackPhase = AttackPhase.IDLE
var _phase_timer:      float       = -INITIAL_DELAY
var _aoe_indicator:    MeshInstance3D
var _laser_indicator:  MeshInstance3D
var _laser_to:         Vector3
var _use_forward_slam: bool    = true
var _slam_target_pos:  Vector3 = Vector3.ZERO

# ── Shared / house-breaker state ─────────────────────────────────────────────
var _house_attack_timer: float = 0.0
var _block_slam_timer:   float = 0.0

# ── Movement state ────────────────────────────────────────────────────────────
var _waypoint:       Vector3 = Vector3.ZERO
var _waypoint_timer: float   = 0.0

# ── Combat state ──────────────────────────────────────────────────────────────
var hp:         int
var _dying:     bool = false
var _body_mat:  StandardMaterial3D
var _hp_label:  Label3D
var _dmg_label: Label3D

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_init_colors()
	_build_visuals()
	_refresh_hp()

func _init_colors() -> void:
	if target_type == "wooden_house":
		_body_color  = Color(0.05, 0.28, 0.08)
		_bone_color  = Color(0.42, 0.55, 0.32)
		_armor_color = Color(0.08, 0.20, 0.08)
		_spine_color = Color(0.12, 0.26, 0.10)
		_eye_color   = Color(0.25, 1.0,  0.25)
	else:
		_body_color  = Color(0.10, 0.10, 0.12)
		_bone_color  = Color(0.62, 0.60, 0.50)
		_armor_color = Color(0.17, 0.17, 0.20)
		_spine_color = Color(0.22, 0.20, 0.26)
		_eye_color   = Color(0.45, 0.92, 1.0)

func _process(delta: float) -> void:
	if _dying:
		return
	_phase_timer        += delta
	_house_attack_timer -= delta
	_block_slam_timer   -= delta
	match _phase:
		AttackPhase.IDLE:
			if not _try_clear_blocker():
				if target_type == "player":
					_idle_player_hunt()
				else:
					_idle_house_break()
		AttackPhase.WINDUP_AOE:
			if _phase_timer >= windup_duration:
				_land_aoe()
		AttackPhase.WINDUP_LASER:
			if _phase_timer >= windup_duration:
				_fire_laser()
	_move_wander(delta)

# ── Player Hunter AI ──────────────────────────────────────────────────────────

func _idle_player_hunt() -> void:
	var effective_cd := attack_cooldown_override if attack_cooldown_override > 0.0 else attack_cooldown
	if _phase_timer < 0.0 or _phase_timer < effective_cd:
		return
	var player := _nearest_player()
	if player == null or global_position.distance_to(player.global_position) > attack_range:
		return
	if randi() % 2 == 0:
		_use_forward_slam = true
		_begin_aoe()
	else:
		_begin_laser(player)

# ── House Breaker AI ──────────────────────────────────────────────────────────

func _idle_house_break() -> void:
	var house := _get_house()
	if house == null:
		return
	if global_position.distance_to(house.global_position) <= house_attack_range:
		if _house_attack_timer <= 0.0:
			_attack_house(house)

func _attack_house(house: Node3D) -> void:
	_house_attack_timer = house_attack_cd
	if house.has_method("take_damage"):
		house.call("take_damage", house_attack_damage)
	var tween := create_tween()
	tween.tween_property(_body_mat, "albedo_color", Color(0.4, 1.0, 0.4), 0.05)
	tween.tween_property(_body_mat, "albedo_color", _body_color, 0.2)

# Raycast from the snout forward in the monster's facing direction.
# Detects any world object ahead — including the wooden house — so the monster
# slams whatever it walks into rather than getting stuck against it.
func _find_blocking_object() -> Node3D:
	var head_world := global_transform * _HEAD_LOCAL
	var forward    := -transform.basis.z            # local -Z = monster's facing dir
	var ray_to     := head_world + forward * _HEAD_RAY_DIST

	var space := get_world_3d().direct_space_state
	var query  := PhysicsRayQueryParameters3D.create(head_world, ray_to)
	query.exclude = [self]
	var hit   := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var col := hit.get("collider") as Node3D
	if col != null and is_instance_valid(col) and col.is_in_group("world_objects"):
		return col
	return null

# Shared for both types: if physically blocked by a world object, slam it.
# Uses its own short cooldown so it doesn't starve the primary attack timer.
func _try_clear_blocker() -> bool:
	if _block_slam_timer > 0.0:
		return false
	var blocker := _find_blocking_object()
	if blocker == null:
		return false
	_use_forward_slam = false
	_slam_target_pos  = blocker.global_position
	_block_slam_timer = block_slam_cd
	_begin_aoe()
	return true

func _get_house() -> Node3D:
	for wo: Node3D in get_tree().get_nodes_in_group("world_objects"):
		if wo.get("object_id") == "obj-wooden-house":
			return wo
	return null

# ── Movement ──────────────────────────────────────────────────────────────────

func _move_wander(delta: float) -> void:
	var target: Node3D = _nearest_player() if target_type == "player" else _get_house()
	if target == null:
		return

	_waypoint_timer -= delta
	if _waypoint_timer <= 0.0 or global_position.distance_to(_waypoint) < WAYPOINT_REACH:
		_pick_waypoint(target)

	var flat_pos    := Vector3(global_position.x, 0.0, global_position.z)
	var flat_target := Vector3(_waypoint.x,       0.0, _waypoint.z)
	var dir         := (flat_target - flat_pos).normalized()

	if dir.length() > 0.01:
		var target_y := atan2(-dir.x, -dir.z)
		rotation.y   = lerp_angle(rotation.y, target_y, ROTATION_SPEED * delta)

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if can_climb and _check_climb():
		velocity.y = climb_speed

	move_and_slide()

func _pick_waypoint(target: Node3D) -> void:
	var center := target.global_position
	if target_type == "player":
		var angle       := randf() * TAU
		var dist        := randf_range(WANDER_NEAR, WANDER_FAR)
		_waypoint       = Vector3(center.x + cos(angle) * dist, 0.0, center.z + sin(angle) * dist)
		_waypoint_timer  = randf_range(2.5, 5.0)
	else:
		_waypoint       = Vector3(center.x, 0.0, center.z)
		_waypoint_timer  = 1.0

# Two-ray check: low ray blocked + high ray clear = climbable object in front.
func _check_climb() -> bool:
	var move_dir := Vector3(velocity.x, 0.0, velocity.z)
	if move_dir.length() < 0.5:
		return false
	move_dir = move_dir.normalized()
	var space := get_world_3d().direct_space_state

	var low_from := global_position + Vector3(0, 0.3, 0)
	var low_to   := low_from + move_dir * 1.5
	var q_low    := PhysicsRayQueryParameters3D.create(low_from, low_to)
	q_low.exclude = [self]
	if space.intersect_ray(q_low).is_empty():
		return false

	var high_from := global_position + Vector3(0, max_climb_height, 0)
	var high_to   := high_from + move_dir * 1.5
	var q_high    := PhysicsRayQueryParameters3D.create(high_from, high_to)
	q_high.exclude = [self]
	return space.intersect_ray(q_high).is_empty()

func _screen_shake() -> void:
	var player := _nearest_player()
	if player == null:
		return
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var rest  := cam.position
	var tween := create_tween()
	for _i in 5:
		var offset := Vector3(randf_range(-0.5, 0.5), randf_range(-0.25, 0.25), randf_range(-0.2, 0.2))
		tween.tween_property(cam, "position", rest + offset, 0.05)
	tween.tween_property(cam, "position", rest, 0.1)

# ── AI attacks ────────────────────────────────────────────────────────────────

func _begin_aoe() -> void:
	_phase       = AttackPhase.WINDUP_AOE
	_phase_timer = 0.0

	var disc_mat                       := StandardMaterial3D.new()
	disc_mat.albedo_color               = Color(1.0, 0.0, 0.0, 0.55)
	disc_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.emission_enabled           = true
	disc_mat.emission                   = Color(1.0, 0.1, 0.0)
	disc_mat.emission_energy_multiplier = 1.2
	disc_mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED

	var disc_mesh           := CylinderMesh.new()
	disc_mesh.top_radius     = aoe_radius
	disc_mesh.bottom_radius  = aoe_radius
	disc_mesh.height         = 0.04

	_aoe_indicator                  = MeshInstance3D.new()
	_aoe_indicator.mesh              = disc_mesh
	_aoe_indicator.material_override = disc_mat
	get_tree().root.add_child(_aoe_indicator)

	if _use_forward_slam:
		var forward := -transform.basis.z
		forward.y    = 0.0
		if forward.length() > 0.01:
			forward = forward.normalized()
		var slam_world := global_position + forward * SLAM_OFFSET
		_aoe_indicator.global_position = Vector3(slam_world.x, 0.02, slam_world.z)
	else:
		_aoe_indicator.global_position = Vector3(_slam_target_pos.x, 0.02, _slam_target_pos.z)

	var tween := create_tween().set_loops()
	tween.tween_property(disc_mat, "albedo_color:a", 0.75, 0.3)
	tween.tween_property(disc_mat, "albedo_color:a", 0.35, 0.3)

func _land_aoe() -> void:
	_phase       = AttackPhase.IDLE
	_phase_timer = 0.0

	var aoe_world_pos := _aoe_indicator.global_position if _aoe_indicator != null else global_position
	if _aoe_indicator != null:
		_aoe_indicator.queue_free()
		_aoe_indicator = null

	_screen_shake()

	var tween := create_tween()
	tween.tween_property(_body_mat, "albedo_color", Color(1.0, 0.55, 0.0), 0.06)
	tween.tween_property(_body_mat, "albedo_color", _body_color, 0.25)

	for player: Node3D in get_tree().get_nodes_in_group("player"):
		if player.global_position.distance_to(aoe_world_pos) <= aoe_radius:
			if player.has_method("take_damage"):
				player.call("take_damage", aoe_damage)

	for wo: Node3D in get_tree().get_nodes_in_group("world_objects"):
		if wo.global_position.distance_to(aoe_world_pos) <= aoe_radius:
			if wo.has_method("take_damage"):
				wo.call("take_damage", aoe_damage)

func _begin_laser(player: Node3D) -> void:
	_phase       = AttackPhase.WINDUP_LASER
	_phase_timer = 0.0
	_laser_to    = player.global_position + Vector3(0.0, 1.0, 0.0)

	var beam_mat                       := StandardMaterial3D.new()
	beam_mat.albedo_color               = Color(1.0, 0.4, 0.85, 0.5)
	beam_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled           = true
	beam_mat.emission                   = Color(1.0, 0.4, 0.85)
	beam_mat.emission_energy_multiplier = 1.8
	beam_mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED

	var origin := _laser_origin()
	var mid    := (origin + _laser_to) * 0.5
	var length := origin.distance_to(_laser_to)

	var beam_mesh  := BoxMesh.new()
	beam_mesh.size  = Vector3(0.3, 0.3, length)

	_laser_indicator                  = MeshInstance3D.new()
	_laser_indicator.mesh              = beam_mesh
	_laser_indicator.material_override = beam_mat
	get_tree().root.add_child(_laser_indicator)
	_laser_indicator.global_position   = mid
	_laser_indicator.look_at(_laser_to, Vector3.UP)

	var tween := create_tween().set_loops()
	tween.tween_property(beam_mat, "albedo_color:a", 0.75, 0.2)
	tween.tween_property(beam_mat, "albedo_color:a", 0.25, 0.2)

func _fire_laser() -> void:
	_phase       = AttackPhase.IDLE
	_phase_timer = 0.0

	if _laser_indicator != null:
		_laser_indicator.queue_free()
		_laser_indicator = null

	var tween := create_tween()
	tween.tween_property(_body_mat, "albedo_color", Color(1.0, 1.0, 1.0), 0.04)
	tween.tween_property(_body_mat, "albedo_color", _body_color, 0.3)

	var origin := _laser_origin()
	var dir    := (_laser_to - origin).normalized()

	for player: Node3D in get_tree().get_nodes_in_group("player"):
		var to_player := player.global_position - origin
		var proj      := to_player.dot(dir)
		if proj < 0.0:
			continue
		var perp := (to_player - dir * proj).length()
		if perp <= laser_hit_width:
			if _laser_blocked(origin, player.global_position):
				continue
			if player.has_method("take_damage"):
				player.call("take_damage", laser_damage)

func _laser_blocked(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query  := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var hit    := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var col := hit.get("collider") as Node3D
	return col != null and col.is_in_group("world_objects")

func _laser_origin() -> Vector3:
	return global_position + Vector3(0.0, 3.22, -6.15)

func _nearest_player() -> Node3D:
	var best:      Node3D = null
	var best_dist: float  = INF
	for node: Node3D in get_tree().get_nodes_in_group("player"):
		var d := global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best      = node
	return best

# ── Combat ────────────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if _dying:
		return
	hp = max(0, hp - amount)
	_refresh_hp()
	_show_damage_number(amount)
	_flash_hit()
	if hp <= 0:
		_die()

func _refresh_hp() -> void:
	var pct    := float(hp) / float(max_hp)
	var filled := int(pct * 8.0)
	var bar    := ""
	for j in 8:
		bar += "█" if j < filled else "░"
	_hp_label.text = bar

func _show_damage_number(amount: int) -> void:
	_dmg_label.text      = "-%d" % amount
	_dmg_label.modulate   = Color.RED
	_dmg_label.position   = Vector3(0, 6.5, 0)
	_dmg_label.visible    = true
	var tween := create_tween()
	tween.tween_property(_dmg_label, "position:y", 8.0, 0.8)
	tween.parallel().tween_property(_dmg_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		_dmg_label.visible    = false
		_dmg_label.modulate.a = 1.0
	)

func _flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(_body_mat, "albedo_color", Color(0.7, 0.3, 0.1), 0.06)
	tween.tween_property(_body_mat, "albedo_color", _body_color, 0.25)

func _die() -> void:
	_dying = true
	remove_from_group("enemies")
	if _aoe_indicator != null:
		_aoe_indicator.queue_free()
		_aoe_indicator = null
	if _laser_indicator != null:
		_laser_indicator.queue_free()
		_laser_indicator = null
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.6, 0.04, 1.6), 0.45)
	tween.tween_callback(queue_free)

# ── Mesh helpers ──────────────────────────────────────────────────────────────

func _mat(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	m.metallic     = metallic
	return m

func _box(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh             := BoxMesh.new()
	mesh.size             = size
	var mi               := MeshInstance3D.new()
	mi.mesh               = mesh
	mi.material_override  = mat
	mi.position           = pos
	add_child(mi)
	return mi

func _cyl(radius: float, height: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh              := CylinderMesh.new()
	mesh.top_radius        = radius
	mesh.bottom_radius     = radius
	mesh.height            = height
	var mi                := MeshInstance3D.new()
	mi.mesh                = mesh
	mi.material_override   = mat
	mi.position            = pos
	add_child(mi)
	return mi

func _sphere(radius: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh             := SphereMesh.new()
	mesh.radius           = radius
	mesh.height           = radius * 2.0
	var mi               := MeshInstance3D.new()
	mi.mesh               = mesh
	mi.material_override  = mat
	mi.position           = pos
	add_child(mi)
	return mi

func _build_leg(x: float, z: float) -> void:
	var body_mat  := _mat(_body_color,  0.95, 0.00)
	var bone_mat  := _mat(_bone_color,  0.78, 0.00)
	var armor_mat := _mat(_armor_color, 0.32, 0.80)

	var upper := _cyl(0.50, 1.52, Vector3(x, 1.74, z), body_mat)
	upper.rotation_degrees.z = -6.0 if x < 0.0 else 6.0
	_sphere(0.28, Vector3(x, 0.98, z), bone_mat)
	_box(Vector3(0.55, 0.18, 0.55), Vector3(x, 1.02, z), armor_mat)
	_cyl(0.38, 1.0, Vector3(x, 0.48, z), body_mat)
	_box(Vector3(0.95, 0.22, 1.15), Vector3(x, 0.11, z), bone_mat)

func _build_visuals() -> void:
	_body_mat     = _mat(_body_color,  0.95, 0.00)
	var bone_mat  := _mat(_bone_color,  0.78, 0.00)
	var armor_mat := _mat(_armor_color, 0.32, 0.80)
	var spine_mat := _mat(_spine_color, 0.45, 0.55)

	var eye_mat                       := StandardMaterial3D.new()
	eye_mat.albedo_color               = _eye_color
	eye_mat.emission_enabled           = true
	eye_mat.emission                   = _eye_color
	eye_mat.emission_energy_multiplier = 2.2

	_box(Vector3(3.0, 2.0, 5.5), Vector3(0, 3.5, 0), _body_mat)

	for i in 5:
		var ry := 2.75 + float(i) * 0.30
		var rz := -1.7  + float(i) * 0.65
		_box(Vector3(3.65, 0.10, 0.22), Vector3(0, ry, rz), bone_mat)

	_build_leg(-1.30, -1.55)
	_build_leg( 1.30, -1.55)
	_build_leg(-1.30,  1.55)
	_build_leg( 1.30,  1.55)

	for sx: float in [-1.72, 1.72]:
		_box(Vector3(0.82, 0.24, 1.65), Vector3(sx, 4.05, -1.45), armor_mat)
		_box(Vector3(0.82, 0.24, 1.65), Vector3(sx, 4.05,  1.25), armor_mat)

	for i in 7:
		var sz_pos  := -2.4 + float(i) * 0.82
		var spike_h := 0.75 - float(i) * 0.04
		_box(Vector3(0.40, spike_h, 0.30), Vector3(0, 4.68, sz_pos), spine_mat)

	var neck := _cyl(0.68, 2.3, Vector3(0, 3.85, -3.45), _body_mat)
	neck.rotation_degrees.x = -40.0
	_box(Vector3(2.1, 0.32, 0.55), Vector3(0, 3.30, -2.75), armor_mat)
	_box(Vector3(2.5, 1.65, 2.9), Vector3(0, 3.0, -5.35), _body_mat)
	_box(Vector3(2.3, 0.40, 2.75), Vector3(0, 3.88, -5.35), armor_mat)

	for sx: float in [-1.38, 1.38]:
		_box(Vector3(0.24, 1.30, 2.60), Vector3(sx, 3.0, -5.35), armor_mat)

	_box(Vector3(2.10, 0.28, 0.38), Vector3(0, 3.95, -6.58), bone_mat)
	_box(Vector3(1.75, 1.05, 2.25), Vector3(0, 2.62, -6.65), _body_mat)

	var jaw := _box(Vector3(1.55, 0.58, 2.05), Vector3(0, 1.82, -6.42), bone_mat)
	jaw.rotation_degrees.x = 6.0

	for i in 4:
		var tx := -0.60 + float(i) * 0.40
		_box(Vector3(0.17, 0.46, 0.17), Vector3(tx, 2.18, -7.50), bone_mat)

	for i in 3:
		var tx := -0.40 + float(i) * 0.40
		_box(Vector3(0.15, 0.38, 0.15), Vector3(tx, 2.08, -7.30), bone_mat)

	for ex: float in [-0.62, 0.62]:
		_sphere(0.27, Vector3(ex, 3.22, -6.15), eye_mat)

	var tail_r: Array[float] = [0.50, 0.37, 0.26, 0.16]
	for i in tail_r.size():
		var seg := _cyl(tail_r[i], 1.30,
			Vector3(0, 3.20 + float(i) * 0.24, 3.00 + float(i) * 1.05), _body_mat)
		seg.rotation_degrees.x = 30.0 + float(i) * 12.0

	for i in 6:
		_box(Vector3(0.13, 0.13, 0.07),
			Vector3(-1.62, 3.65 - float(i) * 0.27, -0.9 + float(i) * 0.08), armor_mat)

	var col     := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(3.6, 4.6, 10.5)
	col.shape    = col_box
	col.position = Vector3(0, 2.3, -2.0)
	add_child(col)

	var name_lbl           := Label3D.new()
	name_lbl.text           = enemy_name
	name_lbl.position       = Vector3(0, 6.0, 0)
	name_lbl.pixel_size     = 0.008
	name_lbl.billboard      = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.no_depth_test  = true
	add_child(name_lbl)

	_hp_label               = Label3D.new()
	_hp_label.position      = Vector3(0, 5.55, 0)
	_hp_label.pixel_size    = 0.010
	_hp_label.modulate      = Color(0.9, 0.15, 0.15)
	_hp_label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	add_child(_hp_label)

	_dmg_label               = Label3D.new()
	_dmg_label.visible        = false
	_dmg_label.position       = Vector3(0, 6.5, 0)
	_dmg_label.pixel_size     = 0.010
	_dmg_label.modulate       = Color.RED
	_dmg_label.billboard      = BaseMaterial3D.BILLBOARD_ENABLED
	_dmg_label.no_depth_test  = true
	add_child(_dmg_label)
