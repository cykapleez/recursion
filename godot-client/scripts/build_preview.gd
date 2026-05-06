extends Node3D

var _ghost: Node3D = null
var _current_id: String = ""
var _player: Node3D = null

func _ready() -> void:
	GameManager.mode_changed.connect(_on_mode_changed)
	call_deferred("_find_player")

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0] as Node3D

func _on_mode_changed(mode_name: String) -> void:
	if mode_name != "BUILD":
		_clear_ghost()

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var player_mode: int    = _player.get("mode")
	var player_obj_id: String = _player.get("build_object_id")

	if player_mode != Player.Mode.BUILD or player_obj_id == "":
		_clear_ghost()
		return

	if player_obj_id != _current_id:
		_rebuild_ghost(player_obj_id)

	var raw := _get_mouse_world_pos()
	var pos: Vector3
	if Input.is_key_pressed(KEY_ALT):
		pos = Vector3(raw.x, 0.0, raw.z)
	else:
		pos = GameManager.snap_to_grid(raw)
		pos.y = 0.0

	if _ghost:
		_ghost.global_position = pos

func _rebuild_ghost(object_id: String) -> void:
	_clear_ghost()
	_current_id = object_id

	var def: Dictionary = GameManager.OBJECT_DEFS.get(object_id, {})
	if def.is_empty():
		return

	var wo_scene: PackedScene = load("res://scenes/WorldObject.tscn")
	var wo := wo_scene.instantiate() as StaticBody3D
	add_child(wo)
	wo.call("setup", object_id, def)
	wo.remove_from_group("world_objects")
	wo.collision_layer = 0
	wo.collision_mask  = 0
	_make_transparent(wo)
	_ghost = wo

func _make_transparent(node: Node3D) -> void:
	for child in node.get_children():
		if child is Label3D:
			(child as Label3D).visible = false
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat: Material = mi.material_override
			if mat == null and mi.mesh != null:
				mat = mi.mesh.surface_get_material(0)
			if mat is StandardMaterial3D:
				var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				dup.albedo_color.a = 0.4
				mi.material_override = dup
		if child is Node3D:
			_make_transparent(child as Node3D)

func _clear_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_current_id = ""

func _get_mouse_world_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var mouse    := get_viewport().get_mouse_position()
	var ray_from := cam.project_ray_origin(mouse)
	var ray_dir  := cam.project_ray_normal(mouse)
	if abs(ray_dir.y) < 0.0001:
		return Vector3.ZERO
	var t := -ray_from.y / ray_dir.y
	return ray_from + ray_dir * t
