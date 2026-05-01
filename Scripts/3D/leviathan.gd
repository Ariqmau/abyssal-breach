## leviathan.gd
##
## Follows the submarine left/right inside the cave.
## Every lunge_interval seconds it rushes the sub — but only deals damage
## if the sub is already slowed (hull < max), punishing weakened subs.
##
## Attach to a Node3D in Main.tscn. Drag Submarine3D into 'submarine' slot.
extends Node3D


# ══════════════════════════════════════════════════════
#  EXPORTED TUNABLES
# ══════════════════════════════════════════════════════

@export var submarine      : CharacterBody3D

## Distance kept behind the sub along +Z.
@export var chase_distance  : float = 15.0
## Max chase speed — slightly below sub full speed so player can escape.
@export var hunt_speed      : float = 19.0
## Rush speed during lunge.
@export var lunge_speed     : float = 40.0
## Speed returning to chase position after lunge.
@export var retreat_speed   : float = 14.0
## How close leviathan must be to its chase target before lunge is allowed.
@export var lunge_trigger_dist : float = 4.0
## Radius of the damage hitbox during a lunge (sphere at leviathan center).
@export var hit_range          : float = 10.0
## Minimum seconds between lunges.
@export var lunge_cooldown     : float = 5.0


# ══════════════════════════════════════════════════════
#  STATE MACHINE
# ══════════════════════════════════════════════════════

enum Phase { CHASE, LUNGE, RETREAT }

var _phase          : Phase   = Phase.CHASE
var _phase_timer    : float   = 0.0
var _lunge_cooldown : float   = 8.0   # longer first cooldown so player can orient
var _lunge_dir      : Vector3 = Vector3.ZERO
var _lunge_hit      : bool    = false
var _vel            : Vector3 = Vector3.ZERO
var _time           : float   = 0.0
var _smooth_fwd     : Vector3 = Vector3(0.0, 0.0, -1.0)


# ══════════════════════════════════════════════════════
#  VISUAL
# ══════════════════════════════════════════════════════

## Path to the imported .glb scene. Set this in the Inspector or change the path.
@export var model_scene  : PackedScene
## Uniform scale applied to the model on spawn. Adjust until it fits the cave.
@export var model_scale  : float = 1.0
## Rotation offset (degrees) applied to the model root to fix import orientation.
@export var model_rotation_deg : Vector3 = Vector3.ZERO

var _body     : Node3D     # root of the spawned model (or fallback capsule)
var _anim     : AnimationPlayer
var _eye_mats : Array[StandardMaterial3D] = []


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("leviathan")
	_build_body()

	if not submarine:
		submarine = get_tree().get_first_node_in_group("submarine") as CharacterBody3D
	if not submarine:
		_find_any_character_body()
	if not submarine:
		push_warning("Leviathan: drag Submarine3D into the 'submarine' export slot.")
		return

	global_position = submarine.global_position + Vector3(0.0, 0.0, chase_distance + 10.0)


func _process(delta: float) -> void:
	if not is_instance_valid(submarine):
		return
	_time        += delta
	_phase_timer -= delta

	if _lunge_cooldown > 0.0:
		_lunge_cooldown -= delta

	match _phase:
		Phase.CHASE:   _do_chase(delta)
		Phase.LUNGE:   _do_lunge(delta)
		Phase.RETREAT: _do_retreat(delta)

	_update_visual(delta)


# ══════════════════════════════════════════════════════
#  PHASE LOGIC
# ══════════════════════════════════════════════════════

func _do_chase(delta: float) -> void:
	var sub_pos := submarine.global_position

	# Chase target: directly behind the sub.
	var target    := Vector3(sub_pos.x, sub_pos.y * 0.5, sub_pos.z + chase_distance)
	var to_target := target - global_position
	var dist      := to_target.length()

	# Lunge fires when leviathan has caught up to its chase target
	# (within lunge_trigger_dist) AND cooldown is ready.
	if dist <= lunge_trigger_dist and _lunge_cooldown <= 0.0:
		_begin_lunge()
		return

	# Scale speed proportionally to distance — no overshoot, no vibration.
	var speed   := hunt_speed * clampf(dist / 8.0, 0.0, 1.0)
	var desired := to_target.normalized() * speed if dist > 0.01 else Vector3.ZERO

	_vel = _vel.lerp(desired, 5.0 * delta)
	global_position += _vel * delta


func _begin_lunge() -> void:
	_phase       = Phase.LUNGE
	_phase_timer = 0.75
	_lunge_dir   = (submarine.global_position - global_position).normalized()
	_lunge_hit   = false
	SoundManager.play_lev_lunge()


func _do_lunge(delta: float) -> void:
	# Partial tracking — curves toward sub so it's hard to dodge laterally.
	var to_sub := (submarine.global_position - global_position).normalized()
	_lunge_dir  = _lunge_dir.lerp(to_sub, 3.0 * delta).normalized()
	_vel        = _lunge_dir * lunge_speed
	global_position += _vel * delta

	# Hitbox: sphere at leviathan center. Fires once per lunge on contact.
	if not _lunge_hit and global_position.distance_to(submarine.global_position) < hit_range:
		_lunge_hit = true
		Globals.take_damage("leviathan")
		var cam := get_tree().get_first_node_in_group("camera_controller")
		if cam:
			cam.apply_shake(1.8)

	if _phase_timer <= 0.0:
		_phase          = Phase.RETREAT
		_phase_timer    = 2.0
		_lunge_cooldown = lunge_cooldown


