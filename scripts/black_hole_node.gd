@tool
extends Area2D
## Sahneye Target ve Ball gibi yerleştirilebilen yuvarlak Kara Delik engeli.
## Büyüklüğüne (scale) göre topa uyguladığı çekim alanı ve çekim kuvveti artar;
## top olay ufkuna girerse topu yutar ve oyunu bitirir.

const GameProgress := preload("res://scripts/game_progress.gd")

@export var main_color: Color = Color("#FF6B2B"):
	set(value):
		main_color = value
		queue_redraw()
@export var light_color: Color = Color("#FFD194"):
	set(value):
		light_color = value
		queue_redraw()
@export var glow_color: Color = Color("#FFB066"):
	set(value):
		glow_color = value
		queue_redraw()
@export var core_color: Color = Color("#09020F"):
	set(value):
		core_color = value
		queue_redraw()

## Ölçek 1.0 iken çekim alanının yarıçapı (piksel). Kara delik büyüdükçe (scale) bu alan da büyür.
@export var base_pull_radius: float = 235.0
## Ölçek 1.0 iken temel çekim kuvveti. Kara delik büyüdükçe çekim gücü katlanarak artar.
@export var base_gravity_force: float = 540.0
## Topun içine çekilme süresi (saniye)
@export var pull_duration: float = 1.15
## Topun içine çekilirken etrafında kaç tur döneceği
@export var pull_turns: float = 1.5
@export var spin_speed: float = 2.2
@export var particle_count: int = 16

var time: float = 0.0
var swirl_angle: float = 0.0
var absorbing: bool = false
var flash: float = 0.0
var particles: Array = []
var _ball: RigidBody2D = null
var _main_node: Node2D = null
var _pulling_ball: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	particles.clear()
	for i in range(particle_count):
		particles.append(_new_particle(14.0 + float(i) * (36.0 / float(max(particle_count, 1)))))

	if Engine.is_editor_hint():
		queue_redraw()
		return

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_main_node = get_parent() as Node2D
	if _main_node:
		_ball = _main_node.get_node_or_null("Ball") as RigidBody2D
	queue_redraw()

func _new_particle(radius: float) -> Dictionary:
	return {
		"angle": randf() * TAU,
		"radius": radius,
		"speed": randf_range(10.0, 22.0),
		"size": randf_range(1.2, 2.4),
	}

func _get_size_factor() -> float:
	return maxf(0.25, (absf(scale.x) + absf(scale.y)) * 0.5)

func _process(delta: float):
	if Engine.is_editor_hint():
		return

	var speed_mult := 3.5 if absorbing else 1.0
	time += delta
	swirl_angle += delta * spin_speed * speed_mult

	for i in range(particles.size()):
		var p: Dictionary = particles[i]
		p["radius"] = float(p["radius"]) - float(p["speed"]) * delta * speed_mult
		p["angle"] = float(p["angle"]) + delta * (60.0 / maxf(float(p["radius"]), 6.0)) * speed_mult
		if float(p["radius"]) < 12.0:
			p = _new_particle(randf_range(44.0, 52.0))
		particles[i] = p

	queue_redraw()

func _physics_process(_delta: float):
	if Engine.is_editor_hint() or absorbing:
		_pulling_ball = false
		return

	if not is_instance_valid(_main_node) or not is_instance_valid(_ball):
		_pulling_ball = false
		return

	if _main_node.get("game_over") == true or _main_node.get("cutscene_active") == true:
		_pulling_ball = false
		return

	var target_node := _main_node.get_node_or_null("Target")
	if target_node and target_node.get("completed") == true:
		_pulling_ball = false
		return

	# Top henüz fırlatılmadıysa çekim uygulama
	if int(_main_node.get("shot_count")) <= 0 or not bool(_main_node.get("ball_in_flight")) or _ball.freeze:
		_pulling_ball = false
		return

	var size_factor := _get_size_factor()
	var to_center := global_position - _ball.global_position
	var dist := to_center.length()

	# 1. Yutma yarıçapı (büyüklüğe göre ölçeklenir)
	var capture_radius := 28.0 * size_factor
	if dist <= capture_radius:
		_swallow_ball(_ball)
		return

	# 2. Büyüklüğe göre ölçeklenen kütleçekim alanı ve çekim kuvveti
	var pull_radius := base_pull_radius * size_factor
	if dist < pull_radius and dist > 0.001:
		_pulling_ball = true
		var dir := to_center / dist
		var proximity := clampf(1.0 - (dist / pull_radius), 0.0, 1.0)
		# Kara deliğin büyüklüğü arttıkça çekim gücü belirgin şekilde (size_factor^1.75) artar
		var size_power := pow(size_factor, 1.75)
		var force_mag := base_gravity_force * size_power * (0.38 + 1.95 * proximity * proximity)
		_ball.apply_central_force(dir * force_mag)
	else:
		_pulling_ball = false

