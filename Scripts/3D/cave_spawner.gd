## cave_spawner.gd
##
## Spawns oval, rough-walled cave tunnel segments ahead of the submarine.
## Stalactites / stalagmites / columns are procedural Area3D obstacles.
extends Node3D


# ══════════════════════════════════════════════════════
#  EXPORTED TUNABLES
# ══════════════════════════════════════════════════════

@export var submarine          : CharacterBody3D

@export var segment_length     : float = 30.0
@export var segments_ahead     : int   = 10

## Inner radius of the tunnel (open space). Must exceed sub's x_boundary (11.0).
@export var tunnel_radius      : float = 13.0

## Number of sides for the circular cross-section mesh.
@export var tube_sides         : int   = 20

## Thickness of the outer wall shell (visible in 2D dollhouse mode).
@export var wall_thickness     : float = 18.0

## Max random shift of the cave centre per segment — creates winding.
@export var meander_x          : float = 0.8
@export var meander_y          : float = 0.4
@export var meander_clamp_x    : float = 2.0
@export var meander_clamp_y    : float = 1.2

@export var formation_max      : int   = 6
@export var stalactite_min_len : float = 3.5
@export var stalactite_max_len : float = 9.0
@export var stalactite_min_r   : float = 0.8
@export var stalactite_max_r   : float = 2.2

## Chance (0–1) per formation slot that a column spawns instead.
@export var column_chance      : float = 0.06

## Chance (0–1) that a stalactite slot also gets a matching stalagmite from the floor.
@export var stalagmite_chance  : float = 0.70

## How many reward orbs spawn per tunnel segment.
@export var rewards_per_segment : int   = 2
## Score added when the sub collects one orb.
@export var reward_value        : int   = 50


# ══════════════════════════════════════════════════════
#  SHAPE CONSTANTS
# ══════════════════════════════════════════════════════

const _REWARD_SCRIPT = preload("res://Scripts/3D/reward_crystal.gd")

const _OVAL_Y       : float = 0.72
const _SEAM_OVERLAP : float = 2.0
const _N_SLICES     : int   = 7
const _RIB_AMP      : float = 0.22
const _RIB_FREQ     : float = 0.18


# ══════════════════════════════════════════════════════
#  INTERNAL STATE
# ══════════════════════════════════════════════════════

var _next_z   : float         = 0.0
var _centre   : Vector2       = Vector2.ZERO
var _segments : Array[Node3D] = []

var _wall_mat  : StandardMaterial3D
var _outer_mat : StandardMaterial3D
var _stala_mat : StandardMaterial3D


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	if not submarine:
		push_error("CaveSpawner: 'submarine' export not set!")
		return
	_build_materials()
	_next_z = submarine.global_position.z
	for i in range(segments_ahead):
		_spawn_segment()


func _process(_delta: float) -> void:
	if not is_instance_valid(submarine):
		return
	while _next_z > submarine.global_position.z - segments_ahead * segment_length:
		_spawn_segment()
	_prune_old_segments()


# ══════════════════════════════════════════════════════
#  SPAWNING
# ══════════════════════════════════════════════════════

func _spawn_segment() -> void:
	_centre.x = clamp(_centre.x + randf_range(-meander_x, meander_x), -meander_clamp_x, meander_clamp_x)
	_centre.y = clamp(_centre.y + randf_range(-meander_y, meander_y), -meander_clamp_y, meander_clamp_y)

	var seg := Node3D.new()
	add_child(seg)
	seg.global_position = Vector3(_centre.x, _centre.y, _next_z)

	_add_tube_inner(seg)
	_add_tube_outer(seg)
	_build_formations(seg)
	_build_rewards(seg)

	_segments.append(seg)
	_next_z -= segment_length


func _add_tube_inner(seg: Node3D) -> void:
	var vis     := MeshInstance3D.new()
	var seg_mat := _wall_mat.duplicate() as StandardMaterial3D
	var tint    := sin(seg.global_position.z * 0.03) * 0.02
	seg_mat.albedo_color = _wall_mat.albedo_color + Color(tint, tint * 0.8, tint * 0.5)
	vis.mesh     = _build_tube_mesh(tunnel_radius, segment_length + _SEAM_OVERLAP * 2.0,
									seg_mat, seg.global_position.z, true)
	vis.position = Vector3(0.0, 0.0, -segment_length * 0.5)
	seg.add_child(vis)


