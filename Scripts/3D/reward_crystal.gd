## reward_crystal.gd
## Glowing collectible orb. Spawned by cave_spawner inside the tunnel.
## Attach to an Area3D — cave_spawner sets _value after add_child.
extends Area3D

var _value       : int   = 50
var _time        : float = 0.0
var _origin_y    : float = 0.0
var _initialized : bool  = false


func _ready() -> void:
	monitoring      = true
	monitorable     = false
	collision_layer = 0
	collision_mask  = 2
	body_entered.connect(_collect)


func _process(delta: float) -> void:
	if not _initialized:
		_origin_y    = position.y
		_initialized = true
	_time      += delta
	position.y  = _origin_y + sin(_time * 1.8) * 0.28


func _collect(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return
	Globals.collect_reward(_value)
	queue_free()
