extends CharacterBody3D

# Undead Colossus — large quadruped beast, 4× player scale.

@export var max_hp:     int    = 300
@export var enemy_name: String = "Undead Colossus"

# ── AI constants ──────────────────────────────────────────────────────────────
const ATTACK_RANGE:     float = 22.0
const ATTACK_COOLDOWN:  float = 4.0
const WINDUP_DURATION:  float = 1.4
const INITIAL_DELAY:    float = 2.0

const AOE_RADIUS:       float = 4.5
const AOE_DAMAGE:       int   = 35
const LASER_DAMAGE:     int   = 55
const LASER_HIT_WIDTH:  float = 2.0

# ── Movement constants ────────────────────────────────────────────────────────
const MOVE_SPEED:       float = 2.8
const GRAVITY:          float = 9.8
const WANDER_NEAR:      float = 3.0   # min distance from player for waypoints
const WANDER_FAR:       float = 8.0   # max distance from player for waypoints
const WAYPOINT_REACH:   float = 1.5   # distance at which a new waypoint is chosen

enum AttackPhase { IDLE, WINDUP_AOE, WINDUP_LASER }

# ── AI state ──────────────────────────────────────────────────────────────────
var _phase:           AttackPhase = AttackPhase.IDLE
var _phase_timer:     float       = -INITIAL_DELAY
var _aoe_indicator:   MeshInstance3D
var _laser_indicator: MeshInstance3D
var _laser_to:        Vector3

# ── Movement state ────────────────────────────────────────────────────────────
var _waypoint:        Vector3 = Vector3.ZERO
var _waypoint_timer:  float   = 0.0

const BODY_COLOR  := Color(0.10, 0.10, 0.12)   # near-black decayed flesh
const BONE_COLOR  := Color(0.62, 0.60, 0.50)   # aged yellowed bone
const ARMOR_COLOR := Color(0.17, 0.17, 0.20)   # dark iron plate
const SPINE_COLOR := Color(0.22, 0.20, 0.26)   # slightly oxidised spine ridges
const EYE_COLOR   := Color(0.45, 0.92, 1.0)    # cold undead glow

var attack_cooldown_override: float = 0.0   # set by WaveManager per wave; 0 = use const

var hp:         int
var _dying:     bool = false
var _body_mat:  StandardMaterial3D
var _hp_label:  Label3D
var _dmg_label: Label3D

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_build_visuals()
	_refresh_hp()

func _process(delta: float) -> void:
	if hp <= 0:
		return
	_phase_timer += delta
	match _phase:
		AttackPhase.IDLE:
			var effective_cd := attack_cooldown_override if attack_cooldown_override > 0.0 else ATTACK_COOLDOWN
			if _phase_timer >= 0.0 and _phase_timer >= effective_cd:
				var player := _nearest_player()
				if player != null and global_position.distance_to(player.global_position) <= ATTACK_RANGE:
					if randi() % 2 == 0:
						_begin_aoe(player)
					else:
						_begin_laser(player)
		AttackPhase.WINDUP_AOE:
			if _phase_timer >= WINDUP_DURATION:
				_land_aoe()
		AttackPhase.WINDUP_LASER:
			if _phase_timer >= WINDUP_DURATION:
				_fire_laser()
	_move_wander(delta)

# ── Mesh helpers ─────────────────────────────────────────────────────────────

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

# ── Leg builder ───────────────────────────────────────────────────────────────
# Body bottom is at y = 2.5 (torso center 3.5 − half-height 1.0).
# Legs span from y = 2.5 down to y = 0.

