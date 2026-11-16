@tool
extends Node2D
## Bölüm 10 (Siber Neon Şehri) mekanikleri:
## 1) Sol yukarıda kablodan sarkan MOR neon "E" harfi ve sağ yukarıda kablodan sarkan MAVİ neon "M" harfi.
## 2) Tam ortada zeminde yan yana dip dibe 4 adet siber lazer: sırayla senkronik şekilde açılıp en yukarıya kadar ilerler,
##    top değerse oyunu bitirir.

const GameProgress := preload("res://scripts/game_progress.gd")
const SoundManager := preload("res://scripts/sound_manager.gd")

## Toplam salınım açısı (derece). 60 derece = sağa 30°, sola 30° tarama açısı.
@export var total_swing_Angle_deg: float = 60.0

var ball: RigidBody2D = null
var main_node: Node2D = null

var _time: float = 0.0
var _sparks: Array = []

var _signs: Array = [
	{
		"letter": "E",
		"anchor": Vector2(421.0, -6.0),
		"cable_len": 165.0,
		"box_half": Vector2(30.0, 38.0),
		"speed": 1.85,
		"phase": 0.0,
		"angle": 0.0,
		"ang_vel": 0.0,
		"flash": 0.0,
		"cooldown": 0.0,
		"glow_col": Color(0.68, 0.14, 1.0, 0.28),
		"tube_col": Color("#9D28FF"),
		"mid_col": Color("#D97AFF"),
		"core_col": Color("#FBF0FF"),
		"frame_col": Color("#160B2B"),
	},
	{
		"letter": "M",
		"anchor": Vector2(875.0, -6.0),
		"cable_len": 165.0,
		"box_half": Vector2(34.0, 38.0),
		"speed": 1.85,
		"phase": 2.1,
		"angle": 0.0,
		"ang_vel": 0.0,
		"flash": 0.0,
		"cooldown": 0.0,
		"glow_col": Color(0.06, 0.62, 1.0, 0.28),
		"tube_col": Color("#1288FF"),
		"mid_col": Color("#66E0FF"),
		"core_col": Color("#F0FCFF"),
		"frame_col": Color("#0A172E"),
	},
]

# --- 2. Ortadaki 4 Yan Yana Siber Lazer ---
const LASER_GROUND_Y: float = 610.0
const LASER_EMIT_Y: float = 595.0
const LASER_TOP_Y: float = -10.0
const LASER_CYCLE: float = 3.2
const LASER_STEP_DELAY: float = 0.42
const LASER_CHARGE_DUR: float = 0.25
const LASER_EXTEND_DUR: float = 0.20
const LASER_HOLD_DUR: float = 0.55
const LASER_RETRACT_DUR: float = 0.14

var _lasers: Array = [
	{"x": 604.0, "col": Color("#FF1424"), "mid": Color("#FF6670"), "state": 0, "top_y": 595.0, "bot_y": 595.0, "charge": 0.0},
	{"x": 628.0, "col": Color("#FF1424"), "mid": Color("#FF6670"), "state": 0, "top_y": 595.0, "bot_y": 595.0, "charge": 0.0},
	{"x": 652.0, "col": Color("#FF1424"), "mid": Color("#FF6670"), "state": 0, "top_y": 595.0, "bot_y": 595.0, "charge": 0.0},
	{"x": 676.0, "col": Color("#FF1424"), "mid": Color("#FF6670"), "state": 0, "top_y": 595.0, "bot_y": 595.0, "charge": 0.0},
]

