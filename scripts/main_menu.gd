extends Control
## Ana menü: BAŞLA / BÖLÜMLER / ÇIKIŞ ve bölüm kataloğu.

const GameProgress := preload("res://scripts/game_progress.gd")
const SoundManager := preload("res://scripts/sound_manager.gd")

const CARD_SIZE := Vector2(150, 104)

const COMPLETED_BG := Color(0.42, 0.72, 0.3)
const COMPLETED_BG_HOVER := Color(0.5, 0.8, 0.38)
const COMPLETED_BORDER := Color(0.13, 0.29, 0.09)
const LOCKED_BG := Color(0.36, 0.32, 0.29)
const LOCKED_BORDER := Color(0.18, 0.15, 0.13)
const SOON_BG := Color(0.56, 0.5, 0.44)
const SOON_BORDER := Color(0.29, 0.247, 0.212)
const CREAM := Color(1, 0.957, 0.863)
const OUTLINE := Color(0.231, 0.137, 0.078)

@onready var home: Control = $Home
@onready var subtitle_label: Label = $Home/VBox/Subtitle
@onready var ball_holder: Control = $Home/VBox/BallHolder
@onready var ball: TextureRect = $Home/VBox/BallHolder/Ball
@onready var progress_label: Label = $Home/VBox/ProgressLabel
@onready var start_button: Button = $Home/VBox/StartButton
@onready var levels_button: Button = $Home/VBox/LevelsButton
@onready var settings_button: Button = $Home/VBox/SettingsButton
@onready var quit_button: Button = $Home/VBox/QuitButton
@onready var lang_button: Button = $LangButton
@onready var info_button: Button = $InfoButton

@onready var levels_overlay: Control = $LevelsOverlay
@onready var levels_title: Label = $LevelsOverlay/Center/Panel/VBox/Title
@onready var summary_label: Label = $LevelsOverlay/Center/Panel/VBox/Summary
@onready var grid: GridContainer = $LevelsOverlay/Center/Panel/VBox/Grid
@onready var back_button: Button = $LevelsOverlay/Center/Panel/VBox/BackButton

@onready var settings_overlay: Control = $SettingsOverlay
@onready var settings_title: Label = $SettingsOverlay/Center/Panel/VBox/Title
@onready var volume_label: Label = $SettingsOverlay/Center/Panel/VBox/VolumeBox/Header/VolumeLabel
@onready var volume_value_label: Label = $SettingsOverlay/Center/Panel/VBox/VolumeBox/Header/VolumeValue
@onready var volume_slider: HSlider = $SettingsOverlay/Center/Panel/VBox/VolumeBox/VolumeSlider
@onready var settings_back_button: Button = $SettingsOverlay/Center/Panel/VBox/BackButton

@onready var info_overlay: Control = $InfoOverlay
@onready var info_title: Label = $InfoOverlay/Center/Panel/VBox/Title
@onready var how_to_title: Label = $InfoOverlay/Center/Panel/VBox/HowToTitle
@onready var how_to_desc: Label = $InfoOverlay/Center/Panel/VBox/HowToDesc
@onready var stars_title: Label = $InfoOverlay/Center/Panel/VBox/StarsTitle
@onready var stars_rules: Label = $InfoOverlay/Center/Panel/VBox/StarsRules
@onready var replay_button: Button = $InfoOverlay/Center/Panel/VBox/ReplayButton
@onready var developer_label: Label = $InfoOverlay/Center/Panel/VBox/DeveloperRow/DeveloperLabel
@onready var linkedin_button: Button = $InfoOverlay/Center/Panel/VBox/DeveloperRow/LinkedInButton
@onready var github_button: Button = $InfoOverlay/Center/Panel/VBox/DeveloperRow/GitHubButton
@onready var version_label: Label = $InfoOverlay/Center/Panel/VBox/VersionLabel
@onready var info_back_button: Button = $InfoOverlay/Center/Panel/VBox/BackButton

@onready var fade_rect: ColorRect = $Fade

var time := 0.0
var leaving := false

