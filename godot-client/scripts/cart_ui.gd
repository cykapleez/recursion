extends PanelContainer

# Cart HUD — shows contents, weight, and throw buttons.
# Attach to a PanelContainer in the CanvasLayer.
# Scene needs: PanelContainer → VBoxContainer (name: "ItemList")

@onready var item_list: VBoxContainer = $ItemList

func _ready() -> void:
	GameManager.cart_changed.connect(_on_cart_changed)
	GameManager.mode_changed.connect(_on_mode_changed)
	_on_cart_changed(GameManager.cart_items)

func _on_cart_changed(items: Array) -> void:
	for child in item_list.get_children():
		child.queue_free()

	if items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Cart empty"
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_list.add_child(empty_lbl)
	else:
		for i in range(items.size()):
			_add_item_row(i, items[i])
	_add_weight_bar()

func _add_item_row(slot: int, item: Dictionary) -> void:
	var def: Dictionary = GameManager.OBJECT_DEFS.get(item.object_id, {})
	var damage := GameManager.calc_throw_damage(def)
	var is_farmable: bool = def.get("item_category", "crafted") == "farmable"

	var row := HBoxContainer.new()

	var swatch := ColorRect.new()
	swatch.color = def.get("color", Color.WHITE)
	swatch.custom_minimum_size = Vector2(14, 14)
	row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = def.get("name", item.object_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(name_lbl)

	var cat_lbl := Label.new()
	if is_farmable:
		cat_lbl.text = " RAW"
		cat_lbl.add_theme_color_override("font_color", Color(0.55, 0.80, 0.45))
	else:
		cat_lbl.text = " BUILT"
		cat_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	cat_lbl.add_theme_font_size_override("font_size", 9)
	row.add_child(cat_lbl)

	var dmg_lbl := Label.new()
	dmg_lbl.text = "  %ddmg" % damage
	if is_farmable:
		dmg_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.55))
	else:
		dmg_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	dmg_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(dmg_lbl)

	var throw_btn := Button.new()
	throw_btn.text = "T"
	throw_btn.tooltip_text = "Enter throw aim mode for this item (or press T)"
	throw_btn.custom_minimum_size = Vector2(24, 0)
	throw_btn.pressed.connect(func() -> void: _request_throw(slot))
	row.add_child(throw_btn)

	item_list.add_child(row)

func _add_weight_bar() -> void:
	var sep := HSeparator.new()
	item_list.add_child(sep)

	var w_lbl := Label.new()
	var cur := GameManager.cart_current_weight
	var max_w := GameManager.cart_max_weight
	var overloaded := GameManager.is_overloaded()
	w_lbl.text = "Weight: %d / %d" % [cur, max_w]
	if overloaded:
		w_lbl.text += "  OVERLOADED (-35% speed)"
		w_lbl.add_theme_color_override("font_color", Color.RED)
	else:
		w_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	w_lbl.add_theme_font_size_override("font_size", 10)
	item_list.add_child(w_lbl)

func _request_throw(slot: int) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].set_throw_slot(slot)

func _on_mode_changed(mode_name: String) -> void:
	# Visual feedback: highlight panel when in throw aim mode
	var in_throw := mode_name == "THROW_AIM"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.05, 0.05, 0.9) if in_throw else Color(0.1, 0.1, 0.1, 0.85)
	style.border_color = Color(1.0, 0.3, 0.0) if in_throw else Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2 if in_throw else 1)
	add_theme_stylebox_override("panel", style)
