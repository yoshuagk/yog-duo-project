extends Area3D
class_name Hurtbox

## Team/faction ID: 0 = player, 1 = enemy, 2 = environment/props
@export var team: int = 2

## Path to the HealthComponent node (usually a sibling)
@export var health_component_path: NodePath = NodePath("../HealthComponent")

var health_component: HealthComponent = null

func _ready() -> void:
	# This is a hurtbox - it should be monitorable (can be detected) but not monitoring
	monitoring = false
	monitorable = true
	
	# Find the HealthComponent
	if health_component_path:
		health_component = get_node_or_null(health_component_path)
	
	if not health_component:
		# Try to find it as a sibling
		health_component = get_parent().get_node_or_null("HealthComponent")
	
	if not health_component:
		push_warning("Hurtbox on %s: No HealthComponent found!" % get_parent().name)

func take_damage(amount: int, source: Node = null) -> void:
	if health_component:
		health_component.apply_damage(amount, source)
	else:
		push_warning("Hurtbox on %s: Cannot take damage, no HealthComponent!" % get_parent().name)