func _build_leg(x: float, z: float) -> void:
	var body_mat  := _mat(BODY_COLOR,  0.95, 0.00)  # rotting flesh — maximally rough
	var bone_mat  := _mat(BONE_COLOR,  0.78, 0.00)  # aged bone — rough, no sheen
	var armor_mat := _mat(ARMOR_COLOR, 0.32, 0.80)  # dark iron — metallic

	# Upper thigh — splayed slightly outward
	var upper := _cyl(0.50, 1.52, Vector3(x, 1.74, z), body_mat)
	upper.rotation_degrees.z = -6.0 if x < 0.0 else 6.0

	# Knee joint — exposed bone knuckle
	_sphere(0.28, Vector3(x, 0.98, z), bone_mat)

	# Knee armour cap
	_box(Vector3(0.55, 0.18, 0.55), Vector3(x, 1.02, z), armor_mat)

	# Lower shin
	_cyl(0.38, 1.0, Vector3(x, 0.48, z), body_mat)

	# Paw / hoof — wide flat slab of bone
	_box(Vector3(0.95, 0.22, 1.15), Vector3(x, 0.11, z), bone_mat)

# ── Main visual build ─────────────────────────────────────────────────────────

func _build_visuals() -> void:
	# TODO: replace with undead texture sheets when sourced
	_body_mat     = _mat(BODY_COLOR,  0.95, 0.00)  # decayed flesh
	var bone_mat  := _mat(BONE_COLOR,  0.78, 0.00)  # yellowed bone
	var armor_mat := _mat(ARMOR_COLOR, 0.32, 0.80)  # dark iron plate
	var spine_mat := _mat(SPINE_COLOR, 0.45, 0.55)  # oxidised spine

	var eye_mat                       := StandardMaterial3D.new()
	eye_mat.albedo_color               = EYE_COLOR
	eye_mat.emission_enabled           = true
	eye_mat.emission                   = EYE_COLOR
	eye_mat.emission_energy_multiplier = 2.2

	# ── Torso ────────────────────────────────────────────────────────────────
	# Centre at (0, 3.5, 0). Bottom edge at y = 2.5, top at y = 4.5.
	_box(Vector3(3.0, 2.0, 5.5), Vector3(0, 3.5, 0), _body_mat)

	# Undead rib bones — thin strips poking through flesh on each side
	for i in 5:
		var ry := 2.75 + float(i) * 0.30
		var rz := -1.7  + float(i) * 0.65
		_box(Vector3(3.65, 0.10, 0.22), Vector3(0, ry, rz), bone_mat)

	# ── Four legs ────────────────────────────────────────────────────────────
	_build_leg(-1.30, -1.55)   # front-left
	_build_leg( 1.30, -1.55)   # front-right
	_build_leg(-1.30,  1.55)   # back-left
	_build_leg( 1.30,  1.55)   # back-right

	# ── Shoulder & haunch armour plates ─────────────────────────────────────
	for sx: float in [-1.72, 1.72]:
		_box(Vector3(0.82, 0.24, 1.65), Vector3(sx, 4.05, -1.45), armor_mat)
		_box(Vector3(0.82, 0.24, 1.65), Vector3(sx, 4.05,  1.25), armor_mat)

	# ── Spine armour ridge ───────────────────────────────────────────────────
	for i in 7:
		var sz_pos  := -2.4 + float(i) * 0.82
		var spike_h := 0.75 - float(i) * 0.04
		_box(Vector3(0.40, spike_h, 0.30), Vector3(0, 4.68, sz_pos), spine_mat)

	# ── Neck ─────────────────────────────────────────────────────────────────
	# Angled forward-down to connect torso to drooping head.
	var neck := _cyl(0.68, 2.3, Vector3(0, 3.85, -3.45), _body_mat)
	neck.rotation_degrees.x = -40.0

	# Neck armour collar at base
	_box(Vector3(2.1, 0.32, 0.55), Vector3(0, 3.30, -2.75), armor_mat)

	# ── Head ─────────────────────────────────────────────────────────────────
	# Wide and low — beast lowers its head like a charging bull.
	_box(Vector3(2.5, 1.65, 2.9), Vector3(0, 3.0, -5.35), _body_mat)

	# Skull armour cap
	_box(Vector3(2.3, 0.40, 2.75), Vector3(0, 3.88, -5.35), armor_mat)

	# Cheek armour plates
	for sx: float in [-1.38, 1.38]:
		_box(Vector3(0.24, 1.30, 2.60), Vector3(sx, 3.0, -5.35), armor_mat)

	# Brow ridge — exposed bone overhang above eyes
	_box(Vector3(2.10, 0.28, 0.38), Vector3(0, 3.95, -6.58), bone_mat)

	# ── Snout / muzzle ────────────────────────────────────────────────────────
	_box(Vector3(1.75, 1.05, 2.25), Vector3(0, 2.62, -6.65), _body_mat)

	# ── Lower jaw — open slightly, hangs heavy ────────────────────────────────
	var jaw := _box(Vector3(1.55, 0.58, 2.05), Vector3(0, 1.82, -6.42), bone_mat)
	jaw.rotation_degrees.x = 6.0   # slightly dropped open

	# Upper teeth
	for i in 4:
		var tx := -0.60 + float(i) * 0.40
		_box(Vector3(0.17, 0.46, 0.17), Vector3(tx, 2.18, -7.50), bone_mat)

	# Lower teeth — offset for a jagged bite
	for i in 3:
		var tx := -0.40 + float(i) * 0.40
		_box(Vector3(0.15, 0.38, 0.15), Vector3(tx, 2.08, -7.30), bone_mat)

	# ── Eyes ─────────────────────────────────────────────────────────────────
	for ex: float in [-0.62, 0.62]:
		_sphere(0.27, Vector3(ex, 3.22, -6.15), eye_mat)

	# ── Tail — four tapering segments curving upward ──────────────────────────
	var tail_r: Array[float] = [0.50, 0.37, 0.26, 0.16]
	for i in tail_r.size():
		var seg := _cyl(tail_r[i], 1.30,
			Vector3(0, 3.20 + float(i) * 0.24, 3.00 + float(i) * 1.05), _body_mat)
		seg.rotation_degrees.x = 30.0 + float(i) * 12.0

	# ── Undead chain detail — dangling from left shoulder ────────────────────
	for i in 6:
		_box(Vector3(0.13, 0.13, 0.07),
			Vector3(-1.62, 3.65 - float(i) * 0.27, -0.9 + float(i) * 0.08), armor_mat)

	# ── Collision shape ───────────────────────────────────────────────────────
	# Covers full body + head extension, centred between torso and head.
	var col           := CollisionShape3D.new()
	var col_box       := BoxShape3D.new()
	col_box.size       = Vector3(3.6, 4.6, 10.5)
	col.shape          = col_box
	col.position       = Vector3(0, 2.3, -2.0)
	add_child(col)

	# ── Labels ───────────────────────────────────────────────────────────────
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

	_dmg_label              = Label3D.new()
	_dmg_label.visible      = false
	_dmg_label.position     = Vector3(0, 6.5, 0)
	_dmg_label.pixel_size   = 0.010
	_dmg_label.modulate     = Color.RED
	_dmg_label.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	_dmg_label.no_depth_test = true
	add_child(_dmg_label)

