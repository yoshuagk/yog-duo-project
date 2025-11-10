extends Node
class_name AbilitiesContainer

## abilities are triggered by the ability_key, in this case its "G"
## to change that go to project -> project settings -> input map -> ability_key

## reference to the FormController to check which form is active
@onready var form_controller: FormController = get_parent().get_node("FormController")

func _ready() -> void:
	if not form_controller:
		push_error("AbilitiesContainer: Could not find FormController!")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_key"):
		use_ability()

## triggers the ability based on the current form
func use_ability() -> void:
	if not form_controller:
		print("AbilitiesContainer: No FormController found!")
		return
	
	var current_form := form_controller.get_current_form()
	if not current_form:
		print("AbilitiesContainer: No active form!")
		return
	
	# checks which form is active and execute the form specific ability
	match current_form.form_name:
		&"Default":
			_use_default_ability()
		&"Small":
			_use_fox_ability()
		&"Large":
			_use_bear_ability()
		_:
			print("No ability defined for form '%s'" % current_form.form_name)

## Default form ability (placeholder)
func _use_default_ability() -> void:
	print("=== DEFAULT FORM ABILITY ACTIVATED ===")
	# add logic for astral projection

## Fox form ability to dig through to special diggable blocks
func _use_fox_ability() -> void:
	print("=== FOX FORM ABILITY ACTIVATED ===")
	
	# get the player body
	var player := get_parent() as CharacterBody3D
	# check if player body is found
	#if not player:
		#print("Error: Could not find player CharacterBody3D")
		#return
	
	# checks if player is on the ground
	#if not player.is_on_floor():
		#print("Fox cannot dig while in the air!")
		#return
	
	# Create a raycast to detect what's below the player
	var space_state := player.get_world_3d().direct_space_state
	var player_pos := player.global_position
	
	# Cast ray from player position downward
	var ray_start := player_pos
	var ray_end := player_pos + Vector3.DOWN * 2.0  # checks 2 units below
	
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1  # Collide with world layer
	
	var result := space_state.intersect_ray(query)
	
	# checls if block object below is diggable
	if result:
		var hit_object = result.collider
		print("Fox detected object below: %s" % hit_object.name)
		
		# check if it's a diggable block
		# in this case a CSGBOX3D which is in the diggable group
		if hit_object is CSGBox3D and _is_diggable(hit_object):
			print("Digging through %s!" % hit_object.name)
			hit_object.queue_free()  # removes the block
			# logic for particle effects, sound, animation here later
		else:
			print("This block cannot be dug through!")
	else:
		print("Nothing detected below fox")

## check if a block is diggabl
func _is_diggable(block: Node) -> bool:
	# method for every block which should have "dirt" in their name
	# var block_name := block.name.to_lower()
	#if "dirt" in block_name in block_name:
		#return true
	
	# every diggable block is added in "diggable" group
	# view block in inspector, then go to node section, if there is not a checkbox for diggable
	# then click the "+" and add a group with the name "diggable"
	if block.is_in_group("diggable"):
		return true
	
	return false
## bear form ability
func _use_bear_ability() -> void:
	print("=== BEAR FORM ABILITY ACTIVATED ===")
	# add logic for bear attack
	# add logic for bear walk climb
