extends Area3D
class_name BearHitbox

@export var damage: int = 1
@export var active_time: float = 0.2
@export var cooldown: float = 0.5
# team of the attacker (0 = player, 1 = enemy)
@export var attacker_team: int = 0

# offset from player position when attacking
@export var hitbox_offset: Vector3 = Vector3(1.0, 0.5, 0)

var _can_attack: bool = true
var _is_active: bool = false
var _hits_this_swing: Dictionary = {}

func _ready() -> void:
	# Hitbox should be detecting hurtboxes
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

## Trigger the attack
func perform_attack(attacker_position: Vector3) -> void:
	if not _can_attack:
		print("BearHitbox: Attack on cooldown")
		return
	
	_can_attack = false
	_hits_this_swing.clear()
	
	# Position the hitbox in front of the player
	#var offset := hitbox_offset
	#if not facing_right:
		#offset.x = -offset.x
	
	#global_position = attacker_position + offset
	
	# Activate hitbox
	monitoring = true
	_is_active = true
	print("BearHitbox: Attack started at %s" % global_position)
	
	# Deactivate after active_time
	await get_tree().create_timer(active_time).timeout
	monitoring = false
	_is_active = false
	print("BearHitbox: Attack ended")
	
	# Start cooldown
	await get_tree().create_timer(cooldown).timeout
	_can_attack = true
	print("BearHitbox: Ready to attack again")

func _on_area_entered(area: Area3D) -> void:
	if not _is_active:
		return
	
	# Check if it's a Hurtbox
	if not area is Hurtbox:
		return
	
	var hurtbox := area as Hurtbox
	
	# Prevent friendly fire (skip same team)
	if hurtbox.team == attacker_team:
		print("BearHitbox: Skipping friendly target %s" % hurtbox.get_parent().name)
		return
	
	# Prevent hitting the same target multiple times in one swing
	var target := hurtbox.get_parent()
	if _hits_this_swing.has(target):
		return
	
	_hits_this_swing[target] = true
	
	# deal damage
	hurtbox.take_damage(damage, get_parent().get_parent())  # Source is the player

func is_ready_to_attack() -> bool:
	return _can_attack
