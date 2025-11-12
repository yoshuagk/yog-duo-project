extends Interactable
class_name DoorInteractable

## Number of keys required to unlock the door
@export var keys_required: int = 3

## Reference to the player's inventory/key counter
var player_keys: int = 0

func _ready() -> void:
	super._ready()
	interactable_name = "Exit Door"

func _on_interact(player: CharacterBody3D) -> void:
	# Check how many keys the player has collected
	if player.has_method("get_key_count"):
		player_keys = player.get_key_count()
	
	if player_keys >= keys_required:
		print("Door: All keys collected! Ending game...")
		_end_game()
	else:
		var remaining := keys_required - player_keys
		print("Door: You need %d more key(s) to unlock this door!" % remaining)
		print("Keys: %d/%d" % [player_keys, keys_required])

func _end_game() -> void:
	print("=== GAME COMPLETE ===")
	print("Congratulations! You collected all the keys!")
	
	# Wait a moment before quitting
	await get_tree().create_timer(2.0).timeout
	
	# Quit the game
	get_tree().quit()