func _ready():
	SoundManager.play_menu_music()
	levels_overlay.hide()
	settings_overlay.hide()
	info_overlay.hide()

	start_button.pressed.connect(_on_start_pressed)
	levels_button.pressed.connect(_open_levels)
	settings_button.pressed.connect(_open_settings)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_close_levels)
	settings_back_button.pressed.connect(_close_settings)
	info_button.pressed.connect(_open_info)
	info_back_button.pressed.connect(_close_info)
	replay_button.pressed.connect(_on_replay_story_pressed)
	linkedin_button.pressed.connect(_on_linkedin_pressed)
	github_button.pressed.connect(_on_github_pressed)
	_setup_linkedin_button()
	_setup_github_button()
	lang_button.pressed.connect(_on_lang_pressed)

	var current_pct := roundi(GameProgress.get_volume() * 100.0)
	volume_slider.value = current_pct
	volume_value_label.text = "%d%%" % current_pct
	volume_slider.value_changed.connect(_on_volume_changed)

	# Web sürümünde çıkış butonu anlamsız
	quit_button.visible = not OS.has_feature("web")

	_apply_texts()

	fade_rect.modulate.a = 1.0
	create_tween().tween_property(fade_rect, "modulate:a", 0.0, 0.6)

func _process(delta):
	time += delta

	# Top hafifçe süzülür
	ball.pivot_offset = ball.size / 2.0
	ball.position = Vector2(
		(ball_holder.size.x - ball.size.x) / 2.0,
		(ball_holder.size.y - ball.size.y) / 2.0 + sin(time * 2.0) * 8.0
	)
	ball.rotation = sin(time * 0.8) * 0.25

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if levels_overlay.visible:
			_close_levels()
			get_viewport().set_input_as_handled()
		elif settings_overlay.visible:
			_close_settings()
			get_viewport().set_input_as_handled()
		elif info_overlay.visible:
			_close_info()
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------
# Ana ekran
# ------------------------------------------------------------

func _apply_texts():
	subtitle_label.text = GameProgress.t("subtitle")
	start_button.text = GameProgress.t("start")
	levels_button.text = GameProgress.t("levels")
	settings_button.text = GameProgress.t("settings")
	quit_button.text = GameProgress.t("quit")
	levels_title.text = GameProgress.t("levels")
	back_button.text = GameProgress.t("back")
	settings_title.text = GameProgress.t("settings")
	volume_label.text = GameProgress.t("sound_volume")
	settings_back_button.text = GameProgress.t("back")
	info_title.text = GameProgress.t("info_title")
	how_to_title.text = GameProgress.t("how_to_play_title")
	how_to_desc.text = GameProgress.t("how_to_play_desc")
	stars_title.text = GameProgress.t("stars_title")
	stars_rules.text = GameProgress.t("stars_rules")
	replay_button.text = GameProgress.t("replay_story")
	developer_label.text = GameProgress.t("credits_dev")
	version_label.text = GameProgress.t("credits_ver")
	info_back_button.text = GameProgress.t("back")
	lang_button.text = GameProgress.t("lang_btn")
	_update_progress_label()
	if levels_overlay.visible:
		_update_levels_summary()
		_build_cards()

func _on_lang_pressed():
	GameProgress.toggle_lang()
	_apply_texts()

func _update_progress_label():
	var done := GameProgress.completed_count()
	var total := GameProgress.level_count()

	if done == 0:
		progress_label.text = GameProgress.t("worlds_waiting") % total
	else:
		progress_label.text = GameProgress.t("progress_short") % [done, total, GameProgress.total_stars()]

func _update_levels_summary():
	var done := GameProgress.completed_count()
	summary_label.text = GameProgress.t("levels_summary") % [
		done, GameProgress.level_count(), GameProgress.total_stars(), GameProgress.level_count() * 3
	]

func _on_start_pressed():
	_start_level(GameProgress.get_continue_level())

func _on_quit_pressed():
	get_tree().quit()

func _start_level(index: int):
	if leaving or not GameProgress.is_playable(index):
		return

	leaving = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.4)
	await tween.finished

	GameProgress.start_level(index)

# ------------------------------------------------------------
# Bölüm kataloğu
# ------------------------------------------------------------

func _open_levels():
	_build_cards()
	_update_levels_summary()

	home.hide()
	levels_overlay.show()
	levels_overlay.modulate.a = 0.0
	create_tween().tween_property(levels_overlay, "modulate:a", 1.0, 0.2)

	# Kartlar sırayla belirir
	var cards := grid.get_children()
	for i in cards.size():
		var card: Control = cards[i]
		card.pivot_offset = CARD_SIZE / 2.0
		card.scale = Vector2.ZERO
		create_tween().tween_property(card, "scale", Vector2.ONE, 0.3) \
			.set_delay(i * 0.035).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _close_levels():
	levels_overlay.hide()
	home.show()

# ------------------------------------------------------------
# Ayarlar
# ------------------------------------------------------------

