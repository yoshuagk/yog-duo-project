extends Node3D

# Array to store different player characters
var characters: Array = []
var current_character_index: int = 0

@export var character1: NodePath
@export var character2: NodePath
@export var character3: NodePath
# New: exported node used as spawn / checkpoint (Position3D / Marker3D / Node3D)
@export var start_node: NodePath
var _start_ref: Node3D = null

func _ready() -> void:
	# cache start node if provided
	if not start_node.is_empty():
		_start_ref = get_node(start_node) as Node3D
	# Get the character nodes and store them in the array
	if not character1.is_empty():
		characters.append(get_node(character1))
	if not character2.is_empty():
		characters.append(get_node(character2))
	if not character3.is_empty():
		characters.append(get_node(character3))
	
	# Initialize characters (place at start node if present, hide all except the first one)
	for i in range(characters.size()):
		# place at start position
		if _start_ref:
			characters[i].global_position = _start_ref.global_position

		if i != current_character_index:
			characters[i].hide()
			characters[i].set_process(false)
			characters[i].set_physics_process(false)
			characters[i].set_collision_layer_value(1, false)  # Disable collision layer
			characters[i].set_collision_mask_value(1, false)   # Disable collision mask
		else:
			characters[i].show()
			characters[i].set_process(true)
			characters[i].set_physics_process(true)
			characters[i].set_collision_layer_value(1, true)   # Enable collision layer
			characters[i].set_collision_mask_value(1, true)    # Enable collision mask

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("switch_key"):
		# Only allow switching when the current character is on the floor
		if characters.size() == 0:
			return
		var current = characters[current_character_index]
		if current and current.has_method("is_on_floor") and not current.is_on_floor():
			# optional feedback while trying to switch in air
			# print("Cannot switch while airborne")
			return
		switch_character()

func switch_character() -> void:
	# Prevent switching when there is 0 or 1 characters
	if characters.size() <= 1:
		return

	# Prevent switching when player is in the air and only allow switching when on the ground
	var cur = characters[current_character_index]
	if cur and cur.has_method("is_on_floor") and not cur.is_on_floor():
		return
		
	# Hide and disable current character
	characters[current_character_index].hide()
	characters[current_character_index].set_process(false)
	characters[current_character_index].set_physics_process(false)
	characters[current_character_index].set_collision_layer_value(1, false)  # Disable collision layer
	characters[current_character_index].set_collision_mask_value(1, false)   # Disable collision mask
	
	# Update index
	current_character_index = (current_character_index + 1) % characters.size()
	
	# Show and enable new character
	characters[current_character_index].show()
	characters[current_character_index].set_process(true)
	characters[current_character_index].set_physics_process(true)
	characters[current_character_index].set_collision_layer_value(1, true)   # Enable collision layer
	characters[current_character_index].set_collision_mask_value(1, true)    # Enable collision mask
	
	# Transfer position from old character to new character (keep continuity)
	if characters.size() > 0:
		var previous_index = (current_character_index - 1 + characters.size()) % characters.size()
		characters[current_character_index].global_position = characters[previous_index].global_position

	# Update the start/checkpoint node so it keeps track of the current active character position
	if _start_ref:
		_start_ref.global_position = characters[current_character_index].global_position
