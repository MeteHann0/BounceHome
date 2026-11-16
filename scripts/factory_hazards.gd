@tool
extends Node2D
## Bölüm 11 (Paslı Fabrika / Rusty Factory) engelleri:
## 1) Hidrolik preslerin solunda ve sağında hem kendi etrafında dönen hem de Y ekseninde yukarı-aşağı hareket eden 2 dev paslı dişli çark
## 2) Ortada yan yana dizili, senkronize şekilde sırayla kapanıp yere vuran 3 adet hidrolik ezici pres
## 3) En sağdaki hidrolik presin sağında, zeminde topu sola doğru hızlandıran konveyör bant (yürüyen fabrika bandı)
## 4) Sol tarafta zeminde basınçla yukarı doğru sıcak buhar püskürten endüstriyel buhar vanası

const GameProgress := preload("res://scripts/game_progress.gd")
const SoundManager := preload("res://scripts/sound_manager.gd")

var _time: float = 0.0
var _ball: RigidBody2D = null
var _main_node: Node2D = null
var _ball_crushed: bool = false
var _crush_flash: float = 0.0
var _crush_pos: Vector2 = Vector2.ZERO
var _sparks: Array = []

# 1. Sol ve sağ yanda dönen ve Y ekseninde yukarı-aşağı hareket eden paslı dişli çarklar
var _gears: Array = [
	{
		"x": 365.0,
		"base_y": 355.0,
		"y": 355.0,
		"vy": 0.0,
		"move_amp": 135.0,
		"move_speed": 1.65,
		"phase": 0.0,
		"angle": 0.0,
		"rot_speed": 2.45,
		"outer_r": 52.0,
		"body_r": 41.0,
		"inner_r": 25.0,
		"teeth": 12,
		"hit_flash": 0.0,
		"cooldown": 0.0,
	},
	{
		"x": 915.0,
		"base_y": 355.0,
		"y": 355.0,
		"vy": 0.0,
		"move_amp": 135.0,
		"move_speed": 1.65,
		"phase": PI,
		"angle": 0.0,
		"rot_speed": -2.45,
		"outer_r": 52.0,
		"body_r": 41.0,
		"inner_r": 25.0,
		"teeth": 12,
		"hit_flash": 0.0,
		"cooldown": 0.0,
	},
]

# 2. Ortada yan yana 3 adet senkronize hidrolik ezici pres
# state: 0 = açık (yukarıda), 1 = uyarı (titreme), 2 = hızla kapanıyor, 3 = kapalı (yerde), 4 = yukarı çekiliyor
var _presses: Array = [
	{
		"x": 564.0,
		"width": 68.0,
		"head_h": 64.0,
		"open_bottom_y": 112.0,
		"ground_y": 610.0,
		"bottom_y": 112.0,
		"step_index": 0,
		"state": 0,
		"shake_x": 0.0,
		"slammed_fx": false,
		"cooldown": 0.0,
	},
	{
		"x": 640.0,
		"width": 68.0,
		"head_h": 64.0,
		"open_bottom_y": 112.0,
		"ground_y": 610.0,
		"bottom_y": 112.0,
		"step_index": 1,
		"state": 0,
		"shake_x": 0.0,
		"slammed_fx": false,
		"cooldown": 0.0,
	},
	{
		"x": 716.0,
		"width": 68.0,
		"head_h": 64.0,
		"open_bottom_y": 112.0,
		"ground_y": 610.0,
		"bottom_y": 112.0,
		"step_index": 2,
		"state": 0,
		"shake_x": 0.0,
		"slammed_fx": false,
		"cooldown": 0.0,
	},
]

# 3. En sağdaki hidrolik presin sağında, yerde sola doğru hızlandıran konveyör bant
var _conveyor: Dictionary = {
	"left_x": 762.0,
	"right_x": 1038.0,
	"ground_y": 610.0,
	"height": 16.0,
	"dir": -1.0, # -1.0 = Sola doğru hızlandırır
	"belt_speed": 240.0,
	"boost_force": 720.0,
	"scroll": 0.0,
	"spark_cd": 0.0,
}

# 4. Sol tarafta basınçlı buhar vanası (topu yukarı doğru savurur)
var _steam_vents: Array = [
	{
		"x": 468.0,
		"y": 610.0,
		"phase": 0.0,
		"cycle": 3.2,
		"active_dur": 1.35,
		"warn_dur": 0.45,
		"jet_h": 225.0,
		"state": 0,
		"intensity": 0.0,
	},
]

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if Engine.is_editor_hint():
		_update_mechanisms(0.0)
		queue_redraw()
		return

	_main_node = get_parent() as Node2D
	if _main_node:
		_ball = _main_node.get_node_or_null("Ball") as RigidBody2D
	_update_mechanisms(0.0)