func _open_settings():
	home.hide()
	settings_overlay.show()
	settings_overlay.modulate.a = 0.0
	create_tween().tween_property(settings_overlay, "modulate:a", 1.0, 0.2)

func _close_settings():
	settings_overlay.hide()
	home.show()

func _on_volume_changed(value: float):
	var pct := roundi(value)
	volume_value_label.text = "%d%%" % pct
	var linear := clampf(value / 100.0, 0.0, 1.0)
	GameProgress.set_volume(linear)
	SoundManager.set_master_volume(linear)

# ------------------------------------------------------------
# Bilgi / Hakkında
# ------------------------------------------------------------

func _open_info():
	home.hide()
	info_overlay.show()
	info_overlay.modulate.a = 0.0
	create_tween().tween_property(info_overlay, "modulate:a", 1.0, 0.2)

func _close_info():
	info_overlay.hide()
	home.show()

func _on_replay_story_pressed():
	if leaving:
		return
	leaving = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.4)
	await tween.finished
	GameProgress.replay_intro()

func _on_linkedin_pressed():
	OS.shell_open("https://www.linkedin.com/in/metehancetiner")

func _setup_linkedin_button():
	var bg := Color("#0A66C2")
	var hover_bg := Color("#167AC6")
	var border := Color("#053566")
	linkedin_button.add_theme_stylebox_override("normal", _make_linkedin_style(bg, border, false))
	linkedin_button.add_theme_stylebox_override("hover", _make_linkedin_style(hover_bg, border, false))
	linkedin_button.add_theme_stylebox_override("pressed", _make_linkedin_style(bg.darkened(0.12), border, true))
	linkedin_button.add_theme_stylebox_override("hover_pressed", _make_linkedin_style(bg.darkened(0.12), border, true))
	linkedin_button.draw.connect(_draw_linkedin_logo)