var _laser_hitting_ball: bool = false
var _laser_hit_timer: float = 0.0
var _laser_hit_origin: Vector2 = Vector2.ZERO
var _laser_hit_col: Color = Color("#FF1424")

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
	_update_sparks(delta)

	if _laser_hitting_ball:
		_laser_hit_timer += delta
		if is_instance_valid(ball):
			var jitter := Vector2(sin(_time * 95.0) * 4.0, cos(_time * 88.0) * 4.0)
			ball.global_position = _laser_hit_origin + jitter
		queue_redraw()
		if _laser_hit_timer >= 0.52:
			_laser_hitting_ball = false
			if is_instance_valid(ball):
				ball.hide()
			if is_instance_valid(main_node) and main_node.has_method("end_game"):
				main_node.end_game(GameProgress.t("hit_by_laser"))
		return

	if is_instance_valid(main_node) and main_node.get("game_over") == true:
		queue_redraw()
		return

	var shot_active := false
	if is_instance_valid(ball) and not ball.freeze and is_instance_valid(main_node) and int(main_node.get("shot_count")) > 0:
		shot_active = true

	var max_rad := deg_to_rad(total_swing_Angle_deg * 0.5)
	for s in _signs:
		var spd: float = float(s["speed"])
		var ph: float = float(s["phase"])
		var ang := sin(_time * spd + ph) * max_rad
		var ang_vel := cos(_time * spd + ph) * spd * max_rad
		s["angle"] = ang
		s["ang_vel"] = ang_vel
		s["flash"] = move_toward(float(s["flash"]), 0.0, delta * 3.2)
		s["cooldown"] = maxf(0.0, float(s["cooldown"]) - delta)

		if shot_active and float(s["cooldown"]) <= 0.0:
			_check_sign_collision(s)

	_process_lasers(shot_active)
	queue_redraw()

func _process_lasers(shot_active: bool):
	var cyc := fmod(_time, LASER_CYCLE)
	var ball_r := 15.0

	for i in range(_lasers.size()):
		var l: Dictionary = _lasers[i]
		var start_t := float(i) * LASER_STEP_DELAY
		var lt := cyc - start_t
		if lt < -LASER_CHARGE_DUR:
			lt += LASER_CYCLE

		var active_end := LASER_EXTEND_DUR + LASER_HOLD_DUR
		var total_end := active_end + LASER_RETRACT_DUR

		if lt >= -LASER_CHARGE_DUR and lt < 0.0:
			# 1) Şarj / uyarı aşaması
			l["state"] = 1
			l["charge"] = (lt + LASER_CHARGE_DUR) / LASER_CHARGE_DUR
			l["top_y"] = LASER_EMIT_Y
			l["bot_y"] = LASER_EMIT_Y
		elif lt >= 0.0 and lt < LASER_EXTEND_DUR:
			# 2) Zeminden en yukarıya kadar hızla ilerleme
			l["state"] = 2
			l["charge"] = 1.0
			var p := clampf(lt / LASER_EXTEND_DUR, 0.0, 1.0)
			l["top_y"] = lerpf(LASER_EMIT_Y, LASER_TOP_Y, p)
			l["bot_y"] = LASER_EMIT_Y
		elif lt >= LASER_EXTEND_DUR and lt < active_end:
			# 3) Tam boy açık kalma (en yukarıya kadar)
			l["state"] = 2
			l["charge"] = 1.0
			l["top_y"] = LASER_TOP_Y
			l["bot_y"] = LASER_EMIT_Y
		elif lt >= active_end and lt < total_end:
			# 4) Yukarı doğru sönerek kapanma
			l["state"] = 3
			var p := clampf((lt - active_end) / LASER_RETRACT_DUR, 0.0, 1.0)
			l["charge"] = 1.0 - p
			l["top_y"] = LASER_TOP_Y
			l["bot_y"] = lerpf(LASER_EMIT_Y, LASER_TOP_Y, p)
		else:
			# 0) Kapalı / beklemede
			l["state"] = 0
			l["charge"] = 0.0
			l["top_y"] = LASER_EMIT_Y
			l["bot_y"] = LASER_EMIT_Y

		# Top aktif lazere değdi mi kontrol et
		if shot_active and (int(l["state"]) == 2 or int(l["state"]) == 3):
			var lx: float = float(l["x"])
			var top_y: float = float(l["top_y"])
			var bot_y: float = float(l["bot_y"])
			var bpos := ball.global_position
			if absf(bpos.x - lx) <= (5.5 + ball_r * 0.82) and bpos.y >= top_y - ball_r and bpos.y <= bot_y + ball_r:
				_trigger_laser_hit(l["col"])
				return