func _do_retreat(delta: float) -> void:
	var sub_pos := submarine.global_position
	var target  := Vector3(sub_pos.x, sub_pos.y * 0.5, sub_pos.z + chase_distance)

	var to_target := target - global_position
	var dist      := to_target.length()
	var speed     := retreat_speed * clampf(dist / 6.0, 0.0, 1.0)
	var desired   := to_target.normalized() * speed if dist > 0.01 else Vector3.ZERO

	_vel = _vel.lerp(desired, 4.0 * delta)
	global_position += _vel * delta

	if _phase_timer <= 0.0:
		_phase = Phase.CHASE


# ══════════════════════════════════════════════════════
#  VISUAL
# ══════════════════════════════════════════════════════

func _update_visual(delta: float) -> void:
	if _vel.length() > 0.5:
		_smooth_fwd = _smooth_fwd.lerp(_vel.normalized(), 7.0 * delta).normalized()
	if _smooth_fwd.length() > 0.01:
		look_at(global_position + _smooth_fwd, Vector3.UP)

	if _body:
		_body.position.y = sin(_time * 2.4) * 0.35

	# Drive animations using exact GLB animation names.
	if _anim:
		var wanted : String
		match _phase:
			Phase.LUNGE:
				wanted = "model|model|GhostLevi_aggroSwimF|Base Layer"
			Phase.RETREAT:
				wanted = "model|model|GhostLevi_swimF|Base Layer"
			Phase.CHASE:
				wanted = "model|model|GhostLevi_swimF|Base Layer"
		if _anim.current_animation != wanted and _anim.has_animation(wanted):
			_anim.play(wanted)

	# Pulse procedural eye materials (only used by the fallback capsule body).
	var eye_energy := 8.0 + sin(_time * 6.0) * 2.0
	if _phase == Phase.LUNGE:
		eye_energy = 22.0
	for mat in _eye_mats:
		mat.emission_energy_multiplier = eye_energy


func _build_body() -> void:
	if model_scene:
		# ── GLB model path ──────────────────────────────
		_body = model_scene.instantiate() as Node3D
		_body.scale    = Vector3.ONE * model_scale
		_body.rotation = Vector3(
			deg_to_rad(model_rotation_deg.x),
			deg_to_rad(model_rotation_deg.y),
			deg_to_rad(model_rotation_deg.z)
		)
		add_child(_body)
		# Find the AnimationPlayer anywhere in the model tree.
		_anim = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim:
			_anim.play("model|model|GhostLevi_swimF|Base Layer")
	else:
		# ── Fallback procedural capsule ──────────────────
		var mesh_inst         := MeshInstance3D.new()
		var caps               := CapsuleMesh.new()
		caps.radius             = 3.5
		caps.height             = 18.0
		mesh_inst.mesh          = caps
		mesh_inst.rotation.x    = PI * 0.5

		var mat                       := StandardMaterial3D.new()
		mat.albedo_color               = Color(0.20, 0.45, 0.90)
		mat.roughness                  = 0.6
		mat.emission_enabled           = true
		mat.emission                   = Color(0.10, 0.35, 1.00)
		mat.emission_energy_multiplier = 4.0
		mesh_inst.material_override    = mat

		# Eyes — body-local (x,y,z) → parent (x,-z,y) due to rotation.x=PI/2.
		# Target parent offset (±1.4, +0.4, -7.0) → body local (±1.4, -7.0, -0.4).
		for side in [-1, 1]:
			var eye  := MeshInstance3D.new()
			var esph := SphereMesh.new()
			esph.radius = 0.55
			esph.height = 1.1
			eye.mesh    = esph
			var em                       := StandardMaterial3D.new()
			em.albedo_color               = Color(1.0, 0.10, 0.05)
			em.emission_enabled           = true
			em.emission                   = Color(1.0, 0.05, 0.0)
			em.emission_energy_multiplier = 8.0
			eye.material_override         = em
			eye.position                  = Vector3(float(side) * 1.4, -7.0, -0.4)
			mesh_inst.add_child(eye)
			_eye_mats.append(em)

		_body = mesh_inst
		add_child(_body)

	# Bioluminescent point light — works for both model and capsule.
	var light         := OmniLight3D.new()
	light.light_color  = Color(0.15, 0.45, 1.00)
	light.light_energy = 3.0
	light.omni_range   = 25.0
	add_child(light)


# ══════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════

func _find_any_character_body() -> void:
	_search_node(get_tree().root)


func _search_node(node: Node) -> void:
	if submarine:
		return
	if node is CharacterBody3D:
		submarine = node as CharacterBody3D
		return
	for child in node.get_children():
		_search_node(child)
