extends Node3D

const GRID_SIZE  := 1.0
const EXTENT     := 24       # cells in each direction from origin
const LINE_COLOR := Color(0.35, 0.55, 0.35, 0.35)

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA

	var im    := ImmediateMesh.new()
	var limit := float(EXTENT) * GRID_SIZE

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in range(-EXTENT, EXTENT + 1):
		var c := float(i) * GRID_SIZE
		# Lines running along Z
		im.surface_set_color(LINE_COLOR)
		im.surface_add_vertex(Vector3(c, 0.01, -limit))
		im.surface_set_color(LINE_COLOR)
		im.surface_add_vertex(Vector3(c, 0.01,  limit))
		# Lines running along X
		im.surface_set_color(LINE_COLOR)
		im.surface_add_vertex(Vector3(-limit, 0.01, c))
		im.surface_set_color(LINE_COLOR)
		im.surface_add_vertex(Vector3( limit, 0.01, c))
	im.surface_end()

	var mi         := MeshInstance3D.new()
	mi.mesh         = im
	mi.material_override = mat
	mi.cast_shadow  = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