func _physics_process(delta: float):
	if Engine.is_editor_hint():
		return

	_time += delta
	_crush_flash = maxf(0.0, _crush_flash - delta * 2.5)
	_update_mechanisms(delta)
	_update_sparks(delta)

	if not _ball_crushed and is_instance_valid(_main_node) and _main_node.get("game_over") != true:
		if is_instance_valid(_ball) and not _ball.freeze:
			_check_gear_collisions()
			_check_press_collisions()
			_apply_conveyor_belt(delta)
			_apply_steam_forces()

	queue_redraw()

func _update_mechanisms(delta: float):
	# 1. Sol ve sağ dişli çarkların dönüşü ve Y ekseninde yukarı-aşağı hareketi
	for i in range(_gears.size()):
		var g: Dictionary = _gears[i]
		var base_y: float = g["base_y"]
		var move_amp: float = g["move_amp"]
		var move_speed: float = g["move_speed"]
		var phase: float = g["phase"]
		var rot_speed: float = g["rot_speed"]

		g["y"] = base_y + sin(_time * move_speed + phase) * move_amp
		g["vy"] = cos(_time * move_speed + phase) * move_speed * move_amp
		g["angle"] = float(g["angle"]) + rot_speed * delta
		g["hit_flash"] = maxf(0.0, float(g["hit_flash"]) - delta * 3.2)
		g["cooldown"] = maxf(0.0, float(g["cooldown"]) - delta)
		_gears[i] = g

	# 2. 3 Hidrolik presin senkronize sıralı hareketi
	var cycle_period := 3.0
	var step_delay := 0.52
	var warn_dur := 0.35
	var slam_dur := 0.18
	var hold_dur := 0.45
	var retract_dur := 0.64

	for i in range(_presses.size()):
		var p: Dictionary = _presses[i]
		p["cooldown"] = maxf(0.0, float(p["cooldown"]) - delta)
		var step_idx: int = p["step_index"]
		var open_y: float = p["open_bottom_y"]
		var ground_y: float = p["ground_y"]
		var local_t := fposmod(_time - float(step_idx) * step_delay, cycle_period)

		if local_t < warn_dur:
			# Uyarı: yukarıda titrer ve sarı-kırmızı uyarı ışığı yanar
			p["state"] = 1
			p["bottom_y"] = open_y + sin(_time * 55.0 + float(i)) * 2.5
			p["shake_x"] = sin(_time * 68.0 + float(i) * 1.7) * 2.8
			p["slammed_fx"] = false
		elif local_t < warn_dur + slam_dur:
			# Hızla aşağı inip yere vurma (Slam)
			p["state"] = 2
			var prog := (local_t - warn_dur) / slam_dur
			var eased := prog * prog
			p["bottom_y"] = lerpf(open_y, ground_y, eased)
			p["shake_x"] = 0.0
		elif local_t < warn_dur + slam_dur + hold_dur:
			# Yerde kapalı kalma
			p["state"] = 3
			p["bottom_y"] = ground_y
			p["shake_x"] = 0.0
			if not bool(p["slammed_fx"]) and not Engine.is_editor_hint():
				p["slammed_fx"] = true
				_spawn_sparks(Vector2(float(p["x"]), ground_y - 3.0), Color("#FF9E2C"), 10)
		elif local_t < warn_dur + slam_dur + hold_dur + retract_dur:
			# Yukarı geri çekilme
			p["state"] = 4
			var prog := (local_t - (warn_dur + slam_dur + hold_dur)) / retract_dur
			var smooth := prog * prog * (3.0 - 2.0 * prog)
			p["bottom_y"] = lerpf(ground_y, open_y, smooth)
			p["shake_x"] = 0.0
			p["slammed_fx"] = false
		else:
			# Açık bekleme
			p["state"] = 0
			p["bottom_y"] = open_y
			p["shake_x"] = 0.0
			p["slammed_fx"] = false

		_presses[i] = p

	# 3. Konveyör bant animasyon ilerlemesi
	_conveyor["scroll"] = fposmod(float(_conveyor["scroll"]) + delta * 85.0, 28.0)
	_conveyor["spark_cd"] = maxf(0.0, float(_conveyor["spark_cd"]) - delta)

	# 4. Basınçlı buhar vanalarının döngüsü
	for i in range(_steam_vents.size()):
		var sv: Dictionary = _steam_vents[i]
		var cycle: float = sv["cycle"]
		var phase: float = sv["phase"]
		var warn_d: float = sv["warn_dur"]
		var act_d: float = sv["active_dur"]
		var lt := fposmod(_time + phase, cycle)

		if lt < warn_d:
			sv["state"] = 1
			sv["intensity"] = (lt / warn_d) * 0.35
		elif lt < warn_d + act_d:
			sv["state"] = 2
			var active_t := lt - warn_d
			var fade_in := clampf(active_t / 0.12, 0.0, 1.0)
			var fade_out := clampf((act_d - active_t) / 0.20, 0.0, 1.0)
			sv["intensity"] = minf(fade_in, fade_out)
		else:
			sv["state"] = 0
			sv["intensity"] = 0.0

		_steam_vents[i] = sv

