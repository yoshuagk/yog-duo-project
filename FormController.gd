extends Node
class_name FormController

signal form_changed(new_form: PlayerForm)

@export_group("References")
# uses the characterbody node for the player, which should only be one of to not break the camera
@export var character_body: CharacterBody3D
# the movement script attached to characterbody
@export var movement_script: Node
# collisionshape to resize
@export var collision_shape: CollisionShape3D

@export var visuals_container: Node3D
# node container where ability nodes are instantiated
@export var abilities_container: Node
## PhantomCamera3D to adjust offset per form (optional)
@export var phantom_camera: PhantomCamera3D

@export_group("Forms")
# array of available forms (must have at least one)
@export var forms: Array[PlayerForm] = []
# index of the starting form, which MUST be the default form
@export var starting_form_index: int = 0
## The default form that can never be removed from the cycle
@export var default_form: PlayerForm = null
## Duration for visual cross-transition (seconds)
@export var transform_blend_time: float = 0.15

# current form and active form should be default
var current_form_index: int = 0
var current_form: PlayerForm = null

# keeps track of current abilities on current character
var _active_ability_nodes: Array[Node] = []
## Track instantiated visual node
var _active_visual_node: Node = null
## Store original materials before applying spirit glow
var _original_materials: Array[Material] = []

# used for animations specific to abilities and if player can transform
var is_digging: bool = false #to use f_dig
var is_attacking: bool = false #to use b_attack
var cannot_transform: bool = false #to use d_headshake, f_headshake or b_headshake depending on current form

func _ready() -> void:
	# start with just the default form
	forms = [default_form]
	current_form_index = 0
	apply_form(forms[current_form_index])


func _physics_process(_delta: float) -> void:
	# for the placeholder image to make sure the spirit can also rotate
	if _active_visual_node and _active_visual_node is MeshInstance3D:
		var mat = _active_visual_node.get_surface_override_material(0)
		if mat and mat is StandardMaterial3D:
			var should_flip := false
			
			# Check if in spirit mode - flip based on velocity direction
			if character_body and character_body.has_method("get") and character_body.get("is_spirit_mode"):
				# In spirit mode, check horizontal velocity
				var velocity = character_body.velocity
				if abs(velocity.x) > 0.1:  # Moving horizontally
					should_flip = velocity.x < 0  # Flip if moving left
			else:
				# Normal mode - check rotation
				if character_body and abs(character_body.rotation.y) > 1.5:  # Facing left (close to PI)
					should_flip = true
			
			# Apply the flip
			if should_flip:
				mat.uv1_scale = Vector3(-1, 1, 1)  # Flip horizontally
			else:
				mat.uv1_scale = Vector3(1, 1, 1)  # Normal orientation


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_key"):
		# only allow switching forms when on the ground
		if character_body and character_body.is_on_floor():
			cycle_form()


# cycle to the next form in the array if there is any
func cycle_form() -> void:
	if forms.is_empty():
		# No forms available
		if movement_script and movement_script.has_method("play_override_animation"):
			movement_script.play_override_animation("headshake", 3.0)
		return

	# Play animation if default is the only form
	if forms.size() < 2:
		#print("No other forms to transform into.")
		if movement_script and movement_script.has_method("play_override_animation"):
			movement_script.play_override_animation("headshake", 3.0)
		return
	
	# Get the next form in the cycle
	var next_index: int = (current_form_index + 1) % forms.size()
	var next_form: PlayerForm = forms[next_index]
	
	# Check if there's enough space for the next form
	if not _has_space_for_form(next_form):
		#print("Not enough space to transform into '%s'!" % next_form.form_name)
		# Play headshake animation using movement script
		if movement_script and movement_script.has_method("play_override_animation"):
			movement_script.play_override_animation("headshake", 3.0)
		return
	
	current_form_index = next_index
	apply_form(forms[next_index])


# applies granted form to the array
func set_form_by_index(index: int) -> void:
	if index < 0 or index >= forms.size():
		push_warning("FormController: Invalid form index %d" % index)
		return
	
	current_form_index = index
	apply_form(forms[index])

## apply the given form to the player
func apply_form(form: PlayerForm) -> void:
	current_form = form
	
	# update movement parameters with each form
	if movement_script:
		if "speed" in movement_script:
			movement_script.speed = form.speed
		if "jump_height" in movement_script:
			movement_script.jump_height = form.jump_height
		if "gravity" in movement_script:
			var base_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
			movement_script.gravity = base_gravity * form.gravity_scale
		if "can_wall_climb" in movement_script:
			movement_script.can_wall_climb = form.can_wall_climb
		if "collider_radius" in movement_script:
			movement_script.collider_radius = form.collider_radius
		if "collider_height" in movement_script:
			movement_script.collider_height = form.collider_height
		
		# calls recalculate_jump in movemest script
		if movement_script.has_method("recalculate_jump"):
			movement_script.recalculate_jump()
	
	# update collider size
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		var old_height := capsule.height
		capsule.radius = form.collider_radius
		capsule.height = form.collider_height
		# Keep feet anchored when height changes to avoid snapping
		if character_body and old_height != form.collider_height:
			var dh := form.collider_height - old_height
			character_body.global_position.y += dh * 0.5
	
	# update visuals when models are ready
	_update_visuals(form)
	
	# update abilities when abilities are coded in
	_update_abilities(form)
	
	# update camera offset
	#if phantom_camera:
		#var current_offset := phantom_camera.follow_offset
		#phantom_camera.follow_offset = Vector3(current_offset.x, form.camera_offset_y, current_offset.z)
	
	# Emit signal for other systems
	# in this case it will be to have the ui show name/icon of form when transfored
	form_changed.emit(form)
	
	#print("FormController: Switched to form '%s'" % form.form_name)


