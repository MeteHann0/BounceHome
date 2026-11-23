extends Node2D

const GameProgress := preload("res://scripts/game_progress.gd")
const SoundManager := preload("res://scripts/sound_manager.gd")

const MAX_LIVES := 3

@onready var ball: RigidBody2D = $Ball
@onready var target = $Target

@onready var game_over_panel = $CanvasLayer/Overlay
@onready var game_over_title: Label = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/GameOverTitle
@onready var game_over_sub: Label = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/SubLabel
@onready var retry_button = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/TryAgainButton
@onready var game_over_menu_button = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/MenuButton

@onready var hud_pause_button: Button = $CanvasLayer/PauseButton

@onready var pause_panel = $CanvasLayer/PauseOverlay
@onready var pause_title: Label = $CanvasLayer/PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/PauseTitle
@onready var resume_button = $CanvasLayer/PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/ResumeButton
@onready var pause_restart_button = $CanvasLayer/PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/RestartButton
@onready var pause_menu_button = $CanvasLayer/PauseOverlay/CenterContainer/PanelContainer/VBoxContainer/MenuButton

@onready var hud_hbox: HBoxContainer = $CanvasLayer/HudPanel/HBox
@onready var shot_counter_label = $CanvasLayer/HudPanel/HBox/ShotCounterLabel
@export var max_drag_distance: float = 150.0
@export var launch_power: float = 8.0

var is_dragging := false
var drag_position := Vector2.ZERO
var game_over := false
var shot_count := 0
var cutscene_active := false
var ball_in_flight := false

var lives: int = MAX_LIVES
var _initial_ball_pos := Vector2(150, 450)
var _initial_sprite_scale := Vector2(0.17, 0.17)
var _respawning := false
var _hearts_ctrl: Control = null
var _heart_loss_anim: float = 0.0
var _last_lost_heart_idx: int = -1
var _toast_label: Label = null
var _toast_tween: Tween = null

const GRAVITY := Vector2(0, 980)
const TIME_STEP := 0.025
const MAX_TIME := 0.3

func _ready():
	SoundManager.play_game_music()
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Ball.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Ground.process_mode = Node.PROCESS_MODE_PAUSABLE
	if has_node("Reflector"):
		$Reflector.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Target.process_mode = Node.PROCESS_MODE_PAUSABLE

	_initial_ball_pos = ball.global_position
	var ball_sprite := ball.get_node_or_null("Sprite2D") as Node2D
	if ball_sprite:
		_initial_sprite_scale = ball_sprite.scale

	game_over_panel.hide()
	pause_panel.hide()
	game_over_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_over_sub.custom_minimum_size.x = 340.0

	retry_button.disabled = false
	retry_button.pressed.connect(_on_retry_pressed)
	game_over_menu_button.pressed.connect(_on_menu_pressed)

	hud_pause_button.pressed.connect(_toggle_pause)
	hud_pause_button.draw.connect(_draw_hamburger_icon)

	resume_button.pressed.connect(_resume_game)
	pause_restart_button.pressed.connect(_on_retry_pressed)
	pause_menu_button.pressed.connect(_on_menu_pressed)

	_setup_hearts_hud()
	_apply_texts()

	if has_node("Ground") and bool($Ground.get("is_atlantis")):
		ball.gravity_scale = 0.08
		ball.linear_damp = 0.35

func _setup_hearts_hud():
	if hud_hbox:
		var sep := Control.new()
		sep.custom_minimum_size = Vector2(8, 0)
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_hbox.add_child(sep)

		_hearts_ctrl = Control.new()
		_hearts_ctrl.custom_minimum_size = Vector2(114, 38)
		_hearts_ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hearts_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hearts_ctrl.draw.connect(_draw_hearts_hud)
		hud_hbox.add_child(_hearts_ctrl)

	var canvas_layer := get_node_or_null("CanvasLayer")
	if canvas_layer:
		_toast_label = Label.new()
		_toast_label.theme_type_variation = &"HudLabel"
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast_label.custom_minimum_size = Vector2(760.0, 48.0)
		_toast_label.size = Vector2(760.0, 48.0)
		_toast_label.position = Vector2(260.0, 22.0)
		_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
		_toast_label.modulate.a = 0.0
		canvas_layer.add_child(_toast_label)

func _draw_hearts_hud():
	if not is_instance_valid(_hearts_ctrl):
		return
	var cy := _hearts_ctrl.size.y * 0.5 - 1.0
	var start_x := 19.0
	var spacing := 37.0

	for i in range(MAX_LIVES):
		var center := Vector2(start_x + float(i) * spacing, cy)
		var is_alive := i < lives
		var scale_mult := 1.0
		if i == _last_lost_heart_idx and _heart_loss_anim > 0.0:
			scale_mult = 1.0 + sin(_heart_loss_anim * PI) * 0.35
		_draw_single_heart(_hearts_ctrl, center, 0.84 * scale_mult, is_alive)

