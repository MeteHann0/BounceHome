@tool
extends StaticBody2D

const GameProgress := preload("res://scripts/game_progress.gd")
const VolcanoRockScript := preload("res://scripts/volcano_rock.gd")
const StalactiteScript := preload("res://scripts/stalactite.gd")

@export var is_sand: bool = false:
	set(value):
		is_sand = value
		queue_redraw()
@export var is_ice: bool = false:
	set(value):
		is_ice = value
		queue_redraw()
@export var is_mushroom_forest: bool = false:
	set(value):
		is_mushroom_forest = value
		queue_redraw()
@export var is_volcano: bool = false:
	set(value):
		is_volcano = value
		queue_redraw()
@export var is_cloud: bool = false:
	set(value):
		is_cloud = value
		queue_redraw()
@export var is_crystal_cave: bool = false:
	set(value):
		is_crystal_cave = value
		queue_redraw()
@export var is_swamp: bool = false:
	set(value):
		is_swamp = value
		queue_redraw()
@export var is_atlantis: bool = false:
	set(value):
		is_atlantis = value
		queue_redraw()
@export var is_cyber_city: bool = false:
	set(value):
		is_cyber_city = value
		queue_redraw()
@export var is_rusty_factory: bool = false:
	set(value):
		is_rusty_factory = value
		queue_redraw()
@export var is_black_hole: bool = false:
	set(value):
		is_black_hole = value
		queue_redraw()

## Bataklığın başladığı yerel X konumu (-640..swamp_start_x arası güvenli başlangıç toprağıdır)
@export var swamp_start_x: float = -380.0:
	set(value):
		swamp_start_x = value
		queue_redraw()
## Topun bataklıkta saniyede kaç piksel hızla batacağı (yarıya kadar 15px batması ~3 saniye sürer)
@export var swamp_sink_speed: float = 5.0

## Kristal mağarada 1.25 - 1.75 saniye aralığında tavandan sarkıt düşsün mü
@export var spawn_stalactites: bool = true
@export var stalactite_interval_min: float = 1.25
@export var stalactite_interval_max: float = 1.75

## Bulut zeminde topun net sekme oranı (normal toprak 0.6, bulut varsayılan 0.38)
@export var cloud_bounce: float = 0.38
## Bulut bölümünde rüzgar esme sıklığı (saniye) ve savurma gücü
@export var wind_interval_min: float = 2.0
@export var wind_interval_max: float = 3.0
@export var wind_duration: float = 1.4
@export var wind_force: float = 260.0

## Lav yarığının Ground merkezine (x=640) göre yatay konumu
@export var lava_pit_x: float = 20.0:
	set(value):
		lava_pit_x = value
		queue_redraw()

## Lav yarığının genişliği (piksel)
@export var lava_pit_width: float = 270.0:
	set(value):
		lava_pit_width = maxf(60.0, value)
		queue_redraw()

## Yanardağdan 1-1.5 saniye arasında kor kaya parçaları düşsün mü
@export var spawn_volcano_rocks: bool = true
@export var rock_interval_min: float = 1.0
@export var rock_interval_max: float = 1.5

var _lava_time: float = 0.0
var _rock_timer: float = 1.0
var _ball: RigidBody2D = null
var _main_node: Node2D = null
var _ball_sinking: bool = false
var _sink_progress: float = 0.0
var _sink_local_x: float = 0.0

var _wind_timer: float = 2.0
var _wind_active_timer: float = 0.0
var _wind_dir: float = 1.0
var _wind_anim_time: float = 0.0
var _stalactite_timer: float = 1.25
var _crystal_anim_time: float = 0.0
var _bat_timer: float = 3.5
var _bat_last_dir: float = 0.0
var _active_bats: Array = []

var _swamp_time: float = 0.0
var _ball_in_swamp: bool = false
var _swamp_escape_timer: float = 0.0
var _last_swamp_shot_count: int = 0
var _atlantis_time: float = 0.0
var _cyber_time: float = 0.0
var _factory_time: float = 0.0
var _void_time: float = 0.0

func _ready():
	if not is_volcano and get_parent() and String(get_parent().scene_file_path).ends_with("level5.tscn"):
		is_volcano = true
	if not is_cloud and get_parent() and String(get_parent().scene_file_path).ends_with("level6.tscn"):
		is_cloud = true
	if not is_crystal_cave and get_parent() and String(get_parent().scene_file_path).ends_with("level7.tscn"):
		is_crystal_cave = true
	if not is_swamp and get_parent() and String(get_parent().scene_file_path).ends_with("level8.tscn"):
		is_swamp = true
	if not is_atlantis and get_parent() and String(get_parent().scene_file_path).ends_with("level9.tscn"):
		is_atlantis = true
	if not is_cyber_city and get_parent() and String(get_parent().scene_file_path).ends_with("level10.tscn"):
		is_cyber_city = true
	if not is_rusty_factory and get_parent() and String(get_parent().scene_file_path).ends_with("level11.tscn"):
		is_rusty_factory = true
	if not is_black_hole and get_parent() and String(get_parent().scene_file_path).ends_with("level12.tscn"):
		is_black_hole = true

	if Engine.is_editor_hint():
		queue_redraw()
		return

	_main_node = get_parent() as Node2D
	if _main_node:
		_ball = _main_node.get_node_or_null("Ball") as RigidBody2D

	if is_swamp:
		z_index = 1
		_setup_swamp_colliders()

	if is_crystal_cave:
		_setup_crystal_cave_stalagmites()
		stalactite_interval_min = 1.25
		stalactite_interval_max = 1.75
		_stalactite_timer = randf_range(stalactite_interval_min, stalactite_interval_max)
		if spawn_stalactites:
			call_deferred("_spawn_initial_stalactites")

	if is_volcano:
		_setup_volcano_colliders()
		rock_interval_min = 1.0
		rock_interval_max = 1.5
		_rock_timer = 0.6
		if spawn_volcano_rocks:
			call_deferred("_spawn_initial_rocks")

	if is_cloud:
		var cloud_mat := PhysicsMaterial.new()
		cloud_mat.friction = 0.15
		cloud_mat.absorbent = true
		var target_bounce: float = cloud_bounce if cloud_bounce != null else 0.38
		# Topun kendi bounce'u 0.6 olduğu için absorbent ile (0.6 - cloud_bounce) kadar düşürülür
		cloud_mat.bounce = clampf(0.6 - target_bounce, 0.0, 0.6)
		physics_material_override = cloud_mat
		_wind_timer = randf_range(wind_interval_min, wind_interval_max)
		_wind_dir = 1.0 if randf() < 0.5 else -1.0

	if is_ice:
		var mat := PhysicsMaterial.new()
		mat.friction = 0.015
		mat.bounce = 0.25
		physics_material_override = mat

		# Buz zeminde topun da sürtünmesini azaltarak gerçekçi kayma hissi ver
		var ball := get_parent().get_node_or_null("Ball") as RigidBody2D
		if ball and ball.physics_material_override:
			var ball_mat := ball.physics_material_override.duplicate() as PhysicsMaterial
			ball_mat.friction = 0.015
			ball.physics_material_override = ball_mat
			ball.angular_damp = 0.2

func _setup_volcano_colliders():
	var pit_left := clampf(lava_pit_x - lava_pit_width * 0.5, -580.0, 580.0)
	var pit_right := clampf(lava_pit_x + lava_pit_width * 0.5, -580.0, 580.0)

	var left_col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if left_col:
		var left_w := maxf(20.0, pit_left - (-640.0))
		var left_rect := RectangleShape2D.new()
		left_rect.size = Vector2(left_w, 40.0)
		left_col.shape = left_rect
		left_col.position = Vector2(-640.0 + left_w * 0.5, 0.0)

	var right_w := maxf(20.0, 640.0 - pit_right)
	var right_col := CollisionShape2D.new()
	right_col.name = "RightCollisionShape"
	var right_rect := RectangleShape2D.new()
	right_rect.size = Vector2(right_w, 40.0)
	right_col.shape = right_rect
	right_col.position = Vector2(pit_right + right_w * 0.5, 0.0)
	add_child(right_col)

