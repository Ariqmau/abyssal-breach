## hud.gd
## In-game HUD + Pause overlay + Win / Game-Over overlays.
## Attach to any Node inside Main.tscn's CanvasLayer.
extends Node


# ══════════════════════════════════════════════════════
#  LAYOUT / COLOURS
# ══════════════════════════════════════════════════════

const _BAR_W   : float = 180.0
const _BAR_H   : float = 14.0
const _PANEL_W : float = 200.0

const _C_FULL := Color(0.20, 0.90, 0.40)
const _C_LOW  := Color(0.95, 0.25, 0.10)
const _C_TEXT := Color(0.80, 0.95, 1.00)
const _C_DIM  := Color(0.45, 0.65, 0.75)
const _C_BG   := Color(0.00, 0.04, 0.10, 0.85)
const _C_DIST := Color(0.20, 0.65, 0.95)
const _C_WIN  := Color(0.20, 0.90, 0.60)


# ══════════════════════════════════════════════════════
#  FONTS
# ══════════════════════════════════════════════════════

var _fnt_bold : FontFile
var _fnt_mono : FontFile


# ══════════════════════════════════════════════════════
#  NODE REFS
# ══════════════════════════════════════════════════════

var _canvas    : CanvasLayer
var _root      : Control
var _hp_fill   : ColorRect
var _hp_label  : Label
var _spd_label : Label
var _score_lbl : Label
var _hi_lbl    : Label
var _dist_fill : ColorRect
var _dist_lbl  : Label

var _overlay   : Control = null


# ══════════════════════════════════════════════════════
#  STATE
# ══════════════════════════════════════════════════════

var _paused         : bool = false
var _result_showing : bool = false


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_fnt_bold = load("res://Assets/fonts/Exo_2/static/Exo2-Bold.ttf")
	_fnt_mono = load("res://Assets/fonts/Share_Tech_Mono/ShareTechMono-Regular.ttf")

	_canvas              = CanvasLayer.new()
	_canvas.layer        = 2
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_build_hud()

	Globals.hull_integrity_changed.connect(_on_hull_changed)
	Globals.ship_destroyed.connect(_on_ship_destroyed)
	Globals.game_won.connect(_on_game_won)


func _input(event: InputEvent) -> void:
	if _result_showing:
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_score_lbl.text = "SCORE  %d" % Globals.score
	_hi_lbl.text    = "BEST   %d" % Globals.high_score
	_spd_label.text = "SPD  %.0f / %.0f" % [Globals.current_speed, Globals.base_speed]
	var prog          := clampf(Globals.distance_traveled / maxf(Globals.win_distance, 1.0), 0.0, 1.0)
	_dist_fill.size.x  = _BAR_W * prog
	_dist_lbl.text     = "DIST  %d%%" % int(prog * 100.0)


# ══════════════════════════════════════════════════════
#  SIGNAL HANDLERS
# ══════════════════════════════════════════════════════

func _on_hull_changed(hp: int) -> void:
	var ratio        := float(hp) / float(Globals.max_hull_integrity)
	_hp_fill.size.x   = _BAR_W * ratio
	_hp_fill.color    = _C_FULL.lerp(_C_LOW, 1.0 - ratio)
	_hp_label.text    = "HULL  %d / %d" % [hp, Globals.max_hull_integrity]


func _on_ship_destroyed() -> void:
	_result_showing = true
	_show_result(
		"HULL DESTROYED",
		"SCORE  %d\nBEST   %d" % [Globals.score, Globals.high_score],
		_C_LOW, false
	)


func _on_game_won() -> void:
	_result_showing = true
	_show_result(
		"MISSION COMPLETE",
		"SCORE  %d\nBEST   %d" % [Globals.score, Globals.high_score],
		_C_WIN, true
	)


# ══════════════════════════════════════════════════════
#  PAUSE
# ══════════════════════════════════════════════════════

func _toggle_pause() -> void:
	_paused = !_paused
	get_tree().paused = _paused
	if _paused:
		_show_pause_menu()
	else:
		_close_overlay()


func _resume() -> void:
	_paused           = false
	get_tree().paused = false
	_close_overlay()


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


# ══════════════════════════════════════════════════════
#  HUD BUILDER
# ══════════════════════════════════════════════════════

func _build_hud() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_root)

	# Panel background
	var panel      := ColorRect.new()
	panel.color     = _C_BG
	panel.size      = Vector2(_PANEL_W, 122.0)
	panel.position  = Vector2(10.0, 10.0)
	_root.add_child(panel)

	# Hull label
	_hp_label = _make_hud_label(
		"HULL  %d / %d" % [Globals.hull_integrity, Globals.max_hull_integrity],
		Vector2(14.0, 14.0), 11, _C_TEXT
	)

	# Hull bar background
	var hp_bg      := ColorRect.new()
	hp_bg.color     = Color(0.10, 0.05, 0.05)
	hp_bg.size      = Vector2(_BAR_W, _BAR_H)
	hp_bg.position  = Vector2(14.0, 28.0)
	_root.add_child(hp_bg)

	# Hull bar fill
	_hp_fill          = ColorRect.new()
	_hp_fill.color    = _C_FULL
	_hp_fill.size     = Vector2(_BAR_W, _BAR_H)
	_hp_fill.position = Vector2(14.0, 28.0)
	_root.add_child(_hp_fill)

	# Speed
	_spd_label = _make_hud_label("SPD  20 / 20", Vector2(14.0, 48.0), 11, _C_DIM)

	# Score + best
	_score_lbl = _make_hud_label("SCORE  0", Vector2(14.0, 65.0), 12, _C_TEXT)
	_hi_lbl    = _make_hud_label("BEST   0", Vector2(14.0, 80.0), 10, _C_DIM)

	# Distance label
	_dist_lbl  = _make_hud_label("DIST  0%", Vector2(14.0, 96.0), 10, _C_DIST)

	# Distance bar background
	var dist_bg      := ColorRect.new()
	dist_bg.color     = Color(0.05, 0.10, 0.20)
	dist_bg.size      = Vector2(_BAR_W, 6.0)
	dist_bg.position  = Vector2(14.0, 110.0)
	_root.add_child(dist_bg)

	# Distance bar fill
	_dist_fill          = ColorRect.new()
	_dist_fill.color    = _C_DIST
	_dist_fill.size     = Vector2(0.0, 6.0)
	_dist_fill.position = Vector2(14.0, 110.0)
	_root.add_child(_dist_fill)

	# Force-sync hull bar to current Globals state
	_on_hull_changed(Globals.hull_integrity)