func _check_gear_collisions():
	var ball_r := 15.0
	for i in range(_gears.size()):
		var g: Dictionary = _gears[i]
		if float(g["cooldown"]) > 0.0:
			continue

		var gear_pos := Vector2(float(g["x"]), float(g["y"]))
		var outer_r: float = g["outer_r"]
		var diff := _ball.global_position - gear_pos
		var dist := diff.length()
		var min_dist := outer_r + ball_r

		if dist < min_dist and dist > 0.001:
			var normal := diff / dist
			var tangent := Vector2(-normal.y, normal.x)
			_ball.global_position = gear_pos + normal * (min_dist + 2.0)

			var vel := _ball.linear_velocity
			var speed := maxf(vel.length(), 280.0)
			var reflected := vel.bounce(normal).normalized() * speed * 0.94

			# Çarkın dönüş yönünden teğetsel hız + dikey hareketinden hız katkısı ekle
			var rot_speed: float = g["rot_speed"]
			var gear_vy: float = g["vy"]
			var spin_boost := tangent * (rot_speed * outer_r * 0.85) + Vector2(0.0, gear_vy * 0.35)
			var final_vel := reflected + spin_boost
			if final_vel.length() < 300.0:
				final_vel = final_vel.normalized() * 300.0

			_ball.linear_velocity = final_vel
			_ball.angular_velocity = rot_speed * 5.0
			g["cooldown"] = 0.08
			g["hit_flash"] = 1.0
			_gears[i] = g
			SoundManager.play_click()
			_spawn_sparks(gear_pos + normal * outer_r, Color("#FFB84D"), 14)

func _check_press_collisions():
	var ball_pos := _ball.global_position
	var ball_r := 15.0

	for i in range(_presses.size()):
		var p: Dictionary = _presses[i]
		var px: float = float(p["x"]) + float(p["shake_x"])
		var half_w: float = float(p["width"]) * 0.5
		var head_h: float = p["head_h"]
		var bottom_y: float = p["bottom_y"]
		var ground_y: float = p["ground_y"]
		var top_y: float = bottom_y - head_h
		var state: int = p["state"]

		# 1) Ezilme kontrolü: SADECE pres hızla aşağı inerken (state == 2) top pres başlığının
		# tam altında kalırsa ezilir ve oyun biter. Pres yukarıdayken, yukarı çekilirken veya
		# yerdeyken çarpan top ezilmez, sekerek uzaklaşır.
		if state == 2 and bottom_y < ground_y - 2.0 and absf(ball_pos.x - px) < half_w - 6.0:
			if ball_pos.y >= bottom_y - 18.0 and ball_pos.y <= bottom_y + ball_r + 2.0:
				_trigger_press_crush(ball_pos)
				return

		# 2) Pres başlığından sekme kontrolü (yukarıdayken alt yüzeyden veya her durumda yan yüzeylerden)
		var head_closest_x := clampf(ball_pos.x, px - half_w, px + half_w)
		var head_closest_y := clampf(ball_pos.y, top_y, bottom_y)
		var head_diff := ball_pos - Vector2(head_closest_x, head_closest_y)
		var head_dist := head_diff.length()

		if head_dist < ball_r:
			if float(p["cooldown"]) <= 0.0:
				var hit_bottom := bottom_y < ground_y - 2.0 and ball_pos.y >= bottom_y - 4.0 and absf(ball_pos.x - px) < half_w - 4.0
				if hit_bottom:
					_ball.global_position.y = bottom_y + ball_r + 2.0
					var speed := maxf(_ball.linear_velocity.length(), 220.0)
					var bounced := _ball.linear_velocity.bounce(Vector2(0.0, 1.0))
					if bounced.y < 120.0:
						bounced.y = 160.0
					_ball.linear_velocity = bounced.normalized() * speed * 0.88
				else:
					var normal := Vector2(1.0 if ball_pos.x >= px else -1.0, 0.0)
					if head_dist > 0.001 and absf(head_diff.x) > 0.5:
						normal = head_diff.normalized()
					var push_x := (px + half_w + ball_r + 2.0) if ball_pos.x >= px else (px - half_w - ball_r - 2.0)
					_ball.global_position.x = push_x
					var speed := maxf(_ball.linear_velocity.length(), 240.0)
					var bounced := _ball.linear_velocity.bounce(normal)
					if absf(bounced.x) < 140.0:
						bounced.x = (1.0 if ball_pos.x >= px else -1.0) * 180.0
					_ball.linear_velocity = bounced.normalized() * speed * 0.90
				p["cooldown"] = 0.08
				_presses[i] = p
				SoundManager.play_click()
				_spawn_sparks(Vector2(head_closest_x, head_closest_y), Color("#FF9E2C"), 10)
			continue

		# B) Üstteki hidrolik piston mili / kovanı (px - 16 .. px + 16, 18 .. top_y)
		var rod_half_w := 16.0
		var rod_closest_x := clampf(ball_pos.x, px - rod_half_w, px + rod_half_w)
		var rod_closest_y := clampf(ball_pos.y, 18.0, top_y)
		var rod_diff := ball_pos - Vector2(rod_closest_x, rod_closest_y)
		var rod_dist := rod_diff.length()

		if rod_dist < ball_r and float(p["cooldown"]) <= 0.0:
			var side_sign := 1.0 if ball_pos.x >= px else -1.0
			_ball.global_position.x = px + side_sign * (rod_half_w + ball_r + 2.0)
			var speed := maxf(_ball.linear_velocity.length(), 230.0)
			var bounced := _ball.linear_velocity.bounce(Vector2(side_sign, 0.0))
			if absf(bounced.x) < 140.0:
				bounced.x = side_sign * 170.0
			_ball.linear_velocity = bounced.normalized() * speed * 0.88
			p["cooldown"] = 0.08
			_presses[i] = p
			SoundManager.play_click()
			_spawn_sparks(Vector2(rod_closest_x, rod_closest_y), Color("#FF9E2C"), 8)