func _physics_process(delta: float):
	if Engine.is_editor_hint():
		return

	if is_black_hole:
		_void_time += delta
		queue_redraw()
		return

	if is_rusty_factory:
		_factory_time += delta
		queue_redraw()
		return

	if is_cyber_city:
		_cyber_time += delta
		queue_redraw()
		return

	if is_atlantis:
		_atlantis_time += delta
		queue_redraw()
		return

	if is_swamp:
		_process_swamp(delta)
		return

	if is_crystal_cave:
		_process_crystal_cave(delta)
		return

	if is_cloud:
		_process_cloud_wind(delta)
		return

	if not is_volcano:
		return

	_lava_time += delta
	if _ball_sinking:
		_sink_progress = move_toward(_sink_progress, 1.0, delta / 0.65)
	queue_redraw()

	if _ball_sinking or (is_instance_valid(_main_node) and _main_node.get("game_over") == true):
		return

	# Top lav yarığına düştü mü kontrol et
	if is_instance_valid(_ball):
		var local_ball := to_local(_ball.global_position)
		var pit_left := clampf(lava_pit_x - lava_pit_width * 0.5, -580.0, 580.0)
		var pit_right := clampf(lava_pit_x + lava_pit_width * 0.5, -580.0, 580.0)
		if local_ball.x > pit_left + 4.0 and local_ball.x < pit_right - 4.0 and local_ball.y >= -10.0:
			_sink_ball_in_lava(local_ball.x)
			return

	# 1 - 1.5 saniyede bir yanardağdan kor kaya parçası düşür
	if spawn_volcano_rocks and is_instance_valid(_main_node):
		_rock_timer -= delta
		if _rock_timer <= 0.0:
			_rock_timer = randf_range(rock_interval_min, rock_interval_max)
			_spawn_volcano_rock()
			if randf() < 0.55:
				_spawn_volcano_rock()

func _sink_ball_in_lava(hit_x: float):
	_ball_sinking = true
	_sink_progress = 0.0
	_sink_local_x = hit_x

	if is_instance_valid(_main_node):
		_main_node.set("is_dragging", false)
		_main_node.queue_redraw()

	_ball.call_deferred("set_linear_velocity", Vector2.ZERO)
	_ball.call_deferred("set_angular_velocity", 0.0)
	_ball.call_deferred("set_freeze_enabled", true)

	var start_pos := _ball.global_position
	var sink_target := Vector2(start_pos.x, global_position.y + 34.0)
	var sprite := _ball.get_node_or_null("Sprite2D") as Node2D

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_ball, "global_position", sink_target, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_ball, "modulate", Color(1.0, 0.25, 0.0, 0.0), 0.58) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if sprite:
		tween.tween_property(sprite, "scale", sprite.scale * Vector2(0.45, 0.15), 0.58) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(func():
		if is_instance_valid(_ball):
			_ball.hide()
		if is_instance_valid(_main_node) and _main_node.has_method("end_game"):
			_main_node.end_game(GameProgress.t("fell_in_lava"))
	)

func _spawn_initial_rocks():
	for start_y in [90.0, 230.0, 360.0]:
		_spawn_volcano_rock(start_y)

func _spawn_volcano_rock(custom_start_y: float = -26.0):
	if not is_instance_valid(_main_node):
		return
	var rock := Node2D.new()
	rock.set_script(VolcanoRockScript)

	# 45 ile 135 derece arasında rastgele düşüş açısı
	var angle_deg := randf_range(45.0, 135.0)
	var angle_rad := deg_to_rad(angle_deg)
	var dir := Vector2(cos(angle_rad), sin(angle_rad))
	var speed := randf_range(145.0, 185.0)
	var cot := dir.x / dir.y

	# Kayanın ekranın orta oyun alanından (x = 300..1080, y = 340) geçmesini sağla
	var target_mid_x := randf_range(300.0, 1080.0)
	var spawn_x := target_mid_x - (340.0 - custom_start_y) * cot

	# Topun başlangıç bölgesine (x < 260) inmesini kesin olarak engelle
	var min_safe_spawn_x := 260.0 - maxf(0.0, 600.0 - custom_start_y) * minf(0.0, cot)
	spawn_x = maxf(spawn_x, min_safe_spawn_x)

	rock.global_position = Vector2(spawn_x, custom_start_y)
	rock.velocity = dir * speed
	rock.rot_speed = randf_range(-2.2, 2.2)
	rock.rock_radius = randf_range(16.0, 22.0)
	rock.ball = _ball
	rock.main_node = _main_node
	_main_node.add_child(rock)

func is_wind_blowing() -> bool:
	return is_cloud and _wind_active_timer > 0.0

func get_wind_direction() -> float:
	return _wind_dir

func _process_cloud_wind(delta: float):
	_wind_anim_time += delta
	queue_redraw()

	if is_instance_valid(_main_node) and _main_node.get("game_over") == true:
		_wind_active_timer = 0.0
		return

	if _wind_active_timer > 0.0:
		_wind_active_timer -= delta
		# Rüzgar eserken top fırlatılmışsa topu ileri/geri savur
		if is_instance_valid(_ball) and not _ball.freeze:
			var shot_active := true
			if is_instance_valid(_main_node) and int(_main_node.get("shot_count")) == 0:
				shot_active = false
			if shot_active and _ball.linear_velocity.length() > 6.0:
				_ball.apply_central_force(Vector2(_wind_dir * wind_force, 0.0))
	else:
		_wind_timer -= delta
		if _wind_timer <= 0.0:
			_wind_timer = randf_range(wind_interval_min, wind_interval_max)
			_wind_active_timer = wind_duration
			# %70 ihtimalle yön değiştir, %30 ihtimalle rastgele seç (tek yöne takılmasın)
			if randf() < 0.7:
				_wind_dir = -_wind_dir
			else:
				_wind_dir = 1.0 if randf() < 0.5 else -1.0

			# Rüzgar başladığı anda top havada/hareket halindeyse anlık esinti darbesi uygula
			if is_instance_valid(_ball) and not _ball.freeze:
				var shot_active := true
				if is_instance_valid(_main_node) and int(_main_node.get("shot_count")) == 0:
					shot_active = false
				if shot_active and _ball.linear_velocity.length() > 6.0:
					_ball.apply_central_impulse(Vector2(_wind_dir * 25.0, 0.0))

func _draw():
	if is_black_hole:
		_draw_black_hole_ground()
		return

	if is_rusty_factory:
		_draw_rusty_factory_ground()
		return

	if is_cyber_city:
		_draw_cyber_city_ground()
		return

	if is_atlantis:
		_draw_atlantis_ground()
		return

	if is_swamp:
		_draw_swamp_ground()
		return

	if is_crystal_cave:
		_draw_crystal_cave_ground()
		return

	if is_cloud:
		_draw_cloud_ground()
		return

	if is_volcano:
		_draw_volcano_ground()
		return

	if is_mushroom_forest:
		# Koyu mor-lacivert orman toprağı
		draw_rect(
			Rect2(-640, -20, 1280, 200),
			Color("#1D162B")
		)

		# Toprak içi mor taş ve kök dokuları
		for i in range(80):
			var x = -630 + i * 16
			var y = -3 + sin(i * 8.3) * 9

			draw_circle(
				Vector2(x, y),
				2.2,
				Color("#35274D")
			)

		# Koyu zümrüt-çam yeşili orman yosunu tabakası
		draw_rect(
			Rect2(-640, -20, 1280, 9),
			Color("#1F5247")
		)

		# Üst biyolüminesan turkuaz-yeşil yosun sırtı
		draw_rect(
			Rect2(-640, -20, 1280, 3),
			Color("#3BA68B")
		)

		# Yosun çimenleri ve parlayan turkuaz/turuncu mini sporlar
		for i in range(160):
			var x = -635 + i * 8
			var height = 3 + abs(sin(i * 12.7)) * 4

			draw_line(
				Vector2(x, -20),
				Vector2(x + 1.5, -20 - height),
				Color("#3BA68B"),
				2.0
			)

			# Arka plandaki parlayan mavi-turkuaz ve turuncu mantar sporları
			if i % 7 == 0:
				draw_circle(Vector2(x, -22 - height * 0.6), 2.3, Color("#4CF5FF", 0.9))
				draw_circle(Vector2(x, -22 - height * 0.6), 4.5, Color("#4CF5FF", 0.22))
			elif i % 13 == 0:
				draw_circle(Vector2(x, -21 - height * 0.4), 2.0, Color("#FF8C3B", 0.9))
		return

	if is_ice:
		# Alt donmuş buzul katmanı
		draw_rect(
			Rect2(-640, -20, 1280, 200),
			Color("#3A6B8C")
		)

		# Buz içi kristal / kabarcık detayları
		for i in range(80):
			var x = -630 + i * 16
			var y = -3 + sin(i * 8.3) * 9

			draw_circle(
				Vector2(x, y),
				2.2,
				Color("#64A2C8")
			)

		# Buz içi parlak yansıma çizgileri
		for i in range(28):
			var lx = -610 + i * 45
			draw_line(
				Vector2(lx, -8),
				Vector2(lx + 18, 4),
				Color("#8CCDF0", 0.55),
				1.5
			)

		# Üst saydam buz tabakası
		draw_rect(
			Rect2(-640, -20, 1280, 10),
			Color("#8CE0FF")
		)

		# En üst kar / parlak buz sırtı
		draw_rect(
			Rect2(-640, -20, 1280, 4),
			Color("#E8FAFF")
		)
		return

	if is_sand:
		# Alt kum/taş tabakası
		draw_rect(
			Rect2(-640, -20, 1280, 200),
			Color("#B88446")
		)

		# Kum taneleri / çakıl detayları
		for i in range(80):
			var x = -630 + i * 16
			var y = -5 + sin(i * 8.3) * 8

			draw_circle(
				Vector2(x, y),
				2.0,
				Color("#966530")
			)

		# Üst sıcak kum tabakası
		draw_rect(
			Rect2(-640, -20, 1280, 10),
			Color("#DFB16B")
		)

		# Kumun güneş vuran aydınlık üst çizgisi
		draw_rect(
			Rect2(-640, -20, 1280, 3),
			Color("#F5D293")
		)
		return

	# Koyu kahverengi toprak
	draw_rect(
		Rect2(-640, -20, 1280, 200),
		Color("#493D32")
	)

	# Toprak detayları
	for i in range(80):
		var x = -630 + i * 16
		var y = -5 + sin(i * 8.3) * 8

		draw_circle(
			Vector2(x, y),
			2.0,
			Color("#665044")
		)

	# Yeşil çimen tabakası
	draw_rect(
		Rect2(-640, -20, 1280, 8),
		Color("#32834A")
	)

	# Çimenin aydınlık üst çizgisi
	draw_rect(
		Rect2(-640, -20, 1280, 3),
		Color("#58B96A")
	)

	# Çimen yaprakları
	for i in range(160):
		var x = -635 + i * 8
		var height = 3 + abs(sin(i * 12.7)) * 5

		draw_line(
			Vector2(x, -20),
			Vector2(x + 2, -20 - height),
			Color("#58B96A"),
			2.0
		)

