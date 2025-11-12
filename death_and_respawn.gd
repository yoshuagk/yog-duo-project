extends Area3D

@export var respawn_point_name: String = ""

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "CharacterBody3D":
		var main = get_tree().root.get_node("General_Level")
		if main.has_method("respawn_player"):
			main.respawn_player(respawn_point_name)
