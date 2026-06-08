## main_menu.gd
## Title screen — initial scene when the game is launched.
## Set this scene as Main Scene in Project Settings → Application → Run.
extends Control


# ══════════════════════════════════════════════════════
#  COLOURS
# ══════════════════════════════════════════════════════

const _C_TEXT  := Color(0.80, 0.95, 1.00)
const _C_DIM   := Color(0.45, 0.65, 0.75)
const _C_ACCENT := Color(0.20, 0.65, 0.95)
const _C_BG    := Color(0.00, 0.03, 0.08)


# ══════════════════════════════════════════════════════
#  FONTS
# ══════════════════════════════════════════════════════

var _fnt_black : FontFile
var _fnt_bold  : FontFile
var _fnt_mono  : FontFile


# ══════════════════════════════════════════════════════
#  STATE
# ══════════════════════════════════════════════════════

var _controls_overlay : Control = null


# ══════════════════════════════════════════════════════
#  LIFECYCLE
# ══════════════════════════════════════════════════════

func _ready() -> void:
	_fnt_black = load("res://Assets/fonts/Exo_2/static/Exo2-Black.ttf")
	_fnt_bold  = load("res://Assets/fonts/Exo_2/static/Exo2-Bold.ttf")
	_fnt_mono  = load("res://Assets/fonts/Share_Tech_Mono/ShareTechMono-Regular.ttf")
	_build()


# ══════════════════════════════════════════════════════
#  BUILD
# ══════════════════════════════════════════════════════

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.color = _C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Vignette tint
	var tint := ColorRect.new()
	tint.color = Color(0.00, 0.05, 0.15, 0.45)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tint)

	# Centered layout
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	# Title
	vbox.add_child(_label("ABYSSAL BREACH", 56, _C_TEXT, _fnt_black, true))

	# Subtitle
	vbox.add_child(_label("Navigate the depths  ·  Survive the dark", 14, _C_DIM, _fnt_bold, true))
	vbox.add_child(_spacer(4))
	vbox.add_child(_label("✦ Collect as many glowing crystals as you can", 11, _C_ACCENT, _fnt_mono, true))

	# Spacer
	vbox.add_child(_spacer(24))

	# Highscore
	var hi_box := HBoxContainer.new()
	hi_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hi_box)
	hi_box.add_child(_label("BEST SCORE", 13, _C_DIM, _fnt_bold, false))
	hi_box.add_child(_spacer_h(12))
	hi_box.add_child(_label("%d" % Globals.high_score, 16, _C_ACCENT, _fnt_mono, false))

	# Spacer
	vbox.add_child(_spacer(20))

	# Buttons
	_btn(vbox, "PLAY", func():
		get_tree().change_scene_to_file("res://Scenes/Main.tscn")
	)
	_btn(vbox, "CONTROLS", func():
		_show_controls()
	)

	# Hint
	vbox.add_child(_spacer(12))
	vbox.add_child(_label("TAB — Switch 2D / 3D Mode      ESC — Pause", 10, _C_DIM, _fnt_mono, true))


# ══════════════════════════════════════════════════════
#  CONTROLS OVERLAY
# ══════════════════════════════════════════════════════

func _show_controls() -> void:
	if _controls_overlay != null:
		return

	_controls_overlay = Control.new()
	_controls_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.02, 0.05, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var pw := 340.0
	var ph := 290.0
	panel.size     = Vector2(pw, ph)
	panel.position = Vector2(-pw * 0.5, -ph * 0.5)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.14, 0.97)
	style.border_color = Color(0.20, 0.55, 0.90)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 28.0
	style.content_margin_right  = 28.0
	style.content_margin_top    = 22.0
	style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", style)
	_controls_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	vbox.add_child(_label("CONTROLS", 20, _C_TEXT, _fnt_bold, true))

	var sep       := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.20, 0.55, 0.90, 0.5)
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	var rows := [
		["WASD / Arrows",   "Steer submarine"],
		["TAB",             "Switch 2D / 3D Mode"],
		["Left Click (2D)", "Move robot / Fix sign"],
		["ESC",             "Pause game"],
	]
	for row in rows:
		var hbox := HBoxContainer.new()
		var key_lbl := _label(row[0], 13, _C_ACCENT, _fnt_bold, false)
		key_lbl.custom_minimum_size = Vector2(160.0, 0.0)
		hbox.add_child(key_lbl)
		hbox.add_child(_label(row[1], 13, _C_TEXT, null, false))
		vbox.add_child(hbox)

	vbox.add_child(_spacer(8))
	_btn(vbox, "BACK", func():
		_controls_overlay.queue_free()
		_controls_overlay = null
	, 220.0)

	add_child(_controls_overlay)


# ══════════════════════════════════════════════════════
#  UI HELPERS
# ══════════════════════════════════════════════════════

func _label(text: String, size: int, col: Color, font: FontFile, center: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	if font:
		lbl.add_theme_font_override("font", font)
	if center:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c


func _spacer_h(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0.0)
	return c


func _btn(parent: VBoxContainer, text: String, action: Callable, width: float = 260.0) -> void:
	var btn := Button.new()
	btn.text               = text
	btn.custom_minimum_size = Vector2(width, 46.0)

	if _fnt_bold:
		btn.add_theme_font_override("font", _fnt_bold)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color",         Color(0.80, 0.95, 1.00))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 1.00, 1.00))
	btn.add_theme_color_override("font_pressed_color", Color(0.60, 0.85, 1.00))

	var sn := StyleBoxFlat.new()
	sn.bg_color    = Color(0.04, 0.15, 0.30, 0.90)
	sn.border_color = Color(0.20, 0.55, 0.90, 0.70)
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(5)

	var sh := StyleBoxFlat.new()
	sh.bg_color    = Color(0.10, 0.30, 0.55, 0.95)
	sh.border_color = Color(0.30, 0.70, 1.00)
	sh.set_border_width_all(2)
	sh.set_corner_radius_all(5)

	var sp := StyleBoxFlat.new()
	sp.bg_color    = Color(0.15, 0.40, 0.68)
	sp.border_color = Color(0.40, 0.80, 1.00)
	sp.set_border_width_all(2)
	sp.set_corner_radius_all(5)

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sp)

	btn.pressed.connect(func():
		SoundManager.play_ui_click()
		action.call()
	)
	parent.add_child(btn)
