extends HBoxContainer

func _ready() -> void:
	for id: String in GameManager.OBJECT_DEFS:
		if id == "obj-wooden-house":
			continue
		var def: Dictionary = GameManager.OBJECT_DEFS[id]
		var btn := Button.new()
		var category: String = def.get("item_category", "crafted")
		var cat_tag: String  = "Raw material" if category == "farmable" else "Built"
		btn.text = def["name"]
		btn.tooltip_text = "%s  ·  %dkg  ·  %d dmg" % [cat_tag, def["weight"], GameManager.calc_throw_damage(def)]
		var col: Color = def.get("color", Color.WHITE)
		btn.add_theme_color_override("font_color", col.lightened(0.3))
		btn.pressed.connect(func() -> void:
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				players[0].set_build_object(id)
		)
		add_child(btn)
