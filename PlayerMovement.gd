extends CharacterBody3D

## Movement properties - these will be set by FormController
var speed: float = 6.0
var jump_height: float = 2.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_wall_climb: bool = false
var collider_radius: float = 0.5  # Used for wall detection
var collider_height: float = 2.0  # Used for ledge/mantle placement

var _jump_velocity: float

## Reference to visuals node for rotation
@onready var visuals: Node3D = $Visuals

## Animation player from current form's model
var _animation_player: AnimationPlayer = null
## Animation prefix for current form (e.g., "d_", "f_", "b_")
var _animation_prefix: String = "d_"

## Wall climbing state
var is_wall_climbing: bool = false
var _wall_normal: Vector3 = Vector3.ZERO

## Mantle (ledge climb-over) state
var is_mantling: bool = false
var _mantle_target: Vector3 = Vector3.ZERO
var mantle_speed: float = 8.0  # Units per second

## Spirit mode flags and saved collision state
var is_spirit_mode: bool = false
var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0

## Spirit bounds (spherical) centered at an origin; when enabled, spirit cannot move beyond radius
var _spirit_bounds_enabled: bool = false
var _spirit_origin: Vector3 = Vector3.ZERO
var _spirit_radius: float = 0.0

## Interactables currently in range
var _nearby_interactables: Array[Interactable] = []

## Key collection tracking
var keys_collected: int = 0

## Jump delay tracking
var _jump_delay_timer: float = 0.0
const JUMP_DELAY: float = 0.5  # 0.5 second delay

func _ready() -> void:
	_jump_velocity = sqrt(2.0 * gravity * jump_height)
	
	# Set collision layer for player (bit 2)
	collision_layer = 2
	collision_mask = 1  # Collide with world (bit 1)

# called by FormController when movement properties change
func recalculate_jump() -> void:
	_jump_velocity = sqrt(2.0 * gravity * jump_height)

## Called by FormController to set the animation player from the current form
func set_animation_player(anim_player: AnimationPlayer, anim_prefix: String = "d_") -> void:
	_animation_player = anim_player
	_animation_prefix = anim_prefix
	if _animation_player:
		print("AnimationPlayer set with prefix '%s' and animations: " % _animation_prefix, _animation_player.get_animation_list())

func _physics_process(delta: float) -> void:
	# Update jump delay timer
	if _jump_delay_timer > 0.0:
		_jump_delay_timer -= delta
	
	if is_spirit_mode:
		# Free-fly 2D movement: left/right = X, up/down = Y, ignore gravity and jump
		var input_x := float(Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
		var input_y := float(Input.get_action_strength("move_up") - Input.get_action_strength("move_down"))
		var dir2 := Vector2(input_x, input_y)
		if dir2.length() > 1.0:
			dir2 = dir2.normalized()
		var intended_velocity := Vector3(dir2.x * speed, dir2.y * speed, 0.0)

		if _spirit_bounds_enabled and _spirit_radius > 0.0 and delta > 0.0:
			var attempted_next := global_position + intended_velocity * delta
			var v := attempted_next - _spirit_origin
			if v.length() > _spirit_radius:
				# Clamp to sphere surface and set velocity accordingly
				var clamped_next := _spirit_origin + v.normalized() * _spirit_radius
				intended_velocity = (clamped_next - global_position) / max(delta, 0.000001)
		velocity = intended_velocity
	elif is_wall_climbing:
		# Wall climbing mode
		_handle_wall_climbing(delta)
	elif is_mantling:
		# Move smoothly toward mantle target without gravity
		var to_target: Vector3 = _mantle_target - global_position
		var dist := to_target.length()
		if dist < 0.02:
			is_mantling = false
			velocity = Vector3.ZERO
		else:
			var max_step := mantle_speed
			var move_v := to_target.normalized() * max_step
			# Don't overshoot
			if max_step * delta > dist:
				move_v = to_target / max(delta, 0.000001)
			velocity = move_v
	else:
		# Normal grounded/airborne movement (platformer style)
		_handle_normal_movement(delta)

	move_and_slide()
	
	# Check for wall climbing opportunity after moving (only if not in spirit mode)
	if not is_spirit_mode and can_wall_climb and not is_wall_climbing:
		_check_for_wall()
	
	# Update animations based on movement state
	_update_animations()


func _handle_normal_movement(delta: float) -> void:
	# horizontal input (x-axis only)
	var input_x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	velocity.x = input_x * speed
	velocity.z = 0.0
	
	# Instant turn to face movement direction (rotate visuals only)
	if input_x > 0:
		rotation.y = 0  # Face right
	elif input_x < 0:
		rotation.y = PI  # Face left (180 degrees)

	# gravity and jump
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			# Start jump delay timer
			_jump_delay_timer = JUMP_DELAY
		
		# Execute jump after delay
		if _jump_delay_timer > 0.0 and _jump_delay_timer <= JUMP_DELAY - 0.016:  # After at least one frame
			if _jump_delay_timer <= JUMP_DELAY * 0.5:  # Halfway through delay
				velocity.y = _jump_velocity
				_jump_delay_timer = 0.0  # Reset timer
		elif _jump_delay_timer <= 0.0:
			velocity.y = 0.0


func _handle_wall_climbing(delta: float) -> void:
	# Vertical movement on wall (move_up/move_down)
	var input_y := int(Input.is_action_pressed("move_up")) - int(Input.is_action_pressed("move_down"))
	velocity.y = input_y * speed * 0.8 
	
	# Horizontal movement along wall (limited)
	var input_x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	velocity.x = input_x * speed * 0.3  # Very limited horizontal movement
	velocity.z = 0.0
	
	# Jump off wall
	if Input.is_action_just_pressed("jump"):
		# Push away from wall
		velocity = _wall_normal * speed * 1.2  # Push outward
		velocity.y = _jump_velocity * 0.8  # Half jump height
		is_wall_climbing = false
		print("Bear: Jumped off wall!")
		return
	
	# Check if still touching wall
	if not _is_touching_wall():
		# Try to mantle over ledge before letting go
		if _try_start_mantle():
			is_wall_climbing = false
			print("Bear: Mantling over ledge")
			return
		else:
			is_wall_climbing = false
			print("Bear: Left wall")


func _check_for_wall() -> void:
	# Only check if in the air or just jumped
	if is_on_floor():
		return
	
	# Use a raycast to detect walls to the left and right
	var space_state := get_world_3d().direct_space_state
	var player_pos: Vector3 = global_position
	
	# Check both left and right sides
	var directions: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT]
	
	for direction in directions:
		var ray_start: Vector3 = player_pos
		var ray_end: Vector3 = player_pos + direction * (collider_radius + 0.2)
		
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collision_mask = 1  # World layer
		query.exclude = [self]
		
		var result := space_state.intersect_ray(query)
		
		if result:
			var hit_normal: Vector3 = result.normal
			# Check if it's actually a wall (roughly vertical surface)
			if abs(hit_normal.y) < 0.3:  # Not floor or ceiling
				is_wall_climbing = true
				_wall_normal = hit_normal
				velocity.y = 0  # Stop falling when attaching to wall
				print("Bear: Grabbed wall! (Normal: %s)" % hit_normal)
				return