# ══════════════════════════════════════════════════════
#  PAUSE MENU OVERLAY
# ══════════════════════════════════════════════════════

func _show_pause_menu() -> void:
	_close_overlay()
	var ov  := _make_dimmed_overlay()
	var box := _make_popup_box(ov, 260.0, 210.0)

	_popup_title(box, "PAUSED")
	_popup_btn(box, "RESUME", func(): _resume())
	_popup_btn(box, "RESTART", func():
		get_tree().paused = false
		Globals.reset()
		get_tree().reload_current_scene()
	)
	_popup_btn(box, "MAIN MENU", func():
		get_tree().paused = false
		Globals.reset()
		get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
	)
	_overlay = ov


# ══════════════════════════════════════════════════════
#  WIN / GAME-OVER OVERLAY
# ══════════════════════════════════════════════════════

func _show_result(title: String, body: String, col: Color, _won: bool) -> void:
	_close_overlay()
	var ov  := _make_dimmed_overlay()
	var box := _make_popup_box(ov, 300.0, 250.0)

	_popup_title(box, title, col)

	var body_lbl := Label.new()
	body_lbl.text                = body
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.add_theme_font_size_override("font_size", 14)
	if _fnt_mono:
		body_lbl.add_theme_font_override("font", _fnt_mono)
	body_lbl.add_theme_color_override("font_color", _C_TEXT)
	box.add_child(body_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	_popup_btn(box, "PLAY AGAIN" if _won else "TRY AGAIN", func():
		get_tree().paused = false
		Globals.reset()
		get_tree().reload_current_scene()
	)
	_popup_btn(box, "MAIN MENU", func():
		get_tree().paused = false
		Globals.reset()
		get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
	)
	_overlay = ov


# ══════════════════════════════════════════════════════
#  UI HELPERS — HUD
# ══════════════════════════════════════════════════════

func _make_hud_label(text: String, pos: Vector2, size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	if _fnt_mono:
		lbl.add_theme_font_override("font", _fnt_mono)
	_root.add_child(lbl)
	return lbl


# ══════════════════════════════════════════════════════
#  UI HELPERS — OVERLAYS
# ══════════════════════════════════════════════════════

func _make_dimmed_overlay() -> Control:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.02, 0.05, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(bg)

	_canvas.add_child(ov)
	return ov


func _make_popup_box(parent: Control, w: float, h: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size     = Vector2(w, h)
	panel.position = -Vector2(w * 0.5, h * 0.5)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.97)
	style.border_color = Color(0.20, 0.55, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 20.0
	style.content_margin_right  = 20.0
	style.content_margin_top    = 16.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	return vbox


func _popup_title(parent: VBoxContainer, text: String, col: Color = _C_TEXT) -> void:
	var lbl := Label.new()
	lbl.text                = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", col)
	if _fnt_bold:
		lbl.add_theme_font_override("font", _fnt_bold)
	parent.add_child(lbl)

	var sep       := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.20, 0.55, 0.90, 0.5)
	sep.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(sep)


func _popup_btn(parent: VBoxContainer, text: String, action: Callable) -> void:
	var btn := Button.new()
	btn.text               = text
	btn.custom_minimum_size = Vector2(200.0, 38.0)
	btn.process_mode       = Node.PROCESS_MODE_ALWAYS

	if _fnt_bold:
		btn.add_theme_font_override("font", _fnt_bold)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color",         Color(0.80, 0.95, 1.00))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 1.00, 1.00))
	btn.add_theme_color_override("font_pressed_color", Color(0.60, 0.85, 1.00))

	var sn := StyleBoxFlat.new()
	sn.bg_color    = Color(0.05, 0.18, 0.35, 0.90)
	sn.border_color = Color(0.20, 0.55, 0.90, 0.70)
	sn.set_border_width_all(1)
	sn.set_corner_radius_all(4)

	var sh := StyleBoxFlat.new()
	sh.bg_color    = Color(0.10, 0.32, 0.58, 0.95)
	sh.border_color = Color(0.30, 0.70, 1.00)
	sh.set_border_width_all(2)
	sh.set_corner_radius_all(4)

	var sp := StyleBoxFlat.new()
	sp.bg_color    = Color(0.15, 0.40, 0.68)
	sp.border_color = Color(0.40, 0.80, 1.00)
	sp.set_border_width_all(2)
	sp.set_corner_radius_all(4)

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sp)

	btn.pressed.connect(func():
		SoundManager.play_ui_click()
		action.call()
	)
	parent.add_child(btn)