func _apply_conveyor_belt(delta: float):
	var left_x: float = _conveyor["left_x"]
	var right_x: float = _conveyor["right_x"]
	var ground_y: float = _conveyor["ground_y"]
	var belt_h: float = _conveyor["height"]
	var belt_top := ground_y - belt_h
	var belt_dir: float = _conveyor["dir"]
	var target_vx: float = belt_dir * float(_conveyor["belt_speed"])
	var boost_force: float = _conveyor["boost_force"]

	var ball_pos := _ball.global_position
	var ball_r := 15.0

	# Top konveyör bandın üst yüzeyine değdiğinde sola doğru güçlü ivme uygula
	if ball_pos.x >= left_x - 6.0 and ball_pos.x <= right_x + 6.0 and ball_pos.y >= belt_top - ball_r - 5.0:
		# Topu bandın üst yüzeyinde tut ve sola doğru hızla fırlat
		if ball_pos.y > belt_top - ball_r + 2.0:
			_ball.global_position.y = belt_top - ball_r + 1.0
			if _ball.linear_velocity.y > 0.0:
				_ball.linear_velocity.y = -_ball.linear_velocity.y * 0.35

		_ball.linear_velocity.x = move_toward(_ball.linear_velocity.x, target_vx, boost_force * delta)
		if _ball.linear_velocity.x > -135.0:
			_ball.linear_velocity.x = -135.0
		_ball.angular_velocity = -8.0

		if float(_conveyor["spark_cd"]) <= 0.0:
			_conveyor["spark_cd"] = 0.09
			_spawn_sparks(Vector2(ball_pos.x, belt_top), Color("#FFB838"), 4)

func _apply_steam_forces():
	var ball_pos := _ball.global_position
	for i in range(_steam_vents.size()):
		var sv: Dictionary = _steam_vents[i]
		if int(sv["state"]) != 2:
			continue
		var vx: float = sv["x"]
		var vy: float = sv["y"]
		var jet_h: float = sv["jet_h"]
		var intensity: float = sv["intensity"]

		if absf(ball_pos.x - vx) <= 32.0 and ball_pos.y <= vy and ball_pos.y >= vy - jet_h:
			var height_factor := clampf(1.0 - ((vy - ball_pos.y) / jet_h) * 0.45, 0.4, 1.0)
			_ball.apply_central_force(Vector2(35.0, -780.0 * intensity * height_factor))