func _is_touching_wall() -> bool:
	var space_state := get_world_3d().direct_space_state
	var player_pos: Vector3 = global_position
	
	# Check in the direction opposite to wall normal
	var check_direction: Vector3 = -_wall_normal
	var ray_start: Vector3 = player_pos
	var ray_end: Vector3 = player_pos + check_direction * (collider_radius + 0.3)
	
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1
	query.exclude = [self]
	
	var result := space_state.intersect_ray(query)
	
	if result:
		var hit_normal: Vector3 = result.normal
		# Verify it's still a wall
		if abs(hit_normal.y) < 0.3:
			print("Bear: Still on wall")
			return true
	
	return false

## Try to detect a ledge above and in front, and begin mantle if found
func _try_start_mantle() -> bool:
	var space_state := get_world_3d().direct_space_state
	# Forward is into the wall; wall normal points away from wall
	var forward: Vector3 = -_wall_normal
	
	# Probe point above the player and slightly into the wall to find top surface
	var probe_up: float = collider_height  # how high to check for a top
	var probe_forward: float = collider_radius + 0.25
	var top_probe_start: Vector3 = global_position + Vector3.UP * probe_up + forward * probe_forward
	var top_probe_end: Vector3 = top_probe_start + Vector3.DOWN * (probe_up + 1.0)

	var down_query := PhysicsRayQueryParameters3D.create(top_probe_start, top_probe_end)
	down_query.collision_mask = 1
	down_query.exclude = [self]
	var down_hit := space_state.intersect_ray(down_query)

	if down_hit:
		var n: Vector3 = down_hit.normal
		# Ensure it's a walkable top (fairly horizontal)
		if n.y > 0.6:
			# Compute a target on top, offset slightly away from the ledge using wall normal
			var top_point: Vector3 = down_hit.position
			var center_height := collider_radius + (collider_height * 0.5)
			var land_point: Vector3 = top_point + _wall_normal * (collider_radius + 0.05)
			land_point.y = top_point.y + center_height
			land_point.z = global_position.z  # keep constrained plane

			# Optional: simple headroom check (ray up from landing)
			var head_start: Vector3 = land_point
			var head_end: Vector3 = head_start + Vector3.UP * (collider_height * 0.6)
			var up_query := PhysicsRayQueryParameters3D.create(head_start, head_end)
			up_query.collision_mask = 1
			up_query.exclude = [self]
			var up_hit := space_state.intersect_ray(up_query)
			if up_hit:
				# Blocked overhead; cannot mantle
				return false

			_mantle_target = land_point
			is_mantling = true
			print("Bear: Ledge detected, starting mantle to %s" % _mantle_target)
			return true

	return false
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact_key"):
		interact()


## Called when player enters an interactable's Area3D
func _register_interactable(interactable: Interactable) -> void:
	if not _nearby_interactables.has(interactable):
		_nearby_interactables.append(interactable)
		print("Entered interact zone: %s" % interactable.interactable_name)


