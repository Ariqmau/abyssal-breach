## engineer_robot.gd
## Click-to-move platformer inside the submarine interior.
## Left-click floor → walk there.  Left-click WarningSign → walk + repair.
## Gravity and floor detection follow SubmarineModel's local Y axis.
extends CharacterBody3D


# ══════════════════════════════════════════════════════
#  TUNABLES
# ══════════════════════════════════════════════════════

@export var move_speed      : float = 3.2
@export var jump_force      : float = 5.8
@export var gravity         : float = 16.0
@export var arrival_dist    : float = 0.25
## X depth in SubmarineModel local space where the robot lives.
## Must match the floor collision shape's X center (~0.64).
@export var interior_x_depth : float = 0.64


# ══════════════════════════════════════════════════════
#  NODE REF
# ══════════════════════════════════════════════════════

@onready var _sprite : AnimatedSprite3D = $AnimatedSprite3D


# ══════════════════════════════════════════════════════
#  CONSTANTS
# ══════════════════════════════════════════════════════

const _FIX_DURATION   : float = 0.8
const _LAUNCH_MULT    : float = 1.8   # trampoline launch multiplier


# ══════════════════════════════════════════════════════
#  STATE
# ══════════════════════════════════════════════════════

var _sub_model    : Node3D = null
var _vel_v        : float  = 0.0
var _was_on_floor : bool   = true

var _has_target        : bool    = false
var _target_local      : Vector3 = Vector3.ZERO  # target in SubmarineModel local space
var _current_sign      : Area3D  = null
var _trampoline_target : bool    = false

var _is_fixing    : bool   = false
var _fix_timer    : float  = 0.0


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	floor_snap_length = 0.3


# ══════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if not Globals.is_in_2d_mode:
		return
	if Globals.hull_integrity <= 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)
		get_viewport().set_input_as_handled()


