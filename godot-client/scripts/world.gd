extends Node3D

@onready var mode_label: Label = $CanvasLayer/ModeLabel

func _ready() -> void:
	GameManager.mode_changed.connect(_on_mode_changed)
	_on_mode_changed("FREE")
	_build_spawn_markers()
	_populate_world()

func _build_spawn_markers() -> void:
	var half := GameManager.SPAWN_ZONE_HALF
	var sz   := half * 2.0

	var mat                        := StandardMaterial3D.new()
	mat.albedo_color                = Color(0.25, 0.55, 1.0, 0.65)
	mat.transparency                = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode                = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled            = true
	mat.emission                    = Color(0.25, 0.55, 1.0)
	mat.emission_energy_multiplier  = 0.5

	var mesh      := BoxMesh.new()
	mesh.size      = Vector3(sz, 0.02, sz)

	for spawn: Vector3 in GameManager.SPAWN_POSITIONS:
		var mi              := MeshInstance3D.new()
		mi.mesh              = mesh
		mi.material_override = mat
		mi.position          = Vector3(spawn.x, 0.01, spawn.z)
		add_child(mi)

func _populate_world() -> void:
	var ids: Array[String] = [
		"obj-flower-pot",   "obj-flower-pot",
		"obj-iron-fence",   "obj-iron-fence",   "obj-iron-fence",
		"obj-wooden-crate",
		"obj-garden-bench",
		"obj-cherry-tree",
		"obj-orange-tree",  "obj-orange-tree",
		"obj-stone-wall",   "obj-stone-block",
		"obj-iron-spike",
		"obj-small-shed",
		"obj-wooden-house",
	]
	var positions: Array[Vector3] = [
		Vector3(-2.0, 0.0, -1.0), Vector3( 2.0, 0.0, -1.0),
		Vector3(-3.0, 0.0, -3.0), Vector3(-1.5, 0.0, -3.0), Vector3( 0.0, 0.0, -3.0),
		Vector3( 3.5, 0.0, -2.5),
		Vector3( 1.0, 0.0, -4.5),
		Vector3( 2.5, 0.0, -5.0),
		Vector3(-5.0, 0.0, -5.0), Vector3( 5.0, 0.0, -5.0),
		Vector3(-5.5, 0.0, -6.5), Vector3( 5.5, 0.0, -6.5),
		Vector3( 0.0, 0.0, -7.5),
		Vector3(-4.0, 0.0, -9.0),
		Vector3( 0.0, 0.0, -13.0),
	]
	for i in range(ids.size()):
		GameManager.place_object(ids[i], positions[i])

func _on_mode_changed(mode_name: String) -> void:
	match mode_name:
		"FREE":
			mode_label.text = "FREE  —  B: Build  |  E: Pick up  |  T: Throw  |  R: Smash (melee, must be close)"
		"BUILD":
			mode_label.text = "BUILD  —  Click to place (snaps to grid)  |  ALT+Click: free place  |  B: Cancel"
		"THROW_AIM":
			mode_label.text = "THROW AIM  —  Click on or near the enemy  |  T: Cancel"
		_:
			mode_label.text = mode_name
