extends EditorNode3DGizmoPlugin

const ProtoRamp := preload("proto_ramp.gd")
var camera_position := Vector3(0, 0, 0)
var width_gizmo_id: int
var depth_gizmo_id: int
var height_gizmo_id: int

func _has_gizmo(node) -> bool:
	# Generate a random id for each gizmo
	width_gizmo_id = randi_range(0, 1_000_000)
	depth_gizmo_id = randi_range(0, 1_000_000)
	height_gizmo_id = randi_range(0, 1_000_000)
	return node is ProtoRamp

func _get_gizmo_name() -> String:
	return "ProtoRamp"

func _init() -> void:
	create_material("main", Color(1, 0, 0))
	create_handle_material("handles")

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var node: ProtoRamp = gizmo.get_node_3d()
	if !node.anchor_changed.is_connected(gizmo.get_node_3d().update_gizmos):
		node.anchor_changed.connect(gizmo.get_node_3d().update_gizmos)

	var true_depth: float = node.get_true_depth()
	var true_height: float = node.get_true_height()
	var anchor_offset: Vector3 = node.get_anchor_offset(node.anchor)
	var depth_gizmo_position := Vector3(0, true_height / 2, true_depth) + anchor_offset
	var width_gizmo_position := Vector3(node.width / 2, true_height / 2, true_depth / 2) + anchor_offset
	var height_gizmo_position := Vector3(0, true_height, true_depth / 2) + anchor_offset

	# When on the left, width gizmo is on the right
	# When in the back (top, base), depth gizmo is on the front
	# When on the top, height gizmo is on the bottom
	match node.anchor:
		ProtoRamp.Anchor.BOTTOM_LEFT:
			width_gizmo_position.x = -node.width
		ProtoRamp.Anchor.TOP_LEFT:
			width_gizmo_position.x = -node.width
			depth_gizmo_position.z = -true_depth
			height_gizmo_position.y = -true_height
		ProtoRamp.Anchor.BASE_LEFT:
			width_gizmo_position.x = -node.width
			depth_gizmo_position.z = -true_depth
		ProtoRamp.Anchor.BASE_CENTER:
			depth_gizmo_position.z = -true_depth
		ProtoRamp.Anchor.BASE_RIGHT:
			depth_gizmo_position.z = -true_depth
		ProtoRamp.Anchor.TOP_RIGHT:
			depth_gizmo_position.z = -true_depth
			height_gizmo_position.y = -true_height
		ProtoRamp.Anchor.TOP_CENTER:
			depth_gizmo_position.z = -true_depth
			height_gizmo_position.y = -true_height

	var handles = PackedVector3Array()
	handles.push_back(depth_gizmo_position)
	handles.push_back(width_gizmo_position)
	handles.push_back(height_gizmo_position)

	gizmo.add_handles(handles, get_material("handles", gizmo), [depth_gizmo_id, width_gizmo_id, height_gizmo_id])

	# Add collision triangles by generating TriangleMesh from node mesh
	gizmo.add_collision_triangles(node.get_meshes()[1].generate_triangle_mesh())

func _set_handle(
	gizmo: EditorNode3DGizmo,
	handle_id: int,
	secondary: bool,
	camera: Camera3D,
	screen_pos: Vector2) -> void:
	match handle_id:
		depth_gizmo_id:
			_set_depth_handle(gizmo, camera, screen_pos)
		width_gizmo_id:
			_set_width_handle(gizmo, camera, screen_pos)
		height_gizmo_id:
			_set_height_handle(gizmo, camera, screen_pos)

	gizmo.get_node_3d().update_gizmos()

## Calculates plane based on the gizmo's position facing the camera
## Returns offset based on the intersection of the ray from the camera to the cursor hitting the plane
func _get_handle_offset(
	gizmo: EditorNode3DGizmo,
	camera: Camera3D,
	screen_pos: Vector2,
	gizmo_position: Vector3,
	offset_axis: Vector3) -> Vector3:
	var node: Node3D = gizmo.get_node_3d()
	var quat_axis: Vector3 = node.quaternion.get_axis() if node.quaternion.get_axis().is_normalized() else Vector3.UP
	var plane: Plane = _get_camera_oriented_plane(camera.position, gizmo_position, offset_axis, gizmo)
	var offset: Vector3 = (plane.intersects_ray(camera.position, camera.project_position(screen_pos, 1.0) - camera.position) - node.position).rotated(quat_axis, -node.quaternion.get_angle())
	return offset

func _set_width_handle(
	gizmo: EditorNode3DGizmo,
	camera: Camera3D,
	screen_pos: Vector2):
	var node: ProtoRamp = gizmo.get_node_3d()
	var gizmo_position := Vector3(node.width / 2, node.get_true_height() / 2, node.get_true_depth() / 2) + node.get_anchor_offset(node.anchor)
	var offset: float = _get_handle_offset(gizmo, camera, screen_pos, gizmo_position, Vector3(1, 0, 0)).x
	# If anchor is on the left, offset is negative
	# If anchor is not centered, offset is divided by 2
	match node.anchor:
		ProtoRamp.Anchor.BOTTOM_LEFT:
			offset = -offset / 2
		ProtoRamp.Anchor.TOP_LEFT:
			offset = -offset / 2
		ProtoRamp.Anchor.BASE_LEFT:
			offset = -offset / 2
		ProtoRamp.Anchor.BOTTOM_RIGHT:
			offset = offset / 2
		ProtoRamp.Anchor.TOP_RIGHT:
			offset = offset / 2
		ProtoRamp.Anchor.BASE_RIGHT:
			offset = offset / 2
	node.width = offset * 2

