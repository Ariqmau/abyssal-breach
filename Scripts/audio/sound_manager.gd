## sound_manager.gd  –  Autoload singleton
## Centralises all game audio.
## Other scripts call SoundManager.play_xxx() directly.
extends Node


# ══════════════════════════════════════════════════════
#  PLAYERS
# ══════════════════════════════════════════════════════

var _ui_click    : AudioStreamPlayer
var _sub_hum     : AudioStreamPlayer   # continuous loop
var _ambient     : AudioStreamPlayer   # continuous loop
var _damage      : AudioStreamPlayer
var _reward      : AudioStreamPlayer
var _lev_roar    : AudioStreamPlayer
var _lev_lunge   : AudioStreamPlayer
var _footstep    : AudioStreamPlayer
var _robot_fix   : AudioStreamPlayer
var _mode_switch : AudioStreamPlayer
var _win         : AudioStreamPlayer
var _game_over   : AudioStreamPlayer


# ══════════════════════════════════════════════════════
#  INTERNAL STATE
# ══════════════════════════════════════════════════════

var _footstep_cd : float = 0.0
var _roar_timer  : float = 18.0   # first roar after 18 s


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ui_click    = _mk("res://Assets/audio/ui-button-click.mp3",        false, true)
	_sub_hum     = _mk("res://Assets/audio/submarine.mp3",              true,  true)
	_ambient     = _mk("res://Assets/audio/underwater-ambience.mp3",    true,  true)
	_damage      = _mk("res://Assets/audio/damage_hit.mp3")
	_reward      = _mk("res://Assets/audio/sub-claim-reward.mp3")
	_reward.volume_db = -20.0
	_lev_roar    = _mk("res://Assets/audio/leviathan-roar-random.mp3")
	_lev_lunge   = _mk("res://Assets/audio/leviathan-lunge.mp3")
	_lev_lunge.volume_db = -6.0
	_footstep    = _mk("res://Assets/audio/robot-footstep.mp3")
	_footstep.volume_db = -12.0
	_robot_fix   = _mk("res://Assets/audio/robot-fix.mp3")
	_mode_switch = _mk("res://Assets/audio/3d-2dmode-switch.mp3")
	_win         = _mk("res://Assets/audio/win_sound.mp3")
	_game_over   = _mk("res://Assets/audio/game-over.mp3")

	_sub_hum.play()
	_ambient.play()

	Globals.hull_integrity_changed.connect(func(_hp): play_damage())
	Globals.ship_destroyed.connect(func(): play_game_over())
	Globals.reward_collected.connect(func(_v): play_reward())
	Globals.mode_changed.connect(func(_m): play_mode_switch())
	Globals.game_won.connect(func(): play_win())


func _process(delta: float) -> void:
	if _footstep_cd > 0.0:
		_footstep_cd -= delta

	# Random leviathan ambient roar — only during active gameplay.
	if Globals.hull_integrity > 0:
		_roar_timer -= delta
		if _roar_timer <= 0.0:
			_fire(_lev_roar)
			_roar_timer = randf_range(18.0, 35.0)


# ══════════════════════════════════════════════════════
#  PUBLIC API
# ══════════════════════════════════════════════════════

func play_ui_click() -> void:
	_fire(_ui_click)

func play_damage() -> void:
	_fire(_damage)

func play_reward() -> void:
	_fire(_reward)

func play_lev_lunge() -> void:
	_fire(_lev_lunge)

## Rate-limited: robot walking and jumping share the same clip.
func play_footstep() -> void:
	if _footstep_cd > 0.0:
		return
	_footstep_cd = 0.32
	_fire(_footstep)

func play_robot_fix() -> void:
	_fire(_robot_fix)

func play_mode_switch() -> void:
	_fire(_mode_switch)

func play_win() -> void:
	_fire(_win)

func play_game_over() -> void:
	_fire(_game_over)


# ══════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════

func _mk(path: String, loop: bool = false, always: bool = false) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream  = load(path)
	if stream and loop and stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	player.stream = stream
	if always:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _fire(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()
