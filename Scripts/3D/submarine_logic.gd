## submarine_logic.gd
##
## Attach to the root CharacterBody3D of Submarine3D.tscn.
## Auto-moves forward (-Z). Player steers X/Y.
## Speed is set entirely by Globals.current_speed (driven by hull_integrity level).
extends CharacterBody3D


# ══════════════════════════════════════════════════════
#  EXPORTED TUNABLES
# ══════════════════════════════════════════════════════

@export var steer_speed        : float = 12.0
@export var steer_acceleration : float = 4.0
@export var steer_damping      : float = 5.0

@export var x_boundary         : float = 9.5
@export var y_boundary         : float = 7.0

@export var max_bank_angle     : float = 22.0
@export var max_pitch_angle    : float = 18.0
@export var tilt_speed         : float = 2.5


# ══════════════════════════════════════════════════════
#  NODE REFERENCES
# ══════════════════════════════════════════════════════

@onready var _model            : Node3D         = $SubmarineModel
@onready var _sub_samping      : Node3D         = $SubmarineModel/Sub_samping
@onready var _interior         : Node3D         = find_child("Interior",         true, false)
@onready var _back_wall_mesh   : MeshInstance3D = find_child("BackWall",         true, false)
@onready var _back_wall_vp     : SubViewport    = find_child("BackWallViewport", true, false)
@onready var _sign_slots       : Node3D         = find_child("SignSlots",        true, false)


# ══════════════════════════════════════════════════════
#  WARNING SIGN MANAGER
# ══════════════════════════════════════════════════════

const _SIGN_SCENE := preload("res://Scenes/2D/WarningSign3D.tscn")

var _prev_hull : int = 5


# ══════════════════════════════════════════════════════
#  INTERNAL STATE
# ══════════════════════════════════════════════════════

var _steering_enabled : bool    = true
var _steer_velocity   : Vector2 = Vector2.ZERO
var _knockback        : Vector3 = Vector3.ZERO
var _game_over        : bool    = false


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("submarine")
	Globals.mode_changed.connect(_on_mode_changed)
	Globals.mode_tween_finished.connect(_on_mode_tween_finished)
	Globals.hull_integrity_changed.connect(_on_hull_changed)
	Globals.ship_destroyed.connect(_on_ship_destroyed)
	_prev_hull = Globals.hull_integrity
	_interior.visible    = false
	_sub_samping.visible = true
	_setup_backwall_texture()


func _physics_process(delta: float) -> void:
	if _game_over:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_apply_movement(delta)
	_clamp_to_boundary()
	_check_wall_graze()
	_update_visual_tilt(delta)


# ══════════════════════════════════════════════════════
#  MOVEMENT
# ══════════════════════════════════════════════════════

func _apply_movement(delta: float) -> void:
	var input := Vector2.ZERO

	if _steering_enabled:
		input.x = Input.get_axis("move_left",  "move_right")
		input.y = Input.get_axis("move_down", "move_up")

	if input.length() > 0.0:
		_steer_velocity = _steer_velocity.lerp(input * steer_speed, steer_acceleration * delta)
	else:
		_steer_velocity = _steer_velocity.lerp(Vector2.ZERO, steer_damping * delta)

	_knockback = _knockback.lerp(Vector3.ZERO, 14.0 * delta)

	velocity = Vector3(
		_steer_velocity.x,
		_steer_velocity.y,
		-Globals.current_speed
	) + _knockback
	move_and_slide()


func _clamp_to_boundary() -> void:
	var p  := global_position
	var ex := p.x / x_boundary
	var ey := p.y / y_boundary
	var el := sqrt(ex * ex + ey * ey)
	if el > 1.0:
		p.x = (ex / el) * x_boundary
		p.y = (ey / el) * y_boundary
	global_position = p


func _check_wall_graze() -> void:
	if not _steering_enabled:
		return
	var p  := global_position
	var ex := p.x / x_boundary
	var ey := p.y / y_boundary
	if ex * ex + ey * ey < 0.81:
		return
	var input_x := Input.get_axis("move_left",  "move_right")
	var input_y := Input.get_axis("move_down", "move_up")
	if ex * input_x + ey * input_y > 0.2:
		Globals.take_damage("wall")


# ══════════════════════════════════════════════════════
#  VISUAL TILT
# ══════════════════════════════════════════════════════

func _update_visual_tilt(delta: float) -> void:
	var ratio_x := _steer_velocity.x / steer_speed
	var ratio_y := _steer_velocity.y / steer_speed
	_model.rotation.x = lerp_angle(_model.rotation.x,  ratio_y * deg_to_rad(max_pitch_angle), tilt_speed * delta)
	_model.rotation.z = lerp_angle(_model.rotation.z, -ratio_x * deg_to_rad(max_bank_angle),  tilt_speed * delta)


# ══════════════════════════════════════════════════════
#  SIGNAL HANDLERS
# ══════════════════════════════════════════════════════

func _setup_backwall_texture() -> void:
	# Assign ViewportTexture via script — Inspector path resolution fails in instanced scenes.
	var vt  : ViewportTexture    = _back_wall_vp.get_texture()
	var quad: QuadMesh           = _back_wall_mesh.mesh as QuadMesh
	var mat : StandardMaterial3D = (quad.material as StandardMaterial3D).duplicate()
	mat.albedo_color   = Color.WHITE
	mat.albedo_texture = vt
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	_back_wall_mesh.material_override = mat


func _on_mode_changed(in_2d_mode: bool) -> void:
	_interior.visible = in_2d_mode
	if not in_2d_mode:
		_sub_samping.visible = true   # show immediately when returning to 3D


func _on_mode_tween_finished(in_2d_mode: bool) -> void:
	if in_2d_mode:
		_sub_samping.visible = false  # hide only after tween completes


func _on_hull_changed(hp: int) -> void:
	# Knockback on any hit.
	_knockback = Vector3(
		randf_range(-3.0, 3.0),
		randf_range(-2.0, 2.0),
		randf_range(-2.0, 2.0)
	) * 12.0
	# Spawn a warning sign only when hull decreases (damage, not repair).
	if hp < _prev_hull:
		_spawn_warning_sign()
	_prev_hull = hp


func _spawn_warning_sign() -> void:
	if _sign_slots == null:
		return
	# Collect slots that have no sign child yet.
	var free_slots : Array = []
	for slot in _sign_slots.get_children():
		if slot.get_child_count() == 0:
			free_slots.append(slot)
	if free_slots.is_empty():
		return
	var slot : Node3D = free_slots[randi() % free_slots.size()]
	var sign          = _SIGN_SCENE.instantiate()
	slot.add_child(sign)
	sign.position = Vector3.ZERO  # sit exactly at marker position


func _on_ship_destroyed() -> void:
	_game_over      = true
	_steer_velocity = Vector2.ZERO
	_knockback      = Vector3.ZERO
