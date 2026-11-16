@tool
extends StaticBody2D

const GameProgress := preload("res://scripts/game_progress.gd")

## Kullanıcı fare ile tutup döndürebilsin mi?
@export var can_drag_rotate: bool = true
## Oyun sırasında kendi etrafında dönüş hızı (radyan/sn). 0 ise dönmez.
@export var auto_rotate_speed: float = 0.0
## İşaretlenirse ahşap yerine gri taş duvar görünümünde çizilir.
@export var is_stone_wall: bool = false:
	set(value):
		is_stone_wall = value
		queue_redraw()
## İşaretlenirse parlak buz engel görünümünde çizilir ve düşük sürtünmeli olur.
@export var is_ice_bar: bool = false:
	set(value):
		is_ice_bar = value
		queue_redraw()
## İşaretlenirse zıplatan mantar trambolin görünümünde çizilir ve topu güçlü sektirir.
@export var is_mushroom: bool = false:
	set(value):
		is_mushroom = value
		queue_redraw()
## Mantar zıplatma katsayısı (1.0 = normal sekme, 1.25 = hızlandırarak trambolin gibi fırlatma)
@export var mushroom_bounce: float = 1.2
## İşaretlenirse volkanik lavlı kaya görünümünde çizilir ve sekme oranı düşürülür.
@export var is_lava_rock: bool = false:
	set(value):
		is_lava_rock = value
		queue_redraw()
## Lavlı kaya sekme oranı (normal reflector ~1.0 iken lavlı kaya varsayılan 0.45)
@export var lava_rock_bounce: float = 0.45
## İşaretlenirse küçük bulut görünümünde çizilir ve rüzgarla sağa/sola hareket eder.
@export var is_cloud_platform: bool = false:
	set(value):
		is_cloud_platform = value
		queue_redraw()
## Bulut engelin başlangıç konumundan sağa/sola gidebileceği maksimum mesafe (piksel)
@export var cloud_move_range: float = 180.0
## Bulut engelin rüzgar eserken sağa/sola kayma hızı (piksel/sn)
@export var cloud_wind_speed: float = 120.0
## İşaretlenirse parlayan çok yüzeyli bir kristal parçası şeklinde çizilir.
@export var is_crystal: bool = false:
	set(value):
		is_crystal = value
		queue_redraw()
## İşaretlenirse Antik Atlantis altın-turkuaz rünlü sütun görünümünde çizilir.
@export var is_atlantis: bool = false:
	set(value):
		is_atlantis = value
		queue_redraw()
## İşaretlenirse Siber Neon Şehri neon bariyer görünümünde çizilir.
@export var is_cyber_neon: bool = false:
	set(value):
		is_cyber_neon = value
		queue_redraw()
## İşaretlenirse Paslı Fabrika perçinli çelik kiriş görünümünde çizilir.
@export var is_rusty_factory: bool = false:
	set(value):
		is_rusty_factory = value
		queue_redraw()
## Yukarı-aşağı hareket mesafesi (piksel). 0 ise dikey hareket etmez.
@export var vertical_move_range: float = 0.0
## Yukarı-aşağı salınım hızı (radyan/sn)
@export var vertical_move_speed: float = 1.65
## Yukarı-aşağı salınım başlangıç fazı (radyan)
@export var vertical_move_phase: float = 0.0
## Dikey harekette çıkabileceği en üst Y sınırı (üstteki E ve M harflerine çarpmaması için)
@export var vertical_min_y: float = 352.0
## Dikey harekette inebileceği en alt Y sınırı (yere çarpmaması için)
@export var vertical_max_y: float = 524.0

var is_rotating := false
var _drag_angle_offset := 0.0
var _last_bounce_msec := 0
var _start_x := 0.0
var _start_y := 0.0
var _move_time := 0.0
var _cloud_drift_vel := 0.0

# Fırtına bulutu şimşek ve kül olma durumu
# 0: beklemede, 1: 0.5sn şarj oluyor, 2: şimşek çakıyor, 3: soğuma (cooldown)
var _lightning_state := 0
var _lightning_timer := 0.0
var _lightning_bolt_global := PackedVector2Array()
var _ball_turning_to_ash := false
var _ash_progress := 0.0
var _ash_origin_global := Vector2.ZERO
var _ash_particles: Array = []

@onready var ball: RigidBody2D = get_parent().get_node_or_null("Ball") if get_parent() else null
@onready var ground: Node = get_parent().get_node_or_null("Ground") if get_parent() else null
@onready var main_node: Node2D = get_parent() as Node2D

