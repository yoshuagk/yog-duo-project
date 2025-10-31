extends Area3D
class_name CameraBounds

@export_group("References")
@export var phantom_camera: PhantomCamera3D
@export var camera3d: Camera3D  # optional, used when include_view_size is true

@export_group("Bounds Source")
# mark as true to read the size of bounding box
@export var use_area_shape := true
@export var bounds_min := Vector3(-10, -10, -10)
@export var bounds_max := Vector3(10, 10, 10)

@export_group("Viewport Adjustments")
@export var include_view_size := true  # inset bounds by ortho view so edges never leak

var _min := Vector3.ZERO
var _max := Vector3.ZERO
var _orig_deadzone_w := 0.0
var _orig_deadzone_h := 0.0

func _ready() -> void:
	# run after PhantomCamera updates so we clamp the final position
	process_priority = 500
	# ensure physics clamping happens AFTER PhantomCameraHost (which uses ~300)
	# so the host writes the camera position first, then we confine it
	process_physics_priority = 900

	# remember original sizes of deadzones when they are temporarily adjusted
	_orig_deadzone_w = phantom_camera.dead_zone_width
	_orig_deadzone_h = phantom_camera.dead_zone_height

	# resolve bounds from our first BoxShape3D if requested
	if use_area_shape:
		var cs := _get_first_collision_shape()
		if cs and cs.shape is BoxShape3D:
			var box := cs.shape as BoxShape3D
			var scale := cs.global_transform.basis.get_scale().abs()
			var world_size := box.size * scale
			var half := world_size * 0.5
			var center := cs.global_transform.origin
			_min = center - half
			_max = center + half
		else:
			push_warning("CameraBounds: No BoxShape3D found, falling back to manual bounds")
			_min = bounds_min
			_max = bounds_max
	else:
		_min = bounds_min
		_max = bounds_max

	# inset by orthographic view to prevent the view from peeking past the bounds box
	if include_view_size and camera3d and camera3d.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var vp_size := camera3d.get_viewport().get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			var view_h := camera3d.size  # ortho height in world units
			var view_w := view_h * (vp_size.x / vp_size.y)
			var half_w := view_w * 0.5
			var half_h := view_h * 0.5
			_min.x += half_w; _max.x -= half_w
			_min.y += half_h; _max.y -= half_h

func _physics_process(_delta: float) -> void:
	if not phantom_camera:
		return
	# skip if inverted bounds
	if _min.x > _max.x or _min.y > _max.y:
		return

	# clamp PhantomCamera (camera carrier)
	var pos := phantom_camera.global_position
	var clamped_x := false
	var clamped_y := false
	var new_x: float = clamp(pos.x, _min.x, _max.x)
	var new_y: float = clamp(pos.y, _min.y, _max.y)
	clamped_x = not is_equal_approx(new_x, pos.x)
	clamped_y = not is_equal_approx(new_y, pos.y)
	pos.x = new_x
	pos.y = new_y
	phantom_camera.global_position = pos

	# also clamp final Camera3D (prevents any visual leak due to ordering or interp)
	if camera3d:
		var cpos := camera3d.global_position
		cpos.x = clamp(cpos.x, _min.x, _max.x)
		cpos.y = clamp(cpos.y, _min.y, _max.y)
		camera3d.global_position = cpos

	# edge deadzone tweak: shrink horizontal deadzone when hard clamped on X
	# so the camera can re-center sooner after hitting bounds (avoids breaking the camera and getting stuck).
	if clamped_x:
		# Reduce width but keep a minimum sensible range; 0.1 feels responsive.
		phantom_camera.dead_zone_width = min(_orig_deadzone_w, 0.1)
	else:
		phantom_camera.dead_zone_width = _orig_deadzone_w

func _get_first_collision_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null
