extends RigidBody3D

# Physical projectile spawned when a cart item is thrown.
# Arcs through the air under gravity, tumbles, then deals damage on impact.
# Visual is taken directly from WorldObject.tscn so it matches the picked-up object exactly.
# The scene's BoxShape3D remains as the (intentionally small) physics hitbox.

const GRAVITY      := 9.8
const FLIGHT_TIME  := 0.85  # seconds to reach target

var damage:     int
var object_id:  String
var object_def: Dictionary

var _can_hit := false  # brief delay so projectile clears the player before detecting collisions

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Destroy automatically if it somehow never hits anything (e.g. launched off-map)
	get_tree().create_timer(6.0).timeout.connect(queue_free)
	# Enable collision after leaving the player's immediate area
	get_tree().create_timer(0.15).timeout.connect(func() -> void: _can_hit = true)

func launch(from: Vector3, target: Vector3) -> void:
	global_position = from
	# Compute velocity for a ballistic arc reaching `target` in FLIGHT_TIME seconds
	var t  := FLIGHT_TIME
	var vx := (target.x - from.x) / t
	var vz := (target.z - from.z) / t
	var vy := (target.y - from.y + 0.5 * GRAVITY * t * t) / t
	linear_velocity  = Vector3(vx, vy, vz)
	# Random tumbling — heavier objects tumble slower
	var spin := lerpf(12.0, 4.0, clampf(float(object_def.get("weight", 20)) / 200.0, 0.0, 1.0))
	angular_velocity = Vector3(
		randf_range(-spin, spin),
		randf_range(-spin, spin),
		randf_range(-spin, spin)
	)
	_build_visual()

func _build_visual() -> void:
	var wo_scene: PackedScene = load("res://scenes/WorldObject.tscn")
	var wo := wo_scene.instantiate() as Node3D
	wo.call("setup", object_id, object_def)
	# Steal visual children — skip collision shapes and labels (hitbox lives in the scene file)
	var children := wo.get_children()
	for child: Node in children:
		if child is CollisionShape3D or child is Label3D:
			continue
		wo.remove_child(child)
		add_child(child)
	wo.queue_free()

func _on_body_entered(body: Node3D) -> void:
	if not _can_hit:
		return
	if body.is_in_group("player"):
		return  # never self-hit
	if body.is_in_group("enemies"):
		body.take_damage(damage)
	_impact()
	queue_free()

func _impact() -> void:
	# TODO: replace with a proper VFX particle burst
	pass
