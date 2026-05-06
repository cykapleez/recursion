extends Node3D

@onready var mode_label:    Label      = $CanvasLayer/ModeLabel
@onready var _canvas:       CanvasLayer = $CanvasLayer
@onready var _wave_manager: Node        = $WaveManager

# Light objects that respawn between waves so the player always has ammo
const _RESUPPLY_IDS: Array[String] = [
	"obj-flower-pot", "obj-flower-pot",
	"obj-wooden-crate",
	"obj-iron-fence",
	"obj-garden-bench",
	"obj-cherry-tree",
]
const _RESUPPLY_POS: Array[Vector3] = [
	Vector3(-2.0, 0.0, -1.0),
	Vector3( 2.0, 0.0, -1.0),
	Vector3( 3.5, 0.0, -2.5),
	Vector3(-3.0, 0.0, -3.0),
	Vector3( 1.0, 0.0, -4.5),
	Vector3( 2.5, 0.0, -5.0),
]

var _wave_label:   Label
var _lives_label:  Label
var _status_label: Label
var _overlay:      ColorRect
var _game_ended:   bool = false

func _ready() -> void:
	GameManager.mode_changed.connect(_on_mode_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	_on_mode_changed("FREE")
	_build_hud()
	_build_spawn_markers()
	_populate_world()
	_connect_wave_manager()
	_wave_manager.start()

# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 15)
	_wave_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_wave_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.offset_top = 8.0
	_wave_label.text = "— PREPARE —"
	_canvas.add_child(_wave_label)

	_lives_label = Label.new()
	_lives_label.add_theme_font_size_override("font_size", 17)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22))
	_lives_label.position = Vector2(10, 34)
	_lives_label.text = _hearts(3)
	_canvas.add_child(_lives_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 40)
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	_status_label.set_anchors_preset(Control.PRESET_CENTER)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_status_label.visible = false
	_canvas.add_child(_status_label)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_canvas.add_child(_overlay)

	var ol_title := Label.new()
	ol_title.name = "OverlayTitle"
	ol_title.add_theme_font_size_override("font_size", 56)
	ol_title.add_theme_color_override("font_color", Color.WHITE)
	ol_title.set_anchors_preset(Control.PRESET_CENTER)
	ol_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ol_title.offset_top = -48.0
	_overlay.add_child(ol_title)

	var ol_hint := Label.new()
	ol_hint.name = "OverlayHint"
	ol_hint.add_theme_font_size_override("font_size", 18)
	ol_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	ol_hint.set_anchors_preset(Control.PRESET_CENTER)
	ol_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ol_hint.offset_top = 32.0
	ol_hint.text = "Press  ENTER  to restart"
	_overlay.add_child(ol_hint)

func _hearts(n: int) -> String:
	var s := ""
	for i in n:
		s += "♥  "
	return s.strip_edges()

func _on_lives_changed(remaining: int) -> void:
	_lives_label.text = _hearts(remaining)

# ── Wave manager wiring ───────────────────────────────────────────────────────

func _connect_wave_manager() -> void:
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_cleared.connect(_on_wave_cleared)
	_wave_manager.countdown_tick.connect(_on_countdown_tick)
	_wave_manager.all_waves_cleared.connect(_on_all_waves_cleared)
	_wave_manager.game_lost.connect(_on_game_lost)

func _on_wave_started(num: int, total: int) -> void:
	_wave_label.text = "WAVE  %d / %d" % [num, total]
	_flash_status("WAVE  %d" % num, Color(1.0, 0.6, 0.1))
	if num > 1:
		_respawn_light_objects()

func _on_wave_cleared(num: int) -> void:
	_flash_status("WAVE  %d  CLEAR" % num, Color(0.3, 1.0, 0.4))

func _on_countdown_tick(secs_left: float) -> void:
	if not _status_label.visible:
		return
	# Let flash handle display; tick just keeps it alive if still showing

func _on_all_waves_cleared() -> void:
	_game_ended = true
	_wave_label.text = "ALL WAVES CLEARED"
	_show_overlay("VICTORY!", Color(0.3, 1.0, 0.4))

func _on_game_lost() -> void:
	_game_ended = true
	_wave_label.text = ""
	_show_overlay("GAME OVER", Color(1.0, 0.25, 0.25))

func _flash_status(text: String, color: Color) -> void:
	_status_label.text    = text
	_status_label.modulate = color
	_status_label.visible  = true
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(_status_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		_status_label.visible    = false
		_status_label.modulate.a = 1.0
	)

func _show_overlay(title: String, color: Color) -> void:
	_overlay.visible = true
	var ol_title := _overlay.get_node("OverlayTitle") as Label
	ol_title.text = title
	ol_title.add_theme_color_override("font_color", color)

# ── Restart ───────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _game_ended and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

# ── World population ──────────────────────────────────────────────────────────

func _build_spawn_markers() -> void:
	var half := GameManager.SPAWN_ZONE_HALF
	var sz   := half * 2.0

	var mat                       := StandardMaterial3D.new()
	mat.albedo_color               = Color(0.25, 0.55, 1.0, 0.65)
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled           = true
	mat.emission                   = Color(0.25, 0.55, 1.0)
	mat.emission_energy_multiplier = 0.5

	var mesh := BoxMesh.new()
	mesh.size = Vector3(sz, 0.02, sz)

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

func _respawn_light_objects() -> void:
	for i in _RESUPPLY_IDS.size():
		var pos      := _RESUPPLY_POS[i]
		var occupied := false
		for wo: Node3D in get_tree().get_nodes_in_group("world_objects"):
			if wo.global_position.distance_to(pos) < 0.8:
				occupied = true
				break
		if not occupied:
			GameManager.place_object(_RESUPPLY_IDS[i], pos)

# ── Mode label ────────────────────────────────────────────────────────────────

func _on_mode_changed(mode_name: String) -> void:
	match mode_name:
		"FREE":
			mode_label.text = "FREE  —  B: Build  |  E: Pick up  |  T: Throw  |  R: Smash"
		"BUILD":
			mode_label.text = "BUILD  —  Click to place (snaps to grid)  |  ALT+Click: free place  |  B: Cancel"
		"THROW_AIM":
			mode_label.text = "THROW AIM  —  Click to throw  |  Heavy items charge up  |  T: Cancel"
		"POWER_THROW_CHARGING":
			mode_label.text = "POWER THROW  —  Charging...  (Cannot cancel)"
		_:
			mode_label.text = mode_name