# ── Movement ─────────────────────────────────────────────────────────────────

func _move_wander(delta: float) -> void:
	var player := _nearest_player()

	_waypoint_timer -= delta
	if _waypoint_timer <= 0.0 or global_position.distance_to(_waypoint) < WAYPOINT_REACH:
		_pick_waypoint(player)

	var flat_pos     := Vector3(global_position.x, 0.0, global_position.z)
	var flat_target  := Vector3(_waypoint.x,       0.0, _waypoint.z)
	var dir          := (flat_target - flat_pos).normalized()

	velocity.x = dir.x * MOVE_SPEED
	velocity.z = dir.z * MOVE_SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _pick_waypoint(player: Node3D) -> void:
	var center: Vector3
	if player != null:
		center = player.global_position
	else:
		center = global_position

	var angle := randf() * TAU
	var dist  := randf_range(WANDER_NEAR, WANDER_FAR)
	_waypoint      = Vector3(center.x + cos(angle) * dist, 0.0, center.z + sin(angle) * dist)
	_waypoint_timer = randf_range(2.5, 5.0)

func _screen_shake() -> void:
	var player := _nearest_player()
	if player == null:
		return
	var cam := player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var rest   := Vector3(0.0, 12.0, 9.0)
	var tween  := create_tween()
	for i in 5:
		var offset := Vector3(randf_range(-0.5, 0.5), randf_range(-0.25, 0.25), randf_range(-0.2, 0.2))
		tween.tween_property(cam, "position", rest + offset, 0.05)
	tween.tween_property(cam, "position", rest, 0.1)

