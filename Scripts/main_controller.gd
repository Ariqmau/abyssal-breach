## main_controller.gd
##
## Attach to the root Node3D of Main.tscn.
## Responsibilities:
##   • Tab → Globals.toggle_mode() (3D ↔ 2D Dollhouse)
##   • V   → toggle rear-view PiP window (bottom-right corner)
##   • Smooth tween between cockpit and dollhouse cameras.
##   • Lock main camera to active marker every non-tween frame.
##   • Dynamic FOV based on current speed.
##   • Camera shake on hull damage.
extends Node3D


# ══════════════════════════════════════════════════════
#  NODE REFERENCES
# ══════════════════════════════════════════════════════

@onready var main_camera : Camera3D        = $MainCamera
@onready var submarine   : CharacterBody3D = $Submarine3D

@export var cam_cockpit   : Marker3D
@export var cam_dollhouse : Marker3D
@export var cam_back      : Marker3D


# ══════════════════════════════════════════════════════
#  EXPORTED TUNABLES
# ══════════════════════════════════════════════════════

@export var tween_duration : float = 1.2

## Size of the rear-view PiP window in pixels.
@export var pip_size : Vector2 = Vector2(300.0, 169.0)


# ══════════════════════════════════════════════════════
#  FOV
# ══════════════════════════════════════════════════════

const _FOV_FULL    : float = 95.0
const _FOV_PENALTY : float = 62.0
const _FOV_LERP    : float = 4.0

## Orthographic size for the dollhouse view — increase to zoom out.
@export var ortho_size   : float = 12.0
## Win distance in metres (speed × seconds). Default ≈ 5 min at max speed (20 m/s × 300 s).
@export var win_distance : float = 6000.0


# ══════════════════════════════════════════════════════
#  CAMERA SHAKE
# ══════════════════════════════════════════════════════

const _SHAKE_MAX   : float = 0.35
const _SHAKE_DECAY : float = 4.0

var _shake_trauma  : float = 0.0


# ══════════════════════════════════════════════════════
#  CAMERA TWEEN
# ══════════════════════════════════════════════════════

var _is_tweening    : bool        = false
var _tween_progress : float       = 0.0
var _tween_from     : Transform3D
var _tween_target   : Marker3D


# ══════════════════════════════════════════════════════
#  BACK CAMERA
# ══════════════════════════════════════════════════════

var _use_back_cam : bool = false


# ══════════════════════════════════════════════════════
#  PiP (picture-in-picture — shows opposite of main cam)
# ══════════════════════════════════════════════════════

var _pip_container : SubViewportContainer
var _pip_viewport  : SubViewport
var _pip_camera    : Camera3D
var _pip_label     : Label


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	if not cam_cockpit:
		cam_cockpit   = submarine.find_child("CamPos_Cockpit",   true, false) as Marker3D
	if not cam_dollhouse:
		cam_dollhouse = submarine.find_child("CamPos_Dollhouse", true, false) as Marker3D
	if not cam_back:
		cam_back      = submarine.find_child("CamPos_Back",      true, false) as Marker3D

	if not cam_cockpit:
		cam_cockpit = _make_marker("CamPos_Cockpit", Vector3(0.0, 0.5, 0.5), Vector3.ZERO)
	if not cam_dollhouse:
		cam_dollhouse = _make_marker("CamPos_Dollhouse", Vector3(0.0, 6.0, 14.0), Vector3(deg_to_rad(-20), deg_to_rad(180), 0.0))
	if not cam_back:
		cam_back = _make_marker("CamPos_Back", Vector3(0.0, 2.5, 9.0), Vector3(deg_to_rad(-10), deg_to_rad(180), 0.0))

	main_camera.global_transform = cam_cockpit.global_transform

	Globals.win_distance = win_distance
	Globals.reset()
	Globals.hull_integrity_changed.emit(Globals.hull_integrity)

	add_to_group("camera_controller")
	Globals.mode_changed.connect(_on_mode_changed)
	Globals.hull_integrity_changed.connect(_on_hull_changed_shake)
	Globals.ship_destroyed.connect(func(): apply_shake(1.5))

	_setup_pip()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("swap_mode"):
		Globals.toggle_mode()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			_use_back_cam = !_use_back_cam
			# In 3D: tween main cam.  In 2D: only PiP switches, dollhouse stays.
			if not Globals.is_in_2d_mode:
				_start_camera_tween(_use_back_cam_marker())


func _process(delta: float) -> void:
	_shake_trauma = maxf(_shake_trauma - _SHAKE_DECAY * delta, 0.0)

	_update_fov(delta)

	if _is_tweening:
		_step_camera_tween(delta)
	else:
		var target := cam_dollhouse if Globals.is_in_2d_mode else _use_back_cam_marker()
		main_camera.global_transform = target.global_transform

	_apply_camera_shake()

	# PiP: C toggles front/back in both modes.
	# In 3D: shows the opposite of main cam.
	# In 2D: main cam is dollhouse; PiP mirrors _use_back_cam toggle.
	var pip_marker : Marker3D
	if _use_back_cam:
		pip_marker      = cam_cockpit if not Globals.is_in_2d_mode else cam_back
		_pip_label.text = "FRONT" if not Globals.is_in_2d_mode else "REAR"
	else:
		pip_marker      = cam_back if not Globals.is_in_2d_mode else cam_cockpit
		_pip_label.text = "REAR" if not Globals.is_in_2d_mode else "FRONT"
	_pip_camera.global_transform = pip_marker.global_transform


