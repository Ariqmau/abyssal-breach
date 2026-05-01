## submarine_lights.gd
##
## Attach to a SubmarineLights Node3D inside SubmarineModel.
## Manages two SpotLight3D (left / right) that react to hull damage.
##
## SCENE TREE (inside Submarine3D.tscn):
##   SubmarineModel (Node3D)
##   └── SubmarineLights (Node3D)  ← this script
##       ├── LightLeft  (SpotLight3D)   position (-1.2, 0, 1.5), rotation (0, 0, 0)
##       └── LightRight (SpotLight3D)   position ( 1.2, 0, 1.5), rotation (0, 0, 0)
##
## SpotLight3D recommended settings per light:
##   light_energy : 3.0
##   spot_range   : 35.0
##   spot_angle   : 40.0
##   light_color  : Color(0.85, 0.92, 1.0)   — cool blue-white submarine lamp
extends Node3D


# ══════════════════════════════════════════════════════
#  NODE REFERENCES
# ══════════════════════════════════════════════════════

@onready var _left  : SpotLight3D = $LightLeft
@onready var _right : SpotLight3D = $LightRight


# ══════════════════════════════════════════════════════
#  FLICKER STATE
# ══════════════════════════════════════════════════════

var _flicker_target : SpotLight3D = null
var _flicker_timer  : float       = 0.0


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	Globals.hull_integrity_changed.connect(_on_hull_changed)
	Globals.ship_destroyed.connect(_on_ship_destroyed)
	_apply_state(Globals.hull_integrity)


func _process(delta: float) -> void:
	if _flicker_target == null:
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		# Random interval between flicker toggles — shorter when near death.
		var interval := 0.06 if Globals.hull_integrity <= 1 else 0.15
		_flicker_timer        = randf_range(interval, interval * 3.0)
		_flicker_target.visible = not _flicker_target.visible


# ══════════════════════════════════════════════════════
#  SIGNAL HANDLERS
# ══════════════════════════════════════════════════════

func _on_hull_changed(hp: int) -> void:
	_apply_state(hp)


func _on_ship_destroyed() -> void:
	_flicker_target = null
	_left.visible   = false
	_right.visible  = false


# ══════════════════════════════════════════════════════
#  STATE MACHINE
# ══════════════════════════════════════════════════════

func _apply_state(hp: int) -> void:
	_flicker_target = null

	match hp:
		3:  # Full health — both lights bright.
			_set_light(_left,  true,  3.0)
			_set_light(_right, true,  3.0)

		2:  # One hit — left light damaged, dims and flickers.
			_set_light(_left,  true,  1.2)
			_set_light(_right, true,  3.0)
			_flicker_target = _left
			_flicker_timer  = 0.1

		1:  # Critical — left light dead, right flickering fast.
			_set_light(_left,  false, 0.0)
			_set_light(_right, true,  3.0)
			_flicker_target = _right
			_flicker_timer  = 0.05

		_:  # Dead — handled by _on_ship_destroyed.
			pass


func _set_light(light: SpotLight3D, on: bool, energy: float) -> void:
	light.visible      = on
	light.light_energy = energy
