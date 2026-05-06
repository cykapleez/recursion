extends Node

const TOTAL_WAVES:    int   = 3
const SPAWN_DIST:     float = 18.0
const BETWEEN_DELAY:  float = 6.0
const PRE_DELAY:      float = 3.0

# Per-wave config: enemy count + attack cooldown (seconds between attacks)
const WAVE_DEFS: Array[Dictionary] = [
	{ "count": 2, "cooldown": 4.0 },
	{ "count": 3, "cooldown": 3.2 },
	{ "count": 4, "cooldown": 2.5 },
]

signal wave_started(num: int, total: int)
signal wave_cleared(num: int)
signal countdown_tick(secs_left: float)
signal all_waves_cleared
signal game_lost

var _wave:  int    = 0
var _state: String = "IDLE"   # IDLE, PRE, ACTIVE, BETWEEN, WON, LOST
var _timer: float  = 0.0

func start() -> void:
	_state = "PRE"
	_timer = PRE_DELAY
	GameManager.game_over.connect(_on_game_over)

func _process(delta: float) -> void:
	match _state:
		"PRE", "BETWEEN":
			_timer -= delta
			emit_signal("countdown_tick", maxf(_timer, 0.0))
			if _timer <= 0.0:
				_spawn_wave()
		"ACTIVE":
			if get_tree().get_nodes_in_group("enemies").is_empty():
				if _wave >= TOTAL_WAVES:
					_state = "WON"
					emit_signal("all_waves_cleared")
				else:
					_state = "BETWEEN"
					_timer = BETWEEN_DELAY
					emit_signal("wave_cleared", _wave)

func _spawn_wave() -> void:
	_wave += 1
	_state = "ACTIVE"
	var def: Dictionary = WAVE_DEFS[_wave - 1]
	emit_signal("wave_started", _wave, TOTAL_WAVES)

	var scene: PackedScene = load("res://scenes/Enemy.tscn")
	for i in def["count"]:
		var angle := TAU * float(i) / float(def["count"]) + randf_range(-0.25, 0.25)
		var pos   := Vector3(cos(angle) * SPAWN_DIST, 0.0, sin(angle) * SPAWN_DIST)
		var e     := scene.instantiate()
		e.set("attack_cooldown_override", def["cooldown"])
		get_tree().current_scene.add_child(e)
		e.global_position = pos

func _on_game_over() -> void:
	if _state in ["WON", "LOST"]:
		return
	_state = "LOST"
	emit_signal("game_lost")