## Called when player exits an interactable's Area3D
func _unregister_interactable(interactable: Interactable) -> void:
	_nearby_interactables.erase(interactable)
	print("Left interact zone: %s" % interactable.interactable_name)


## Interact with the nearest interactable (if any)
func interact() -> void:
	if _nearby_interactables.is_empty():
		print("Nothing to interact with")
		return
	
	# Get the first interactable in range (you could sort by distance if needed)
	var target := _nearby_interactables[0]
	target.interact(self)

## Toggle spirit mode from abilities/other systems
func set_spirit_mode(enabled: bool) -> void:
	is_spirit_mode = enabled
	if enabled:
		# Save and clear collisions so spirit can pass through world (optional). Adjust if you want collisions.
		_saved_collision_layer = collision_layer
		_saved_collision_mask = collision_mask
		collision_layer = 8  # Spirit layer (different from player layer 2)
		collision_mask = 0   # Don't collide with anything
		velocity = Vector3.ZERO
	else:
		# Restore collisions and reset velocity
		collision_layer = _saved_collision_layer
		collision_mask = _saved_collision_mask
		velocity = Vector3.ZERO
		# Clear bounds by default when leaving spirit mode
		clear_spirit_bounds()

## Configure spherical bounds for spirit movement
func set_spirit_bounds(origin: Vector3, radius: float) -> void:
	_spirit_origin = origin
	_spirit_radius = max(0.0, radius)
	_spirit_bounds_enabled = _spirit_radius > 0.0

func clear_spirit_bounds() -> void:
	_spirit_bounds_enabled = false
	_spirit_radius = 0.0

## Collect a key
func collect_key() -> void:
	keys_collected += 1
	print("Player collected key! Total keys: %d" % keys_collected)

## Get the number of keys collected
func get_key_count() -> int:
	return keys_collected

## Play a specific ability animation (called from abilities script)
func play_ability_animation(anim_name: String, speed: float = 1.0) -> void:
	if not _animation_player:
		return
	
	var full_anim_name := _animation_prefix + anim_name
	if _animation_player.has_animation(full_anim_name):
		_animation_player.play(full_anim_name)
		_animation_player.speed_scale = speed
		print("Playing ability animation: %s" % full_anim_name)
	else:
		print("Warning: Animation '%s' not found" % full_anim_name)

## Update which animation is playing based on current movement state
func _update_animations() -> void:
	if not _animation_player:
		return
	
	# Build animation names with prefix
	var anim_idle := _animation_prefix + "idle"
	var anim_walk := _animation_prefix + "walk"
	var anim_jump := _animation_prefix + "jump"
	var anim_fall := _animation_prefix + "fall"
	var anim_climb := _animation_prefix + "climb"
	var anim_wall_pose := _animation_prefix + "wall_pose"
	var anim_wallclimb := _animation_prefix + "wallclimb"
	
	# Determine which animation should play
	if is_spirit_mode:
		if _animation_player.current_animation != anim_idle:
			_animation_player.play(anim_idle)
			_animation_player.speed_scale = 1.0
	elif is_wall_climbing:
		# Check if player is moving on wall (climbing) or just holding
		var is_moving: bool = abs(velocity.x) > 0.1 or abs(velocity.y) > 0.1
		if is_moving:
			# Moving on wall - use wallclimb animation
			if _animation_player.has_animation(anim_wallclimb):
				if _animation_player.current_animation != anim_wallclimb:
					_animation_player.play(anim_wallclimb)
					_animation_player.speed_scale = 5.0
			else:
				# Fallback to regular climb
				if _animation_player.current_animation != anim_climb:
					_animation_player.play(anim_climb)
					_animation_player.speed_scale = 1.0
		else:
			# Holding on wall - use wall_pose animation
			if _animation_player.has_animation(anim_wall_pose):
				if _animation_player.current_animation != anim_wall_pose:
					_animation_player.play(anim_wall_pose)
					_animation_player.speed_scale = 1.0
			else:
				# Fallback to regular climb
				if _animation_player.current_animation != anim_climb:
					_animation_player.play(anim_climb)
					_animation_player.speed_scale = 1.0
	elif is_mantling:
		if _animation_player.current_animation != anim_climb:
			_animation_player.play(anim_climb)
			_animation_player.speed_scale = 2.0
	elif not is_on_floor():
		# In air - check direction
		if velocity.y > 0.5:
			if _animation_player.current_animation != anim_jump:
				_animation_player.play(anim_jump)
				_animation_player.speed_scale = 5.0
		else:
			if _animation_player.current_animation != anim_fall:
				_animation_player.play(anim_fall)
				_animation_player.speed_scale = 1.0
	else:
		# On ground - walk or idle
		if _jump_delay_timer > 0.0:
			if _animation_player.current_animation != anim_jump:
				_animation_player.play(anim_jump)
				_animation_player.speed_scale = 4.0
		elif abs(velocity.x) > 0.1:
			if _animation_player.current_animation != anim_walk:
				_animation_player.play(anim_walk)
				_animation_player.speed_scale = 7.0 
		else:
			if _animation_player.current_animation != anim_idle:
				_animation_player.play(anim_idle)
				_animation_player.speed_scale = 1.0