func _draw_volcano_ground():
	var pit_left := clampf(lava_pit_x - lava_pit_width * 0.5, -580.0, 580.0)
	var pit_right := clampf(lava_pit_x + lava_pit_width * 0.5, -580.0, 580.0)
	var left_w := pit_left - (-640.0)
	var right_w := 640.0 - pit_right

	# 1. Yarık içindeki karanlık arka duvar ve kızgın lav havuzu
	draw_rect(Rect2(pit_left, -18.0, lava_pit_width, 200.0), Color("#1A0707"))
	# Lav yukarı doğru sıcak parıltı (glow)
	draw_rect(Rect2(pit_left, -20.0, lava_pit_width, 18.0), Color(1.0, 0.28, 0.0, 0.22))
	# Ana lav kütlesi
	draw_rect(Rect2(pit_left, -4.0, lava_pit_width, 185.0), Color("#B81D0A"))
	draw_rect(Rect2(pit_left, -4.0, lava_pit_width, 22.0), Color("#FF4D00"))
	draw_rect(Rect2(pit_left, -4.0, lava_pit_width, 8.0), Color("#FF9900"))

	# Hareketli magma dalgaları ve fokurdayan lav kabarcıkları
	var wave_count := int(lava_pit_width / 22.0)
	for i in range(wave_count):
		var wx := pit_left + 12.0 + i * 22.0
		var wy := -3.0 + sin(_lava_time * 3.5 + i * 1.3) * 2.5
		draw_circle(Vector2(wx, wy), 5.5, Color("#FFD03B", 0.9))
		draw_circle(Vector2(wx, wy + 7.0), 3.5, Color("#FF7300", 0.85))

	# Top lava batarken çıkan lav sıçraması ve fokurdama halkaları
	if _ball_sinking and _sink_progress < 1.0:
		var t := _sink_progress
		var alpha := clampf(1.0 - t, 0.0, 1.0)
		draw_circle(Vector2(_sink_local_x, -3.0), lerpf(8.0, 28.0, t), Color(1.0, 0.65, 0.1, alpha * 0.65))
		for j in range(5):
			var dir_x := (j - 2) * 9.5
			var drop_x := _sink_local_x + dir_x * t * 1.6
			var drop_y := -5.0 - sin(t * PI) * (24.0 - absf(j - 2) * 4.5)
			draw_circle(Vector2(drop_x, drop_y), lerpf(4.8, 1.5, t), Color("#FF5500", alpha))
			draw_circle(Vector2(drop_x, drop_y), lerpf(2.8, 0.8, t), Color("#FFE066", alpha))

	# 2. Sol ve sağ volkanik bazalt zemin blokları
	var segments := [
		Rect2(-640.0, -20.0, left_w, 200.0),
		Rect2(pit_right, -20.0, right_w, 200.0),
	]
	for seg in segments:
		# Koyu bazalt kaya gövdesi
		draw_rect(seg, Color("#1C1417"))
		# Üst kül ve korlaşmış taş katmanı
		draw_rect(Rect2(seg.position.x, -20.0, seg.size.x, 10.0), Color("#332126"))
		draw_rect(Rect2(seg.position.x, -20.0, seg.size.x, 3.5), Color("#59343A"))

	# Yarık kenarlarındaki kırık/erimiş kaya çıkıntıları
	var left_edge := PackedVector2Array([
		Vector2(pit_left - 14.0, -20.0),
		Vector2(pit_left + 4.0, -20.0),
		Vector2(pit_left + 10.0, 12.0),
		Vector2(pit_left - 4.0, 48.0),
		Vector2(pit_left - 14.0, 90.0),
	])
	draw_colored_polygon(left_edge, Color("#28181C"))
	draw_polyline(left_edge, Color("#FF5E00", 0.85), 2.2)

	var right_edge := PackedVector2Array([
		Vector2(pit_right + 14.0, -20.0),
		Vector2(pit_right - 4.0, -20.0),
		Vector2(pit_right - 10.0, 12.0),
		Vector2(pit_right + 4.0, 48.0),
		Vector2(pit_right + 14.0, 90.0),
	])
	draw_colored_polygon(right_edge, Color("#28181C"))
	draw_polyline(right_edge, Color("#FF5E00", 0.85), 2.2)

	# Zemin içi kor çatlaklar ve volkanik taş dokuları
	for i in range(80):
		var x := -630.0 + i * 16.0
		if x > pit_left - 10.0 and x < pit_right + 10.0:
			continue
		var y := -3.0 + sin(i * 8.3) * 9.0
		draw_circle(Vector2(x, y), 2.3, Color("#382329"))
		if i % 6 == 0:
			draw_line(Vector2(x - 6.0, -18.0), Vector2(x + 4.0, -11.0), Color("#FF5500", 0.7), 1.8)

func _draw_cloud_ground():
	# 1. Alt koyu lavanta-mavi bulut gölge katmanı
	draw_rect(Rect2(-640.0, -14.0, 1280.0, 200.0), Color("#8090B5"))
	draw_rect(Rect2(-640.0, -14.0, 1280.0, 38.0), Color("#9AA9CC"))

	# 2. Orta yumuşak leylak-mavi bulut kubbeleri
	for i in range(34):
		var cx := -630.0 + i * 38.5
		var cy := 6.0 + sin(i * 1.9) * 5.0
		var r := 28.0 + fmod(i * 7.3, 10.0)
		draw_circle(Vector2(cx, cy), r, Color("#B8C4E0"))

	# 3. Üst güneş vuran sıcak krem-şeftali pofuduk bulut tepeleri
	for i in range(42):
		var cx := -635.0 + i * 31.0
		var bob := sin(_wind_anim_time * 1.8 + i * 0.8) * 1.5
		var cy := -8.0 + sin(i * 2.3) * 3.5 + bob
		var r := 20.0 + fmod(i * 5.1, 7.0)
		draw_circle(Vector2(cx, cy + 3.0), r + 1.5, Color("#D6C6D8"))
		draw_circle(Vector2(cx, cy), r, Color("#FFE8D8"))
		draw_circle(Vector2(cx - 3.0, cy - 3.5), r * 0.68, Color("#FFF7F0"))

	# Bulut içi yumuşak kıvrım çizgileri
	for i in range(22):
		var lx := -600.0 + i * 56.0
		var ly := 12.0 + sin(i * 3.1) * 6.0
		draw_arc(Vector2(lx, ly), 14.0, PI * 1.1, PI * 1.9, 12, Color("#6E7EA3", 0.55), 2.0)

	# 4. Rüzgar eserken ekranda akıp giden rüzgar çizgileri ve kıvrımları
	if _wind_active_timer > 0.0 and not Engine.is_editor_hint():
		var progress := 1.0 - (_wind_active_timer / maxf(0.1, wind_duration))
		var alpha := sin(clampf(progress, 0.0, 1.0) * PI)
		var stream_color := Color(1.0, 0.98, 0.95, alpha * 0.65)
		var glow_color := Color(0.78, 0.9, 1.0, alpha * 0.35)

		for i in range(14):
			var base_y := -560.0 + i * 37.0 + sin(i * 4.2) * 10.0
			var speed := 680.0 + (i % 4) * 95.0
			var offset := fmod(_wind_anim_time * speed + i * 170.0, 1460.0)
			var sx: float
			if _wind_dir > 0.0:
				sx = -730.0 + offset
			else:
				sx = 730.0 - offset

			var len := 85.0 + (i % 3) * 32.0
			var ex := sx + _wind_dir * len
			var wave_y := sin(_wind_anim_time * 8.0 + i) * 3.5

			draw_line(Vector2(sx, base_y), Vector2(ex, base_y + wave_y), glow_color, 5.0)
			draw_line(Vector2(sx, base_y), Vector2(ex, base_y + wave_y), stream_color, 2.2)

			# Rüzgar ucundaki küçük hava kıvrımı (yönü belli eder)
			var curl_center := Vector2(ex, base_y + wave_y - 6.0)
			draw_arc(curl_center, 6.0, 0.0, PI * 1.35, 10, stream_color, 2.0)

