## trampoline_3d.gd
## Attach to the Trampoline StaticBody3D inside the submarine interior.
## Robot detects this group in its collision loop and auto-launches upward.
extends StaticBody3D


func _ready() -> void:
	add_to_group("trampoline")
	collision_layer = 4  # same as Floor1/Floor2 — robot collision_mask=4 can land here
	collision_mask  = 0
