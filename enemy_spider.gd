extends CharacterBody3D
class_name SpiderEnemy

enum State { PATROL, CHASE, ATTACK, DEAD }

@export_group("Movement")
@export var patrol_speed: float = 2.0
@export var chase_speed: float = 4.0
@export var patrol_range: float = 5.0  # How far left/right to patrol
@export var turn_wait_time: float = 1.0  # Pause at patrol ends

@export_group("Detection")
@export var detection_radius: float = 8.0
@export var attack_radius: float = 1.5
@export var attack_cooldown: float = 1.5
@export var attack_damage: int = 1

@export_group("References")
@export var detection_zone: Area3D
@export var attack_range: Area3D
@export var health_component: HealthComponent
@export var hurtbox: Area3D
@export var patrol_area: Area3D

var current_state: State = State.PATROL
var patrol_direction: int = 1  # 1 = right, -1 = left
var patrol_origin: Vector3
var turn_timer: float = 0.0
var attack_timer: float = 0.0
var player: CharacterBody3D = null
var _animation_player: AnimationPlayer = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _patrol_left_x: float
var _patrol_right_x: float
var _initial_rotation_y: float  # Preserve scene rotation
var _startup_grace: float = 0.5  # Prevent immediate state changes
var _used_patrol_area: bool = false  # Track if we used PatrolArea for bounds

func _ready() -> void:
	patrol_origin = global_position
	_initial_rotation_y = rotation.y  # Store scene rotation
	print("Spider: Starting at position ", global_position, " with rotation.y=", rotation.y)
	
	# Find AnimationPlayer in imported model
	_animation_player = _find_animation_player(self)
	if _animation_player:
		var anims = _animation_player.get_animation_list()
		#print("Spider: Found AnimationPlayer with animations: ", anims)
		# If no animations found, something is wrong
		if anims.size() == 0:
			#print("Spider: WARNING - AnimationPlayer has no animations!")
			_animation_player = null
	
	# Setup detection zone
	if detection_zone:
		# Ensure it detects the player layer (2)
		detection_zone.collision_mask = 2
		detection_zone.monitoring = true
		detection_zone.body_entered.connect(_on_detection_entered)
		detection_zone.body_exited.connect(_on_detection_exited)
	
	# Setup attack range
	if attack_range:
		attack_range.collision_mask = 2
		attack_range.monitoring = true
		attack_range.body_entered.connect(_on_attack_range_entered)
		attack_range.body_exited.connect(_on_attack_range_exited)
	
	# Setup health component
	if health_component:
		health_component.died.connect(_on_death)
	
	# Setup hurtbox
	if hurtbox:
		hurtbox.add_to_group("enemy")
		hurtbox.collision_layer = 8  # Hurtbox layer
		hurtbox.collision_mask = 0

	# Set up patrol bounds (either from PatrolArea or from patrol_range)
	_compute_patrol_bounds()
	#print("Spider: Patrol bounds X from ", snapped(_patrol_left_x, 0.01), " to ", snapped(_patrol_right_x, 0.01), " (range: ", snapped(_patrol_right_x - _patrol_left_x, 0.01), ")")
	#print("Spider: Starting position x=", snapped(global_position.x, 0.01), " direction=", patrol_direction)
	#print("Spider: Initial state=", State.keys()[current_state], " patrol_speed=", patrol_speed, " turn_wait_time=", turn_wait_time)
	#print("Spider: AnimationPlayer found: ", _animation_player != null)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0  # Zero out Y when grounded
	
	# Update timers
	if _startup_grace > 0:
		_startup_grace -= delta
	if turn_timer > 0:
		turn_timer -= delta
		# Debug turn timer
	if attack_timer > 0:
		attack_timer -= delta
	
	# State machine
	match current_state:
		State.PATROL:
			_handle_patrol(delta)
		State.CHASE:
			_handle_chase(delta)
		State.ATTACK:
			_handle_attack(delta)
	
	move_and_slide()
	

	_update_facing()
	_update_animations()

func _handle_patrol(_delta: float) -> void:
	if turn_timer > 0:
		velocity.x = 0
		velocity.z = 0
		return
	
	# Flip on walls
	if is_on_wall():
		patrol_direction *= -1
		turn_timer = turn_wait_time
		velocity.x = 0
		velocity.z = 0
		return

	# Check boundaries only if moving toward them
	if global_position.x <= _patrol_left_x and patrol_direction < 0:
		# At left bound, moving left - turn around
		patrol_direction = 1
		turn_timer = turn_wait_time
		velocity.x = 0
		velocity.z = 0
		return
	elif global_position.x >= _patrol_right_x and patrol_direction > 0:
		# At right bound, moving right - turn around
		patrol_direction = -1
		turn_timer = turn_wait_time
		velocity.x = 0
		velocity.z = 0
		return
	
	# Move in patrol direction
	velocity.x = patrol_direction * patrol_speed
	velocity.z = 0