func _trigger_press_crush(hit_pos: Vector2):
	if _ball_crushed:
		return
	_ball_crushed = true
	_crush_flash = 1.0
	_crush_pos = hit_pos
	_spawn_sparks(hit_pos, Color("#FF6B1A"), 24)

	if is_instance_valid(_main_node):
		_main_node.set("is_dragging", false)
		_main_node.queue_redraw()

	_ball.call_deferred("set_linear_velocity", Vector2.ZERO)
	_ball.call_deferred("set_angular_velocity", 0.0)
	_ball.call_deferred("set_freeze_enabled", true)

	var sprite := _ball.get_node_or_null("Sprite2D") as Node2D
	var tween := create_tween()
	tween.tween_property(_ball, "modulate", Color(1.6, 0.55, 0.2, 1.0), 0.08)
	tween.tween_property(_ball, "modulate", Color(0.25, 0.18, 0.14, 0.0), 0.30)
	if sprite:
		tween.parallel().tween_property(sprite, "scale", sprite.scale * Vector2(1.55, 0.18), 0.26)

	tween.tween_callback(func():
		if is_instance_valid(_ball):
			_ball.hide()
		if is_instance_valid(_main_node) and _main_node.has_method("end_game"):
			_main_node.end_game(GameProgress.t("crushed_by_press"))
	)

func _spawn_sparks(origin: Vector2, col: Color, count: int = 12):
	for i in range(count):
		var ang := randf_range(0.0, TAU)
		var spd := randf_range(75.0, 220.0)
		_sparks.append({
			"pos": origin,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"col": col,
			"life": 1.0,
		})

func _update_sparks(delta: float):
	for i in range(_sparks.size() - 1, -1, -1):
		var sp: Dictionary = _sparks[i]
		sp["life"] = float(sp["life"]) - delta * 2.5
		if float(sp["life"]) <= 0.0:
			_sparks.remove_at(i)
		else:
			var vel: Vector2 = sp["vel"]
			vel.y += 280.0 * delta
			sp["vel"] = vel
			sp["pos"] = (sp["pos"] as Vector2) + vel * delta
			_sparks[i] = sp

func _draw():
	for i in range(_gears.size()):
		_draw_single_gear(_gears[i])
	_draw_hydraulic_presses()
	_draw_conveyor_belt()
	_draw_steam_vents()

	# Kıvılcım parçacıkları
	for i in range(_sparks.size()):
		var sp: Dictionary = _sparks[i]
		var life: float = sp["life"]
		var col: Color = sp["col"]
		var pos: Vector2 = sp["pos"]
		var vel: Vector2 = sp["vel"]
		draw_line(pos, pos - vel * 0.035, Color(col.r, col.g, col.b, life), 2.4)
		draw_circle(pos, 2.2 * life, Color(1.0, 0.95, 0.75, life))

	if _crush_flash > 0.0:
		draw_circle(_crush_pos, 34.0 * _crush_flash, Color(1.0, 0.45, 0.1, 0.45 * _crush_flash))
		draw_circle(_crush_pos, 16.0 * _crush_flash, Color(1.0, 0.9, 0.6, 0.8 * _crush_flash))

