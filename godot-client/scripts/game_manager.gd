extends Node

# Alpha PoC: all game logic runs locally. No server required to test mechanics.
# TODO: Replace local computations with backend socket events before multiplayer.

const PLAYER_STRENGTH  := 15
const THROW_MULTIPLIER := 1.4   # Warrior class
const SMASH_MULTIPLIER := 1.8   # melee bonus over throw
const GRID_SIZE              := 1.0
const SPAWN_POSITIONS: Array[Vector3] = [Vector3(0.0, 0.0, 0.0)]
const SPAWN_ZONE_HALF: float = 1.0
const POWER_THROW_THRESHOLD: float = 30.0   # kg — above this weight, throw requires a charge

const OBJECT_DEFS := {
	# ── Crafted (built products) — full weight-based damage ───────────────────
	"obj-flower-pot":    { "name": "Flower Pot",        "item_category": "crafted",  "weight": 5,   "throw_damage_base": 12,  "throw_effectiveness": 1.0,  "color": Color(0.8, 0.3, 0.8) },
	"obj-iron-fence":    { "name": "Iron Fence",         "item_category": "crafted",  "weight": 15,  "throw_damage_base": 22,  "throw_effectiveness": 1.0,  "color": Color(0.5, 0.5, 0.6) },
	"obj-wooden-crate":  { "name": "Wooden Crate",       "item_category": "crafted",  "weight": 20,  "throw_damage_base": 18,  "throw_effectiveness": 1.0,  "color": Color(0.55, 0.35, 0.15) },
	"obj-garden-bench":  { "name": "Garden Bench",       "item_category": "crafted",  "weight": 25,  "throw_damage_base": 20,  "throw_effectiveness": 1.0,  "color": Color(0.2, 0.5, 0.2) },
	"obj-stone-wall":    { "name": "Stone Wall",         "item_category": "crafted",  "weight": 60,  "throw_damage_base": 35,  "throw_effectiveness": 1.0,  "color": Color(0.55, 0.55, 0.55) },
	"obj-iron-spike":    { "name": "Iron Spike Trap",    "item_category": "crafted",  "weight": 35,  "throw_damage_base": 60,  "throw_effectiveness": 1.0,  "color": Color(0.3, 0.3, 0.35) },
	"obj-small-shed":    { "name": "Small Shed",         "item_category": "crafted",  "weight": 120, "throw_damage_base": 65,  "throw_effectiveness": 1.0,  "color": Color(0.7, 0.5, 0.3) },
	"obj-wooden-house":  { "name": "Wooden House",       "item_category": "crafted",  "weight": 200, "throw_damage_base": 100, "throw_effectiveness": 1.0,  "color": Color(0.65, 0.4, 0.2) },
	# ── Farmable (natural objects) — weak throw damage (0.25×) ───────────────
	"obj-cherry-tree":   { "name": "Cherry Tree",        "item_category": "farmable", "weight": 20,  "throw_damage_base": 15,  "throw_effectiveness": 0.25, "color": Color(1.0, 0.65, 0.75) },
	"obj-orange-tree":   { "name": "Orange Tree",        "item_category": "farmable", "weight": 120, "throw_damage_base": 35,  "throw_effectiveness": 0.25, "color": Color(1.0, 0.55, 0.05) },
	"obj-stone-block":   { "name": "Stone Block",        "item_category": "farmable", "weight": 80,  "throw_damage_base": 45,  "throw_effectiveness": 0.25, "color": Color(0.4, 0.4, 0.45) },
}

var cart_items:          Array = []
var cart_max_weight:     int   = 150
var cart_current_weight: int   = 0

signal cart_changed(items: Array)
signal throw_resolved(damage: int, target_pos: Vector3, object_id: String)
signal mode_changed(mode_name: String)
signal lives_changed(remaining: int)
signal game_over

func _ready() -> void:
	_setup_input_map()

func _setup_input_map() -> void:
	var actions: Array[String] = ["move_up", "move_down", "move_left", "move_right", "toggle_build", "toggle_throw", "interact", "smash"]
	var keys:    Array[Key]    = [KEY_W,     KEY_S,       KEY_A,       KEY_D,        KEY_B,          KEY_T,          KEY_E,      KEY_R]
	for i in range(actions.size()):
		if not InputMap.has_action(actions[i]):
			InputMap.add_action(actions[i])
		var ev := InputEventKey.new()
		ev.keycode = keys[i]
		InputMap.action_add_event(actions[i], ev)

func snap_to_grid(pos: Vector3) -> Vector3:
	return Vector3(
		round(pos.x / GRID_SIZE) * GRID_SIZE,
		pos.y,
		round(pos.z / GRID_SIZE) * GRID_SIZE
	)

