extends Node2D
## Oyunun final / bitiş sahnesi (Intro.tscn ile aynı sinematik yapıda).
## Küçük top son kara delikten çıkar -> binlerce topun yaşadığı kendi evrenine ulaşır ->
## ailesi (Anne, Baba ve küçük kardeş top) yanına gelip ona sımsıkı sarılır.

const GameProgress := preload("res://scripts/game_progress.gd")
const SoundManager := preload("res://scripts/sound_manager.gd")

const CHAR_TIME := 0.045
const SCREEN_SIZE := Vector2(1280, 720)
const HOLE_POS := Vector2(230, 210)
const HUG_CENTER := Vector2(640, 315)

@onready var black_hole: Node2D = $BlackHole
@onready var dad_ball: Sprite2D = $DadBall
@onready var mom_ball: Sprite2D = $MomBall
@onready var ball: Sprite2D = $Ball
@onready var sibling_ball: Sprite2D = $SiblingBall
@onready var overlay_drawer: Node2D = $OverlayDrawer

@onready var caption_box: Control = $UI/CaptionBox
@onready var caption: Label = $UI/CaptionBox/Center/Panel/Caption
@onready var credits_screen: ColorRect = $UI/CreditsScreen
@onready var credits_roll: VBoxContainer = $UI/CreditsScreen/CreditsRoll
@onready var credits_body: Label = $UI/CreditsScreen/CreditsRoll/CreditsBody
@onready var skip_button: Button = $UI/SkipButton
@onready var flash_rect: ColorRect = $UI/Flash
@onready var fade_rect: ColorRect = $UI/Fade

var stars: Array = []
var nebulae: Array = []
var bg_balls_far: Array = []
var bg_balls_mid: Array = []
var bg_balls_near: Array = []
var hearts: Array = []

var time: float = 0.0
var crowd_alpha: float = 0.0
var family_visible: bool = false
var hug_progress: float = 0.0
var ball_floating: bool = false
var hero_base_pos: Vector2 = HUG_CENTER
var dad_base_pos: Vector2 = HUG_CENTER + Vector2(54, -10)
var mom_base_pos: Vector2 = HUG_CENTER + Vector2(-52, -6)
var sibling_base_pos: Vector2 = HUG_CENTER + Vector2(24, 30)

var typing: bool = false
var typing_tween: Tween
var credits_active: bool = false
var credits_scrolling: bool = false
var finishing: bool = false

func _ready():
	_generate_home_universe()
	SoundManager.play_ending_music()

	overlay_drawer.draw.connect(_draw_family_overlay)

	black_hole.position = HOLE_POS
	black_hole.scale = Vector2.ONE * 1.35
	black_hole.show()

	ball.position = HOLE_POS
	ball.scale = Vector2.ZERO
	ball.modulate = Color(0.85, 0.5, 1.0, 0.0)

	dad_ball.hide()
	mom_ball.hide()
	sibling_ball.hide()

	caption.text = ""
	caption_box.modulate.a = 0.0
	credits_screen.hide()
	credits_body.text = GameProgress.t("ending_credits")
	flash_rect.modulate.a = 0.0
	fade_rect.modulate.a = 1.0

	skip_button.text = GameProgress.t("skip")
	skip_button.pressed.connect(_on_skip_pressed)

	_play()