func _add_tube_outer(seg: Node3D) -> void:
	# Solid outer shell — gives cave walls visible thickness in 2D dollhouse view.
	var vis      := MeshInstance3D.new()
	var outer_r  := tunnel_radius + wall_thickness
	vis.mesh      = _build_tube_mesh(outer_r, segment_length + _SEAM_OVERLAP * 2.0,
									 _outer_mat, seg.global_position.z, false)
	vis.position  = Vector3(0.0, 0.0, -segment_length * 0.5)
	seg.add_child(vis)


# ══════════════════════════════════════════════════════
#  FORMATIONS (stalactites / stalagmites / columns)
# ══════════════════════════════════════════════════════

func _build_formations(seg: Node3D) -> void:
	var count := randi_range(2, formation_max)
	for i in range(count):
		var x_offset := randf_range(-(tunnel_radius - 3.0), tunnel_radius - 3.0)
		var z_offset := randf_range(-segment_length * 0.9, -segment_length * 0.1)
		var arc_y    := sqrt(maxf(0.0, tunnel_radius * tunnel_radius - x_offset * x_offset)) \
						* _OVAL_Y

		if randf() < column_chance:
			_add_column(seg, x_offset, z_offset, arc_y)
			continue

		# Stalactite from ceiling.
		var s_len  := randf_range(stalactite_min_len, stalactite_max_len)
		var s_base := randf_range(stalactite_min_r,   stalactite_max_r)
		_add_stalactite(seg, Vector3(x_offset, arc_y, z_offset), s_base, s_len, -1.0)

		# Stalagmite from floor.
		if randf() < stalagmite_chance:
			var m_len  := randf_range(stalactite_min_len * 0.7, stalactite_max_len * 0.7)
			var m_base := randf_range(stalactite_min_r,         stalactite_max_r * 0.8)
			_add_stalactite(seg, Vector3(x_offset, -arc_y, z_offset), m_base, m_len, 1.0)


func _add_stalactite(
		seg      : Node3D,
		root_pos : Vector3,
		base_r   : float,
		length   : float,
		dir_y    : float
) -> void:
	var area  := Area3D.new()
	var col   := CollisionShape3D.new()
	var cap_s := CapsuleShape3D.new()
	cap_s.radius = maxf(base_r * 0.9, 0.8)
	cap_s.height = length * 0.7
	col.shape    = cap_s
	area.add_child(col)

	_mesh_stala(area, base_r, length, dir_y)

	seg.add_child(area)
	area.position        = root_pos + Vector3(0.0, dir_y * length * 0.5, 0.0)
	area.monitoring      = true
	area.monitorable     = false
	area.collision_layer = 0
	area.collision_mask  = 2
	area.set_meta("hit_reported", false)
	area.body_entered.connect(_on_formation_hit.bind(area))


# Two tapered sections with lateral drift — no straight cylinders, natural droop.
func _mesh_stala(parent: Node3D, base_r: float, length: float, dir_y: float) -> void:
	# Flattened blob at ceiling/floor attachment.
	var blob  := MeshInstance3D.new()
	var bsph  := SphereMesh.new()
	bsph.radius = base_r * 0.85
	bsph.height = base_r * 0.45
	bsph.surface_set_material(0, _stala_mat)
	blob.mesh     = bsph
	blob.position = Vector3(0.0, dir_y * -length * 0.5, 0.0)
	parent.add_child(blob)

	var mid_r := base_r * randf_range(0.28, 0.50)
	var sec1  := length * 0.60
	var sec2  := length - sec1

	# Independent lateral offsets per section — creates organic droop.
	var dx1 := randf_range(-0.25, 0.25) * base_r
	var dz1 := randf_range(-0.20, 0.20) * base_r
	var dx2 := dx1 + randf_range(-0.35, 0.35) * mid_r
	var dz2 := dz1 + randf_range(-0.25, 0.25) * mid_r

	# Upper section: wide base → mid.
	var v1 := MeshInstance3D.new()
	var c1 := CylinderMesh.new()
	c1.top_radius    = base_r if dir_y < 0.0 else mid_r
	c1.bottom_radius = mid_r  if dir_y < 0.0 else base_r
	c1.height        = sec1
	c1.radial_segments = 6
	c1.surface_set_material(0, _stala_mat)
	v1.mesh     = c1
	v1.position = Vector3(dx1, dir_y * (-length * 0.5 + sec1 * 0.5), dz1)
	parent.add_child(v1)

	# Lower section: mid → sharp tip.
	var v2 := MeshInstance3D.new()
	var c2 := CylinderMesh.new()
	c2.top_radius    = mid_r if dir_y < 0.0 else 0.07
	c2.bottom_radius = 0.07  if dir_y < 0.0 else mid_r
	c2.height        = sec2
	c2.radial_segments = 6
	c2.surface_set_material(0, _stala_mat)
	v2.mesh     = c2
	v2.position = Vector3(dx2, dir_y * (-length * 0.5 + sec1 + sec2 * 0.5), dz2)
	parent.add_child(v2)

	# Small drip sphere at tip (60 % chance).
	if randf() > 0.4:
		var tip  := MeshInstance3D.new()
		var tsph := SphereMesh.new()
		tsph.radius = 0.15
		tsph.height = 0.30
		tsph.surface_set_material(0, _stala_mat)
		tip.mesh     = tsph
		tip.position = Vector3(dx2, dir_y * length * 0.5, dz2)
		parent.add_child(tip)