# --- Placement ---

func place_object(object_id: String, world_pos: Vector3) -> void:
	var def: Dictionary = OBJECT_DEFS.get(object_id, {})
	if def.is_empty():
		return
	for spawn: Vector3 in SPAWN_POSITIONS:
		if abs(world_pos.x - spawn.x) < SPAWN_ZONE_HALF and abs(world_pos.z - spawn.z) < SPAWN_ZONE_HALF:
			return
	# TODO: send object:place to backend → spawn on server confirmation
	var wo_scene: PackedScene = load("res://scenes/WorldObject.tscn")
	var wo := wo_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(wo)
	wo.call("setup", object_id, def)
	wo.global_position = world_pos

# --- Pickup ---

func pickup_object(world_object: Node3D) -> void:
	var def: Dictionary = OBJECT_DEFS.get(world_object.get("object_id"), {})
	if def.is_empty():
		return
	var weight: int = def.get("weight", 0)
	var lift_cap: int = PLAYER_STRENGTH * 10  # 150kg solo cap for Warrior STR 15
	if weight > lift_cap:
		# TODO: trigger cooperative lift UI instead of hard block
		print("Too heavy to lift alone! (%dkg, your limit: %dkg)" % [weight, lift_cap])
		return
	cart_items.append({ "object_id": world_object.get("object_id"), "weight": weight })
	_recalc_weight()
	world_object.queue_free()
	emit_signal("cart_changed", cart_items)

# --- Throw ---

func throw_object(slot_index: int, target_pos: Vector3) -> void:
	if slot_index >= cart_items.size():
		return
	var item: Dictionary = cart_items[slot_index]
	var def: Dictionary = OBJECT_DEFS.get(item.object_id, {})
	if def.is_empty():
		return

	var damage := calc_throw_damage(def)

	# Spawn the physical projectile from the player's position
	# TODO: send cart:throw to backend → apply server-authoritative damage
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player := players[0] as Node3D
	var launch_pos := player.global_position + Vector3(0, 1.5, 0)

	var proj_scene: PackedScene = load("res://scenes/ThrowProjectile.tscn")
	var proj := proj_scene.instantiate()
	proj.set("damage", damage)
	proj.set("object_id", item.object_id)
	proj.set("object_def", def)
	get_tree().current_scene.add_child(proj)
	proj.call("launch", launch_pos, target_pos)

	cart_items.remove_at(slot_index)
	_recalc_weight()
	emit_signal("cart_changed", cart_items)
	emit_signal("throw_resolved", damage, target_pos, item.object_id)

func calc_throw_damage(def: Dictionary) -> int:
	var base: float      = float(def.get("throw_damage_base", 0)) * float(def.get("throw_effectiveness", 1.0))
	var str_bonus: float = float(PLAYER_STRENGTH) * THROW_MULTIPLIER
	return roundi(base + str_bonus)

func calc_smash_damage(def: Dictionary) -> int:
	var base: float      = float(def.get("throw_damage_base", 0)) * float(def.get("throw_effectiveness", 1.0))
	var str_bonus: float = float(PLAYER_STRENGTH) * THROW_MULTIPLIER
	return roundi((base + str_bonus) * SMASH_MULTIPLIER)

# --- Smash ---

func get_nearest_enemy_in_range(from: Vector3, range_dist: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist    := range_dist
	for body in get_tree().get_nodes_in_group("enemies"):
		var enemy  := body as Node3D
		var flat   := Vector2(from.x - enemy.global_position.x, from.z - enemy.global_position.z)
		if flat.length() < nearest_dist:
			nearest_dist = flat.length()
			nearest      = enemy
	return nearest

func smash_object(slot_index: int, enemy: Node3D) -> void:
	if slot_index >= cart_items.size():
		return
	var item: Dictionary = cart_items[slot_index]
	var def: Dictionary  = OBJECT_DEFS.get(item.object_id, {})
	if def.is_empty():
		return
	var damage := calc_smash_damage(def)
	enemy.call("take_damage", damage)
	cart_items.remove_at(slot_index)
	_recalc_weight()
	emit_signal("cart_changed", cart_items)
	emit_signal("throw_resolved", damage, enemy.global_position, item.object_id)

func _recalc_weight() -> void:
	cart_current_weight = 0
	for item: Dictionary in cart_items:
		cart_current_weight += item.get("weight", 0)

func is_overloaded() -> bool:
	return cart_current_weight > cart_max_weight

func get_speed_modifier() -> float:
	return 0.65 if is_overloaded() else 1.0
