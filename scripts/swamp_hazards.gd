@tool
extends Node2D
## Bölüm 8 (Gece Bataklığı) engelleri ve atmosferi:
## 1) Bataklık Kurbağası (2-3 saniyede bir dilini yukarı uzatıp değen topu bataklığa çeker)
## 2) Sarkan Bataklık Sarmaşıkları (sarkaç gibi sallanır, çarpan topun hızını kesip bataklığa düşürür)
## 3) Yoğun Gece Sisi ve Ateşböcekleri (orta/sağ alanı sisle kapatır; top ve ateşböcekleri çevresini aydınlatır)

var ball: RigidBody2D = null
var main_node: Node2D = null

var _time: float = 0.0

# --- 1. Bataklık Kurbağaları ve Dilleri ---
# 0: beklemede, 1: ağzını açıp hazırlanıyor (0.32sn), 2: dil uzuyor/yukarıda (0.46sn), 3: dil geri çekiliyor (0.16sn)
var _tongue_max_len: float = 330.0
var _frogs: Array = [
	{
		"pos": Vector2(485.0, 598.0),
		"state": 0,
		"timer": 1.0,
		"tongue_ext": 0.0,
		"caught_ball": false,
		"pull_time": 0.0,
	},
	{
		"pos": Vector2(815.0, 598.0),
		"state": 0,
		"timer": 2.4,
		"tongue_ext": 0.0,
		"caught_ball": false,
		"pull_time": 0.0,
	},
]

# --- 2. Sarkan Bataklık Sarmaşıkları ---
var _vines: Array = [
	{"anchor": Vector2(445.0, -5.0), "length": 255.0, "max_angle": 0.42, "speed": 1.85, "phase": 0.2, "cooldown": 0.0, "angle": 0.0},
	{"anchor": Vector2(885.0, -5.0), "length": 275.0, "max_angle": 0.44, "speed": 1.65, "phase": 2.4, "cooldown": 0.0, "angle": 0.0},
]

# --- 3. Yoğun Bataklık Sisi ve Ateşböcekleri ---
var _fog_puffs: Array = []
var _fireflies: Array = []

func _ready():
	z_index = 2
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_init_fog_and_fireflies()
	if Engine.is_editor_hint():
		queue_redraw()
		return

	if not main_node:
		main_node = get_parent() as Node2D
	if main_node and not ball:
		ball = main_node.get_node_or_null("Ball") as RigidBody2D

func _init_fog_and_fireflies():
	_fog_puffs.clear()
	# Orta ve sağ bölgeyi (x = 300 .. 1260, y = 90 .. 570) kaplayan yoğun sis katmanları
	var cols := 13
	var rows := 6
	for r in range(rows):
		for c in range(cols):
			var bx := 310.0 + c * 76.0 + fmod(r * 37.0, 38.0)
			var by := 105.0 + r * 86.0 + sin(c * 2.1 + r) * 18.0
			var rad := 78.0 + fmod((c * 7 + r * 13) * 5.0, 28.0)
			_fog_puffs.append({
				"base_x": bx,
				"base_y": by,
				"r": rad,
				"speed": 14.0 + fmod(r * 5.3 + c * 3.1, 12.0),
				"phase": c * 0.9 + r * 1.4,
				"alpha": 0.78 + fmod(c * 2.7 + r, 0.14),
			})

	_fireflies.clear()
	for i in range(6):
		_fireflies.append({
			"center": Vector2(410.0 + i * 155.0, 230.0 + fmod(i * 110.0, 240.0)),
			"rx": 95.0 + (i % 3) * 30.0,
			"ry": 65.0 + (i % 2) * 35.0,
			"speed": 0.75 + (i % 4) * 0.18,
			"phase": i * 1.35,
			"pos": Vector2(410.0 + i * 155.0, 260.0),
		})

func _physics_process(delta: float):
	if Engine.is_editor_hint():
		return

	_time += delta
	_update_fireflies()

	if is_instance_valid(main_node) and main_node.get("game_over") == true:
		queue_redraw()
		return

	_process_vines(delta)
	_process_frogs(delta)
	queue_redraw()

