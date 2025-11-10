extends Area3D
class_name Interactable

# base class for interactable objects (altars, buttons, save points, etc.)

signal interacted(player: CharacterBody3D)

# check if it calls the right name
@export var interactable_name: String = "Object"

# whether this interactable is currently enabled
# for something like the altars it would be set to false since you cant use it anymore after interacting with it
# and manage forms at save points instead
@export var enabled: bool = true


func _ready() -> void:
	# collision layer and mask setup to prevent player from bumping into the box and prevent box detecting everything
	# layer 3 = interactables, mask 2 = player
	collision_layer = 4
	collision_mask = 2  
	
	# automatic detection for when player enters and exits interactable range
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not enabled:
		return
	
	# check if it's the player entering
	if body is CharacterBody3D and body.has_method("_register_interactable"):
		body._register_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	# check if it's the player leaving
	if body is CharacterBody3D and body.has_method("_unregister_interactable"):
		body._unregister_interactable(self)


# called by the player when interact_key is pressed while in range of the box
func interact(player: CharacterBody3D) -> void:
	if not enabled:
		return
	
	print("Interacted with: %s" % interactable_name)
	interacted.emit(player)
	
	# method which can be called and overwritten in inherited scripts to add custom behavior
	_on_interact(player)

func _on_interact(player: CharacterBody3D) -> void:
	pass