func _trigger_laser_hit(lcol: Color):
	if _laser_hitting_ball or not is_instance_valid(ball):
		return
	_laser_hitting_ball = true
	_laser_hit_timer = 0.0
	_laser_hit_origin = ball.global_position
	_laser_hit_col = lcol

	if is_instance_valid(main_node):
		main_node.set("is_dragging", false)
		main_node.queue_redraw()

	ball.call_deferred("set_linear_velocity", Vector2.ZERO)
	ball.call_deferred("set_angular_velocity", 0.0)
	ball.call_deferred("set_freeze_enabled", true)
	ball.modulate = Color(2.5, 0.35, 0.35, 1.0)
	_spawn_hit_sparks(_laser_hit_origin, lcol)
	_spawn_hit_sparks(_laser_hit_origin, Color.WHITE)

func _check_sign_collision(s: Dictionary):
	var anchor: Vector2 = s["anchor"]
	var cable_len: float = float(s["cable_len"])
	var ang: float = float(s["angle"])
	var box_half: Vector2 = s["box_half"]
	var ball_r := 15.0

	var down_dir := Vector2(sin(ang), cos(ang))
	var right_dir := Vector2(cos(ang), -sin(ang))
	var sign_center := anchor + down_dir * (cable_len + box_half.y)

	# 1) Harf tabelası (döndürülmüş dikdörtgen kutu) çarpışma kontrolü
	var rel := ball.global_position - sign_center
	var local_pt := Vector2(rel.dot(right_dir), rel.dot(down_dir))
	var clamped := Vector2(
		clampf(local_pt.x, -box_half.x, box_half.x),
		clampf(local_pt.y, -box_half.y, box_half.y)
	)
	var diff_local := local_pt - clamped
	var dist_sq := diff_local.length_squared()

	if dist_sq < ball_r * ball_r:
		s["cooldown"] = 0.14
		s["flash"] = 1.0

		var n_local: Vector2
		if dist_sq > 0.0001:
			n_local = diff_local.normalized()
		else:
			var dx := box_half.x - absf(local_pt.x)
			var dy := box_half.y - absf(local_pt.y)
			if dx < dy:
				n_local = Vector2(signf(local_pt.x) if local_pt.x != 0.0 else 1.0, 0.0)
			else:
				n_local = Vector2(0.0, signf(local_pt.y) if local_pt.y != 0.0 else 1.0)

		var world_n := (right_dir * n_local.x + down_dir * n_local.y).normalized()
		var closest_world := sign_center + right_dir * clamped.x + down_dir * clamped.y
		ball.global_position = closest_world + world_n * (ball_r + 2.5)

		# Tabelanın salınım hızını da hesaba katarak topu neon enerjisiyle sektir
		var sign_vel := right_dir * (float(s["ang_vel"]) * (cable_len + box_half.y))
		var rel_vel := ball.linear_velocity - sign_vel
		var reflected := rel_vel.bounce(world_n) * 0.92 + sign_vel * 0.55
		if reflected.length() < 260.0:
			reflected = world_n * 260.0
		ball.linear_velocity = reflected
		_spawn_hit_sparks(closest_world, s["mid_col"])
		SoundManager.play_click()
		return

	# 2) Kablo çarpışma kontrolü (anchor .. cable_end)
	var cable_end := anchor + down_dir * cable_len
	var seg := cable_end - anchor
	var seg_len_sq := seg.length_squared()
	if seg_len_sq > 0.0:
		var t := clampf((ball.global_position - anchor).dot(seg) / seg_len_sq, 0.0, 1.0)
		var closest := anchor + seg * t
		var c_diff := ball.global_position - closest
		var c_dist := c_diff.length()
		var min_c_dist := ball_r + 4.5
		if c_dist < min_c_dist and c_dist > 0.001:
			s["cooldown"] = 0.14
			s["flash"] = 0.7
			var cn := c_diff / c_dist
			ball.global_position = closest + cn * (min_c_dist + 2.0)
			ball.linear_velocity = ball.linear_velocity.bounce(cn) * 0.85
			_spawn_hit_sparks(closest, s["mid_col"])
			SoundManager.play_click()

