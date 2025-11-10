extends CharacterBody3D

## Movement properties - these will be set by FormController
var speed: float = 6.0
var jump_height: float = 2.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _jump_velocity: float

## Interactables currently in range
var _nearby_interactables: Array[Interactable] = []

func _ready() -> void:
	_jump_velocity = sqrt(2.0 * gravity * jump_height)
	
	# Set collision layer for player (bit 2)
	collision_layer = 2
	collision_mask = 1  # Collide with world (bit 1)

# called by FormController when movement properties change
func recalculate_jump() -> void:
	_jump_velocity = sqrt(2.0 * gravity * jump_height)

func _physics_process(delta: float) -> void:
	
	# horizontal input (x-axis only)
	var input_x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	velocity.x = input_x * speed
	velocity.z = 0.0

	# gravity and jump
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = _jump_velocity
		else:
			velocity.y = 0.0

	move_and_slide()
	
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