func _ready():
	if not is_rusty_factory and not is_cyber_neon and not is_atlantis and not is_crystal and not is_cloud_platform and not is_lava_rock and not is_mushroom and not is_ice_bar and not is_stone_wall:
		if get_parent():
			var sp := String(get_parent().scene_file_path)
			if sp.ends_with("level5.tscn"):
				is_lava_rock = true
			elif sp.ends_with("level6.tscn"):
				is_cloud_platform = true
			elif sp.ends_with("level7.tscn"):
				is_crystal = true
			elif sp.ends_with("level9.tscn"):
				is_atlantis = true
			elif sp.ends_with("level10.tscn"):
				is_cyber_neon = true
			elif sp.ends_with("level11.tscn"):
				is_rusty_factory = true

	if Engine.is_editor_hint():
		queue_redraw()
		return

	_start_x = position.x
	_start_y = position.y
	process_mode = Node.PROCESS_MODE_PAUSABLE
	input_pickable = can_drag_rotate

	if is_mushroom and physics_material_override:
		var mat := physics_material_override.duplicate() as PhysicsMaterial
		mat.friction = 0.0
		mat.bounce = mushroom_bounce
		physics_material_override = mat

		if ball:
			ball.contact_monitor = true
			if ball.max_contacts_reported < 4:
				ball.max_contacts_reported = 4
			if not ball.body_entered.is_connected(_on_ball_hit):
				ball.body_entered.connect(_on_ball_hit)
	elif is_lava_rock and physics_material_override:
		var mat := physics_material_override.duplicate() as PhysicsMaterial
		mat.friction = 0.25
		mat.absorbent = true
		mat.bounce = clampf(0.6 - lava_rock_bounce, 0.0, 0.6)
		physics_material_override = mat
	elif is_ice_bar and physics_material_override:
		var mat := physics_material_override.duplicate() as PhysicsMaterial
		mat.friction = 0.01
		mat.bounce = 0.85
		physics_material_override = mat
	elif is_crystal and physics_material_override:
		var mat := physics_material_override.duplicate() as PhysicsMaterial
		mat.friction = 0.05
		mat.bounce = 0.9
		physics_material_override = mat
	elif is_atlantis and physics_material_override:
		var mat := physics_material_override.duplicate() as PhysicsMaterial
		mat.friction = 0.04
		mat.bounce = 0.95
		physics_material_override = mat
	elif is_cyber_neon and physics_material_override:
		var mat := physics_material_override.duplicate() as PhysicsMaterial
		mat.friction = 0.03
		mat.bounce = 0.92
		physics_material_override = mat

	queue_redraw()

func _on_ball_hit(body: Node):
	if body != self:
		return
	var now := Time.get_ticks_msec()
	if now - _last_bounce_msec < 80:
		return
	_last_bounce_msec = now

	# Mantar esneme (squash & stretch) animasyonu
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.16, 0.72), 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.94, 1.12), 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _physics_process(delta):
	if Engine.is_editor_hint():
		return
	if auto_rotate_speed != 0.0:
		rotation += auto_rotate_speed * delta
		constant_angular_velocity = auto_rotate_speed

	if vertical_move_range > 0.0:
		_move_time += delta
		var phase := _move_time * vertical_move_speed + vertical_move_phase
		var target_y := clampf(
			_start_y + sin(phase) * vertical_move_range,
			vertical_min_y,
			vertical_max_y
		)
		var vy := (target_y - position.y) / maxf(delta, 0.001)
		position.y = target_y
		constant_linear_velocity = Vector2(0.0, vy)

	if is_cloud_platform:
		var target_vel := 0.0
		if not _ball_turning_to_ash and is_instance_valid(ground) and ground.has_method("is_wind_blowing") and ground.is_wind_blowing():
			var w_dir: float = ground.get_wind_direction()
			target_vel = w_dir * cloud_wind_speed
		# Rüzgar başladığında yumuşakça hızlan, rüzgar durduğunda yumuşakça yavaşla
		_cloud_drift_vel = move_toward(_cloud_drift_vel, target_vel, 320.0 * delta)
		if absf(_cloud_drift_vel) > 0.5:
			position.x = clampf(
				position.x + _cloud_drift_vel * delta,
				_start_x - cloud_move_range,
				_start_x + cloud_move_range
			)
		_process_storm_lightning(delta)

