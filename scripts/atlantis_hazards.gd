@tool
extends Node2D
## Bölüm 9 (Kayıp Atlantis) su altı engelleri:
## 1) Parlayan Elektrikli Denizanaları (Üst kubbesi trambolin gibi sektirir, alt elektrikli dokunaçları çarpar)
## 2) Şişen Kirpi Balıkları (Periyodik olarak şişip dikenlerini çıkarır, çarpan topu güçlüce geri fırlatır)

const GameProgress := preload("res://scripts/game_progress.gd")
const SoundManager := preload("res://scripts/sound_manager.gd")

var ball: RigidBody2D = null
var main_node: Node2D = null

var _time: float = 0.0

# --- 1. Parlayan Elektrikli Denizanaları ---
var _jellyfish: Array = [
	{
		"base_pos": Vector2(410.0, 235.0),
		"pos": Vector2(410.0, 235.0),
		"amp": 52.0,
		"speed": 1.55,
		"phase": 0.0,
		"squash": 0.0,
		"cooldown": 0.0,
		"color_top": Color("#FF58CD"),
		"color_rim": Color("#38F6FF"),
	},
	{
		"base_pos": Vector2(885.0, 225.0),
		"pos": Vector2(885.0, 225.0),
		"amp": 52.0,
		"speed": 1.45,
		"phase": 2.6,
		"squash": 0.0,
		"cooldown": 0.0,
		"color_top": Color("#9A5CFF"),
		"color_rim": Color("#45F9E6"),
	},
]

var _shocking_ball: bool = false
var _shock_timer: float = 0.0
var _shock_ball_origin: Vector2 = Vector2.ZERO

# --- 2. Şişen Kirpi Balıkları (Pufferfish) ---
const PUFFER_CYCLE: float = 4.6
const PUFFER_MIN_R: float = 20.0
const PUFFER_MAX_R: float = 48.0

var _pufferfish: Array = [
	{
		"base_pos": Vector2(455.0, 475.0),
		"pos": Vector2(455.0, 475.0),
		"phase": 0.0,
		"inflate": 0.0,
		"hit_pulse": 0.0,
		"cooldown": 0.0,
		"facing": -1.0,
	},
	{
		"base_pos": Vector2(860.0, 465.0),
		"pos": Vector2(860.0, 465.0),
		"phase": 2.3, # İlk balıkla ters zamanlı şişsin
		"inflate": 0.0,
		"hit_pulse": 0.0,
		"cooldown": 0.0,
		"facing": -1.0,
	},
]

func _ready():
	z_index = 2
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if Engine.is_editor_hint():
		queue_redraw()
		return

	if not main_node:
		main_node = get_parent() as Node2D
	if main_node and not ball:
		ball = main_node.get_node_or_null("Ball") as RigidBody2D

func _physics_process(delta: float):
	if Engine.is_editor_hint():
		return

	_time += delta

	if _shocking_ball:
		_shock_timer += delta
		if is_instance_valid(ball):
			var jitter := Vector2(sin(_time * 95.0) * 4.5, cos(_time * 88.0) * 4.5)
			ball.global_position = _shock_ball_origin + jitter
		queue_redraw()
		if _shock_timer >= 0.65:
			_shocking_ball = false
			if is_instance_valid(ball):
				ball.modulate = Color.WHITE
			if is_instance_valid(main_node) and main_node.has_method("end_game"):
				main_node.end_game(GameProgress.t("shocked_by_jellyfish"))
		return

	if is_instance_valid(main_node) and main_node.get("game_over") == true:
		queue_redraw()
		return

	var shot_active := _is_shot_active()
	_process_jellyfish(delta, shot_active)
	_process_pufferfish(delta, shot_active)
	queue_redraw()

func _is_shot_active() -> bool:
	if not is_instance_valid(ball) or ball.freeze:
		return false
	if is_instance_valid(main_node):
		if int(main_node.get("shot_count")) <= 0:
			return false
		if bool(main_node.get("cutscene_active")):
			return false
	return true

