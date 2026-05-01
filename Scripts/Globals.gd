## Globals.gd  ─  Autoload Singleton
extends Node


# ══════════════════════════════════════════════════════
#  SIGNALS
# ══════════════════════════════════════════════════════

signal mode_changed(in_2d_mode: bool)
signal mode_tween_finished(in_2d_mode: bool)
signal hull_integrity_changed(new_hp: int)
signal ship_destroyed()
signal reward_collected(value: int)
signal game_won()


# ══════════════════════════════════════════════════════
#  SPEED LEVELS
#  Index = hull_integrity.  Hull 0 = game over.
# ══════════════════════════════════════════════════════

const SPEED_LEVELS : Array[float] = [0.0, 4.0, 8.0, 12.0, 16.0, 20.0]


# ══════════════════════════════════════════════════════
#  GAME STATE
# ══════════════════════════════════════════════════════

var current_speed      : float = 20.0
var base_speed         : float = 20.0
var is_in_2d_mode      : bool  = false

var hull_integrity     : int   = 5
var max_hull_integrity : int   = 5

var score              : int   = 0
var high_score         : int   = 0

## Accumulated travel distance (units = metres at current_speed m/s).
## Win triggers when this reaches win_distance.
var distance_traveled  : float = 0.0
## Set by main_controller from its @export so it's tweakable per-scene.
var win_distance       : float = 6000.0


# ══════════════════════════════════════════════════════
#  INTERNAL
# ══════════════════════════════════════════════════════

const _DAMAGE_COOLDOWN : float  = 1.5
const _SAVE_PATH       : String = "user://abyssal_breach.cfg"

var _damage_timer    : float = 0.0
var _game_won_fired  : bool  = false


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	_load_data()


func _process(delta: float) -> void:
	if _damage_timer > 0.0:
		_damage_timer -= delta

	if hull_integrity > 0 and current_speed > 0.0:
		var gain := current_speed * delta
		score             += int(gain)
		distance_traveled += gain
		if score > high_score:
			high_score = score
		if not _game_won_fired and distance_traveled >= win_distance:
			_game_won_fired = true
			_save_data()
			game_won.emit()


# ══════════════════════════════════════════════════════
#  PUBLIC API
# ══════════════════════════════════════════════════════

func take_damage(source: String = "") -> void:
	if hull_integrity <= 0:
		return
	if source != "leviathan" and _damage_timer > 0.0:
		return
	_damage_timer   = _DAMAGE_COOLDOWN
	hull_integrity -= 1
	print("[HIT: %s] Hull %d/%d  speed→%.0f" % [source, hull_integrity, max_hull_integrity, SPEED_LEVELS[hull_integrity]])
	if hull_integrity <= 0:
		current_speed = 0.0
		_save_data()
		ship_destroyed.emit()
		return
	current_speed = SPEED_LEVELS[hull_integrity]
	hull_integrity_changed.emit(hull_integrity)


func repair_level() -> void:
	if hull_integrity >= max_hull_integrity:
		return
	hull_integrity += 1
	current_speed = SPEED_LEVELS[hull_integrity]
	hull_integrity_changed.emit(hull_integrity)


func collect_reward(value: int) -> void:
	score += value
	if score > high_score:
		high_score = score
	reward_collected.emit(value)


func toggle_mode() -> void:
	is_in_2d_mode = !is_in_2d_mode
	mode_changed.emit(is_in_2d_mode)


## Call before loading / reloading the game scene to start fresh.
func reset() -> void:
	score             = 0
	hull_integrity    = max_hull_integrity
	current_speed     = SPEED_LEVELS[hull_integrity]
	base_speed        = SPEED_LEVELS[hull_integrity]
	distance_traveled = 0.0
	is_in_2d_mode     = false
	_damage_timer     = 0.0
	_game_won_fired   = false


# ══════════════════════════════════════════════════════
#  PERSISTENCE
# ══════════════════════════════════════════════════════

func _save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("data", "high_score", high_score)
	cfg.save(_SAVE_PATH)


func _load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SAVE_PATH) == OK:
		high_score = cfg.get_value("data", "high_score", 0)