func _update_fireflies():
	for f in _fireflies:
		var ph: float = float(f["phase"]) + _time * float(f["speed"])
		var cx: float = f["center"].x + sin(ph) * float(f["rx"])
		var cy: float = f["center"].y + cos(ph * 1.3) * float(f["ry"])
		f["pos"] = Vector2(cx, cy)

func _process_vines(delta: float):
	var shot_active := false
	if is_instance_valid(ball) and not ball.freeze and is_instance_valid(main_node) and int(main_node.get("shot_count")) > 0:
		shot_active = true

	for v in _vines:
		var cd := float(v["cooldown"])
		if cd > 0.0:
			v["cooldown"] = maxf(0.0, cd - delta)

		var ang := sin(_time * float(v["speed"]) + float(v["phase"])) * float(v["max_angle"])
		v["angle"] = ang

		if shot_active and float(v["cooldown"]) <= 0.0 and ball.linear_velocity.length() > 12.0:
			var anchor: Vector2 = v["anchor"]
			var length: float = v["length"]
			var tip := anchor + Vector2(sin(ang), cos(ang)) * length
			var closest := Geometry2D.get_closest_point_to_segment(ball.global_position, anchor, tip)
			if closest.distance_to(ball.global_position) <= 22.0:
				v["cooldown"] = 0.45
				# Sarmaşığa çarpan topun yatay hızı kesilir ve aşağı bataklığa doğru düşer
				var push_x := -signf(ball.linear_velocity.x) * minf(absf(ball.linear_velocity.x) * 0.22, 65.0)
				ball.linear_velocity = Vector2(push_x, maxf(190.0, absf(ball.linear_velocity.y) * 0.45))
				ball.angular_velocity *= 0.25

func _is_any_other_frog_active(exclude_index: int) -> bool:
	for j in range(_frogs.size()):
		if j != exclude_index and int(_frogs[j]["state"]) != 0:
			return true
	return false

func _process_frogs(delta: float):
	for i in range(_frogs.size()):
		var frog: Dictionary = _frogs[i]
		var fpos: Vector2 = frog["pos"]

		if bool(frog["caught_ball"]):
			var pt := float(frog["pull_time"]) + delta
			frog["pull_time"] = pt
			var ext := move_toward(float(frog["tongue_ext"]), 0.0, delta / 0.22)
			frog["tongue_ext"] = ext
			if is_instance_valid(ball) and not ball.freeze:
				var target_pull := fpos + Vector2(-38.0, -4.0)
				var pull_dir := (target_pull - ball.global_position)
				ball.linear_velocity = pull_dir * 7.5 + Vector2(0.0, 260.0)
			if pt >= 0.24 or ext <= 0.05:
				frog["caught_ball"] = false
				frog["state"] = 0
				frog["timer"] = randf_range(2.2, 3.0)
				# Diğer kurbağanın hemen aynı anda dil atmaması için kısa bir bekleme farkı bırak
				for j in range(_frogs.size()):
					if j != i and int(_frogs[j]["state"]) == 0:
						_frogs[j]["timer"] = maxf(float(_frogs[j]["timer"]), 0.65)
			continue

		var st := int(frog["state"])
		if st == 0:
			var tm := float(frog["timer"]) - delta
			frog["timer"] = tm
			if tm <= 0.0:
				# Başka bir kurbağa şu an dil atıyorsa veya hazırlanıyorsa sırasını bekle
				if _is_any_other_frog_active(i):
					frog["timer"] = randf_range(0.55, 0.85)
				else:
					frog["state"] = 1
					frog["timer"] = 0.32
					frog["tongue_ext"] = 0.0

		elif st == 1:
			# Dil fırlamadan hemen önce 0.32sn boğaz şişirme / ağız açma uyarısı
			var tm := float(frog["timer"]) - delta
			frog["timer"] = tm
			if tm <= 0.0:
				frog["state"] = 2
				frog["timer"] = 0.46

		elif st == 2:
			# Dil hızla yukarı uzar ve 0.46sn boyunca yukarıda kalır
			frog["tongue_ext"] = move_toward(float(frog["tongue_ext"]), 1.0, delta / 0.09)
			var tm := float(frog["timer"]) - delta
			frog["timer"] = tm
			_check_frog_tongue_hit_ball(frog)
			if tm <= 0.0 and not bool(frog["caught_ball"]):
				frog["state"] = 3

		elif st == 3:
			# Dil geri çekilir
			var ext := move_toward(float(frog["tongue_ext"]), 0.0, delta / 0.16)
			frog["tongue_ext"] = ext
			_check_frog_tongue_hit_ball(frog)
			if ext <= 0.0:
				frog["state"] = 0
				frog["timer"] = randf_range(2.2, 3.0)
				for j in range(_frogs.size()):
					if j != i and int(_frogs[j]["state"]) == 0:
						_frogs[j]["timer"] = maxf(float(_frogs[j]["timer"]), 0.65)

