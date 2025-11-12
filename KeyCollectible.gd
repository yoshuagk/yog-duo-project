extends Area3D
class_name KeyCollectible

## Visual feedback when collected (optional)
@export var collect_message: String = "Key collected!"

func _ready() -> void:
	# Set up collision for player detection
	collision_layer = 4  # Interactables layer
	collision_mask = 2   # Player layer
	
	# Make sure it's in the Collectables group
	add_to_group("collectables")
	
	# Connect signals
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Check if it's the player
	if body is CharacterBody3D and body.has_method("collect_key"):
		body.collect_key()
		print(collect_message)
		
		# Remove the entire parent object (the sphere/visual) from the scene
		var parent := get_parent()
		if parent:
			parent.queue_free()
		else:
			# Fallback: just remove this Area3D if no parent
			queue_free()