func _get_stalagmites_data() -> Array:
	# Ground merkezine (x=640, üst yüzey y=-20) göre 4 adet boyları değişken dikit
	return [
		{"x": -275.0, "base_w": 36.0, "height": 58.0, "crystal": Color("#38F2E6")},
		{"x": -95.0,  "base_w": 44.0, "height": 102.0, "crystal": Color("#B84DFF")},
		{"x": 110.0,  "base_w": 38.0, "height": 70.0, "crystal": Color("#42A5FF")},
		{"x": 290.0,  "base_w": 46.0, "height": 118.0, "crystal": Color("#38F2E6")},
	]

func _setup_crystal_cave_stalagmites():
	var idx := 0
	for st in _get_stalagmites_data():
		idx += 1
		var cx: float = st["x"]
		var hw: float = st["base_w"] * 0.5
		var h: float = st["height"]
		var col := CollisionPolygon2D.new()
		col.name = "StalagmiteCol%d" % idx
		col.polygon = PackedVector2Array([
			Vector2(cx - hw, -20.0),
			Vector2(cx - hw * 0.48, -20.0 - h * 0.62),
			Vector2(cx, -20.0 - h),
			Vector2(cx + hw * 0.48, -20.0 - h * 0.62),
			Vector2(cx + hw, -20.0),
		])
		add_child(col)

func _process_crystal_cave(delta: float):
	_crystal_anim_time += delta

	# Ekrandan hızla geçen yarasaları güncelle
	for i in range(_active_bats.size() - 1, -1, -1):
		var b: Dictionary = _active_bats[i]
		b["x"] = float(b["x"]) + float(b["dir"]) * float(b["speed"]) * delta
		b["flap"] = float(b["flap"]) + float(b["flap_speed"]) * delta
		if (float(b["dir"]) > 0.0 and float(b["x"]) > 900.0) or (float(b["dir"]) < 0.0 and float(b["x"]) < -900.0):
			_active_bats.remove_at(i)

	queue_redraw()

	if is_instance_valid(_main_node) and _main_node.get("game_over") == true:
		return

	# 7 - 8 saniyede bir sağdan veya soldan birkaç yarasa uçur
	_bat_timer -= delta
	if _bat_timer <= 0.0:
		_bat_timer = randf_range(7.0, 8.0)
		_spawn_bat_flock()

	if spawn_stalactites and is_instance_valid(_main_node):
		_stalactite_timer -= delta
		if _stalactite_timer <= 0.0:
			_stalactite_timer = randf_range(stalactite_interval_min, stalactite_interval_max)
			_spawn_stalactite()
			if randf() < 0.35:
				_spawn_stalactite()

func _spawn_bat_flock():
	var dir: float
	if _bat_last_dir == 0.0:
		dir = 1.0 if randf() < 0.5 else -1.0
	else:
		# Sürekli aynı yönden gelmemesi için yönü değiştir
		dir = -_bat_last_dir
	_bat_last_dir = dir

	var count := randi_range(3, 5)
	var group_y := randf_range(-510.0, -250.0)
	var base_speed := randf_range(470.0, 560.0)
	for i in range(count):
		var start_x := (-680.0 - i * randf_range(28.0, 48.0)) if dir > 0.0 else (680.0 + i * randf_range(28.0, 48.0))
		_active_bats.append({
			"x": start_x,
			"y": group_y + randf_range(-34.0, 34.0),
			"dir": dir,
			"speed": base_speed + randf_range(-35.0, 45.0),
			"flap": randf() * TAU,
			"flap_speed": randf_range(24.0, 30.0),
			"scale": randf_range(0.85, 1.15),
		})

func _spawn_initial_stalactites():
	for start_y in [95.0, 260.0]:
		_spawn_stalactite(start_y)

func _spawn_stalactite(custom_start_y: float = -32.0):
	if not is_instance_valid(_main_node):
		return
	var stal := Node2D.new()
	stal.set_script(StalactiteScript)

	# Topun başlangıç konumu (x=150) dışında rastgele yatay konumdan sarkıt düşür
	var spawn_x := randf_range(260.0, 1045.0)
	stal.global_position = Vector2(spawn_x, custom_start_y)
	stal.fall_speed = randf_range(210.0, 265.0)
	stal.length_px = randf_range(40.0, 56.0)
	stal.half_width = randf_range(10.5, 14.5)
	stal.ball = _ball
	stal.main_node = _main_node
	_main_node.add_child(stal)

