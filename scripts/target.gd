
extends Area2D

const GameProgress := preload("res://scripts/game_progress.gd")
const SoundManager := preload("res://scripts/sound_manager.gd")

# Kara delik renkleri (eski mor paletten türetildi)
const CORE_COLOR := Color("#12001F")
const MAIN_COLOR := Color("#C13CFF")
const LIGHT_COLOR := Color("#F0B8FF")
const GLOW_COLOR := Color("#E9A8FF")

## Topun içine çekilme süresi (saniye)
@export var pull_duration: float = 1.6
## Topun içine çekilirken etrafında kaç tur döneceği
@export var pull_turns: float = 1.5
## Girdabın normal dönüş hızı
@export var spin_speed: float = 2.0
## Etrafta içe doğru akan parçacık sayısı
@export var particle_count: int = 16

var completed := false
var absorbing := false
var time := 0.0
var swirl_angle := 0.0
var flash := 0.0
var particles: Array = []

@onready var completion_panel = $CanvasLayer/Overlay
@onready var win_title: Label = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/Title
@onready var retry_button = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/Buttons/RetryButton
@onready var menu_button = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/Buttons/MenuButton
@onready var next_button = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/Buttons/NextButton
@onready var star_label = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/StarLabel
@onready var shots_label = $CanvasLayer/Overlay/CenterContainer/PanelContainer/VBoxContainer/ShotsLabel

func _ready():
	body_entered.connect(_on_body_entered)

	completion_panel.hide()

	win_title.text = GameProgress.t("level_complete")
	retry_button.text = GameProgress.t("retry")
	menu_button.text = GameProgress.t("menu")
	if _is_final_level():
		next_button.text = GameProgress.t("end")
		next_button.disabled = false
	else:
		next_button.text = GameProgress.t("next")
		next_button.disabled = not GameProgress.has_next_level()

	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(GameProgress.go_to_menu)
	next_button.pressed.connect(_on_next_pressed)

	for i in particle_count:
		particles.append(_new_particle(randf_range(14.0, 50.0)))

func _new_particle(radius: float) -> Dictionary:
	return {
		"angle": randf() * TAU,
		"radius": radius,
		"speed": randf_range(10.0, 22.0),
		"size": randf_range(1.2, 2.4),
	}

func _process(delta):
	# Top çekilirken girdap hızlanır
	var speed_mult := 3.5 if absorbing else 1.0

	time += delta
	swirl_angle += delta * spin_speed * speed_mult

	for p in particles:
		p["radius"] -= p["speed"] * delta * speed_mult
		# Merkeze yaklaştıkça daha hızlı döner
		p["angle"] += delta * (60.0 / max(p["radius"], 6.0)) * speed_mult

		if p["radius"] < 12.0:
			var fresh := _new_particle(randf_range(44.0, 52.0))
			p.merge(fresh, true)

	queue_redraw()

func _on_body_entered(body):
	if completed:
		return

	if body is RigidBody2D and body.name == "Ball":
		completed = true

		var shots = get_parent().shot_count
		var stars = 1

		if shots <= 2:
			stars = 3
		elif shots == 3:
			stars = 2

		star_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
		if shots == 1:
			shots_label.text = GameProgress.t("finished_in_1")
		else:
			shots_label.text = GameProgress.t("finished_in_n") % shots

		GameProgress.complete_level(GameProgress.current_level, stars)
		if _is_final_level():
			next_button.text = GameProgress.t("end")
			next_button.disabled = false
		else:
			next_button.disabled = not GameProgress.has_next_level()

		body.call_deferred("set_linear_velocity", Vector2.ZERO)
		body.call_deferred("set_angular_velocity", 0.0)
		body.call_deferred("set_freeze_enabled", true)

		print("LEVEL COMPLETED! Stars: ", stars)

		_absorb_ball(body)