# ------------------------------------------------------------------------------
# 1. Elektrikli Denizanaları Fiziği
# ------------------------------------------------------------------------------

func _process_jellyfish(delta: float, shot_active: bool):
	var ball_r := 15.0
	for j in _jellyfish:
		var ph: float = float(j["phase"]) + _time * float(j["speed"])
		var bpos: Vector2 = j["base_pos"]
		var cur_pos := bpos + Vector2(sin(ph * 0.5) * 10.0, sin(ph) * float(j["amp"]))
		j["pos"] = cur_pos
		j["squash"] = move_toward(float(j["squash"]), 0.0, delta * 3.0)
		j["cooldown"] = maxf(0.0, float(j["cooldown"]) - delta)

		if not shot_active:
			continue

		var rel := ball.global_position - cur_pos

		# A) Üst kubbe (Trambolin sekme bölgesi: rel.y <= 8.0)
		var dome_center := Vector2(0.0, -6.0)
		var d_vec := rel - dome_center
		# Elips mesafe kontrolü (rx = 38 + ball_r, ry = 28 + ball_r)
		var nx := d_vec.x / (38.0 + ball_r)
		var ny := d_vec.y / (28.0 + ball_r)
		if rel.y <= 8.0 and (nx * nx + ny * ny) <= 1.0 and float(j["cooldown"]) <= 0.0:
			j["cooldown"] = 0.16
			j["squash"] = 1.0
			var bounce_dir := Vector2(d_vec.x * 0.7, minf(-12.0, d_vec.y)).normalized()
			var spd := maxf(ball.linear_velocity.length() * 1.28, 350.0)
			ball.linear_velocity = bounce_dir * spd
			ball.global_position = cur_pos + dome_center + bounce_dir * (38.0 + ball_r + 2.0)
			SoundManager.play_click()
			continue

		# B) Alt elektrikli dokunaçlar (Çarpılma bölgesi: rel.y > 10.0 .. 88.0)
		if rel.y > 10.0 and rel.y < 88.0 and absf(rel.x) < (24.0 + ball_r * 0.65):
			_trigger_electric_shock()
			return

func _trigger_electric_shock():
	if _shocking_ball or not is_instance_valid(ball):
		return
	_shocking_ball = true
	_shock_timer = 0.0
	_shock_ball_origin = ball.global_position

	if is_instance_valid(main_node):
		main_node.set("is_dragging", false)
		main_node.queue_redraw()

	ball.call_deferred("set_linear_velocity", Vector2.ZERO)
	ball.call_deferred("set_angular_velocity", 0.0)
	ball.call_deferred("set_freeze_enabled", true)
	ball.modulate = Color(1.7, 2.3, 2.8, 1.0)

# ------------------------------------------------------------------------------
# 2. Şişen Kirpi Balıkları Fiziği
# ------------------------------------------------------------------------------

func _process_pufferfish(delta: float, shot_active: bool):
	var ball_r := 15.0
	for p in _pufferfish:
		var bpos: Vector2 = p["base_pos"]
		var ph: float = float(p["phase"])
		var cyc := fmod(_time + ph, PUFFER_CYCLE)

		# Döngü: 0..2.1s küçük, 2.1..2.5s şişiyor, 2.5..4.15s şişmiş dikenli, 4.15..4.6s iniyor
		var inf := 0.0
		if cyc < 2.1:
			inf = 0.0
		elif cyc < 2.5:
			var t := (cyc - 2.1) / 0.4
			inf = clampf(1.0 + sin((t - 1.0) * PI * 0.5) * 0.15 + t, 0.0, 1.08)
			inf = ease(t, -2.0)
		elif cyc < 4.15:
			inf = 1.0 + sin((cyc - 2.5) * 8.0) * 0.04
		else:
			var t := (cyc - 4.15) / 0.45
			inf = 1.0 - ease(clampf(t, 0.0, 1.0), 1.8)

		p["inflate"] = inf
		p["hit_pulse"] = move_toward(float(p["hit_pulse"]), 0.0, delta * 3.5)
		p["cooldown"] = maxf(0.0, float(p["cooldown"]) - delta)

		var bob_y := sin((_time + ph) * 2.2) * 8.0
		var cur_pos := bpos + Vector2(0.0, bob_y)
		p["pos"] = cur_pos

		if not shot_active or float(p["cooldown"]) > 0.0:
			continue

		var cur_r := lerpf(PUFFER_MIN_R, PUFFER_MAX_R, clampf(inf, 0.0, 1.0))
		var diff := ball.global_position - cur_pos
		var dist := diff.length()
		var min_dist := cur_r + ball_r
		if dist < min_dist and dist > 0.001:
			p["cooldown"] = 0.14
			p["hit_pulse"] = 1.0
			var n := diff / dist
			var bounce_mult := 1.35 if inf >= 0.4 else 1.05
			var min_spd := 390.0 if inf >= 0.4 else 250.0
			var spd := maxf(ball.linear_velocity.length() * bounce_mult, min_spd)
			ball.global_position = cur_pos + n * (min_dist + 2.5)
			ball.linear_velocity = n * spd
			SoundManager.play_click()

