
extends Node2D
## Oyunun açılış hikayesi.
## Top kendi evreninde süzülür -> kara delik onu yutar -> yeni bir dünyaya düşer -> ana menü açılır.
## Sadece ilk açılışta oynatılır (GameProgress içinde saklanır).

const GameProgress := preload("res://scripts/game_progress.gd")
const SoundManager := preload("res://scripts/sound_manager.gd")

## Daktilo efektinde harf başına süre (saniye)
const CHAR_TIME := 0.045

const BALL_START := Vector2(640, 330)
const BALL_LAND := Vector2(150, 595)
const HOLE_POS := Vector2(980, 250)
const SCREEN_SIZE := Vector2(1280, 720)


@export var always_play := false


@onready var world: Node2D = $World
@onready var ball: Sprite2D = $Ball
@onready var black_hole = $BlackHole
@onready var caption_box: Control = $UI/CaptionBox
@onready var caption: Label = $UI/CaptionBox/Center/Panel/Caption
@onready var skip_button: Button = $UI/SkipButton
@onready var flash_rect: ColorRect = $UI/Flash
@onready var fade_rect: ColorRect = $UI/Fade

var stars: Array = []
var nebulae: Array = []
var time := 0.0
var space_visible := true
var ball_floating := true
var ball_scale := Vector2.ONE
var typing := false
var typing_tween: Tween
var finishing := false

func _ready():
	if not always_play and GameProgress.is_intro_seen():
		GameProgress.go_to_menu.call_deferred()
		return

	_generate_space()
	SoundManager.play_menu_music()

	ball_scale = ball.scale
	ball.position = BALL_START

	world.hide()
	black_hole.hide()
	black_hole.scale = Vector2.ZERO

	caption.text = ""
	caption_box.modulate.a = 0.0
	flash_rect.modulate.a = 0.0
	fade_rect.modulate.a = 1.0

	skip_button.text = GameProgress.t("skip")
	skip_button.pressed.connect(_finish)

	_play()

# ------------------------------------------------------------
# Hikaye akışı
# ------------------------------------------------------------

func _play():
	# 1) Topun kendi evreni
	await _tween_alpha(fade_rect, 0.0, 1.2).finished
	await _type(GameProgress.t("story_0"))
	await _wait(1.6)

	# 2) Kara delik belirir
	black_hole.position = HOLE_POS
	black_hole.show()

	var appear := create_tween()
	appear.tween_property(black_hole, "scale", Vector2.ONE * 1.4, 1.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_type(GameProgress.t("story_1"))
	await appear.finished
	await _wait(0.4)

	# 3) Top kara deliğe çekilir
	ball_floating = false
	black_hole.speed_mult = 3.5
	await _pull_ball_into_hole()

	# 4) Beyaz parlama -> yeni dünya
	await _tween_alpha(flash_rect, 1.0, 0.25).finished

	space_visible = false
	queue_redraw()
	black_hole.hide()
	world.show()

	ball.scale = ball_scale
	ball.modulate = Color.WHITE
	ball.rotation = 0.0
	ball.position = Vector2(BALL_LAND.x, -60)

	await _wait(0.3)
	_tween_alpha(flash_rect, 0.0, 0.9)

	# 5) Top gökyüzünden düşer ve zıplayarak yere iner
	var fall := create_tween().set_parallel(true)
	fall.tween_property(ball, "position:y", BALL_LAND.y, 1.4) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	fall.tween_property(ball, "rotation", TAU * 2.0, 1.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await _type(GameProgress.t("story_2"))
	await _wait(1.2)

	# Şaşkınlıkla küçük bir zıplama
	var hop := create_tween()
	hop.tween_property(ball, "position:y", BALL_LAND.y - 30, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(ball, "position:y", BALL_LAND.y, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hop.finished

	# 6) Görev
	await _type(GameProgress.t("story_3"))
	await _wait(2.8)

	_finish()

func _pull_ball_into_hole():
	var center: Vector2 = black_hole.position
	var start_offset: Vector2 = ball.position - center
	var duration := 2.2

	var tween := create_tween().set_parallel(true)

	var spiral_move := func(t: float): ball.position = center + start_offset.rotated(t * TAU * 1.25) * (1.0 - t)
	tween.tween_method(spiral_move, 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.tween_property(ball, "scale", Vector2.ZERO, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	tween.tween_property(ball, "rotation", ball.rotation + TAU * 5.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.tween_property(ball, "modulate", Color(0.75, 0.3, 1.0, 0.0), duration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	await tween.finished

func _finish():
	if finishing:
		return

	finishing = true
	skip_button.disabled = true
	GameProgress.mark_intro_seen()

	await _tween_alpha(fade_rect, 1.0, 0.8).finished
	GameProgress.go_to_menu()

# ------------------------------------------------------------
# Yardımcılar
# ------------------------------------------------------------

func _type(text: String) -> void:
	if finishing:
		return

	caption.text = text
	caption.visible_ratio = 0.0

	if caption_box.modulate.a < 1.0:
		_tween_alpha(caption_box, 1.0, 0.3)

	typing = true
	typing_tween = create_tween()
	typing_tween.tween_property(caption, "visible_ratio", 1.0, text.length() * CHAR_TIME)
	await typing_tween.finished
	typing = false

func _wait(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished

func _tween_alpha(node: CanvasItem, alpha: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", alpha, duration)
	return tween

func _unhandled_input(event: InputEvent):
	# Ekrana tıklamak / Enter yazıyı anında tamamlar
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed("ui_accept")

	if pressed and typing and typing_tween and typing_tween.is_valid():
		typing_tween.custom_step(100.0)

# ------------------------------------------------------------
# Topun evreni (uzay arka planı)
# ------------------------------------------------------------

func _generate_space():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	for i in 160:
		stars.append({
			"pos": Vector2(rng.randf_range(-200, SCREEN_SIZE.x + 200), rng.randf() * SCREEN_SIZE.y),
			"size": rng.randf_range(0.8, 2.4),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.5, 4.0),
		})

	nebulae = [
		{"pos": Vector2(300, 220), "radius": 280.0, "color": Color("#FF7A1A", 0.07)},
		{"pos": Vector2(1000, 520), "radius": 320.0, "color": Color("#7B2CFF", 0.08)},
		{"pos": Vector2(700, 100), "radius": 220.0, "color": Color("#FF3CA0", 0.05)},
	]

func _process(delta):
	time += delta

	if ball_floating:
		ball.position.y = BALL_START.y + sin(time * 2.0) * 10.0
		ball.rotation = sin(time * 0.8) * 0.25

	if space_visible:
		queue_redraw()

func _draw():
	if not space_visible:
		return

	draw_rect(Rect2(Vector2(-200, 0), SCREEN_SIZE + Vector2(400, 0)), Color("#0B0620"))

	for n in nebulae:
		for i in 5:
			draw_circle(n["pos"], n["radius"] * (1.0 - i * 0.18), n["color"])

	for s in stars:
		var twinkle: float = 0.5 + 0.5 * sin(time * s["speed"] + s["phase"])
		draw_circle(s["pos"], s["size"], Color(1.0, 0.95, 0.85, 0.3 + 0.7 * twinkle))

	# Topun etrafındaki sıcak ışık
	if ball_floating:
		for i in 4:
			draw_circle(ball.position, 70.0 - i * 12.0, Color("#FFB347", 0.05 + i * 0.03))