func _spawn_hit_sparks(pos: Vector2, col: Color):
	for i in range(10):
		var a := randf() * TAU
		var spd := randf_range(70.0, 190.0)
		_sparks.append({
			"pos": pos,
			"vel": Vector2(cos(a), sin(a)) * spd,
			"life": 1.0,
			"col": col,
		})

func _update_sparks(delta: float):
	for i in range(_sparks.size() - 1, -1, -1):
		var sp: Dictionary = _sparks[i]
		sp["pos"] = (sp["pos"] as Vector2) + (sp["vel"] as Vector2) * delta
		sp["life"] = float(sp["life"]) - delta * 2.8
		if float(sp["life"]) <= 0.0:
			_sparks.remove_at(i)

func _draw():
	_draw_ground_lasers()
	for s in _signs:
		_draw_neon_sign(s)

	# Çarpışma kıvılcımları
	for sp in _sparks:
		var life: float = clampf(float(sp["life"]), 0.0, 1.0)
		var scol: Color = sp["col"]
		var p: Vector2 = sp["pos"]
		draw_circle(p, 3.2 * life, Color(scol.r, scol.g, scol.b, life))
		draw_circle(p, 1.5 * life, Color(1.0, 1.0, 1.0, life))

	if _laser_hitting_ball and is_instance_valid(ball):
		var bpos := ball.global_position
		draw_circle(bpos, 26.0, Color(_laser_hit_col.r, _laser_hit_col.g, _laser_hit_col.b, 0.38))
		draw_arc(bpos, 20.0 + sin(_time * 40.0) * 4.0, 0.0, TAU, 24, Color.WHITE, 2.5)

