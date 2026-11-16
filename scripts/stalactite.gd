extends Node2D
## Mağara tavanından kopup dikey olarak düşen doğal kaya sarkıt.
## Top hareket halindeyken çarparsa topun yönünü saptırır ve parçalanır.

var fall_speed: float = 240.0
var fall_accel: float = 160.0
var length_px: float = 46.0
var half_width: float = 12.0
var _hit_ball: bool = false
var _shattering: bool = false
var _shatter_time: float = 0.0
var _shards: Array = []

var ball: RigidBody2D = null
var main_node: Node2D = null

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _physics_process(delta: float):
	if _shattering:
		_shatter_time += delta
		modulate.a = clampf(1.0 - (_shatter_time / 0.28), 0.0, 1.0)
		queue_redraw()
		if _shatter_time >= 0.28:
			queue_free()
		return

	fall_speed = minf(fall_speed + fall_accel * delta, 380.0)
	global_position.y += fall_speed * delta

	# Top ile çarpışma kontrolü (top fırlatılmışsa ve oyun bitmemişse)
	if not _hit_ball and is_instance_valid(ball):
		var is_active_shot := true
		if is_instance_valid(main_node):
			if main_node.get("game_over") == true or int(main_node.get("shot_count")) == 0:
				is_active_shot = false

		if is_active_shot and ball.linear_velocity.length() > 12.0:
			# Sarkıtın dikey gövdesi (y - length*0.5 .. y + length*0.5) ile topun mesafesini ölç
			var closest_y := clampf(ball.global_position.y, global_position.y - length_px * 0.45, global_position.y + length_px * 0.48)
			var closest_pt := Vector2(global_position.x, closest_y)
			var dist := closest_pt.distance_to(ball.global_position)
			if dist <= half_width + 14.0:
				_deflect_ball(closest_pt)
				return

	# Zemine ulaştığında parçalanarak kaybol
	if global_position.y + length_px * 0.45 >= 608.0:
		_start_shatter()
		return

	queue_redraw()

func _deflect_ball(contact_pt: Vector2):
	_hit_ball = true
	var normal := (ball.global_position - contact_pt).normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.DOWN

	var ball_vel := ball.linear_velocity
	var speed := ball_vel.length()

	var deflected: Vector2
	if ball_vel.dot(normal) < 0.0:
		deflected = ball_vel.bounce(normal) * 0.62 + Vector2(0.0, fall_speed * 0.22)
	else:
		var new_dir := (ball_vel.normalized() + normal * 0.75).normalized()
		deflected = new_dir * (speed * 0.68) + Vector2(0.0, fall_speed * 0.22)

	var max_allowed_speed := maxf(speed * 0.75, 140.0)
	deflected = deflected.limit_length(max_allowed_speed)

	ball.linear_velocity = deflected
	ball.angular_velocity += randf_range(-5.5, 5.5)

	_start_shatter()

func _start_shatter():
	_shattering = true
	_shatter_time = 0.0
	_shards.clear()
	for i in range(7):
		var a := randf_range(-PI * 0.9, -PI * 0.1) if i < 4 else randf_range(0.0, TAU)
		_shards.append({
			"dir": Vector2(cos(a), sin(a)) * randf_range(22.0, 52.0),
			"size": randf_range(3.0, 6.0),
			"light": i % 2 == 0,
		})

func _draw():
	if _shattering:
		var t := _shatter_time / 0.28
		for s in _shards:
			var p: Vector2 = s["dir"] * t
			var r: float = lerpf(s["size"], 1.2, t)
			draw_circle(p, r, Color("#3A4659") if s["light"] else Color("#1D2636"))
		return

	var top_y := -length_px * 0.5
	var bot_y := length_px * 0.5
	var hw := half_width

	# Ana doğal kaya sarkıt gövdesi (sol koyu taş yüzeyi ve sağ orta-açık taş yüzeyi)
	var left_rock := PackedVector2Array([
		Vector2(-hw, top_y),
		Vector2(0.0, top_y - 3.0),
		Vector2(0.0, bot_y),
		Vector2(-hw * 0.58, bot_y * 0.22),
	])
	draw_colored_polygon(left_rock, Color("#1D2533"))

	var right_rock := PackedVector2Array([
		Vector2(0.0, top_y - 3.0),
		Vector2(hw, top_y),
		Vector2(hw * 0.58, bot_y * 0.22),
		Vector2(0.0, bot_y),
	])
	draw_colored_polygon(right_rock, Color("#2F3B4F"))

	# Üst kaya katmanı ve taş boğumları
	var upper_band := PackedVector2Array([
		Vector2(-hw * 0.85, top_y + 4.0),
		Vector2(0.0, top_y + 1.0),
		Vector2(hw * 0.85, top_y + 4.0),
		Vector2(hw * 0.68, top_y + 13.0),
		Vector2(0.0, top_y + 16.0),
		Vector2(-hw * 0.68, top_y + 13.0),
	])
	draw_colored_polygon(upper_band, Color("#263042"))

	# Kaya sırt çizgisi, taş çatlakları ve dış kontur
	draw_line(Vector2(0.0, top_y - 2.0), Vector2(0.0, bot_y), Color("#465670", 0.85), 1.4)
	draw_line(Vector2(-hw * 0.55, top_y + 10.0), Vector2(hw * 0.35, top_y + 15.0), Color("#141A24", 0.8), 1.3)
	draw_line(Vector2(hw * 0.45, 0.0), Vector2(-hw * 0.25, bot_y * 0.35), Color("#141A24", 0.8), 1.2)

	var outline := PackedVector2Array([
		Vector2(-hw, top_y),
		Vector2(0.0, top_y - 3.0),
		Vector2(hw, top_y),
		Vector2(hw * 0.58, bot_y * 0.22),
		Vector2(0.0, bot_y),
		Vector2(-hw * 0.58, bot_y * 0.22),
		Vector2(-hw, top_y),
	])
	draw_polyline(outline, Color("#0E131C"), 1.8)