func _draw_crystal_cave_ground():
	# 1. Zeminden yükselen boyları değişken 4 adet kaya/kristal dikit
	for st in _get_stalagmites_data():
		var cx: float = st["x"]
		var hw: float = st["base_w"] * 0.5
		var h: float = st["height"]
		var c_col: Color = st["crystal"]

		# Dikit etrafındaki hafif kristal parıltısı
		draw_circle(Vector2(cx, -20.0 - h * 0.55), hw * 1.15, Color(c_col.r, c_col.g, c_col.b, 0.14))

		# Sol koyu kaya yüzeyi
		var left_face := PackedVector2Array([
			Vector2(cx - hw, -18.0),
			Vector2(cx - hw * 0.48, -20.0 - h * 0.62),
			Vector2(cx, -20.0 - h),
			Vector2(cx, -18.0),
		])
		draw_colored_polygon(left_face, Color("#121F36"))

		# Sağ aydınlık kaya yüzeyi
		var right_face := PackedVector2Array([
			Vector2(cx, -18.0),
			Vector2(cx, -20.0 - h),
			Vector2(cx + hw * 0.48, -20.0 - h * 0.62),
			Vector2(cx + hw, -18.0),
		])
		draw_colored_polygon(right_face, Color("#213659"))

		# Dikitin üst kristal ucu ve parlayan iç damarı
		var crystal_cap := PackedVector2Array([
			Vector2(cx - hw * 0.34, -20.0 - h * 0.58),
			Vector2(cx, -20.0 - h),
			Vector2(cx + hw * 0.34, -20.0 - h * 0.58),
			Vector2(cx, -20.0 - h * 0.32),
		])
		draw_colored_polygon(crystal_cap, c_col.darkened(0.15))

		var crystal_shine := PackedVector2Array([
			Vector2(cx, -20.0 - h),
			Vector2(cx + hw * 0.30, -20.0 - h * 0.58),
			Vector2(cx, -20.0 - h * 0.36),
		])
		draw_colored_polygon(crystal_shine, c_col.lightened(0.38))

		# Dikit gövdesindeki parlayan kristal çatlak çizgisi ve dış kontur
		draw_line(Vector2(cx, -20.0 - h), Vector2(cx - 2.0, -22.0), Color(c_col.r, c_col.g, c_col.b, 0.8), 1.8)
		var outline := PackedVector2Array([
			Vector2(cx - hw, -19.0),
			Vector2(cx - hw * 0.48, -20.0 - h * 0.62),
			Vector2(cx, -20.0 - h),
			Vector2(cx + hw * 0.48, -20.0 - h * 0.62),
			Vector2(cx + hw, -19.0),
		])
		draw_polyline(outline, Color("#09111F"), 2.0)

	# 2. Koyu lacivert-arduvaz mağara kaya zemini
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 200.0), Color("#0E1729"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 13.0), Color("#1A2B47"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 4.0), Color("#2B446E"))

	# Kaya blokları, taş katmanları ve çatlak detayları
	for i in range(42):
		var rx := -625.0 + i * 30.5
		var ry := -6.0 + sin(i * 4.7) * 7.0
		var rw := 16.0 + fmod(i * 5.3, 10.0)
		var rh := 7.0 + fmod(i * 3.1, 5.0)
		var rock_poly := PackedVector2Array([
			Vector2(rx - rw * 0.5, ry),
			Vector2(rx - rw * 0.3, ry - rh * 0.5),
			Vector2(rx + rw * 0.35, ry - rh * 0.45),
			Vector2(rx + rw * 0.5, ry + rh * 0.2),
			Vector2(rx, ry + rh * 0.5),
		])
		draw_colored_polygon(rock_poly, Color("#16253E") if i % 2 == 0 else Color("#203454"))
		draw_line(Vector2(rx - rw * 0.3, ry - rh * 0.5), Vector2(rx + rw * 0.35, ry - rh * 0.45), Color("#345280", 0.65), 1.4)

	# 3. Kaya zemin üzerinde ve içinde küçük parlayan kristaller
	var crystal_palette := [
		Color("#38F2E6"), # Turkuaz
		Color("#42A5FF"), # Mavi
		Color("#B84DFF"), # Mor / Ametist
		Color("#B8FAFF"), # Buz beyazı
	]
	for i in range(36):
		var kx := -618.0 + i * 35.0 + sin(i * 2.1) * 5.0
		var c_color: Color = crystal_palette[i % crystal_palette.size()]
		var pulse := 0.78 + 0.22 * sin(_crystal_anim_time * 3.2 + i * 1.4)

		if i % 2 == 0:
			# Zemin sırtından yukarı doğru çıkan küçük sivri kristal filizleri
			var ch := 6.5 + fmod(i * 3.7, 5.5)
			var cw := 3.4 + fmod(i * 1.9, 2.0)
			var tilt := sin(i * 5.1) * 2.2
			var shard := PackedVector2Array([
				Vector2(kx - cw, -19.0),
				Vector2(kx + tilt, -19.0 - ch),
				Vector2(kx + cw, -19.0),
				Vector2(kx, -16.5),
			])
			draw_circle(Vector2(kx + tilt * 0.5, -19.0 - ch * 0.5), ch * 0.85, Color(c_color.r, c_color.g, c_color.b, 0.20 * pulse))
			draw_colored_polygon(shard, c_color)
			draw_line(Vector2(kx + tilt, -19.0 - ch), Vector2(kx, -17.0), Color(1.0, 1.0, 1.0, 0.85 * pulse), 1.2)
		else:
			# Kaya içine gömülü parlayan küçük kristal cevherleri
			var ky := -4.0 + sin(i * 6.3) * 8.0
			var r := 3.2 + fmod(i * 2.3, 1.8)
			var gem := PackedVector2Array([
				Vector2(kx, ky - r),
				Vector2(kx + r * 1.1, ky),
				Vector2(kx, ky + r),
				Vector2(kx - r * 1.1, ky),
			])
			draw_circle(Vector2(kx, ky), r * 2.1, Color(c_color.r, c_color.g, c_color.b, 0.18 * pulse))
			draw_colored_polygon(gem, c_color)
			draw_circle(Vector2(kx - 0.6, ky - 0.6), r * 0.4, Color(1.0, 1.0, 1.0, 0.85 * pulse))

	# 4. Ekrandan hızla geçen küçük siyah kanatlı yarasalar
	var bat_col := Color("#080B12")
	for b in _active_bats:
		var bx := float(b["x"])
		var flap := float(b["flap"])
		var s := float(b["scale"])
		var by := float(b["y"]) + sin(flap * 0.35) * 4.5
		var pos := Vector2(bx, by)
		var wing_tip_y := sin(flap) * 8.0 * s
		var wing_mid_y := sin(flap - 0.5) * 4.5 * s

		# Küçük siyah gövde
		draw_circle(pos, 2.8 * s, bat_col)
		# Sol ve sağ çırpınan siyah kanatlar
		var left_wing := PackedVector2Array([
			pos + Vector2(-1.5 * s, -1.0 * s),
			pos + Vector2(-6.5 * s, wing_mid_y - 3.5 * s),
			pos + Vector2(-13.0 * s, wing_tip_y),
			pos + Vector2(-5.5 * s, wing_mid_y + 2.5 * s),
			pos + Vector2(-1.5 * s, 1.5 * s),
		])
		var right_wing := PackedVector2Array([
			pos + Vector2(1.5 * s, -1.0 * s),
			pos + Vector2(6.5 * s, wing_mid_y - 3.5 * s),
			pos + Vector2(13.0 * s, wing_tip_y),
			pos + Vector2(5.5 * s, wing_mid_y + 2.5 * s),
			pos + Vector2(1.5 * s, 1.5 * s),
		])
		draw_colored_polygon(left_wing, bat_col)
		draw_colored_polygon(right_wing, bat_col)

func _setup_swamp_colliders():
	# Sadece sol başlangıç bölgesi (-640 .. swamp_start_x) sert zemin olsun;
	# geri kalan sağ kısım tamamen bataklık olarak çalışsın.
	var left_col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if left_col:
		var safe_w := maxf(60.0, swamp_start_x - (-640.0))
		var left_rect := RectangleShape2D.new()
		left_rect.size = Vector2(safe_w, 40.0)
		left_col.shape = left_rect
		left_col.position = Vector2(-640.0 + safe_w * 0.5, 0.0)

func _process_swamp(delta: float):
	_swamp_time += delta
	if _ball_sinking:
		_sink_progress = move_toward(_sink_progress, 1.0, delta / 0.55)
	queue_redraw()

	if _ball_sinking or (is_instance_valid(_main_node) and _main_node.get("game_over") == true):
		return

	if not is_instance_valid(_ball) or _ball.freeze:
		return

	var current_shots := int(_main_node.get("shot_count")) if is_instance_valid(_main_node) else 0
	var local_ball := to_local(_ball.global_position)
	var surface_y := global_position.y - 20.0 # 610.0 (bataklık üst yüzeyi)
	var contact_y := surface_y - 15.0         # 595.0 (topun altının bataklığa değdiği nokta = %0 batma)
	var half_sunk_y := surface_y              # 610.0 (topun merkezinin yüzeye indiği nokta = %50 batma)

	# Kullanıcı bataklıktaki topu yukarı doğru fırlattıysa batma derinliğine göre direnç uygula
	if _ball_in_swamp and current_shots > _last_swamp_shot_count:
		_last_swamp_shot_count = current_shots
		if _ball.linear_velocity.y < -25.0:
			# 0.0 = yeni değdi, 1.0 = yarıya kadar (%50) battı
			var depth_ratio := clampf((_ball.global_position.y - contact_y) / (half_sunk_y - contact_y), 0.0, 1.0)
			var up_speed := -_ball.linear_velocity.y
			# Derine battıkça tek seferde kurtulmak için gereken dikey fırlatma gücü artar
			var required_up_speed := lerpf(240.0, 960.0, pow(depth_ratio, 0.85))

			if up_speed >= required_up_speed:
				# Yeterince güçlü çekildi: bataklıktan çıkar ama derinliğe göre hızının bir kısmını çamurda bırakır
				var keep_ratio := lerpf(0.76, 0.26, depth_ratio)
				_ball.linear_velocity *= keep_ratio
				_ball.global_position.y = minf(_ball.global_position.y, contact_y - 1.0)
				_ball_in_swamp = false
				_swamp_escape_timer = 0.22
				return
			else:
				# Güç tamamen çıkmaya yetmedi: top tek seferde kurtulamaz, sadece çamur içinde biraz yukarı yükselir
				var pull_progress := clampf(up_speed / maxf(1.0, required_up_speed), 0.15, 0.92)
				var lift_px := pull_progress * lerpf(8.5, 5.0, depth_ratio)
				_ball.global_position.y = maxf(contact_y + 0.4, _ball.global_position.y - lift_px)
				_ball.global_position.x += clampf(_ball.linear_velocity.x * 0.015, -10.0, 10.0)
				_ball.linear_velocity = Vector2(_ball.linear_velocity.x * 0.08, 0.0)
				_ball.angular_velocity *= 0.1
	else:
		_last_swamp_shot_count = current_shots

	if _swamp_escape_timer > 0.0:
		_swamp_escape_timer -= delta
		if _ball.global_position.y < contact_y - 1.5:
			return
		if _ball.linear_velocity.y < -15.0:
			return

	# Top ekran sınırları içindeki bataklık bölgesinde (swamp_start_x .. 635) ve bataklık yüzeyine indi mi?
	if local_ball.x > swamp_start_x + 4.0 and local_ball.x <= 635.0 and _ball.global_position.y >= contact_y - 0.5:
		if not _ball_in_swamp:
			_ball_in_swamp = true
			# Hızlı düşüşlerde ilk karede doğrudan dibe geçmemesi için yüzeyden başlat
			if _ball.global_position.y > contact_y + 1.5:
				_ball.global_position.y = contact_y + 0.5
			# Bataklığa girdiği anda topu çok yavaşlat ve sekmesini kes
			_ball.linear_velocity = Vector2(_ball.linear_velocity.x * 0.16, 0.0)
			_ball.angular_velocity *= 0.12

		# Bataklık içinde yatay hızı ve dönüşü hızla sönümle
		_ball.linear_velocity.x = move_toward(_ball.linear_velocity.x, 0.0, 280.0 * delta)
		_ball.angular_velocity = move_toward(_ball.angular_velocity, 0.0, 16.0 * delta)

		# Yerçekimini dengele ve yavaş, sabit hızla batır
		_ball.apply_central_force(Vector2(0.0, -980.0 * _ball.mass))
		var sink_spd: float = swamp_sink_speed if swamp_sink_speed != null else 5.0
		_ball.linear_velocity.y = sink_spd

		# Topun yarısından çoğu (%50'den fazlası) battıysa oyunu kaybettir
		if _ball.global_position.y > half_sunk_y + 0.5:
			_sink_ball_in_swamp(local_ball.x)
	else:
		_ball_in_swamp = false