func _check_frog_tongue_hit_ball(frog: Dictionary):
	var ext := float(frog["tongue_ext"])
	if bool(frog["caught_ball"]) or ext <= 0.15 or not is_instance_valid(ball) or ball.freeze:
		return
	if is_instance_valid(main_node) and int(main_node.get("shot_count")) == 0:
		return
	# Top zaten bataklığın içindeyse tekrar çekme
	if ball.global_position.y >= 590.0:
		return

	var fpos: Vector2 = frog["pos"]
	var mouth_pos := fpos + Vector2(0.0, -14.0)
	var tip_pos := mouth_pos + Vector2(0.0, -_tongue_max_len * ext)
	var closest := Geometry2D.get_closest_point_to_segment(ball.global_position, mouth_pos, tip_pos)
	if closest.distance_to(ball.global_position) <= 23.0:
		frog["caught_ball"] = true
		frog["pull_time"] = 0.0
		# Dili topun yüksekliğine kilitleyip hızla aşağı bataklığa çek
		frog["tongue_ext"] = clampf((mouth_pos.y - ball.global_position.y) / _tongue_max_len, 0.15, 1.0)
		ball.linear_velocity = Vector2((fpos.x - 36.0 - ball.global_position.x) * 3.0, 460.0)

func _draw():
	_draw_vines()
	for frog in _frogs:
		_draw_single_frog(frog)
	_draw_fog_and_fireflies()

func _draw_vines():
	for v in _vines:
		var anchor: Vector2 = v["anchor"]
		var length: float = v["length"]
		var ang: float = v["angle"]

		var pts := PackedVector2Array()
		var segs := 8
		for i in range(segs + 1):
			var t := float(i) / float(segs)
			# Sarkaç açısı + sarmaşık boyunca hafif doğal kıvrım
			var local_ang := ang * (0.85 + 0.3 * t) + sin(_time * 2.5 + i * 0.7) * 0.03 * t
			var pt := anchor + Vector2(sin(local_ang), cos(local_ang)) * (length * t)
			pts.append(pt)

		# Ana sarmaşık gövdesi ve aydınlık yosun sırtı
		draw_polyline(pts, Color("#142919"), 10.0)
		draw_polyline(pts, Color("#294F2D"), 6.0)
		draw_polyline(pts, Color("#467A44"), 2.4)

		# Sarmaşık üzerindeki yapraklar ve sarkan yosun telleri
		for i in range(1, segs):
			var p := pts[i]
			var side := -1.0 if i % 2 == 0 else 1.0
			var leaf_dir := Vector2(side * 12.0, 5.0).rotated(ang)
			draw_line(p, p + leaf_dir, Color("#3B6E3B"), 3.2)
			draw_circle(p + leaf_dir, 3.5, Color("#52944B"))
			if i % 2 == 1:
				draw_line(p, p + Vector2(0.0, 18.0), Color("#365934", 0.75), 1.8)

