extends CharacterBody3D
class_name Player

enum Mode { FREE, BUILD, THROW_AIM, POWER_THROW_CHARGING }

const BASE_SPEED        := 6.0
const GRAVITY           := 9.8
const MAX_THROW_DIST    := 8.0
const SMASH_RANGE       := 3.5
const LUNGE_SPEED       := 22.0
const LUNGE_TIME        := 0.18
const POWER_THROW_TIME  := 0.5    # seconds to charge a heavy throw
const MAX_LIVES         := 3

@export var pickup_range := 2.5

var mode:             Mode   = Mode.FREE
var build_object_id:  String = ""
var throw_slot_index: int    = 0

var max_hp: int = 100
var hp:     int

var _throw_arc:    Node3D
var _hp_label:     Label3D
var _smashing:     bool    = false
var _lunge_dir:    Vector3 = Vector3.ZERO
var _lunge_timer:  float   = 0.0
var _lunge_target: Node3D
var _spawn_pos:           Vector3 = Vector3.ZERO
var _dead:                bool    = false
var lives:                int     = MAX_LIVES
var _power_throw_timer:   float   = 0.0
var _power_throw_target:  Vector3 = Vector3.ZERO
var _charge_label:        Label3D

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	call_deferred("_find_throw_arc")
	call_deferred("_store_spawn_pos")
	_build_visuals()
	_refresh_hp_bar()

func _store_spawn_pos() -> void:
	_spawn_pos = global_position

func _build_visuals() -> void:
	# TODO: replace with proper character texture sheets when sourced
	var blue := _mat(Color(0.2, 0.5, 1.0),  0.85, 0.0)   # cloth/soft armour
	var skin := _mat(Color(0.95, 0.78, 0.62), 0.70, 0.0)  # skin
	var dark := _mat(Color(0.1, 0.2, 0.5),   0.35, 0.15)  # eye gloss

	# Legs / torso
	var body_mesh          := CylinderMesh.new()
	body_mesh.top_radius    = 0.22
	body_mesh.bottom_radius = 0.28
	body_mesh.height        = 1.2
	var body               := MeshInstance3D.new()
	body.mesh               = body_mesh
	body.material_override  = blue
	body.position.y         = 0.6
	add_child(body)

	# Head
	var head_mesh  := SphereMesh.new()
	head_mesh.radius = 0.28
	head_mesh.height = 0.56
	var head       := MeshInstance3D.new()
	head.mesh       = head_mesh
	head.material_override = skin
	head.position.y = 1.58
	add_child(head)

	# Eyes (two small dark spheres)
	for ex: float in [-0.12, 0.12]:
		var em  := SphereMesh.new()
		em.radius = 0.06
		em.height = 0.12
		var ei  := MeshInstance3D.new()
		ei.mesh              = em
		ei.material_override = dark
		ei.position          = Vector3(ex, 1.62, -0.22)
		add_child(ei)

	var name_lbl           := Label3D.new()
	name_lbl.text           = "Player"
	name_lbl.position       = Vector3(0, 2.4, 0)
	name_lbl.pixel_size     = 0.007
	name_lbl.billboard      = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.no_depth_test  = true
	add_child(name_lbl)

	_hp_label               = Label3D.new()
	_hp_label.position      = Vector3(0, 2.1, 0)
	_hp_label.pixel_size    = 0.009
	_hp_label.modulate      = Color(0.15, 0.9, 0.15)
	_hp_label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	add_child(_hp_label)

	_charge_label              = Label3D.new()
	_charge_label.visible       = false
	_charge_label.position      = Vector3(0, 3.2, 0)
	_charge_label.pixel_size    = 0.009
	_charge_label.modulate      = Color(1.0, 0.85, 0.1)
	_charge_label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	_charge_label.no_depth_test = true
	add_child(_charge_label)