# ------------------------------------------------------------------------------
# Çizimler
# ------------------------------------------------------------------------------

func _draw():
	for j in _jellyfish:
		_draw_single_jellyfish(j)
	for p in _pufferfish:
		_draw_single_pufferfish(p)
	if _shocking_ball and is_instance_valid(ball):
		_draw_ball_shock_effect(ball.global_position)

func _draw_single_jellyfish(j: Dictionary):
	var pos: Vector2 = j["pos"] if not Engine.is_editor_hint() else j["base_pos"]
	var ph: float = float(j["phase"]) + _time * float(j["speed"])
	var sq: float = float(j["squash"])
	var pulse := sin(ph * 2.0) * 0.07
	var sx := 1.0 + pulse + sq * 0.24
	var sy := 1.0 - pulse - sq * 0.20

	var top_col: Color = j["color_top"]
	var rim_col: Color = j["color_rim"]

	# 1. Dış biyolüminesan parıltı (glow)
	draw_circle(pos + Vector2(0, -4), 48.0, Color(rim_col.r, rim_col.g, rim_col.b, 0.14))

	# 2. Alt elektrikli dokunaçlar (6 dalgalı dokunaç + aralarında elektrik arkları)
	var tentacle_count := 6
	for ti in range(tentacle_count):
		var tx_base := -21.0 + ti * 8.4
		var pts := PackedVector2Array()
		var segs := 8
		for s in range(segs + 1):
			var frac := float(s) / float(segs)
			var wave := sin(_time * 5.2 + ti * 1.1 + frac * 4.2) * (6.5 * frac)
			var px := pos.x + tx_base * sx + wave
			var py := pos.y + 6.0 + frac * 78.0
			pts.append(Vector2(px, py))
		draw_polyline(pts, Color(rim_col.r, rim_col.g, rim_col.b, 0.38), 4.5)
		draw_polyline(pts, Color(top_col.r, top_col.g, top_col.b, 0.85), 2.2)

	# Dokunaçlar üzerinde çakan sarı-camgöbeği elektrik kıvılcımları
	for ei in range(3):
		var spark_y := pos.y + 18.0 + fmod(_time * 65.0 + ei * 24.0, 62.0)
		var sx1 := pos.x - 18.0 + sin(_time * 22.0 + ei * 2.0) * 6.0
		var sx2 := pos.x + 18.0 + cos(_time * 25.0 + ei * 1.7) * 6.0
		var mid := Vector2((sx1 + sx2) * 0.5, spark_y + sin(_time * 40.0 + ei) * 5.0)
		var bolt := PackedVector2Array([Vector2(sx1, spark_y), mid, Vector2(sx2, spark_y + 2.0)])
		draw_polyline(bolt, Color(0.3, 0.95, 1.0, 0.65), 3.2)
		draw_polyline(bolt, Color(1.0, 0.96, 0.45, 0.95), 1.5)

	# 3. Üst kubbe (Trambolin şapka)
	var dome_pts := PackedVector2Array()
	var rx := 38.0 * sx
	var ry := 28.0 * sy
	for i in range(19):
		var a := PI + float(i) / 18.0 * PI # Üst yarım elips (PI .. 2*PI)
		dome_pts.append(pos + Vector2(cos(a) * rx, 6.0 + sin(a) * ry))
	# Alt fırfırlı kenar (uç noktaları tekrarlamadan ve üst kubbeyi kesmeden)
	for i in range(7, 0, -1):
		var frac := float(i) / 8.0
		var lx := lerpf(-rx, rx, frac)
		var env := sin(frac * PI) # Uçlarda sıfırlanan zarf
		var frill := 9.0 + sin(frac * PI * 5.0 + _time * 4.0) * 3.0 * env
		dome_pts.append(pos + Vector2(lx, frill))

	draw_colored_polygon(dome_pts, Color(top_col.r, top_col.g, top_col.b, 0.82))

	# İç parlak katman
	var inner_pts := PackedVector2Array()
	for i in range(15):
		var a := PI + float(i) / 14.0 * PI
		inner_pts.append(pos + Vector2(cos(a) * rx * 0.78, 3.0 + sin(a) * ry * 0.75))
	draw_colored_polygon(inner_pts, Color(rim_col.r, rim_col.g, rim_col.b, 0.55))

	# Kubbe üzerindeki biyolüminesan benekler ve parlama
	draw_circle(pos + Vector2(-14.0 * sx, -8.0 * sy), 4.5, Color(1.0, 1.0, 1.0, 0.65))
	draw_circle(pos + Vector2(0.0, -14.0 * sy), 5.5, Color(1.0, 1.0, 1.0, 0.65))
	draw_circle(pos + Vector2(14.0 * sx, -8.0 * sy), 4.5, Color(1.0, 1.0, 1.0, 0.65))

	var outline := dome_pts.duplicate()
	outline.append(dome_pts[0])
	draw_polyline(outline, rim_col.lightened(0.25), 2.2)