func _make_linkedin_style(bg: Color, border: Color, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.border_width_bottom = 3 if pressed else 6
	style.set_corner_radius_all(6)
	style.corner_detail = 2
	return style

func _draw_linkedin_logo():
	var s := linkedin_button.size
	var cx := s.x * 0.5
	var cy := s.y * 0.5 - 1.0
	var white := Color.WHITE

	# Sol taraf: "i" harfi (nokta + dikey gövde)
	var ix := cx - 7.5
	linkedin_button.draw_circle(Vector2(ix, cy - 6.5), 2.4, white)
	linkedin_button.draw_rect(Rect2(ix - 2.1, cy - 2.2, 4.2, 11.2), white)

	# Sağ taraf: "n" harfi (sol dikey bacak + üst kavis + sağ dikey bacak)
	var nx := cx - 1.2
	linkedin_button.draw_rect(Rect2(nx, cy - 2.2, 4.1, 11.2), white)
	linkedin_button.draw_arc(Vector2(nx + 6.4, cy + 1.8), 4.0, PI, TAU, 12, white, 4.0)
	linkedin_button.draw_rect(Rect2(nx + 8.3, cy + 1.2, 4.1, 7.8), white)

func _on_github_pressed():
	OS.shell_open("https://github.com/MeteHann0")

func _setup_github_button():
	var bg := Color("#24292F")
	var hover_bg := Color("#32383F")
	var border := Color("#0D1117")
	github_button.add_theme_stylebox_override("normal", _make_linkedin_style(bg, border, false))
	github_button.add_theme_stylebox_override("hover", _make_linkedin_style(hover_bg, border, false))
	github_button.add_theme_stylebox_override("pressed", _make_linkedin_style(bg.darkened(0.15), border, true))
	github_button.add_theme_stylebox_override("hover_pressed", _make_linkedin_style(bg.darkened(0.15), border, true))
	github_button.draw.connect(_draw_github_logo)

func _draw_github_logo():
	var s := github_button.size
	var c := Vector2(s.x * 0.5, s.y * 0.5 - 1.0)
	var white := Color.WHITE

	# Octocat kafa gövdesi (yuvarlak kafa + sol ve sağ kedi kulakları)
	var left_ear := PackedVector2Array([
		c + Vector2(-7.5, -2.5),
		c + Vector2(-8.2, -9.8),
		c + Vector2(-2.2, -6.5),
	])
	var right_ear := PackedVector2Array([
		c + Vector2(7.5, -2.5),
		c + Vector2(8.2, -9.8),
		c + Vector2(2.2, -6.5),
	])
	github_button.draw_colored_polygon(left_ear, white)
	github_button.draw_colored_polygon(right_ear, white)
	github_button.draw_circle(c + Vector2(0.0, -1.5), 7.8, white)

	# Alt gövde / omuz sütunu
	github_button.draw_rect(Rect2(c.x - 4.2, c.y + 4.5, 8.4, 6.8), white)

	# Sol kıvrık kuyruk (Octocat tentacle tail)
	var tail_pts := PackedVector2Array([
		c + Vector2(-4.0, 8.2),
		c + Vector2(-7.8, 7.2),
		c + Vector2(-9.5, 4.8),
	])
	github_button.draw_polyline(tail_pts, white, 2.5, true)

func _build_cards():
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	for i in GameProgress.level_count():
		grid.add_child(_make_card(i))

func _make_card(index: int) -> Button:
	var completed := GameProgress.is_completed(index)
	var unlocked := GameProgress.is_unlocked(index)
	var playable := GameProgress.is_playable(index)

	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not playable

	if playable:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.pressed.connect(_start_level.bind(index))

	if completed:
		_apply_card_style(card, COMPLETED_BG, COMPLETED_BG_HOVER, COMPLETED_BORDER)
	elif not unlocked:
		card.add_theme_stylebox_override("disabled", _make_style(LOCKED_BG, LOCKED_BORDER))
	elif not playable:
		card.add_theme_stylebox_override("disabled", _make_style(SOON_BG, SOON_BORDER))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -5
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)

	# Bölüm numarası
	var number := Label.new()
	number.text = str(index + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 34)
	number.add_theme_constant_override("outline_size", 9)
	box.add_child(number)

	# Bölüm adı
	var level_name := Label.new()
	level_name.text = GameProgress.get_level_name(index) if unlocked else "???"
	level_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_name.add_theme_font_size_override("font_size", 13)
	level_name.add_theme_constant_override("outline_size", 5)
	box.add_child(level_name)

	# Durum: yıldızlar / OYNA / YAKINDA / kilit
	if completed:
		var stars := GameProgress.get_stars(index)
		var star_label := Label.new()
		star_label.theme_type_variation = &"StarsLabel"
		star_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
		star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_label.add_theme_font_size_override("font_size", 24)
		star_label.add_theme_constant_override("outline_size", 7)
		star_label.add_theme_constant_override("shadow_offset_y", 2)
		box.add_child(star_label)
	elif not unlocked:
		var lock := Control.new()
		lock.custom_minimum_size = Vector2(24, 26)
		lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.draw.connect(_draw_lock.bind(lock))
		box.add_child(lock)

		number.modulate.a = 0.55
		level_name.modulate.a = 0.55
	else:
		var status := Label.new()
		status.text = GameProgress.t("card_play") if playable else GameProgress.t("card_soon")
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.add_theme_font_size_override("font_size", 15)
		status.add_theme_constant_override("outline_size", 5)
		box.add_child(status)

	return card

func _apply_card_style(card: Button, bg: Color, hover_bg: Color, border: Color):
	card.add_theme_stylebox_override("normal", _make_style(bg, border))
	card.add_theme_stylebox_override("hover", _make_style(hover_bg, border))
	card.add_theme_stylebox_override("pressed", _make_style(bg.darkened(0.1), border, true))
	card.add_theme_stylebox_override("hover_pressed", _make_style(bg.darkened(0.1), border, true))
	card.add_theme_color_override("font_outline_color", border)

func _make_style(bg: Color, border: Color, pressed := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(4)
	style.border_width_bottom = 4 if pressed else 9
	style.set_corner_radius_all(6)
	style.corner_detail = 1
	style.anti_aliasing = false
	return style

func _draw_lock(lock: Control):
	var w := lock.size.x
	var h := lock.size.y
	var shackle_center := Vector2(w / 2.0, h * 0.45)
	var radius := w * 0.27

	# Kilit halkası
	lock.draw_arc(shackle_center, radius, PI, TAU, 16, OUTLINE, 7.0)
	lock.draw_arc(shackle_center, radius, PI, TAU, 16, CREAM, 3.5)

	# Kilit gövdesi
	var body := Rect2(w * 0.1, h * 0.45, w * 0.8, h * 0.55)
	lock.draw_rect(body.grow(2.0), OUTLINE)
	lock.draw_rect(body, CREAM)

	# Anahtar deliği
	lock.draw_circle(Vector2(w / 2.0, h * 0.68), 2.5, OUTLINE)
	lock.draw_rect(Rect2(w / 2.0 - 1.0, h * 0.68, 2.0, h * 0.18), OUTLINE)