func _add_column(seg: Node3D, x_offset: float, z_offset: float, arc_y: float) -> void:
	var height := arc_y * 2.0
	var radius := randf_range(0.9, 2.2)

	var area  := Area3D.new()
	var col   := CollisionShape3D.new()
	var cap_s := CapsuleShape3D.new()
	cap_s.radius = radius * 1.1
	cap_s.height = height * 0.6
	col.shape    = cap_s
	area.add_child(col)

	_mesh_column(area, radius, height)

	seg.add_child(area)
	area.position        = Vector3(x_offset, 0.0, z_offset)
	area.monitoring      = true
	area.monitorable     = false
	area.collision_layer = 0
	area.collision_mask  = 2
	area.set_meta("hit_reported", false)
	area.body_entered.connect(_on_formation_hit.bind(area))


# Two tapered halves meeting at a pinched neck — natural stalactite-meets-stalagmite.
func _mesh_column(parent: Node3D, radius: float, height: float) -> void:
	var half   := height * 0.5
	var neck_r := radius * randf_range(0.45, 0.68)

	# Slight lean shared by both halves so column curves as one piece.
	var dx := randf_range(-0.18, 0.18) * radius
	var dz := randf_range(-0.12, 0.12) * radius

	# Ceiling and floor attachment blobs.
	_add_bulge(parent, radius * 0.82,  half)
	_add_bulge(parent, radius * 0.82, -half)

	# Top half: ceiling (radius) → neck (narrow).
	var vt := MeshInstance3D.new()
	var ct := CylinderMesh.new()
	ct.top_radius    = radius
	ct.bottom_radius = neck_r
	ct.height        = half
	ct.radial_segments = 7
	ct.surface_set_material(0, _stala_mat)
	vt.mesh     = ct
	vt.position = Vector3(dx * 0.4, half * 0.5, dz * 0.4)
	parent.add_child(vt)

	# Bottom half: floor (radius) → neck (narrow).
	var vb := MeshInstance3D.new()
	var cb := CylinderMesh.new()
	cb.top_radius    = neck_r
	cb.bottom_radius = radius
	cb.height        = half
	cb.radial_segments = 7
	cb.surface_set_material(0, _stala_mat)
	vb.mesh     = cb
	vb.position = Vector3(dx * 0.4, -half * 0.5, dz * 0.4)
	parent.add_child(vb)


func _add_bulge(parent: Node3D, radius: float, local_y: float) -> void:
	var bulge := MeshInstance3D.new()
	var sph   := SphereMesh.new()
	sph.radius = radius * 0.9
	sph.height = radius * 0.65
	sph.surface_set_material(0, _stala_mat)
	bulge.mesh     = sph
	bulge.position = Vector3(0.0, local_y, 0.0)
	parent.add_child(bulge)


func _on_formation_hit(body: Node3D, area: Area3D) -> void:
	if not (body is CharacterBody3D):
		return
	if area.get_meta("hit_reported"):
		return
	area.set_meta("hit_reported", true)
	Globals.take_damage("stalactite")


# ══════════════════════════════════════════════════════
#  REWARDS
# ══════════════════════════════════════════════════════