func _draw_single_gear(g: Dictionary):
	var gx: float = g["x"]
	var gy: float = g["y"]
	var base_y: float = g["base_y"]
	var move_amp: float = g["move_amp"]
	var rail_top := base_y - move_amp - 28.0
	var rail_bot := base_y + move_amp + 28.0
	var rail_h := rail_bot - rail_top

	# 1. Dikey çelik kızak rayı (dişli çarkın yukarı-aşağı hareket ettiği kanal)
	draw_rect(Rect2(gx - 12.0, rail_top, 24.0, rail_h), Color("#1A1512"))
	draw_rect(Rect2(gx - 6.0, rail_top + 6.0, 12.0, rail_h - 12.0), Color("#0E0B09"))
	draw_rect(Rect2(gx - 12.0, rail_top, 24.0, rail_h), Color("#4A3A2E"), false, 2.0)

	# Ray üzerindeki yatay travers ve perçinler
	var steps := 10
	for i in range(steps + 1):
		var ry := rail_top + 10.0 + float(i) * ((rail_h - 20.0) / float(steps))
		draw_circle(Vector2(gx - 9.0, ry), 1.8, Color("#7A614D"))
		draw_circle(Vector2(gx + 9.0, ry), 1.8, Color("#7A614D"))

	# Ray üst ve alt durdurucu tampon blokları
	for end_y: float in [rail_top, rail_bot - 10.0]:
		draw_rect(Rect2(gx - 18.0, end_y, 36.0, 10.0), Color("#3B2E25"))
		draw_rect(Rect2(gx - 18.0, end_y, 36.0, 10.0), Color("#85664D"), false, 1.5)

	# 2. Dönen Paslı Dişli Çark
	var center := Vector2(gx, gy)
	var angle: float = g["angle"]
	var outer_r: float = g["outer_r"]
	var body_r: float = g["body_r"]
	var inner_r: float = g["inner_r"]
	var teeth: int = g["teeth"]
	var hit_flash: float = g["hit_flash"]

	if hit_flash > 0.0:
		draw_circle(center, outer_r + 10.0, Color(1.0, 0.65, 0.2, 0.30 * hit_flash))

	# Dişler (12 adet trapez diş)
	for t in range(teeth):
		var a := angle + float(t) * (TAU / float(teeth))
		var half_base := 0.14
		var half_tip := 0.09
		var tooth_poly := PackedVector2Array([
			center + Vector2(cos(a - half_base), sin(a - half_base)) * (body_r - 2.0),
			center + Vector2(cos(a - half_tip), sin(a - half_tip)) * outer_r,
			center + Vector2(cos(a + half_tip), sin(a + half_tip)) * outer_r,
			center + Vector2(cos(a + half_base), sin(a + half_base)) * (body_r - 2.0),
		])
		var tooth_col := Color("#4A382B") if t % 2 == 0 else Color("#5C4332")
		draw_colored_polygon(tooth_poly, tooth_col)
		var tooth_outline := tooth_poly.duplicate()
		tooth_outline.append(tooth_poly[0])
		draw_polyline(tooth_outline, Color("#1F1712"), 1.6)

	# Ana döküm demir gövde çemberi
	draw_circle(center, body_r, Color("#3B2D23"))
	draw_arc(center, body_r - 3.0, 0.0, TAU, 36, Color("#7A3E1D", 0.75), 4.0)
	draw_arc(center, body_r, 0.0, TAU, 36, Color("#1C1410"), 2.2)

	# İç boşluk ve 4 adet çapraz çark kolu (spokes)
	draw_circle(center, inner_r, Color("#16120F"))
	for s in range(4):
		var sa := angle + float(s) * (PI * 0.5)
		var dir := Vector2(cos(sa), sin(sa))
		draw_line(center - dir * inner_r, center + dir * inner_r, Color("#4A382B"), 9.0)
		draw_line(center - dir * inner_r, center + dir * inner_r, Color("#785A42"), 3.0)

	# İç çember bileziği ve perçinler
	draw_arc(center, inner_r, 0.0, TAU, 28, Color("#6E523C"), 3.0)
	for b in range(8):
		var ba := angle + float(b) * (TAU / 8.0)
		var bp := center + Vector2(cos(ba), sin(ba)) * ((body_r + inner_r) * 0.5)
		draw_circle(bp, 2.5, Color("#1F1813"))
		draw_circle(bp + Vector2(-0.5, -0.5), 1.4, Color("#9E7B5B"))

	# Merkez pirinç/bakır yatak göbeği
	draw_circle(center, 11.5, Color("#241B15"))
	draw_circle(center, 8.5, Color("#B87333"))
	draw_circle(center, 4.0, Color("#F0B265"))

