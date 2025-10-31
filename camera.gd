extends Camera3D

@export var forms_node: NodePath  # Reference to the Forms node
@export var smooth_speed: float = 4.0  # general smoothing factor (used when recentering)
@export var max_speed: float = 10.0    # maximum camera movement speed

# Deadzone (in camera-local X/Y units)
@export var deadzone_size: Vector2 = Vector2(2.0, 1.0) # width (x), height (y)
@export var deadzone_offset: Vector2 = Vector2(0, 0)  # offset in camera-local coords
@export var deadzone_smooth: float = 8.0             # how fast camera moves to satisfy deadzone

@export var follow_z: bool = false  # if true, camera will follow target Z as well
@export var debug_draw_deadzone: bool = false # show a visible box representing the deadzone for tuning
@export var player_padding: Vector2 = Vector2(0.5, 0.5)  # Extra padding around player bounds (x, y)

var _target_ref: Node3D = null
var _velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Initialize target reference if possible
	if not forms_node.is_empty():
		var forms_ref = get_node(forms_node) as Node3D
		_target_ref = forms_ref.characters[forms_ref.current_character_index]

func _physics_process(delta: float) -> void:
	# update target reference each frame (in case forms node swaps characters)
	if not forms_node.is_empty():
		var forms_ref = get_node(forms_node) as Node3D
		_target_ref = forms_ref.characters[forms_ref.current_character_index]

	if not _target_ref:
		return

	# Always use exported deadzone values (no deadzone_node logic)
	var dz_size: Vector2 = deadzone_size
	var dz_offset: Vector2 = deadzone_offset

	# Get player bounds in camera-local space
	var target_local: Vector3 = to_local(_target_ref.global_position)
	
	# Try to get visual bounds from the target (check for VisualInstance3D children or AABB)
	var player_half_size := Vector2(0.0, 0.0)
	
	# Look for MeshInstance3D or other visual children to get bounds
	for child in _target_ref.get_children():
		if child is VisualInstance3D:
			var vi = child as VisualInstance3D
			var aabb = vi.get_aabb()
			# Transform AABB to account for child's local transform
			var transformed_aabb = aabb
			# Get the maximum extents in X and Y
			var extents = transformed_aabb.size * child.scale
			player_half_size.x = max(player_half_size.x, extents.x * 0.5)
			player_half_size.y = max(player_half_size.y, extents.y * 0.5)
	
	# If no visual bounds found, use the target's scale as a fallback estimate
	if player_half_size.length() < 0.01:
		player_half_size = Vector2(_target_ref.scale.x * 0.5, _target_ref.scale.y * 0.5)
	
	# Add user-defined padding
	player_half_size += player_padding

	# Deadzone bounds in local space (accounting for player size)
	# The player's bounds need to fit entirely within the deadzone
	var half = dz_size * 0.5
	var min_b = dz_offset - half + player_half_size  # Shrink deadzone by player size
	var max_b = dz_offset + half - player_half_size

	# Compute local shift required to bring target to nearest edge (if outside)
	var shift_local = Vector3.ZERO
	if target_local.x < min_b.x:
		shift_local.x = target_local.x - min_b.x
	elif target_local.x > max_b.x:
		shift_local.x = target_local.x - max_b.x

	if target_local.y < min_b.y:
		shift_local.y = target_local.y - min_b.y
	elif target_local.y > max_b.y:
		shift_local.y = target_local.y - max_b.y

	# We don't move along camera local Z with the deadzone; maintain current Z unless follow_z
	shift_local.z = 0

	# If nothing to do, decay velocity smoothly and return
	if shift_local.x == 0 and shift_local.y == 0:
		# decay velocity to zero for a smooth stop
		_velocity = _velocity.lerp(Vector3.ZERO, clamp(deadzone_smooth * delta, 0.0, 1.0))
		global_position += _velocity * delta
		_draw_deadzone(dz_size, dz_offset)
		return

	# Convert local shift to world-space and compute desired camera position
	var shift_world: Vector3 = global_transform.basis * shift_local
	var desired_pos: Vector3 = global_position + shift_world

	# Keep Z if requested
	if not follow_z:
		desired_pos.z = global_position.z

	# Compute desired velocity then apply smoothing / clamping
	var desired_velocity: Vector3 = (desired_pos - global_position) * deadzone_smooth
	if desired_velocity.length() > max_speed:
		desired_velocity = desired_velocity.normalized() * max_speed

	_velocity = _velocity.lerp(desired_velocity, clamp(deadzone_smooth * delta, 0.0, 1.0))
	# Prevent overshooting the desired position in one frame — clamp step to remaining distance
	var step: Vector3 = _velocity * delta
	var to_target: Vector3 = desired_pos - global_position
	if to_target.length() > 0.00001:
		# If step would move past desired_pos, clamp it
		if step.length() > to_target.length() and step.dot(to_target) > 0:
			step = to_target

	global_position += step
	# Keep internal velocity consistent with actual movement (use step/delta)
	_velocity = step / max(delta, 0.00001)

	_draw_deadzone(dz_size, dz_offset)

# Draws a visible deadzone box for debugging/tuning
func _draw_deadzone(dz_size: Vector2, dz_offset: Vector2) -> void:
	if debug_draw_deadzone:
		# Find or create the visualization in the scene root (so camera can see it)
		var root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
		var vis := root.get_node_or_null("_DeadzoneVis") as MeshInstance3D
		if not vis:
			vis = MeshInstance3D.new()
			vis.name = "_DeadzoneVis"
			vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			vis.layers = 1  # Ensure it's on the right render layer
			# Create a simple material so it's visible
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 1.0, 0.0, 0.5)  # Bright yellow, semi-transparent
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.no_depth_test = true  # Always visible, not occluded
			vis.material_override = mat
			root.add_child(vis)
			print("Created deadzone visualization box")
		
		# Update the mesh every frame to ensure it's set
		if not vis.mesh or vis.mesh.get_class() != "BoxMesh":
			var box := BoxMesh.new()
			box.size = Vector3(dz_size.x, dz_size.y, 0.1)
			vis.mesh = box
		
		# Position the box slightly in front of the camera (negative Z in camera space)
		# For orthographic, we want it at a Z that's between camera and the scene
		var local_box_pos = Vector3(dz_offset.x, dz_offset.y, -1.0)  # 1 unit in front
		vis.global_position = global_position + global_transform.basis * local_box_pos
		vis.global_rotation = global_rotation
		vis.visible = true
	else:
		# Clean up visualization if debug is disabled
		var root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
		var vis2 := root.get_node_or_null("_DeadzoneVis")
		if vis2:
			vis2.queue_free()