func _build_rewards(seg: Node3D) -> void:
	var mat                        := StandardMaterial3D.new()
	mat.albedo_color                = Color(0.0, 0.85, 0.70)
	mat.emission_enabled            = true
	mat.emission                    = Color(0.0, 1.0, 0.75)
	mat.emission_energy_multiplier  = 4.0
	mat.roughness                   = 0.15

	for i in range(rewards_per_segment):
		var x   := randf_range(-(tunnel_radius - 4.5), tunnel_radius - 4.5)
		var z   := randf_range(-segment_length * 0.85, -segment_length * 0.15)
		var y   := randf_range(-2.5, 2.5)

		var area := Area3D.new()
		area.set_script(_REWARD_SCRIPT)

		# Sphere mesh.
		var vis := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.45
		sph.height = 0.90
		sph.surface_set_material(0, mat)
		vis.mesh = sph
		area.add_child(vis)

		# Soft point light.
		var light        := OmniLight3D.new()
		light.light_color = Color(0.0, 1.0, 0.75)
		light.light_energy = 2.5
		light.omni_range   = 5.5
		area.add_child(light)

		# Collision sphere.
		var col   := CollisionShape3D.new()
		var sph_s := SphereShape3D.new()
		sph_s.radius = 0.85
		col.shape    = sph_s
		area.add_child(col)

		area.position = Vector3(x, y, z)
		seg.add_child(area)
		area._value = reward_value


# ══════════════════════════════════════════════════════
#  PRUNING
# ══════════════════════════════════════════════════════

func _prune_old_segments() -> void:
	var sub_z      := submarine.global_position.z
	var keep_behind := segment_length * 5
	for i in range(_segments.size() - 1, -1, -1):
		var seg := _segments[i]
		if not is_instance_valid(seg):
			_segments.remove_at(i)
		elif seg.global_position.z > sub_z + keep_behind:
			seg.queue_free()
			_segments.remove_at(i)


# ══════════════════════════════════════════════════════
#  TUBE MESH BUILDER
# ══════════════════════════════════════════════════════

func _build_tube_mesh(radius: float, length: float, mat: StandardMaterial3D = null,
		world_z_start: float = 0.0, inward: bool = true) -> ArrayMesh:
	var verts   := PackedVector3Array()
	var norms   := PackedVector3Array()
	var uvs     := PackedVector2Array()
	var indices := PackedInt32Array()
	var sides   := tube_sides
	var slices  := _N_SLICES

	for s in range(slices):
		var t     := float(s) / float(slices - 1)
		var z_loc := -length * 0.5 + t * length
		var z_w   := world_z_start + z_loc

		var r_mod := 1.0 \
			+ sin(z_w * _RIB_FREQ) * _RIB_AMP \
			+ cos(z_w * _RIB_FREQ * 0.63 + 1.4) * (_RIB_AMP * 0.45)
		var r := radius * r_mod

		var jz := sin(z_w * 31.7) * 0.7

		for i in range(sides):
			var a  := TAU * i / sides
			var ca := cos(a)
			var sa := sin(a)
			verts.append(Vector3(ca * r, sa * r * _OVAL_Y, z_loc + jz))
			var nx := -ca if inward else ca
			var ny := (-sa / _OVAL_Y) if inward else (sa / _OVAL_Y)
			norms.append(Vector3(nx, ny, 0.0).normalized())
			uvs.append(Vector2(float(i) / sides, t))

	for s in range(slices - 1):
		for i in range(sides):
			var n  := (i + 1) % sides
			var v0 := s       * sides + i
			var v1 := s       * sides + n
			var v2 := (s + 1) * sides + i
			var v3 := (s + 1) * sides + n
			if inward:
				indices.append(v0); indices.append(v1); indices.append(v2)
				indices.append(v1); indices.append(v3); indices.append(v2)
			else:
				indices.append(v0); indices.append(v2); indices.append(v1)
				indices.append(v1); indices.append(v2); indices.append(v3)

	var arr := Array()
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat if mat else _wall_mat)
	return mesh


# ══════════════════════════════════════════════════════
#  MATERIALS
# ══════════════════════════════════════════════════════

func _build_materials() -> void:
	_wall_mat              = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.32, 0.28, 0.22)
	_wall_mat.roughness    = 0.95
	_wall_mat.metallic     = 0.0

	_outer_mat              = StandardMaterial3D.new()
	_outer_mat.albedo_color = Color(0.18, 0.15, 0.11)
	_outer_mat.roughness    = 1.0
	_outer_mat.metallic     = 0.0
	_outer_mat.cull_mode    = BaseMaterial3D.CULL_DISABLED

	_stala_mat              = StandardMaterial3D.new()
	_stala_mat.albedo_color = Color(0.28, 0.24, 0.18)
	_stala_mat.roughness    = 0.9
	_stala_mat.metallic     = 0.05
