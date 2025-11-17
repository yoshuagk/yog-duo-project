extends Node

@onready var player = $Player/CharacterBody3D
@onready var level_container = $Level_Container
@onready var fade_overlay: ColorRect = $FadeOverlay/ColorRect
@onready var camera = $Camera3D

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

# Fade settings
var fade_duration: float = 0.3
var spirit_dim_alpha: float = 0.0  # Track spirit mode dimming
var last_spawn_point: String = ""  # Track last checkpoint for death respawn

func _ready():
	# Start with fade overlay tansparent
	if fade_overlay:
		fade_overlay.color.a = 0.0
	
	# Connect player death to respawn
	var player_health = player.get_node_or_null("HealthComponent")
	if player_health and player_health.has_signal("died"):
		player_health.died.connect(_on_player_died)
		print("Main: Connected player death handler")
	
	load_level("forest_level", "default_spawn")

func load_level(level_name: String, spawn_point_name: String = "default_spawn"):
	if is_transitioning:
		return
	is_transitioning = true
	
	# Fade to black
	await fade_to_black()
	
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
		# Snap camera to player position to prevent panning
		if camera and camera.has_method("snap_to_target"):
			camera.snap_to_target()
	
	var transitions = current_level.get_node_or_null("Scene_Triggers")
	if transitions:
		for trigger in transitions.get_children():
			if trigger is Area3D and not trigger.body_entered.is_connected(_on_transition_triggered):
				trigger.body_entered.connect(_on_transition_triggered.bind(trigger))
	
	# Fade back to clear
	await fade_to_clear()
	
	is_transitioning = false

func _on_transition_triggered(body: Node3D, trigger: Area3D):
	if body == player and not is_transitioning:
		var target_level = trigger.get_meta("target_level", "")
		var target_spawn = trigger.get_meta("target_spawn", "default_spawn")
		if target_level != "":
			load_level(target_level, target_spawn)

## Fade the screen to black
func fade_to_black() -> void:
	if not fade_overlay:
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_overlay, "color:a", 1.5, fade_duration)
	await tween.finished

## Fade the screen from black to clear
func fade_to_clear() -> void:
	if not fade_overlay:
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_overlay, "color:a", 0.0, fade_duration)

#SPIKES death and respawn
func respawn_player(spawn_point_name: String):
	# Store this as the last spawn point for death respawn
	last_spawn_point = spawn_point_name
	
	# Fade to black first
	await fade_to_black()
	
	var spawn_point = current_level.get_node_or_null("Spawn_Points/" + spawn_point_name)
	
	if spawn_point:
		player.global_position = spawn_point.global_position
		player.global_rotation = spawn_point.global_rotation
		# Reset player velocity to prevent carried momentum
		if player.has_method("set"):
			player.velocity = Vector3.ZERO
		# Snap camera to prevent panning
		if camera and camera.has_method("snap_to_target"):
			camera.snap_to_target()
	
	# Fade back to clear
	await fade_to_clear()

func _on_player_died():
	print("Main: Player died! Respawning...")
	
	# Determine spawn point: use last checkpoint or find default spawn
	var spawn_name = last_spawn_point
	if spawn_name == "":
		# No checkpoint set, find first spawn point in current level
		var spawn_points = current_level.get_node_or_null("Spawn_Points")
		if spawn_points and spawn_points.get_child_count() > 0:
			spawn_name = spawn_points.get_child(0).name
			print("Main: Using default spawn: ", spawn_name)
		else:
			print("Main: ERROR - No spawn points found!")
			return
	
	# Reset player health before respawning
	var player_health = player.get_node_or_null("HealthComponent")
	if player_health:
		player_health.current_health = player_health.max_health
	
	# Respawn at the checkpoint
	await respawn_player(spawn_name)
