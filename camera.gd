extends Camera3D

@export var follow_target: Node3D

func _process(delta):
  global_position = follow_target.global_position
