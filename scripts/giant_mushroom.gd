@tool
extends StaticBody2D
## Sağ kenardan/zeminden gövdesi yükselen, yukarıdan aşırtma atışları
## zıplatarak geri püskürten dev sabit mantar.

@export var bounce_strength: float = 1.25

var _last_bounce_msec := 0

@onready var ball: RigidBody2D = get_parent().get_node_or_null("Ball") if get_parent() else null

func _ready():
	if Engine.is_editor_hint():
		queue_redraw()
		return

	process_mode = Node.PROCESS_MODE_PAUSABLE

	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	mat.bounce = bounce_strength
	physics_material_override = mat

	var stem_body := get_node_or_null("StemBody") as StaticBody2D
	if stem_body:
		var dull_mat := PhysicsMaterial.new()
		dull_mat.friction = 0.45
		dull_mat.bounce = 0.55
		dull_mat.absorbent = true
		stem_body.physics_material_override = dull_mat

	if ball:
		ball.contact_monitor = true
		if ball.max_contacts_reported < 4:
			ball.max_contacts_reported = 4
		if not ball.body_entered.is_connected(_on_ball_hit):
			ball.body_entered.connect(_on_ball_hit)

	queue_redraw()

func _on_ball_hit(body: Node):
	if body != self:
		return
	if ball and to_local(ball.global_position).y > 8.0:
		return
	var now := Time.get_ticks_msec()
	if now - _last_bounce_msec < 80:
		return
	_last_bounce_msec = now

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.08, 0.88), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.96, 1.06), 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _draw():
	# Sağ kenardan/aşağıdan şapkaya doğru kıvrılarak yükselen dev mantar gövdesi
	var stem := PackedVector2Array([
		Vector2(-32, 18),
		Vector2(36, 18),
		Vector2(85, 130),
		Vector2(175, 290),
		Vector2(110, 290),
		Vector2(28, 145),
	])
	draw_colored_polygon(stem, Color("#9C829B"))

	# Gövde iç aydınlık şeridi
	var stem_light := PackedVector2Array([
		Vector2(-14, 18),
		Vector2(14, 18),
		Vector2(55, 130),
		Vector2(138, 290),
		Vector2(118, 290),
		Vector2(34, 140),
	])
	draw_colored_polygon(stem_light, Color("#C4ACC2"))

	# Şapka altı gölge bileziği (etek)
	var ring := PackedVector2Array([
		Vector2(-42, 14),
		Vector2(44, 14),
		Vector2(54, 34),
		Vector2(0, 28),
		Vector2(-48, 34),
	])
	draw_colored_polygon(ring, Color("#563957"))
	draw_line(Vector2(-40, 22), Vector2(42, 22), Color("#4CF5E8", 0.75), 2.5)

	# Gövde dış konturu
	var stem_outline := stem.duplicate()
	stem_outline.append(stem[0])
	draw_polyline(stem_outline, Color("#241129"), 2.5)

	# Şapkanın altındaki parlayan turkuaz lameller (solungaçlar)
	var under_cap := PackedVector2Array([
		Vector2(-155, 12),
		Vector2(155, 12),
		Vector2(125, 24),
		Vector2(0, 28),
		Vector2(-125, 24),
	])
	draw_colored_polygon(under_cap, Color("#1D5E63"))
	for i in range(-5, 6):
		var gx := i * 24.0
		draw_line(Vector2(gx * 0.4, 26), Vector2(gx, 12), Color("#6BF7E8", 0.65), 2.0)

	# Dev mantar şapkası
	var cap := PackedVector2Array([
		Vector2(-165, 14),
		Vector2(-156, -24),
		Vector2(-118, -68),
		Vector2(-58, -98),
		Vector2(0, -108),
		Vector2(58, -98),
		Vector2(118, -68),
		Vector2(156, -24),
		Vector2(165, 14),
	])
	draw_colored_polygon(cap, Color("#8E2252"))

	# Şapka üst parlak katmanı
	var cap_top := PackedVector2Array([
		Vector2(-136, -16),
		Vector2(-102, -60),
		Vector2(-50, -90),
		Vector2(0, -100),
		Vector2(50, -90),
		Vector2(102, -60),
		Vector2(136, -16),
	])
	draw_colored_polygon(cap_top, Color("#BA326A"))

	# Parlayan turuncu-sarı benekler
	var spots := [
		{"pos": Vector2(-95, -30), "r": 14.0},
		{"pos": Vector2(-38, -66), "r": 18.0},
		{"pos": Vector2(32, -72), "r": 16.0},
		{"pos": Vector2(96, -34), "r": 15.0},
		{"pos": Vector2(-12, -26), "r": 12.0},
		{"pos": Vector2(48, -24), "r": 10.0},
		{"pos": Vector2(-128, -4), "r": 9.0},
		{"pos": Vector2(126, -6), "r": 9.5},
	]
	for s in spots:
		draw_circle(s["pos"], s["r"], Color("#FF9E3B"))
		draw_circle(s["pos"], s["r"] * 0.55, Color("#FFF0A8"))

	# Şapka dış konturu
	var cap_outline := cap.duplicate()
	cap_outline.append(cap[0])
	draw_polyline(cap_outline, Color("#220918"), 3.0)