func _sink_ball_in_swamp(hit_x: float):
	_ball_sinking = true
	_ball_in_swamp = false
	_sink_progress = 0.0
	_sink_local_x = hit_x

	if is_instance_valid(_main_node):
		_main_node.set("is_dragging", false)
		_main_node.queue_redraw()

	_ball.call_deferred("set_linear_velocity", Vector2.ZERO)
	_ball.call_deferred("set_angular_velocity", 0.0)
	_ball.call_deferred("set_freeze_enabled", true)

	var start_pos := _ball.global_position
	var sink_target := Vector2(start_pos.x, global_position.y + 16.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_ball, "global_position", sink_target, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_ball, "modulate", Color(0.35, 0.26, 0.18, 0.0), 0.48) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.chain().tween_callback(func():
		if is_instance_valid(_ball):
			_ball.hide()
		if is_instance_valid(_main_node) and _main_node.has_method("end_game"):
			_main_node.end_game(GameProgress.t("sunk_in_swamp"))
	)

func _draw_swamp_ground():
	var safe_w := maxf(60.0, swamp_start_x - (-640.0))
	var swamp_w := 640.0 - swamp_start_x

	# 1. SAĞ BATAKLIK BÖLGESİ (swamp_start_x .. 640)
	# Derin koyu bataklık çamuru
	draw_rect(Rect2(swamp_start_x, -20.0, swamp_w, 200.0), Color("#261A10"))
	draw_rect(Rect2(swamp_start_x, -20.0, swamp_w, 28.0), Color("#3D2A19"))
	draw_rect(Rect2(swamp_start_x, -20.0, swamp_w, 9.0), Color("#543B23"))
	draw_rect(Rect2(swamp_start_x, -20.0, swamp_w, 3.0), Color("#6B4C2E"))

	# Çamur içi koyu halkalar ve bataklık dokusu
	for i in range(28):
		var mx := swamp_start_x + 22.0 + i * 35.5
		var my := -6.0 + sin(i * 3.7) * 7.0
		var mw := 18.0 + fmod(i * 5.1, 12.0)
		draw_line(Vector2(mx - mw * 0.5, my), Vector2(mx + mw * 0.5, my), Color("#2E1F12", 0.8), 2.5)

	# Bataklık yüzeyindeki nilüfer yaprakları ve fokurdayan çamur kabarcıkları
	for i in range(14):
		var bx := swamp_start_x + 42.0 + i * 70.0
		var bob := sin(_swamp_time * 2.4 + i * 1.7) * 1.4
		if i % 3 == 0:
			# Nilüfer yaprağı
			draw_circle(Vector2(bx, -19.5 + bob * 0.4), 9.0, Color("#2D4F25"))
			draw_circle(Vector2(bx, -20.0 + bob * 0.4), 7.5, Color("#3E6B32"))
		else:
			# Parlak çamur kabarcığı (arka plandaki kabarcıklarla uyumlu)
			var br := 5.0 + fmod(i * 2.3, 4.0) + sin(_swamp_time * 3.2 + i) * 1.1
			draw_arc(Vector2(bx, -18.5), br + 3.0, 0.0, PI, 10, Color("#735334", 0.55), 1.4)
			draw_circle(Vector2(bx, -20.0 + bob), br, Color("#66482B"))
			draw_arc(Vector2(bx, -20.0 + bob), br, PI * 1.05, PI * 1.95, 10, Color("#8F6943"), 1.6)
			draw_circle(Vector2(bx + br * 0.32, -21.5 + bob), br * 0.26, Color("#FFF0C2", 0.85))

	# Top bataklıkta batarken etrafında oluşan çamur halkası
	if (_ball_in_swamp or _ball_sinking) and is_instance_valid(_ball):
		var bx := to_local(_ball.global_position).x
		draw_line(Vector2(bx - 20.0, -19.5), Vector2(bx + 20.0, -19.5), Color("#382515"), 4.0)
		draw_line(Vector2(bx - 16.0, -20.5), Vector2(bx + 16.0, -20.5), Color("#7D5A38"), 2.2)

	# 2. SOL GÜVENLİ BAŞLANGIÇ TOPRAĞI (-640 .. swamp_start_x)
	draw_rect(Rect2(-640.0, -20.0, safe_w, 200.0), Color("#1F1712"))
	draw_rect(Rect2(-640.0, -20.0, safe_w, 10.0), Color("#243D26"))
	draw_rect(Rect2(-640.0, -20.0, safe_w, 3.5), Color("#3B613B"))

	# Başlangıç kıyısındaki eğimli kök/toprak geçişi
	var bank_edge := PackedVector2Array([
		Vector2(swamp_start_x - 10.0, -20.0),
		Vector2(swamp_start_x + 6.0, -18.0),
		Vector2(swamp_start_x + 14.0, 8.0),
		Vector2(swamp_start_x - 4.0, 50.0),
		Vector2(swamp_start_x - 10.0, 90.0),
	])
	draw_colored_polygon(bank_edge, Color("#1F1712"))
	draw_polyline(bank_edge, Color("#3B613B", 0.85), 2.2)

	# Sol güvenli zemin üzerindeki bataklık otları ve sazlıklar
	for i in range(30):
		var gx := -632.0 + i * 8.4
		if gx > swamp_start_x - 4.0:
			break
		var gh := 3.5 + absf(sin(i * 9.3)) * 5.5
		draw_line(Vector2(gx, -20.0), Vector2(gx + 1.5, -20.0 - gh), Color("#3B613B"), 2.0)

func _draw_atlantis_ground():
	# 1. Derin okyanus tabanı kaya ve turkuaz deniz kumu katmanları
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 200.0), Color("#082942"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 26.0), Color("#0F4568"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 11.0), Color("#1C6D91"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 3.5), Color("#4EC5DE"))

	# 2. Antik Atlantis mermer / taş döşeme blokları ve derz çizgileri
	for i in range(20):
		var bx := -632.0 + i * 64.0
		var bw := 58.0
		var block_rect := Rect2(bx, -20.0, bw, 11.0)
		var block_col := Color("#2380A3") if i % 2 == 0 else Color("#1B698A")
		draw_rect(block_rect, block_col)
		# Mermer üst ışık yansıması
		draw_line(Vector2(bx + 2.0, -19.0), Vector2(bx + bw - 2.0, -19.0), Color("#7CE2F5", 0.85), 2.0)
		# Antik taş çatlakları
		if i % 3 == 0:
			draw_line(Vector2(bx + 18.0, -20.0), Vector2(bx + 24.0, -12.0), Color("#0B3552"), 1.6)
		# Mermer blok üzerindeki deniz yosunu örtüsü
		if i % 2 == 1:
			draw_rect(Rect2(bx + 8.0, -20.0, 26.0, 4.0), Color("#1E754B"))
			draw_line(Vector2(bx + 10.0, -20.0), Vector2(bx + 32.0, -20.0), Color("#38A869"), 2.0)

	# 3. Deniz tabanı çakıl taşları ve su altı kum dalgaları
	for i in range(44):
		var sx := -625.0 + i * 29.0
		var sy := -2.0 + sin(i * 5.7) * 7.5
		draw_circle(Vector2(sx, sy), 2.4, Color("#16587D") if i % 2 == 0 else Color("#0B3552"))

	# 4. Zemin üzerinde dalgalanan deniz yosunları ve renkli mercanlar (arka planla uyumlu)
	var coral_colors := [
		Color("#E86B8C"), # Pembe mercan
		Color("#F28C38"), # Turuncu mercan
		Color("#F5B841"), # Sarı-altın mercan
	]
	for i in range(32):
		var kx := -618.0 + i * 39.5
		var sway := sin(_atlantis_time * 2.2 + i * 0.9) * 3.2

		if i % 3 == 0:
			# Küçük renkli mercan dalları
			var c_col: Color = coral_colors[(i / 3) % coral_colors.size()]
			var base_pt := Vector2(kx, -19.5)
			draw_line(base_pt, base_pt + Vector2(-4.5 + sway * 0.3, -9.0), c_col, 2.6)
			draw_line(base_pt, base_pt + Vector2(0.5 + sway * 0.4, -12.0), c_col, 2.8)
			draw_line(base_pt, base_pt + Vector2(5.0 + sway * 0.3, -8.5), c_col, 2.6)
			draw_circle(base_pt + Vector2(0.5 + sway * 0.4, -12.0), 2.0, c_col.lightened(0.25))
		else:
			# Su akıntısıyla sallanan yeşil deniz yosunu yaprakları
			var kh := 8.0 + fmod(i * 3.7, 7.0)
			var k_col := Color("#1E7A4C") if i % 2 == 0 else Color("#2EA364")
			var mid_pt := Vector2(kx + sway * 0.5, -20.0 - kh * 0.5)
			var tip_pt := Vector2(kx + sway, -20.0 - kh)
			draw_line(Vector2(kx, -19.5), mid_pt, k_col, 2.6)
			draw_line(mid_pt, tip_pt, k_col.lightened(0.15), 2.0)

	# 5. Deniz tabanından hafifçe yükselen minik su kabarcıkları
	for i in range(10):
		var bx := -560.0 + i * 122.0
		var cycle := fmod(_atlantis_time * 18.0 + i * 11.0, 26.0)
		var by := -21.0 - cycle
		var alpha := clampf(1.0 - (cycle / 26.0), 0.0, 1.0) * 0.65
		draw_arc(Vector2(bx + sin(_atlantis_time * 3.0 + i) * 2.5, by), 2.5, 0.0, TAU, 10, Color(0.68, 0.95, 1.0, alpha), 1.3)