# ══════════════════════════════════════════════════════
#  FOV
# ══════════════════════════════════════════════════════

func _update_fov(delta: float) -> void:
	if Globals.is_in_2d_mode:
		return
	var speed_ratio := Globals.current_speed / Globals.base_speed
	var target_fov  := lerpf(_FOV_PENALTY, _FOV_FULL, speed_ratio)
	main_camera.fov  = lerpf(main_camera.fov, target_fov, _FOV_LERP * delta)


# ══════════════════════════════════════════════════════
#  CAMERA SHAKE
# ══════════════════════════════════════════════════════

func _on_hull_changed_shake(_hp: int) -> void:
	apply_shake(1.0)


func apply_shake(trauma: float) -> void:
	_shake_trauma = clampf(_shake_trauma + trauma, 0.0, 2.0)


func _apply_camera_shake() -> void:
	if _shake_trauma <= 0.0 or Globals.is_in_2d_mode:
		return
	var amount := _shake_trauma * _shake_trauma
	var basis  := main_camera.global_transform.basis
	main_camera.global_position += basis.x * randf_range(-1.0, 1.0) * _SHAKE_MAX * amount
	main_camera.global_position += basis.y * randf_range(-1.0, 1.0) * _SHAKE_MAX * amount


# ══════════════════════════════════════════════════════
#  CAMERA TWEEN
# ══════════════════════════════════════════════════════

func _on_mode_changed(in_2d_mode: bool) -> void:
	var target := cam_dollhouse if in_2d_mode else _use_back_cam_marker()
	_start_camera_tween(target)
	if in_2d_mode:
		_use_back_cam = false
	else:
		main_camera.projection = Camera3D.PROJECTION_PERSPECTIVE


func _start_camera_tween(to_marker: Marker3D) -> void:
	_tween_from     = main_camera.global_transform
	_tween_target   = to_marker
	_tween_progress = 0.0
	_is_tweening    = true


func _step_camera_tween(delta: float) -> void:
	_tween_progress += delta / tween_duration
	_tween_progress  = minf(_tween_progress, 1.0)

	var t := smoothstep(0.0, 1.0, _tween_progress)
	main_camera.global_transform = _tween_from.interpolate_with(
		_tween_target.global_transform, t
	)

	if _tween_progress >= 1.0:
		_is_tweening = false
		if Globals.is_in_2d_mode:
			main_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			main_camera.size       = ortho_size
		Globals.mode_tween_finished.emit(Globals.is_in_2d_mode)


# ══════════════════════════════════════════════════════
#  PiP SETUP
# ══════════════════════════════════════════════════════

func _setup_pip() -> void:
	var canvas        := CanvasLayer.new()
	canvas.layer       = 10
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # must not eat input from lower layers
	canvas.add_child(root)

	var margin : float = 14.0
	var border : float = 2.0

	# Blue border frame behind the viewport.
	var frame       := ColorRect.new()
	frame.color      = Color(0.20, 0.55, 0.90, 0.90)
	frame.size       = Vector2(pip_size.x + border * 2.0, pip_size.y + border * 2.0)
	frame.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	frame.position   = Vector2(-(pip_size.x + border * 2.0 + margin), -(pip_size.y + border * 2.0 + margin))
	root.add_child(frame)

	# Label above the window — updated each frame to FRONT or REAR.
	_pip_label     = Label.new()
	_pip_label.text = "REAR"
	_pip_label.add_theme_font_size_override("font_size", 10)
	_pip_label.add_theme_color_override("font_color", Color(0.80, 0.95, 1.00))
	_pip_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pip_label.position = Vector2(-(pip_size.x + margin - 4.0), -(pip_size.y + margin + border * 2.0 + 14.0))
	root.add_child(_pip_label)

	# SubViewportContainer — hosts the SubViewport texture.
	_pip_container          = SubViewportContainer.new()
	_pip_container.size      = pip_size
	_pip_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pip_container.position  = Vector2(-(pip_size.x + margin), -(pip_size.y + margin))
	_pip_container.visible   = true
	root.add_child(_pip_container)

	# SubViewport shares the main World3D so it renders the same scene.
	_pip_viewport                       = SubViewport.new()
	_pip_viewport.size                   = Vector2i(int(pip_size.x), int(pip_size.y))
	_pip_viewport.own_world_3d           = false
	_pip_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pip_container.add_child(_pip_viewport)

	# Camera inside the SubViewport — transform is updated each frame.
	_pip_camera = Camera3D.new()
	_pip_viewport.add_child(_pip_camera)


# ══════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════

func _use_back_cam_marker() -> Marker3D:
	return cam_back if _use_back_cam else cam_cockpit


func _make_marker(n: String, pos: Vector3, rot: Vector3) -> Marker3D:
	var m     := Marker3D.new()
	m.name     = n
	m.position = pos
	m.rotation = rot
	submarine.add_child(m)
	return m
