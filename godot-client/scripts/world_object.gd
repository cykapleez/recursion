extends StaticBody3D

var object_id:  String
var object_def: Dictionary

const _MODELS: Dictionary = {
	"obj-flower-pot":    "res://assets/models/pottedPlant.glb",
	"obj-iron-fence":    "res://assets/models/fence.glb",
	"obj-wooden-crate":  "res://assets/models/barrel.glb",
	"obj-garden-bench":  "res://assets/models/bench.glb",
	"obj-orange-tree":   "res://assets/models/tree-autumn.glb",
	"obj-stone-wall":    "res://assets/models/wall.glb",
	"obj-stone-block":   "res://assets/models/cliff_block_stone.glb",
	"obj-iron-spike":    "res://assets/models/fence-fortified.glb",
	"obj-small-shed":    "res://assets/models/building-sample-house-a.glb",
	"obj-wooden-house":  "res://assets/models/building-sample-house-b.glb",
}

# Per-object uniform scale applied on top of the natural model size
const _SCALES: Dictionary = {
	"obj-iron-fence":    2.0,
	"obj-orange-tree":   3.0,
	"obj-small-shed":    2.0,
	"obj-wooden-house":  3.5,
}

# Explicit collision size overrides — use only when you want the hitbox to
# differ from the visual (e.g. a gameplay-tuned smaller hitbox).
# When absent, _build_collision() sizes itself from the actual mesh AABB.
const _COLLISION_OVERRIDE: Dictionary = {}

# Label height above ground, tuned to each model's natural proportions
const _LABEL_Y: Dictionary = {
	"obj-flower-pot":    0.8,
	"obj-iron-fence":    3.2,
	"obj-wooden-crate":  1.2,
	"obj-garden-bench":  1.2,
	"obj-cherry-tree":   2.5,
	"obj-orange-tree":   9.0,
	"obj-stone-wall":    2.2,
	"obj-stone-block":   1.5,
	"obj-iron-spike":    1.8,
	"obj-small-shed":    3.0,
	"obj-wooden-house":  4.0,
}

func setup(id: String, def: Dictionary) -> void:
	object_id  = id
	object_def = def
	add_to_group("world_objects")
	_build_visuals()
	_build_collision()

func _build_visuals() -> void:
	var weight: int    = object_def.get("weight", 20)
	var label_y: float = float(_LABEL_Y.get(object_id, 1.5))

	var path: String = _MODELS.get(object_id, "")
	if path != "":
		var packed: PackedScene = load(path)
		if packed != null:
			var instance := packed.instantiate() as Node3D
			var s: float = float(_SCALES.get(object_id, 1.0))
			if s != 1.0:
				instance.scale = Vector3.ONE * s
			add_child(instance)
		else:
			push_warning("WorldObject: failed to load model %s — falling back to box" % path)
			_build_box_fallback(weight, label_y)
	elif object_id == "obj-cherry-tree":
		_build_cherry_tree()
	else:
		_build_box_fallback(weight, label_y)

	var name_lbl           := Label3D.new()
	name_lbl.text           = object_def.get("name", object_id)
	name_lbl.position.y     = label_y
	name_lbl.pixel_size     = 0.006
	name_lbl.billboard      = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.no_depth_test  = true
	add_child(name_lbl)

	var hint           := Label3D.new()
	hint.text           = "[E] pick up  %dkg" % weight
	hint.position.y     = label_y - 0.3
	hint.pixel_size     = 0.005
	hint.modulate       = Color.CYAN
	hint.billboard      = BaseMaterial3D.BILLBOARD_ENABLED
	hint.no_depth_test  = true
	add_child(hint)

func _build_cherry_tree() -> void:
	var trunk_mat          := StandardMaterial3D.new()
	trunk_mat.albedo_color  = Color(0.36, 0.20, 0.07)
	trunk_mat.roughness     = 0.95

	var trunk_mesh             := CylinderMesh.new()
	trunk_mesh.top_radius       = 0.10
	trunk_mesh.bottom_radius    = 0.16
	trunk_mesh.height           = 1.6
	var trunk                  := MeshInstance3D.new()
	trunk.mesh                  = trunk_mesh
	trunk.material_override     = trunk_mat
	trunk.position.y            = 0.8
	add_child(trunk)

	var canopy_mat         := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(1.0, 0.65, 0.75)
	canopy_mat.roughness    = 0.85

	var canopy_mesh        := SphereMesh.new()
	canopy_mesh.radius      = 0.95
	canopy_mesh.height      = 1.90
	var canopy             := MeshInstance3D.new()
	canopy.mesh             = canopy_mesh
	canopy.material_override = canopy_mat
	canopy.position.y       = 2.15
	add_child(canopy)

func _build_box_fallback(weight: int, _label_y: float) -> void:
	var sz: float     = clampf(0.4 + float(weight) * 0.01, 0.4, 2.2)
	var height: float = sz * 0.8
	var mat           := StandardMaterial3D.new()
	mat.albedo_color   = object_def.get("color", Color.WHITE)
	var box           := BoxMesh.new()
	box.size           = Vector3(sz, height, sz)
	var body          := MeshInstance3D.new()
	body.mesh          = box
	body.material_override = mat
	body.position.y    = height * 0.5
	add_child(body)

func _build_collision() -> void:
	var col_size: Vector3
	var col_pos:  Vector3

	if _COLLISION_OVERRIDE.has(object_id):
		col_size = _COLLISION_OVERRIDE[object_id]
		col_pos  = Vector3(0.0, col_size.y * 0.5, 0.0)
	else:
		var aabb := _visual_aabb()
		if aabb.size.length() > 0.01:
			col_size = aabb.size
			col_pos  = aabb.position + aabb.size * 0.5
		else:
			# No visual geometry yet — weight-based fallback
			var weight: int = object_def.get("weight", 20)
			var sz: float   = clampf(0.4 + float(weight) * 0.01, 0.4, 2.2)
			col_size = Vector3(sz, sz * 0.8, sz)
			col_pos  = Vector3(0.0, col_size.y * 0.5, 0.0)

	var shape     := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = col_size
	shape.shape    = box_shape
	shape.position = col_pos
	add_child(shape)

# Returns the combined AABB of all mesh children in this node's local space.
# Called after _build_visuals() so all mesh nodes already exist.
func _visual_aabb() -> AABB:
	var combined := AABB()
	var inv_self  := global_transform.affine_inverse()
	var found     := false
	for mi: MeshInstance3D in _find_mesh_instances(self):
		if mi.mesh == null:
			continue
		var local_aabb := (inv_self * mi.global_transform) * mi.get_aabb()
		if not found:
			combined = local_aabb
			found    = true
		else:
			combined = combined.merge(local_aabb)
	return combined

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is CollisionShape3D or child is Label3D:
			continue
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		result.append_array(_find_mesh_instances(child))
	return result
