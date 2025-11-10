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

## Current form index
var current_form_index: int = 0
## Current active form
var current_form: PlayerForm = null

## Track instantiated ability nodes for cleanup
var _active_ability_nodes: Array[Node] = []
## Track instantiated visual node
var _active_visual_node: Node = null

func _ready() -> void:
	# checks if characterbody and default form is assigned
	if not default_form:
		push_error("FormController: default_form not assigned!")
		return
	
	if not character_body:
		push_error("FormController: character_body not set!")
		return
	
	# start with just the default form
	forms = [default_form]
	current_form_index = 0
	apply_form(forms[current_form_index])


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_key"):
		# only allow switching forms when on the ground
		if character_body and character_body.is_on_floor():
			cycle_form()


# cycle to the next form in the array if there is any
func cycle_form() -> void:
	if forms.is_empty():
		return
	
	current_form_index = (current_form_index + 1) % forms.size()
	apply_form(forms[current_form_index])


# applies granted form to the array
func set_form_by_index(index: int) -> void:
	if index < 0 or index >= forms.size():
		push_warning("FormController: Invalid form index %d" % index)
		return
	
	current_form_index = index
	apply_form(forms[index])

## apply the given form to the player
func apply_form(form: PlayerForm) -> void:
	if not form:
		push_error("FormController: Tried to apply null form!")
		return
	
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
		
		# calls recalculate_jump in movemest script
		if movement_script.has_method("recalculate_jump"):
			movement_script.recalculate_jump()
	
	# update collider size
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.radius = form.collider_radius
		capsule.height = form.collider_height
	
	# update visuals when models are ready
	_update_visuals(form)
	
	# update abilities when abilities are coded in
	_update_abilities(form)
	
	# update camera offset
	if phantom_camera:
		var current_offset := phantom_camera.follow_offset
		phantom_camera.follow_offset = Vector3(current_offset.x, form.camera_offset_y, current_offset.z)
	
	# Emit signal for other systems
	# in this case it will be to have the ui show name/icon of form when transfored
	form_changed.emit(form)
	
	print("FormController: Switched to form '%s'" % form.form_name)


## Replace visuals with the form's mesh_scene or a colored capsule
func _update_visuals(form: PlayerForm) -> void:
	if not visuals_container:
		return
	
	# Remove old visual
	if _active_visual_node:
		_active_visual_node.queue_free()
		_active_visual_node = null
	
	# Instance new visual
	if form.mesh_scene:
		_active_visual_node = form.mesh_scene.instantiate()
		visuals_container.add_child(_active_visual_node)
	elif form.sprite_texture:
		# Create a textured quad as a simple billboard sprite placeholder
		var sprite_mesh_instance := MeshInstance3D.new()
		var quad := QuadMesh.new()
		# Size the quad roughly to the collider dimensions
		quad.size = Vector2(max(0.1, form.collider_radius * 2.0), max(0.1, form.collider_height))
		sprite_mesh_instance.mesh = quad

		var mat := StandardMaterial3D.new()
		mat.albedo_texture = form.sprite_texture
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 1)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sprite_mesh_instance.set_surface_override_material(0, mat)

		visuals_container.add_child(sprite_mesh_instance)
		_active_visual_node = sprite_mesh_instance
	else:
		# Create a simple colored capsule mesh for testing
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
		if "position" in _active_visual_node:
			_active_visual_node.position.y += form.visual_y_offset
		if "scale" in _active_visual_node and form.visual_scale != Vector3.ONE:
			_active_visual_node.scale *= form.visual_scale


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