func _draw_cyber_city_ground():
	# 1. Ana ıslak siber asfalt ve kaldırım tabanı (arka plandaki koyu lacivert/indigo sokakla uyumlu)
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 200.0), Color("#0A0F24"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 32.0), Color("#111A3A"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 10.0), Color("#192752"))

	# 2. Sol ve sağ kaldırım blokları + dükkan neon yansımaları (Sol: Camgöbeği & Pembe, Sağ: Pembe & Neon Yeşil)
	draw_rect(Rect2(-640.0, -20.0, 300.0, 26.0), Color("#152246"))
	draw_rect(Rect2(340.0, -20.0, 300.0, 26.0), Color("#152246"))

	# Sol kaldırım neon yansımaları (camgöbeği ve pembe vitrin ışıkları)
	draw_rect(Rect2(-625.0, -18.0, 145.0, 7.0), Color(0.08, 0.90, 1.0, 0.32))
	draw_rect(Rect2(-465.0, -18.0, 115.0, 7.0), Color(0.98, 0.22, 0.82, 0.30))
	# Sağ kaldırım neon yansımaları (pembe ve sağdaki yeşil dükkan ışığı)
	draw_rect(Rect2(350.0, -18.0, 115.0, 7.0), Color(0.98, 0.22, 0.82, 0.30))
	draw_rect(Rect2(480.0, -18.0, 145.0, 7.0), Color(0.20, 1.0, 0.38, 0.34))

	# 3. Orta ıslak cadde üzerinde neon su birikintisi yansımaları (puddles)
	var puddles := [
		{"x": -520.0, "y": 14.0, "w": 130.0, "h": 8.0, "col": Color("#14E8FF")},
		{"x": -350.0, "y": 24.0, "w": 110.0, "h": 7.0, "col": Color("#FF36C8")},
		{"x": -185.0, "y": 10.0, "w": 140.0, "h": 9.0, "col": Color("#14E8FF")},
		{"x": 45.0, "y": 16.0, "w": 145.0, "h": 9.0, "col": Color("#FF36C8")},
		{"x": 235.0, "y": 26.0, "w": 115.0, "h": 7.0, "col": Color("#14E8FF")},
		{"x": 475.0, "y": 14.0, "w": 135.0, "h": 8.0, "col": Color("#2BFF4E")},
	]
	for i in range(puddles.size()):
		var p: Dictionary = puddles[i]
		var px: float = p["x"]
		var py: float = p["y"]
		var pw: float = p["w"]
		var ph: float = p["h"]
		var pcol: Color = p["col"]
		var shimmer := 0.22 + 0.08 * sin(_cyber_time * 3.0 + i * 1.3)
		draw_rect(Rect2(px - pw * 0.5, py, pw, ph), Color(pcol.r, pcol.g, pcol.b, shimmer))
		draw_line(
			Vector2(px - pw * 0.38, py + ph * 0.5),
			Vector2(px + pw * 0.38, py + ph * 0.5),
			Color(1.0, 1.0, 1.0, shimmer * 1.4),
			1.6
		)

	# 4. Kaldırım taş derzleri ve siber ızgara (grid) perspektif çizgileri
	for i in range(21):
		var gx := -640.0 + i * 64.0
		var slant := (gx / 640.0) * 28.0
		draw_line(Vector2(gx, -20.0), Vector2(gx + slant, 90.0), Color("#23366E", 0.55), 1.5)

	# 5. Cadde ortası perspektif şerit çizgisi ve siber devre hatları
	var center_stripe := PackedVector2Array([
		Vector2(-7.0, -19.0),
		Vector2(7.0, -19.0),
		Vector2(14.0, 90.0),
		Vector2(-14.0, 90.0),
	])
	draw_colored_polygon(center_stripe, Color(0.45, 0.82, 1.0, 0.28))
	draw_line(Vector2(-340.0, -19.0), Vector2(-430.0, 90.0), Color("#18E8FF", 0.55), 2.2)
	draw_line(Vector2(340.0, -19.0), Vector2(430.0, 90.0), Color("#FF36C8", 0.55), 2.2)

	# 6. Üst zemin sınırında (y = -20) kesintisiz parlayan neon bordür hattı ve akan veri ışıkları
	draw_line(Vector2(-640.0, -19.0), Vector2(-210.0, -19.0), Color("#14E8FF", 0.90), 3.0)
	draw_line(Vector2(-210.0, -19.0), Vector2(260.0, -19.0), Color("#FF38C8", 0.90), 3.0)
	draw_line(Vector2(260.0, -19.0), Vector2(640.0, -19.0), Color("#2BFF58", 0.90), 3.0)
	draw_line(Vector2(-640.0, -20.0), Vector2(640.0, -20.0), Color(0.88, 0.97, 1.0, 0.75), 1.2)

	# Zemin altındaki siber devre hattı boyunca akan parlak enerji paketleri
	draw_line(Vector2(-640.0, -6.0), Vector2(640.0, -6.0), Color("#1F3166"), 2.0)
	for i in range(8):
		var pulse_x := -640.0 + fmod(_cyber_time * 140.0 + i * 160.0, 1280.0)
		var p_col := Color("#14E8FF") if i % 2 == 0 else Color("#FF38C8")
		if pulse_x > 280.0:
			p_col = Color("#2BFF58")
		draw_line(Vector2(pulse_x - 16.0, -6.0), Vector2(pulse_x + 16.0, -6.0), p_col, 2.8)
		draw_circle(Vector2(pulse_x, -6.0), 3.0, Color.WHITE)

