extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_height: float = 2.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


var _jump_velocity: float

func _ready() -> void:
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
