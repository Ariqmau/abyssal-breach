## warning_sign_3d.gd
## Attach to WarningSign3D (Area3D root).
## Robot clicks it → robot navigates here → robot calls apply_fix() once per visit.
## After _FIXES_NEEDED calls: hull is repaired + sign disappears.
extends Area3D


const _FIXES_NEEDED : int = 1

@onready var _sprite : AnimatedSprite3D = $AnimatedSprite3D

var _fix_count : int = 0


func _ready() -> void:
	# Layer 5 (value 16) — detectable by robot's raycast click.
	collision_layer = 16
	# Keep mask 8 (layer 4 robot) so body_entered fires if needed.
	collision_mask  = 8
	_sprite.play("damaged")


func apply_fix() -> void:
	_fix_count += 1
	if _fix_count >= _FIXES_NEEDED:
		Globals.repair_level()
		queue_free()