func _draw_rusty_factory_ground():
	# 1. Ana endüstriyel beton ve isli fabrika zemini katmanları (arka plandaki avluya uyumlu)
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 200.0), Color("#14110F"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 44.0), Color("#26211D"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 16.0), Color("#362E28"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 5.0), Color("#4A3E35"))

	# 2. Sol ve sağ bina önlerindeki sarı/amber fabrika fenerlerinin zemindeki sıcak yansımaları
	var glow_flicker := 0.24 + 0.05 * sin(_factory_time * 4.2)
	draw_rect(Rect2(-415.0, -18.0, 195.0, 14.0), Color(0.90, 0.48, 0.14, glow_flicker))
	draw_rect(Rect2(-380.0, -16.0, 125.0, 8.0), Color(0.98, 0.65, 0.22, glow_flicker * 0.85))
	draw_rect(Rect2(190.0, -18.0, 250.0, 14.0), Color(0.90, 0.48, 0.14, glow_flicker))
	draw_rect(Rect2(230.0, -16.0, 160.0, 8.0), Color(0.98, 0.65, 0.22, glow_flicker * 0.85))

	# 3. Zemindeki pas lekeleri, oksitlenmiş metal plakalar ve koyu makine yağı birikintileri
	var rust_patches := [
		{"x": -560.0, "y": -8.0, "w": 115.0, "h": 12.0, "col": Color("#6E371B")},
		{"x": -340.0, "y": 4.0, "w": 140.0, "h": 14.0, "col": Color("#7D3E1E")},
		{"x": -135.0, "y": -6.0, "w": 125.0, "h": 11.0, "col": Color("#633118")},
		{"x": 45.0, "y": 6.0, "w": 150.0, "h": 15.0, "col": Color("#7A3D1D")},
		{"x": 265.0, "y": -7.0, "w": 130.0, "h": 12.0, "col": Color("#874420")},
		{"x": 470.0, "y": 3.0, "w": 120.0, "h": 13.0, "col": Color("#6B351A")},
	]
	for i in range(rust_patches.size()):
		var rp: Dictionary = rust_patches[i]
		var rx: float = rp["x"]
		var ry: float = rp["y"]
		var rw: float = rp["w"]
		var rh: float = rp["h"]
		var rcol: Color = rp["col"]
		draw_rect(Rect2(rx, ry, rw, rh), Color(rcol.r, rcol.g, rcol.b, 0.65))
		draw_rect(Rect2(rx + 12.0, ry + 2.0, rw * 0.6, rh * 0.5), rcol.lightened(0.16))

	# Koyu makine yağı birikintileri (oil puddles)
	var oil_puddles := [
		Vector2(-210.0, 16.0),
		Vector2(-20.0, 12.0),
		Vector2(175.0, 18.0),
		Vector2(395.0, 15.0),
	]
	for i in range(oil_puddles.size()):
		var op: Vector2 = oil_puddles[i]
		draw_rect(Rect2(op.x - 42.0, op.y, 84.0, 7.0), Color("#0C0A09", 0.85))
		draw_line(Vector2(op.x - 26.0, op.y + 2.5), Vector2(op.x + 22.0, op.y + 2.5), Color("#59493B", 0.55), 1.5)

	# 4. Üst yüzey boyunca perçinli ağır çelik fabrika kirişi ve paslı demir plakalar (-20 .. -9)
	for i in range(16):
		var px: float = -640.0 + i * 80.0
		var pw: float = 78.0
		var plate_col := Color("#3D332C") if i % 2 == 0 else Color("#47392F")
		draw_rect(Rect2(px, -20.0, pw, 11.0), plate_col)
		# Plaka üzerindeki paslanma izi
		if i % 3 != 0:
			var rust_w: float = 28.0 + fmod(i * 11.0, 24.0)
			draw_rect(Rect2(px + 8.0, -19.0, rust_w, 6.0), Color("#7A3E1D", 0.72))
		# Üst metalik aşınma parlaması
		draw_line(Vector2(px + 2.0, -19.2), Vector2(px + pw - 2.0, -19.2), Color("#8C735B", 0.75), 1.6)
		# Alt gölge ve plaka derzi
		draw_line(Vector2(px, -9.0), Vector2(px + pw, -9.0), Color("#171310"), 2.0)
		# Plakanın sol ve sağ perçin çivileri (rivets)
		draw_circle(Vector2(px + 6.0, -14.5), 2.0, Color("#211B17"))
		draw_circle(Vector2(px + 5.5, -15.0), 1.3, Color("#78624E"))
		draw_circle(Vector2(px + pw - 6.0, -14.5), 2.0, Color("#211B17"))
		draw_circle(Vector2(px + pw - 6.5, -15.0), 1.3, Color("#78624E"))

	# 5. Sol ve sağ yükleme rampası kenarlarında aşınmış sarı-siyah endüstriyel uyarı şeritleri
	for side_idx in range(2):
		var base_x: float = -620.0 if side_idx == 0 else 440.0
		draw_rect(Rect2(base_x, -9.0, 180.0, 8.0), Color("#1C1815"))
		for s in range(9):
			var sx: float = base_x + 4.0 + s * 20.0
			var stripe_poly := PackedVector2Array([
				Vector2(sx, -9.0),
				Vector2(sx + 10.0, -9.0),
				Vector2(sx + 6.0, -1.0),
				Vector2(sx - 4.0, -1.0),
			])
			draw_colored_polygon(stripe_poly, Color("#B88228", 0.70))

	# 6. Zemin altına gömülü eski fabrika boruları ve vana ızgaraları
	draw_rect(Rect2(-640.0, 26.0, 1280.0, 10.0), Color("#2B221C"))
	draw_line(Vector2(-640.0, 27.5), Vector2(640.0, 27.5), Color("#5E4330", 0.75), 2.0)
	draw_line(Vector2(-640.0, 35.5), Vector2(640.0, 35.5), Color("#0E0B09", 0.90), 2.0)
	for i in range(11):
		var fx: float = -560.0 + i * 112.0
		draw_rect(Rect2(fx - 4.0, 24.0, 8.0, 14.0), Color("#4A3525"))
		draw_line(Vector2(fx - 4.0, 24.0), Vector2(fx + 4.0, 24.0), Color("#7D5638"), 1.6)

	# 7. Buhar mazgallarından hafifçe tüten endüstriyel duman/buhar (arka plandaki bacalarla uyumlu)
	var vents := [-450.0, -110.0, 120.0, 420.0]
	for i in range(vents.size()):
		var vx: float = vents[i]
		# Mazgal ızgarası
		draw_rect(Rect2(vx - 16.0, -20.0, 32.0, 5.0), Color("#14110E"))
		for g in range(5):
			var gx: float = vx - 12.0 + g * 6.0
			draw_line(Vector2(gx, -20.0), Vector2(gx, -15.0), Color("#524338"), 1.5)
		# Yükselen hafif buhar halkaları
		for p in range(2):
			var cycle: float = fmod(_factory_time * 14.0 + i * 9.0 + p * 13.0, 26.0)
			var sy: float = -22.0 - cycle
			var sx: float = vx + sin(_factory_time * 2.4 + i + p) * 4.0
			var alpha: float = clampf(1.0 - (cycle / 26.0), 0.0, 1.0) * 0.28
			draw_circle(Vector2(sx, sy), 3.5 + cycle * 0.18, Color(0.76, 0.71, 0.64, alpha))

func _draw_black_hole_ground():
	# 1. Zifiri kozmik siyah obsidyen gövde (arka plandan net ayrışan koyu katmanlar)
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 200.0), Color("#050408"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 38.0), Color("#0C0914"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 14.0), Color("#151024"))
	draw_rect(Rect2(-640.0, -20.0, 1280.0, 5.0), Color("#231A3A"))

	# 2. Üst yüzey boyunca koyu obsidyen-bazalt kaya plakaları (oyuncunun zemini rahatça seçmesi için)
	for i in range(16):
		var bx: float = -640.0 + float(i) * 80.0
		var bw: float = 78.0
		var slab_col := Color("#181229") if i % 2 == 0 else Color("#120E20")
		draw_rect(Rect2(bx, -20.0, bw, 12.0), slab_col)
		# Plaka derzi ve iç koyu çatlak izi
		draw_line(Vector2(bx, -8.0), Vector2(bx + bw, -8.0), Color("#07050D"), 2.0)
		if i % 3 == 0:
			draw_line(Vector2(bx + 22.0, -19.0), Vector2(bx + 34.0, -10.0), Color("#2E224D", 0.75), 1.5)

	# 3. Zemin sınırını oyuncuya net gösteren olay ufku (event horizon) üst kontur parıltısı
	draw_line(Vector2(-640.0, -20.0), Vector2(640.0, -20.0), Color("#56428A", 0.92), 2.6)
	draw_line(Vector2(-640.0, -19.2), Vector2(640.0, -19.2), Color("#9E82E8", 0.55), 1.2)

	# Arka plandaki sarı/kehribar ve mor kara delik diskleriyle uyumlu hafif ufuk yansımaları
	for i in range(8):
		var gx: float = -540.0 + float(i) * 154.0
		var pulse: float = 0.25 + 0.12 * sin(_void_time * 2.2 + float(i) * 1.1)
		var g_col := Color("#D99B4E", pulse) if i % 2 == 0 else Color("#8A64D6", pulse)
		draw_line(Vector2(gx - 38.0, -19.5), Vector2(gx + 38.0, -19.5), g_col, 2.2)

	# 4. Siyah zemin içinde hafifçe parıldayan kozmik yıldız tozu zerreleri
	for i in range(28):
		var sx: float = -615.0 + float(i) * 45.5
		var sy: float = -4.0 + sin(float(i) * 6.3) * 14.0
		var tw: float = 0.22 + 0.18 * sin(_void_time * 2.8 + float(i) * 1.7)
		var scol := Color(0.75, 0.65, 0.98, tw) if i % 3 != 0 else Color(0.95, 0.78, 0.50, tw)
		draw_circle(Vector2(sx, sy), 1.5, scol)
