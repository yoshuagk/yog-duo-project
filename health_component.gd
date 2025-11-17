extends Node3D
class_name HealthComponent

signal damaged(amount: int, source: Node)
signal died()

@export var max_health := 5
@export var current_health := 5

func _ready() -> void:
	current_health = max_health

func apply_damage(amount: int, source: Node = null) -> void:
	if current_health <= 0:
		return  # Already dead
	
	current_health -= amount
	damaged.emit(amount, source)
	print("%s took %d damage! Health: %d/%d" % [get_parent().name, amount, current_health, max_health])
	
	if current_health <= 0:
		current_health = 0
		print("HealthComponent: Emitting died signal for %s" % get_parent().name)
		died.emit()
		_on_death()

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	print("%s healed %d! Health: %d/%d" % [get_parent().name, amount, current_health, max_health])

func _on_death() -> void:
	var parent = get_parent()
	print("%s died!" % parent.name)
	# Don't queue_free the player - main scene handles player respawn
	# Check if this is the player (CharacterBody3D that's a child of Player node)
	if parent.name == "CharacterBody3D" and parent.get_parent() and parent.get_parent().name == "Player":
		print("Player death detected - main_scene_script will handle respawn")
		return  # Let main_scene_script handle respawn via died signal
	# Queue free enemies and NPCs
	parent.queue_free()