## Give spirit a bright white look
func _update_visuals(form: PlayerForm) -> void:
	# keep for later when using actual models
	if not visuals_container:
		#print("FormController: No visuals_container!")
		return
	
	# Keep reference to old visual for a short cross-transition
	var old_visual: Node3D = null
	if _active_visual_node and _active_visual_node is Node3D:
		old_visual = _active_visual_node as Node3D
	_active_visual_node = null
	
	# Instance new visual
	if form.mesh_scene:
		_active_visual_node = form.mesh_scene.instantiate()
		visuals_container.add_child(_active_visual_node)
		
		# Find and pass AnimationPlayer to movement script
		var anim_player := _find_animation_player(_active_visual_node)
		if anim_player and movement_script and movement_script.has_method("set_animation_player"):
			movement_script.set_animation_player(anim_player, form.animation_prefix)
	elif form.sprite_texture:
		# Create a textured quad as a simple billboard sprite placeholder
		var sprite_mesh_instance := MeshInstance3D.new()
		var quad := QuadMesh.new()
		# Size the quad roughly to the collider dimensions
		var quad_size := Vector2(max(0.1, form.collider_radius * 2.0), max(0.1, form.collider_height))
		quad.size = quad_size
		sprite_mesh_instance.mesh = quad

		var mat := StandardMaterial3D.new()
		mat.albedo_texture = form.sprite_texture
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 1)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Enable texture flipping based on parent rotation
		mat.uv1_scale = Vector3(1, 1, 1)  # Will be modified in _physics_process
		sprite_mesh_instance.set_surface_override_material(0, mat)

		visuals_container.add_child(sprite_mesh_instance)
		_active_visual_node = sprite_mesh_instance
		print("  - Sprite billboard created successfully at: %s" % sprite_mesh_instance.global_position)
	else:
		print("FormController: Using debug capsule")
		var mesh_instance := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = form.collider_radius
		capsule_mesh.height = form.collider_height
		mesh_instance.mesh = capsule_mesh
		
		# Apply debug color
		var material := StandardMaterial3D.new()
		material.albedo_color = form.debug_color
		mesh_instance.set_surface_override_material(0, material)
		
		visuals_container.add_child(mesh_instance)
		_active_visual_node = mesh_instance

	# Apply per-form visual transform adjustments
	if _active_visual_node:
		if "position" in _active_visual_node and form.visual_position_offset != Vector3.ZERO:
			_active_visual_node.position = form.visual_position_offset
		if "rotation_degrees" in _active_visual_node and form.visual_rotation != Vector3.ZERO:
			_active_visual_node.rotation_degrees = form.visual_rotation
		if "scale" in _active_visual_node and form.visual_scale != Vector3.ONE:
			_active_visual_node.scale *= form.visual_scale

	# Transition between forms
	if _active_visual_node and _active_visual_node is Node3D:
		var new_visual := _active_visual_node as Node3D
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)

		# New comes in from 90% scale to target
		var target_scale: Vector3 = new_visual.scale
		new_visual.scale = target_scale * 0.9
		tween.tween_property(new_visual, "scale", target_scale, max(0.05, transform_blend_time))

		# Old eases down then is freed
		if old_visual:
			var old_target := old_visual.scale * 0.9
			var t2 := create_tween()
			t2.set_trans(Tween.TRANS_SINE)
			t2.set_ease(Tween.EASE_IN)
			t2.tween_property(old_visual, "scale", old_target, max(0.05, transform_blend_time))
			t2.finished.connect(func():
				if is_instance_valid(old_visual):
					old_visual.queue_free()
			)
	elif old_visual:
		old_visual.queue_free()


## Replace abilities with the form's ability_scenes
func _update_abilities(form: PlayerForm) -> void:
	if not abilities_container:
		return
	
	# Remove old abilities
	for ability_node in _active_ability_nodes:
		ability_node.queue_free()
	_active_ability_nodes.clear()
	
	# Instance new abilities
	for ability_scene in form.ability_scenes:
		if ability_scene:
			var ability_instance := ability_scene.instantiate()
			abilities_container.add_child(ability_instance)
			_active_ability_nodes.append(ability_instance)


