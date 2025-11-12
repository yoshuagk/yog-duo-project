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
		died.emit()
		_on_death()

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	print("%s healed %d! Health: %d/%d" % [get_parent().name, amount, current_health, max_health])

func _on_death() -> void:
	print("%s died!" % get_parent().name)
	# Queue free the parent (the entity that has this component)
	get_parent().queue_free()
