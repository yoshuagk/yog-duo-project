extends Resource
class_name PlayerForm

## Defines a player form (shapeshift state) with movement, collider, visuals, and abilities.
## Used by FormController to apply different character states.

@export_group("Identity")
## Unique name for this form (e.g., "default", "small", "large")
@export var form_name: StringName = &"default"

@export_group("Movement")
## Horizontal movement speed
@export var speed: float = 6.0
## Jump height in world units
@export var jump_height: float = 2.0
## Gravity multiplier (1.0 = use default gravity)
@export var gravity_scale: float = 1.0
## Whether this form can wall climb (passive ability)
@export var can_wall_climb: bool = false

@export_group("Collider")
## Capsule radius
@export var collider_radius: float = 0.5
## Capsule height
@export var collider_height: float = 2.0

@export_group("Camera")
## Vertical offset to apply to camera follow_offset when this form is active
## (e.g., smaller forms might want the camera lower to keep them centered)
@export var camera_offset_y: float = 0.0

@export_group("Visuals")
## Optional scene to instance for this form's visuals (mesh + animations)
## If null, uses a default capsule mesh
@export var mesh_scene: PackedScene = null
## Optional sprite texture to use as a simple placeholder visual (ignored if mesh_scene is set)
@export var sprite_texture: Texture2D = null
## Optional scale applied to the instantiated visual (mesh_scene or sprite)
@export var visual_scale: Vector3 = Vector3.ONE
## Optional Y offset applied to the visual so feet align with the ground
@export var visual_y_offset: float = 0.0

@export_group("Abilities")
## Ability scenes to enable for this form (e.g., AttackAbility, DashAbility)
## Each will be instantiated as a child of the Abilities node
@export var ability_scenes: Array[PackedScene] = []

## Optional color tint for the default capsule (if mesh_scene is null)
@export var debug_color: Color = Color.WHITE