func _draw_ground_lasers():
	# 1. 4 lazeri birleştiren ortak zemin platformu (tam ortada dip dibe)
	var base_left := 590.0
	var base_w := 100.0
	draw_rect(Rect2(base_left, LASER_GROUND_Y - 6.0, base_w, 10.0), Color("#0A0F24"))
	draw_rect(Rect2(base_left, LASER_GROUND_Y - 6.0, base_w, 10.0), Color("#23366E"), false, 1.6)

	for i in range(_lasers.size()):
		var l: Dictionary = _lasers[i]
		var lx: float = float(l["x"])
		var col: Color = l["col"]
		var mid: Color = l["mid"]
		var st: int = int(l["state"])
		var chg: float = float(l["charge"])
		var top_y: float = float(l["top_y"])
		var bot_y: float = float(l["bot_y"])

		# A) Şarj olurken ince kesikli uyarı izi
		if st == 1:
			draw_line(
				Vector2(lx, LASER_EMIT_Y),
				Vector2(lx, LASER_TOP_Y),
				Color(col.r, col.g, col.b, 0.18 * chg),
				2.0
			)

		# B) Aktif lazer ışını (zeminden en yukarıya kadar ilerleyen çok katmanlı neon lazer)
		if (st == 2 or st == 3) and bot_y > top_y:
			var p_bot := Vector2(lx, bot_y)
			var p_top := Vector2(lx, top_y)
			var pulse := 0.9 + 0.1 * sin(_time * 45.0 + i)

			# Dış neon lazer parıltısı
			draw_line(p_bot, p_top, Color(col.r, col.g, col.b, 0.30 * pulse), 20.0)
			# Ana lazer gövdesi
			draw_line(p_bot, p_top, Color(col.r, col.g, col.b, 0.88), 10.0)
			# Parlak ara katman
			draw_line(p_bot, p_top, mid, 5.2)
			# Beyaz sıcak çekirdek
			draw_line(p_bot, p_top, Color.WHITE, 2.2)

			# Lazerin ilerleyen en üst ucundaki enerji parlaması
			draw_circle(p_top, 11.0 * pulse, Color(col.r, col.g, col.b, 0.45))
			draw_circle(p_top, 5.5, mid)
			draw_circle(p_top, 2.8, Color.WHITE)

		# C) Zemin üzerindeki dip dibe siber lazer namlusu (emitter)
		var em_w := 22.0
		var em_h := 15.0
		var em_rect := Rect2(lx - em_w * 0.5, LASER_GROUND_Y - em_h, em_w, em_h)
		draw_rect(em_rect, Color("#111A3A"))
		draw_rect(Rect2(lx - em_w * 0.35, LASER_GROUND_Y - em_h - 3.0, em_w * 0.7, 4.0), Color("#1D2C5E"))
		draw_rect(em_rect, col if st >= 1 else Color("#2B4078"), false, 1.8)

		# Lazer merceği (lens)
		var lens_pos := Vector2(lx, LASER_EMIT_Y)
		var lens_alpha := 0.35 if st == 0 else (0.55 + 0.45 * chg)
		draw_circle(lens_pos, 6.5, Color(col.r, col.g, col.b, lens_alpha * 0.45))
		draw_circle(lens_pos, 4.0, Color(col.r, col.g, col.b, lens_alpha))
		if st >= 1:
			draw_circle(lens_pos, 2.0, Color.WHITE)

