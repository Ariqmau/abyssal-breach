extends StaticBody3D


## Atlas coords of the idle (compressed/loaded) trampoline tile — default state.
@export var atlas_compressed : Vector2i = Vector2i(1, 9)
## Atlas coords of the extended trampoline tile — shown briefly on bounce.
@export var atlas_extended   : Vector2i = Vector2i(0, 9)
## Cell position of the trampoline in the TileMapLayer grid.
@export var trampoline_cell  : Vector2i = Vector2i(6, 5)
## How long the extended frame is shown before returning to compressed.
@export var extend_duration  : float = 0.20


var _tilemap    : TileMapLayer = null
var _anim_timer : float        = 0.0


func _ready() -> void:
	add_to_group("trampoline")
	collision_layer = 4
	collision_mask  = 0
	_tilemap = get_parent().get_node_or_null(
		"BackWallViewport/BackgroundTileMap/TileMapLayer"
	) as TileMapLayer
	if _tilemap == null:
		push_warning("Trampoline: TileMapLayer not found — check node path.")


func bounce() -> void:
	if _tilemap == null:
		return
	_tilemap.set_cell(trampoline_cell, 0, atlas_extended)
	_anim_timer = extend_duration


func _process(delta: float) -> void:
	if _anim_timer <= 0.0:
		return
	_anim_timer -= delta
	if _anim_timer <= 0.0 and _tilemap != null:
		_tilemap.set_cell(trampoline_cell, 0, atlas_compressed)
