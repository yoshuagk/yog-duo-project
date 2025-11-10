extends Interactable
class_name AltarInteractable

# inherits from Interactable class script. So this script is for altar behavior

# the form to grant when player interacts with this altar which is linked with the tres files
@export var form_to_grant: PlayerForm = null

# for testing, this is to be able to reuse altars and SHOULD be one time use in real game
# whether this altar can only be used once
@export var one_time_use: bool = false

# whether this altar has already been used
var _used: bool = false


func _on_interact(player: CharacterBody3D) -> void:
	# check if already used
	if one_time_use and _used:
		print("%s: Already activated" % interactable_name)
		return
	
	# Validate form
	if not form_to_grant:
		push_error("%s: No form assigned to grant!" % interactable_name)
		return
	
	# find FormController on the player
	var form_controller: FormController = null
	for child in player.get_children():
		if child is FormController:
			form_controller = child
			break
	
	if not form_controller:
		push_error("%s: Player has no FormController!" % interactable_name)
		return
	
	# check if player already has this form
	# just for testing
	if form_controller.has_form(form_to_grant):
		print("%s: You already have the '%s' form" % [interactable_name, form_to_grant.form_name])
		return
	
	# grant the form
	form_controller.unlock_form(form_to_grant)
	_used = true
	
	print("%s: Granted '%s' form!" % [interactable_name, form_to_grant.form_name])
	
	_on_form_granted()


# overide this for custom behavior such as animations and sound
func _on_form_granted() -> void:
	pass