func _draw_conveyor_belt():
	var left_x: float = _conveyor["left_x"]
	var right_x: float = _conveyor["right_x"]
	var ground_y: float = _conveyor["ground_y"]
	var belt_h: float = _conveyor["height"]
	var top_y := ground_y - belt_h
	var mid_y := top_y + belt_h * 0.5
	var w := right_x - left_x
	var scroll: float = _conveyor["scroll"]
	var r := belt_h * 0.5

	# 1. Konveyör çelik gövde kasası ve yan makaralar
	draw_rect(Rect2(left_x + r, top_y, w - belt_h, belt_h), Color("#1F1B18"))
	draw_circle(Vector2(left_x + r, mid_y), r, Color("#26201B"))
	draw_circle(Vector2(right_x - r, mid_y), r, Color("#26201B"))

	# İç kauçuk/çelik bant şeridi
	draw_rect(Rect2(left_x + r, top_y + 3.0, w - belt_h, belt_h - 6.0), Color("#14110F"))

	# 2. Üst yüzeyde sola doğru akan parlak sarı-turuncu yön şeritleri (<<<)
	var step := 28.0
	var start_x := left_x + r + 8.0
	var end_x := right_x - r - 8.0
	var x_cursor := start_x + (step - scroll)
	while x_cursor < end_x:
		var arrow := PackedVector2Array([
			Vector2(x_cursor + 5.0, top_y + 2.5),
			Vector2(x_cursor - 2.0, mid_y),
			Vector2(x_cursor + 5.0, ground_y - 2.5),
		])
		draw_polyline(arrow, Color("#F5A623"), 2.4)
		x_cursor += step

	# 3. Dönen makara tekerlekleri (sol, orta, sağ)
	var roller_xs := [left_x + r, left_x + w * 0.35, left_x + w * 0.65, right_x - r]
	var roller_ang := -_time * 5.0
	for rx_val in roller_xs:
		var rx: float = rx_val
		draw_circle(Vector2(rx, mid_y), r - 2.5, Color("#4A3C31"))
		draw_arc(Vector2(rx, mid_y), r - 2.5, 0.0, TAU, 16, Color("#171310"), 1.5)
		var spoke := Vector2(cos(roller_ang), sin(roller_ang)) * (r - 3.5)
		draw_line(Vector2(rx, mid_y) - spoke, Vector2(rx, mid_y) + spoke, Color("#8C735B"), 1.6)
		draw_circle(Vector2(rx, mid_y), 2.0, Color("#D49B2A"))

	# Üst ve alt bant çerçeve konturu
	draw_line(Vector2(left_x + r, top_y), Vector2(right_x - r, top_y), Color("#7D634C"), 2.0)
	draw_line(Vector2(left_x + r, ground_y), Vector2(right_x - r, ground_y), Color("#120E0C"), 2.0)

func _draw_hydraulic_presses():
	# Üst tavan çelik taşıyıcı köprü kirişi (3 presi birleştiren ana gövde)
	var gantry_left := 512.0
	var gantry_w := 256.0
	draw_rect(Rect2(gantry_left, 0.0, gantry_w, 26.0), Color("#241D18"))
	draw_rect(Rect2(gantry_left, 20.0, gantry_w, 6.0), Color("#3D3128"))
	draw_rect(Rect2(gantry_left, 0.0, gantry_w, 26.0), Color("#5E4B3C"), false, 2.0)

	for i in range(_presses.size()):
		var p: Dictionary = _presses[i]
		var px: float = float(p["x"]) + float(p["shake_x"])
		var base_px: float = p["x"]
		var w: float = p["width"]
		var half_w := w * 0.5
		var head_h: float = p["head_h"]
		var bottom_y: float = p["bottom_y"]
		var top_y := bottom_y - head_h
		var state: int = p["state"]

		# 1. Hidrolik silindir kovanı ve parlak çelik piston mili (y = 24 .. top_y)
		var cyl_h := maxf(14.0, (top_y - 24.0) * 0.42)
		var rod_top := 24.0 + cyl_h
		var rod_h := maxf(0.0, top_y - rod_top)

		# Dış ağır hidrolik kovan
		draw_rect(Rect2(base_px - 18.0, 24.0, 36.0, cyl_h), Color("#2E251F"))
		draw_rect(Rect2(base_px - 12.0, 24.0, 10.0, cyl_h), Color("#4A3B31"))
		draw_rect(Rect2(base_px - 18.0, 24.0, 36.0, cyl_h), Color("#17120F"), false, 2.0)
		draw_rect(Rect2(base_px - 21.0, rod_top - 6.0, 42.0, 6.0), Color("#5C4738"))

		# İç krom/çelik piston mili
		if rod_h > 0.0:
			draw_rect(Rect2(px - 11.0, rod_top, 22.0, rod_h), Color("#59524C"))
			draw_rect(Rect2(px - 6.0, rod_top, 7.0, rod_h), Color("#9E948B"))
			draw_rect(Rect2(px + 4.0, rod_top, 5.0, rod_h), Color("#332E2A"))
			draw_rect(Rect2(px - 11.0, rod_top, 22.0, rod_h), Color("#1C1815"), false, 1.6)

		# 2. Üst bağlantıdaki durum lambası (Açık: Yeşil, Uyarı: Turuncu/Sarı, Kapanıyor/Kapalı: Kırmızı)
		var lamp_col := Color("#38D962")
		if state == 1:
			var blink := 0.55 + 0.45 * sin(_time * 28.0)
			lamp_col = Color(1.0, 0.65, 0.1, blink)
		elif state == 2 or state == 3:
			lamp_col = Color("#FF2424")
		elif state == 4:
			lamp_col = Color("#E69B28")
		draw_circle(Vector2(base_px, 13.0), 7.5, Color(lamp_col.r, lamp_col.g, lamp_col.b, 0.32))
		draw_circle(Vector2(base_px, 13.0), 4.2, lamp_col)

		# 3. Ezici Pres Başlığı (top_y .. bottom_y)
		var head_rect := Rect2(px - half_w, top_y, w, head_h - 8.0)
		draw_rect(head_rect, Color("#332922"))
		draw_rect(Rect2(px - half_w + 4.0, top_y + 4.0, w - 8.0, 14.0), Color("#4A3B30"))

		# Gövde üzerindeki pas lekesi
		draw_rect(Rect2(px - half_w + 8.0, top_y + 20.0, w - 16.0, 14.0), Color("#783B1C", 0.72))

		# Alt kısımda sarı-siyah endüstriyel tehlike şeridi kuşağı
		var band_y := bottom_y - 22.0
		draw_rect(Rect2(px - half_w + 2.0, band_y, w - 4.0, 12.0), Color("#1A1612"))
		for s in range(4):
			var sx := px - half_w + 6.0 + float(s) * 15.0
			var stripe := PackedVector2Array([
				Vector2(sx, band_y),
				Vector2(sx + 8.0, band_y),
				Vector2(sx + 4.0, band_y + 12.0),
				Vector2(sx - 4.0, band_y + 12.0),
			])
			draw_colored_polygon(stripe, Color("#D99B26"))

		# Başlık köşelerindeki perçin çivileri
		for rx_off: float in [-half_w + 7.0, half_w - 7.0]:
			for ry_off: float in [top_y + 8.0, top_y + 28.0]:
				draw_circle(Vector2(px + rx_off, ry_off), 2.2, Color("#171310"))
				draw_circle(Vector2(px + rx_off - 0.5, ry_off - 0.5), 1.3, Color("#8F745C"))

		# Dış çelik çerçeve
		draw_rect(head_rect, Color("#17120E"), false, 2.2)

		# 4. En altta tırtıklı çelik ezici dişler (bottom_y - 8 .. bottom_y)
		var tooth_count := 4
		var tooth_w := w / float(tooth_count)
		for t in range(tooth_count):
			var tx := px - half_w + float(t) * tooth_w
			var tooth_poly := PackedVector2Array([
				Vector2(tx + 1.0, bottom_y - 8.0),
				Vector2(tx + tooth_w - 1.0, bottom_y - 8.0),
				Vector2(tx + tooth_w * 0.75, bottom_y),
				Vector2(tx + tooth_w * 0.25, bottom_y),
			])
			draw_colored_polygon(tooth_poly, Color("#5E5248"))
			draw_polyline(tooth_poly, Color("#1C1612"), 1.6)