func _set_depth_handle(
	gizmo: EditorNode3DGizmo,
	camera: Camera3D,
	screen_pos: Vector2):
	var node: ProtoRamp = gizmo.get_node_3d()
	var gizmo_position := Vector3(0, node.get_true_height() / 2, node.get_true_depth()) + node.get_anchor_offset(node.anchor)
	var offset: float = _get_handle_offset(gizmo, camera, screen_pos, gizmo_position, Vector3(0, 0, 1)).z
	if node.calculation == ProtoRamp.Calculation.STEP_DIMENSIONS and node.type == ProtoRamp.Type.STAIRCASE:
		offset = offset / node.steps
	# If anchor is on the back, offset is negative
	match node.anchor:
		ProtoRamp.Anchor.BASE_CENTER:
			offset = -offset
		ProtoRamp.Anchor.BASE_RIGHT:
			offset = -offset
		ProtoRamp.Anchor.BASE_LEFT:
			offset = -offset
		ProtoRamp.Anchor.TOP_CENTER:
			offset = -offset
		ProtoRamp.Anchor.TOP_RIGHT:
			offset = -offset
		ProtoRamp.Anchor.TOP_LEFT:
			offset = -offset
	node.depth = offset

func _set_height_handle(
	gizmo: EditorNode3DGizmo,
	camera: Camera3D,
	screen_pos: Vector2):
	var node: ProtoRamp = gizmo.get_node_3d()
	var gizmo_position := Vector3(0, node.get_true_height(), node.get_true_depth() / 2) + node.get_anchor_offset(node.anchor)
	var offset: float = _get_handle_offset(gizmo, camera, screen_pos, gizmo_position, Vector3(0, 1, 0)).y
	# If anchor is TOP, offset is negative
	if node.calculation == ProtoRamp.Calculation.STEP_DIMENSIONS and node.type == ProtoRamp.Type.STAIRCASE:
		offset = offset / node.steps
	match node.anchor:
		ProtoRamp.Anchor.TOP_LEFT:
			offset = -offset
		ProtoRamp.Anchor.TOP_CENTER:
			offset = -offset
		ProtoRamp.Anchor.TOP_RIGHT:
			offset = -offset
	node.height = offset

## Gets the plane along [param gizmo_axis] going through [param gizmo_position] and facing towards the [param camera_position]
func _get_camera_oriented_plane(
	camera_position: Vector3,
	gizmo_position: Vector3,
	gizmo_axis: Vector3,
	gizmo: EditorNode3DGizmo) -> Plane:
	# camera: Camera to orient the plane to
	# gizmo_position: gizmo's current position in the world
	# gizmo_axis: axis the gizmo is moving along
	var node := gizmo.get_node_3d()
	# Node's transformation
	var quaternion := node.quaternion # Rotation in degrees for each axis
	var quat_axis: Vector3 = quaternion.get_axis() if quaternion.get_axis().is_normalized() else Vector3.UP

	# Transform the local point
	var local_gizmo_position: Vector3 = gizmo_position
	var global_gizmo_position: Vector3 = gizmo_position.rotated(quat_axis, quaternion.get_angle()) * node.scale + node.position
	var global_gizmo_axis: Vector3 = gizmo_axis.rotated(quat_axis, quaternion.get_angle()).normalized()
	var closest_point_to_camera: Vector3 = _get_closest_point_on_line(global_gizmo_position, global_gizmo_axis, camera_position)
	var closest_point_to_camera_difference: Vector3 = closest_point_to_camera - camera_position
	var parallel_to_gizmo_dir: Vector3 = closest_point_to_camera - global_gizmo_position
	var perpendicular_to_gizmo_dir: Vector3 = parallel_to_gizmo_dir.cross(closest_point_to_camera_difference).normalized()

	# Transform 3 points to global space
	var x: Vector3 = global_gizmo_position
	var y: Vector3 = global_gizmo_position + global_gizmo_axis
	var z: Vector3 = global_gizmo_position + perpendicular_to_gizmo_dir
	var plane := Plane(x, y, z)

	# Drawing
	var lines := PackedVector3Array()
	var debug_gizmo_position: Vector3 = gizmo_position + Vector3(0, 0, 1)

	# Plane normal
	lines.push_back(debug_gizmo_position)
	lines.push_back(debug_gizmo_position + plane.normal)

	# Camera perpendicular
	lines.push_back(debug_gizmo_position)
	lines.push_back(debug_gizmo_position + perpendicular_to_gizmo_dir.normalized())

	# Gizmo axis
	lines.push_back(debug_gizmo_position)
	lines.push_back(debug_gizmo_position + gizmo_axis)
	gizmo.add_lines(lines, get_material("main", gizmo), false)

	return plane

## [param point_in_line] is a point on the line
## [param line_dir] is the direction of the line
## [param point] is the point to find the closest point on the line to
func _get_closest_point_on_line(
	point_in_line: Vector3,
	line_dir: Vector3,
	point: Vector3) -> Vector3:
	var A := point_in_line
	var B := point_in_line + line_dir  # This can be any other point in the direction of the line
	var AP := point - A
	var AB := B - A

	var t := AP.dot(AB) / AB.dot(AB)
	var closest_point := A + t * AB

	return closest_point
