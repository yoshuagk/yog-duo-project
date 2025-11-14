extends Node
class_name AbilitiesContainer

## abilities are triggered by the ability_key, in this case its "G"
## to change that go to project -> project settings -> input map -> ability_key

## reference to the FormController to check which form is active
@onready var form_controller: FormController = get_parent().get_node("FormController")
@export var character_body : CharacterBody3D
## Spirit move radius (units) limiting free-fly distance from dropped statue
@export var spirit_move_radius: float = 8.0

## keeps track of the last spawned duplicate for default ability
var default_statue: Node3D = null
## tracks whether the player is currently in spirit state
var is_spirit: bool = false

func _ready() -> void:
	if not form_controller:
		push_error("AbilitiesContainer: Could not find FormController!")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_key"):
		if is_spirit:
			use_ability()
			return
		if character_body and character_body.is_on_floor():
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

## Default form ability
func _use_default_ability() -> void:
	print("=== DEFAULT FORM ABILITY ACTIVATED ===")

	var player := get_parent() as CharacterBody3D
	if not player:
		print("Default ability: could not find player body")
		return

	# Access movement script via FormController to toggle spirit controls
	var movement_script := form_controller.movement_script if form_controller else null

	# If already in spirit state, return to the body and end the state
	if is_spirit:
		if default_statue and is_instance_valid(default_statue):
			# teleport player back to the statue position
			player.global_position = default_statue.global_position
			# clean up the statue
			default_statue.queue_free()
			default_statue = null
		# disable spirit movement
		if movement_script and movement_script.has_method("set_spirit_mode"):
			movement_script.set_spirit_mode(false)
			if movement_script.has_method("clear_spirit_bounds"):
				movement_script.clear_spirit_bounds()
		is_spirit = false
		print("Back to body")
		return

	# Otherwise, enter spirit state and drop a statue at current position
	if default_statue and is_instance_valid(default_statue):
		default_statue.queue_free()
		default_statue = null

	# create a container node that will hold the visual duplicate
	default_statue = Node3D.new()
	default_statue.name = "DefaultStatue"
	default_statue.global_transform = player.global_transform

	# add to the active scene (fallback to root if needed)
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(default_statue)
	else:
		get_tree().root.add_child(default_statue)

	# try to duplicate the current visual under the player's Visuals node
	var visuals_container := player.get_node_or_null("Visuals")
	if visuals_container and visuals_container.get_child_count() > 0:
		var current_visual := visuals_container.get_child(0)
		var statue_visual := current_visual.duplicate()
		# keep the same relative transform as the active visual
		statue_visual.transform = current_visual.transform
		default_statue.add_child(statue_visual)

	# enable spirit movement
	if movement_script and movement_script.has_method("set_spirit_mode"):
		movement_script.set_spirit_mode(true)
		# set spirit bounds centered on the statue
		if movement_script.has_method("set_spirit_bounds"):
			movement_script.set_spirit_bounds(default_statue.global_position, spirit_move_radius)

	is_spirit = true
	print("placed statue at %s" % default_statue.global_position)


## Fox form ability to dig through to special diggable blocks
func _use_fox_ability() -> void:
	print("=== FOX FORM ABILITY ACTIVATED ===")
	
	# Play dig animation
	var movement_script := form_controller.movement_script if form_controller else null
	if movement_script and movement_script.has_method("play_ability_animation"):
		movement_script.play_ability_animation("dig", 1.0)
	
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
	
	# Play attack animation
	var movement_script := form_controller.movement_script if form_controller else null
	if movement_script and movement_script.has_method("play_ability_animation"):
		movement_script.play_ability_animation("attack", 1.5)
	
	# Find or create the BearHitbox
	var hitbox: BearHitbox = get_node_or_null("BearHitbox")
	if not hitbox:
		push_warning("BearHitbox not found under Abilities node!")
		return
	
	# Check if ready to attack
	if not hitbox.is_ready_to_attack():
		print("Bear attack on cooldown")
		return
	
	# Get player position and facing direction
	var player := get_parent() as CharacterBody3D
	if not player:
		return
	
	# Determine facing direction from Visuals rotation
	#var visuals := player.get_node_or_null("Visuals")
	#var facing_right := true
	#if visuals:
		# If rotation.y is PI (180 degrees), player is facing left
		#facing_right = abs(visuals.rotation.y) < 1.0
	
	# Trigger the attack
	hitbox.perform_attack(player.global_position)
	print("Bear attacks")
