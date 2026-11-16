extends Node2D
## Yanardağdan patlayıp yavaşça süzülerek düşen kor lav kayası.
## Top havada veya hareket halindeyken çarparsa topun yönünü değiştirir.

var velocity := Vector2(0.0, 140.0)
var rot_speed := 1.6
var rock_radius := 19.0
var _hit_ball := false
var _shattering := false
var _shatter_time := 0.0
var _shape_points := PackedVector2Array()
var _crack_points := PackedVector2Array()
var _rot_angle := 0.0
var _pulse_time := 0.0

var ball: RigidBody2D = null
var main_node: Node2D = null

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rot_angle = randf() * TAU
	_pulse_time = randf() * 10.0

	# Düzensiz volkanik kaya çokgeni oluştur
	var vertex_count := 8
	for i in range(vertex_count):
		var a := (TAU / vertex_count) * i
		var r := rock_radius * randf_range(0.78, 1.12)
		_shape_points.append(Vector2(cos(a), sin(a)) * r)

	# İç magma çatlak noktaları
	for i in range(4):
		var a := (TAU / 4.0) * i + randf_range(-0.3, 0.3)
		_crack_points.append(Vector2(cos(a), sin(a)) * (rock_radius * 0.62))

func _physics_process(delta: float):
	_pulse_time += delta * 6.0

	if _shattering:
		_shatter_time += delta
		modulate.a = clampf(1.0 - (_shatter_time / 0.25), 0.0, 1.0)
		global_position += velocity * delta * 0.4
		queue_redraw()
		if _shatter_time >= 0.25:
			queue_free()
		return

	# Belirlenen açıyı (45°-135°) bozmadan sabit hızla ilerle
	global_position += velocity * delta
	_rot_angle += rot_speed * delta

	if global_position.x < -80.0 or global_position.x > 1360.0:
		queue_free()
		return

	# Top ile çarpışma kontrolü (top fırlatılmışsa ve oyun bitmemişse)
	if not _hit_ball and is_instance_valid(ball):
		var is_active_shot := true
		if is_instance_valid(main_node):
			if main_node.get("game_over") == true or int(main_node.get("shot_count")) == 0:
				is_active_shot = false

		if is_active_shot and ball.linear_velocity.length() > 15.0:
			var dist := global_position.distance_to(ball.global_position)
			var combined_r := rock_radius + 15.0
			if dist <= combined_r:
				_deflect_ball()
				return

	# Zemine ulaştığında parçalanarak kaybol
	if global_position.y >= 602.0:
		_start_shatter()
		return

	queue_redraw()

func _deflect_ball():
	_hit_ball = true
	var normal := (ball.global_position - global_position).normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.UP

	var ball_vel := ball.linear_velocity
	var speed := ball_vel.length()

	# Topu hızlandırmadan, hızını biraz kırarak yönünü saptır
	var deflected: Vector2
	if ball_vel.dot(normal) < 0.0:
		deflected = ball_vel.bounce(normal) * 0.58 + velocity * 0.18
	else:
		var new_dir := (ball_vel.normalized() + normal * 0.75).normalized()
		deflected = new_dir * (speed * 0.65) + velocity * 0.18

	# Çarpışma sonrası hız asla mevcut hızı geçmesin (hızlandırmasın)
	var max_allowed_speed := maxf(speed * 0.72, 130.0)
	deflected = deflected.limit_length(max_allowed_speed)

	ball.linear_velocity = deflected
	ball.angular_velocity += randf_range(-5.0, 5.0)

	# Kaya da çarpmanın etkisiyle ters yöne savrulup parçalansın
	velocity = -normal * 140.0
	_start_shatter()

func _start_shatter():
	_shattering = true
	_shatter_time = 0.0

func _draw():
	if _shattering:
		# Parçalanma kıvılcımları
		var t := _shatter_time / 0.25
		for i in range(6):
			var a := _rot_angle + i * (TAU / 6.0)
			var p := Vector2(cos(a), sin(a)) * (8.0 + t * 28.0)
			draw_circle(p, lerpf(6.0, 1.5, t), Color("#FF6A00"))
			draw_circle(p, lerpf(3.5, 0.8, t), Color("#FFE066"))
		return

	# Arkasında bıraktığı sıcak duman ve kor izi
	var trail_dir := -velocity.normalized()
	draw_circle(trail_dir * 14.0, rock_radius * 0.65, Color(1.0, 0.32, 0.05, 0.22))
	draw_circle(trail_dir * 25.0, rock_radius * 0.42, Color(1.0, 0.55, 0.1, 0.14))

	# Dış kor هاله (glow)
	var glow_alpha := 0.24 + sin(_pulse_time) * 0.06
	draw_circle(Vector2.ZERO, rock_radius * 1.28, Color(1.0, 0.3, 0.02, glow_alpha))

	# Kaya gövdesini döndürerek çiz
	var rotated_poly := PackedVector2Array()
	for pt in _shape_points:
		rotated_poly.append(pt.rotated(_rot_angle))

	draw_colored_polygon(rotated_poly, Color("#2A171B"))

	# Kaya dış konturu (kızgın turuncu-kırmızı kenar)
	var outline := rotated_poly.duplicate()
	outline.append(rotated_poly[0])
	draw_polyline(outline, Color("#FF4D00", 0.85), 2.2)

	# İç lav çatlakları ve kor merkez
	for cpt in _crack_points:
		var rpt := cpt.rotated(_rot_angle)
		draw_line(Vector2.ZERO, rpt, Color("#FF7B00"), 2.6)
		draw_line(Vector2.ZERO, rpt * 0.65, Color("#FFF078"), 1.4)

	draw_circle(Vector2.ZERO, 4.2, Color("#FFAE00"))
	draw_circle(Vector2.ZERO, 2.2, Color("#FFF7B2"))
