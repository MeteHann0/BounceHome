
extends Node2D

const GameProgress := preload("res://scripts/game_progress.gd")
const SoundManager := preload("res://scripts/sound_manager.gd")

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

@onready var shot_counter_label = $CanvasLayer/HudPanel/HBox/ShotCounterLabel
@export var max_drag_distance: float = 150.0
@export var launch_power: float = 8.0

var is_dragging := false
var drag_position := Vector2.ZERO
var game_over := false
var shot_count := 0
var cutscene_active := false

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

	_apply_texts()

	if has_node("Ground") and bool($Ground.get("is_atlantis")):
		ball.gravity_scale = 0.08
		ball.linear_damp = 0.35

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

func _physics_process(_delta):
	if game_over or get_tree().paused:
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
	if game_over or target.completed:
		return

	game_over = true
	is_dragging = false

	if custom_reason != "":
		game_over_sub.text = custom_reason
	else:
		game_over_sub.text = GameProgress.t("out_of_bounds")

	ball.call_deferred("set_linear_velocity", Vector2.ZERO)
	ball.call_deferred("set_angular_velocity", 0.0)
	ball.call_deferred("set_freeze_enabled", true)

	SoundManager.play_lose()
	game_over_panel.show()
	queue_redraw()

	print("GAME OVER!")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _input(event):
	if game_over or ball.freeze or get_tree().paused or cutscene_active:
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