func _draw_single_heart(canvas: Control, center: Vector2, heart_scale: float, filled: bool):
	var outline_col := Color(0.231, 0.137, 0.078, 1.0)
	var fill_col := Color("#FF2E4C") if filled else Color(0.24, 0.15, 0.12, 0.65)

	var poly := PackedVector2Array()
	var shadow_poly := PackedVector2Array()
	var steps := 36
	for i in range(steps):
		var t := float(i) * TAU / float(steps)
		var st := sin(t)
		var hx := 16.0 * st * st * st
		var hy := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		var pt := center + Vector2(hx, hy + 1.5) * heart_scale
		poly.append(pt)
		shadow_poly.append(pt + Vector2(0.0, 2.5))

	var outline_pts := poly.duplicate()
	outline_pts.append(poly[0])

	# Alt gölge, iç dolgu ve pürüzsüz dış kontur
	canvas.draw_colored_polygon(shadow_poly, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_colored_polygon(poly, fill_col)
	canvas.draw_polyline(outline_pts, outline_col, 3.0, true)

	# Sol üst parlama noktası
	if filled:
		canvas.draw_circle(center + Vector2(-5.2, -3.5) * heart_scale, 2.6 * heart_scale, Color(1.0, 0.82, 0.86, 0.88))

func _apply_texts():
	shot_counter_label.text = GameProgress.t("moves") % shot_count
	game_over_title.text = GameProgress.t("game_over")
	game_over_sub.text = GameProgress.t("out_of_bounds")
	retry_button.text = GameProgress.t("try_again")
	game_over_menu_button.text = GameProgress.t("main_menu")
	pause_title.text = GameProgress.t("paused")
	resume_button.text = GameProgress.t("resume")
	pause_restart_button.text = GameProgress.t("restart")
	pause_menu_button.text = GameProgress.t("main_menu")

func _process(delta: float):
	if _heart_loss_anim > 0.0:
		_heart_loss_anim = maxf(0.0, _heart_loss_anim - delta * 2.4)
		if is_instance_valid(_hearts_ctrl):
			_hearts_ctrl.queue_redraw()

func _physics_process(_delta):
	if game_over or _respawning or get_tree().paused:
		return

	if is_ball_outside_map():
		end_game()
		return

	if is_dragging:
		queue_redraw()

func is_ball_outside_map() -> bool:
	var pos = ball.global_position

	return (
		pos.x < -30 or
		pos.x > 1310
	)

func end_game(custom_reason: String = ""):
	if game_over or _respawning or target.completed:
		return

	is_dragging = false
	ball_in_flight = false
	queue_redraw()

	var reason_text := custom_reason if custom_reason != "" else GameProgress.t("out_of_bounds")
	lives = maxi(0, lives - 1)
	_last_lost_heart_idx = lives
	_heart_loss_anim = 1.0
	if is_instance_valid(_hearts_ctrl):
		_hearts_ctrl.queue_redraw()

	# Eğer hala kalp hakkımız varsa menü çıkarma; topu başlangıç noktasına geri koy
	if lives > 0:
		_respawn_ball_after_life_lost(reason_text)
		return

	# 3 kalp hakkı da bittiyse OYUN BİTTİ / TEKRAR DENE menüsünü göster
	game_over = true
	game_over_sub.text = reason_text

	ball.call_deferred("set_linear_velocity", Vector2.ZERO)
	ball.call_deferred("set_angular_velocity", 0.0)
	ball.call_deferred("set_freeze_enabled", true)

	SoundManager.play_lose()
	game_over_panel.show()
	queue_redraw()

	print("GAME OVER!")

func _respawn_ball_after_life_lost(reason_text: String):
	_respawning = true
	SoundManager.play_click()
	_show_life_lost_toast(reason_text)

	# Sahnedeki engel scriptlerinin ölüm/yakalama bayraklarını sıfırla
	if has_node("Ground"):
		var g := $Ground
		g.set("_ball_sinking", false)
		g.set("_ball_in_swamp", false)
		g.set("_sink_progress", 0.0)
		g.set("_swamp_escape_timer", 0.0)

	for child in get_children():
		if child.get("_ball_turning_to_ash") != null:
			child.set("_ball_turning_to_ash", false)
			child.set("_lightning_state", 0)
			child.set("_lightning_timer", 0.0)
		if child.get("_shocking_ball") != null:
			child.set("_shocking_ball", false)
			child.set("_shock_timer", 0.0)
		if child.get("_laser_hitting_ball") != null:
			child.set("_laser_hitting_ball", false)
			child.set("_laser_hit_timer", 0.0)
		if child.get("_ball_crushed") != null:
			child.set("_ball_crushed", false)
		if child.get("absorbing") != null and child != target:
			child.set("absorbing", false)

	cutscene_active = false

	# Topun görünümünü ve fiziğini başlangıç durumuna döndür
	ball.set_deferred("freeze", true)
	ball.set_deferred("linear_velocity", Vector2.ZERO)
	ball.set_deferred("angular_velocity", 0.0)

	await get_tree().physics_frame

	ball.global_position = _initial_ball_pos
	ball.rotation = 0.0
	ball.modulate = Color.WHITE
	ball.z_index = 0
	ball.show()

	var ball_sprite := ball.get_node_or_null("Sprite2D") as Node2D
	if ball_sprite:
		ball_sprite.scale = _initial_sprite_scale
		ball_sprite.rotation = 0.0
		ball_sprite.modulate = Color.WHITE

	if has_node("Ground") and bool($Ground.get("is_atlantis")):
		ball.gravity_scale = 0.08
		ball.linear_damp = 0.35

	await get_tree().physics_frame
	ball.set_deferred("freeze", false)
	_respawning = false

func _show_life_lost_toast(reason_text: String):
	if not is_instance_valid(_toast_label):
		return
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_label.text = reason_text
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.25)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.45)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _input(event):
	if game_over or _respawning or ball.freeze or get_tree().paused or cutscene_active:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:
				var mouse_pos = get_global_mouse_position()

				if mouse_pos.distance_to(ball.global_position) < 35:
					is_dragging = true
					drag_position = mouse_pos

			else:
				if is_dragging:
					shoot_ball()
					is_dragging = false
					queue_redraw()

	elif event is InputEventMouseMotion and is_dragging:
		drag_position = get_global_mouse_position()

