extends Node

@onready var player = $Player/CharacterBody3D
@onready var level_container = $Level_Container

#SCENES TANSITIONING!!!
var current_level: Node = null
var is_transitioning: bool = false

#Scenes array
var levels = {
	"forest_level": "res://scenes/forest_area.tscn",
	"fox_altar_level": "res://scenes/fox_altar_area.tscn",
	"cave_level": "res://scenes/cave_area.tscn",
	"bear_altar_level": "res://scenes/bear_altar_area.tscn"
}

func _ready():
	load_level("forest_level", "default_spawn")

func load_level(level_name: String, spawn_point_name: String = "default_spawn"):
	if is_transitioning:
		return
	is_transitioning = true
	
	if current_level != null:
		current_level.queue_free()
		await current_level.tree_exited
	
	var level_scene = load(levels[level_name])
	current_level = level_scene.instantiate()
	level_container.add_child(current_level)
	
	var spawn_point = current_level.get_node_or_null("Spawn_Points/" + spawn_point_name)
	if spawn_point:
		player.global_position = spawn_point.global_position
		player.global_rotation = spawn_point.global_rotation
	
	var transitions = current_level.get_node_or_null("Scene_Triggers")
	if transitions:
		for trigger in transitions.get_children():
			if trigger is Area3D and not trigger.body_entered.is_connected(_on_transition_triggered):
				trigger.body_entered.connect(_on_transition_triggered.bind(trigger))
	
	is_transitioning = false

func _on_transition_triggered(body: Node3D, trigger: Area3D):
	if body == player and not is_transitioning:
		var target_level = trigger.get_meta("target_level", "")
		var target_spawn = trigger.get_meta("target_spawn", "default_spawn")
		if target_level != "":
			load_level(target_level, target_spawn)

#SPIKES death and respawn
func respawn_player(spawn_point_name: String):
	var spawn_point = current_level.get_node_or_null("Spawn_Points/" + spawn_point_name)
	
	if spawn_point:
		player.global_position = spawn_point.global_position
		player.global_rotation = spawn_point.global_rotation
