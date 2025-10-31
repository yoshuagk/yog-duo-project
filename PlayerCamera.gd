extends Camera3D
# This script ensures the camera only follows on X and Y axes, not Z
# Works alongside PhantomCamera to constrain movement

@export var lock_z: bool = true  # Keep Z position fixed
@export var fixed_z_position: float = 0.0  # The Z position to maintain

var _initial_z: float = 0.0

func _ready() -> void:
	_initial_z = global_position.z
	if lock_z:
		fixed_z_position = _initial_z

func _process(_delta: float) -> void:
	# After PhantomCamera updates the position, lock Z if enabled
	if lock_z:
		var pos = global_position
		pos.z = fixed_z_position
		global_position = pos