func shoot_ball():
	var pull_vector = ball.global_position - drag_position
	pull_vector = pull_vector.limit_length(max_drag_distance)

	if pull_vector.length() < 5:
		return

	shot_count += 1
	ball_in_flight = true
	shot_counter_label.text = GameProgress.t("moves") % shot_count

	var is_underwater := has_node("Ground") and bool($Ground.get("is_atlantis"))
	if is_underwater:
		# Su altında yerçekimi neredeyse 0 olsun ve top yavaş hareket etsin
		ball.gravity_scale = 0.05
		ball.linear_damp = 0.32
		ball.linear_velocity = Vector2.ZERO
		ball.apply_central_impulse(pull_vector * (launch_power * 0.52))
		var poseidon := get_node_or_null("Poseidon")
		if poseidon and poseidon.has_method("try_trigger"):
			poseidon.try_trigger()
	else:
		ball.apply_central_impulse(pull_vector * launch_power)

func _toggle_pause():
	if game_over or target.completed or cutscene_active:
		return
	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game():
	is_dragging = false
	queue_redraw()
	get_tree().paused = true
	pause_panel.show()

func _resume_game():
	get_tree().paused = false
	pause_panel.hide()

func _on_retry_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed():
	get_tree().paused = false
	GameProgress.go_to_menu()

func _draw_hamburger_icon():
	var w := hud_pause_button.size.x
	var h := hud_pause_button.size.y
	var bar_w := 24.0
	var bar_h := 4.0
	var gap := 8.5
	var x := (w - bar_w) / 2.0
	var center_y := (h - 5.0) / 2.0

	var outline := Color(0.231, 0.137, 0.078)
	var fill := Color(1.0, 0.957, 0.863)

	for i in [-1, 0, 1]:
		var rect := Rect2(x, center_y + i * gap - bar_h / 2.0, bar_w, bar_h)
		hud_pause_button.draw_rect(rect.grow(2.0), outline)
		hud_pause_button.draw_rect(rect, fill)

func _draw():
	if not is_dragging or game_over:
		return

	var ball_pos = to_local(ball.global_position)
	var mouse_pos = to_local(drag_position)

	var pull_vector = ball_pos - mouse_pos
	pull_vector = pull_vector.limit_length(max_drag_distance)

	var is_underwater := has_node("Ground") and bool($Ground.get("is_atlantis"))
	var effective_power := (launch_power * 0.52) if is_underwater else launch_power
	var effective_gravity := (GRAVITY * 0.04) if is_underwater else GRAVITY
	var step := (TIME_STEP * 1.8) if is_underwater else TIME_STEP
	var max_t := (MAX_TIME * 1.8) if is_underwater else MAX_TIME

	var initial_velocity = pull_vector * effective_power

	for i in range(1, int(max_t / step) + 1):
		var t = i * step

		var point = ball_pos + initial_velocity * t + 0.5 * effective_gravity * t * t

		var progress = float(i) / int(max_t / step)

		# Noktalar ilerledikçe küçülsün
		var dot_size = lerp(3.5, 0.8, progress)

		# Noktalar ilerledikçe saydamlaşsın
		var alpha = lerp(1.0, 0.3, progress)

		draw_circle(
			point,
			dot_size,
			Color(1.0, 1.0, 1.0, alpha)
			)