func _process_storm_lightning(delta: float):
	if _ball_turning_to_ash:
		_ash_progress = move_toward(_ash_progress, 1.0, delta / 0.95)
		queue_redraw()
		return

	if is_instance_valid(main_node) and main_node.get("game_over") == true:
		return

	if _lightning_state == 0:
		# Top fırlatılmışsa ve bulutun altından geçiyorsa 0.5sn şimşek sayacını başlat
		if is_instance_valid(ball) and not ball.freeze:
			var shot_active := true
			if is_instance_valid(main_node) and int(main_node.get("shot_count")) == 0:
				shot_active = false
			if shot_active and ball.global_position.y > global_position.y + 8.0 and ball.global_position.y < 625.0:
				if absf(ball.global_position.x - global_position.x) <= 78.0:
					_lightning_state = 1
					_lightning_timer = 0.5
					queue_redraw()

	elif _lightning_state == 1:
		# 0.5 saniye şarj olma süresi
		_lightning_timer -= delta
		queue_redraw()
		if _lightning_timer <= 0.0:
			_lightning_state = 2
			_lightning_timer = 0.28
			_generate_lightning_bolt()
			_check_lightning_hit_ball()
			queue_redraw()

	elif _lightning_state == 2:
		# Şimşek çakma anı
		_lightning_timer -= delta
		_check_lightning_hit_ball()
		queue_redraw()
		if _lightning_timer <= 0.0:
			_lightning_state = 3
			_lightning_timer = 0.9
			queue_redraw()

	elif _lightning_state == 3:
		# Kısa soğuma süresi
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			_lightning_state = 0
			queue_redraw()

func _generate_lightning_bolt():
	_lightning_bolt_global.clear()
	var start_pt := global_position + Vector2(0.0, 10.0)
	var end_y := 612.0
	var steps := 9
	_lightning_bolt_global.append(start_pt)
	for i in range(1, steps):
		var t := float(i) / float(steps)
		var py := lerpf(start_pt.y, end_y, t)
		var px := global_position.x + randf_range(-24.0, 24.0)
		_lightning_bolt_global.append(Vector2(px, py))
	_lightning_bolt_global.append(Vector2(global_position.x + randf_range(-8.0, 8.0), end_y))

func _check_lightning_hit_ball():
	if _ball_turning_to_ash or not is_instance_valid(ball):
		return
	if ball.global_position.y > global_position.y - 4.0 and ball.global_position.y < 625.0:
		if absf(ball.global_position.x - global_position.x) <= 62.0:
			_strike_ball_into_ash()

func _strike_ball_into_ash():
	_ball_turning_to_ash = true
	_ash_progress = 0.0
	_ash_origin_global = ball.global_position

	if is_instance_valid(main_node):
		main_node.set("is_dragging", false)
		main_node.queue_redraw()

	ball.call_deferred("set_linear_velocity", Vector2.ZERO)
	ball.call_deferred("set_angular_velocity", 0.0)
	ball.call_deferred("set_freeze_enabled", true)

	_ash_particles.clear()
	for i in range(24):
		_ash_particles.append({
			"offset": Vector2(randf_range(-13.0, 13.0), randf_range(-13.0, 13.0)),
			"drift": Vector2(randf_range(-28.0, 28.0), randf_range(-35.0, 22.0)),
			"r": randf_range(2.0, 4.5),
			"shade": randf_range(0.14, 0.34),
		})

	var sprite := ball.get_node_or_null("Sprite2D") as Node2D
	var tween := create_tween()
	# Önce şimşek elektriğiyle parlama, ardından yavaşça kararıp küle dönüşerek dağılma
	tween.tween_property(ball, "modulate", Color(2.2, 2.2, 1.5, 1.0), 0.1)
	tween.tween_property(ball, "modulate", Color(0.18, 0.18, 0.2, 1.0), 0.38)
	tween.tween_property(ball, "modulate", Color(0.1, 0.1, 0.12, 0.0), 0.45)
	if sprite:
		tween.parallel().tween_property(sprite, "scale", sprite.scale * Vector2(1.12, 0.65), 0.45)

	tween.tween_callback(func():
		if is_instance_valid(ball):
			ball.hide()
		if is_instance_valid(main_node) and main_node.has_method("end_game"):
			main_node.end_game(GameProgress.t("struck_by_lightning"))
	)

func _is_point_on_grab_area(global_pt: Vector2) -> bool:
	var local_pt := to_local(global_pt)
	if is_mushroom or is_cloud_platform:
		# Mantar veya bulut için geniş tutma alanı
		return Rect2(-80, -26, 160, 58).has_point(local_pt)
	# Standart çubuk için rahat tutma alanı
	return Rect2(-78, -18, 156, 36).has_point(local_pt)

func _input(event):
	if Engine.is_editor_hint() or not can_drag_rotate or not ball:
		return
	if get_tree().paused or ball.freeze or ball.linear_velocity.length() > 5.0:
		is_rotating = false
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos := get_global_mouse_position()
			# Topun kendisine tıklanıyorsa topu fırlatma öncelikli olsun
			if mouse_pos.distance_to(ball.global_position) < 35.0:
				return
			if _is_point_on_grab_area(mouse_pos):
				is_rotating = true
				var click_angle := (mouse_pos - global_position).angle()
				_drag_angle_offset = wrapf(rotation - click_angle, -PI, PI)
				get_viewport().set_input_as_handled()
		else:
			is_rotating = false

	elif event is InputEventMouseMotion and is_rotating:
		var mouse_pos := get_global_mouse_position()
		if mouse_pos.distance_to(global_position) > 4.0:
			var current_angle := (mouse_pos - global_position).angle()
			rotation = current_angle + _drag_angle_offset
		get_viewport().set_input_as_handled()