func _handle_click(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var sub := _get_sub_model()
	if sub == null:
		return

	var from := camera.project_ray_origin(screen_pos)
	var dir  := camera.project_ray_normal(screen_pos)

	# Only hit interior layers: 4 (platforms/trampoline) + 16 (warning signs).
	# This skips the outer submarine hull on collision layer 2.
	var params := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	params.exclude            = [get_rid()]
	params.collision_mask     = 4 | 16
	params.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(params)

	if hit and hit.has("collider"):
		var col = hit["collider"]
		if col is Area3D and col.has_method("apply_fix"):
			# Clicked a warning sign → navigate + repair on arrival.
			_current_sign      = col as Area3D
			_target_local      = sub.to_local(col.global_position)
			_has_target        = true
			_is_fixing         = false
			_trampoline_target = false
			return
		elif col is StaticBody3D:
			if col.is_in_group("trampoline"):
				# Clicked trampoline → walk to its Z position then auto-launch on arrival.
				# Force target X to the robot's lane so horiz has no X component
				# (the hit position X is the trampoline surface, not the robot's floor lane).
				var local_hit  := sub.to_local(hit["position"])
				local_hit.x    = interior_x_depth
				_target_local      = local_hit
				_has_target        = true
				_current_sign      = null
				_is_fixing         = false
				_trampoline_target = true
			else:
				# Regular floor → walk to hit position.
				_target_local      = sub.to_local(hit["position"])
				_has_target        = true
				_current_sign      = null
				_is_fixing         = false
				_trampoline_target = false
			return

	# Fallback: dollhouse camera looks in -X (orthographic side view), so
	# dir.dot(world_up) ≈ 0 and a horizontal-plane intersection never works.
	# Instead intersect the vertical plane X = robot's current X.
	var denom := dir.x
	if absf(denom) > 0.001:
		var t := (global_position.x - from.x) / denom
		if t > 0.0:
			_target_local      = sub.to_local(from + dir * t)
			_has_target        = true
			_current_sign      = null
			_is_fixing         = false
			_trampoline_target = false


# ══════════════════════════════════════════════════════
#  PHYSICS
# ══════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if not Globals.is_in_2d_mode:
		return

	var sub := _get_sub_model()
	if sub == null:
		return

	var sub_up := sub.global_transform.basis.y
	up_direction = sub_up

	# Fix animation timer — robot stands still while fixing.
	# apply_fix() was already called immediately in _on_arrived(); the timer
	# only controls how long the fix animation plays before returning to idle.
	if _is_fixing:
		_fix_timer -= delta
		if _fix_timer <= 0.0:
			_is_fixing = false
		_apply_gravity(delta, sub_up)
		velocity = sub_up * _vel_v
		move_and_slide()
		_vel_v = velocity.dot(sub_up)
		var lp_fix := sub.to_local(global_position)
		lp_fix.x   = interior_x_depth
		lp_fix.z   = clampf(lp_fix.z, -2.5, 4.0)
		global_position = sub.to_global(lp_fix)
		_update_anim(Vector3.ZERO)
		return

	# Gravity.
	_apply_gravity(delta, sub_up)

	# Horizontal movement toward target.
	# Reconvert from SubmarineModel local space each frame so the target
	# stays fixed within the interior even as the submarine moves.
	var h_vel := Vector3.ZERO
	if _has_target:
		var world_target : Vector3
		if _current_sign != null and is_instance_valid(_current_sign):
			world_target = _current_sign.global_position
		else:
			world_target = sub.to_global(_target_local)
		var to_target  := world_target - global_position
		var horiz      := to_target - to_target.project(sub_up)
		var vert_dist  := absf(to_target.dot(sub_up))
		if horiz.length() > arrival_dist:
			h_vel = horiz.normalized() * move_speed
		elif vert_dist <= 0.6 or _trampoline_target:
			# Only "arrive" if at roughly the same floor level (prevents fixing
			# a Floor-2 sign from Floor 1 when XZ positions happen to match).
			_on_arrived()

	velocity = h_vel + sub_up * _vel_v
	move_and_slide()

	# Sync velocity back after collision response.
	_vel_v = velocity.dot(sub_up)
	h_vel  = velocity - velocity.project(sub_up)

	# Trampoline detection — launch if landing (negative vertical velocity).
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() != null and col.get_collider().is_in_group("trampoline"):
			if _vel_v <= 0.0:
				_vel_v             = jump_force * _LAUNCH_MULT
				_target_local      = Vector3(interior_x_depth, 0.7, 1.32)
				_has_target        = true
				_current_sign      = null
				_is_fixing         = false
				_trampoline_target = false
				var tramp := col.get_collider()
				if tramp.has_method("bounce"):
					tramp.bounce()
			break

	# Lock X to floor depth; clamp Z inside interior bounds.
	var lp := sub.to_local(global_position)
	lp.x    = interior_x_depth
	lp.z    = clampf(lp.z, -2.5, 4.0)
	global_position = sub.to_global(lp)

	_update_anim(h_vel)


func _apply_gravity(delta: float, sub_up: Vector3) -> void:
	if not is_on_floor():
		_vel_v -= gravity * delta
	elif _vel_v < 0.0:
		_vel_v = 0.0


func _on_arrived() -> void:
	_has_target = false
	if _trampoline_target:
		# Robot reached the trampoline base — launch to Floor 2.
		_trampoline_target = false
		_vel_v        = jump_force * _LAUNCH_MULT
		_target_local = Vector3(interior_x_depth, 0.7, 1.32)
		_has_target   = true
		var tramp := get_tree().get_first_node_in_group("trampoline")
		if tramp != null and tramp.has_method("bounce"):
			tramp.bounce()
		return
	if _current_sign != null and is_instance_valid(_current_sign):
		_is_fixing = true
		_fix_timer = _FIX_DURATION
		_anim(&"fix")
		SoundManager.play_robot_fix()
		# Fix immediately on arrival; timer is only for animation length.
		var sign := _current_sign
		_current_sign = null
		sign.apply_fix()


# ══════════════════════════════════════════════════════
#  ANIMATION
# ══════════════════════════════════════════════════════

func _update_anim(h_vel: Vector3) -> void:
	var on_floor := is_on_floor()

	# Sprite faces the direction of horizontal movement (using camera's right axis).
	if not _is_fixing and h_vel.length() > 0.01:
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			_sprite.flip_h = h_vel.dot(camera.global_transform.basis.x) < 0

	if _is_fixing:
		pass  # keep "fix"
	elif not on_floor and not _was_on_floor:
		_anim(&"jump")
		SoundManager.play_footstep()
	elif on_floor and not _was_on_floor:
		_anim(&"land")
	elif _sprite.animation == &"land" and _sprite.is_playing():
		pass  # let land finish
	elif h_vel.length() > 0.05:
		_anim(&"run")
		SoundManager.play_footstep()
	else:
		_anim(&"idle")

	_was_on_floor = on_floor


func _anim(name: StringName) -> void:
	if _sprite.animation != name:
		_sprite.play(name)


# ══════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════

func _get_sub_model() -> Node3D:
	if _sub_model == null:
		var subs := get_tree().get_nodes_in_group("submarine")
		if not subs.is_empty():
			_sub_model = subs[0].get_node_or_null("SubmarineModel")
	return _sub_model
