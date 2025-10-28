extends Camera3D

@export var target: NodePath
@export var deadzone_node: NodePath   # assign the DeadZone Node3D (optional)
@export var deadzone_size: Vector3 = Vector3(4.0, 2.5, 4.0) # local-space extents (width, height, depth)
@export var smooth_speed: float = 4.0  # higher = snappier
@export var max_speed: float = 10.0    # maximum camera movement speed
@export var zoom_level: float = 10.0   # default zoom level (distance from target)

var _target_ref: Node3D = null
var _deadzone_ref: Node3D = null
var _desired_position: Vector3
var _velocity: Vector3 = Vector3.ZERO
var _last_target_pos: Vector3

func _ready() -> void:
	if not target.is_empty():
		_target_ref = get_node(target)
		_last_target_pos = _target_ref.global_position
		_desired_position = global_position
		
	if not deadzone_node.is_empty():
		_deadzone_ref = get_node(deadzone_node)

func set_target(new_target: Node3D) -> void:
	_target_ref = new_target
	_last_target_pos = _target_ref.global_position

func _physics_process(delta: float) -> void:
	if not _target_ref:
		return
		
	var target_pos = _target_ref.global_position
	
	# Calculate how far the target has moved from its last position
	var target_movement = target_pos - _last_target_pos
	
	# Update desired position based on deadzone
	if _deadzone_ref:
		var local_target = _deadzone_ref.to_local(target_pos)
		var push_vector = Vector3.ZERO
		
		# Calculate push vector based on how far outside deadzone the target is
		if abs(local_target.x) > deadzone_size.x * 0.5:
			push_vector.x = local_target.x - sign(local_target.x) * deadzone_size.x * 0.5
			
		if abs(local_target.y) > deadzone_size.y * 0.5:
			push_vector.y = local_target.y - sign(local_target.y) * deadzone_size.y * 0.5
			
		if abs(local_target.z) > deadzone_size.z * 0.5:
			push_vector.z = local_target.z - sign(local_target.z) * deadzone_size.z * 0.5
			
		if push_vector != Vector3.ZERO:
			# Convert local push vector to global movement
			var global_push = _deadzone_ref.to_global(push_vector) - _deadzone_ref.global_position
			_desired_position = global_position + global_push
	
	# Smooth movement using velocity-based approach
	var direction = _desired_position - global_position
	var target_velocity = direction * smooth_speed
	
	# Limit maximum speed
	if target_velocity.length() > max_speed:
		target_velocity = target_velocity.normalized() * max_speed
	
	# Smooth acceleration
	_velocity = _velocity.lerp(target_velocity, smooth_speed * delta)
	
	# Apply movement
	global_position += _velocity * delta
	
	# Update last known position
	_last_target_pos = target_pos
	
	# Optional: Look at target (if you want the camera to always face the target)
	# look_at(target_pos)