func _draw_single_frog(frog: Dictionary):
	var fp: Vector2 = frog["pos"]
	var st := int(frog["state"])
	var ext := float(frog["tongue_ext"])
	var caught := bool(frog["caught_ball"])

	# Kurbağanın altındaki büyük nilüfer yaprağı
	draw_circle(fp + Vector2(0.0, 6.0), 22.0, Color("#1E381B"))
	draw_circle(fp + Vector2(0.0, 4.5), 19.5, Color("#2F5729"))
	draw_line(fp + Vector2(0.0, 4.5), fp + Vector2(18.0, 6.0), Color("#1E381B"), 2.2)

	# Uzayan pembe kurbağa dili (kurbağa ağzının arkasından yukarı doğru çıkar)
	var mouth_pos := fp + Vector2(0.0, -14.0)
	if ext > 0.01:
		var tip_pos := mouth_pos + Vector2(0.0, -_tongue_max_len * ext)
		if caught and is_instance_valid(ball):
			tip_pos = ball.global_position
		draw_line(mouth_pos, tip_pos, Color("#9E2A48"), 8.0)
		draw_line(mouth_pos, tip_pos, Color("#FF6B8B"), 4.6)
		draw_circle(tip_pos, 7.0, Color("#FF4F79"))
		draw_circle(tip_pos + Vector2(-2.0, -2.0), 2.5, Color("#FFB3C6"))

	# Kurbağa arka bacakları
	draw_circle(fp + Vector2(-14.0, -3.0), 8.0, Color("#244721"))
	draw_circle(fp + Vector2(14.0, -3.0), 8.0, Color("#244721"))

	# Kurbağa gövdesi
	draw_circle(fp + Vector2(0.0, -8.0), 15.0, Color("#2E5C29"))
	draw_circle(fp + Vector2(0.0, -9.0), 12.5, Color("#438038"))

	# Saldırı öncesi şişen sarı-yeşil boğaz kesesi
	var throat_r := 8.5 if st != 1 else (11.5 + sin(_time * 35.0) * 1.8)
	var throat_col := Color("#A3C959") if st != 1 else Color("#D8F268")
	draw_circle(fp + Vector2(0.0, -6.0), throat_r, throat_col)

	# Kurbağa ağzı (dil çıkarken veya hazırlanırken açık)
	if st == 1 or ext > 0.02:
		draw_circle(mouth_pos, 5.5, Color("#4A1022"))
	else:
		draw_line(fp + Vector2(-9.0, -12.0), fp + Vector2(9.0, -12.0), Color("#183316"), 2.0)

	# Kurbağa gözleri (yukarı bakan parlak sarı gözler)
	for sx in [-8.0, 8.0]:
		var eye_pos := fp + Vector2(sx, -20.0)
		draw_circle(eye_pos, 6.0, Color("#2E5C29"))
		draw_circle(eye_pos, 4.4, Color("#FFE854"))
		draw_circle(eye_pos + Vector2(0.0, -1.2), 2.0, Color("#10140D"))

func _draw_fog_and_fireflies():
	var ball_pos := ball.global_position if is_instance_valid(ball) else Vector2(150.0, 450.0)

	# 1. Yoğun Bataklık Sisi (topun ve ateşböceklerinin yakınında aralanır/aydınlanır)
	for p in _fog_puffs:
		var px := float(p["base_x"]) + sin(_time * 0.45 + float(p["phase"])) * 24.0
		var py := float(p["base_y"]) + cos(_time * 0.35 + float(p["phase"])) * 10.0
		var fpos := Vector2(px, py)
		var rad := float(p["r"])
		var alpha := float(p["alpha"])

		# Topa yakınlık: topun çevresini (145px yarıçap) netleştir
		var dist_ball := fpos.distance_to(ball_pos)
		if dist_ball < 155.0:
			alpha *= clampf((dist_ball - 48.0) / 107.0, 0.08, 1.0)

		# Ateşböceklerine yakınlık: her ateşböceği kendi etrafındaki sisi (115px) dağıtır
		for f in _fireflies:
			var f_dist := fpos.distance_to(f["pos"])
			if f_dist < 118.0:
				alpha *= clampf((f_dist - 32.0) / 86.0, 0.12, 1.0)

		if alpha > 0.03:
			draw_circle(fpos, rad, Color(0.07, 0.11, 0.14, alpha * 0.62))
			draw_circle(fpos + Vector2(14.0, -6.0), rad * 0.72, Color(0.11, 0.17, 0.20, alpha * 0.48))

	# 2. Sisi aydınlatan parlayan Ateşböcekleri
	for i in range(_fireflies.size()):
		var fpos: Vector2 = _fireflies[i]["pos"]
		var pulse := 0.75 + 0.25 * sin(_time * 5.0 + i * 1.7)
		draw_circle(fpos, 22.0 * pulse, Color(0.75, 1.0, 0.28, 0.14 * pulse))
		draw_circle(fpos, 9.0 * pulse, Color(0.85, 1.0, 0.35, 0.32 * pulse))
		draw_circle(fpos, 3.2, Color("#FAFF9E"))