func _handle_chase(_delta: float) -> void:
	if not player:
		current_state = State.PATROL
		return
	
	# Move toward player
	var direction = sign(player.global_position.x - global_position.x)
	velocity.x = direction * chase_speed
	velocity.z = 0

func _handle_attack(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	
	# Perform attack if cooldown ready
	if attack_timer <= 0 and player:
		_perform_attack()
		attack_timer = attack_cooldown

func _perform_attack() -> void:
	#print("Spider attacking!")
	if _animation_player and _animation_player.has_animation("SpiderArmature|Spider_Attack"):
		_animation_player.play("SpiderArmature|Spider_Attack", 0.05, 1.5)
	
	# Deal damage after animation delay
	await get_tree().create_timer(0.3).timeout
	
	# Check if player still in range
	if player and attack_range and attack_range.overlaps_body(player):
		var player_health := player.get_node_or_null("HealthComponent")
		if player_health and player_health.has_method("apply_damage"):
			player_health.apply_damage(attack_damage, self)
			print("Spider dealt %d damage to player" % attack_damage)

func _update_facing() -> void:
	# Face movement direction relative to initial rotation
	if abs(velocity.x) > 0.1:
		if velocity.x > 0:
			# Moving right: use initial rotation
			rotation.y = _initial_rotation_y
		else:
			# Moving left: flip 180° from initial
			rotation.y = _initial_rotation_y + PI

func _update_animations() -> void:
	if not _animation_player:
		return
	
	var anim_to_play = ""
	
	match current_state:
		State.DEAD:
			if _animation_player.has_animation("SpiderArmature|Spider_Death"):
				anim_to_play = "SpiderArmature|Spider_Death"
				_animation_player.play(anim_to_play, 0.1, 1.0)
		State.ATTACK:
			# Attack animation handled in _perform_attack
			pass
		State.CHASE:
			if _animation_player.has_animation("SpiderArmature|Spider_Walk"):
				anim_to_play = "SpiderArmature|Spider_Walk"
				_animation_player.play(anim_to_play, 0.12, 1.2)
		State.PATROL:
			if abs(velocity.x) > 0.1:
				if _animation_player.has_animation("SpiderArmature|Spider_Walk"):
					anim_to_play = "SpiderArmature|Spider_Walk"
					_animation_player.play(anim_to_play, 0.12, 1.0)
			else:
				# Idle when not moving
				if _animation_player.has_animation("SpiderArmature|Spider_Idle"):
					anim_to_play = "SpiderArmature|Spider_Idle"
					_animation_player.play(anim_to_play, 0.2, 1.0)

func _on_detection_entered(body: Node3D) -> void:
	if _startup_grace > 0:
		return  # Ignore during startup
	if body.name == "CharacterBody3D" and current_state != State.DEAD:
		player = body as CharacterBody3D
		current_state = State.CHASE
		#print("Spider detected player! Switching to CHASE")

func _on_detection_exited(body: Node3D) -> void:
	if body == player:
		player = null
		if current_state == State.CHASE:
			current_state = State.PATROL
		#print("Spider lost player")

func _on_attack_range_entered(body: Node3D) -> void:
	if _startup_grace > 0:
		return  # Ignore during startup
	if body == player and current_state == State.CHASE:
		current_state = State.ATTACK
		#print("Spider in attack range! Switching to ATTACK")

func _on_attack_range_exited(body: Node3D) -> void:
	if body == player and current_state == State.ATTACK:
		current_state = State.CHASE

func _on_death() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0  # Stop colliding
	collision_mask = 0
	print("Spider died!")
	
	# Play death animation then remove
	if _animation_player and _animation_player.has_animation("SpiderArmature|Spider_Death"):
		_animation_player.play("SpiderArmature|Spider_Death", 0.05, 1.0)
		await _animation_player.animation_finished
	
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null

func _compute_patrol_bounds() -> void:
	# Default to symmetric bounds around origin
	_patrol_left_x = patrol_origin.x - patrol_range
	_patrol_right_x = patrol_origin.x + patrol_range
	_used_patrol_area = false

	if not patrol_area:
		#print("Spider: No PatrolArea assigned, using patrol_range=", patrol_range)
		return
