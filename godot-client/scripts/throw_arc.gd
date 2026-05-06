extends Node3D

# Draws a parabolic arc from launch point to throw target using ImmediateMesh.
# This node lives at World origin so local space == world space.

const ARC_STEPS  := 24
const PEAK_RATIO := 0.4

var _im:        ImmediateMesh
var _mat:       StandardMaterial3D
var _mesh_inst: MeshInstance3D

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true

	_im = ImmediateMesh.new()

	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.mesh             = _im
	_mesh_inst.material_override = _mat
	_mesh_inst.cast_shadow      = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_inst)

	visible = false

func show_arc(from: Vector3, to: Vector3) -> void:
	visible = true
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _mat)
	var pts := _arc_points(from, to, ARC_STEPS)
	for i in range(pts.size()):
		var t := float(i) / float(pts.size() - 1)
		_im.surface_set_color(Color(1.0, lerpf(0.9, 0.2, t), 0.0, lerpf(1.0, 0.5, t)))
		_im.surface_add_vertex(pts[i])
	_im.surface_end()

	# Impact ring — small circle of lines at the target
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _mat)
	var ring_pts := 16
	for i in range(ring_pts + 1):
		var angle := float(i) / float(ring_pts) * TAU
		_im.surface_set_color(Color(1.0, 0.2, 0.0, 0.7))
		_im.surface_add_vertex(to + Vector3(cos(angle) * 0.4, 0.05, sin(angle) * 0.4))
	_im.surface_end()

func hide_arc() -> void:
	visible = false
	_im.clear_surfaces()

func _arc_points(from: Vector3, to: Vector3, steps: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var dist := from.distance_to(to)
	var peak := dist * PEAK_RATIO
	for i in range(steps + 1):
		var t   := float(i) / float(steps)
		var pos := from.lerp(to, t)
		pos.y   += peak * 4.0 * t * (1.0 - t)
		pts.append(pos)
	return pts
