extends Camera3D
## simple 2D platformer camera that follows the player on x and y axis
@export var follow_target: Node3D  # The player to follow
@export var follow_smoothing: float = 0.1  # Lower = smoother (0 = instant)
@export var fixed_z_distance: float = 10.0  # Distance from the 2D plane

@export_group("Camera Bounds")
@export var use_bounds: bool = true
@export var bounds_min: Vector2 = Vector2(-20, 0)
@export var bounds_max: Vector2 = Vector2(20, 25)

## Instantly snap camera to target position (no smoothing)
func snap_to_target() -> void:
	if not follow_target:
		return
	var target_pos := follow_target.global_position
	global_position = Vector3(target_pos.x, target_pos.y, target_pos.z + fixed_z_distance)

func _physics_process(delta: float) -> void:
	if not follow_target:
		return
	
	# get player target position
	var target_pos := follow_target.global_position
	
	# calculates the desired x and y position
	var desired_x := target_pos.x
	var desired_y := target_pos.y
	
	# Apply bounds if enabled
	#if use_bounds:
		#desired_x = clamp(desired_x, bounds_min.x, bounds_max.x)
		#desired_y = clamp(desired_y, bounds_min.y, bounds_max.y)
	
	# how smooth the camera moves to the player
	if follow_smoothing > 0.0:
		var current := global_position
		var target := Vector3(desired_x, desired_y, target_pos.z + fixed_z_distance)
		global_position = current.lerp(target, 1.0 - pow(follow_smoothing, delta))
	else:
		global_position = Vector3(desired_x, desired_y, target_pos.z + fixed_z_distance)