func _draw_neon_sign(s: Dictionary):
	var anchor: Vector2 = s["anchor"]
	var cable_len: float = float(s["cable_len"])
	var ang: float = float(s["angle"]) if not Engine.is_editor_hint() else 0.0
	var box_half: Vector2 = s["box_half"]
	var flash: float = float(s["flash"])

	var down_dir := Vector2(sin(ang), cos(ang))
	var cable_end := anchor + down_dir * cable_len
	var sign_center := anchor + down_dir * (cable_len + box_half.y)

	var glow_col: Color = s["glow_col"]
	var tube_col: Color = s["tube_col"]
	var mid_col: Color = s["mid_col"]
	var core_col: Color = s["core_col"]
	var frame_col: Color = s["frame_col"]

	# 1. Tavan bağlantı soketi ve sarkan siber kablo
	draw_circle(anchor, 6.0, Color("#0E152E"))
	draw_circle(anchor, 3.0, mid_col)

	# Ana taşıyıcı siyah kablo ve içinden akan neon enerji darbesi
	draw_line(anchor, cable_end, Color("#080C1C"), 5.5)
	draw_line(anchor, cable_end, Color("#1E2C54"), 2.4)

	var pulse_t := fmod(_time * 1.1 + float(s["phase"]) * 0.3, 1.0)
	var p1 := anchor.lerp(cable_end, clampf(pulse_t - 0.08, 0.0, 1.0))
	var p2 := anchor.lerp(cable_end, clampf(pulse_t + 0.08, 0.0, 1.0))
	draw_line(p1, p2, mid_col, 3.2)

	# Kablo ucundan tabela köşelerine ayrılan ikili askı telleri
	draw_set_transform(sign_center, -ang, Vector2.ONE)
	var top_mount := Vector2(0.0, -box_half.y)
	draw_line(top_mount, Vector2(-box_half.x * 0.62, -box_half.y + 8.0), Color("#182342"), 3.0)
	draw_line(top_mount, Vector2(box_half.x * 0.62, -box_half.y + 8.0), Color("#182342"), 3.0)
	draw_circle(top_mount, 4.5, Color("#243460"))

	# 2. Neon tabela arka metal çerçevesi ve dış ışık halesi (glow)
	var flicker := 0.92 + 0.08 * sin(_time * 16.0 + float(s["phase"]) * 3.0)
	var boost := 1.0 + flash * 0.55

	# Geniş neon ortam parıltısı
	draw_circle(Vector2.ZERO, maxf(box_half.x, box_half.y) * 1.45, Color(glow_col.r, glow_col.g, glow_col.b, glow_col.a * flicker * boost))

	# Koyu siber tabela kasası (kafes çerçeve)
	var frame_rect := Rect2(-box_half + Vector2(0.0, 4.0), box_half * 2.0 - Vector2(0.0, 4.0))
	draw_rect(frame_rect, Color(frame_col.r, frame_col.g, frame_col.b, 0.82))
	draw_rect(frame_rect, Color(tube_col.r, tube_col.g, tube_col.b, 0.45), false, 2.2)

	# 3. Neon Harf Tüpleri ("E" veya "M")
	var letter: String = s["letter"]
	var segments: Array = []
	if letter == "E":
		var lx := -16.0
		var rx := 16.0
		var ty := -22.0
		var my := 2.0
		var by := 26.0
		segments = [
			[Vector2(lx, ty), Vector2(lx, by)],       # Sol dikey gövde
			[Vector2(lx, ty), Vector2(rx, ty)],       # Üst yatay çubuk
			[Vector2(lx, my), Vector2(rx - 4.0, my)], # Orta yatay çubuk
			[Vector2(lx, by), Vector2(rx, by)],       # Alt yatay çubuk
		]
	else:
		# "M" harfi
		var lx := -20.0
		var rx := 20.0
		var ty := -22.0
		var by := 26.0
		var vy := 10.0
		segments = [
			[Vector2(lx, by), Vector2(lx, ty)],   # Sol dikey bacak
			[Vector2(lx, ty), Vector2(0.0, vy)],  # Sol üstten ortaya iniş
			[Vector2(0.0, vy), Vector2(rx, ty)],  # Ortadan sağ üste çıkış
			[Vector2(rx, ty), Vector2(rx, by)],   # Sağ dikey bacak
		]

	# Katman 1: Dış neon yayılımı
	for seg in segments:
		var a_pt: Vector2 = seg[0]
		var b_pt: Vector2 = seg[1]
		draw_line(a_pt, b_pt, Color(tube_col.r, tube_col.g, tube_col.b, 0.38 * flicker), 16.0 * boost)
		draw_circle(a_pt, 8.0 * boost, Color(tube_col.r, tube_col.g, tube_col.b, 0.32 * flicker))
		draw_circle(b_pt, 8.0 * boost, Color(tube_col.r, tube_col.g, tube_col.b, 0.32 * flicker))

	# Katman 2: Ana renkli neon tüp (Mor / Mavi)
	for seg in segments:
		var a_pt: Vector2 = seg[0]
		var b_pt: Vector2 = seg[1]
		draw_line(a_pt, b_pt, tube_col, 9.5)
		draw_circle(a_pt, 4.75, tube_col)
		draw_circle(b_pt, 4.75, tube_col)

	# Katman 3: İç parlak neon katmanı
	for seg in segments:
		var a_pt: Vector2 = seg[0]
		var b_pt: Vector2 = seg[1]
		draw_line(a_pt, b_pt, mid_col, 5.2)
		draw_circle(a_pt, 2.6, mid_col)
		draw_circle(b_pt, 2.6, mid_col)

	# Katman 4: Merkez beyaz-neon çekirdek (filament)
	for seg in segments:
		var a_pt: Vector2 = seg[0]
		var b_pt: Vector2 = seg[1]
		draw_line(a_pt, b_pt, core_col, 2.2)
		draw_circle(a_pt, 1.1, core_col)
		draw_circle(b_pt, 1.1, core_col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