func _on_body_entered(body: Node):
	if Engine.is_editor_hint() or absorbing:
		return
	if body is RigidBody2D and body.name == "Ball":
		_swallow_ball(body as RigidBody2D)

func _swallow_ball(body: RigidBody2D):
	if absorbing or not is_instance_valid(_main_node):
		return
	if _main_node.get("game_over") == true or _main_node.get("cutscene_active") == true:
		return
	var target_node := _main_node.get_node_or_null("Target")
	if target_node and target_node.get("completed") == true:
		return

	absorbing = true
	_pulling_ball = false
	_main_node.set("is_dragging", false)
	_main_node.set("cutscene_active", true)
	_main_node.queue_redraw()

	body.call_deferred("set_linear_velocity", Vector2.ZERO)
	body.call_deferred("set_angular_velocity", 0.0)
	body.call_deferred("set_freeze_enabled", true)

	_animate_swallow(body)

func _animate_swallow(body: RigidBody2D):
	await get_tree().physics_frame
	if not is_instance_valid(body):
		return

	body.z_index = 1
	var sprite := body.get_node_or_null("Sprite2D") as Node2D
	var start_offset: Vector2 = body.global_position - global_position
	var center: Vector2 = global_position

	var tween := create_tween().set_parallel(true)

	# Spiral çizerek kara deliğin merkezine doğru çekilme
	var spiral_move := func(t: float):
		if is_instance_valid(body):
			body.global_position = center + start_offset.rotated(t * TAU * pull_turns) * (1.0 - t)
	tween.tween_method(spiral_move, 0.0, 1.0, pull_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if sprite:
		tween.tween_property(sprite, "scale", Vector2.ZERO, pull_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "rotation", sprite.rotation + TAU * 4.0, pull_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(sprite, "modulate", Color(main_color.r, main_color.g, main_color.b, 0.0), pull_duration) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	await tween.finished

	if is_instance_valid(body):
		body.hide()

	# Yutma sonrası dışa doğru şok halkası
	var flash_tween := create_tween()
	flash_tween.tween_property(self, "flash", 1.0, 0.38).from(0.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await flash_tween.finished

	absorbing = false
	if is_instance_valid(_main_node):
		_main_node.set("cutscene_active", false)
		if _main_node.has_method("end_game"):
			_main_node.end_game(GameProgress.t("swallowed_by_black_hole"))

func _draw():
	var pulse := 0.5 + 0.5 * sin(time * 3.0)

	# 0. Kütleçekim etki alanı halkası (top çekim alanındayken daha belirgin parlar)
	var field_alpha := (0.16 + 0.08 * pulse) if _pulling_ball else (0.06 + 0.03 * pulse)
	draw_arc(Vector2.ZERO, base_pull_radius, 0.0, TAU, 72, Color(main_color.r, main_color.g, main_color.b, field_alpha), 1.4)

	# 1. Dış parıltı (içe doğru yoğunlaşan halkalar)
	for i in range(6):
		draw_circle(Vector2.ZERO, 50.0 - float(i) * 4.0, Color(main_color, 0.04 + float(i) * 0.02))

	# 2. Nabız gibi atan dış halka
	draw_arc(Vector2.ZERO, 32.0 + pulse * 2.0, 0.0, TAU, 64, Color(light_color, 0.5 + 0.3 * pulse), 2.0)

	# 3. Toplanma diski (accretion disk)
	draw_circle(Vector2.ZERO, 28.0, Color(main_color, 0.85))

	# 4. Dönen spiral kollar
	var arms := 4
	for a in range(arms):
		var points := PackedVector2Array()
		var base_angle: float = swirl_angle + float(a) * TAU / float(arms)
		for s in range(16):
			var k: float = float(s) / 15.0
			var r: float = lerpf(30.0, 11.0, k)
			points.append(Vector2.from_angle(base_angle + k * 2.6) * r)
		draw_polyline(points, Color(light_color, 0.78), 2.5, true)

	# 5. İçe doğru akan parçacıklar
	for i in range(particles.size()):
		var p: Dictionary = particles[i]
		var pr: float = p["radius"]
		var pang: float = p["angle"]
		var psize: float = p["size"]
		var alpha: float = clampf((pr - 12.0) / 20.0, 0.0, 1.0)
		draw_circle(Vector2.from_angle(pang) * pr, psize, Color(glow_color, alpha))

	# 6. Olay ufku (kara çekirdek)
	draw_circle(Vector2.ZERO, 14.5, main_color.darkened(0.55))
	draw_circle(Vector2.ZERO, 12.0, core_color)
	draw_arc(Vector2.ZERO, 12.5, 0.0, TAU, 48, Color(glow_color, 0.6 + 0.4 * pulse), 1.5)

	# 7. Yutma sonrası şok dalgası
	if flash > 0.0 and flash < 1.0:
		draw_arc(Vector2.ZERO, 14.0 + flash * 50.0, 0.0, TAU, 64, Color(1.0, 0.9, 0.75, 1.0 - flash), 4.0 * (1.0 - flash) + 1.0)
