extends Node

func _on_fox_scene_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://scenes/fox_altar_area.tscn")


func _on_fox_area_to_forest_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file("res://scenes/forest_area.tscn")