# ── AI attacks ───────────────────────────────────────────────────────────────

func _begin_aoe(player: Node3D) -> void:
	_phase       = AttackPhase.WINDUP_AOE
	_phase_timer = 0.0

	var disc_mat                       := StandardMaterial3D.new()
	disc_mat.albedo_color               = Color(1.0, 0.0, 0.0, 0.55)
	disc_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.emission_enabled           = true
	disc_mat.emission                   = Color(1.0, 0.1, 0.0)
	disc_mat.emission_energy_multiplier = 1.2
	disc_mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED

	var disc_mesh        := CylinderMesh.new()
	disc_mesh.top_radius  = AOE_RADIUS
	disc_mesh.bottom_radius = AOE_RADIUS
	disc_mesh.height      = 0.04

	_aoe_indicator                  = MeshInstance3D.new()
	_aoe_indicator.mesh              = disc_mesh
	_aoe_indicator.material_override = disc_mat
	get_tree().root.add_child(_aoe_indicator)
	_aoe_indicator.global_position   = Vector3(player.global_position.x, 0.02, player.global_position.z)

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

	# Flash orange on hit
	var tween := create_tween()
	tween.tween_property(_body_mat, "albedo_color", Color(1.0, 0.55, 0.0), 0.06)
	tween.tween_property(_body_mat, "albedo_color", BODY_COLOR, 0.25)

	for player: Node3D in get_tree().get_nodes_in_group("player"):
		if player.global_position.distance_to(aoe_world_pos) <= AOE_RADIUS:
			if player.has_method("take_damage"):
				player.call("take_damage", AOE_DAMAGE)

func _begin_laser(player: Node3D) -> void:
	_phase       = AttackPhase.WINDUP_LASER
	_phase_timer = 0.0
	_laser_to    = player.global_position + Vector3(0.0, 1.0, 0.0)

	var beam_mat                       := StandardMaterial3D.new()
	beam_mat.albedo_color               = Color(1.0, 0.0, 0.0, 0.5)
	beam_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled           = true
	beam_mat.emission                   = Color(1.0, 0.1, 0.0)
	beam_mat.emission_energy_multiplier = 1.8
	beam_mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED

	var origin  := _laser_origin()
	var mid     := (origin + _laser_to) * 0.5
	var length  := origin.distance_to(_laser_to)

	var beam_mesh        := BoxMesh.new()
	beam_mesh.size        = Vector3(0.3, 0.3, length)

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

	# Flash white on fire
	var tween := create_tween()
	tween.tween_property(_body_mat, "albedo_color", Color(1.0, 1.0, 1.0), 0.04)
	tween.tween_property(_body_mat, "albedo_color", BODY_COLOR, 0.3)

	var origin := _laser_origin()
	var dir    := (_laser_to - origin).normalized()

	for player: Node3D in get_tree().get_nodes_in_group("player"):
		var to_player := player.global_position - origin
		var proj      := to_player.dot(dir)
		if proj < 0.0:
			continue
		var perp := (to_player - dir * proj).length()
		if perp <= LASER_HIT_WIDTH:
			if player.has_method("take_damage"):
				player.call("take_damage", LASER_DAMAGE)

func _laser_origin() -> Vector3:
	# Midpoint between the two eye spheres, in world space
	return global_position + Vector3(0.0, 3.22, -6.15)

func _nearest_player() -> Node3D:
	var best:     Node3D = null
	var best_dist: float = INF
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
	tween.tween_property(_body_mat, "albedo_color", BODY_COLOR, 0.25)

func _die() -> void:
	_dying = true
	remove_from_group("enemies")   # wave manager reads group size; remove immediately
	if _aoe_indicator != null:
		_aoe_indicator.queue_free()
		_aoe_indicator = null
	if _laser_indicator != null:
		_laser_indicator.queue_free()
		_laser_indicator = null
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.6, 0.04, 1.6), 0.45)
	tween.tween_callback(queue_free)