# get the current form
func get_current_form() -> PlayerForm:
	return current_form


# grant a new form and adds it to the array and makes sure default form in array position 0 does not get effected
func unlock_form(new_form: PlayerForm) -> void:
	# if we only have the default form then add the new form
	if forms.size() == 1:
		forms.append(new_form)
		print("FormController: Unlocked new form '%s'" % new_form.form_name)
	else:
		# replaces form in second slot with new one
		var old_form_name := forms[1].form_name
		forms[1] = new_form
		print("FormController: Replaced '%s' with '%s'" % [old_form_name, new_form.form_name])

	# switches to the newly acquired form when granted
	current_form_index = 1
	apply_form(new_form)

func has_form(form: PlayerForm) -> bool:
	return forms.has(form)

func has_form_by_name(form_name: StringName) -> bool:
	for f in forms:
		if f.form_name == form_name:
			return true
	return false

## Recursively search for AnimationPlayer in instantiated model
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	
	return null

## Check if there's enough vertical space to transform into the target form
func _has_space_for_form(target_form: PlayerForm) -> bool:
	if not character_body or not collision_shape:
		return true  # Can't check, allow transformation
	
	# Get current collision shape to find the base position
	var current_capsule := collision_shape.shape as CapsuleShape3D
	if not current_capsule:
		return true
	
	# Calculate the base of current capsule (feet position)
	var capsule_bottom_offset: float = collision_shape.position.y - (current_capsule.height / 2.0)
	
	# Calculate where the top of the next form would be
	var new_height: float = target_form.collider_height
	var new_top_local: float = capsule_bottom_offset + new_height
	
	# Convert to global position for raycast
	var check_start: Vector3 = character_body.global_position
	check_start.y += capsule_bottom_offset + 0.1  # Start just above feet
	
	var check_end: Vector3 = character_body.global_position
	check_end.y += new_top_local + 0.1  # Add small margin
	
	# Perform raycast upward to check for obstacles
	var space_state := character_body.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(check_start, check_end)
	query.collision_mask = 1  # World layer
	query.exclude = [character_body]
	
	var result := space_state.intersect_ray(query)
	
	if result:
		# Hit something - not enough space
		#print("FormController: Blocked by %s at distance %.2f" % [result.collider.name, check_start.distance_to(result.position)])
		return false
	
	# No obstruction - safe to transform
	return true

## Apply bright white glow effect to the active visual (for spirit mode)
func set_spirit_glow(enabled: bool) -> void:
	if not _active_visual_node:
		return
	
	if enabled:
		# Store original materials and apply glowing white emission
		_original_materials.clear()
		_collect_and_apply_glow(_active_visual_node, true)
	else:
		# Restore original materials
		var mat_index := 0
		_restore_materials(_active_visual_node, mat_index)
		_original_materials.clear()

## Recursively collect materials and apply glow
func _collect_and_apply_glow(node: Node, apply: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.mesh:
			return
		
		for i in range(mesh_instance.mesh.get_surface_count()):
			# Store original material
			var original := mesh_instance.get_surface_override_material(i)
			if not original:
				original = mesh_instance.mesh.surface_get_material(i)
			_original_materials.append(original)
			
			# Create glowing white material
			var glow_mat := StandardMaterial3D.new()
			if original and original is StandardMaterial3D:
				var orig_std := original as StandardMaterial3D
				# Copy texture if exists
				if orig_std.albedo_texture:
					glow_mat.albedo_texture = orig_std.albedo_texture
					glow_mat.albedo_color = Color(1.5, 1.5, 1.5, 1.0)  # Bright white tint
				else:
					glow_mat.albedo_color = Color(1, 1, 1, 1)
				# Copy transparency settings
				glow_mat.transparency = orig_std.transparency
				glow_mat.billboard_mode = orig_std.billboard_mode
				glow_mat.cull_mode = orig_std.cull_mode
				glow_mat.shading_mode = orig_std.shading_mode
				glow_mat.uv1_scale = orig_std.uv1_scale
			else:
				glow_mat.albedo_color = Color(1, 1, 1, 1)
			
			# Add bright emission
			glow_mat.emission_enabled = true
			glow_mat.emission = Color(1, 1, 1, 1)  # Pure white
			glow_mat.emission_energy_multiplier = 2.5  # Bright glow
			
			mesh_instance.set_surface_override_material(i, glow_mat)
	
	# Recurse through children
	for child in node.get_children():
		_collect_and_apply_glow(child, apply)

## Recursively restore original materials
func _restore_materials(node: Node, mat_index: int) -> int:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.mesh:
			return mat_index
			
		for i in range(mesh_instance.mesh.get_surface_count()):
			if mat_index < _original_materials.size():
				mesh_instance.set_surface_override_material(i, _original_materials[mat_index])
				mat_index += 1
	for child in node.get_children():
		mat_index = _restore_materials(child, mat_index)
	
	return mat_index