func _mat(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	m.metallic     = metallic
	return m

func _refresh_hp_bar() -> void:
	var pct    := float(hp) / float(max_hp)
	var filled := int(pct * 8.0)
	var bar    := ""
	for j in 8:
		bar += "█" if j < filled else "░"
	_hp_label.text = bar

func take_damage(amount: int) -> void:
	if _dead:
		return
	hp = max(0, hp - amount)
	_refresh_hp_bar()
	if hp <= 0:
		_die()

func _die() -> void:
	_dead   = true
	visible = false
	lives  -= 1
	GameManager.lives_changed.emit(lives)
	if lives <= 0:
		GameManager.game_over.emit()
		return
	await get_tree().create_timer(1.2).timeout
	global_position = _spawn_pos
	hp = max_hp
	_refresh_hp_bar()
	visible = true
	_dead   = false

func _current_throw_weight() -> float:
	if throw_slot_index >= GameManager.cart_items.size():
		return 0.0
	var item: Dictionary = GameManager.cart_items[throw_slot_index]
	var def:  Dictionary = GameManager.OBJECT_DEFS.get(item.get("object_id", ""), {})
	return float(def.get("weight", 0))

func _find_throw_arc() -> void:
	_throw_arc = get_parent().get_node_or_null("ThrowArc3D")

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _smashing:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = 0.0
		velocity.x    = _lunge_dir.x * LUNGE_SPEED
		velocity.z    = _lunge_dir.z * LUNGE_SPEED
		move_and_slide()
		_lunge_timer -= delta
		if _lunge_timer <= 0.0:
			_finish_smash()
		return

	if mode in [Mode.FREE, Mode.BUILD, Mode.THROW_AIM]:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = 0.0
		var raw := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var spd  := BASE_SPEED * GameManager.get_speed_modifier()
		velocity.x = raw.x * spd
		velocity.z = raw.y * spd
		move_and_slide()

func _process(delta: float) -> void:
	if _dead:
		return
	if mode == Mode.THROW_AIM and _throw_arc:
		_throw_arc.call("show_arc",
			global_position + Vector3(0, 1.5, 0),
			_clamped_throw_pos())
	if mode == Mode.POWER_THROW_CHARGING:
		_power_throw_timer += delta
		var pct  := clampf(_power_throw_timer / POWER_THROW_TIME, 0.0, 1.0)
		var bars := int(pct * 8)
		var bar  := ""
		for i in 8:
			bar += "█" if i < bars else "░"
		_charge_label.text    = "⚡ " + bar
		_charge_label.visible = true
		if _power_throw_timer >= POWER_THROW_TIME:
			_charge_label.visible = false
			GameManager.throw_object(throw_slot_index, _power_throw_target)
			_set_mode(Mode.FREE)

func _unhandled_input(event: InputEvent) -> void:
	if _dead or mode == Mode.POWER_THROW_CHARGING:
		return
	if event.is_action_pressed("toggle_build"):
		_set_mode(Mode.FREE if mode == Mode.BUILD else Mode.BUILD)
		return
	if event.is_action_pressed("toggle_throw"):
		if GameManager.cart_items.is_empty():
			return
		_set_mode(Mode.FREE if mode == Mode.THROW_AIM else Mode.THROW_AIM)
		return
	if event.is_action_pressed("interact"):
		_try_pickup()
		return
	if event.is_action_pressed("smash"):
		_try_smash()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if mode == Mode.THROW_AIM:
				_set_mode(Mode.FREE)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			match mode:
				Mode.BUILD:
					if build_object_id != "":
						var pos := _get_mouse_world_pos()
						if not Input.is_key_pressed(KEY_ALT):
							pos = GameManager.snap_to_grid(pos)
						GameManager.place_object(build_object_id, pos)
				Mode.THROW_AIM:
					if _current_throw_weight() > GameManager.POWER_THROW_THRESHOLD:
						_power_throw_target = _clamped_throw_pos()
						_power_throw_timer  = 0.0
						_set_mode(Mode.POWER_THROW_CHARGING)
					else:
						GameManager.throw_object(throw_slot_index, _clamped_throw_pos())
						_set_mode(Mode.FREE)

func _try_pickup() -> void:
	for wo in get_tree().get_nodes_in_group("world_objects"):
		var flat := Vector2(global_position.x - wo.global_position.x,
							global_position.z - wo.global_position.z)
		if flat.length() <= pickup_range:
			GameManager.pickup_object(wo)
			return

func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if _throw_arc:
		if mode != Mode.THROW_AIM:
			_throw_arc.call("hide_arc")
	GameManager.emit_signal("mode_changed", Mode.keys()[mode])

func set_build_object(id: String) -> void:
	build_object_id = id
	_set_mode(Mode.BUILD)

func set_throw_slot(index: int) -> void:
	throw_slot_index = index
	_set_mode(Mode.THROW_AIM)

func _try_smash() -> void:
	if _smashing or GameManager.cart_items.is_empty():
		return
	var enemy: Node3D = GameManager.get_nearest_enemy_in_range(global_position, SMASH_RANGE)
	if enemy == null:
		print("No enemy in smash range (%.1f units)" % SMASH_RANGE)
		return
	if mode != Mode.FREE:
		_set_mode(Mode.FREE)
	var dir   := enemy.global_position - global_position
	dir.y      = 0.0
	_lunge_dir    = dir.normalized()
	_lunge_timer  = LUNGE_TIME
	_lunge_target = enemy
	_smashing     = true

func _finish_smash() -> void:
	_smashing  = false
	velocity.x = 0.0
	velocity.z = 0.0
	if is_instance_valid(_lunge_target):
		GameManager.smash_object(throw_slot_index, _lunge_target)
	_lunge_target = null

func _clamped_throw_pos() -> Vector3:
	var raw    := _get_mouse_world_pos()
	var offset := Vector3(raw.x - global_position.x, 0.0, raw.z - global_position.z)
	if offset.length() > MAX_THROW_DIST:
		offset = offset.normalized() * MAX_THROW_DIST
	return Vector3(global_position.x + offset.x, 0.0, global_position.z + offset.z)

func _get_mouse_world_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var mouse    := get_viewport().get_mouse_position()
	var ray_from := cam.project_ray_origin(mouse)
	var ray_dir  := cam.project_ray_normal(mouse)
	# Intersect with Y = 0 ground plane
	if abs(ray_dir.y) < 0.0001:
		return Vector3.ZERO
	var t := -ray_from.y / ray_dir.y
	return ray_from + ray_dir * t