func _draw_single_pufferfish(p: Dictionary):
	var pos: Vector2 = p["pos"] if not Engine.is_editor_hint() else p["base_pos"]
	var inf: float = float(p["inflate"])
	var pulse: float = float(p["hit_pulse"])
	var dir: float = float(p["facing"])

	var cur_r := lerpf(PUFFER_MIN_R, PUFFER_MAX_R, clampf(inf, 0.0, 1.0)) * (1.0 + pulse * 0.14)

	# 1. Arka kuyruk yüzgeci
	var tail_swing := sin(_time * 7.5 + float(p["phase"])) * 4.0
	var tail_pts := PackedVector2Array([
		pos + Vector2(-dir * (cur_r * 0.85), 0.0),
		pos + Vector2(-dir * (cur_r + 14.0), -11.0 + tail_swing),
		pos + Vector2(-dir * (cur_r + 11.0), tail_swing * 0.5),
		pos + Vector2(-dir * (cur_r + 14.0), 11.0 + tail_swing),
	])
	draw_colored_polygon(tail_pts, Color("#E07A16"))
	draw_polyline(PackedVector2Array([tail_pts[0], tail_pts[1], tail_pts[2], tail_pts[3], tail_pts[0]]), Color("#5C2D04"), 1.6)

	# 2. Çevredeki dikenler (Şiştikçe dışarı uzar)
	var spine_len := lerpf(3.5, 14.5, clampf(inf, 0.0, 1.0))
	var spine_count := 14
	for i in range(spine_count):
		var a := TAU * float(i) / float(spine_count) + sin(_time * 1.5) * 0.05
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		var base_w := lerpf(2.2, 4.8, clampf(inf, 0.0, 1.0))
		var s_poly := PackedVector2Array([
			pos + d * (cur_r - 2.0) - n * base_w,
			pos + d * (cur_r + spine_len),
			pos + d * (cur_r - 2.0) + n * base_w,
		])
		draw_colored_polygon(s_poly, Color("#FFF3C4"))
		draw_polyline(PackedVector2Array([s_poly[0], s_poly[1], s_poly[2]]), Color("#6E3B08"), 1.5)

	# 3. Ana gövde (Üst altın-turuncu, alt açık krem karın)
	draw_circle(pos, cur_r, Color("#F59B23"))

	# Alt açık krem karın bölgesi
	var belly_pts := PackedVector2Array()
	for i in range(17):
		var a := 0.15 + float(i) / 16.0 * (PI - 0.3)
		belly_pts.append(pos + Vector2(cos(a) * cur_r * 0.92, sin(a) * cur_r * 0.92))
	draw_colored_polygon(belly_pts, Color("#FFF0B8"))

	# Sırt benekleri ve gövde içi küçük diken izleri
	for b_off in [Vector2(-0.35, -0.45), Vector2(0.05, -0.58), Vector2(0.42, -0.38)]:
		draw_circle(pos + b_off * cur_r, cur_r * 0.14, Color("#C9640C", 0.65))

	# Gövde dış konturu
	draw_arc(pos, cur_r, 0.0, TAU, 32, Color("#5C2D04"), 2.2)

	# 4. Yan yüzgeç (çırpınan küçük kanatçık)
	var fin_flap := sin(_time * 9.0 + float(p["phase"])) * 3.5
	var fin_pts := PackedVector2Array([
		pos + Vector2(-dir * cur_r * 0.1, cur_r * 0.1),
		pos + Vector2(-dir * cur_r * 0.45, cur_r * 0.02 + fin_flap),
		pos + Vector2(-dir * cur_r * 0.42, cur_r * 0.32 + fin_flap),
	])
	draw_colored_polygon(fin_pts, Color("#FFBA49"))
	draw_polyline(PackedVector2Array([fin_pts[0], fin_pts[1], fin_pts[2], fin_pts[0]]), Color("#6E3B08"), 1.4)

	# 5. Göz ve şişkin yanaklı ağız
	var eye_pos := pos + Vector2(dir * cur_r * 0.42, -cur_r * 0.22)
	var eye_r := lerpf(5.0, 8.5, clampf(inf, 0.0, 1.0))
	draw_circle(eye_pos, eye_r, Color.WHITE)
	draw_arc(eye_pos, eye_r, 0.0, TAU, 16, Color("#3B1E04"), 1.6)
	draw_circle(eye_pos + Vector2(dir * 1.5, 0.0), eye_r * 0.48, Color("#1A1A1A"))
	draw_circle(eye_pos + Vector2(dir * 0.5, -eye_r * 0.25), eye_r * 0.2, Color.WHITE)

	# Şiştiğinde tombul pembe yanak ve "O" şeklinde ağız
	var mouth_pos := pos + Vector2(dir * cur_r * 0.68, cur_r * 0.12)
	if inf > 0.35:
		draw_circle(pos + Vector2(dir * cur_r * 0.46, cur_r * 0.18), cur_r * 0.16, Color(1.0, 0.45, 0.4, 0.55))
		draw_circle(mouth_pos, 3.8, Color("#7A2E1D"))
	else:
		draw_arc(mouth_pos, 3.5, 0.2, PI - 0.2, 8, Color("#5C2D04"), 1.8)

func _draw_ball_shock_effect(bpos: Vector2):
	# Çarpılan topun etrafında elektrik halkaları ve yıldırımlar
	draw_circle(bpos, 26.0, Color(0.25, 0.95, 1.0, 0.35))
	for i in range(6):
		var a1 := TAU * float(i) / 6.0 + _time * 18.0
		var a2 := a1 + 0.55
		var p1 := bpos + Vector2(cos(a1), sin(a1)) * 12.0
		var p2 := bpos + Vector2(cos((a1 + a2) * 0.5), sin((a1 + a2) * 0.5)) * 27.0
		var p3 := bpos + Vector2(cos(a2), sin(a2)) * 15.0
		var arc := PackedVector2Array([p1, p2, p3])
		draw_polyline(arc, Color(0.2, 0.95, 1.0, 0.9), 3.2)
		draw_polyline(arc, Color(1.0, 0.98, 0.5, 1.0), 1.6)