func _draw_steam_vents():
	for i in range(_steam_vents.size()):
		var sv: Dictionary = _steam_vents[i]
		var vx: float = sv["x"]
		var vy: float = sv["y"]
		var state: int = sv["state"]
		var intensity: float = sv["intensity"]
		var jet_h: float = sv["jet_h"]

		# 1. Buhar püskürme bulutu (state == 1 uyarı sızıntısı, state == 2 tam basınçlı buhar jeti)
		if state == 1 or state == 2:
			var puffs := 8 if state == 2 else 3
			for p in range(puffs):
				var frac := fmod(_time * 3.4 + float(p) / float(puffs), 1.0)
				var py := vy - 14.0 - frac * (jet_h if state == 2 else 45.0)
				var sway := sin(_time * 9.0 + float(p) * 1.7 + float(i)) * (6.0 + frac * 14.0)
				var rad := (10.0 + frac * 20.0) * (0.6 + 0.4 * intensity)
				var alpha := (1.0 - frac * 0.75) * intensity * (0.48 if state == 2 else 0.30)
				draw_circle(Vector2(vx + sway, py), rad, Color(0.86, 0.82, 0.76, alpha))
				draw_circle(Vector2(vx + sway * 0.6, py + 3.0), rad * 0.6, Color(0.96, 0.94, 0.90, alpha * 0.85))

		# 2. Zemine monte paslı pirinç/demir buhar vanası ağzı
		draw_rect(Rect2(vx - 18.0, vy - 8.0, 36.0, 8.0), Color("#382B22"))
		draw_rect(Rect2(vx - 13.0, vy - 14.0, 26.0, 6.0), Color("#5E4430"))
		draw_rect(Rect2(vx - 18.0, vy - 8.0, 36.0, 8.0), Color("#1A130F"), false, 1.6)

		# Küçük yuvarlak basınç manometresi
		var gauge_col := Color("#FF3B24") if state > 0 else Color("#47D16C")
		draw_circle(Vector2(vx, vy - 6.0), 4.5, Color("#1A1410"))
		draw_circle(Vector2(vx, vy - 6.0), 2.8, gauge_col)
