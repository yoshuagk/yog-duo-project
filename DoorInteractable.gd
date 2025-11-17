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
	
	# Get reference to main scene for fade overlay
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_method("fade_to_black"):
		await main.fade_to_black()
	
	# Create Demo Completed UI
	_show_completion_screen()
	
	# Wait before quitting
	await get_tree().create_timer(5.0).timeout
	
	# Quit the game
	get_tree().quit()

func _show_completion_screen() -> void:
	# Create a CanvasLayer for the completion screen
	var canvas = CanvasLayer.new()
	canvas.layer = 200  # Above everything else
	get_tree().root.add_child(canvas)
	
	# Background panel (semi-transparent black)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	# "Demo Completed" text
	var title = Label.new()
	title.text = "DEMO COMPLETED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-200, -100)
	title.size = Vector2(400, 100)
	title.add_theme_font_size_override("font_size", 48)
	canvas.add_child(title)
	
	# "Thank you for playing!" text
	var subtitle = Label.new()
	subtitle.text = "Thank you for playing!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-200, 20)
	subtitle.size = Vector2(400, 50)
	subtitle.add_theme_font_size_override("font_size", 24)
	canvas.add_child(subtitle)