func _play():
	# 1) Sahne açılır, son kara delik parlar ve küçük topu kendi evrenine fırlatır
	await _tween_alpha(fade_rect, 0.0, 1.1).finished
	black_hole.set("speed_mult", 3.2)

	var emerge := create_tween().set_parallel(true)
	var spiral_out := func(t: float):
		var start_ofs := Vector2(120, 40)
		ball.position = HOLE_POS.lerp(Vector2(520, 325), t) + start_ofs.rotated((1.0 - t) * TAU * 1.2) * (1.0 - t) * 0.45
	emerge.tween_method(spiral_out, 0.0, 1.0, 1.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	emerge.tween_property(ball, "scale", Vector2(0.17, 0.17), 1.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	emerge.tween_property(ball, "rotation", TAU * 3.0, 1.7) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	emerge.tween_property(ball, "modulate", Color.WHITE, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_type(GameProgress.t("ending_0"))
	await emerge.finished

	hero_base_pos = ball.position
	ball_floating = true

	# Kara delik kapanarak kaybolur
	var close_hole := create_tween()
	close_hole.tween_property(black_hole, "scale", Vector2.ZERO, 0.75) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await close_hole.finished
	black_hole.hide()
	await _wait(0.5)

	# 2) Sıcak altın parlama ile binlerce topun bulunduğu ana evren aydınlanır
	await _tween_alpha(flash_rect, 0.85, 0.25).finished
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(self, "crowd_alpha", 1.0, 1.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(ball, "position:x", HUG_CENTER.x - 4.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hero_base_pos = Vector2(HUG_CENTER.x - 4.0, HUG_CENTER.y + 4.0)
	_tween_alpha(flash_rect, 0.0, 0.95)

	await _type(GameProgress.t("ending_1"))
	await _wait(1.6)

	# 3) Ailesi (Anne, Baba ve küçük kardeş top) sağdan ve soldan sevinçle gelip sarılır
	family_visible = true
	dad_ball.show()
	mom_ball.show()
	sibling_ball.show()

	dad_ball.position = Vector2(1080, 295)
	mom_ball.position = Vector2(200, 300)
	sibling_ball.position = Vector2(1120, 355)

	dad_base_pos = HUG_CENTER + Vector2(46.0, -8.0)
	mom_base_pos = HUG_CENTER + Vector2(-46.0, -5.0)
	sibling_base_pos = HUG_CENTER + Vector2(22.0, 28.0)
	hero_base_pos = HUG_CENTER + Vector2(-2.0, 6.0)

	var reunite := create_tween().set_parallel(true)
	reunite.tween_property(dad_ball, "position", dad_base_pos, 1.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reunite.tween_property(mom_ball, "position", mom_base_pos, 1.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reunite.tween_property(sibling_ball, "position", sibling_base_pos, 1.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reunite.tween_property(ball, "position", hero_base_pos, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_type(GameProgress.t("ending_2"))
	await reunite.finished

	# Sımsıkı sarılma animasyonu ve kalpler
	var hug_tween := create_tween()
	hug_tween.tween_property(self, "hug_progress", 1.0, 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await hug_tween.finished
	_spawn_hug_hearts()
	await _wait(1.6)

	# 4) Final mesajı
	await _type(GameProgress.t("ending_3"))
	await _wait(2.8)

	if not credits_active and not finishing:
		_start_credits_roll()

func _on_skip_pressed():
	if finishing:
		return
	if not credits_active:
		_start_credits_roll()
	else:
		_finish_to_menu()

func _start_credits_roll():
	if credits_active or finishing:
		return
	credits_active = true
	typing = false
	if typing_tween and typing_tween.is_valid():
		typing_tween.kill()

	await _tween_alpha(fade_rect, 1.0, 0.85).finished
	if finishing:
		return

	caption_box.hide()
	credits_body.text = GameProgress.t("ending_credits")
	credits_roll.position.y = 730.0
	credits_screen.show()
	skip_button.text = GameProgress.t("main_menu")

	await _tween_alpha(fade_rect, 0.0, 0.65).finished
	credits_scrolling = true

func _finish_to_menu():
	if finishing:
		return
	finishing = true
	credits_scrolling = false
	skip_button.disabled = true
	await _tween_alpha(fade_rect, 1.0, 0.85).finished
	GameProgress.go_to_menu()

func _type(text: String) -> void:
	if finishing or credits_active:
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
	if finishing or credits_active:
		return
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished

func _tween_alpha(node: CanvasItem, alpha: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", alpha, duration)
	return tween

func _unhandled_input(event: InputEvent):
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed("ui_accept")
	if pressed and typing and typing_tween and typing_tween.is_valid():
		typing_tween.custom_step(100.0)

func _generate_home_universe():
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for i in range(170):
		stars.append({
			"pos": Vector2(rng.randf_range(0.0, SCREEN_SIZE.x), rng.randf_range(0.0, SCREEN_SIZE.y)),
			"size": rng.randf_range(0.8, 2.3),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.5, 3.8),
		})

	nebulae = [
		{"pos": Vector2(640, 290), "radius": 380.0, "color": Color("#FF9436", 0.08)},
		{"pos": Vector2(280, 220), "radius": 290.0, "color": Color("#FF5E9C", 0.06)},
		{"pos": Vector2(990, 250), "radius": 310.0, "color": Color("#8C42FF", 0.07)},
		{"pos": Vector2(640, 500), "radius": 320.0, "color": Color("#FFB84D", 0.06)},
	]

	# 1. En uzaktaki yüzlerce/binlerce minik top (derinlik hissi veren yoğun küre bulutu)
	for i in range(320):
		var pos := Vector2(rng.randf_range(20.0, 1260.0), rng.randf_range(20.0, 660.0))
		# Merkezdeki aile sarılma alanını (640, 315) hafifçe açık bırak
		if pos.distance_to(HUG_CENTER) < 115.0:
			pos += (pos - HUG_CENTER).normalized() * 115.0
		bg_balls_far.append({
			"pos": pos,
			"r": rng.randf_range(2.2, 5.2),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.2, 2.8),
			"tint": rng.randf_range(0.0, 1.0),
		})

	# 2. Orta mesafede süzülen basketbol topları
	for i in range(85):
		var pos := Vector2(rng.randf_range(35.0, 1245.0), rng.randf_range(35.0, 620.0))
		if pos.distance_to(HUG_CENTER) < 145.0:
			pos += (pos - HUG_CENTER).normalized() * 145.0
		bg_balls_mid.append({
			"pos": pos,
			"r": rng.randf_range(7.0, 13.5),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.4, 2.6),
			"hue": rng.randf_range(-0.04, 0.05),
		})

	# 3. Daha yakında neşeyle süzülen ve gülümseyen toplar
	for i in range(26):
		var pos := Vector2(rng.randf_range(60.0, 1220.0), rng.randf_range(50.0, 560.0))
		if pos.distance_to(HUG_CENTER) < 190.0:
			pos += (pos - HUG_CENTER).normalized() * 185.0
		bg_balls_near.append({
			"pos": pos,
			"r": rng.randf_range(16.0, 23.0),
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.6, 2.4),
		})

func _spawn_hug_hearts():
	for i in range(10):
		hearts.append({
			"pos": HUG_CENTER + Vector2(randf_range(-65.0, 65.0), randf_range(-35.0, 10.0)),
			"vel": Vector2(randf_range(-14.0, 14.0), randf_range(-42.0, -24.0)),
			"scale": randf_range(0.75, 1.25),
			"phase": randf() * TAU,
			"alpha": 1.0,
		})

func _process(delta: float):
	time += delta

	if credits_scrolling and not finishing:
		credits_roll.position.y -= 48.0 * delta
		var roll_h := maxf(credits_roll.size.y, 520.0)
		if credits_roll.position.y + roll_h < -40.0:
			_finish_to_menu()
		return

	if ball_floating:
		var bob := sin(time * 2.3) * 6.5
		if hug_progress > 0.01:
			# Sarılırken tüm aile birlikte nefes alır gibi hafifçe süzülür
			var shared_bob := sin(time * 2.2) * 5.5
			var squeeze := sin(time * 4.2) * 1.5 * hug_progress
			ball.position = hero_base_pos + Vector2(0.0, shared_bob)
			ball.rotation = sin(time * 1.5) * 0.06
			dad_ball.position = dad_base_pos + Vector2(-squeeze, shared_bob)
			dad_ball.rotation = -0.10 * hug_progress
			mom_ball.position = mom_base_pos + Vector2(squeeze, shared_bob)
			mom_ball.rotation = 0.10 * hug_progress
			sibling_ball.position = sibling_base_pos + Vector2(-squeeze * 0.6, shared_bob + sin(time * 3.5) * 2.0)
			sibling_ball.rotation = -0.12 * hug_progress
		else:
			ball.position.y = hero_base_pos.y + bob
			ball.rotation = sin(time * 1.2) * 0.15

	# Kalplerin yükselişi
	if hug_progress >= 0.95 and randf() < delta * 2.2:
		hearts.append({
			"pos": HUG_CENTER + Vector2(randf_range(-58.0, 58.0), randf_range(-30.0, 0.0)),
			"vel": Vector2(randf_range(-12.0, 12.0), randf_range(-38.0, -22.0)),
			"scale": randf_range(0.7, 1.15),
			"phase": randf() * TAU,
			"alpha": 1.0,
		})

	for i in range(hearts.size() - 1, -1, -1):
		var h: Dictionary = hearts[i]
		h["pos"] = (h["pos"] as Vector2) + (h["vel"] as Vector2) * delta + Vector2(sin(time * 3.0 + float(h["phase"])) * 12.0 * delta, 0.0)
		h["alpha"] = float(h["alpha"]) - delta * 0.42
		if float(h["alpha"]) <= 0.0:
			hearts.remove_at(i)
		else:
			hearts[i] = h

	queue_redraw()
	overlay_drawer.queue_redraw()

func _draw():
	# 1. Kozmik yuva arka planı
	draw_rect(Rect2(Vector2(-100, -100), SCREEN_SIZE + Vector2(200, 200)), Color("#0B0620"))

	for n in nebulae:
		var n_pos: Vector2 = n["pos"]
		var n_rad: float = n["radius"]
		var n_col: Color = n["color"]
		for i in range(5):
			draw_circle(n_pos, n_rad * (1.0 - float(i) * 0.18), n_col)

	for s in stars:
		var s_pos: Vector2 = s["pos"]
		var s_size: float = s["size"]
		var twinkle: float = 0.5 + 0.5 * sin(time * float(s["speed"]) + float(s["phase"]))
		draw_circle(s_pos, s_size, Color(1.0, 0.95, 0.85, 0.3 + 0.7 * twinkle))

	# 2. Binlerce Topun Bulunduğu Evren (3 derinlik katmanı)
	if crowd_alpha > 0.001:
		# A) Uzak katman (yüzlerce parlayan turuncu-altın top küresi)
		for i in range(bg_balls_far.size()):
			var b: Dictionary = bg_balls_far[i]
			var bp: Vector2 = b["pos"]
			var br: float = b["r"]
			var bob := sin(time * float(b["speed"]) + float(b["phase"])) * 3.5
			var p := bp + Vector2(0.0, bob)
			var c := Color("#E87425").lerp(Color("#FFB347"), float(b["tint"]))
			c.a = crowd_alpha * 0.62
			draw_circle(p, br, c)
			draw_circle(p + Vector2(-br * 0.28, -br * 0.28), br * 0.35, Color(1.0, 0.92, 0.75, crowd_alpha * 0.55))

		# B) Orta katman (basketbol çizgili toplar)
		for i in range(bg_balls_mid.size()):
			var b: Dictionary = bg_balls_mid[i]
			var bp: Vector2 = b["pos"]
			var br: float = b["r"]
			var bob := sin(time * float(b["speed"]) + float(b["phase"])) * 6.0
			var p := bp + Vector2(0.0, bob)
			_draw_mini_basketball(p, br, crowd_alpha * 0.82, false)

		# C) Yakın katman (neşeyle zıplayan ve gülümseyen toplar)
		for i in range(bg_balls_near.size()):
			var b: Dictionary = bg_balls_near[i]
			var bp: Vector2 = b["pos"]
			var br: float = b["r"]
			var bob := sin(time * float(b["speed"]) + float(b["phase"])) * 9.0
			var p := bp + Vector2(0.0, bob)
			_draw_mini_basketball(p, br, crowd_alpha * 0.95, true)

	# 3. Aile sarılma merkezindeki sıcak altın-pembe sevgi halesi
	if ball_floating:
		var glow_center := HUG_CENTER if hug_progress > 0.1 else ball.position
		var glow_r := lerpf(75.0, 155.0, hug_progress)
		for i in range(5):
			var r := glow_r * (1.0 - float(i) * 0.16)
			var col := Color("#FFB347", 0.05 + float(i) * 0.025).lerp(Color("#FF78B0", 0.07 + float(i) * 0.025), hug_progress * 0.5)
			draw_circle(glow_center, r, col)

func _draw_mini_basketball(center: Vector2, r: float, alpha: float, draw_smile: bool):
	# Dış sıcak hale
	draw_circle(center, r * 1.25, Color(1.0, 0.62, 0.22, alpha * 0.14))
	# Ana turuncu gövde + gölge ve parlama
	draw_circle(center, r, Color(0.88, 0.42, 0.12, alpha))
	draw_circle(center + Vector2(-r * 0.18, -r * 0.18), r * 0.78, Color(0.96, 0.54, 0.18, alpha))
	draw_circle(center + Vector2(-r * 0.32, -r * 0.32), r * 0.28, Color(1.0, 0.82, 0.52, alpha * 0.75))

	# Basketbol oluk çizgileri
	var seam_col := Color(0.22, 0.09, 0.04, alpha * 0.75)
	draw_line(center + Vector2(-r * 0.92, 0.0), center + Vector2(r * 0.92, 0.0), seam_col, maxf(1.0, r * 0.09))
	draw_line(center + Vector2(0.0, -r * 0.92), center + Vector2(0.0, r * 0.92), seam_col, maxf(1.0, r * 0.09))
	draw_arc(center, r, 0.0, TAU, 24, Color(0.18, 0.07, 0.03, alpha * 0.85), maxf(1.1, r * 0.10))

	if draw_smile:
		var eye_col := Color(0.15, 0.06, 0.03, alpha)
		draw_arc(center + Vector2(-r * 0.28, -r * 0.10), r * 0.13, PI, TAU, 8, eye_col, 1.6)
		draw_arc(center + Vector2(r * 0.28, -r * 0.10), r * 0.13, PI, TAU, 8, eye_col, 1.6)
		draw_arc(center + Vector2(0.0, r * 0.04), r * 0.24, 0.15, PI - 0.15, 10, eye_col, 1.6)

func _draw_family_overlay():
	if not ball_floating:
		return

	# 1. Küçük Topun (Kahraman) yüz ifadesi
	var hp := ball.position
	_draw_happy_face(hp, 26.0, hug_progress, false, false, true)

	if not family_visible:
		return

	var dp := dad_ball.position
	var mp := mom_ball.position
	var sp := sibling_ball.position

	# 2. Anne Topun başında zarif pembe fiyonk ve sevgi dolu yüzü
	_draw_mom_bow(mp + Vector2(-6.0, -30.0))
	_draw_happy_face(mp, 31.0, hug_progress, true, false, false)

	# 3. Baba Topun babacan bıyığı/kaşları ve gururlu yüzü
	_draw_happy_face(dp, 34.0, hug_progress, false, true, false)

	# 4. Küçük Kardeş Topun sevimli yüzü
	_draw_happy_face(sp, 19.0, hug_progress, false, false, false)

	# 5. Sarılma Kolları (Anne ve Baba kollarını küçük topun ve kardeşin etrafına sarar)
	if hug_progress > 0.05:
		var arm_alpha := clampf(hug_progress, 0.0, 1.0)
		var arm_dark := Color(0.20, 0.07, 0.03, arm_alpha)
		var arm_fill := Color(0.93, 0.45, 0.14, arm_alpha)

		# Annenin sarılan kolu (soldan merkeze doğru uzanır)
		var mom_arm := PackedVector2Array([
			mp + Vector2(-12.0, 8.0),
			mp.lerp(hp, 0.48) + Vector2(0.0, 18.0),
			hp + Vector2(-6.0, 14.0) * hug_progress + Vector2(-14.0, 10.0) * (1.0 - hug_progress),
		])
		overlay_drawer.draw_polyline(mom_arm, arm_dark, 11.0, true)
		overlay_drawer.draw_polyline(mom_arm, arm_fill, 6.5, true)
		overlay_drawer.draw_circle(mom_arm[2], 6.0, arm_dark)
		overlay_drawer.draw_circle(mom_arm[2], 4.2, arm_fill)

		# Babanın sarılan kolu (sağdan merkeze ve kardeşin omzuna doğru uzanır)
		var dad_arm := PackedVector2Array([
			dp + Vector2(14.0, 6.0),
			dp.lerp(hp, 0.50) + Vector2(4.0, 20.0),
			hp + Vector2(8.0, 12.0) * hug_progress + Vector2(16.0, 8.0) * (1.0 - hug_progress),
		])
		overlay_drawer.draw_polyline(dad_arm, arm_dark, 12.0, true)
		overlay_drawer.draw_polyline(dad_arm, arm_fill, 7.2, true)
		overlay_drawer.draw_circle(dad_arm[2], 6.5, arm_dark)
		overlay_drawer.draw_circle(dad_arm[2], 4.5, arm_fill)

		# Küçük topun iki yana açıp ailesine sarılan kolları
		var hero_left_arm := PackedVector2Array([
			hp + Vector2(-14.0, 4.0),
			hp.lerp(mp, 0.55) + Vector2(0.0, 6.0),
		])
		var hero_right_arm := PackedVector2Array([
			hp + Vector2(14.0, 4.0),
			hp.lerp(dp, 0.55) + Vector2(0.0, 6.0),
		])
		overlay_drawer.draw_polyline(hero_left_arm, arm_dark, 8.5, true)
		overlay_drawer.draw_polyline(hero_left_arm, arm_fill, 5.0, true)
		overlay_drawer.draw_polyline(hero_right_arm, arm_dark, 8.5, true)
		overlay_drawer.draw_polyline(hero_right_arm, arm_fill, 5.0, true)

	# 6. Yükselen sevgi kalpleri
	for i in range(hearts.size()):
		var h: Dictionary = hearts[i]
		_draw_heart(h["pos"], float(h["scale"]) * 10.0, Color(1.0, 0.38, 0.62, float(h["alpha"])))

func _draw_happy_face(center: Vector2, r: float, hug_t: float, is_mom: bool, is_dad: bool, is_hero: bool):
	var dark := Color("#260C04")
	var cheek_col := Color(1.0, 0.42, 0.55, 0.45 + 0.35 * hug_t)

	# Pembe yanaklar
	overlay_drawer.draw_circle(center + Vector2(-r * 0.44, r * 0.08), r * 0.16, cheek_col)
	overlay_drawer.draw_circle(center + Vector2(r * 0.44, r * 0.08), r * 0.16, cheek_col)

	# Gözler: sarılırken mutlulukla kapanan gülen gözler (^ ^)
	for side: float in [-1.0, 1.0]:
		var ex: float = center.x + side * r * 0.28
		var ey: float = center.y - r * 0.10
		if hug_t > 0.35:
			overlay_drawer.draw_arc(Vector2(ex, ey + r * 0.04), r * 0.14, PI + 0.25, TAU - 0.25, 12, dark, 2.4)
			if is_mom:
				overlay_drawer.draw_line(
					Vector2(ex + side * r * 0.13, ey - r * 0.02),
					Vector2(ex + side * r * 0.21, ey - r * 0.10),
					dark,
					2.0
				)
		else:
			overlay_drawer.draw_circle(Vector2(ex, ey), r * 0.11, dark)
			overlay_drawer.draw_circle(Vector2(ex - r * 0.03, ey - r * 0.03), r * 0.04, Color.WHITE)

	# Baba topun kalın babacan kaşları ve bıyığı
	if is_dad:
		for side: float in [-1.0, 1.0]:
			var bx: float = center.x + side * r * 0.28
			var by: float = center.y - r * 0.28
			overlay_drawer.draw_line(Vector2(bx - r * 0.13, by), Vector2(bx + r * 0.13, by - side * 1.5), Color("#3D1A08"), 3.2)
		# Bıyık
		var my := center.y + r * 0.06
		overlay_drawer.draw_arc(Vector2(center.x - r * 0.12, my + 3.0), r * 0.14, PI * 1.1, PI * 1.95, 10, Color("#3D1A08"), 3.4)
		overlay_drawer.draw_arc(Vector2(center.x + r * 0.12, my + 3.0), r * 0.14, PI * 1.05, PI * 1.9, 10, Color("#3D1A08"), 3.4)

	# Gülümseyen ağız
	var mouth_y := center.y + (r * 0.16 if is_dad else r * 0.06)
	overlay_drawer.draw_arc(Vector2(center.x, mouth_y), r * 0.24, 0.18, PI - 0.18, 14, dark, 2.4)

	# Küçük topun ve annenin göz kenarında mutluluk gözyaşı damlası (sarılırken)
	if (is_hero or is_mom) and hug_t > 0.5:
		var tear_alpha := clampf((hug_t - 0.5) * 2.0, 0.0, 1.0)
		var tear_dir := -1.0 if is_hero else 1.0
		var tear_pos := center + Vector2(tear_dir * r * 0.44, -r * 0.02)
		overlay_drawer.draw_circle(tear_pos, r * 0.09, Color(0.55, 0.90, 1.0, tear_alpha * 0.9))
		overlay_drawer.draw_circle(tear_pos + Vector2(-1.0, -1.0), r * 0.035, Color(1.0, 1.0, 1.0, tear_alpha))

func _draw_mom_bow(pos: Vector2):
	var bow_col := Color("#FF5C98")
	var bow_dark := Color("#4A0E26")
	var left_wing := PackedVector2Array([
		pos,
		pos + Vector2(-13.0, -7.0),
		pos + Vector2(-11.0, 6.0),
	])
	var right_wing := PackedVector2Array([
		pos,
		pos + Vector2(13.0, -7.0),
		pos + Vector2(11.0, 6.0),
	])
	overlay_drawer.draw_colored_polygon(left_wing, bow_col)
	overlay_drawer.draw_colored_polygon(right_wing, bow_col)
	overlay_drawer.draw_polyline(left_wing, bow_dark, 1.8)
	overlay_drawer.draw_polyline(right_wing, bow_dark, 1.8)
	overlay_drawer.draw_circle(pos, 4.2, Color("#FF94BC"))
	overlay_drawer.draw_arc(pos, 4.2, 0.0, TAU, 12, bow_dark, 1.6)

func _draw_heart(pos: Vector2, s: float, col: Color):
	var r := s * 0.5
	overlay_drawer.draw_circle(pos + Vector2(-r * 0.55, -r * 0.3), r * 0.62, col)
	overlay_drawer.draw_circle(pos + Vector2(r * 0.55, -r * 0.3), r * 0.62, col)
	var tri := PackedVector2Array([
		pos + Vector2(-r * 1.12, -r * 0.1),
		pos + Vector2(r * 1.12, -r * 0.1),
		pos + Vector2(0.0, r * 1.15),
	])
	overlay_drawer.draw_colored_polygon(tri, col)
