extends CharacterBody3D
class_name Player

enum Mode { FREE, BUILD, THROW_AIM, POWER_THROW_CHARGING }

const _CHAR_RUN_GLB  := "res://assets/models/characters/builder/Meshy_AI_THE_BUILDER_BLUE_biped_Animation_Running_withSkin.glb"
const _CHAR_WALK_GLB := "res://assets/models/characters/builder/Meshy_AI_THE_BUILDER_BLUE_biped_Animation_Walking_withSkin.glb"
const _CHAR_IDLE_GLB := "res://assets/models/characters/builder/Meshy_AI_THE_BUILDER_BLUE_biped_Character_output.glb"
const _TURN_SPEED    := 10.0

const BASE_SPEED        := 6.0
const GRAVITY           := 9.8
const MAX_THROW_DIST    := 8.0
const SMASH_RANGE       := 3.5
const LUNGE_SPEED       := 22.0
const LUNGE_TIME        := 0.18
const POWER_THROW_TIME  := 0.5    # seconds to charge a heavy throw
const MAX_LIVES         := 3

# Zoom: index 0 = closest (3 steps in), index 3 = default, index 6 = farthest (3 steps out)
const ZOOM_LEVELS:  Array[float] = [0.40, 0.58, 0.75, 1.0, 1.30, 1.60, 1.90]
const ZOOM_DEFAULT: int          = 3
const CAMERA_BASE:  Vector3      = Vector3(0.0, 12.0, 9.0)

@export var pickup_range := 2.5

var mode:             Mode   = Mode.FREE
var build_object_id:  String = ""
var throw_slot_index: int    = 0

var max_hp: int = 100
var hp:     int

var _throw_arc:    Node3D
var _hp_label:     Label3D
var _zoom_index:   int      = ZOOM_DEFAULT
var _camera:       Camera3D
var _model:        Node3D
var _anim_player:  AnimationPlayer
var _anim_run:     String = ""
var _anim_walk:    String = ""
var _anim_idle:    String = ""
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
	call_deferred("_find_camera")
	call_deferred("_store_spawn_pos")
	_build_visuals()
	_refresh_hp_bar()

func _store_spawn_pos() -> void:
	_spawn_pos = global_position

func _build_visuals() -> void:
	var packed := load(_CHAR_RUN_GLB) as PackedScene
	if packed == null:
		push_warning("Player: failed to load character model")
	else:
		_model = packed.instantiate() as Node3D
		add_child(_model)
		_setup_animations()

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

func _setup_animations() -> void:
	_anim_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		return
	# Discover the run animation name from the default library
	if _anim_player.has_animation_library(""):
		var names := _anim_player.get_animation_library("").get_animation_list()
		if names.size() > 0:
			_anim_run = names[0]
	# Import walk animation from the walking GLB into a separate library
	var walk_packed := load(_CHAR_WALK_GLB) as PackedScene
	if walk_packed != null:
		var walk_inst := walk_packed.instantiate()
		var walk_ap   := walk_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if walk_ap != null and walk_ap.has_animation_library(""):
			var walk_lib := walk_ap.get_animation_library("").duplicate(true) as AnimationLibrary
			if not _anim_player.has_animation_library("walk"):
				_anim_player.add_animation_library("walk", walk_lib)
			var wnames := walk_lib.get_animation_list()
			if wnames.size() > 0:
				_anim_walk = "walk/" + wnames[0]
		walk_inst.queue_free()
	# Import standing/idle animation from the character output GLB
	var idle_packed := load(_CHAR_IDLE_GLB) as PackedScene
	if idle_packed != null:
		var idle_inst := idle_packed.instantiate()
		var idle_ap   := idle_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if idle_ap != null and idle_ap.has_animation_library(""):
			var idle_lib := idle_ap.get_animation_library("").duplicate(true) as AnimationLibrary
			if not _anim_player.has_animation_library("idle"):
				_anim_player.add_animation_library("idle", idle_lib)
			var inames := idle_lib.get_animation_list()
			if inames.size() > 0:
				_anim_idle = "idle/" + inames[0]
		idle_inst.queue_free()
	# Fallback: use the built-in RESET track if the output GLB had no animation
	if _anim_idle == "" and _anim_player.has_animation("RESET"):
		_anim_idle = "RESET"

func _update_animation(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	# Rotate model to face movement direction
	if _model != null and hspeed > 0.5:
		var dir   := Vector3(velocity.x, 0.0, velocity.z).normalized()
		var tgt_y := atan2(dir.x, dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, tgt_y, _TURN_SPEED * delta)
	# Drive animation state
	if _anim_player == null or _anim_run == "":
		return
	if hspeed > 0.5:
		var target := _anim_walk if (hspeed < 3.0 and _anim_walk != "") else _anim_run
		if _anim_player.current_animation != target:
			_anim_player.play(target)
	else:
		var idle_target := _anim_idle if _anim_idle != "" else ""
		if idle_target != "" and _anim_player.current_animation != idle_target:
			_anim_player.play(idle_target)
		elif idle_target == "" and _anim_player.is_playing():
			_anim_player.stop()

func _find_throw_arc() -> void:
	_throw_arc = get_parent().get_node_or_null("ThrowArc3D")

func _find_camera() -> void:
	_camera = get_node_or_null("Camera3D") as Camera3D

func _apply_zoom() -> void:
	if _camera == null:
		return
	var target := CAMERA_BASE * ZOOM_LEVELS[_zoom_index]
	var tween  := create_tween()
	tween.tween_property(_camera, "position", target, 0.12).set_ease(Tween.EASE_OUT)

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
		_update_animation(delta)
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
	_update_animation(delta)

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
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_index = max(0, _zoom_index - 1)
				_apply_zoom()
				return
			if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_index = min(ZOOM_LEVELS.size() - 1, _zoom_index + 1)
				_apply_zoom()
				return
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