func _draw():
	if is_rusty_factory:
		# 1. Perçinli paslı çelik I-kiriş gövdesi
		draw_rect(Rect2(-70.0, -7.0, 140.0, 14.0), Color("#362C25"))
		draw_rect(Rect2(-70.0, -7.0, 140.0, 3.5), Color("#59483B"))
		draw_rect(Rect2(-70.0, 3.5, 140.0, 3.5), Color("#211A15"))

		# 2. Gövde üzerindeki oksitlenmiş kızıl-kahve pas lekeleri
		draw_rect(Rect2(-52.0, -4.0, 30.0, 8.0), Color("#7D3F1E", 0.78))
		draw_rect(Rect2(14.0, -3.5, 36.0, 7.0), Color("#8A4621", 0.78))

		# 3. Sol ve sağ uçlarda sarı-siyah endüstriyel uyarı şeritli çelik kelepçeler
		for side: float in [-1.0, 1.0]:
			var cx: float = side * 60.0
			draw_rect(Rect2(cx - 8.0, -8.0, 16.0, 16.0), Color("#26201B"))
			draw_line(Vector2(cx - 5.0, -7.0), Vector2(cx - 1.0, 7.0), Color("#D49B2A"), 2.4)
			draw_line(Vector2(cx + 2.0, -7.0), Vector2(cx + 6.0, 7.0), Color("#D49B2A"), 2.4)
			draw_rect(Rect2(cx - 8.0, -8.0, 16.0, 16.0), Color("#6E5847"), false, 1.5)

		# 4. Kiriş boyunca çelik perçin çivileri
		for rx_pos: float in [-42.0, -24.0, 24.0, 42.0]:
			draw_circle(Vector2(rx_pos, 0.0), 2.2, Color("#1C1612"))
			draw_circle(Vector2(rx_pos - 0.5, -0.5), 1.4, Color("#8C735B"))

		# 5. Merkez pirinç/bakır fabrika somunu
		draw_circle(Vector2.ZERO, 6.5, Color("#241D18"))
		draw_circle(Vector2.ZERO, 4.8, Color("#B87333"))
		draw_circle(Vector2.ZERO, 2.2, Color("#E6A85C"))
		draw_rect(Rect2(-70.0, -7.0, 140.0, 14.0), Color("#1A1410"), false, 1.5)
		return

	if is_cyber_neon:
		# Sol yansıtıcı mor/pembe neon, sağ yansıtıcı mavi/camgöbeği neon ağırlıklı olsun
		var is_right_side := position.x > 640.0
		var neon_main := Color("#00E5FF") if is_right_side else Color("#D536FF")
		var neon_sub := Color("#FF36C8") if is_right_side else Color("#18E8FF")

		# 1. Dış siber neon ışık halesi (glow)
		draw_rect(Rect2(-74.0, -11.0, 148.0, 22.0), Color(neon_main.r, neon_main.g, neon_main.b, 0.20))

		# 2. Koyu siber-metal gövde
		draw_rect(Rect2(-70.0, -6.5, 140.0, 13.0), Color("#0C1229"))
		draw_rect(Rect2(-70.0, -6.5, 140.0, 3.5), Color("#1A2754"))
		draw_rect(Rect2(-70.0, 3.0, 140.0, 3.5), Color("#070A18"))

		# 3. Üst ve alt parlak neon enerji rayları
		draw_line(Vector2(-66.0, -5.5), Vector2(66.0, -5.5), neon_main, 2.4)
		draw_line(Vector2(-66.0, 5.5), Vector2(66.0, 5.5), neon_main, 2.4)

		# 4. Merkez siber veri şeridi ve çapraz teknolojik bölmeler
		draw_line(Vector2(-54.0, 0.0), Vector2(54.0, 0.0), neon_sub, 2.8)
		draw_line(Vector2(-52.0, 0.0), Vector2(52.0, 0.0), Color(0.95, 0.98, 1.0, 0.9), 1.2)
		for side: float in [-1.0, 1.0]:
			var cx: float = side * 62.0
			draw_rect(Rect2(cx - 6.0, -7.0, 12.0, 14.0), Color("#18244A"))
			draw_rect(Rect2(cx - 6.0, -7.0, 12.0, 14.0), neon_main, false, 1.6)
			draw_circle(Vector2(cx, 0.0), 2.6, Color.WHITE)

		# Merkez dönüş çekirdeği
		draw_circle(Vector2.ZERO, 5.5, Color("#0C1229"))
		draw_arc(Vector2.ZERO, 5.5, 0.0, TAU, 16, neon_main, 1.8)
		draw_circle(Vector2.ZERO, 2.4, Color.WHITE)
		return

	if is_atlantis:
		# Dış biyolüminesan turkuaz Atlantis parıltısı (glow)
		var aura_poly := PackedVector2Array([
			Vector2(-82, 0),
			Vector2(-64, -13),
			Vector2(64, -13),
			Vector2(82, 0),
			Vector2(64, 13),
			Vector2(-64, 13),
		])
		draw_colored_polygon(aura_poly, Color(0.05, 0.92, 0.98, 0.20))

		# Ana antik deniz mermeri / Atlantis sütun gövdesi
		draw_rect(Rect2(-66, -7, 132, 14), Color("#195363"))
		draw_rect(Rect2(-66, -7, 132, 4), Color("#368FA3"))
		draw_rect(Rect2(-66, 3, 132, 4), Color("#0D2F3A"))

		# Orta parlayan turkuaz enerji kanalı
		draw_rect(Rect2(-52, -2.5, 104, 5.0), Color("#00E5FF", 0.55))
		draw_line(Vector2(-50, 0), Vector2(50, 0), Color("#D4FFFF", 0.95), 2.0)

		# Sol ve sağ altın Atlantis başlıkları ve mızrak uçları
		for side: float in [-1.0, 1.0]:
			var tip_poly := PackedVector2Array([
				Vector2(side * 64.0, -7.5),
				Vector2(side * 77.0, 0.0),
				Vector2(side * 64.0, 7.5),
			])
			draw_colored_polygon(tip_poly, Color("#F4C430"))
			draw_polyline(PackedVector2Array([tip_poly[0], tip_poly[1], tip_poly[2]]), Color("#7A5304"), 1.8)

			var cap_x: float = -66.0 if side < 0.0 else 52.0
			draw_rect(Rect2(cap_x, -8.0, 14.0, 16.0), Color("#D9A418"))
			draw_rect(Rect2(cap_x, -8.0, 14.0, 4.5), Color("#FFE270"))
			draw_rect(Rect2(cap_x, 3.5, 14.0, 4.5), Color("#8F6206"))
			draw_rect(Rect2(cap_x, -8.0, 14.0, 16.0), Color("#5E3E02"), false, 1.6)

			# Parlayan Atlantis rün eşkenar dörtgenleri
			var rx: float = side * 31.0
			var rune := PackedVector2Array([
				Vector2(rx, -4.5),
				Vector2(rx + 5.5, 0.0),
				Vector2(rx, 4.5),
				Vector2(rx - 5.5, 0.0),
			])
			draw_colored_polygon(rune, Color("#24F3FF"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(rx, -2.2), Vector2(rx + 2.8, 0.0), Vector2(rx, 2.2), Vector2(rx - 2.8, 0.0)
			]), Color("#E8FFFF"))

		# Merkezdeki altın Poseidon halkası ve turkuaz mücevher
		draw_rect(Rect2(-9.0, -8.5, 18.0, 17.0), Color("#E5B21E"))
		draw_rect(Rect2(-9.0, -8.5, 18.0, 4.5), Color("#FFE57F"))
		draw_rect(Rect2(-9.0, 4.0, 18.0, 4.5), Color("#8C6005"))
		draw_rect(Rect2(-9.0, -8.5, 18.0, 17.0), Color("#593B02"), false, 1.6)
		draw_circle(Vector2.ZERO, 4.5, Color("#0A4858"))
		draw_circle(Vector2.ZERO, 3.3, Color("#33F6FF"))
		draw_circle(Vector2(-1.0, -1.0), 1.3, Color("#FFFFFF"))

		# Sütun dış çerçevesi
		draw_rect(Rect2(-66, -7, 132, 14), Color("#0A252E"), false, 1.8)
		return

	if is_crystal:
		# Dış ametist-mor kristal parıltısı (glow)
		var glow_poly := PackedVector2Array([
			Vector2(-80, 0),
			Vector2(-56, -13),
			Vector2(56, -13),
			Vector2(80, 0),
			Vector2(56, 13),
			Vector2(-56, 13),
		])
		draw_colored_polygon(glow_poly, Color(0.75, 0.32, 1.0, 0.22))

		# Ana altıgen mor kristal prizma gövdesi
		var base_shard := PackedVector2Array([
			Vector2(-74, 0),
			Vector2(-52, -8),
			Vector2(52, -8),
			Vector2(74, 0),
			Vector2(52, 8),
			Vector2(-52, 8),
		])
		draw_colored_polygon(base_shard, Color("#6A1B9A"))

		# Üst aydınlık leylak-eflatun kristal yüzeyi (facet)
		var top_facet := PackedVector2Array([
			Vector2(-74, 0),
			Vector2(-52, -8),
			Vector2(52, -8),
			Vector2(74, 0),
			Vector2(44, -1),
			Vector2(-44, -1),
		])
		draw_colored_polygon(top_facet, Color("#C77DFF"))

		# Alt koyu mor-mürdüm gölge yüzeyi
		var bottom_facet := PackedVector2Array([
			Vector2(-74, 0),
			Vector2(-44, 1),
			Vector2(44, 1),
			Vector2(74, 0),
			Vector2(52, 8),
			Vector2(-52, 8),
		])
		draw_colored_polygon(bottom_facet, Color("#3C096C"))

		# Orta prizmatik ametist iç yüzey ve fuşya-mor yansımalar
		var center_facet := PackedVector2Array([
			Vector2(-54, 0),
			Vector2(-38, -4),
			Vector2(38, -4),
			Vector2(54, 0),
			Vector2(38, 4),
			Vector2(-38, 4),
		])
		draw_colored_polygon(center_facet, Color("#9D4EDD"))

		var purple_glint := PackedVector2Array([
			Vector2(-36, 0),
			Vector2(-14, 4),
			Vector2(28, 4),
			Vector2(42, 0),
		])
		draw_colored_polygon(purple_glint, Color("#E0AAFF", 0.55))

		# Kristal kırılma çizgileri (facet ridges) ve parlak lavanta-beyaz ışık yansımaları
		draw_line(Vector2(-74, 0), Vector2(74, 0), Color("#F8E8FF", 0.9), 1.6)
		draw_line(Vector2(-52, -8), Vector2(-38, -4), Color("#FFFFFF", 0.85), 1.4)
		draw_line(Vector2(52, -8), Vector2(38, -4), Color("#FFFFFF", 0.85), 1.4)
		draw_line(Vector2(-52, 8), Vector2(-38, 4), Color("#D896FF", 0.75), 1.3)
		draw_line(Vector2(52, 8), Vector2(38, 4), Color("#D896FF", 0.75), 1.3)
		draw_line(Vector2(-34, -5), Vector2(22, -5), Color("#FFFFFF", 0.95), 1.8)

		# Kristal dış konturu
		var outline := base_shard.duplicate()
		outline.append(base_shard[0])
		draw_polyline(outline, Color("#240046"), 2.0)
		return

	if is_cloud_platform:
		# Şimşek çakıyorsa bulutun altından zemine inen şimşek hattını çiz
		if _lightning_state == 2 and _lightning_bolt_global.size() >= 2:
			var local_bolt := PackedVector2Array()
			for gpt in _lightning_bolt_global:
				local_bolt.append(to_local(gpt))
			draw_polyline(local_bolt, Color(0.45, 0.85, 1.0, 0.42), 14.0)
			draw_polyline(local_bolt, Color(1.0, 0.92, 0.35, 0.92), 6.0)
			draw_polyline(local_bolt, Color(1.0, 1.0, 0.92, 1.0), 2.5)

		# Top şimşekle vurulduysa yavaşça dağılan kül taneciklerini çiz
		if _ball_turning_to_ash and _ash_progress > 0.15:
			var t := clampf((_ash_progress - 0.15) / 0.85, 0.0, 1.0)
			var alpha := clampf(1.0 - t, 0.0, 1.0)
			for p in _ash_particles:
				var gpos: Vector2 = _ash_origin_global + p["offset"] + p["drift"] * t
				var lpos := to_local(gpos)
				var sh: float = p["shade"]
				draw_circle(lpos, lerpf(p["r"], 0.8, t), Color(sh, sh, sh + 0.02, alpha))

		# 1. Alt koyu fırtına bulutu gölgesi
		var puffs_shadow := [
			{"pos": Vector2(-50, 4), "r": 14.5},
			{"pos": Vector2(-24, 6), "r": 17.0},
			{"pos": Vector2(0, 7), "r": 19.0},
			{"pos": Vector2(26, 6), "r": 17.0},
			{"pos": Vector2(50, 4), "r": 14.5},
		]
		for p in puffs_shadow:
			draw_circle(p["pos"], p["r"], Color("#181C28"))

		# Şarj olurken veya çakarken bulutun altındaki elektrik parıltısı
		if _lightning_state == 1 or _lightning_state == 2:
			var charge_alpha := 0.75 if _lightning_state == 2 else (0.35 + absf(sin(_lightning_timer * 26.0)) * 0.45)
			draw_circle(Vector2(-18, 5), 13.0, Color(1.0, 0.92, 0.35, charge_alpha))
			draw_circle(Vector2(0, 6), 16.0, Color(0.55, 0.9, 1.0, charge_alpha))
			draw_circle(Vector2(18, 5), 13.0, Color(1.0, 0.92, 0.35, charge_alpha))

		# 2. Orta koyu kurşuni-lacivert fırtına bulutu gövdesi
		var puffs_mid := [
			{"pos": Vector2(-52, 0), "r": 13.5},
			{"pos": Vector2(-28, -2), "r": 16.5},
			{"pos": Vector2(0, -3), "r": 19.0},
			{"pos": Vector2(28, -2), "r": 16.5},
			{"pos": Vector2(52, 0), "r": 13.5},
		]
		for p in puffs_mid:
			draw_circle(p["pos"], p["r"], Color("#262D3F"))
			draw_circle(p["pos"] + Vector2(0, -1.5), p["r"] * 0.9, Color("#343D54"))

		# 3. Üst fırtına bulutu tepeleri
		var puffs_top := [
			{"pos": Vector2(-46, -3), "r": 9.5},
			{"pos": Vector2(-24, -6), "r": 12.0},
			{"pos": Vector2(0, -8), "r": 14.0},
			{"pos": Vector2(24, -6), "r": 12.0},
			{"pos": Vector2(46, -3), "r": 9.5},
		]
		for p in puffs_top:
			draw_circle(p["pos"], p["r"], Color("#46526E"))

		# Bulut içi elektrik kıvılcım çizgileri ve koyu kıvrımlar
		draw_arc(Vector2(-22, 3), 8.0, PI * 0.15, PI * 0.85, 10, Color("#12151F", 0.75), 2.0)
		draw_arc(Vector2(20, 3), 8.0, PI * 0.15, PI * 0.85, 10, Color("#12151F", 0.75), 2.0)
		draw_line(Vector2(-14, 2), Vector2(-4, 6), Color("#FFE45E", 0.7), 1.6)
		draw_line(Vector2(-4, 6), Vector2(4, 2), Color("#FFE45E", 0.7), 1.6)
		draw_line(Vector2(4, 2), Vector2(14, 7), Color("#FFE45E", 0.7), 1.6)
		return

	if is_lava_rock:
		# Kırıklı volkanik bazalt kaya gövdesi (Ground ile uyumlu koyu bazalt tonları)
		var rock_poly := PackedVector2Array([
			Vector2(-72, -3),
			Vector2(-65, -8),
			Vector2(-28, -9),
			Vector2(18, -8),
			Vector2(64, -9),
			Vector2(72, -2),
			Vector2(67, 8),
			Vector2(22, 9),
			Vector2(-32, 8),
			Vector2(-68, 7),
		])
		draw_colored_polygon(rock_poly, Color("#1C1417"))

		# Üst kül ve korlaşmış kaya katmanı
		var top_crust := PackedVector2Array([
			Vector2(-68, -4),
			Vector2(-64, -8),
			Vector2(-28, -9),
			Vector2(18, -8),
			Vector2(64, -9),
			Vector2(69, -3),
			Vector2(62, -2),
			Vector2(-62, -2),
		])
		draw_colored_polygon(top_crust, Color("#382329"))

		# Kaya içi parlayan magma / lav damarları
		var crack1 := PackedVector2Array([
			Vector2(-56, -2),
			Vector2(-34, 2),
			Vector2(-12, -1),
			Vector2(8, 3),
		])
		draw_polyline(crack1, Color("#FF4D00"), 3.0)
		draw_polyline(crack1, Color("#FFD03B"), 1.3)

		var crack2 := PackedVector2Array([
			Vector2(16, -3),
			Vector2(36, 1),
			Vector2(56, -2),
		])
		draw_polyline(crack2, Color("#FF4D00"), 2.8)
		draw_polyline(crack2, Color("#FFD03B"), 1.2)

		# Küçük kor lekeleri
		draw_circle(Vector2(-44, -4), 2.2, Color("#FF7300"))
		draw_circle(Vector2(2, -4), 2.5, Color("#FF7300"))
		draw_circle(Vector2(42, 4), 2.0, Color("#FF5500"))

		# Kızgın turuncu-koyu bazalt dış kontur
		var outline := rock_poly.duplicate()
		outline.append(rock_poly[0])
		draw_polyline(outline, Color("#FF5500", 0.8), 2.0)
		return

	if is_mushroom:
		# Mantar sapı (altta mor-krem orman gövdesi)
		draw_rect(Rect2(-20, 4, 40, 24), Color("#B898B0"))
		draw_rect(Rect2(-14, 4, 12, 24), Color("#D8C0D0"))
		draw_rect(Rect2(-20, 4, 40, 5), Color("#6E4F6B"))
		# Sap altı parlayan turkuaz halkalar
		draw_line(Vector2(-18, 9), Vector2(18, 9), Color("#4CF5E8", 0.75), 2.0)
		draw_rect(Rect2(-20, 4, 40, 24), Color("#26122B"), false, 2.0)

		# Mantar şapkası (arka planla uyumlu mürdüm-kızıl şapka)
		var cap := PackedVector2Array([
			Vector2(-72, 6),
			Vector2(-68, -6),
			Vector2(-46, -15),
			Vector2(0, -19),
			Vector2(46, -15),
			Vector2(68, -6),
			Vector2(72, 6),
		])
		draw_colored_polygon(cap, Color("#9E2A5B"))

		# Şapka üst parlak katmanı
		var cap_top := PackedVector2Array([
			Vector2(-60, -4),
			Vector2(-42, -13),
			Vector2(0, -17),
			Vector2(42, -13),
			Vector2(60, -4),
		])
		draw_colored_polygon(cap_top, Color("#C93B72"))

		# Şapka alt gölgesi ve biyolüminesan turkuaz çizgi
		draw_rect(Rect2(-70, 2, 140, 4), Color("#4E1332"))
		draw_line(Vector2(-66, 5), Vector2(66, 5), Color("#5CE6D8", 0.7), 1.5)

		# Parlayan turuncu-sarı ve krem benekler (arka plandaki mantarlarla uyumlu)
		draw_circle(Vector2(-38, -6), 6.0, Color("#FFB347"))
		draw_circle(Vector2(-38, -6), 3.2, Color("#FFF3B0"))
		draw_circle(Vector2(0, -10), 7.5, Color("#FFB347"))
		draw_circle(Vector2(0, -10), 4.0, Color("#FFF3B0"))
		draw_circle(Vector2(38, -6), 6.0, Color("#FFB347"))
		draw_circle(Vector2(38, -6), 3.2, Color("#FFF3B0"))
		draw_circle(Vector2(-18, -2), 3.5, Color("#FFE599"))
		draw_circle(Vector2(20, -2), 4.0, Color("#FFE599"))

		# Şapka dış konturu
		var outline := cap.duplicate()
		outline.append(cap[0])
		draw_polyline(outline, Color("#240A1A"), 2.0)
		return

	if is_ice_bar:
		# Ana buz gövdesi
		draw_rect(Rect2(-70, -6, 140, 12), Color("#63C5F2"))
		# Üst beyaz-mavi parlama
		draw_rect(Rect2(-70, -6, 140, 3), Color("#E6FAFF"))
		# Alt koyu buz gölgesi
		draw_rect(Rect2(-70, 3, 140, 3), Color("#2E8BC0"))
		# Buz içi parlak yansıma çizgileri
		draw_line(Vector2(-55, -1), Vector2(-15, -1), Color("#FFFFFF", 0.85), 1.5)
		draw_line(Vector2(5, 1), Vector2(50, 1), Color("#C8F2FF", 0.8), 1.2)
		# Dış kristal çerçeve
		draw_rect(Rect2(-70, -6, 140, 12), Color("#1D638C"), false, 1.5)
		return

	if is_stone_wall:
		# Ana açık gri duvar gövdesi
		draw_rect(Rect2(-70, -6, 140, 12), Color("#9EA4B0"))
		# Üst yüzeyde açık gri parlama
		draw_rect(Rect2(-70, -6, 140, 3), Color("#C5CBD6"))
		# Alt gölge (koyu gri)
		draw_rect(Rect2(-70, 3, 140, 3), Color("#5A606B"))
		# Duvar taş çizgileri / çatlak detayları (koyu gri)
		draw_line(Vector2(-60, -1), Vector2(55, -1), Color("#4A4F59"), 1.5)
		draw_line(Vector2(-45, 2), Vector2(35, 2), Color("#6E7582"), 1.0)
		# Dış kenar çizgisi
		draw_rect(Rect2(-70, -6, 140, 12), Color("#3B3F47"), false, 1.5)
		return

	# Ana ahşap gövde
	draw_rect(Rect2(-70, -6, 140, 12), Color("#704426"))
	# Üst yüzeyde ışık
	draw_rect(Rect2(-70, -6, 140, 3), Color("#A36A3F"))
	# Ahşap damarları
	draw_line(Vector2(-60, -1), Vector2(55, -1), Color("#4B2C1B"), 1.5)
	draw_line(Vector2(-45, 3), Vector2(35, 3), Color("#B17A4E"), 1.0)
	# Kenar çizgileri
	draw_line(Vector2(-70, -6), Vector2(70, -6), Color("#C18A58"), 1.0)