func _absorb_ball(body: RigidBody2D):
	# Fizik motoru topu dondurana kadar bekle
	await get_tree().physics_frame

	absorbing = true
	body.z_index = 1

	var sprite: Sprite2D = body.get_node("Sprite2D")
	var start_offset: Vector2 = body.global_position - global_position
	var center: Vector2 = global_position

	var tween := create_tween().set_parallel(true)

	# Spiral çizerek merkeze doğru yavaşça çekilme
	var spiral_move := func(t: float): body.global_position = center + start_offset.rotated(t * TAU * pull_turns) * (1.0 - t)
	tween.tween_method(spiral_move, 0.0, 1.0, pull_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Küçülerek yok olma
	tween.tween_property(sprite, "scale", Vector2.ZERO, pull_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Kendi etrafında hızlanarak dönme
	tween.tween_property(sprite, "rotation", sprite.rotation + TAU * 4.0, pull_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Merkeze yaklaşınca mora boyanıp kararma
	tween.tween_property(sprite, "modulate", Color(0.75, 0.3, 1.0, 0.0), pull_duration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	await tween.finished

	absorbing = false
	body.hide()

	# Yutma sonrası dışa doğru ışık dalgası
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "flash", 1.0, 0.5).from(0.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await flash_tween.finished

	SoundManager.play_win()
	completion_panel.show()

func _is_final_level() -> bool:
	if GameProgress.current_level == GameProgress.level_count() - 1:
		return true
	if get_parent() and String(get_parent().scene_file_path).ends_with("level12.tscn"):
		return true
	return false

func _on_retry_pressed():
	print("retry pressed")
	get_tree().reload_current_scene()

func _on_next_pressed():
	if _is_final_level():
		SoundManager.play_ending_music()
		GameProgress.go_to_ending()
	else:
		GameProgress.start_next_level()



func _draw():
	var pulse := 0.5 + 0.5 * sin(time * 3.0)

	# Dış parıltı (içe doğru yoğunlaşan halkalar)
	for i in range(6):
		draw_circle(Vector2.ZERO, 50.0 - i * 4.0, Color(MAIN_COLOR, 0.04 + i * 0.02))

	# Nabız gibi atan dış halka
	draw_arc(Vector2.ZERO, 32.0 + pulse * 2.0, 0, TAU, 64, Color(LIGHT_COLOR, 0.5 + 0.3 * pulse), 2.0)

	# Toplanma diski
	draw_circle(Vector2.ZERO, 28.0, Color(MAIN_COLOR, 0.85))

	# Dönen spiral kollar
	var arms := 4
	for a in arms:
		var points := PackedVector2Array()
		var base_angle: float = swirl_angle + a * TAU / arms

		for s in 16:
			var k: float = s / 15.0
			var r: float = lerp(30.0, 11.0, k)
			points.append(Vector2.from_angle(base_angle + k * 2.6) * r)

		draw_polyline(points, Color(LIGHT_COLOR, 0.75), 2.5, true)

	# İçe doğru akan parçacıklar
	for p in particles:
		var alpha: float = clamp((p["radius"] - 12.0) / 20.0, 0.0, 1.0)
		draw_circle(Vector2.from_angle(p["angle"]) * p["radius"], p["size"], Color(GLOW_COLOR, alpha))

	# Olay ufku (kara çekirdek)
	draw_circle(Vector2.ZERO, 14.5, MAIN_COLOR.darkened(0.55))
	draw_circle(Vector2.ZERO, 12.0, CORE_COLOR)
	draw_arc(Vector2.ZERO, 12.5, 0, TAU, 48, Color(GLOW_COLOR, 0.6 + 0.4 * pulse), 1.5)

	# Yutma sonrası ışık dalgası
	if flash > 0.0 and flash < 1.0:
		draw_arc(Vector2.ZERO, 14.0 + flash * 50.0, 0, TAU, 64, Color(1, 1, 1, 1.0 - flash), 4.0 * (1.0 - flash) + 1.0)



func _on_retry_button_pressed() -> void:
	pass # Replace with function body.
